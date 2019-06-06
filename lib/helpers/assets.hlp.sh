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

#>  __process_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D_DPL_MANIFEST. Reads it line by 
#. line, ignores empty lines and lines starting with hash (‘#’) or double-slash 
#. (‘//’).
#
## All other lines are interpreted as relative paths to deployment’s assets.
#
## Copies initial versions of deployment’s assets to deployments assets 
#. directory. Assets directory is then worked with and can be taken under 
#. version control. Does not overwrite anything (user’s data takes priority).
#
## Requires:
#.  $D_DPL_MANIFEST     - Path to assets manifest file
#.  $D_DPL_DIR          - Path to resolve initial asset paths against
#.  $D_DPL_ASSETS_DIR   - Path to compose target asset paths against
#
## Returns:
#.  0 - Task performed
#.  1 - All assets exist in assets directory
#
__process_manifest_of_current_dpl()
{
  # Check if manifest is a readable file
  [ -r "$D_DPL_MANIFEST" -a -f "$D_DPL_MANIFEST" ] || return 0

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Storage variables
  local line dpl_asset_patterns=() keep_globbing=true

  # Read asset manifest line by line
  while IFS='' read -r line || [ -n "$line" ]; do

    # Skip empty and comment lines
    [[ -z $line || $line == '#'* || $line == '//'* ]] && continue

    # Check if starting a named section
    if [[ $line =~ ^\ *\([A-Za-z0-9]+\)\ *$ ]]; then

      # Check if current OS/distro matches section title
      if [[ $line == *"(${OS_FAMILY})"* || $line == *"(${OS_DISTRO})"* ]]; then
        keep_globbing=true
      else
        keep_globbing=false
      fi

      # Done with this line
      continue

    fi

    # Check if we are still globbing
    $keep_globbing || continue
    
    # Remove comments and whitespace on both edges
    line="$( printf '%s\n' "$line" | sed \
      -e 's/[#].*$//' \
      -e 's|//.*$||' \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' )"
    
    # Add whatever is left, if there is anything
    [ -n "$line" ] && dpl_asset_patterns+=( "$line" )

  done <"$D_DPL_MANIFEST"

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Check if $dpl_asset_patterns has at least one entry
  [ ${#dpl_asset_patterns[@]} -gt 0 ] || return 0

  # Storage and status variables
  local path_pattern relative_path src_path dest_path dest_parent_path
  local all_assets_readable=true all_assets_copied=true

  # Start populating global variables
  D_DPL_ASSETS_REL=()
  D_DPL_ASSETS=()

  # Iterate over $dpl_asset_patterns entries
  for path_pattern in "${dpl_asset_patterns[@]}"; do

    # Iterate over find results on that pattern
    while IFS= read -r -d $'\0' src_path; do

      # Compose absolute paths
      relative_path="${src_path#"$D_DPL_DIR/"}"
      dest_path="$D_DPL_ASSETS_DIR/$relative_path"

      # Check if source is readable
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
            continue
          }

        fi

        # Destination is in place: push onto global containers
        D_DPL_ASSETS_REL+=( "$relative_path" )
        D_DPL_ASSETS+=( "$dest_path" )

      else

        # Report error
        dprint_failure -l "Unreadable deployment asset: $src_path"
        all_assets_readable=false

        # Nevertheless if destination path exists (might be pre-copied)
        if ! [ -e "$dest_path" ]; then all_assets_copied=false; fi

      fi

    done < <( find -L "$D_DPL_DIR" -path "$D_DPL_DIR/$path_pattern" -print0 )

  done

  # Return appropriate status
  $all_assets_copied && return 0 || return 1
}

#>  __process_all_manifests_in_main_dir
#
## Processes every valid manifest file in a main deployments directory, using
#. __process_manifest_of_current_dpl function.
#
## Requires:
#.  $D_DPL_NAMES        - Array of taken deployment names
#.  $D_DPL_NAME_PATHS   - Array: index of each taken deployment name from 
#.                        $D_DPL_NAMES contains delimited list of paths to 
#.                        deployment files
#
## Returns:
#.  0 - Every manifest found is successfully processed
#.  1 - At least one manifest caused problems
#
__process_all_manifests_in_main_dir()
{
  # Status and dtorage variables
  local name path manifest_path i
  local all_good=true

  # Iterate over names
  for (( i=0; i<${#D_DPL_NAMES[@]}; i++ )); do

    # Extract name and path
    name="${D_DPL_NAMES[$i]}"
    path="${D_DPL_NAME_PATHS[$i]%"$D_DELIM"}"

    # Set up necessary variables
    D_DPL_MANIFEST="${path%$D_DPL_SH_SUFFIX}$D_ASSETS_SUFFIX"
    D_DPL_DIR="$( dirname -- "$path" )"
    D_DPL_ASSETS_DIR="$D_ASSETS_DIR/$name"

    # Do the deed
    __process_manifest_of_current_dpl || all_good=false

  done

  # Return
  $all_good && return 0 || return 1
}