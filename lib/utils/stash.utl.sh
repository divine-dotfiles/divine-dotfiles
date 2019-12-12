#!/usr/bin/env bash
#:title:        Divine Bash utils: stash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    Make stash skip checks by default
#:created_at:   2019.05.15

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Utility for any deployments and framework components that require persistent 
#. state
#
## Stashing allows to create/retrieve/update/delete key-value pairs that 
#. persist between invocations of deployment scripts. Each deployment gets its 
#. own stash. Stash files are named '.stash.cfg'.
#

# Marker and dependencies
readonly D__UTL_STASH=loaded
d__load procedure prep-sys
d__load util workflow
d__load procedure prep-md5

#>  d__stash [-drgsq] [--] [ CMD [ KEY [VALUE] ] ]
#
## Main interface into the stash, be that on deployment, root, or Grail level. 
#. Dispatches task based on first non-opt argument.
#
## Performs given CMD, where each CMD has its own requirements on presence of 
#. KEY and VALUE.
#
## Stash key, when required, must be a string of alphanumeric characters, 
#. underscores '_', and hyphens '-'. Stash values may contain any characters 
#. except newlines; whitespace on both edges will be stripped. Empty values are 
#. allowed.
#
## Stash is NOT a hash table: multiple instances of the same key are allowed. 
#. Keys set to empty values are allowed as well.
#
## CMD patterns:
#.  ready             - (default) Ensures that stashing system is ready; 
#.                      returns non-zero if not. Checks differ based on stash 
#.                      level. These checks are normally run for every CMD.
#.  has KEY [VALUE]   - Checks if stash contains KEY that is set to VALUE, or 
#.                      if it contains KEY with any value.
#.  set KEY [VALUE]   - Ensures that there is a single instance of KEY and that 
#.                      it is set to VALUE; VALUE can be empty.
#.  add KEY [VALUE]   - Adds record of KEY set to VALUE, regardless of whether 
#.                      stash already contains KEY; VALUE can be empty.
#.  get KEY           - Prints first value of KEY to stdout.
#.  list KEY          - Prints each value of KEY on a line to stdout.
#.  unset KEY [VALUE] - Removes records for KEY from stash; either where set to 
#.                      VALUE, or completely.
#.  list-keys         - Prints each KEY in STASH on a line to stdout; does not 
#.                      prune duplicates.
#.  clear             - Erases all stash records completely.
#
## Options:
#.  -c|--do-checks    - Runs pre-flight stash readiness checks. These checks 
#.                      are automatically run by the framework for every 
#.                      deployment, so there is practically no need to use this 
#.                      option manually.
#.  -s|--skip-checks  - (default) This option directs to skip most pre-flight 
#.                      readiness checks.
#.  -q|--quiet        - Makes stash errors (including critical ones) much less 
#.                      visible in the debug output. This is intended for cases 
#.                      when not using stash is also a viable option.
#
## Stash level (one is active at a time, last option wins):
#.  -d|--dpl    - (default) Use deployment stash. Deployment stash is stored 
#.                under state directory, in a directory named after the current 
#.                deployment. As deployment names are unique, no more than one 
#.                deployment uses a given deployment stash.
#.  -r|--root   - Use root stash. Root stash is stored in the root state 
#.                directory, where it is shared by all deployments and 
#.                framework components on current machine. Divine.dotfiles 
#.                employs root stash during installation of the framework, to 
#.                record installation path of the shortcut shell command.
#.  -g|--grail  - Use Grail stash. Grail stash is stored in Grail directory, 
#.                where it may be synced between machines. Divine.dotfiles 
#.                employs Grail stash to record bundles attached by user.
#
## Returns:
#.  0 - Task performed
#.  1 - Meaning differs between tasks
#.  2 - Stashing system is not operational
#.  3 - Called with an unrecognized routine name
#
d__stash()
{
  # Parse options
  local args=() arg opt i
  local stash_level=d  # stash level option container
  local opt_checks=false  # checks option container
  local opt_qt=false  # verbosity option container
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)              args+=("$@"); break;;
          d|-dpl)         stash_level=d;;
          r|-root)        stash_level=r;;
          g|-grail)       stash_level=g;;
          c|-do-checks)   opt_checks=true;;
          s|-skip-checks) opt_checks=false;;
          q|-quiet)       opt_qt=true;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"
                case $opt in
                  d)  stash_level=d;;
                  r)  stash_level=r;;
                  g)  stash_level=g;;
                  c)  opt_checks=true;;
                  s)  opt_checks=false;;
                  q)  opt_qt=true;;
                  *)  d__notify -l!t "$FUNCNAME" -- \
                        "Ignoring unrecognized option: '$opt'";;
                esac
              done;;
        esac;;
    *)  args+=("$arg");;
  esac; done; set -- "${args[@]}"

  # Initialize local variables
  local stash_filepath  # path to file with stash records
  local stash_md5_filepath  # path to file with stash checksum
  local arg_task=ready  # name of stashing task to perform (1st arg)
  local arg_key; unset arg_key  # stash key (2nd arg)
  local arg_val; unset arg_val  # stash value (3rd arg)

  # Sort out options for debug and error output
  local out_opts  # options for debug output
  local err_opts  # options for error output
  case $stash_level in
    r)  out_opts="t 'Root stash'";;
    g)  out_opts="t 'Grail stash'";;
    *)  out_opts="t 'Dpl stash'";;
  esac
  $opt_qt && err_opts="-qq$out_opts" || err_opts="-lx$out_opts"
  out_opts="-qqq$out_opts"

  # Extract arguments
  if (($#)); then arg_task="$1"; shift; fi
  if (($#)); then arg_key="$1"; shift; fi
  if (($#)); then arg_val="$1"; shift; fi

  # Run pre-flight checks
  [ "$arg_task" = ready ] && opt_checks=true
  d___check_stashing_system || return 2

  # Dispatch appropriate task
  case $arg_task in
    ready)      :;;
    has)        d___validate_stash_key "$arg_key" && d___stash_has;;
    set)        d___validate_stash_key "$arg_key" && d___stash_set;;
    add)        d___validate_stash_key "$arg_key" && d___stash_add;;
    get)        d___validate_stash_key "$arg_key" && d___stash_get;;
    list)       d___validate_stash_key "$arg_key" && d___stash_list;;
    unset)      d___validate_stash_key "$arg_key" && d___stash_unset;;
    list-keys)  d___stash_list_keys;;
    clear)      d___stash_clear;;
    *)          d__notify $err_opts -- \
                  "Refusing to work with unrecognized routine: '$arg_task'"
                return 3
                ;;
  esac

  # Explicitly return the last return code
  return $?
}

