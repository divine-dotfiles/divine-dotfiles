#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: copy-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    5
#:revdate:      2019.08.07
#:revremark:    Grand removal of non-ASCII chars
#:created_at:   2019.05.23

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'copy-queue.dpl.sh'
#
## Copies arbitrary files (e.g., font files) to provided locations (e.g., into 
#. OS's fonts directory). Creates backup of each replaced file. Restores 
#. original set-up on removal.
#

#>  d__copy_queue_check
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
#
## Provides into the global scope:
#.  $D_DPL_TARGET_PATHS   - (array) Version after overrides for current OS
#
## Returns:
#.  Values supported by d_dpl_check function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
d__copy_queue_check()
{
  # Redirect pre-processing
  d_queue_pre_process()
  {
    # Redirect to built-in helper
    d__copy_queue_pre_process
    
    # Try user-provided helper
    if declare -f d_copy_queue_pre_process &>/dev/null; then
      d_copy_queue_pre_process || return 1
    fi
  }

  # Redirect item check to built-in helper
  d_queue_item_is_installed() { d__copy_queue_item_is_installed;  }

  # Redirect post-processing
  d_queue_post_process()
  {
    # Try user-provided helper
    if declare -f d_copy_queue_post_process &>/dev/null; then
      d_copy_queue_post_process
    else
      :
    fi
  }

  # Delegate to helper
  d__queue_check
}

#>  d__copy_queue_install
#
## Copies each file in $D_DPL_ASSET_PATHS to respective destination path in 
#. $D_DPL_TARGET_PATHS, moving pre-existing files to corresponging backup 
#. locations.
#
## Requires:
#.  $D_DPL_ASSET_PATHS    - (array ok) Source filepaths
#.  $D_DPL_TARGET_PATHS   - (array ok) Destination filepaths on current OS
#
## Returns:
#.  Values supported by d_dpl_install function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
d__copy_queue_install()
{
  # Redirect installation with optional pre-processing
  d_queue_item_install()
  {
    # Try user-provided helper
    if declare -f d_copy_queue_item_pre_install &>/dev/null \
      && ! d_copy_queue_item_pre_install
    then
      dprint_debug 'Pre-installation signaled error'
      return 2
    fi

    # Redirect to built-in helper
    d__copy_queue_item_install
  }

  # Delegate to helper
  d__queue_install
}

#>  d__copy_queue_remove
#
## Removes each path in $D_DPL_TARGET_PATHS that has record of previous 
#. copying, then moves corresponding backup path to its original location
#
## Requires:
#.  $D_DPL_TARGET_PATHS    - (array ok) Paths to be restored on current OS
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by d_dpl_remove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
d__copy_queue_remove()
{
  # Redirect removal with optional pre-processing
  d_queue_item_remove()
  {
    # Try user-provided helper
    if declare -f d_copy_queue_item_pre_remove &>/dev/null \
      && ! d_copy_queue_item_pre_remove
    then
      dprint_debug 'Pre-removal signaled error'
      return 2
    fi

    # Redirect to built-in helper
    d__copy_queue_item_remove
  }

  # Delegate to helper
  d__queue_remove
}

d__copy_queue_pre_process()
{
  # Override targets for current OS family, if specific variable is non-empty
  d__adapter_override_dpl_targets_for_os_family

  # Override targets for current OS distro, if specific variable is non-empty
  d__adapter_override_dpl_targets_for_os_distro

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
    local detected_os="$D__OS_FAMILY"
    [ -n "$D__OS_DISTRO" ] && detected_os+=" ($D__OS_DISTRO)"
    dprint_debug \
      'Empty list of paths to replace ($D_DPL_TARGET_PATHS) for detected OS:' \
      "$detected_os"
    return 1

  fi

  # Return
  return 0
}

d__copy_queue_item_is_installed()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"

  # Check if source and destination paths are both not empty
  [ -n "$to_path" -a -n "$from_path" ] || {

    # Compose debug output
    local output
    if [ -z "$from_path" ]; then
      if [ -z "$to_path" ]; then
        output='empty paths for source and destination'
      else
        output='empty source path'
      fi
    else
      if [ -z "$to_path" ]; then
        output='empty destination path'
      else
        :
      fi
    fi

    # Report and return
    dprint_debug "$D__QUEUE_ITEM_TITLE: $output"
    return 3

  }

  # If source filepath is not readable, skip it
  [ -r "$from_path" ] || {
    dprint_debug "Unreadable source at: $from_path"
    return 3
  }

  # Check if there is a copy at destination path
  if [ -e "$to_path" ]; then

    # Destination exists, so it is assumed installed
    return 1
  
  else

    # Destination does not exist, so it is assumed not installed
    
    # Check if backup path exists, which would be abnormal
    if [ -e "$backup_path" ]; then

      # Report abnormal configuration
      dprint_debug "Orphaned backup: $backup_path" \
        -n "of target path: $to_path"
        -n "(force-remove to restore)"

    fi

    # Return appropriate status
    return 2

  fi
}

