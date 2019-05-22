#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: dln
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.04.02
#:revremark:    Initial revision
#:created_at:   2019.04.02

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template ‘link-files.dpl.sh’
#
## Replaces some files (e.g., config file) with symlinks to provided 
#. replacements. Creates backup of each replaced file. Restores original set-up 
#. on removal.
#

#>  dln_check
#
## Checks whether every original file in $D_ORIG[_*] (single path or array 
#. thereof) is currently replaced with a symlink pointing to corresponding 
#. replacement in $D_REPLACEMENTS.
#
## Returns appropriate status based on overall state of installation, prints 
#. warnings when warranted. If in doubt, prefers to prompt user on how to 
#. proceed.
#
## Requires:
#.  $D_REPLACEMENTS - (array ok) Locations of replacement files
#.  $D_ORIG         - (array ok) Locations of files to be replaced
#.  $D_ORIG_LINUX   - (array ok) Overrides $D_ORIG on Linux
#.  $D_ORIG_WSL     - (array ok) Overrides $D_ORIG on WSL
#.  $D_ORIG_BSD     - (array ok) Overrides $D_ORIG on BSD
#.  $D_ORIG_MACOS   - (array ok) Overrides $D_ORIG on macOS
#.  $D_ORIG_UBUNTU  - (array ok) Overrides $D_ORIG on Ubuntu
#.  $D_ORIG_DEBIAN  - (array ok) Overrides $D_ORIG on Debian
#.  $D_ORIG_FEDORA  - (array ok) Overrides $D_ORIG on Fedora
#.  `dos.utl.sh`
#.  `dln.utl.sh`
#
## Provides into the global scope:
#.  $D_ORIG       - (array) $D_ORIG, possibly overridden for current OS
#
## Returns:
#.  Values supported by dcheck function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
dln_check()
{
  # Override $D_ORIG for current OS family, if specific variable is non-empty
  case "$OS_FAMILY" in
    linux)
      [ ${#D_ORIG_LINUX[@]} -gt 1 -o -n "$D_ORIG_LINUX" ] \
        && D_ORIG=( "${D_ORIG_LINUX[@]}" );;
    wsl)
      [ ${#D_ORIG_WSL[@]} -gt 1 -o -n "$D_ORIG_WSL" ] \
        && D_ORIG=( "${D_ORIG_WSL[@]}" );;
    bsd)
      [ ${#D_ORIG_BSD[@]} -gt 1 -o -n "$D_ORIG_BSD" ] \
        && D_ORIG=( "${D_ORIG_BSD[@]}" );;
    macos)
      [ ${#D_ORIG_MACOS[@]} -gt 1 -o -n "$D_ORIG_MACOS" ] \
        && D_ORIG=( "${D_ORIG_MACOS[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Override $D_ORIG for current OS distro, if specific variable is non-empty
  case "$OS_DISTRO" in
    ubuntu)
      [ ${#D_ORIG_UBUNTU[@]} -gt 1 -o -n "$D_ORIG_UBUNTU" ] \
        && D_ORIG=( "${D_ORIG_UBUNTU[@]}" );;
    debian)
      [ ${#D_ORIG_DEBIAN[@]} -gt 1 -o -n "$D_ORIG_DEBIAN" ] \
        && D_ORIG=( "${D_ORIG_DEBIAN[@]}" );;
    fedora)
      [ ${#D_ORIG_FEDORA[@]} -gt 1 -o -n "$D_ORIG_FEDORA" ] \
        && D_ORIG=( "${D_ORIG_FEDORA[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Check if $D_ORIG has ended up empty
  [ ${#D_ORIG[@]} -gt 1 -o -n "$D_ORIG" ] || {
    local detected_os="$OS_FAMILY"
    [ -n "$OS_DISTRO" ] && detected_os+="($OS_DISTRO)"
    dprint_debug \
      'List of paths to replace ($D_ORIG) is empty for detected system:' \
      -i "$detected_os)"
    return 3
  }

  # Rely on stash
  dstash ready || return 3

  # Storage variables
  local all_installed=true all_not_installed=true all_botched=true
  local some_botched=false good_pairs_exist=false
  local i
  local orig_path replacement_path orig_md5 backup_path
  local new_d_orig=() new_d_replacements=()
  D_BACKUPS=()

  # Retrieve number of paths to work with (largest size wins)
  [ ${#D_ORIG[@]} -ge ${#D_REPLACEMENTS[@]} ] \
    && D_NUM_OF_PAIRS=${#D_ORIG[@]} || D_NUM_OF_PAIRS=${#D_REPLACEMENTS[@]}

  # Iterate over pairs of paths
  for (( i=0; i<$D_NUM_OF_PAIRS; i++ )); do

    # Retrieve/construct three paths
    orig_path="${D_ORIG[$i]}"
    replacement_path="${D_REPLACEMENTS[$i]}"
    orig_md5="$( dmd5 -s "$orig_path" 2>/dev/null )"
    backup_path="$D_BACKUPS_DIR/$D_NAME/$orig_md5"

    # Check if original and replacement paths are both not empty
    [ -n "$orig_path" -a -n "$replacement_path" ] || {
      dprint_debug 'Received an unworkable pair of paths:' \
        -i "'$orig_path' - '$replacement_path'" -n 'Skipping'
      continue
    }

    # If replacement file is not readable, skip it
    [ -f "$replacement_path" -a -r "$replacement_path" ] || {
      dprint_debug 'Replacement file is not readable:' \
        -i "$replacement_path" -n 'Skipping'
      continue
    }

    # Check if md5 is correctly calculated
    [ ${#orig_md5} -eq 32 ] || {
      dprint_debug 'Failed to calculate md5 checksum for text string:' \
        -i "'$orig_path'"
      return 3
    }

    # Past initial checks, it is at least a good pair
    good_pairs_exist=true
    new_d_orig+=( "$orig_path" )
    new_d_replacements+=( "$replacement_path" )
    D_BACKUPS+=( "$backup_path" )

    # Check if record of previous installation exists
    if dstash has "$orig_md5"; then

      # Record of previous installation exists

      # Check if that record tells the truth
      if dln -?q -- "$replacement_path" "$orig_path" "$backup_path"; then

        # Previous installation record is valid and true
        all_not_installed=false
        all_botched=false

      else

        # Check if it’s just backup that is missing
        if dln -?q -- "$replacement_path" "$orig_path"; then

          # Still a valid previous installation
          all_not_installed=false
          all_botched=false

        else

          # Unreliable stash record: there is actually no installation
          dprint_debug 'Stashed record of replacing:' -i "$orig_path" \
            -n 'with:' -i "$replacement_path" -n 'is not supported by facts'
          all_installed=false
          some_botched=true

        fi

      fi

    else

      # No record of previous installation

      # Still, check if desired set-up is in place (e.g., wiped stash)
      if dln -?q -- "$replacement_path" "$orig_path" "$backup_path"; then

        # Despite missing record, replacement is installed, with backup
        dprint_debug 'Path at:' -i "$orig_path" -n 'is replaced with:' \
          -i "$replacement_path" -n 'with possible backup at:' \
          -i "$backup_path" -n 'but without appropriate stash record'
        all_not_installed=false
        some_botched=true

      else

        # Check if it’s just backup that is missing
        if dln -?q -- "$replacement_path" "$orig_path"; then

          # Despite missing record, replacement is installed, without backup
          dprint_debug 'Path at:' -i "$orig_path" -n 'is replaced with:' \
            -i "$replacement_path" -n 'without backup' \
            'and, more importantly, without appropriate stash record'
          all_not_installed=false
          some_botched=true

        else

          # No record and no installation: all fair
          all_installed=false
          all_botched=false

        fi

      fi

    fi

  done

  # Report and return

  # Check if there were any good pairs
  if $good_pairs_exist; then
    # Overwrite global arrays with filtered paths
    D_ORIG=( "${new_d_orig[@]}" )
    D_REPLACEMENTS=( "${new_d_replacements[@]}" )
  else
    # If there were no good pairs, print loud warning and signal irrelevant
    dprint_skip -l 'Not a single workable replacement provided'
    return 3
  fi

  # Print loud warning for presence of botched installations
  if $all_botched; then
    dprint_start -l 'Stash records are unreliable for all replacements'
  elif $some_botched; then
    dprint_start -l 'Stash records are unreliable for some replacements'
  fi

  # If no botched jobs, deliver unanimous verdict; otherwise prompt user
  if $all_installed; then
    $some_botched && return 0 || return 1
  elif $all_not_installed; then
    $some_botched && return 0 || return 2
  else
    dprint_start -l 'Replacements appear partially installed'
    return 0
  fi
}

#>  dln_install
#
## Moves each original file in $D_ORIG to its respective backup location in 
#. $D_BCKP; replaces each with a symlink pointing to respective target file in 
#. $D_REPLACEMENTS.
#
## Requires:
#.  $D_REPLACEMENTS     - (array ok) Locations to symlink to
#.  $D_ORIG       - (array ok) Paths to back up and replace on current OS
#.  $D_BCKP       - (array ok) Backup locations on current OS
#.  Divine Bash utils: dmvln (dmvln.utl.sh)
#
## Returns:
#.  Values supported by dinstall function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
dln_install()
{
  # Storage variables
  local all_newly_installed=true all_already_installed=true all_failed=true
  local some_failed=false
  local i
  local orig_path replacement_path orig_md5 backup_path

  # Iterate over pairs of paths
  for (( i=0; i<$D_NUM_OF_PAIRS; i++ )); do

    # Retrieve/construct three paths
    orig_path="${D_ORIG[$i]}"
    replacement_path="${D_REPLACEMENTS[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    orig_md5="$( basename -- "$backup_path" )"

    # Still, check if desired set-up is in place (e.g., wiped stash)
    if dln -?q -- "$replacement_path" "$orig_path" "$backup_path"; then

      # Replacement is already installed, with backup
      
      # Add stash record if it is not there
      if ! dstash has "$orig_md5"; then
        dstash set "$orig_md5"
        dprint_debug 'Added missing stash record about replacing:' \
          -i "$orig_path" -n 'with:' -i "$replacement_path" \
          -n 'with backup at:' -i "$backup_path"
      fi

      # Flip switches
      all_newly_installed=false
      all_failed=false

    else

      # Check if it’s just backup that is missing
      if dln -?q -- "$replacement_path" "$orig_path"; then

        # Replacement is already installed, without backup

        # Add stash record if it is not there
        if ! dstash has "$orig_md5"; then
          dstash set "$orig_md5"
          dprint_debug 'Added missing stash record about replacing:' \
            -i "$orig_path" -n 'with:' -i "$replacement_path" \
            -n 'without backup'
        fi

        all_newly_installed=false
        all_failed=false

      else

        # No installation: install it
        all_already_installed=false

        # Attempt to install
        if dln -f -- "$replacement_path" "$orig_path" "$backup_path"; then

          # All good, make stash record
          if dstash has "$orig_md5"; then
            dprint_debug 'Fulfilled orphaned stash record about replacing:' \
              -i "$orig_path" -n 'with:' -i "$replacement_path"
          else
            dstash set "$orig_md5"
          fi

          # Flip switches
          all_failed=false

        else

          # Failed to install for some reason
          dprint_debug 'Failed to replace path at:' -i "$orig_path" \
            -n 'with:' -i "$replacement_path"

          # Flip switches
          all_newly_installed=false
          some_failed=true

        fi

      fi

    fi

  done

  # Print messages as appropriate and return status
  if $all_newly_installed; then
    return 0
  elif $all_already_installed; then
    dprint_skip -l 'All replacements were already installed'
    return 0
  else
    if $all_failed; then
      dprint_failure -l 'Failed to install all replacements'
      return 1
    elif $some_failed; then
      dprint_failure -l 'Failed to install some replacements'
      return 1
    else
      dprint_skip -l 'Some replacements were already installed'
      return 0
    fi
  fi
}

#>  dln_restore
#
## Removes each path in $D_ORIG that is a symlink pointing to respective target 
#. file in $D_REPLACEMENTS; where possible, restores original file from 
#. corresponding backup location in $D_BCKP.
#
## Requires:
#.  $D_REPLACEMENTS   - (array ok) Locations currently symlinked to
#.  $D_ORIG           - (array ok) Paths to be restored on current OS
#.  $D_BCKP           - (array ok) Backup locations on current OS
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by dremove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
dln_restore()
{
  # Storage variables
  local all_newly_removed=true all_already_removed=true all_failed=true
  local some_failed=false
  local i
  local orig_path replacement_path orig_md5 backup_path

  # Iterate over pairs of paths in reverse order, just for kicks
  for (( i=$D_NUM_OF_PAIRS-1; i>=0; i-- )); do

    # Retrieve/construct three paths
    orig_path="${D_ORIG[$i]}"
    replacement_path="${D_REPLACEMENTS[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    orig_md5="$( basename -- "$backup_path" )"

    # Check if replacement appears to be installed
    if dln -?q -- "$replacement_path" "$orig_path" "$backup_path"; then

      # Replacement is evidently installed
      all_already_removed=false

      # Attempt to remove
      if dln -fr -- "$replacement_path" "$orig_path" "$backup_path"; then

        # Removed successfully, ensure stash record is unset
        if dstash has "$orig_md5"; then
          dstash unset "$orig_md5"
          dprint_debug 'Removed orphaned stash record about replacing:' \
            -i "$orig_path" -n 'with:' -i "$replacement_path" \
            -n 'with backup at:' -i "$backup_path"
        fi

        # Flip switches
        all_failed=false

      else

        # Failed to remove for some reason
        dprint_debug 'Failed to undo replacement of:' -i "$orig_path" \
          -n 'with:' -i "$replacement_path" -n 'and backup at:' \
          -i "$backup_path"

        # Flip switches
        all_newly_removed=false
        some_failed=true

      fi

    else

      # Check if it’s just backup that is missing
      if dln -?q -- "$replacement_path" "$orig_path"; then

        # Still a valid previous installation
        all_already_removed=false
        
        # Attempt to remove
        if dln -fr -- "$replacement_path" "$orig_path"; then

          # Removed successfully, ensure stash record is unset
          if dstash has "$orig_md5"; then
            dstash unset "$orig_md5"
            dprint_debug 'Removed orphaned stash record about replacing:' \
              -i "$orig_path" -n 'with:' -i "$replacement_path" \
              -n 'without backup'
          fi

          # Flip switches
          all_failed=false

        else

          # Failed to remove for some reason
          dprint_debug 'Failed to undo replacement of:' -i "$orig_path" \
            -n 'with:' -i "$replacement_path"

          # Flip switches
          all_newly_removed=false
          some_failed=true

        fi

      else

        # There is no installation to speak of

        # Make sure there is no stash record
        if ! dstash has "$orig_md5"; then
          dprint_debug 'Undid replacing:' -i "$orig_path" -n 'with:' \
            -i "$replacement_path" -n 'to reflect missing stash record'
        else
          dstash unset "$orig_md5"
        fi

        # Flip switches
        all_newly_removed=false
        all_failed=false

      fi

    fi

  done

  # Print messages as appropriate and return status
  if $all_newly_removed; then
    return 0
  elif $all_already_removed; then
    dprint_skip -l 'All replacements were already undone'
    return 0
  else
    if $all_failed; then
      dprint_failure -l 'Failed to undo all replacements'
      return 1
    elif $some_failed; then
      dprint_failure -l 'Failed to undo some replacements'
      return 1
    else
      dprint_skip -l 'Some replacements were already undone'
      return 0
    fi
  fi
}