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

#>  __dln_hlp__dcheck
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
#.  `dos.utl.sh`
#.  `dln.utl.sh`
#
## Provides into the global scope:
#.  $D_DPL_TARGET_PATHS    - (array) Version after overrides for current OS
#.  $D_DPL_BACKUP_PATHS    - (array) Paths to where to put backups
#
## Returns:
#.  Values supported by dcheck function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__dln_hlp__dcheck()
{
  # Redirect functions
  __d__queue_hlp__pre_process()       { __dln_hlp__pre_process;       }
  __d__queue_hlp__item_is_installed() { __dln_hlp__item_is_installed; }

  # Delegate to helper
  __queue_hlp__dcheck
}

#>  __dln_hlp__dinstall
#
## Moves each target file in $D_DPL_TARGET_PATHS to its respective backup 
#. location in $D_DPL_BACKUP_PATHS; replaces each with a symlink pointing to 
#. respective replacement in $D_DPL_ASSET_PATHS.
#
## Requires:
#.  $D_DPL_ASSET_PATHS    - (array ok) Locations to symlink to
#.  $D_DPL_TARGET_PATHS   - (array ok) Paths to back up and replace
#.  $D_DPL_BACKUP_PATHS   - (array ok) Backup locations
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by dinstall function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
__dln_hlp__dinstall()
{
  # Redirect functions
  __d__queue_hlp__install_item()      { __dln_hlp__install_item;      }

  # Delegate to helper
  __queue_hlp__dinstall
}

#>  __dln_hlp__dremove
#
## Removes each path in $D_DPL_TARGET_PATHS that is a symlink pointing to 
#. respective replacement in $D_DPL_ASSET_PATHS. Where possible, restores 
#. original file from corresponding backup location in $D_DPL_BACKUP_PATHS.
#
## Requires:
#.  $D_DPL_ASSET_PATHS    - (array ok) Locations currently symlinked to
#.  $D_DPL_TARGET_PATHS   - (array ok) Paths to be restored
#.  $D_DPL_BACKUP_PATHS   - (array ok) Backup locations
#.  `dln.utl.sh`
#
## Returns:
#.  Values supported by dremove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
__dln_hlp__dremove()
{
  # Redirect functions
  __d__queue_hlp__remove_item()       { __dln_hlp__remove_item;       }

  # Delegate to helper
  __queue_hlp__dremove
}

__dln_hlp__pre_process()
{
  # Override targets for current OS family, if that variable is non-empty
  __override_d_targets_for_family

  # Override targets for current OS distro, if that variable is non-empty
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

  # Check if $D_DPL_TARGET_PATHS still ended up empty
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

__dln_hlp__item_is_installed()
{
  # Storage variables
  local target_path="${D_DPL_TARGET_PATHS[$D_DPL_ITEM_NUM]}"
  local asset_path="${D_DPL_ASSET_PATHS[$D_DPL_ITEM_NUM]}"
  local backup_path="$D_DPL_BACKUPS_DIR/$D_DPL_ITEM_STASH_KEY"

  # Check if original and replacement paths are both not empty
  [ -n "$target_path" -a -n "$asset_path" ] || {
    dprint_debug "Skipped an unworkable asset: $D_DPL_ITEM_TITLE"
    return 3
  }

  # If replacement file/dir is not readable, skip it
  [ -r "$asset_path" ] || {
    dprint_debug "Skipped an unreadable asset at: $asset_path"
    return 3
  }

  # Check if replacement is installed
  if dln -?q -- "$asset_path" "$target_path" "$backup_path"; then

    # Replacement is installed with backup
    return 1

  else

    # Check if it’s just backup that is missing
    if dln -?q -- "$asset_path" "$target_path"; then

      # Replacement is installed without backup
      return 1

    else

      # Replacement is not installed

      # Check if backup path exists, which would be abnormal
      if [ -e "$backup_path" ]; then

        # Report abnormal configuration
        dprint_debug 'Despite lack of symlink from:' \
          "$target_path" -n "to: $asset_path" \
          -n "backup exists at: $backup_path" \
          -n '(Force remove to restore orphaned backups)'

      fi

      # Return appropriate status
      return 2

    fi

  fi
}

__dln_hlp__install_item()
{
  # Storage variables
  local target_path="${D_DPL_TARGET_PATHS[$D_DPL_ITEM_NUM]}"
  local asset_path="${D_DPL_ASSET_PATHS[$D_DPL_ITEM_NUM]}"
  local backup_path="$D_DPL_BACKUPS_DIR/$D_DPL_ITEM_STASH_KEY"

  # Attempt to install
  if dln -f -- "$asset_path" "$target_path" "$backup_path"; then

    # Return success
    return 0

  else

    # Report and return
    dprint_debug "Failed to replace path at: $target_path" \
      -n "with symlink to: $asset_path"
    return 1

  fi
}

__dln_hlp__remove_item()
{
  # Storage variables
  local target_path="${D_DPL_TARGET_PATHS[$D_DPL_ITEM_NUM]}"
  local asset_path="${D_DPL_ASSET_PATHS[$D_DPL_ITEM_NUM]}"
  local backup_path="$D_DPL_BACKUPS_DIR/$D_DPL_ITEM_STASH_KEY"

  # Check if replacement appears to be installed
  if dln -?q -- "$asset_path" "$target_path" "$backup_path"; then

    # Attempt to remove
    if dln -fr -- "$asset_path" "$target_path" "$backup_path"; then

      # Return success
      return 0

    else

      # Report and return failure
      dprint_debug "Failed to undo replacement of: $target_path" \
        -n "with symlink to: $asset_path" \
        -n "and restore backup from: $backup_path"
      return 1

    fi

  else

    # Check if it’s just backup that is missing
    if dln -?q -- "$asset_path" "$target_path"; then

      # Attempt to remove
      if dln -fr -- "$asset_path" "$target_path"; then

        # Return success
        return 0

      else

        # Report and return failure
        dprint_debug 'Failed to undo replacement of:' "$target_path" \
          -n 'with symlink to:' "$asset_path" -n '(no backup detected)'
        return 1

      fi

    fi

  fi

  # If got here and being forced, try to restore orphaned backup
  if $D_DPL_ITEM_IS_FORCED && [ -e "$backup_path" ]; then

    # Remove whatever sits on original location and check status
    if ! rm -rf -- "$target_path"; then

      # Report and return failure
      dprint_debug "Failed to clobber original path at: $target_path" \
        -n "while restoring backup from: $backup_path"
      return 1

    fi

    # Move backup path to original location, and check status
    if mv -n -- "$backup_path" "$target_path"; then

      # Report and return success
      dprint_debug "Restored orphaned backup from: $backup_path" \
        -n "to its original location at: $target_path"
      return 0
    
    else

      # Report and return failure
      dprint_debug "Failed to move orphaned backup from: $backup_path" \
        -n "to its original location at: $target_path"
      return 1

    fi
  
  fi

  # Otherwise, there is nothing to do with this item
  dprint_debug "Nothing to remove/restore for item: $D_DPL_ITEM_TITLE"
  return 0
}