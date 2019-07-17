#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: manifests
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.30
#:revremark:    Initial revision
#:created_at:   2019.05.30

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function that prepares deployment’s asset and queue manifests
#

#>  d__process_manifests_of_current_dpl
#
## Looks for asset manifest at $D__DPL_MNF_PATH and for main queue file at 
#. $D__DPL_QUE_PATH. First, processes manifest (copies assets and fills global 
#. arrays) if manifest is present. Afterward, if main queue is not yet filled, 
#. fills it up: from main queue file, or absent that, from relative asset 
#. paths, or absent that, does not touch the main queue.
#
## Returns:
#.  0 - Assets are successfully processed, while main queue is composed as best 
#.      as possible
#.  1 - Otherwise
d__process_manifests_of_current_dpl()
{
  # First, process asset manifest of current deployment (must return zero)
  d__process_asset_manifest_of_current_dpl || return 1

  # Second, process queue manifest of current deployment (may fail freely)
  d__process_queue_manifest_of_current_dpl

  # If gotten here, return success
  return 0
}

#>  d__process_asset_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D__DPL_MNF_PATH. Reads it line by 
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
#.  $D__DPL_MNF_PATH     - Path to assets manifest file
#.  $D__DPL_DIR          - Path to resolve initial asset paths against
#.  $D__DPL_ASSETS_DIR   - Path to compose target asset paths against
#
## Provides into the global scope:
#.  $D__DPL_ASSET_RELPATHS   - Array of relative paths to assets
#.  $D__DPL_ASSET_PATHS      - Array of absolute paths to copied assets
#
## Returns:
#.  0 - Task performed: all assets now exist in assets directory
#.  1 - Otherwise
#
d__process_asset_manifest_of_current_dpl()
{
  # Check if directory of current deployment is readable
  if ! [ -r "$D__DPL_DIR" -a -d "$D__DPL_DIR" ]; then
    dprint_failure -l "Unreadable directory of current deployment: $D__DPL_DIR"
    return 1
  fi

  # Parse manifest file
  d__process_manifest "$D__DPL_MNF_PATH" || {
    dprint_debug 'No asset manifest'
    return 0
  }

  # Check if $D__DPL_MANIFEST_LINES has at least one entry
  [ ${#D__DPL_MANIFEST_LINES[@]} -gt 0 ] || return 0

  # Storage and status variables
  local i path_pattern path_prefix relative_path
  local src_path dest_path dest_parent_path
  local all_assets_copied=true

  # Start populating global variables
  D__DPL_ASSET_RELPATHS=()
  D__DPL_ASSET_PATHS=()

  # Iterate over $D__DPL_MANIFEST_LINES entries
  for (( i=0; i<${#D__DPL_MANIFEST_LINES[@]}; i++ )); do

    # Extract path/pattern
    path_pattern="${D__DPL_MANIFEST_LINES[$i]}"

    # Extract prefix
    if [ -z ${D__DPL_MANIFEST_LINE_PREFIXES[$i]+isset} ]; then
      path_prefix=
    else
      path_prefix="/${D__DPL_MANIFEST_LINE_PREFIXES[$i]}"
    fi

    # Check if pattern is intended as regex or solid path
    if [[ ${D__DPL_MANIFEST_LINE_FLAGS[$i]} = *r* ]]; then

      # Line is intended as RegEx pattern

      # Iterate over find results on that pattern
      while IFS= read -r -d $'\0' src_path; do

        # Compose absolute paths
        relative_path="${src_path#"${D__DPL_DIR}${path_prefix}/"}"
        dest_path="$D__DPL_ASSETS_DIR/$relative_path"

        # Copy asset (for find results it is expected to always return 0)
        d__copy_asset "$relative_path" "$src_path" "$dest_path" \
          || all_assets_copied=false

      done < <( find -L "$D__DPL_DIR" \
        -path "${D__DPL_DIR}${path_prefix}/$path_pattern" -print0 )
    
    else

      # Line is intended as solid path

      # Copy asset
      d__copy_asset "$path_pattern" "${D__DPL_DIR}${path_prefix}/$path_pattern" \
        "$D__DPL_ASSETS_DIR/$path_pattern" || all_assets_copied=false
    
    fi

  # Done iterating over $D__DPL_MANIFEST_LINES entries
  done

  # Return appropriate code
  $all_assets_copied && return 0 || return 1
}

#>  d__process_queue_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D__DPL_QUE_PATH. Reads it line by 
#. line, ignores empty lines and lines starting with hash (‘#’) or double-slash 
#. (‘//’).
#
## All other lines are interpreted as textual main queue entries, with which it 
#. populates the array $D__DPL_QUEUE_MAIN.
#
## If queue manifest is not available, tries two other methods: copying either 
#. absolute or relative paths to asset files (attempts are made in that order).
#
## Requires:
#.  $D__DPL_QUE_PATH     - Path to queue manifest file
#
## Provides into the global scope:
#.  $D__DPL_QUEUE_MAIN   - Array of main queue entries
#
## Returns:
#.  0 - Task performed: main queue is populated
#.  1 - Otherwise
#
d__process_queue_manifest_of_current_dpl()
{
  # Check if main queue is already filled up
  if [ ${#D__DPL_QUEUE_MAIN[@]} -gt 1 -o -n "$D__DPL_QUEUE_MAIN" ]; then

    # Main queue is already touched, nothing to do:
    return 0

  fi

  # Main queue is not filled: try various methods

  # Check if main queue file is readable
  if d__process_manifest "$D__DPL_QUE_PATH"; then

    # Check if $D__DPL_MANIFEST_LINES has at least one entry
    if [ ${#D__DPL_MANIFEST_LINES[@]} -gt 0 ]; then

      # Assign collected items to main queue
      D__DPL_QUEUE_MAIN=( "${D__DPL_MANIFEST_LINES[@]}" )
    
    fi

  # Otherwise, try to derive main queue from relative asset paths
  elif [ ${#D__DPL_ASSET_RELPATHS[@]} -gt 1 -o -n "$D__DPL_ASSET_RELPATHS" ]
  then

    D__DPL_QUEUE_MAIN=( "${D__DPL_ASSET_RELPATHS[@]}" )

  # Otherwise, try to derive main queue from absolute asset paths
  elif [ ${#D__DPL_ASSET_PATHS[@]} -gt 1 -o -n "$D__DPL_ASSET_PATHS" ]
  then

    D__DPL_QUEUE_MAIN=( "${D__DPL_ASSET_PATHS[@]}" )

  # Otherwise, give up
  else

    # No way to pre-fill main queue
    return 1

  fi
}

#>  d__copy_asset REL_PATH SRC_PATH DEST_PATH
#
## Returns:
#.  0 - Asset is in place as required
#.  1 - Otherwise
#
d__copy_asset()
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
  D__DPL_ASSET_RELPATHS+=( "$relative_path" )
  D__DPL_ASSET_PATHS+=( "$dest_path" )

  # Return success
  return 0
}

#>  d__process_all_asset_manifests_in_dpl_dirs
#
## Processes every valid manifest file in a main deployments directory, using
#. d__process_asset_manifest_of_current_dpl function.
#
## Requires:
#.  $D__DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D__DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Returns:
#.  0 - Every manifest found is successfully processed
#.  1 - At least one manifest caused problems
#
d__process_all_asset_manifests_in_dpl_dirs()
{
  # Status and dtorage variables
  local name path manifest_path i
  local all_good=true

  # Iterate over names
  for (( i=0; i<${#D__DPL_NAMES_IN_FMWK_DIRS[@]}; i++ )); do

    # Extract name and path
    name="${D__DPL_NAMES_IN_FMWK_DIRS[$i]}"
    path="${D__DPL_PATHS_IN_FMWK_DIRS[$i]%"$D__CONST_DELIMITER"}"

    # Set up necessary variables
    D__DPL_MNF_PATH="${path%$D__SUFFIX_DPL_SH}$D__SUFFIX_DPL_MNF"
    D__DPL_DIR="$( dirname -- "$path" )"
    D__DPL_ASSETS_DIR="$D__DIR_ASSETS/$name"

    # Do the deed
    d__process_asset_manifest_of_current_dpl || all_good=false

  done

  # Return
  $all_good && return 0 || return 1
}

#>  d__process_manifest PATH
#
## Processes manifest file at PATH and populates two global arrays with results
#
## Modifies in the global scope:
#.  $D__DPL_MANIFEST_LINES         - (array) Non-empty lines from manifest file 
#.                                  that are relavant for the current OS. Each 
#.                                  line is trimmed of whitespace on both ends.
#.  $D__DPL_MANIFEST_LINE_FLAGS    - (array) For each extracted line, this array 
#.                                  will contain its char flags as a string at 
#.                                  the same index
#.  $D__DPL_MANIFEST_LINE_PREFIXES - (array) For each extracted line, this array 
#.                                  will contain its prefix at the same index
#
## Returns:
#.  0 - Manifest processed, arrays populated
#.  1 - Manifest file could not be accessed
#
d__process_manifest()
{
  # Initialize container arrays
  D__DPL_MANIFEST_LINES=()
  D__DPL_MANIFEST_LINE_FLAGS=()
  D__DPL_MANIFEST_LINE_PREFIXES=()

  # Extract path
  local mnf_filepath="$1"; shift

  # Check if manifest if a readable file, or return immediately
  [ -r "$mnf_filepath" -a -f "$mnf_filepath" ] || return 1

  # Storage variables
  local line chunks chunk tmp counter=0
  local prefix= flags=
  local keep_globbing=true

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Iterate over lines in manifest file
  while IFS='' read -r line || [ -n "$line" ]; do

    # Remove comments, then remove whitespace on both ends
    line="$( sed \
      -e 's/[#].*$//' \
      -e 's|//.*$||' \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' \
      <<<"$line" \
      )"
    
    # Quick exit for empty lines
    [ -n "$line" ] || continue

    # Check if current line is a title line
    if [[ $line = \(*\) ]]; then

      # Strip parentheses
      line="${line:1:${#line}-2}"

      # Check if content of parentheses sets a prefix
      if [[ $line =~ ^\ *prefix\ *: ]]; then

        # Extract prefix
        IFS=':' read -r tmp prefix <<<"$line"

        # Strip whitespace on both ends
        prefix="$( sed \
          -e 's/^[[:space:]]*//' \
          -e 's/[[:space:]]*$//' \
          <<<"$prefix" \
          )"
        
      # Otherwise, treat content of parentheses as list of applicable OS’s
      else

        # Split content of parentheses into vertical bar-separated chunks
        IFS='|' read -r -a chunks <<<"$line"

        # Set default for $keep_globbing
        keep_globbing=false

        # Iterate over vertical bar-separated chunks of title line
        for chunk in "${chunks[@]}"; do

          # Check if detected OS matches current chunk
          if [[ $chunk =~ ^\ *$D__OS_FAMILY\ *$ ]] \
            || [[ $chunk =~ ^\ *$D__OS_DISTRO\ *$ ]]
          then

            # Flip flag and stop further chunk processing
            keep_globbing=true
            break

          fi
        
        # Done iterating over vertical bar-separated chunks of title line
        done
      
      fi

      # For title lines, no further processing
      continue

    fi

    # Check whether to proceed with globbing
    $keep_globbing || continue

    # Set flags to empty string
    flags=

    ## If line starts with escaped opening parenthesis or escaped escape char, 
    #. strip one escape char. If line starts with regular opening parenthesis 
    #. and contains closing one, extract flags from within.
    #
    if [[ $line = \\\(* ]]; then line="${line:1}"
    elif [[ $line = \\\\* ]]; then line="${line:1}"
    elif [[ $line = \(*\)* ]]; then

      # Strip opening parenthesis
      line="${line:1}"

      # Break the line on first occurrence of closing parenthesis
      IFS=')' read -r flags line <<<"$line"

    fi

    # Strip whitespace from both ends of line
    line="$( sed \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' \
      <<<"$line" \
      )"
    
    # Check if there is a line to speak of
    if [ -n "$line" ]; then

      # Add to global array
      D__DPL_MANIFEST_LINES[$counter]="$line"

    else

      # Continue to next line
      continue

    fi

    # Strip whitespace from both ends of flags, same with slashes
    [ -n "$flags" ] && flags="$( sed \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' \
      -e 's/^\/*//' \
      -e 's/\/*$//' \
      <<<"$flags" \
      )"

    # If still some flags left, add them to global array
    [ -n "$flags" ] && D__DPL_MANIFEST_LINE_FLAGS[$counter]="$flags"

    # Also, prefixes
    [ -n "$prefix" ] && D__DPL_MANIFEST_LINE_PREFIXES[$counter]="$prefix"

    # Increment counter for next line
    (( ++counter ))

  # Done iterating over lines in manifest file
  done <"$mnf_filepath"

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Return success
  return 0
}