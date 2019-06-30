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

#>  __process_manifests_of_current_dpl
#
## Looks for asset manifest at $D_DPL_MNF_PATH and for main queue file at 
#. $D_DPL_QUE_PATH. First, processes manifest (copies assets and fills global 
#. arrays) if manifest is present. Afterward, if main queue is not yet filled, 
#. fills it up: from main queue file, or absent that, from relative asset 
#. paths, or absent that, does not touch the main queue.
#
## Returns:
#.  0 - Assets are successfully processed, while main queue is composed as best 
#.      as possible
#.  1 - Otherwise
__process_manifests_of_current_dpl()
{
  # First, process asset manifest of current deployment (must return zero)
  __process_asset_manifest_of_current_dpl || return 1

  # Second, process queue manifest of current deployment (may fail freely)
  __process_queue_manifest_of_current_dpl

  # If gotten here, return success
  return 0
}

#>  __process_asset_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D_DPL_MNF_PATH. Reads it line by 
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
#.  $D_DPL_MNF_PATH     - Path to assets manifest file
#.  $D_DPL_DIR          - Path to resolve initial asset paths against
#.  $D_DPL_ASSETS_DIR   - Path to compose target asset paths against
#
## Provides into the global scope:
#.  $D_DPL_ASSET_RELPATHS   - Array of relative paths to assets
#.  $D_DPL_ASSET_PATHS      - Array of absolute paths to copied assets
#
## Returns:
#.  0 - Task performed: all assets now exist in assets directory
#.  1 - Otherwise
#
__process_asset_manifest_of_current_dpl()
{
  # Check if manifest is a readable file
  if ! [ -r "$D_DPL_MNF_PATH" -a -f "$D_DPL_MNF_PATH" ]; then
    dprint_debug 'No asset manifest'
    return 0
  fi

  # Check if directory of current deployment is readable
  if ! [ -r "$D_DPL_DIR" -a -d "$D_DPL_DIR" ]; then
    dprint_failure -l "Unreadable directory of current deployment: $D_DPL_DIR"
    return 1
  fi

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Storage variables
  local line dpl_asset_patterns=() keep_globbing=true

  # Read asset manifest line by line
  while IFS='' read -r line || [ -n "$line" ]; do

    # Glob line and check status
    line="$( __glob_line "$line" "$keep_globbing" || exit $? )"; case $? in
      0)  dpl_asset_patterns+=( "$line" );;
      1)  keep_globbing=true;;
      2)  keep_globbing=false;;
      *)  :;;
    esac

  done <"$D_DPL_MNF_PATH"

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Check if $dpl_asset_patterns has at least one entry
  [ ${#dpl_asset_patterns[@]} -gt 0 ] || return 0

  # Storage and status variables
  local path_pattern relative_path src_path dest_path dest_parent_path
  local all_assets_copied=true

  # Start populating global variables
  D_DPL_ASSET_RELPATHS=()
  D_DPL_ASSET_PATHS=()

  # Iterate over $dpl_asset_patterns entries
  for path_pattern in "${dpl_asset_patterns[@]}"; do

    # Check if pattern is intended as regex or solid path
    if [[ $path_pattern == '[*] '* ]] || [[ $path_pattern == '[regex] '* ]]
    then

      # Pattern is regex

      # Clean up pattern
      path_pattern="${path_pattern#'[*]'}"
      path_pattern="${path_pattern#'[regex]'}"
      path_pattern="$( printf '%s\n' "$path_pattern" | sed \
        -e 's/^[[:space:]]*//' )"

      # Iterate over find results on that pattern
      while IFS= read -r -d $'\0' src_path; do

        # Compose absolute paths
        relative_path="${src_path#"$D_DPL_DIR/"}"
        dest_path="$D_DPL_ASSETS_DIR/$relative_path"

        # Copy asset (for find results it is expected to always return 0)
        __copy_asset "$relative_path" "$src_path" "$dest_path" \
          || all_assets_copied=false

      done < <( find -L "$D_DPL_DIR" -path "$D_DPL_DIR/$path_pattern" -print0 )
    
    else

      # Pattern is solid path

      # Copy asset
      __copy_asset "$path_pattern" "$D_DPL_DIR/$path_pattern" \
        "$D_DPL_ASSETS_DIR/$path_pattern" || all_assets_copied=false
    
    fi

  done

  # Return appropriate code
  $all_assets_copied && return 0 || return 1
}

#>  __process_queue_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D_DPL_QUE_PATH. Reads it line by 
#. line, ignores empty lines and lines starting with hash (‘#’) or double-slash 
#. (‘//’).
#
## All other lines are interpreted as textual main queue entries, with which it 
#. populates the array $D_DPL_QUEUE_MAIN.
#
## If queue manifest is not available, tries two other methods: copying either 
#. absolute or relative paths to asset files (attempts are made in that order).
#
## Requires:
#.  $D_DPL_QUE_PATH     - Path to queue manifest file
#
## Provides into the global scope:
#.  $D_DPL_QUEUE_MAIN   - Array of main queue entries
#
## Returns:
#.  0 - Task performed: main queue is populated
#.  1 - Otherwise
#
__process_queue_manifest_of_current_dpl()
{
  # Check if main queue is already filled up
  if [ ${#D_DPL_QUEUE_MAIN[@]} -gt 1 -o -n "$D_DPL_QUEUE_MAIN" ]; then

    # Main queue is already touched, nothing to do:
    return 0

  fi

  # Main queue is not filled: try various methods

  # Check if main queue file is readable
  if [ -r "$D_DPL_QUE_PATH" -a -f "$D_DPL_QUE_PATH" ]; then

    # Store current case sensitivity setting, then turn it off
    local restore_nocasematch="$( shopt -p nocasematch )"
    shopt -s nocasematch

    # Storage variables
    local line dpl_main_queue_items=() keep_globbing=true

    # Read asset manifest line by line
    while IFS='' read -r line || [ -n "$line" ]; do

      # Glob line and check status
      line="$( __glob_line "$line" "$keep_globbing" || exit $? )"; case $? in
        0)  dpl_main_queue_items+=( "$line" );;
        1)  keep_globbing=true;;
        2)  keep_globbing=false;;
        *)  :;;
      esac

    done <"$D_DPL_QUE_PATH"

    # Restore case sensitivity
    eval "$restore_nocasematch"

    # Check if $dpl_main_queue_items has at least one entry
    if [ ${#dpl_main_queue_items[@]} -gt 0 ]; then

      # Assign collected items to main queue
      D_DPL_QUEUE_MAIN=( "${dpl_main_queue_items[@]}" )
    
    fi

  elif [ ${#D_DPL_ASSET_RELPATHS[@]} -gt 1 -o -n "$D_DPL_ASSET_RELPATHS" ]
  then

    D_DPL_QUEUE_MAIN=( "${D_DPL_ASSET_RELPATHS[@]}" )

  elif [ ${#D_DPL_ASSET_PATHS[@]} -gt 1 -o -n "$D_DPL_ASSET_PATHS" ]
  then

    D_DPL_QUEUE_MAIN=( "${D_DPL_ASSET_PATHS[@]}" )

  else

    # No way to pre-fill main queue
    return 1

  fi
}

#>  __copy_asset REL_PATH SRC_PATH DEST_PATH
#
## Returns:
#.  0 - Asset is in place as required
#.  1 - Otherwise
#
__copy_asset()
{
  # Compose absolute paths
  local relative_path="$1"; shift
  local src_path="$1"; shift
  local dest_path="$1"; shift

  # Check if source is readable
  if [ -r "$src_path" ]; then

    # Check if destination path exists
    if ! [ -e "$dest_path" ]; then

      # Compose destination’s parent path
      dest_parent_path="$( dirname -- "$dest_path" )"

      # Ensure target directory is available
      mkdir -p -- "$dest_parent_path" &>/dev/null || {
        dprint_failure -l "Failed to create directory: $dest_parent_path"
        return 1
      }

      # Copy initial version to assets directory
      cp -Rn -- "$src_path" "$dest_path" &>/dev/null || {
        dprint_failure -l "Failed to copy: $src_path" -n "to: $dest_path"
        return 1
      }

    fi

  else

    # Report error
    dprint_failure -l "Unreadable deployment asset: $src_path"

    # Nevertheless check if destination path exists (might be pre-copied)
    if ! [ -e "$dest_path" ]; then return 1; fi

  fi

  # Destination is in place: push onto global containers
  D_DPL_ASSET_RELPATHS+=( "$relative_path" )
  D_DPL_ASSET_PATHS+=( "$dest_path" )

  # Return success
  return 0
}

#>  __process_all_asset_manifests_in_dpl_dirs
#
## Processes every valid manifest file in a main deployments directory, using
#. __process_asset_manifest_of_current_dpl function.
#
## Requires:
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Returns:
#.  0 - Every manifest found is successfully processed
#.  1 - At least one manifest caused problems
#
__process_all_asset_manifests_in_dpl_dirs()
{
  # Status and dtorage variables
  local name path manifest_path i
  local all_good=true

  # Iterate over names
  for (( i=0; i<${#D_DPL_NAMES_IN_FMWK_DIRS[@]}; i++ )); do

    # Extract name and path
    name="${D_DPL_NAMES_IN_FMWK_DIRS[$i]}"
    path="${D_DPL_PATHS_IN_FMWK_DIRS[$i]%"$D_CONST_DELIMITER"}"

    # Set up necessary variables
    D_DPL_MNF_PATH="${path%$D_SUFFIX_DPL_SH}$D_SUFFIX_DPL_MNF"
    D_DPL_DIR="$( dirname -- "$path" )"
    D_DPL_ASSETS_DIR="$D_DIR_ASSETS/$name"

    # Do the deed
    __process_asset_manifest_of_current_dpl || all_good=false

  done

  # Return
  $all_good && return 0 || return 1
}

#>  __glob_line LINE KEEP_GLOBBING
#
## Processes line of a key file
#
## Returns:
#.  0 - Printed out regular line
#.  1 - Processed section head, should start globbing
#.  2 - Processed section head, should stop globbing
#.  3 - Nothing to process
#
__glob_line()
{
  # Extract line from first argument
  local line="$1"; shift

  # Remove comments and whitespace on both edges
  line="$( printf '%s\n' "$line" | sed \
    -e 's/[#].*$//' \
    -e 's|//.*$||' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' )"
  
  # Skip empty lines
  [ -z "$line" ] && return 3

  # Check if starting a named section
  if [[ $line =~ ^\([A-Za-z0-9]+\)$ ]]; then

    # Check if current OS/distro matches section title
    if [[ $line == *"(${OS_FAMILY})"* || $line == *"(${OS_DISTRO})"* ]]
    then
      return 1
    else
      return 2
    fi

  fi

  # Check if we are still globbing
  local keep_globbing="$1"; shift
  $keep_globbing || return 3
  
  # Check if anything is left
  if [ -n "$line" ]; then

    # Print and return
    printf '%s\n' "$line"
    return 0

  else

    return 3

  fi
}