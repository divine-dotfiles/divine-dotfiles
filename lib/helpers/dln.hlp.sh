#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: dln
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.2.0-RELEASE
#:revdate:      2019.05.28
#:revremark:    Publication revision
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
## Checks whether every original file in $D_TARGETS[_*] (single path or array 
#. thereof) is currently replaced with a symlink pointing to corresponding 
#. replacement in $D_DPL_ASSETS.
#
## Returns appropriate status based on overall state of installation, prints 
#. warnings when warranted. If in doubt, prefers to prompt user on how to 
#. proceed.
#
## Requires:
#.  $D_DPL_ASSETS       - (array ok) Locations of replacement files
#.  $D_TARGETS          - (array ok) Locations of files to be replaced
#.  $D_TARGETS_LINUX    - (array ok) Overrides $D_TARGETS on Linux
#.  $D_TARGETS_WSL      - (array ok) Overrides $D_TARGETS on WSL
#.  $D_TARGETS_BSD      - (array ok) Overrides $D_TARGETS on BSD
#.  $D_TARGETS_MACOS    - (array ok) Overrides $D_TARGETS on macOS
#.  $D_TARGETS_UBUNTU   - (array ok) Overrides $D_TARGETS on Ubuntu
#.  $D_TARGETS_DEBIAN   - (array ok) Overrides $D_TARGETS on Debian
#.  $D_TARGETS_FEDORA   - (array ok) Overrides $D_TARGETS on Fedora
#.  `dos.utl.sh`
#.  `dln.utl.sh`
#
## Provides into the global scope:
#.  $D_TARGETS    - (array) $D_TARGETS, possibly overridden for current OS
#.  $D_BACKUPS    - (array) Paths to where to put backups of replaced files
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
  # Override $D_TARGETS for current OS family, if that variable is non-empty
  case "$OS_FAMILY" in
    linux)
      [ ${#D_TARGETS_LINUX[@]} -gt 1 -o -n "$D_TARGETS_LINUX" ] \
        && D_TARGETS=( "${D_TARGETS_LINUX[@]}" );;
    wsl)
      [ ${#D_TARGETS_WSL[@]} -gt 1 -o -n "$D_TARGETS_WSL" ] \
        && D_TARGETS=( "${D_TARGETS_WSL[@]}" );;
    bsd)
      [ ${#D_TARGETS_BSD[@]} -gt 1 -o -n "$D_TARGETS_BSD" ] \
        && D_TARGETS=( "${D_TARGETS_BSD[@]}" );;
    macos)
      [ ${#D_TARGETS_MACOS[@]} -gt 1 -o -n "$D_TARGETS_MACOS" ] \
        && D_TARGETS=( "${D_TARGETS_MACOS[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Override $D_TARGETS for current OS distro, if that variable is non-empty
  case "$OS_DISTRO" in
    ubuntu)
      [ ${#D_TARGETS_UBUNTU[@]} -gt 1 -o -n "$D_TARGETS_UBUNTU" ] \
        && D_TARGETS=( "${D_TARGETS_UBUNTU[@]}" );;
    debian)
      [ ${#D_TARGETS_DEBIAN[@]} -gt 1 -o -n "$D_TARGETS_DEBIAN" ] \
        && D_TARGETS=( "${D_TARGETS_DEBIAN[@]}" );;
    fedora)
      [ ${#D_TARGETS_FEDORA[@]} -gt 1 -o -n "$D_TARGETS_FEDORA" ] \
        && D_TARGETS=( "${D_TARGETS_FEDORA[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Check if $D_TARGETS has ended up empty
  [ ${#D_TARGETS[@]} -gt 1 -o -n "$D_TARGETS" ] || {
    local detected_os="$OS_FAMILY"
    [ -n "$OS_DISTRO" ] && detected_os+=" ($OS_DISTRO)"
    dprint_debug \
      'List of paths to replace ($D_TARGETS) is empty for detected system:' \
      "$detected_os"
    return 3
  }

  # Storage variables
  local all_installed=true all_not_installed=true
  local good_pairs_exist=false
  local i
  local orig_path replacement_path orig_md5 backup_path
  local new_d_orig=() new_d_replacements=()
  D_BACKUPS=()

  # Retrieve number of paths to work with (largest size wins)
  [ ${#D_TARGETS[@]} -ge ${#D_DPL_ASSETS[@]} ] \
    && D_NUM_OF_PAIRS=${#D_TARGETS[@]} || D_NUM_OF_PAIRS=${#D_DPL_ASSETS[@]}

  # Iterate over pairs of paths
  for (( i=0; i<$D_NUM_OF_PAIRS; i++ )); do

    # Retrieve/construct three paths
    orig_path="${D_TARGETS[$i]}"
    replacement_path="${D_DPL_ASSETS[$i]}"
    orig_md5="$( dmd5 -s "$orig_path" 2>/dev/null )"
    backup_path="$D_BACKUPS_DIR/$D_NAME/$orig_md5"

    # Check if original and replacement paths are both not empty
    [ -n "$orig_path" -a -n "$replacement_path" ] || {
      dprint_debug 'Skipped an unworkable pair of paths:' \
        -i "'$orig_path' - '$replacement_path'"
      continue
    }

    # If replacement file/dir is not readable, skip it
    [ -r "$replacement_path" ] || {
      dprint_debug "Skipped an unreadable replacement at: $replacement_path"
      continue
    }

    # Check if md5 is correctly calculated
    [ ${#orig_md5} -eq 32 ] || {
      dprint_debug 'Failed to calculate md5 checksum for text string:' \
        "'$orig_path'"
      return 3
    }

    # Past initial checks, it is at least a good pair
    good_pairs_exist=true
    new_d_orig+=( "$orig_path" )
    new_d_replacements+=( "$replacement_path" )
    D_BACKUPS+=( "$backup_path" )

    # Check if replacement is installed
    if dln -?q -- "$replacement_path" "$orig_path" "$backup_path"; then

      # Replacement is installed with backup
      all_not_installed=false

    else

      # Check if it’s just backup that is missing
      if dln -?q -- "$replacement_path" "$orig_path"; then

        # Replacement is installed without backup
        all_not_installed=false

      else

        # Replacement is not installed
        all_installed=false

        # Check if backup path exists, which would be abnormal
        if [ -e "$backup_path" ]; then

          # Report abnormal configuration
          dprint_debug -l 'Despite no record of previous linking of:' \
            "$orig_path" -n "to: $replacement_path" \
            -n "backup exists at: $backup_path" \
            -n '(Force remove to restore orphaned backups)'

        fi

      fi

    fi

  done

  # Check if there were any good pairs
  if $good_pairs_exist; then
    # Overwrite global arrays with filtered paths
    D_TARGETS=( "${new_d_orig[@]}" )
    D_DPL_ASSETS=( "${new_d_replacements[@]}" )
  else
    # If there were no good pairs, print loud warning and signal irrelevant
    dprint_skip -l 'Not a single workable replacement provided'
    return 3
  fi

  # Deliver unanimous verdict or prompt user
  if $all_installed; then return 1
  elif $all_not_installed; then return 2
  else return 4; fi
}

#>  dln_install
#
## Moves each target file in $D_TARGETS to its respective backup location in 
#. $D_BACKUPS; replaces each with a symlink pointing to respective replacement 
#. in $D_DPL_ASSETS.
#
## Requires:
#.  $D_DPL_ASSETS     - (array ok) Locations to symlink to
#.  $D_TARGETS        - (array ok) Paths to back up and replace on current OS
#.  $D_BACKUPS        - (array ok) Backup locations
#.  `dln.utl.sh`
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
    orig_path="${D_TARGETS[$i]}"
    replacement_path="${D_DPL_ASSETS[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    orig_md5="$( basename -- "$backup_path" )"

    # Check if desired set-up is in place (but only if not forcing)
    if ! $D_FORCE && dln -?q -- "$replacement_path" "$orig_path" "$backup_path"
    then

      # Replacement is already installed, with backup
      all_newly_installed=false
      all_failed=false

    else

      # Check if it’s just backup that is missing (but only if not forcing)
      if ! $D_FORCE && dln -?q -- "$replacement_path" "$orig_path"; then

        # Replacement is already installed, without backup
        all_newly_installed=false
        all_failed=false

      else

        # No installation or forcing: install it
        all_already_installed=false

        # Attempt to install
        if dln -f -- "$replacement_path" "$orig_path" "$backup_path"; then

          # Flip switches
          dprint_debug "Replaced path at: $orig_path" \
            -n "with symlink to: $replacement_path"
          all_failed=false

        else

          # Failed to install for some reason
          dprint_debug "Failed to replace path at: $orig_path" \
            -n "with symlink to: $replacement_path"

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
  elif $all_failed; then
    dprint_failure -l 'Failed to install all replacements'
    return 1
  elif $some_failed; then
    dprint_failure -l 'Failed to install some replacements'
    return 1
  else
    dprint_skip -l 'Some replacements were already installed'
    return 0
  fi
}

#>  dln_restore
#
## Removes each path in $D_TARGETS that is a symlink pointing to respective 
#. replacement in $D_DPL_ASSETS. Where possible, restores original file from 
#. corresponding backup location in $D_BACKUPS.
#
## Requires:
#.  $D_DPL_ASSETS     - (array ok) Locations currently symlinked to
#.  $D_TARGETS        - (array ok) Paths to be restored on current OS
#.  $D_BACKUPS        - (array ok) Backup locations
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
    orig_path="${D_TARGETS[$i]}"
    replacement_path="${D_DPL_ASSETS[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    orig_md5="$( basename -- "$backup_path" )"

    # Check if replacement appears to be installed
    if dln -?q -- "$replacement_path" "$orig_path" "$backup_path"; then

      # Replacement is evidently installed
      all_already_removed=false

      # Attempt to remove
      if dln -fr -- "$replacement_path" "$orig_path" "$backup_path"; then

        # Report and flip switches
        dprint_debug "Undid replacement of: $orig_path" \
          -n "with symlink to: $replacement_path" \
          -n "and restored backup from: $backup_path"
        all_failed=false

      else

        # Failed to remove for some reason
        dprint_debug "Failed to undo replacement of: $orig_path" \
          -n "with symlink to: $replacement_path" \
          -n "and restore backup from: $backup_path"

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

          # Report and flip switches
          dprint_debug 'Undid replacement of:' "$orig_path" \
            -n 'with symlink to:' "$replacement_path"
          all_failed=false

        else

          # Failed to remove for some reason
          dprint_debug 'Failed to undo replacement of:' "$orig_path" \
            -n 'with symlink to:' "$replacement_path"

          # Flip switches
          all_newly_removed=false
          some_failed=true

        fi

      else

        # No installation detected

        # Check if forcing
        if $D_FORCE; then

          # Remove as best as possible

          # Check if backup path exists
          if [ -e "$backup_path" ]; then

            # Backup exists

            # Remove whatever sits on original location and check status
            if rm -rf -- "$orig_path"; then

              # Report
              dprint_debug "Clobbered original path at: $orig_path"

            else

              # Report and skip
              dprint_debug "Failed to clobber original path at: $orig_path" \
                -n "while restoring backup from: $backup_path"

              # Flip switches and move on
              all_already_removed=false
              all_newly_removed=false
              some_failed=true
              continue

            fi

            # Move backup path to original location, and check status
            if mv -n -- "$backup_path" "$orig_path"; then

              # Report and flip switches
              dprint_debug "Restored backup from: $backup_path" \
                -n "to its original location at: $orig_path"
              all_already_removed=false
              all_failed=false
            
            else

              # Report
              dprint_debug "Failed to restore backup from: $backup_path" \
                -n "to its original location at: $orig_path"
              
              # Flip switches
              all_already_removed=false
              all_newly_removed=false
              some_failed=true

            fi
          
          fi

        else

          # No installation detected and not forcing: job’s done
          all_newly_removed=false
          all_failed=false

        fi

      fi

    fi

  done

  # Print messages as appropriate and return status
  if $all_newly_removed; then
    return 0
  elif $all_already_removed; then
    dprint_skip -l 'All replacements were already undone'
    return 0
  elif $all_failed; then
    dprint_failure -l 'Failed to undo all replacements'
    return 1
  elif $some_failed; then
    dprint_failure -l 'Failed to undo some replacements'
    return 1
  else
    dprint_skip -l 'Some replacements were already undone'
    return 0
  fi
}