d__copy_queue_item_install()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"
  local to_parent_dir="$( dirname -- "$to_path" )"

  # Check if something already exists at destination path
  if [ -e "$to_path" ]; then

    # Check if something exists at backup path
    if [ -e "$backup_path" ]; then

      # Backup path is occupied: erase it
      if ! rm -rf -- "$backup_path"; then

        # Failed to clobber pre-existing backup: abandon this copying
        dprint_debug 'Error on clobbering path:' \
          -n "$backup_path" -n "while removing old backup"
        return 1
      
      fi

    fi

    # Move destination path to backup path and check status
    if ! mv -n -- "$to_path" "$backup_path"; then

      # Failed to back up destination path: abandon this copying
      dprint_debug 'Error on moving pre-existing target' \
        -n "from: $to_path" -n "to: $backup_path"
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
        if ! sudo -n true 2>/dev/null; then
          dprint_start -l 'Creating directory within:' \
            -i "$to_existing_parent_dir" -n 'requires sudo password'
        fi
        sudo mkdir -p -- "$to_parent_dir"
      fi

      # Check if directory has been created
      if [ $? -ne 0 ]; then

        # Failed to create destination parent dir: abandon this copying
        dprint_debug 'Error on creating parent destination directory:' \
          -i "$to_parent_dir"
        return 1

      fi

    fi

  fi

  # Copy source path to destination path and check status
  if [ -w "$to_parent_dir" ]; then
    cp -Rn -- "$from_path" "$to_path"
  else
    if ! sudo -n true 2>/dev/null; then
      dprint_start -l 'Copying into:' -i "$to_parent_dir" \
        -n 'requires sudo password'
    fi
    sudo cp -Rn -- "$from_path" "$to_path"
  fi

  # Check if copying is successful
  if [ $? -eq 0 ]; then

    # Return success
    return 0

  else

    # Report and return failure
    dprint_debug 'Error on copying asset' \
      -n "from: $from_path" -n "to: $to_path"
    return 1

  fi
}

d__copy_queue_item_remove()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"
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
      if ! sudo -n true 2>/dev/null; then
        dprint_start -l 'Creating directory within:' \
            -i "$to_existing_parent_dir" -n 'requires sudo password'
      fi
      sudo mkdir -p -- "$to_parent_dir"
    fi

    # Check if directory has been created
    if [ $? -ne 0 ]; then

      # Failed to create destination parent dir: abandon this copying
      dprint_debug 'Error on creating parent destination directory:' \
        -i "$to_parent_dir"
      return 1

    fi

  fi

  # Check if destination path exists
  if [ -e "$to_path" ]; then

    # Remove destination path and check status
    if [ -w "$to_parent_dir" ]; then
      rm -rf -- "$to_path"
    else
      if ! sudo -n true 2>/dev/null; then
        dprint_start -l 'Removing within:' \
          -i "$to_parent_dir" -n 'requires sudo password'
      fi
      sudo rm -rf -- "$to_path"
    fi

    # Check status
    if [ $? -ne 0 ]; then

      # Report and return failure
      dprint_debug 'Error on clobbering destination path:' \
        -n "$to_path"
      return 1

    fi

  fi

  # Check if backup is present
  if [ -e "$backup_path" ]; then

    # Move backup path to its original path and check status
    if [ -w "$to_parent_dir" ]; then
      mv -n -- "$backup_path" "$to_path"
    else
      if ! sudo -n true 2>/dev/null; then
        dprint_start -l 'Moving into:' \
          -i "$to_parent_dir" -n 'requires sudo password'
      fi
      sudo mv -n -- "$backup_path" "$to_path"
    fi

    # Check status
    if [ $? -ne 0 ]; then

      # Report and return failure
      dprint_debug 'Error on moving backup' \
        -n "from: $backup_path" -n "to: $to_path"
      return 1
    
    fi

  fi

  # Otherwise, return success
  return 0
}