#>  d___validate_stash_key KEY
#
## INTERNAL USE ONLY
#
## Checks if KEY is safe for stashing. Practically, it means ensuring that key 
#. consists of allowed characters only: ASCII letters (both cases) and digits, 
#. underscore '_', and hyphen '-'.
#
## In:
#>  $arg_key
#>  $err_opts
#
## Returns:
#.  0 - Key is acceptable.
#.  1 - Otherwise.
#
d___validate_stash_key()
{
  if [ -z "$arg_key" ]; then
    d__notify $err_opts -- 'Empty stash key given; must be non-empty'
    return 1
  elif ! [[ $arg_key =~ ^[a-zA-Z0-9_-]+$ ]]; then
    d__notify $err_opts -- "Illegal stash key: '$arg_key'" -n- \
      "Allowed characters: alphanumeric chars, underscore'_', and hyphen '-'"
    return 1
  fi
  return 0
}

#>  d___stash_has
#
## INTERNAL USE ONLY
#
## Checks whether $arg_key is currently set to any value, including empty 
#. string. If $arg_val is given, checks if there is at least one occurrence of 
#. $arg_key set to $arg_val. Key is assumed to be validated.
#
## In:
#>  $arg_key
#>  $arg_val
#>  $stash_filepath
#>  $out_opts
#
## Returns:
#.  0 - Value not given:  key is present
#.      Value given:      key with that value is present
#.  1 - Otherwise
#
d___stash_has()
{
  # Fork depending on whether a value is given
  if [ -z "${arg_val+isset}" ]; then
    d__notify $out_opts -- "Checking for key '$arg_key'"
    grep -q ^"$arg_key"= -- "$stash_filepath" &>/dev/null || return 1
  else
    d__notify $out_opts -- \
      "Checking for key '$arg_key' with value '$arg_val'"
    grep -Fxq "$arg_key=$arg_val" -- "$stash_filepath" &>/dev/null || return 1
  fi
}

