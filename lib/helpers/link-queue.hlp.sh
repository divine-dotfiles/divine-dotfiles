#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: link-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    7
#:revdate:      2019.08.20
#:revremark:    Delay populating  as much as possible
#:created_at:   2019.04.02

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'link-queue.dpl.sh'
#
## Replaces arbitrary files (e.g., config files) with symlinks to provided 
#. replacements. Creates backup of each replaced file. Restores original set-up 
#. on removal.
#

#>  d__link_queue_check
#
## Checks whether every original file in $D_DPL_TARGET_PATHS[_*] (single path 
#. or array thereof) is currently replaced with a symlink pointing to 
#. corresponding replacement in $D_DPL_ASSET_PATHS.
#
## Returns appropriate status based on overall state of installation, prints 
#. warnings when warranted. If in doubt, prefers to prompt user on how to 
#. proceed.
#
## Requires:
#.  $D_DPL_ASSET_PATHS          - (array ok) Locations of replacement files
#.  $D_DPL_TARGET_PATHS         - (array ok) Locations of files to be replaced
#.  `dln.utl.sh`
#
## Provides into the global scope:
#.  $D_DPL_TARGET_PATHS    - (array) Version after overrides for current OS
#
## Returns:
#.  Values supported by d_dpl_check function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
d__link_queue_check()
{
  # Redirect pre-processing
  d_queue_pre_process()
  {
    # Redirect to built-in helper
    d__link_queue_pre_process

    # Try user-provided helper
    if declare -f d_link_queue_pre_process &>/dev/null; then
      d_link_queue_pre_process || return 1
    fi
  }

  # Redirect item check to built-in helper
  d_queue_item_check() { d__link_queue_item_is_installed; }

  # Redirect post-processing
  d_queue_post_process()
  {
    # Try user-provided helper
    if declare -f d_link_queue_post_process &>/dev/null; then
      d_link_queue_post_process
    else
      :
    fi
  }

  # Delegate to helper
  d__queue_check
}

#>  d__link_queue_install
#
## Moves each target file in $D_DPL_TARGET_PATHS to its respective backup 
#. location; replaces each with a symlink pointing to respective replacement in 
#. $D_DPL_ASSET_PATHS.
#
## Requires:
#.  $D_DPL_ASSET_PATHS    - (array ok) Locations to symlink to
#.  $D_DPL_TARGET_PATHS   - (array ok) Paths to back up and replace
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by d_dpl_install function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
d__link_queue_install()
{
  # Redirect installation with optional pre-processing
  d_queue_item_install()
  {
    # Try user-provided helper
    if declare -f d_link_queue_item_pre_install &>/dev/null \
      && ! d_link_queue_item_pre_install
    then
      dprint_debug 'Pre-installation signaled error'
      return 2
    fi

    # Redirect to built-in helper
    d__link_queue_item_install
  }

  # Delegate to helper
  d__queue_install
}

#>  d__link_queue_remove
#
## Removes each path in $D_DPL_TARGET_PATHS that is a symlink pointing to 
#. respective replacement in $D_DPL_ASSET_PATHS. Where possible, restores 
#. original file from corresponding backup location.
#
## Requires:
#.  $D_DPL_ASSET_PATHS    - (array ok) Locations currently symlinked to
#.  $D_DPL_TARGET_PATHS   - (array ok) Paths to be restored
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by d_dpl_remove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
d__link_queue_remove()
{
  # Redirect removal with optional pre-processing
  d_queue_item_remove()
  {
    # Try user-provided helper
    if declare -f d_link_queue_item_pre_remove &>/dev/null \
      && ! d_link_queue_item_pre_remove
    then
      dprint_debug 'Pre-removal signaled error'
      return 2
    fi

    # Redirect to built-in helper
    d__link_queue_item_remove
  }

  # Delegate to helper
  d__queue_remove
}

