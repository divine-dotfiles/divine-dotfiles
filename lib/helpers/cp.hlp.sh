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

#>  __cp_hlp__dcheck
#
## Checks whether every file in $D_DPL_TARGET_PATHS[_*] (single path or array 
#. thereof) is currently a copy of corresponding file in $D_DPL_ASSET_PATHS
#
## Returns appropriate status based on overall state of installation, prints 
#. warnings when warranted. If in doubt, prefers to prompt user on how to 
#. proceed.
#
## Requires:
#.  $D_DPL_ASSET_PATHS          - (array ok) Locations of replacement files
#.  $D_DPL_TARGET_PATHS         - (array ok) Locations of files to be replaced
#.  `dos.utl.sh`
#
## Provides into the global scope:
#.  $D_DPL_TARGET_PATHS   - (array) Version after overrides for current OS
#.  $D_DPL_BACKUP_PATHS   - (array) Paths to where to put backups
#
## Returns:
#.  Values supported by dcheck function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__cp_hlp__dcheck()
{
  # Redirect functions
  __d__queue_hlp__pre_process()       { __cp_hlp__pre_process;        }
  __d__queue_hlp__item_is_installed() { __cp_hlp__item_is_installed;  }

  # Delegate to helper
  __queue_hlp__dcheck
}

#>  __cp_hlp__dinstall
#
## Copies each file in $D_DPL_ASSET_PATHS to respective destination path in 
#. $D_DPL_TARGET_PATHS, moving pre-existing files to corresponging backup 
#. locations in $D_DPL_BACKUP_PATHS.
#
## Requires:
#.  $D_DPL_ASSET_PATHS    - (array ok) Source filepaths
#.  $D_DPL_TARGET_PATHS   - (array ok) Destination filepaths on current OS
#.  $D_DPL_BACKUP_PATHS   - (array ok) Backup locations
#
## Returns:
#.  Values supported by dinstall function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
__cp_hlp__dinstall()
{
  # Redirect functions
  __d__queue_hlp__install_item()      { __cp_hlp__install_item;       }

  # Delegate to helper
  __queue_hlp__dinstall
}

#>  __cp_hlp__dremove
#
## Removes each path in $D_DPL_TARGET_PATHS that has record of previous 
#. copying, then moves corresponding path in $D_DPL_BACKUP_PATHS to its 
#. original location
#
## Requires:
#.  $D_DPL_TARGET_PATHS    - (array ok) Paths to be restored on current OS
#.  $D_DPL_BACKUP_PATHS    - (array ok) Backup locations
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by dremove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
__cp_hlp__dremove()
{
  # Redirect functions
  __d__queue_hlp__remove_item()       { __cp_hlp__remove_item;        }

  # Delegate to helper
  __queue_hlp__dremove
}

