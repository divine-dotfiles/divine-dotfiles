#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: cp
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.23
#:revremark:    Initial revision
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
## Checks whether every file in $D_TO[_*] (single path or array thereof) is 
#. currently a copy of corresponding file in $D_FROM
#
## Returns appropriate status based on overall state of installation, prints 
#. warnings when warranted. If in doubt, prefers to prompt user on how to 
#. proceed.
#
## Requires:
#.  $D_FROM       - (array ok) Locations of replacement files
#.  $D_TO         - (array ok) Locations of files to be replaced
#.  $D_TO_LINUX   - (array ok) Overrides $D_TO on Linux
#.  $D_TO_WSL     - (array ok) Overrides $D_TO on WSL
#.  $D_TO_BSD     - (array ok) Overrides $D_TO on BSD
#.  $D_TO_MACOS   - (array ok) Overrides $D_TO on macOS
#.  $D_TO_UBUNTU  - (array ok) Overrides $D_TO on Ubuntu
#.  $D_TO_DEBIAN  - (array ok) Overrides $D_TO on Debian
#.  $D_TO_FEDORA  - (array ok) Overrides $D_TO on Fedora
#.  `dos.utl.sh`
#
## Provides into the global scope:
#.  $D_TO         - (array) $D_TO, possibly overridden for current OS
#.  $D_BACKUPS    - (array) Paths to where to put backups of replaced files
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

  # Override $D_TO for current OS family, if specific variable is non-empty
  case "$OS_FAMILY" in
    linux)
      [ ${#D_TO_LINUX[@]} -gt 1 -o -n "$D_TO_LINUX" ] \
        && D_TO=( "${D_TO_LINUX[@]}" );;
    wsl)
      [ ${#D_TO_WSL[@]} -gt 1 -o -n "$D_TO_WSL" ] \
        && D_TO=( "${D_TO_WSL[@]}" );;
    bsd)
      [ ${#D_TO_BSD[@]} -gt 1 -o -n "$D_TO_BSD" ] \
        && D_TO=( "${D_TO_BSD[@]}" );;
    macos)
      [ ${#D_TO_MACOS[@]} -gt 1 -o -n "$D_TO_MACOS" ] \
        && D_TO=( "${D_TO_MACOS[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Override $D_TO for current OS distro, if specific variable is non-empty
  case "$OS_DISTRO" in
    ubuntu)
      [ ${#D_TO_UBUNTU[@]} -gt 1 -o -n "$D_TO_UBUNTU" ] \
        && D_TO=( "${D_TO_UBUNTU[@]}" );;
    debian)
      [ ${#D_TO_DEBIAN[@]} -gt 1 -o -n "$D_TO_DEBIAN" ] \
        && D_TO=( "${D_TO_DEBIAN[@]}" );;
    fedora)
      [ ${#D_TO_FEDORA[@]} -gt 1 -o -n "$D_TO_FEDORA" ] \
        && D_TO=( "${D_TO_FEDORA[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Check if $D_TO has ended up empty
  [ ${#D_TO[@]} -gt 1 -o -n "$D_TO" ] || {
    local detected_os="$OS_FAMILY"
    [ -n "$OS_DISTRO" ] && detected_os+="($OS_DISTRO)"
    dprint_debug \
      'List of paths to replace ($D_TO) is empty for detected system:' \
      -i "$detected_os)"
    return 3
  }

  # Storage variables
  local all_installed=true all_not_installed=true some_trouble=false
  local good_pairs_exist=false
  local i
  local to_path from_path to_md5 backup_path
  local new_d_to=() new_d_from=()
  D_BACKUPS=()

  # Retrieve number of paths to work with (largest size wins)
  [ ${#D_TO[@]} -ge ${#D_FROM[@]} ] \
    && D_NUM_OF_PAIRS=${#D_TO[@]} || D_NUM_OF_PAIRS=${#D_FROM[@]}

  # Iterate over pairs of paths
  for (( i=0; i<$D_NUM_OF_PAIRS; i++ )); do

    # Retrieve/construct three paths
    to_path="${D_TO[$i]}"
    from_path="${D_FROM[$i]}"
    to_md5="$( dmd5 -s "$to_path" 2>/dev/null )"
    backup_path="$D_BACKUPS_DIR/$D_NAME/$to_md5"

    # Check if source and destination paths are both not empty
    [ -n "$to_path" -a -n "$from_path" ] || {
      dprint_debug 'Received an unworkable pair of paths:' \
        -i "'$to_path' - '$from_path'" -n 'Skipping'
      continue
    }

    # If source filepath is not readable, skip it
    [ -r "$from_path" ] || {
      dprint_debug 'Replacement is not readable at:' \
        -i "$from_path" -n 'Skipping'
      continue
    }

    # Check if md5 is correctly calculated
    [ ${#to_md5} -eq 32 ] || {
      dprint_debug 'Failed to calculate md5 checksum for text string:' \
        -i "'$to_path'"
      return 3
    }

    # Past initial checks, it is at least a good pair
    good_pairs_exist=true
    new_d_to+=( "$to_path" )
    new_d_from+=( "$from_path" )
    D_BACKUPS+=( "$backup_path" )

    # Check if source filepath is copied
    if dstash has "$to_md5"; then

      # Check if nevertheless there is a copy at destination path
      if [ -e "$to_path" ]; then

        # Source filepath is copied
        all_not_installed=false
      
      else

        # Despite record of copying, source filepath does not exist
        all_installed=false
        some_trouble=true
        dprint_debug 'Despite the record of previous copying from:' \
          -i "$from_path" -n 'to:' -i "$to_path" \
          -n 'destination path does not exist' \
          -n 'Installing/removeing will fix this'

      fi

    else

      # No record of previous copying

      # Check if backup path nevertheless exists
      if [ -e "$backup_path" ]; then

        # Backup path exists without record of installation
        all_not_installed=false
        some_trouble=true
        dprint_debug 'Despite the lack of record of previous copying from:' \
          -i "$from_path" -n 'to:' -i "$to_path" \
          -n 'backup path exists at:' -i "$backup_path" \
          -n 'Re-installing will overwrite it'

      else

        # Source filepath is not copied
        all_installed=false

      fi

    fi

  done

  # Check if there were any good pairs
  if $good_pairs_exist; then
    # Overwrite global arrays with filtered paths
    D_TO=( "${new_d_to[@]}" )
    D_FROM=( "${new_d_from[@]}" )
  else
    # If there were no good pairs, print loud warning and signal irrelevant
    dprint_skip -l 'Not a single workable source-destination pair provided'
    return 3
  fi

  # Deliver unanimous verdict or prompt user
  if $all_installed; then return 1
  elif $all_not_installed; then return 2
  elif $some_trouble; then
    dprint_start -l 'There are irregularities with this deployment'
    return 0
  else
    dprint_start -l 'Source filepaths appear partially copied'
    return 0
  fi
}

#>  cp_install
#
## Copies each original file in $D_FROM to its respective destination location 
#. in $D_TO, moving pre-existing files to corresponging backup locations in 
#. $D_BACKUPS.
#
## Requires:
#.  $D_FROM       - (array ok) Source filepaths
#.  $D_TO         - (array ok) Destination filepaths on current OS
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
    to_path="${D_TO[$i]}"
    from_path="${D_FROM[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    to_md5="$( basename -- "$backup_path" )"

    # Check if previously installed
    if dstash has "$to_md5"; then

      # Previous copying is recorded
      
      # Check if destination exists
      if [ -e "$to_path" ]; then

        # Proper installation
        all_newly_installed=false
        all_failed=false

      else

        # Destination is missing
        all_already_installed=false

        # Re-copy and check status
        if cp -Rn -- "$from_path" "$to_path"; then

          # Successfully copied
          all_failed=false
          dprint_debug 'Fulfilled erroneous stash record of copying:' \
            -i "$from_path" -n 'to:' -i "$to_path"

        else

          # Failed to copy
          all_newly_installed=false
          some_failed=false
          dprint_debug 'Failed to copy from:' -i "$from_path" \
            -n 'to:' -i "$to_path" -n 'while fulfilling erroneous stash record'

        fi
      
      fi

    else

      # No previous copying recorded

      # Check if something already exists at destination path
      if [ -e "$to_path" ]; then

        # Check if something exists at backup path
        if [ -e "$backup_path" ]; then

          # Backup path is occupies: erase it
          if rm -rf -- "$backup_path"; then

            # Report event
            dprint_debug 'Clobbered unrecorded backup:' -i "$backup_path" \
              -n 'of destination path:' -i "$to_path"
            
          else

            # Failed to remove unrecorded backup: abandon this copying
            all_newly_installed=false
            all_already_installed=false
            some_failed=true
            dprint_debug 'Failed to clobber unrecorded backup:' \
              -i "$backup_path" -n 'of destination path:' -i "$to_path" \
              'Skipping this source/destination pair'
            continue
          
          fi

        fi

        # Move destination path to backup path and check status
        if mv -n -- "$to_path" "$backup_path"; then

          # Report event
          dprint_debug 'Backed up destination path:' -i "$to_path" \
            -n 'to:' -i "$backup_path"

        else

          # Failed to back up destination path: abandon this copying
          all_newly_installed=false
          all_already_installed=false
          some_failed=true
          dprint_debug 'Failed to back up destination path:' \
            -i "$to_path" -n 'to:' -i "$backup_path" \
            'Skipping this source/destination pair'
          continue

        fi

      fi

      # Copy source path to destination path and check status
      if cp -Rn -- "$from_path" "$to_path"; then

        # Successfully copied
        all_already_installed=false
        all_failed=false
        dstash set "$to_md5"

      else

        # Failed to copy
        all_newly_installed=false
        all_already_installed=false
        some_failed=false
        dprint_debug 'Failed to copy from:' -i "$from_path" \
          -n 'to:' -i "$to_path" -n 'while fulfilling erroneous stash record'

      fi

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
## Removes each path in $D_TO that has record of previous copying, then moves 
#. corresponding path in $D_BACKUPS to its original location
#
## Requires:
#.  $D_TO         - (array ok) Paths to be restored on current OS
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
  local all_newly_removed=true all_already_removed=true all_failed=true
  local some_failed=false
  local i
  local to_path from_path to_md5 backup_path

  # Iterate over pairs of paths in reverse order, just for kicks
  for (( i=$D_NUM_OF_PAIRS-1; i>=0; i-- )); do

    # Retrieve/construct three paths
    to_path="${D_TO[$i]}"
    from_path="${D_FROM[$i]}"
    backup_path="${D_BACKUPS[$i]}"
    to_md5="$( basename -- "$backup_path" )"

    # Check if previously installed
    if dstash has "$to_md5"; then

      # Previous copying is recorded
      
      # Check if destination exists
      if [ -e "$to_path" ]; then

        # Destination path exists
        all_already_removed=false

        # Proper installation: remove it and check status
        if rm -rf -- "$to_path"; then

          # Successfully removed

          # Check if backup is present
          if [ -e "$backup_path" ]; then

            # Move backup path to its original path and check status
            if mv -n -- "$backup_path" "$to_path"; then

              # Successfully restored backup
              all_failed=false
              dstash unset "$to_md5"

            else

              # Failed to restore backup
              all_newly_removed=false
              some_failed=true
              dprint_debug 'Failed to restore backup:' -i "$backup_path" \
                -n 'to cleared destination location at:' -i "$to_path"
            
            fi
              
          else

            # No backup to restore; successfully removed
            all_failed=false
            dstash unset "$to_md5"

          fi

        else

          # Failed to remove
          all_newly_removed=false
          some_failed=true
          dprint_debug 'Failed to remove path at:' -i "$to_path" \
            'which is previously copied from:' -i "$from_path"

        fi

      else

        # Destination is missing
        all_newly_removed=false
        dprint_debug 'Despite record of copying'

        # Check if backup is present
        if [ -e "$backup_path" ]; then

          # Move backup path to its original path and check status
          if mv -n -- "$backup_path" "$to_path"; then

            # Successfully restored backup
            all_failed=false
            dstash unset "$to_md5"
            dprint_debug 'Removed erroneous stash record of copying:' \
              -i "$from_path" -n 'to:' -i "$to_path" \
              -n 'and restored backup from:' -i "$backup_path"

          else

            # Failed to restore backup
            all_already_removed=false
            some_failed=true
            dprint_debug 'Failed to restore backup:' -i "$backup_path" \
              -n 'of erroneous stash record of copying:' \
              -i "$from_path" -n 'to:' -i "$to_path"
          
          fi
            
        else

          # No backup to restore; already removed: erase erroneous stash record
          all_failed=false
          dstash unset "$to_md5"
          dprint_debug 'Removed erroneous stash record of copying:' \
            -i "$from_path" -n 'to:' -i "$to_path"

        fi

      fi

    else

      # No previous copying recorded

      # Don’t touch anything: no need to
      all_newly_removed=false
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