#>  d___stash_set
#
## INTERNAL USE ONLY
#
## Ensures there is a single instance of $arg_key, and that it is set to $arg_val, 
#. even if the value is empty.
#
## In:
#>  $arg_key
#>  $arg_val
#>  $stash_filepath
#>  $stash_md5_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Otherwise
#
d___stash_set()
{
  # Announce
  d__notify $out_opts -- "Setting key '$arg_key' to value '$arg_val'"
  local tmp_file=$(mktemp)  # buffer for building new stash file
  local line_buf  # buffer for holding current line
  local alr_has=false  # flag for whether stash already contains this k-v
  local should_replace=false  # flag for whether temp file should replace stash

  # Iterate over lines in current stash file
  while read -r line_buf; do

    # Check if current line is for the required key
    if [[ $line_buf = "$arg_key="* ]]; then
      # If already surely replacing, just skip this line
      $should_replace && continue
      # Check if current line sets the required value
      if [ "$line_buf" = "$arg_key=$arg_val" ]; then
        ## This is the required line: if not yet found, copy it to temp, 
        #. otherwise this is a duplicate, and we should replace anyway.
        #
        if $alr_has; then should_replace=true
        else printf '%s\n' "$line_buf"; alr_has=true; fi
      else
        # This key is set to the wrong value: skip line and set flag
        should_replace=true
      fi
    else
      # Regular line, with different key: copy to temp
      printf '%s\n' "$line_buf"
    fi

  done <"$stash_filepath" >$tmp_file

  # Check if required key-value has been found and copied to temp file
  if ! $alr_has; then
    # Not found: append manually and set flag
    printf '%s\n' "$arg_key=$arg_val" >>$tmp_file
    should_replace=true
  fi

  # Check if assembled temp file needs to replace the original
  if $should_replace; then
    # Move temp to location of stash file
    if ! mv -f -- $tmp_file "$stash_filepath"; then
      d__notify $err_opts -- "Failed to move temp file from: $tmp_file" \
        -n- "to: $stash_filepath" -n- 'while setting keys'
      return 1
    fi
    # Update stash file checksum and return zero always
    d___stash_store_md5; return 0
  else
    # If there is no need for replacing, erase the temp file and return zero
    rm -f -- $tmp_file; return 0
  fi
}

#>  d___stash_add
#
## INTERNAL USE ONLY
#
## Adds new occurrence of $arg_key and sets it to $arg_val, even if the value is 
#. empty.
#
## In:
#>  $arg_key
#>  $arg_val
#>  $stash_filepath
#>  $stash_md5_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Otherwise
#
d___stash_add()
{
  # Announce
  d__notify $out_opts -- "Adding to key '$arg_key' value '$arg_val'"
  
  # Append record at the end
  if ! printf '%s\n' "$arg_key=$arg_val" >>"$stash_filepath"; then
    d__notify $err_opts -- "Failed to add record: '$arg_key=$arg_val'" \
      -n- "in stash file at: $stash_filepath"
    return 1
  fi

  # Update stash file checksum and return zero regardless
  d___stash_store_md5; return 0
}

