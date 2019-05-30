#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: assets
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.30
#:revremark:    Initial revision
#:created_at:   2019.05.30

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function that prepares deployment’s assets
#

#>  __prepare_dpl_assets
#
## Copies initial versions of deployment’s assets (as listed in $D_DPL_ASSETS) 
#. to deployments assets directory. Assets directory is then worked with and 
#. can be taken under version control. Does not overwrite anything (user’s data 
#. takes priority).
#
## Requires:
#.  $D_DPL_ASSETS   - Relative path or array of relative paths. Each path is 
#.                    resolved relative to $D_DPL_DIR and copied to path 
#.                    resolved relative to $D_DPL_ASSETS_DIR.
#
## Returns:
#.  0 - Task performed
#.  1 - All assets exist in assets directory
#
__prepare_dpl_assets()
{
  # Check if $D_DPL_ASSETS has at least one entry
  [ ${#D_DPL_ASSETS[@]} -gt 1 -o -n "$D_DPL_ASSETS" ] || return 0

  # Storage and status variables
  local relative_path src_path dest_path dest_parent_path
  local all_assets_readable=true all_assets_copied=true

  # Iterate over $D_DPL_ASSETS entries
  for relative_path in "${D_DPL_ASSETS[@]}"; do

    # Compose absolute paths
    src_path="$D_DPL_DIR/$relative_path"
    dest_path="$D_DPL_ASSETS_DIR/$relative_path"

    # Check source is readable
    if [ -r "$src_path" ]; then

      # Check if destination path exists
      if ! [ -e "$dest_path" ]; then

        # Compose destination’s parent path
        dest_parent_path="$( dirname -- "$dest_path" )"

        # Ensure target directory is available
        mkdir -p -- "$dest_parent_path" &>/dev/null || {
          dprint_failure -l "Failed to create directory: $dest_parent_path"
          all_assets_copied=false
          continue
        }

        # Copy initial version to assets directory
        cp -Rn -- "$src_path" "$dest_path" &>/dev/null || {
          dprint_failure -l "Failed to copy: $src_path" -n "to: $dest_path"
          all_assets_copied=false
        }

      fi

    else

      # Report error
      dprint_failure -l "Unreadable deployment asset: $src_path"
      all_assets_readable=false

      # Nevertheless if destination path exists (might be pre-copied)
      if ! [ -e "$dest_path" ]; then all_assets_copied=false; fi

    fi

  done

  # Return appropriate status
  $all_assets_copied && return 0 || return 1
}