d__link_queue_pre_process()
{
  # Override targets for current OS family, if that variable is non-empty
  d__adapter_override_dpl_targets_for_os_family

  # Override targets for current OS distro, if that variable is non-empty
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

  # Check if $D_DPL_TARGET_PATHS still ended up empty
  if ! [ ${#D_DPL_TARGET_PATHS[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS" ]; then

    # Report and return failure
    local detected_os="$D__OS_FAMILY"
    [ -n "$D__OS_DISTRO" ] && detected_os+=" ($D__OS_DISTRO)"
    dprint_debug \
      'Empty list of paths to replace ($D_DPL_TARGET_PATHS) for detected OS:' \
      "$detected_os"
    return 1
    
  fi

  # Check if $D_QUEUE_MAIN is populated
  if ! [ ${#D_QUEUE_MAIN[@]} -gt 1 -o -n "$D_QUEUE_MAIN" ]; then

    # Main queue is still empty

    # Try to derive main queue from relative asset paths
    if [ ${#D_DPL_ASSET_RELPATHS[@]} -gt 1 -o -n "$D_DPL_ASSET_RELPATHS" ]; then

      D_QUEUE_MAIN=( "${D_DPL_ASSET_RELPATHS[@]}" )

    # Otherwise, try to derive main queue from absolute asset paths
    elif [ ${#D_DPL_ASSET_PATHS[@]} -gt 1 -o -n "$D_DPL_ASSET_PATHS" ]; then

      D_QUEUE_MAIN=( "${D_DPL_ASSET_PATHS[@]}" )

    fi

  fi

  # Return
  return 0
}

d__link_queue_item_is_installed()
{
  # Storage variables
  local target_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local asset_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"

  # Check if original and replacement paths are both not empty
  [ -n "$target_path" -a -n "$asset_path" ] || {

    # Compose debug output
    local output
    if [ -z "$target_path" ]; then
      if [ -z "$asset_path" ]; then
        output='empty paths for asset and target'
      else
        output='empty target path'
      fi
    else
      if [ -z "$asset_path" ]; then
        output='empty asset path'
      else
        :
      fi
    fi

    # Report and return
    dprint_debug "$D__QUEUE_ITEM_TITLE: $output"
    return 3
    
  }

  # If replacement file/dir is not readable, skip it
  [ -r "$asset_path" ] || {
    dprint_debug "Unreadable asset at: $asset_path"
    return 3
  }

  # Check if replacement is installed
  if dln -?q -- "$asset_path" "$target_path" "$backup_path"; then

    # Replacement is installed with backup
    # dprint_debug "Backup stored at: $backup_path"
    return 1

  else

    # Check if it's just backup that is missing
    if dln -?q -- "$asset_path" "$target_path"; then

      # Replacement is installed without backup
      return 1

    else

      # Replacement is not installed

      # Check if backup path exists, which would be abnormal
      if [ -e "$backup_path" ]; then

        # Report not installed with orphaned backup
        dprint_debug "Orphaned backup: $backup_path" \
          -n "of target path: $target_path" \
          -n "(force-remove to restore)"
        
      fi

      # Return appropriate status
      return 2

    fi

  fi
}

d__link_queue_item_install()
{
  # Storage variables
  local target_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local asset_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"

  # Attempt to install
  if dln -f -- "$asset_path" "$target_path" "$backup_path"; then

    # Return success
    return 0

  else

    # Report and return
    dprint_debug 'Error on creating symlink' \
      -n "from: $target_path" -n "to: $asset_path" \
      -n 'and backing up to:' -i "$backup_path"
    return 1

  fi
}

d__link_queue_item_remove()
{
  # Storage variables
  local target_path="${D_DPL_TARGET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local asset_path="${D_DPL_ASSET_PATHS[$D__QUEUE_ITEM_NUM]}"
  local backup_path="$D__DPL_BACKUP_DIR/$D__QUEUE_ITEM_STASH_KEY"

  # Check if replacement appears to be installed
  if dln -?q -- "$asset_path" "$target_path" "$backup_path"; then

    # Attempt to remove
    if dln -fr -- "$asset_path" "$target_path" "$backup_path"; then

      # Return success
      # dprint_debug "Backup restored to: $target_path"
      return 0

    else

      # Report and return failure
      dprint_debug 'Error on removing symlink' \
          -n "from: $target_path" -n "to: $asset_path" \
          -n 'and restoring backup from:' -i "$backup_path"
      return 1

    fi

  else

    # Check if it's just backup that is missing
    if dln -?q -- "$asset_path" "$target_path"; then

      # Attempt to remove
      if dln -fr -- "$asset_path" "$target_path"; then

        # Return success
        return 0

      else

        # Report and return failure
        dprint_debug 'Error on removing symlink' \
          -n "from: $target_path" -n "to: $asset_path"
        return 1

      fi

    fi

  fi

  # If got here and being forced, try to restore orphaned backup
  if $D__QUEUE_ITEM_IS_FORCED && [ -e "$backup_path" ]; then

    # Remove whatever sits on original location and check status
    if ! rm -rf -- "$target_path"; then

      # Report and return failure
      dprint_debug 'Error on clobbering path:' \
        -n "$target_path" -n "while restoring orphaned backup"
      return 1

    fi

    # Move backup path to original location, and check status
    if mv -n -- "$backup_path" "$target_path"; then

      # Report and return success
      dprint_debug "Restored orphaned backup to: $target_path"
      return 0
    
    else

      # Report and return failure
      dprint_debug 'Error on moving orphaned backup' \
        -n "from: $backup_path" -n "to: $backup_path"
      return 1

    fi
  
  fi

  # Otherwise, there is nothing to do with this item
  dprint_debug "$D__QUEUE_ITEM_TITLE: Nothing to remove/restore"
  return 0
}