#>  d___stash_get
#
## INTERNAL USE ONLY
#
## Prints value of first instance of $arg_key to stdout. If the value is empty, 
#. prints empty string. If $arg_key does not exist, prints nothing and returns 
#. non-zero.
#
## In:
#>  $arg_key
#>  $stash_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - Instance of $arg_key is found, its value is printed
#.  1 - Otherwise: $arg_key not found, or other failure
#
d___stash_get()
{
  # Announce
  d__notify $out_opts -- "Retrieving value for key '$arg_key'"
  
  # Search for the $arg_key
  local result="$( grep -m 1 ^"$arg_key"= -- "$stash_filepath" 2>/dev/null \
    || exit $? )"

  # If grep returned non-zero, pass it along
  if (($?)); then return 1; fi

  # Print the result, chopping off the '$arg_key=' part from it
  printf '%s\n' "${result#$arg_key=}"
}

#>  d___stash_list
#
## INTERNAL USE ONLY
#
## For each instance of $arg_key, prints its value to its own line in stdout, even 
#. if the value is empty. If key does not exist prints nothing and returns 
#. non-zero.
#
## In:
#>  $arg_key
#>  $stash_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - At least one instance of $arg_key is found, values are printed
#.  1 - Otherwise: $arg_key not found, or other failure
#
d___stash_list()
{
  # Announce
  d__notify $out_opts -- "Listing values for key '$arg_key'"
  
  # Storage variables
  local match_found=false left right

  # Iterate over grep results, break on first '=', print the right part
  while read -r left; do
    IFS='=' read -r left right <<<"$left "
    printf '%s\n' "${right::${#right}-1}"; match_found=true
  done < <( grep ^"$arg_key"= -- "$stash_filepath" 2>/dev/null )

  # Return based on whether at least one result was there
  $match_found && return 0 || return 1
}

#>  d___stash_unset
#
## INTERNAL USE ONLY
#
## Unsets (removes) all instances of $arg_key. If $arg_val is given, unsets only 
#. those instances of $arg_key, that are currently set to $arg_val.
#
## In:
#>  $arg_key
#>  $arg_val
#>  $stash_filepath
#>  $stash_md5_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - Task performed successfully.
#.  1 - Otherwise: failed to perform unsetting (key-values likely remain).
#
d___stash_unset()
{  
  # Storage variables
  local tmp_file=$(mktemp) line_buf

  # Fork depending on whether a value is given
  if [ -z "${arg_val+isset}" ]; then

    # No value: copy stash file, but without lines starting with '$arg_key='
    d__notify $out_opts -- "Unsetting key '$arg_key'"
    while read -r line_buf; do
      [[ $line_buf = "$arg_key="* ]] || printf '%s\n' "$line_buf"
    done <"$stash_filepath" >$tmp_file

  else

    # Value given: copy stash file, but without lines '$arg_key=$arg_val'
    d__notify $out_opts -- \
      "Unsetting key '$arg_key' with value '$arg_val'"
    while read -r line_buf; do
      [ "$line_buf" = "$arg_key=$arg_val" ] || printf '%s\n' "$line_buf"
    done <"$stash_filepath" >$tmp_file

  fi

  # Move temp to location of stash file
  if ! mv -f -- $tmp_file "$stash_filepath"; then
    d__notify $err_opts -- "Failed to move temp file from: $tmp_file" \
      -n- "to: $stash_filepath" -n- 'while unsetting keys'
    return 1
  fi

  # Update stash file checksum and return zero always
  d___stash_store_md5; return 0
}

#>  d___stash_list_keys
#
## INTERNAL USE ONLY
#
## Prints each KEY currently in the stash to its own line in stdout. If there 
#. are no keys, prints nothing and returns non-zero.
#
## In:
#>  $stash_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - Successfully printed at least one key
#.  1 - Otherwise: zero keys or other failure
#
d___stash_list_keys()
{
  # Announce
  d__notify $out_opts -- 'Listing all keys'
  
  # Storage variables
  local match_found=false left right

  # Iterate over lines in stash file, break on first '=', print the left part
  while IFS='=' read -r left right; do
    printf '%s\n' "$left" && match_found=true
  done <"$stash_filepath"

  # Return based on results
  $match_found && return 0 || return 1
}

