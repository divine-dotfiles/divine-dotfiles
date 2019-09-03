#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: copy-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    16
#:revdate:      2019.09.03
#:revremark:    Modify stashing pattern
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
  d_queue_pre_check() { d__copy_queue_pre_check; }

  # Redirect item check
  d_queue_item_check() { d__copy_queue_item_check; }

  # Redirect post-processing
  d_queue_post_check() { d__copy_queue_post_check; }

  # Delegate to built-in helper
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
  # Redirect pre-processing
  d_queue_pre_install() { d__copy_queue_pre_install; }

  # Redirect item install
  d_queue_item_install() { d__copy_queue_item_install; }

  # Redirect post-processing
  d_queue_post_install() { d__copy_queue_post_install; }

  # Delegate to built-in helper
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
  # Redirect pre-processing
  d_queue_pre_remove() { d__copy_queue_pre_remove; }

  # Redirect item remove
  d_queue_item_remove() { d__copy_queue_item_remove; }

  # Redirect post-processing
  d_queue_post_remove() { d__copy_queue_post_remove; }

  # Delegate to built-in helper
  d__queue_remove
}

d__copy_queue_pre_check()
{
  # Override targets for current OS family, if specific variable is non-empty
  d__adapter_override_dpl_targets_for_os_family

  # Override targets for current OS distro, if specific variable is non-empty
  d__adapter_override_dpl_targets_for_os_distro

  # Check if section of target paths is thus far empty
  if [ ${#D_DPL_TARGET_PATHS[@]} -eq "$D__QUEUE_SECTMIN" ]; then
  
    # Check if there is a target dir and enough relative paths
    if [ -n "$D_DPL_TARGET_DIR" ] \
      && [ ${#D_QUEUE_MAIN[@]} -ge "$D__QUEUE_SECTMAX" ]
    then

      # Interpret $D_QUEUE_MAIN as relative paths

      # Storage variable
      local i relative_path

      for (( i=$D__QUEUE_SECTMIN; i<$D__QUEUE_SECTMAX; i++ )); do

        # Construct path to target and add it
        D_DPL_TARGET_PATHS+=( "$D_DPL_TARGET_DIR/${D_QUEUE_MAIN[$i]}" )

      done

    else

      # Still no target paths

      # Report and return failure
      local detected_os="$D__OS_FAMILY"
      if [ -n "$D__OS_DISTRO" -a "$D__OS_DISTRO" != "$D__OS_FAMILY" ]; then
        detected_os+=" ($D__OS_DISTRO)"
      fi
      dprint_debug \
        'Empty list of target paths ($D_DPL_TARGET_PATHS) for detected OS:' \
        "$detected_os"
      return 1
    
    fi

  fi

  # Check if queue pre-processing hook is implemented
  if declare -f d_copy_queue_pre_check &>/dev/null; then
    
    # Storage variable
    local return_code_hook

    # Launch pre-processing hook, store return code
    d_copy_queue_pre_check; return_code_hook=$?

    # Unset the hook to prevent it from polluting other queues
    unset -f d_copy_queue_pre_check

    # If returned code is non-zero, re-return it
    [ $return_code_hook -ne 0 ] && return $return_code_hook

  fi

  # Implement generic queue item pre-check, to use particular stash key
  d_queue_item_pre_check()
  {
    D__QUEUE_ITEM_STASH_KEY="copy_$( \
      dmd5 -s "${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}" \
    )"
  }

  # If queue item pre-processing hook is not implemented, implement dummy
  if ! declare -f d_copy_queue_item_pre_check &>/dev/null; then
    d_copy_queue_item_pre_check() { :; }
  fi

  # If queue item post-processing hook is not implemented, implement dummy
  if ! declare -f d_copy_queue_item_post_check &>/dev/null; then
    d_copy_queue_item_post_check() { :; }
  fi

  # Return
  return 0
}

d__copy_queue_item_check()
{
  # Storage variables
  local return_code_main return_code_hook

  # Launch pre-processing hook, store return code
  d_copy_queue_item_pre_check; return_code_hook=$?

  # Check if returned code is non-zero
  if [ $return_code_hook -ne 0 ]; then
  
    # Anounce and re-return the non-zero code
    dprint_debug "Pre-check hook forces return code $return_code_hook" \
      -n "on item '$D__QUEUE_ITEM_TITLE'"
    return $return_code_hook

  fi

  # Run item check and catch return code
  d__copy_queue_item_check_subroutine; return_code_main=$?
 
  # Launch post-processing hook, store return code
  D__QUEUE_ITEM_RETURN_CODE=$return_code_main
  d_copy_queue_item_post_check; return_code_hook=$?
  unset D__QUEUE_ITEM_RETURN_CODE

  # Check if returned code is non-zero
  if [ $return_code_hook -ne 0 ]; then
  
    # Anounce and re-return the non-zero code
    dprint_debug "Post-check hook forces return code $return_code_hook" \
      -n "on item '$D__QUEUE_ITEM_TITLE'"
    return $return_code_hook

  fi

  # Return
  return $return_code_main
}

d__copy_queue_item_check_subroutine()
{
  # Storage variables
  local to_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local from_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"

  # Check if source or destination paths is empty
  if ! [ -n "$to_path" -a -n "$from_path" ]; then

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

    # Report and store return code
    dprint_debug "$D__QUEUE_ITEM_TITLE: $output"
    return 3

  # Check if source filepath is not readable
  elif ! [ -r "$from_path" ]; then

    # Report and store return code
    dprint_debug "Unreadable source at: $from_path"
    return 3

  else

    # Source and destination paths are both not empty

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

  fi
}

d__copy_queue_post_check()
{
  # Unset item hooks to prevent them from polluting other queues
  unset -f d_copy_queue_item_pre_check d_copy_queue_item_post_check

  # Check if queue post-processing hook is implemented
  if declare -f d_copy_queue_post_check &>/dev/null; then
    
    # Storage variable
    local return_code_hook

    # Launch post-processing hook, store return code
    d_copy_queue_post_check; return_code_hook=$?

    # Unset the hook to prevent it from polluting other queues
    unset -f d_copy_queue_post_check

    # If returned code is non-zero, re-return it
    [ $return_code_hook -ne 0 ] && return $return_code_hook

  fi

  # Otherwise, return zero
  return 0
}

d__copy_queue_pre_install()
{
  # Check if queue pre-processing hook is implemented
  if declare -f d_copy_queue_pre_install &>/dev/null; then
    
    # Storage variable
    local return_code_hook

    # Launch pre-processing hook, store return code
    d_copy_queue_pre_install; return_code_hook=$?

    # Unset the hook to prevent it from polluting other queues
    unset -f d_copy_queue_pre_install

    # If returned code is non-zero, re-return it
    [ $return_code_hook -ne 0 ] && return $return_code_hook

  fi

  # If queue item pre-processing hook is not implemented, implement dummy
  if ! declare -f d_copy_queue_item_pre_install &>/dev/null; then
    d_copy_queue_item_pre_install() { :; }
  fi

  # If queue item post-processing hook is not implemented, implement dummy
  if ! declare -f d_copy_queue_item_post_install &>/dev/null; then
    d_copy_queue_item_post_install() { :; }
  fi

  # Return
  return 0
}

d__copy_queue_item_install()
{
  # Storage variables
  local return_code_main return_code_hook

  # Launch pre-processing hook, store return code
  d_copy_queue_item_pre_install; return_code_hook=$?

  # Check if returned code is non-zero
  if [ $return_code_hook -ne 0 ]; then
  
    # Anounce and re-return the non-zero code
    dprint_debug "Pre-install hook forces return code $return_code_hook" \
      -n "on item '$D__QUEUE_ITEM_TITLE'"
    return $return_code_hook

  fi

  # Run item installation and catch return code
  d__copy_queue_item_install_subroutine; return_code_main=$?

  # Launch post-processing hook, store return code
  D__QUEUE_ITEM_RETURN_CODE=$return_code_main
  d_copy_queue_item_post_install; return_code_hook=$?
  unset D__QUEUE_ITEM_RETURN_CODE

  # Check if returned code is non-zero
  if [ $return_code_hook -ne 0 ]; then
  
    # Anounce and re-return the non-zero code
    dprint_debug "Post-install hook forces return code $return_code_hook" \
      -n "on item '$D__QUEUE_ITEM_TITLE'"
    return $return_code_hook

  fi

  # Return
  return $return_code_main
}

d__copy_queue_item_install_subroutine()
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
    if ! mv -n -- "$to_path" "$backup_path" &>/dev/null; then

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
          dprint_alert 'Creating directory within:' \
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
      dprint_alert 'Copying into:' -i "$to_parent_dir" \
        -n 'requires sudo password'
    fi
    sudo cp -Rn -- "$from_path" "$to_path"
  fi

  # Check if copying is successful
  if [ $? -eq 0 ]; then

    # Stash path to the destination
    D__QUEUE_ITEM_STASH_VALUE="$to_path"

    # Return success
    return 0

  else

    # Report and return failure
    dprint_debug 'Error on copying asset' \
      -n "from: $from_path" -n "to: $to_path"
    return 1

  fi
}

d__copy_queue_post_install()
{
  # Unset item hooks to prevent them from polluting other queues
  unset -f d_copy_queue_item_pre_install d_copy_queue_item_post_install

  # Check if queue post-processing hook is implemented
  if declare -f d_copy_queue_post_install &>/dev/null; then
    
    # Storage variable
    local return_code_hook

    # Launch post-processing hook, store return code
    d_copy_queue_post_install; return_code_hook=$?

    # Unset the hook to prevent it from polluting other queues
    unset -f d_copy_queue_post_install

    # If returned code is non-zero, re-return it
    [ $return_code_hook -ne 0 ] && return $return_code_hook

  fi

  # Otherwise, return zero
  return 0
}

d__copy_queue_pre_remove()
{
  # Check if queue pre-processing hook is implemented
  if declare -f d_copy_queue_pre_remove &>/dev/null; then
    
    # Storage variable
    local return_code_hook

    # Launch pre-processing hook, store return code
    d_copy_queue_pre_remove; return_code_hook=$?

    # Unset the hook to prevent it from polluting other queues
    unset -f d_copy_queue_pre_remove

    # If returned code is non-zero, re-return it
    [ $return_code_hook -ne 0 ] && return $return_code_hook

  fi

  # If queue item pre-processing hook is not implemented, implement dummy
  if ! declare -f d_copy_queue_item_pre_remove &>/dev/null; then
    d_copy_queue_item_pre_remove() { :; }
  fi

  # If queue item post-processing hook is not implemented, implement dummy
  if ! declare -f d_copy_queue_item_post_remove &>/dev/null; then
    d_copy_queue_item_post_remove() { :; }
  fi

  # Return
  return 0
}

d__copy_queue_item_remove()
{
  # Storage variables
  local return_code_main return_code_hook

  # Launch pre-processing hook, store return code
  d_copy_queue_item_pre_remove; return_code_hook=$?

  # Check if returned code is non-zero
  if [ $return_code_hook -ne 0 ]; then
  
    # Anounce and re-return the non-zero code
    dprint_debug "Pre-remove hook forces return code $return_code_hook" \
      -n "on item '$D__QUEUE_ITEM_TITLE'"
    return $return_code_hook

  fi

  # Run item removal and catch return code
  d__copy_queue_item_remove_subroutine; return_code_main=$?

  # Launch post-processing hook, store return code
  D__QUEUE_ITEM_RETURN_CODE=$return_code_main
  d_copy_queue_item_post_remove; return_code_hook=$?
  unset D__QUEUE_ITEM_RETURN_CODE

  # Check if returned code is non-zero
  if [ $return_code_hook -ne 0 ]; then
  
    # Anounce and re-return the non-zero code
    dprint_debug "Post-remove hook forces return code $return_code_hook" \
      -n "on item '$D__QUEUE_ITEM_TITLE'"
    return $return_code_hook

  fi

  # Return
  return $return_code_main
}

d__copy_queue_item_remove_subroutine()
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
        dprint_alert 'Creating directory within:' \
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
        dprint_alert 'Removing within:' \
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
      mv -n -- "$backup_path" "$to_path" &>/dev/null
    else
      if ! sudo -n true 2>/dev/null; then
        dprint_alert 'Moving into:' \
          -i "$to_parent_dir" -n 'requires sudo password'
      fi
      sudo mv -n -- "$backup_path" "$to_path" &>/dev/null
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

d__copy_queue_post_remove()
{
  # Unset item hooks to prevent them from polluting other queues
  unset -f d_copy_queue_item_pre_remove d_copy_queue_item_post_remove

  # Check if queue post-processing hook is implemented
  if declare -f d_copy_queue_post_remove &>/dev/null; then
    
    # Storage variable
    local return_code_hook

    # Launch post-processing hook, store return code
    d_copy_queue_post_remove; return_code_hook=$?

    # Unset the hook to prevent it from polluting other queues
    unset -f d_copy_queue_post_remove

    # If returned code is non-zero, re-return it
    [ $return_code_hook -ne 0 ] && return $return_code_hook

  fi

  # Otherwise, return zero
  return 0
}