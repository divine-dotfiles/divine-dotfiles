#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: manifests
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    4
#:revdate:      2019.08.07
#:revremark:    Major syntax/parsing rewrite for manifest-like files
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
#.  $D__DPL_ASSET_DIR   - Path to compose target asset paths against
#
## Provides into the global scope:
#.  $D_DPL_ASSET_RELPATHS   - Array of relative paths to assets
#.  $D_DPL_ASSET_PATHS      - Array of absolute paths to copied assets
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

  # Check if $D__MANIFEST_LINES has at least one entry
  [ ${#D__MANIFEST_LINES[@]} -gt 0 ] || return 0

  # Storage and status variables
  local i path_pattern path_prefix relative_path
  local src_path dest_path dest_parent_path
  local all_assets_copied=true

  # Start populating global variables
  D_DPL_ASSET_RELPATHS=()
  D_DPL_ASSET_PATHS=()

  # Iterate over $D__MANIFEST_LINES entries
  for (( i=0; i<${#D__MANIFEST_LINES[@]}; i++ )); do

    # Extract path/pattern
    path_pattern="${D__MANIFEST_LINES[$i]}"

    # Extract prefix
    if [ -z ${D__MANIFEST_LINE_PREFIXES[$i]+isset} ]; then
      path_prefix=
    else
      path_prefix="/${D__MANIFEST_LINE_PREFIXES[$i]}"
    fi

    # Check if pattern is intended as regex or solid path
    if [[ ${D__MANIFEST_LINE_FLAGS[$i]} = *r* ]]; then

      # Line is intended as RegEx pattern

      # Iterate over find results on that pattern
      while IFS= read -r -d $'\0' src_path; do

        # Compose absolute paths
        relative_path="${src_path#"${D__DPL_DIR}${path_prefix}/"}"
        dest_path="$D__DPL_ASSET_DIR/$relative_path"

        # Copy asset (for find results it is expected to always return 0)
        d__copy_asset "$relative_path" "$src_path" "$dest_path" \
          || all_assets_copied=false

      done < <( find -L "$D__DPL_DIR" \
        -path "${D__DPL_DIR}${path_prefix}/$path_pattern" -print0 )
    
    else

      # Line is intended as solid path

      # Copy asset
      d__copy_asset "$path_pattern" "${D__DPL_DIR}${path_prefix}/$path_pattern" \
        "$D__DPL_ASSET_DIR/$path_pattern" || all_assets_copied=false
    
    fi

  # Done iterating over $D__MANIFEST_LINES entries
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
#. populates the array $D__QUEUE_MAIN.
#
## If queue manifest is not available, tries two other methods: copying either 
#. absolute or relative paths to asset files (attempts are made in that order).
#
## Requires:
#.  $D__DPL_QUE_PATH     - Path to queue manifest file
#
## Provides into the global scope:
#.  $D__QUEUE_MAIN   - Array of main queue entries
#
## Returns:
#.  0 - Task performed: main queue is populated
#.  1 - Otherwise
#
d__process_queue_manifest_of_current_dpl()
{
  # Check if main queue is already filled up
  if [ ${#D__QUEUE_MAIN[@]} -gt 1 -o -n "$D__QUEUE_MAIN" ]; then

    # Main queue is already touched, nothing to do:
    return 0

  fi

  # Main queue is not filled: try various methods

  # Check if main queue file is readable
  if d__process_manifest "$D__DPL_QUE_PATH"; then

    # Check if $D__MANIFEST_LINES has at least one entry
    if [ ${#D__MANIFEST_LINES[@]} -gt 0 ]; then

      # Assign collected items to main queue
      D__QUEUE_MAIN=( "${D__MANIFEST_LINES[@]}" )
    
    fi

  # Otherwise, try to derive main queue from relative asset paths
  elif [ ${#D_DPL_ASSET_RELPATHS[@]} -gt 1 -o -n "$D_DPL_ASSET_RELPATHS" ]
  then

    D__QUEUE_MAIN=( "${D_DPL_ASSET_RELPATHS[@]}" )

  # Otherwise, try to derive main queue from absolute asset paths
  elif [ ${#D_DPL_ASSET_PATHS[@]} -gt 1 -o -n "$D_DPL_ASSET_PATHS" ]
  then

    D__QUEUE_MAIN=( "${D_DPL_ASSET_PATHS[@]}" )

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
  D_DPL_ASSET_RELPATHS+=( "$relative_path" )
  D_DPL_ASSET_PATHS+=( "$dest_path" )

  # Return success
  return 0
}

#>  d__process_all_asset_manifests_in_dpl_dirs
#
## Processes every valid manifest file in a main deployments directory, using
#. d__process_asset_manifest_of_current_dpl function.
#
## Requires:
#.  $D__LIST_OF_INT_DPL_NAMES - (array) Names of deployments in framework dirs
#.  $D__LIST_OF_INT_DPL_PATHS - (array) Index of each name contains delimited 
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
  for (( i=0; i<${#D__LIST_OF_INT_DPL_NAMES[@]}; i++ )); do

    # Extract name and path
    name="${D__LIST_OF_INT_DPL_NAMES[$i]}"
    path="${D__LIST_OF_INT_DPL_PATHS[$i]%"$D__CONST_DELIMITER"}"

    # Set up necessary variables
    D__DPL_MNF_PATH="${path%$D__SUFFIX_DPL_SH}$D__SUFFIX_DPL_MNF"
    D__DPL_DIR="$( dirname -- "$path" )"
    D__DPL_ASSET_DIR="$D__DIR_ASSETS/$name"

    # Do the deed
    d__process_asset_manifest_of_current_dpl || all_good=false

  done

  # Return
  $all_good && return 0 || return 1
}

#>  d__process_manifest PATH
#
## Interprets single provided path as manifest file. Parses the file, returns 
#. results by populating global arrays. Each array is emptied out before the
#. manifest file is touched.
#
## Supported types of manifests:
#.  * ‘*.dpl.mnf’     - Divine deployment asset manifest
#.  * ‘*.dpl.que’     - Divine deployment queue manifest
#.  * ‘Divinefile’    - Special kind of Divine deployment for handling system 
#.                      packages. Lines of Divinefile are not parsed beyond 
#.                      key-values and comments.
#
## Modifies in the global scope:
#.  $D__MANIFEST_LINES            - (array) Non-empty lines from manifest file 
#.                                  that are relavant for the current OS. Each 
#.                                  line is trimmed of whitespace on both ends.
#.  $D__MANIFEST_LINE_FLAGS       - (array) For each extracted line, this array 
#.                                  will contain its char flags as a string at 
#.                                  the same index
#.  $D__MANIFEST_LINE_PREFIXES    - (array) For each extracted line, this array 
#.                                  will contain its prefix at the same index
#.  $D__MANIFEST_LINE_PRIORITIES  - (array) For each extracted line, this array 
#.                                  will contain its priority at the same index
#
## Returns:
#.  0 - Manifest processed, arrays now represent its relevant content
#.  1 - Manifest file could not be accessed, arrays are empty
#
d__process_manifest()
{
  # Initialize container arrays
  D__MANIFEST_LINES=()
  D__MANIFEST_LINE_FLAGS=()
  D__MANIFEST_LINE_PREFIXES=()
  D__MANIFEST_LINE_PRIORITIES=()

  # Extract path
  local mnf_filepath="$1"; shift

  # Check if manifest if a readable file, or return immediately
  [ -r "$mnf_filepath" -a -f "$mnf_filepath" ] || return 1

  # Storage variables
  local line_from_file line_continuation=false
  local buffer buffer_backup
  local chunk tmp tmp_l tmp_r key value value_array
  local i x y z

  # Status variables
  local ongoing_relevance ongoing_flags ongoing_prefix ongoing_priority
  local current_relevance current_flags current_prefix current_priority

  # Initial (default) statuses
  ongoing_relevance=true
  ongoing_flags=
  ongoing_prefix=
  ongoing_priority="$D__CONST_DEF_PRIORITY"

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Iterate over lines in manifest file (strip whitespace on both ends)
  while read -r line_from_file || [ -n "$line_from_file" ]; do

    # Check if line is empty or commented
    if [ -z "$line_from_file" ] || [[ $line_from_file = \#* ]]; then

      # Check if arrived with or without line continuation
      if [ "$line_continuation" = true ]; then

        # Line continuation ends here
        line_continuation=false

        ## If there is any buffer to speak of (from previous lines), use it in 
        #. current parsing cycle, otherwise, just go to next line
        [ -n "$buffer" ] || continue

      else

        # No line continuation: just skip
        continue

      fi

    else

      # Line is not empty/commented

      # Check if arrived with or without line continuation
      if [ "$line_continuation" = true ]; then

        # Line continuation ends here
        line_continuation=false

        # Append to buffer
        buffer+="$line_from_file"

      else

        # No line continuation

        # Populate buffer
        buffer="$line_from_file"

        # Inherit status variables for this line
        current_relevance="$ongoing_relevance"
        current_flags="$ongoing_flags"
        current_prefix="$ongoing_prefix"
        current_priority="$ongoing_priority"

      fi

    fi

    # Check if remaining line contains comment symbol
    if [[ $buffer = *\#* ]]; then

      # Save current buffer in case this is not really a commented line
      buffer_backup="$buffer"

      # Break line on first occurence of comment symbol
      IFS='#' read -r chunk tmp <<<"$buffer"

      # Repeat until last character before split is not ‘\’
      while [[ chunk = *\\ ]]; do

        # Check if right part contains another comment symbol
        if [[ $tmp = *\#* ]]; then

          # Re-split right part on comment symbol
          IFS='#' read -r tmp_l tmp_r <<<"$tmp"

          # Re-attach amputated parts
          chunk="${chunk:0:${#chunk}-1}#$tmp_l"
          tmp="$tmp_r"
        
        else

          # Not a proper commented line: restore original buffer and break
          chunk="$buffer_backup"
          break
        
        fi

      # Done repeating until last character before split is not ‘\’
      done

      # Update buffer with non-commented part
      buffer="$chunk"

    # Done checking for comment symbol
    fi

    ## Repeat until line no longer starts with opening parenthesis and contains 
    #. closing one
    while [[ $buffer = \(*\)* ]]; do

      # Save current buffer in case this is not really a key-value
      buffer_backup="$buffer"

      # Shift away opening parenthesis
      buffer="${buffer:1:${#buffer}}"

      # Break line on first occurence of closing parenthesis
      IFS=')' read -r chunk tmp <<<"$buffer"

      # Repeat until last character before split is not ‘\’
      while [[ chunk = *\\ ]]; do

        # Check if right part contains another closing parenthesis
        if [[ $tmp = *\)* ]]; then

          # Re-split right part on closing parenthesis
          IFS=')' read -r tmp_l tmp_r <<<"$tmp"

          # Re-attach amputated parts
          chunk="${chunk:0:${#chunk}-1})$tmp_l"
          tmp="$tmp_r"
        
        else

          # Not a proper key-value: restore original buffer and break loops
          buffer="$buffer_backup"
          break 2
        
        fi

      # Done repeating until last character before split is not ‘\’
      done

      # Trim whitespace on both edges
      read -r chunk <<<"$chunk"
      read -r tmp <<<"$tmp"

      # Update buffer
      buffer="$tmp"

      # If empty parentheses, discard key-value completely
      [ -z "$chunk" ] && continue

      # Check if parentheses contain key-value separator
      if [[ $chunk = *:* ]]; then

        # Split on first occurrence of separator
        IFS=: read -r key value <<<"$chunk"

        # Clear whitespace from edges of key and value
        read -r key <<<"$key"
        read -r value <<<"$value"

        # Check key
        case $key in
          os)
            # If value is empty, all OS’s are allowed
            if [ -z "$value" ]; then current_relevance=true; continue; fi

            # If value is either ‘all’ or ‘any’, again, all OS’s are allowed
            case $value in all|any) current_relevance=true; continue;; esac

            # Read value as vertical bar-separated list of relevant OS’s
            IFS='|' read -r -a value_array <<<"$value"

            # Set default value
            current_relevance=false

            # Iterate over list of relevant OS’s
            for value in "${value_array[@]}"; do

              # Clear whitespace from edges of OS name
              read -r value <<<"$value"

              # Check if current OS name from the list matches detected OS
              if [[ $value = $D__OS_FAMILY || $value = $D__OS_DISTRO ]]; then

                # Flip flag and stop further list processing
                current_relevance=true
                break

              fi

            # Done iterating over list of relevant OS’s
            done
            ;;
          flags)
            # Remove all whitespace from within the value
            value="${value//[[:space:]]/}"
            # Replace current flags
            current_flags="$value"
            ;;
          prefix)
            # Replace current prefix
            current_prefix="$value"
            ;;
          priority)
            # Check if provided priority is a number
            if [[ $value =~ ^[0-9]+$ ]]; then

              # Replace current priority with provided one
              current_priority="$value"

            else

              # Priority is not a valid number: assign default value
              current_priority="$D__CONST_DEF_PRIORITY"
            
            fi
            ;;
          *)
            # Unsupported key: continue to next chunk of the line
            continue
            ;;
        esac

      else

        # Key-value parentheses do not contain a separator (‘:’)

        ## Special case: without separator, interpret key as a set of character 
        #. flags that are to be *appended* to current list of flags
        current_flags+="$chunk"

      fi

    ## Done repeating until line no longer starts with opening parenthesis and 
    #. contains closing one
    done

    # Trim whitespace on both edges of remaining buffer
    read -r buffer <<<"$buffer"

    # Check if remaining buffer ends with ‘\’
    if [[ $buffer = *\\ ]]; then

      # Perform calculations
      i="$(( ${#buffer} - 2 ))"; x=1
      while (( $i )); do
        if [[ ${buffer:$i:$i+1} = \\ ]]; then ((++x)); ((--i)); else break; fi
      done
      y="$(( $x/2 ))"; z="$(( $x - $y*2 ))"

      # Replace terminating backslashes
      buffer="${buffer:0:${#buffer}-$x}"
      while (( $y )); do buffer+='\'; ((--y)); done

      # Check if there is an odd number of terminating backslashes
      if (( $z )); then

        # (Re-)enable line continuation
        line_continuation=true

        # Go to next line
        continue
      
      fi

    fi

    # Check if the line proper starts with an escape character (‘\’)
    if [[ $buffer = \\* ]]; then

      # Remove exactly one escape character
      buffer="${buffer:1:${#buffer}}"

    fi

    # Check if there is any line remaining to speak of
    if [ -n "$buffer" ]; then

      # There is line remaining

      # Proceed with current line only if it is currently relevant
      [ "$current_relevance" = true ] || continue

    else

      # No line remaining: this line’s key-values become ongoing
      ongoing_relevance="$current_relevance"
      ongoing_flags="$current_flags"
      ongoing_prefix="$current_prefix"
      ongoing_priority="$current_priority"

      # Go to next line
      continue

    fi

    # Finally, add this line and it’s parameters to global array
    D__MANIFEST_LINES+=( "$buffer" )
    D__MANIFEST_LINE_FLAGS+=( "$current_flags" )
    D__MANIFEST_LINE_PREFIXES+=( "$current_prefix" )
    D__MANIFEST_LINE_PRIORITIES+=( "$current_priority" )

    # Clear buffer
    buffer=

  # Done iterating over lines in manifest file
  done <"$mnf_filepath"

  ## Check if last line was a relevant non-empty orphan (happens when file ends 
  #. with ‘\’)
  if [ "$line_continuation" = true \
    -a -n "$buffer" \
    -a "$current_relevance" = true ]
  then

    ## Last line needs to be processed. Key-values and comments are both 
    #. already processed, and status variables remain in relevant state
    
    # Add this line and it’s parameters to global array
    D__MANIFEST_LINES+=( "$buffer" )
    D__MANIFEST_LINE_FLAGS+=( "$current_flags" )
    D__MANIFEST_LINE_PREFIXES+=( "$current_prefix" )
    D__MANIFEST_LINE_PRIORITIES+=( "$current_priority" )

  fi

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Return success
  return 0
}