#>  d___stash_clear
#
## INTERNAL USE ONLY
#
## Erases the stash completely.
#
## In:
#>  $stash_filepath
#>  $stash_md5_filepath
#>  $out_opts
#>  $err_opts
#
## Returns:
#.  0 - (always) Successfully erased
#
d___stash_clear()
{
  # Announce
  d__notify $out_opts -- 'Clearing all contents'
  
  # Erase stash file
  >"$stash_filepath"

  # Update stash file checksum and return zero always
  d___stash_store_md5; return 0
}

#>  d___check_stashing_system
#
## INTERNAL USE ONLY
#
## Helper function that ensures that stashing is good to go
#
## In:
#>  $stash_level
#>  $opt_checks
#>  $stash_filepath
#>  $stash_md5_filepath
#>  $err_opts
#
## Out:
#<  $stash_filepath
#<  $stash_md5_filepath
#
## Returns:
#.  0 - Ready for stashing
#.  1 - Otherwise
#
d___check_stashing_system()
{
  # Check if extended diagnostics are required, fire initial debug message
  if $opt_checks; then

    # Сheck for necessary variables
    case $stash_level in
      r)  if [ -n "$D__DIR_STASH" ]; then
            d__notify -qq -- 'Preparing root-level stash'
          else
            d__notify $err_opts -- \
              'Root-level stash has been accessed with empty $D__DIR_STASH'
            return 1
          fi
          ;;
      g)  if [ -n "$D__DIR_GRAIL" ]; then
            d__notify -qq -- 'Preparing Grail-level stash'
          else
            d__notify $err_opts -- \
              'Grail-level stash has been accessed with empty $D__DIR_GRAIL'
            return 1
          fi
          ;;
      *)  if [ -n "$D_DPL_NAME" ]; then
            d__notify -qq -- "Preparing stash for deployment '$D_DPL_NAME'"
          else
            d__notify $err_opts -- \
              'Dpl-level stash has been accessed with empty $D_DPL_NAME'
            return 1
          fi
          if ! [ -n "$D__DIR_STASH" ]; then
            d__notify $err_opts -- \
              'Dpl-level stash has been accessed with empty $D__DIR_STASH'
            return 1
          fi
          ;;
    esac

    # Check if name for stash file is set globally
    if ! [ -n "$D__CONST_NAME_STASHFILE" ]; then
      d__notify $err_opts -- \
        'Stashing has been accessed with empty $D__CONST_NAME_STASHFILE'
      return 1
    fi

  fi  

  # Establish stash directory; set title of debug messages
  local stash_dirpath
  case $stash_level in
    r)  stash_dirpath="$D__DIR_STASH";;
    g)  stash_dirpath="$D__DIR_GRAIL";;
    *)  stash_dirpath="$D__DIR_STASH/$D_DPL_NAME";;
  esac

  # Ensure directory for this stash exists
  if ! mkdir -p -- "$stash_dirpath"; then
    d__notify $err_opts -- \
      "Failed to create stash directory at: $stash_dirpath"
    return 1
  fi

  # Compose path to stash file and its checksum file
  stash_filepath="$stash_dirpath/$D__CONST_NAME_STASHFILE"
  stash_md5_filepath="$stash_filepath.md5"

  # Check if extended diagnostics are required
  if $opt_checks; then

    # Ensure path to stash file is not occupied by not-file
    if [ -e "$stash_filepath" -a ! -f "$stash_filepath" ]; then
      d__notify $err_opts -- \
        "Stash filepath occupied by a non-file: $stash_filepath"
      return 1
    fi

    # Ensure path to stash md5 file is not occupied by not-file
    if [ -e "$stash_md5_filepath" -a ! -f "$stash_md5_filepath" ]; then
      d__notify $err_opts -- \
        "Stash checksum filepath occupied by a non-file: $stash_md5_filepath"
      return 1
    fi

    # Check if stash file exists
    if [ ! -e "$stash_filepath" ]; then

      # Touch up a fresh empty file
      if ! touch -- "$stash_filepath"; then
        d__notify $err_opts -- \
          "Failed to create fresh stash file at: $stash_filepath"
        return 1
      fi

      # Store md5 of empty file
      if ! d__md5 "$stash_filepath" >"$stash_md5_filepath"; then
        d__notify $err_opts -- \
          "Failed to create stash checksum file at: $stash_md5_filepath"
        return 1
      fi

    fi

    # Ensure stash file is a writable files
    if ! [ -w "$stash_filepath" ]; then
      d__notify $err_opts -- "Stash filepath is not writable: $stash_filepath"
      return 1
    fi

    # Ensure stash checksum file is a writable files
    if ! [ -w "$stash_md5_filepath" ]; then
      d__notify $err_opts -- \
        "Stash checksum filepath is not writable: $stash_md5_filepath"
      return 1
    fi

  fi

  # Ensure checksum is good
  d___stash_check_md5 || return 1

  # Return
  return 0
}

