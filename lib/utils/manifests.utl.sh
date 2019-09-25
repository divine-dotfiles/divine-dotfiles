#!/usr/bin/env bash
#:title:        Divine Bash utils: manifests
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Remove revision numbers from all src files
#:created_at:   2019.05.30

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Utility that prepares deployment manifests for assets and queue items
#

#>  d__process_asset_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D__DPL_MNF_PATH. Reads it line by 
#. line, ignores empty lines and lines starting with hash ('#') or double-slash 
#. ('//').
#
## All other lines are interpreted as relative paths to deployment's assets.
#
## Copies initial versions of deployment's assets to deployments assets 
#. directory. Assets directory is then worked with and can be taken under 
#. version control. Does not overwrite anything (user's data takes priority).
#
## Note, that specifically for populating queue arrays, regex patterns from 
#. manifests are resolved against deployment's asset directory in the Grail, as 
#. opposed to the original deployment directory. This is done to include user's 
#. own additions in the queue.
#
## Requires:
#.  $D__DPL_MNF_PATH    - Path to assets manifest file
#.  $D__DPL_DIR         - Path to resolve initial asset paths against
#.  $D__DPL_ASSET_DIR   - Path to compose target asset paths against
#
## Provides into the global scope:
#.  $D_QUEUE_MAIN       - Array of relative paths to assets
#.  $D_DPL_ASSET_PATHS  - Array of absolute paths to assets
#
## Returns:
#.  0 - Task performed: all assets now exist in assets directory
#.  1 - Otherwise
#
d__process_asset_manifest_of_current_dpl()
{
  # Check if directory of current deployment is readable
  if ! [ -r "$D__DPL_DIR" -a -d "$D__DPL_DIR" ]; then
    dprint_failure "Unreadable directory of current deployment: $D__DPL_DIR"
    return 1
  fi

  # Parse manifest file
  if ! d__process_manifest "$D__DPL_MNF_PATH"; then
    dprint_debug 'No asset manifest'
    return 0
  fi

  # Initialize global arrays
  D_QUEUE_MAIN=()
  D_DPL_ASSET_PATHS=()

  # Check if $D__MANIFEST_LINES has at least one entry
  [ ${#D__MANIFEST_LINES[@]} -gt 0 ] || return 0

  # Ensure existence of asset directory
  mkdir -p -- "$D__DPL_ASSET_DIR"

  # Storage and status variables
  local i path_pattern path_prefix relative_path
  local src_path dest_path dest_parent_path
  local all_good=true asset_provided
  local j flag_r flag_d flag_o flag_n flag_p

  # Iterate over $D__MANIFEST_LINES entries
  for (( i=0; i<${#D__MANIFEST_LINES[@]}; i++ )); do

    # If there is a queue split before this line, insert it
    if [ "${D__MANIFEST_SPLITS[$i]}" = true ]; then d__queue_split; fi

    # Extract path/pattern
    path_pattern="${D__MANIFEST_LINES[$i]}"

    # Clear leading and trailing slashes from path/pattern
    while [[ $path_pattern = /* ]]; do path_pattern="${path_pattern##/}"; done
    while [[ $path_pattern = */ ]]; do path_pattern="${path_pattern%%/}"; done

    # Extract prefix
    if [ -z ${D__MANIFEST_LINE_PREFIXES[$i]+isset} ]; then
      path_prefix=
    else
      path_prefix="/${D__MANIFEST_LINE_PREFIXES[$i]}"
    fi

    # Set default flags
    flag_r=false  # RegEx flag
    flag_d=false  # Deployment-dir-only flag
    flag_o=false  # Optional flag
    flag_n=false  # No-queue flag
    flag_p=false  # Provided-only flag
    flag_f=false  # Force flag

    # Extract flags
    for (( j=0; j<${#D__MANIFEST_LINE_FLAGS[$i]}; j++ )); do
      case ${D__MANIFEST_LINE_FLAGS[$i]:j:1} in
        r)  flag_r=true;;
        d)  flag_d=true;;
        o)  flag_o=true;;
        n)  flag_n=true;;
        p)  flag_p=true;;
        f)  flag_f=true;;
      esac
    done

    # Check if asset is to be contained in deployment directory
    if $flag_d; then

      # Check if pattern is intended as regex or concrete path
      if $flag_r; then

        # Line is intended as RegEx pattern

        # Set default provision marker
        asset_provided=false

        # Check if directory within dpl directory can be changed into
        if cd -- "${D__DPL_DIR}${path_prefix}" &>/dev/null; then

          # Iterate over find results on the pattern
          while IFS= read -r -d $'\0' relative_path; do

            # Set provision marker
            asset_provided=true

            # Compose relative and absolute paths
            relative_path="${relative_path#./}"
            orig_path="${D__DPL_DIR}${path_prefix}/$relative_path"

            # Check if pushing onto asset arrays
            if ! $flag_n; then

              # Push onto asset arrays now
              D_QUEUE_MAIN+=( "$relative_path" )
              D_DPL_ASSET_PATHS+=( "$orig_path" )

            fi

          done < <( d__efind -regex "^\./$path_pattern$" -print0 )

        fi

        # Check if asset is not optional and is not provided
        if ! $flag_o && ! $asset_provided; then
          
          # Announce and set failure marker
          dprint_failure \
            'Required asset is not provided by deployment author:' \
            -i "$path_pattern"
          all_good=false

        fi

      else

        # Line is intended as concrete path

        # Compose absolute paths
        orig_path="${D__DPL_DIR}${path_prefix}/$path_pattern"

        # Check if the asset is readable and if pushing onto asset arrays
        if [ -r "$orig_path" ] && ! $flag_n; then

          # Asset is copied: push onto global containers
          D_QUEUE_MAIN+=( "$path_pattern" )
          D_DPL_ASSET_PATHS+=( "$orig_path" )

        else

          # Asset not provided: if its not optional, announce and mark failure
          if ! $flag_o; then
            dprint_failure \
              'Required asset is not provided by deployment author:' \
              -i "$path_pattern"
            all_good=false
          fi

        fi

      fi

      # Do not proceed further with this dpl-dir-only asset
      continue

    fi

    # At this point, the asset is definitely not dpl-dir-only

    # Check if pattern is intended as regex or concrete path
    if $flag_r; then

      # Line is intended as RegEx pattern

      # Set default provision marker
      asset_provided=false

      # Check if directory within dpl directory can be changed into
      if cd -- "${D__DPL_DIR}${path_prefix}" &>/dev/null; then

        # Iterate over find results on the pattern
        while IFS= read -r -d $'\0' relative_path; do

          # Set provision marker
          asset_provided=true

          # Compose relative and absolute paths
          relative_path="${relative_path#./}"
          src_path="${D__DPL_DIR}${path_prefix}/$relative_path"
          dest_path="$D__DPL_ASSET_DIR/$relative_path"

          # Copy asset, or set failure marker
          d__copy_asset $flag_f "$src_path" "$dest_path" \
            || all_good=false

          # Check if pushing onto asset arrays and if limited to provided
          if ! $flag_n && $flag_p; then

            # Push onto asset arrays now
            D_QUEUE_MAIN+=( "$relative_path" )
            D_DPL_ASSET_PATHS+=( "$dest_path" )

          fi

        done < <( d__efind -regex "^\./$path_pattern$" -print0 )

      fi

      # Check if asset is not optional and is not provided
      if ! $flag_o && ! $asset_provided; then
        
        # Announce and set failure marker
        dprint_failure 'Required asset is not provided by deployment author:' \
          -i "$path_pattern"
        all_good=false

      fi

      # Check if pushing onto asset arrays and if not limited to provided
      if ! $flag_n && ! $flag_p; then

        # Check if dpl asset directory can be changed into
        if cd -- "$D__DPL_ASSET_DIR" &>/dev/null; then

          ## Iterate over find results on the pattern again, this time in asset 
          #. directory and without the prefix
          while IFS= read -r -d $'\0' relative_path; do

            # Compose relative and absolute paths
            relative_path="${relative_path#./}"
            dest_path="$D__DPL_ASSET_DIR/$relative_path"

            # Push the asset onto global containers
            D_QUEUE_MAIN+=( "$relative_path" )
            D_DPL_ASSET_PATHS+=( "$dest_path" )

          done < <( d__efind -regex "^\./$path_pattern$" -print0 )

        fi

      fi

    else

      # Line is intended as concrete path

      # Compose absolute paths
      src_path="${D__DPL_DIR}${path_prefix}/$path_pattern"
      dest_path="$D__DPL_ASSET_DIR/$path_pattern"

      # Check if the asset is readable in the deployment directory
      if [ -e "$src_path" ]; then

        # Copy asset, or set failure marker
        d__copy_asset $flag_f "$src_path" "$dest_path" \
          || all_good=false

        # Check if pushing onto asset arrays and if limited to provided
        if ! $flag_n && $flag_p; then

          # Asset is copied: push onto global containers
          D_QUEUE_MAIN+=( "$path_pattern" )
          D_DPL_ASSET_PATHS+=( "$dest_path" )

        fi

      else

        # Asset not provided: if its not optional, announce and mark failure
        if ! $flag_o; then
          dprint_failure \
            'Required asset is not provided by deployment author:' \
            -i "$path_pattern"
          all_good=false
        fi

      fi

      # Check if pushing onto asset arrays and if not limited to provided
      if ! $flag_n && ! $flag_p; then

        # Check if asset is present in asset directory
        if [ -r "$dest_path" ]; then

          # Push the asset onto global containers
          D_QUEUE_MAIN+=( "$path_pattern" )
          D_DPL_ASSET_PATHS+=( "$dest_path" )

        fi

      fi

    fi

  # Done iterating over $D__MANIFEST_LINES entries
  done

  # If there is a terminal queue split, insert it
  if [ "$D__MANIFEST_TERMINAL_SPLIT" = true ]; then d__queue_split; fi

  # Check overall status
  if $all_good; then
    
    # All assets green: return success
    return 0
    
  else
  
    # Report and return error
    dprint_failure 'Failed to process deployment assets'
    return 1

  fi
}

#>  d__process_queue_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D_DPL_QUE_PATH. Parses it and 
#. assigns the extracted entries to $D_QUEUE_MAIN. If queue manifest is not 
#. available, does nothing.
#
## Requires:
#.  $D_DPL_QUE_PATH     - Path to queue manifest file
#
## Provides into the global scope:
#.  $D_QUEUE_MAIN   - Array of main queue entries
#
## Returns:
#.  0 - Always
#
d__process_queue_manifest_of_current_dpl()
{
  # Attempt to process the queue manifest
  if d__process_manifest "$D_DPL_QUE_PATH"; then

    # Queue manifest exists and is now processed

    # Check if main queue is already filled up
    if [ ${#D_QUEUE_MAIN[@]} -gt 1 -o -n "$D_QUEUE_MAIN" ]; then

      # This is either manual queue, or one left over from asset manifest

      # Declare that queue manifests overrides the queue
      dprint_debug 'Queue manifest overwrites previous queue'

    fi

    # Assign collected items to main queue
    D_QUEUE_MAIN=( "${D__MANIFEST_LINES[@]}" )

  fi

  # Always return zero
  return 0
}

#>  d__copy_asset FORCE_FLAG REL_PATH SRC_PATH DEST_PATH
#
## If force flag is 'true', the asset is copied unless DEST_PATH is already a 
#. byte-by-byte copy of the SRC_PATH. Otherwise the asset is copied only if 
#. DEST_PATH does not exist at all.
#
## Returns:
#.  0 - Asset is in place as required
#.  1 - Otherwise
#
d__copy_asset()
{
  # Extract flag and absolute paths
  local force; [ "$1" = true ] && force=true || force=false; shift; 
  local src_path="$1"; shift
  local dest_path="$1"; shift

  # Check if source is readable
  if [ -r "$src_path" ]; then

    # Check if destination path exists
    if [ -e "$dest_path" ]; then

      # Destination path exists: check if forcing
      if $force; then

        # If source and destination are byte-by-byte copies, return success
        cmp -s "$src_path" "$dest_path" && return 0

        # Check if file is a readme
        if [ -f "$dest_path" ] \
          && [[ "$( basename -- "$dest_path" )" =~ ^README(\.[a-z]+)?$ ]]
        then

          # The pre-existing file is a README

          # Overwrite READMEs without backup
          if ! rm -f -- "$dest_path"; then
            dprint_failure "Failed to remove: $dest_path" \
              -n 'while updating to newer version'
            return 1
          fi

        else

          # Compose backup location for destination
          local backup_path="$dest_path-backup"

          # Check if that backup location is occupied
          if [ -e "$backup_path" ]; then

            # Location occupied: try alternatives
            local i=1
            while ((i<=1000)); do
              if [ -e "${backup_path}${i}" ]; then
                ((++i))
              else
                backup_path="${backup_path}${i}"
                break
              fi
            done

          fi

          # If unable to settle on backup location, report and return error
          if [ -e "$backup_path" ]; then
            dprint_failure "Failed to find a backup slot for: $dest_path"
            return 1
          fi

          # Move pre-existing destination to backup location, or return error
          if mv -n -- "$dest_path" "$backup_path" &>/dev/null; then
            dprint_alert 'Replacing asset with a newer version:' \
              -i "$dest_path"
          else
            dprint_failure "Failed to move: $dest_path" -n "to: $backup_path"
            return 1
          fi

        fi

      else

        # Destination path exists and not forcing: return success
        return 0

      fi

    fi

    # At this point destination path is empty

    # Compose destination's parent path
    dest_parent_path="$( dirname -- "$dest_path" )"

    # Ensure target directory is available
    if ! mkdir -p -- "$dest_parent_path" &>/dev/null; then

      # Report and return failure
      dprint_failure "Failed to create directory: $dest_parent_path"
      return 1
    
    fi

    # Copy initial version to assets directory
    if ! cp -Rn -- "$src_path" "$dest_path" &>/dev/null; then
      
      # Report and return failure
      dprint_failure "Failed to copy: $src_path" -n "to: $dest_path"
      return 1
    
    fi

  else

    # Source file is not readable: report and return error
    dprint_failure "Unreadable deployment asset: $src_path"
    return 1

  fi

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
#.  * '*.dpl.mnf'     - Divine deployment asset manifest
#.  * '*.dpl.que'     - Divine deployment queue manifest
#.  * 'Divinefile'    - Special kind of Divine deployment for handling system 
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
#.  $D__MANIFEST_SPLITS           - (array) For each extracted line, this array 
#.                                  will contain the string 'true' at the same 
#.                                  index iff there is a queue split _before_ 
#.                                  that line
#.  $D__MANIFEST_TERMINAL_SPLIT   - If there is a queue split after the very 
#.                                  last line, this variable will be set to 
#.                                  'true'
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
  D__MANIFEST_SPLITS=()
  D__MANIFEST_TERMINAL_SPLIT=false

  # Extract path
  local mnf_filepath="$1"; shift

  # Check if manifest if a readable file, or return immediately
  [ -r "$mnf_filepath" -a -f "$mnf_filepath" ] || return 1

  # Announce
  dprint_debug "Processing manifest at: $mnf_filepath"

  # Storage variables
  local line_from_file line_continuation=false
  local buffer buffer_backup
  local chunk tmp tmp_l tmp_r key value value_array
  local i x y z

  # Status variables
  local ongoing_relevance ongoing_flags ongoing_prefix ongoing_priority
  local current_relevance current_flags current_prefix current_priority
  local split_before_next_entry

  # Initial (default) statuses
  ongoing_relevance=true
  ongoing_flags=
  ongoing_prefix=
  ongoing_priority="$D__CONST_DEF_PRIORITY"
  split_before_next_entry=false

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

      # Repeat until last character before split is not '\'
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

      # Done repeating until last character before split is not '\'
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

      # Repeat until last character before split is not '\'
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

      # Done repeating until last character before split is not '\'
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
            # If value is empty, all OS's are allowed
            if [ -z "$value" ]; then current_relevance=true; continue; fi

            # Check if the list of OS's starts with '!'
            if [[ $value = '!'* ]]; then

              # Strip the '!' and re-trim the list
              value="${value:1:${#value}}"
              read -r value <<<"$value"

              ## If value is empty, all OS's are allowed (negation of empty 
              #. list is not allowed)
              if [ -z "$value" ]; then current_relevance=true; continue; fi

              # Read value as vertical bar-separated list of relevant OS's
              IFS='|' read -r -a value_array <<<"$value"

              # Set default value
              current_relevance=true

              # Iterate over list of negated OS's
              for value in "${value_array[@]}"; do

                # Clear whitespace from edges of OS name
                read -r value <<<"$value"

                # If value is either 'all' or 'any', all OS's are negated
                case $value in
                  all|any) current_relevance=false; break;;
                esac

                # Check if current OS name from the list matches detected OS
                if [[ $value = $D__OS_FAMILY || $value = $D__OS_DISTRO ]]; then

                  # Flip flag
                  current_relevance=false

                fi

              # Done iterating over list of relevant OS's
              done

            else

              # Normal list, does not stasrt with '!'

              # Read value as vertical bar-separated list of relevant OS's
              IFS='|' read -r -a value_array <<<"$value"

              # Set default value
              current_relevance=false

              # Iterate over list of relevant OS's
              for value in "${value_array[@]}"; do

                # Clear whitespace from edges of OS name
                read -r value <<<"$value"

                # If value is either 'all' or 'any', all OS's are allowed
                case $value in
                  all|any) current_relevance=true; break;;
                esac

                # Check if current OS name from the list matches detected OS
                if [[ $value = $D__OS_FAMILY || $value = $D__OS_DISTRO ]]; then

                  # Flip flag and stop further list processing
                  current_relevance=true
                  break

                fi

              # Done iterating over list of relevant OS's
              done

            fi
            ;;
          flags)
            # Remove all whitespace from within the value
            value="${value//[[:space:]]/}"

            # Check if the list of flags starts with '+'
            if [[ $value = '+'* ]]; then

              # Strip the '+'
              value="${value:1:${#value}}"

              # Append to current flags
              current_flags+="$value"

            else

              # Replace current flags
              current_flags="$value"

            fi
            ;;
          prefix)
            # Clear leading and trailing slashes, if any
            while [[ $value = /* ]]; do value="${value##/}"; done
            while [[ $value = */ ]]; do value="${value%%/}"; done
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
          queue)
            # If the value is not precisely 'split', ignore this key-value
            [[ $value = 'split' ]] || continue

            # Set marker for upcoming split
            split_before_next_entry=true
            ;;
          *)
            # Unsupported key: ignore this key-value
            continue
            ;;
        esac

      else

        # Key-value parentheses do not contain a separator (':')

        # Special case: without separator, interpret key as flags value

        # Remove all whitespace from within the value
        chunk="${chunk//[[:space:]]/}"

        # Check if the list of flags starts with '+'
        if [[ $chunk = '+'* ]]; then

          # Strip the '+'
          chunk="${chunk:1:${#chunk}}"

          # Append to current flags
          current_flags+="$chunk"

        else

          # Replace current flags
          current_flags="$chunk"

        fi

      fi

    ## Done repeating until line no longer starts with opening parenthesis and 
    #. contains closing one
    done

    # Trim whitespace on both edges of remaining buffer
    read -r buffer <<<"$buffer"

    # Check if remaining buffer ends with '\'
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

    # Check if the line proper starts with an escape character ('\')
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

      # No line remaining: this line's key-values become ongoing
      ongoing_relevance="$current_relevance"
      ongoing_flags="$current_flags"
      ongoing_prefix="$current_prefix"
      ongoing_priority="$current_priority"

      # Go to next line
      continue

    fi

    # Finally, add this line and it's parameters to global array
    D__MANIFEST_LINES+=( "$buffer" )
    D__MANIFEST_LINE_FLAGS+=( "$current_flags" )
    D__MANIFEST_LINE_PREFIXES+=( "$current_prefix" )
    D__MANIFEST_LINE_PRIORITIES+=( "$current_priority" )
    D__MANIFEST_SPLITS+=( "$split_before_next_entry" )

    # Clear upcoming split marker
    split_before_next_entry=false

    # Clear buffer
    buffer=

  # Done iterating over lines in manifest file
  done <"$mnf_filepath"

  ## Check if last line was a relevant non-empty orphan (happens when file ends 
  #. with '\')
  if [ "$line_continuation" = true \
    -a -n "$buffer" \
    -a "$current_relevance" = true ]
  then

    ## Last line needs to be processed. Key-values and comments are both 
    #. already processed, and status variables remain in relevant state
    
    # Add this line and it's parameters to global array
    D__MANIFEST_LINES+=( "$buffer" )
    D__MANIFEST_LINE_FLAGS+=( "$current_flags" )
    D__MANIFEST_LINE_PREFIXES+=( "$current_prefix" )
    D__MANIFEST_LINE_PRIORITIES+=( "$current_priority" )
    D__MANIFEST_SPLITS+=( "$split_before_next_entry" )

    # Clear upcoming split marker
    split_before_next_entry=false

  fi

  # Populate terminal split marker with the relevant value
  D__MANIFEST_TERMINAL_SPLIT="$split_before_next_entry"

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Return success
  return 0
}