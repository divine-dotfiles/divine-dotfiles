#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: cp
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.1.0-RELEASE
#:revdate:      2019.05.28
#:revremark:    Publication revision
#:created_at:   2019.05.23

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template ‘copy-files.dpl.sh’
#
## Copies provided files (e.g., font files) to provided locations (e.g., into 
#. OS’s fonts directory). Pre-existing files at destination directory with same 
#. name are backed up to backups directory and restored upon removal.
#

#>  cp_check
#
## Checks whether every file in $D_TARGETS[_*] (single path or array thereof) 
#. is currently a copy of corresponding file in $D_DPL_ASSETS
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
#
## Provides into the global scope:
#.  $D_TARGETS  - (array) $D_TARGETS, possibly overridden for current OS
#.  $D_BACKUPS  - (array) Paths to where to put backups of replaced files
#
## Returns:
#.  Values supported by dcheck function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
cp_check()
{
  # This one will rely on stashing
  dstash ready || return 3

  # Override $D_TARGETS for current OS family, if specific variable is non-empty
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

  # Override $D_TARGETS for current OS distro, if specific variable is non-empty
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
  local all_installed=true all_not_installed=true some_trouble=false
  local good_pairs_exist=false
  local i
  local to_path from_path to_md5 backup_path
  local new_d_to=() new_d_from=()
  D_BACKUPS=()
  D_USER_OR_OS=true

  # Retrieve number of paths to work with (largest size wins)
  [ ${#D_TARGETS[@]} -ge ${#D_DPL_ASSETS[@]} ] \
    && D_NUM_OF_PAIRS=${#D_TARGETS[@]} || D_NUM_OF_PAIRS=${#D_DPL_ASSETS[@]}

  # Iterate over pairs of paths
  for (( i=0; i<$D_NUM_OF_PAIRS; i++ )); do

    # Retrieve/construct three paths
    to_path="${D_TARGETS[$i]}"
    from_path="${D_DPL_ASSETS[$i]}"
    to_md5="$( dmd5 -s "$to_path" 2>/dev/null )"
    backup_path="$D_BACKUPS_DIR/$D_NAME/$to_md5"

    # Check if source and destination paths are both not empty
    [ -n "$to_path" -a -n "$from_path" ] || {
      dprint_debug 'Skipped an unworkable pair of paths:' \
        -i "'$to_path' - '$from_path'"
      continue
    }

    # If source filepath is not readable, skip it
    [ -r "$from_path" ] || {
      dprint_debug "Skipped an unreadable replacement at: $from_path"
      continue
    }

    # Check if md5 is correctly calculated
    [ ${#to_md5} -eq 32 ] || {
      dprint_debug 'Failed to calculate md5 checksum for text string:' \
        "'$to_path'"
      return 3
    }

    # Past initial checks, it is at least a good pair
    good_pairs_exist=true
    new_d_to+=( "$to_path" )
    new_d_from+=( "$from_path" )
    D_BACKUPS+=( "$backup_path" )

    # Check if source filepath is copied
    if dstash -s has "$to_md5"; then

      # Check if there is a copy at destination path
      if [ -e "$to_path" ]; then

        # Source filepath is copied
        all_not_installed=false
      
        # Report
        if [ -e "$backup_path" ]; then
          dprint_debug "Copied    : '$from_path' -> '$to_path'" \
            -n "Destination path backed up at: $backup_path"
        else
          dprint_debug "Copied    : '$from_path' -> '$to_path'"
        fi
      
      else

        # Despite record of copying, destination filepath does not exist
        all_installed=false
        some_trouble=true
        dprint_debug \
          "Despite the record of previous copying from: $from_path" \
          -n "to: $to_path" -n 'destination path does not exist' \
          -n '(Install/remove to fix this)'

      fi

    else

      # No record of previous copying

      # Check if backup path nevertheless exists
      if [ -e "$backup_path" ]; then

        # Backup path exists without record of installation
        all_not_installed=false
        some_trouble=true
        dprint_debug "Despite no record of previous copying from: $from_path" \
          -n "to: $to_path" -n "backup path exists at: $backup_path" \
          -n '(Re-installing will overwrite that backup)'

      else

        # Source filepath is not copied
        all_installed=false

        # Report
        dprint_debug "Not copied: '$from_path' -> '$to_path'"

      fi

    fi

  done

  # Check if there were any good pairs
  if $good_pairs_exist; then
    # Overwrite global arrays with filtered paths
    D_TARGETS=( "${new_d_to[@]}" )
    D_DPL_ASSETS=( "${new_d_from[@]}" )
  else
    # If there were no good pairs, print loud warning and signal irrelevant
    dprint_skip -l 'Not a single workable source-destination pair provided'
    return 3
  fi

  # Deliver unanimous verdict or prompt user
  if $all_installed; then return 1
  elif $all_not_installed; then return 2
  else
    if $some_trouble; then
      D_ASK_AGAIN=true
      D_WARNING='There are irregularities with this deployment'
    fi
    return 4
  fi
}

#>  cp_install
#
## Copies each original file in $D_DPL_ASSETS to its respective destination 
#. location in $D_TARGETS, moving pre-existing files to corresponging backup 
#. locations in $D_BACKUPS.
#
## Requires:
#.  $D_DPL_ASSETS - (array ok) Source filepaths
#.  $D_TARGETS    - (array ok) Destination filepaths on current OS
#.  $D_BACKUPS    - (array ok) Backup locations
#
## Returns:
#.  Values supported by dinstall function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
cp_install()
{
  # Storage variables
  local all_newly_installed=true all_already_installed=true all_failed=true
  local some_failed=false
  local i
  local to_path from_path to_md5 backup_path

  # Iterate over pairs of paths
  for (( i=0; i<$D_NUM_OF_PAIRS; i++ )); do

    # Retrieve/construct three paths
    to_path="${D_TARGETS[$i]}"
    from_path="${D_DPL_ASSETS[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    to_md5="$( basename -- "$backup_path" )"

    # Check if there is a reason to (re-)install
    if ! dstash -s has "$to_md5" || [ ! -e "$to_path" ] || $D_FORCE; then

      # No previous copying recorded, or forcing

      # Check if something already exists at destination path
      if [ -e "$to_path" ]; then

        # Check if something exists at backup path
        if [ -e "$backup_path" ]; then

          # Backup path is occupied: erase it
          if rm -rf -- "$backup_path"; then

            # Report event
            dprint_debug "Clobbered unexpected backup: $backup_path" \
              -n "of destination path at: $to_path"
            
          else

            # Failed to remove unrecorded backup: abandon this copying
            all_newly_installed=false
            all_already_installed=false
            some_failed=true
            dprint_debug "Failed to clobber unexpected backup: $backup_path" \
              -n "of destination path at: $to_path" \
              -n '(Skipping this source/destination pair)'
            continue
          
          fi

        fi

        # Move destination path to backup path and check status
        if mv -n -- "$to_path" "$backup_path"; then

          # Report event
          dprint_debug "Backed up destination path at: $to_path" \
            -n "to: $backup_path"

        else

          # Failed to back up destination path: abandon this copying
          all_newly_installed=false
          all_already_installed=false
          some_failed=true
          dprint_debug "Failed to back up destination path at: $to_path" \
            -n "to: $backup_path" \
            -n '(Skipping this source/destination pair)'
          continue

        fi

      fi

      # Copy source path to destination path and check status
      if cp -Rn -- "$from_path" "$to_path"; then

        # Successfully copied
        dprint_debug "Copied from: $from_path" -n "to: $to_path"
        all_already_installed=false
        all_failed=false
        dstash -s set "$to_md5"

      else

        # Failed to copy
        all_newly_installed=false
        all_already_installed=false
        some_failed=false
        dprint_debug "Failed to copy from: $from_path" -n "to: $to_path"

      fi

    else

      # Previous copying is recorded, destination exists: already installed
      all_newly_installed=false
      all_failed=false

    fi

  done

  # Print messages as appropriate and return status
  if $all_newly_installed; then
    return 0
  elif $all_already_installed; then
    dprint_skip -l 'All source filepaths were already copied'
    return 0
  elif $all_failed; then
    dprint_failure -l 'Failed to copy all source filepaths'
    return 1
  elif $some_failed; then
    dprint_failure -l 'Failed to copy some source filepaths'
    return 1
  else
    dprint_skip -l 'Some source filepaths were already copied'
    return 0
  fi
}

#>  cp_restore
#
## Removes each path in $D_TARGETS that has record of previous copying, then 
#. moves corresponding path in $D_BACKUPS to its original location
#
## Requires:
#.  $D_TARGETS    - (array ok) Paths to be restored on current OS
#.  $D_BACKUPS    - (array ok) Backup locations
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by dremove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
cp_restore()
{
  # Storage variables
  local all_newly_restored=true all_already_restored=true all_failed=true
  local some_failed=false
  local i
  local to_path from_path to_md5 backup_path

  # Iterate over pairs of paths in reverse order, just for kicks
  for (( i=$D_NUM_OF_PAIRS-1; i>=0; i-- )); do

    # Retrieve/construct three paths
    to_path="${D_TARGETS[$i]}"
    from_path="${D_DPL_ASSETS[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    to_md5="$( basename -- "$backup_path" )"

    # Check if there is a reason to (re-)undo
    if dstash -s has "$to_md5" || $D_FORCE; then

      # Previous copying recorded, or forcing
      all_already_restored=false

      ## If destination path exists, erase in two distinct cases:
      #.  * Stash record exists (proper restoration)
      #.  * No stash record (=forcing), but there is backup to restore
      #
      if [ -e "$to_path" ] \
        && ( dstash -s has "$to_md5" || [ -e "$backup_path" ] )
      then

        # Remove destination path and check status
        if rm -rf -- "$to_path"; then

          # Successfully erased destination path: report
          dprint_debug "Erased destination path: $to_path" \
            -n "of respective source path: $from_path"

        else

          # Report, flip switches, move on
          dprint_debug "Failed to erase destination path: $to_path" \
            -n "of respective source path: $from_path" \
            -n '(Skipping this source/destination pair)'
          all_newly_restored=false
          some_failed=true
          continue

        fi

      fi

      # Check if backup is present
      if [ -e "$backup_path" ]; then

        # Move backup path to its original path and check status
        if mv -n -- "$backup_path" "$to_path"; then

          # Successfully restored backup: report
          dprint_debug "Restored backup: $backup_path" \
            -n "to destination path at: $to_path"
          
        else

          # Failed to restore backup
          dprint_debug "Failed to restore backup: $backup_path" \
            -n "to destination path at: $to_path" \
            -n '(Skipping this source/destination pair)'
          all_newly_restored=false
          some_failed=true
          continue
        
        fi

      fi

      # Done what everything possible to restore set-up
      all_failed=false
      dstash -s unset "$to_md5"

    else

      # No reason to undo
      all_newly_restored=false
      all_failed=false

    fi

  done

  # Print messages as appropriate and return status
  if $all_newly_removed; then
    return 0
  elif $all_already_removed; then
    dprint_skip -l 'All copies were already removed'
    return 0
  elif $all_failed; then
    dprint_failure -l 'Failed to remove all copies'
    return 1
  elif $some_failed; then
    dprint_failure -l 'Failed to remove some copies'
    return 1
  else
    dprint_skip -l 'Some copies were already removed'
    return 0
  fi
}