#>  d___stash_store_md5
#
## INTERNAL USE ONLY
#
## Stores calculated md5 checksum of stash file into pre-defined file. No file 
#. existence checks are performed
#
## In:
#>  $stash_filepath
#>  $stash_md5_filepath
#
## Returns:
#.  0 - Successfully stored checksum
#.  1 - Otherwise
#
d___stash_store_md5()
{
  # Store current md5 checksum to intended file, or report error
  d__md5 "$stash_filepath" >"$stash_md5_filepath" && return 0
  d__notify $err_opts -- \
    "Failed to create stash checksum file at: $stash_md5_filepath"
  return 1
}

#>  d___stash_check_md5
#
## INTERNAL USE ONLY
#
## Checks whether checksum file at pre-defined path contains current md5 hash 
#. of stash file. If not, issues a warning and prompts user on whether they 
#. which to continue anyway. If they do, updates stored checksum.
#
## In:
#>  $stash_filepath
#>  $stash_md5_filepath
#
## Returns:
#.  0 - Either checksum matches, or user is okay with mismatch
#.  1 - Otherwise
#
d___stash_check_md5()
{
  # Extract stored md5
  local stored_md5="$( head -1 -- "$stash_md5_filepath" 2>/dev/null )"

  # If checksums match: return immediately
  [ "$stored_md5" = "$( d__md5 "$stash_filepath" )" ] && return 0

  # Check if stored md5 is valid-ish
  if [ ${#stored_md5} -eq 32 ]; then

    # Stored checksum is likely valid, but does not match

    # Report error, prompt user
    d__notify -lx -- "Mismatched checksum on stash file: $stash_filepath"
    d__prompt -xhap "$D__OPT_ANSWER" 'Ignore incorrect checksum?' -- \
      "Current checksum of stash file: $stash_filepath" \
      -n- "does not match stored checksum in: $stash_md5_filepath" \
      -n- 'This suggests manual tinkering with framework directories'

  else

    # Stored checksum is either garbage or non-existent

    # Report error, prompt user
    d__notify -lx -- "Missing checksum on stash file: $stash_filepath"
    d__prompt -xhap "$D__OPT_ANSWER" 'Ignore missing checksum?' -- \
      "There is no stored checksum for stash file at: $stash_filepath" \
      -n- 'This suggests manual tinkering with framework directories'

  fi

  # Check response
  if [ $? -eq 0 ]; then

    # Put the correct checksum into place
    d___stash_store_md5

    # Warn of the decision and return
    d__notify -l! -- 'Working with unverified stash'
    return 0

  else

    # Warn of the decision and return
    d__notify -lx -- 'Refused to work with unverified stash'
    return 1

  fi
}