__cp_hlp__pre_process()
{
  # Override targets for current OS family, if specific variable is non-empty
  __override_d_targets_for_family

  # Override targets for current OS distro, if specific variable is non-empty
  __override_d_targets_for_distro

  # If $D_DPL_TARGET_PATHS is thus far empty, try another trick
  if ! [ ${#D_DPL_TARGET_PATHS[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS" ] \
    && [ -n "$D_DPL_TARGET_DIR" ] \
    && [ ${#D_DPL_ASSET_RELPATHS[@]} -gt 0 ]
  then

    # Initialize $D_DPL_TARGET_PATHS to empty array
    D_DPL_TARGET_PATHS=()

    # Storage variable
    local relative_path

    # Iterate over relative asset paths
    for relative_path in "${D_DPL_ASSET_RELPATHS[@]}"; do

      # Construct path to target and add it
      D_DPL_TARGET_PATHS+=( "$D_DPL_TARGET_DIR/$relative_path" )

    done

  fi

  # Check if $D_DPL_TARGET_PATHS has still ended up empty
  if ! [ ${#D_DPL_TARGET_PATHS[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS" ]; then

    # Report and return failure
    local detected_os="$OS_FAMILY"
    [ -n "$OS_DISTRO" ] && detected_os+=" ($OS_DISTRO)"
    dprint_debug \
      'Empty list of paths to replace ($D_DPL_TARGET_PATHS) for detected OS:' \
      "$detected_os"
    return 1

  fi
}

__cp_hlp__item_is_installed()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D_DPL_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D_DPL_ITEM_NUM]}"
  local backup_path="$D_DPL_BACKUPS_DIR/$D_DPL_ITEM_STASH_KEY"

  # Check if source and destination paths are both not empty
  [ -n "$to_path" -a -n "$from_path" ] || {
    dprint_debug "Skipped an unworkable asset: $D_DPL_ITEM_TITLE" \
      -n "Source path: $from_path" \
      -n "Destination path: $to_path"
    return 3
  }

  # If source filepath is not readable, skip it
  [ -r "$from_path" ] || {
    dprint_debug "Skipped an unreadable asset at: $from_path"
    return 3
  }

  # Check if there is a copy at destination path
  if [ -e "$to_path" ]; then

    # Destination exists, so it is assumed to have been copied
    return 1
  
  else

    # Destination does not exist, so it is assumed to have not been copied
    
    # Check if backup path exists, which would be abnormal
    if [ -r "$backup_path" ]; then

      # Report abnormal configuration
      dprint_debug 'Despite lack of copy of original from:' \
        "$target_path" -n "to: $asset_path" \
        -n "backup exists at: $backup_path" \
        -n '(Force remove to restore orphaned backups)'

    fi

    # Return appropriate status
    return 2

  fi
}

__cp_hlp__install_item()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D_DPL_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D_DPL_ITEM_NUM]}"
  local backup_path="$D_DPL_BACKUPS_DIR/$D_DPL_ITEM_STASH_KEY"
  local to_parent_dir="$( dirname -- "$to_path" )"

  # Check if something already exists at destination path
  if [ -e "$to_path" ]; then

    # Check if something exists at backup path
    if [ -e "$backup_path" ]; then

      # Backup path is occupied: erase it
      if ! rm -rf -- "$backup_path"; then

        # Failed to clobber pre-existing backup: abandon this copying
        dprint_debug "Failed to clobber backup at: $backup_path" \
          -n "of destination path at: $to_path" \
          -n '(Skipping this source/destination pair)'
        return 1
      
      fi

    fi

    # Move destination path to backup path and check status
    if ! mv -n -- "$to_path" "$backup_path"; then

      # Failed to back up destination path: abandon this copying
      dprint_debug "Failed to back up destination path at: $to_path" \
        -n "to: $backup_path" \
        -n '(Skipping this source/destination pair)'
      return 1

    fi

  else

    # Nothing exists at destination path: ensure parent directory exists
    if ! [ -d "$to_parent_dir" ]; then

      # Locate existing parent directory
      local to_existing_parent_dir="$( dirname -- "$to_parent_dir" )"
      while [ ! -d "$to_existing_parent_dir" ]; do
        to_existing_parent_dir="$( dirname -- "$to_existing_parent_dir" )"
      done

      # Try to create destination directory
      if [ -w "$to_existing_parent_dir" ]; then
        mkdir -p -- "$to_parent_dir"
      else
        sudo mkdir -p -- "$to_parent_dir"
      fi

      # Check if directory has been created
      if [ $? -ne 0 ]; then

        # Failed to create destination parent dir: abandon this copying
        dprint_debug 'Failed to create destination parent directory:' \
          -i "$to_parent_dir" \
          -n '(Skipping this source/destination pair)'
        return 1

      fi

    fi

  fi

  # Copy source path to destination path and check status
  if [ -w "$to_parent_dir" ]; then
    cp -Rn -- "$from_path" "$to_path"
  else
    sudo cp -Rn -- "$from_path" "$to_path"
  fi

  # Check if copying is successful
  if [ $? -eq 0 ]; then

    # Return success
    return 0

  else

    # Report and return failure
    dprint_debug "Failed to copy from: $from_path" -n "to: $to_path"
    return 1

  fi
}

__cp_hlp__remove_item()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D_DPL_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D_DPL_ITEM_NUM]}"
  local backup_path="$D_DPL_BACKUPS_DIR/$D_DPL_ITEM_STASH_KEY"
  local to_parent_dir="$( dirname -- "$to_path" )"

  # Ensure destination parent directory exists
  if ! [ -d "$to_parent_dir" ]; then

    # Locate existing parent directory
    local to_existing_parent_dir="$( dirname -- "$to_parent_dir" )"
    while [ ! -d "$to_existing_parent_dir" ]; do
      to_existing_parent_dir="$( dirname -- "$to_existing_parent_dir" )"
    done

    # Try to create destination directory
    if [ -w "$to_existing_parent_dir" ]; then
      mkdir -p -- "$to_parent_dir"
    else
      sudo mkdir -p -- "$to_parent_dir"
    fi

    # Check if directory has been created
    if [ $? -ne 0 ]; then

      # Failed to create destination parent dir: abandon this copying
      dprint_debug 'Failed to create destination parent directory:' \
        -i "$to_parent_dir" \
        -n '(Skipping this source/destination pair)'
      return 1

    fi

  fi

  # Check if destination path exists
  if [ -e "$to_path" ]; then

    # Remove destination path and check status
    if [ -w "$to_parent_dir" ]; then
      rm -rf -- "$to_path"
    else
      sudo rm -rf -- "$to_path"
    fi

    # Check status
    if [ $? -ne 0 ]; then

      # Report and return failure
      dprint_debug "Failed to erase destination path: $to_path" \
        -n "that corresponds to source path: $from_path"
      return 1

    fi

  fi

  # Check if backup is present
  if [ -e "$backup_path" ]; then

    # Move backup path to its original path and check status
    if [ -w "$to_parent_dir" ]; then
      mv -n -- "$backup_path" "$to_path"
    else
      sudo mv -n -- "$backup_path" "$to_path"
    fi

    # Check status
    if [ $? -ne 0 ]; then

      # Report and return failure
      dprint_debug "Failed to move backup: $backup_path" \
        -n "to its original location at: $to_path"
      return 1
    
    fi

  fi

  # Otherwise, return success
  return 0
}