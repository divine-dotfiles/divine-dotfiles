#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: stash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    9
#:revdate:      2019.09.05
#:revremark:    Do rough implementations: list-keys, has K V
#:created_at:   2019.05.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function for any deployments that require persistent state
#
## Stashing allows to create/retrieve/update/delete key-value pairs that 
#. persist between invocations of deployment scripts. Each deployment gets its 
#. own stash. Stash files are named '.stash.cfg'.
#

#>  dstash [-rgs] [--] [ CMD [ KEY [VALUE] ] ]
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
#.  -s|--skip-checks  - Normally, pre-flight stash readiness checks are run for 
#.                      every CMD. This option directs to skip most checks. If 
#.                      this function is invoked multiple times in the same 
#.                      context, it is advisable to include this option in all 
#.                      but the very first call.
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
#
dstash()
{
  # Parse options
  local args=() opts opt i
  local stash_mode= do_checks=true
  while (($#)); do
    case $1 in
      --)               shift; args+=("$@"); break;;
      -d|--dpl)         stash_mode=;;
      -r|--root)        stash_mode=-r;;
      -g|--grail)       stash_mode=-g;;
      -s|--skip-checks) do_checks=false;;
      -*)   opts="$1"; shift
            for (( i=1; i<${#opts}; ++i )); do
              opt="${opts:i:1}"
              case $opt in
                d)  stash_mode=;;
                r)  stash_mode=-r;;
                g)  stash_mode=-g;;
                s)  do_checks=false;;
                *)  dprint_debug \
                      "${FUNCNAME}: Ignoring unrecognized option: '$opt'"
                    ;;
              esac
            done
            continue
            ;;
      *)    args+=("$1");;
    esac; shift
  done; set -- "${args[@]}"

  # Perform pre-flight checks first, unless ordered to skip
  if $do_checks; then
    d__stash_pre_flight_checks $stash_mode || return 2
  else
    # Without checks, just populate necessary paths
    local stash_dirpath
    case $stash_mode in
      -g) stash_dirpath="$D__DIR_GRAIL";;
      -r) stash_dirpath="$D__DIR_STASH";;
      *)  stash_dirpath="$D__DIR_STASH/$D_DPL_NAME";;
    esac
    D__STASH_FILEPATH="$stash_dirpath/$D__CONST_NAME_STASHFILE"
    D__STASH_MD5_FILEPATH="$D__STASH_FILEPATH.md5"
  fi

  # Quick return without arguments (equivalent of dstash ready)
  (($#)) || return 0

  # Dispatch task based on first argument
  local task="$1"; shift
  case $task in
    ready)      return 0;;
    has)        d__stash_has "$@";;
    set)        d__stash_set "$@";;
    add)        d__stash_add "$@";;
    get)        d__stash_get "$@";;
    list)       d__stash_list "$@";;
    unset)      d__stash_unset "$@";;
    list-keys)  d__stash_list_keys "$@";;
    clear)      >"$D__STASH_FILEPATH" && return 0 || return 1;;
    *)  dprint_debug "${FUNCNAME}: Ignoring unrecognized task: '$task'"
        return 0
        ;;
  esac

  # Return status of dispatched command
  return $?
}

#>  d__stash_has [-s] KEY [VALUE]
#
## Checks whether KEY is currently set to any value, including empty string.
#. If VALUE is given, checks if there is at least one occurrence of KEY set to 
#. VALUE.
#
## Options:
#.  -s  - (first arg) Skip argument checks (for internal calls)
#
## Parameters:
#.  $1  - Key
#
## Returns:
#.  0 - Key is valid and is set to a value
#.  1 - Key is invalid, not provided, or is not set to a value
#
d__stash_has()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else d__stash_validate_key "$1" || return 1; fi

  # Check for existense in stash file
  if [ -n "$2" ]; then
    grep -Fxq "$1=$2" -- "$D__STASH_FILEPATH" &>/dev/null
  else
    grep -q ^"$1"= -- "$D__STASH_FILEPATH" &>/dev/null
  fi
  [ $? -eq 0 ] && return 0 || return 1
}

#>  d__stash_set KEY [VALUE]
#
## Ensures there is a single occurrence of KEY, and that it is set to VALUE. 
#. Extra arguments are ignored.
#
## Options:
#.  -s  - (first arg) Skip argument checks (for internal calls)
#
## Parameters:
#.  $1  - Key
#.  $2  - (optional) Value. Defaults to zero length string.
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Key is invalid, not provided, or failed to set key
#
d__stash_set()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else d__stash_validate_key "$1" || return 1; fi

  # If key is currently set, unset it
  if d__stash_has -s "$1"; then d__stash_unset -s "$1" || return 1; fi

  # Append record at the end
  printf '%s\n' "$1=$2" >>"$D__STASH_FILEPATH" || {
    dprint_debug 'Failed to store record:' -i "$1=$2" \
      -n 'in stash file at:' -i "$D__STASH_FILEPATH"
    return 1
  }

  # Update stash file checksum and return zero regardless
  d__stash_store_md5; return 0
}

#>  d__stash_add KEY [VALUE]
#
## Adds new occurrence of KEY and sets it to VALUE. Extra arguments are 
#. ignored.
#
## Options:
#.  -s  - (first arg) Skip argument checks (for internal calls)
#
## Parameters:
#.  $1  - Key
#.  $2  - (optional) Value. Defaults to zero length string.
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Key is invalid, not provided, or failed to set key
#
d__stash_add()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else d__stash_validate_key "$1" || return 1; fi

  # Append record at the end
  printf '%s\n' "$1=$2" >>"$D__STASH_FILEPATH" || {
    dprint_debug 'Failed to add record:' -i "$1=$2" \
      -n 'to stash file at:' -i "$D__STASH_FILEPATH"
    return 1
  }

  # Update stash file checksum and return zero regardless
  d__stash_store_md5; return 0
}

#>  d__stash_get KEY
#
## Prints first value assigned to KEY to stdout. If key does not exist prints 
#. nothing and returns non-zero. Extra arguments are ignored.
#
## Options:
#.  -s  - (first arg) Skip argument checks (for internal calls)
#
## Parameters:
#.  $1  - Key
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Key is invalid, not provided, or failed to get/print key
#
d__stash_get()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else d__stash_validate_key "$1" || return 1; fi

  # If key is currently not set, return status
  d__stash_has -s "$1" || {
    dprint_debug 'Tried to get key:' -i "$1" \
      -n 'from stash, but it is currently not set'
    return 1
  }

  # Get key's value
  local value
  value="$( grep ^"$1"= -- "$D__STASH_FILEPATH" 2>/dev/null \
    | head -1 2>/dev/null )"

  # Check if retrieval was successful
  [ $? -eq 0 ] || {
    dprint_debug 'Failed to retrieve key:' -i "$1" \
      -n 'from stash file at:' -i "$D__STASH_FILEPATH"
    return 1
  }

  # Chop off the 'key=' part
  value="${value#$1=}"

  # Print value
  printf '%s\n' "$value"
}

#>  d__stash_list KEY
#
## Prints each value of provided KEY to its own line in stdout. If key does not 
#. exist prints nothing and returns non-zero. Extra arguments are ignored.
#
## Options:
#.  -s  - (first arg) Skip argument checks (for internal calls)
#
## Parameters:
#.  $1  - Key
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Key is invalid, not provided, or failed to get/print key
#
d__stash_list()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else d__stash_validate_key "$1" || return 1; fi

  # If key is currently not set, return status
  d__stash_has -s "$1" || {
    dprint_debug 'Tried to list key:' -i "$1" \
      -n 'from stash, but it is currently not set'
    return 1
  }

  # List key's values
  local value
  while read -r value; do

    # Chop off the 'key=' part
    value="${value#$1=}"

    # Print value
    printf '%s\n' "$value"

  done < <( grep ^"$1"= -- "$D__STASH_FILEPATH" 2>/dev/null )

  # Check if retrieval was successful
  [ $? -eq 0 ] || {
    dprint_debug 'Failed to retrieve key:' -i "$1" \
      -n 'from stash file at:' -i "$D__STASH_FILEPATH"
    return 1
  }
}

#>  d__stash_unset [-s] KEY [VALUE]
#
## Unsets all instances of key or only those instances that are set to VALUE
#
## Options:
#.  -s  - (first arg) Skip argument checks (for internal calls)
#
## Parameters:
#.  $1  - Key
#
## Returns:
#.  0 - Task performed successfully
#.  1 - Key is invalid, not provided, or failed to unset key
#
d__stash_unset()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else d__stash_validate_key "$1" || return 1; fi

  # Make temporary file
  local temp="$( mktemp )"

  # Storage variable
  local line

  # Perform one of two routines depending on whether second argument is given
  if [ -n "$2" ]; then

    # Make a new stash file, but without lines where $1 is assigned value $2
    while read -r line; do
      [ "$line" = "$1=$2" ] || printf '%s\n' "$line"
    done <"$D__STASH_FILEPATH" >"$temp"

  else

    # Make a new stash file, but without lines where $1 is assigned any value
    while read -r line; do
      [[ $line = "$1="* ]] || printf '%s\n' "$line"
    done <"$D__STASH_FILEPATH" >"$temp"

  fi

  # Move temp to location of install file
  mv -f -- "$temp" "$D__STASH_FILEPATH" || {
    dprint_debug "Failed to move temp file from: $temp" \
      -n "to: $D__STASH_FILEPATH"
    return 1
  }

  # Update stash file checksum and return zero regardless
  d__stash_store_md5; return 0
}

#>  d__stash_list_keys
#
## Prints each KEY currently in the stash to its own line in stdout. If there 
#. are no keys, prints nothing. Arguments are ignored.
#
## Returns:
#.  0 - Always
#
d__stash_list_keys()
{
  # Storage variables
  local key value

  # Iterate over lines in stash file, break each line on first '='
  while IFS='=' read -r key value; do

    # If key is not empty, print it
    [ -n "$key" ] && printf '%s\n' "$key" && 

  done <"$D__STASH_FILEPATH"

  # Return zero always
  return 0
}

#>  d__stash_pre_flight_checks [-r|-g]
#
## Helper function that ensures that stashing is good to go
#
## Options:
#.  -r    - Use root stash, instead of deployment-specific
#.  -g    - Use grail stash, instead of box-specific
#
## Returns:
#.  0 - Ready for stashing
#.  1 - Otherwise
#
d__stash_pre_flight_checks()
{
  # Establish whether using root, or grail, or deployment-specific stash
  local stash_mode
  case $1 in
    -g) dprint_debug 'Working with grail stash'
        stash_mode=grail
        ;;
    -r) dprint_debug 'Working with root stash'
        stash_mode=root
        ;;
    *)  :;;
  esac

  # Check that $D__DIR_STASH is populated
  [ -n "$D__DIR_STASH" ] || {
    dprint_debug "$D__FMWK_NAME:" \
      'Stashing accessed without $D__DIR_STASH populated'
    return 1
  }

  # Check that $D__CONST_NAME_STASHFILE is populated
  [ -n "$D__CONST_NAME_STASHFILE" ] || {
    dprint_debug "$D__FMWK_NAME:" \
      'Stashing accessed without $D__CONST_NAME_STASHFILE populated'
    return 1
  }

  # Check if within deployment by ensuring $D_DPL_NAME is populated
  [ -z "$stash_mode" -a -z "$D_DPL_NAME" ] && {
    dprint_debug "$D__FMWK_NAME:" \
      'Stashing accessed without $D_DPL_NAME populated'
    return 1
  }

  # Check if grep command is available
  type -P grep &>/dev/null || {
    dprint_debug "$D__FMWK_NAME:" \
      'grep command is not found in $PATH' \
      -n 'Stashing is not available without grep'
    return 1
  }

  # Check if head command is available
  type -P head &>/dev/null || {
    dprint_debug "$D__FMWK_NAME:" \
      'head command is not found in $PATH' \
      -n 'Stashing is not available without head'
    return 1
  }

  # Check if md5 checking works
  dmd5 -s &>/dev/null || {
    dprint_debug "$D__FMWK_NAME:" \
      'Unable to verify md5 checksums' \
      -n 'Stashing is not available without means of checksum verification'
    return 1
  }

  # Establish directory path for stash
  local stash_dirpath
  case $stash_mode in
    grail)  stash_dirpath="$D__DIR_GRAIL";;
    root)   stash_dirpath="$D__DIR_STASH";;
    *)      stash_dirpath="$D__DIR_STASH/$D_DPL_NAME";;
  esac

  # Ensure directory for this stash exists
  mkdir -p -- "$stash_dirpath" || {
    dprint_debug "$D__FMWK_NAME:" \
      'Failed to create stash directory at:' -i "$stash_dirpath"
    return 1
  }

  # Compose path to stash file and its checksum file
  local stash_filepath="$stash_dirpath/$D__CONST_NAME_STASHFILE"
  local stash_md5_filepath="$stash_filepath.md5"

  # Ensure both stash files are not directories
  [ -d "$stash_filepath" ] && {
    dprint_debug "$D__FMWK_NAME:" \
      'Stash filepath occupied by a directory:' -i "$stash_filepath"
    return 1
  }
  [ -d "$stash_md5_filepath" ] && {
    dprint_debug "$D__FMWK_NAME:" \
      'Stash checksum filepath occupied by a directory:' \
      -i "$stash_md5_filepath"
    return 1
  }

  # If stash file does not yet exist, create it and record checksum
  if [ ! -e "$stash_filepath" ]; then
    touch -- "$stash_filepath" || {
      dprint_debug "$D__FMWK_NAME:" \
        'Failed to create fresh stash file at:' -i "$stash_filepath"
      return 1
    }
    dmd5 "$stash_filepath" >"$stash_md5_filepath" || {
      dprint_debug "$D__FMWK_NAME:" \
        'Failed to create stash md5 checksum file at:' -i "$stash_md5_filepath"
      return 1
    }
  fi

  # Ensure stash file and checksum file are both writable files
  [ -f "$stash_filepath" -a -w "$stash_filepath" ] || {
    dprint_debug "$D__FMWK_NAME:" \
      'Stash filepath is not a writable file:' -i "$stash_filepath"
    return 1
  }
  [ -f "$stash_md5_filepath" -a -w "$stash_md5_filepath" ] || {
    dprint_debug "$D__FMWK_NAME:" \
      'Stash md5 checksum filepath is not a writable file:' \
      -i "$stash_md5_filepath"
    return 1
  }

  # Populate stash file path globally
  D__STASH_FILEPATH="$stash_filepath"
  D__STASH_MD5_FILEPATH="$stash_md5_filepath"

  # Ensure checksum is good
  d__stash_check_md5 || return 1

  # Return
  return 0
}

#>  d__stash_validate_key KEY
#
## Checks if KEY is safe for stashing. Practically, it means ensuring that key 
#. consists of allowed characters only, which are: ASCII letters (both cases) 
#. and digits, underscore (_), and hyphen (-).
#
## Returns:
#.  0 - Key is acceptable
#.  1 - Otherwise
#
d__stash_validate_key()
{
  # Check if key is empty
  [ -n "$1" ] || {
    dprint_debug 'Stash key cannot be empty'
    return 1
  }

  # Check key characters
  [[ $1 =~ ^[a-zA-Z0-9_-]+$ ]] || {
    dprint_debug 'Stash key contains illegal characters:' -i "$1" \
      -n "Allowed characters: ASCII letters (both cases) and digits, '_', '-'"
    return 1
  }

  # Return
  return 0
}

#>  d__stash_store_md5
#
## Stores calculated md5 checksum of stash file into pre-defined file. No file 
#. existence checks are performed
#
## Returns:
#.  0 - Successfully stored checksum
#.  1 - Otherwise
#
d__stash_store_md5()
{
  # Store current md5 checksum to intended file, or report error
  dmd5 "$D__STASH_FILEPATH" >"$D__STASH_MD5_FILEPATH" || {
    dprint_debug "$D__FMWK_NAME:" \
      'Failed to create md5 checksum file at:' -i "$D__STASH_MD5_FILEPATH"
    return 1
  }
}

#>  d__stash_check_md5
#
## Checks whether checksum file at pre-defined path contains current md5 hash 
#. of stash file. If not, issues a warning and prompts user on whether they 
#. which to continue anyway. If they do, updates stored checksum.
#
## Returns:
#.  0 - Either checksum matches, or user is okay with mismatch
#.  1 - Otherwise
#
d__stash_check_md5()
{
  # Calculate current checksum; extract stored one
  local calculated_md5="$( dmd5 "$D__STASH_FILEPATH" )"
  local stored_md5="$( head -1 -- "$D__STASH_MD5_FILEPATH" 2>/dev/null )"

  # If checksums match: return immediately
  [ "$calculated_md5" = "$stored_md5" ] && return 0

  # Otherwise, compose prompt
  local prompt_desc prompt_question
  if [ ${#stored_md5} -eq 32 ]; then
    dprint_debug 'Mismatched checksum on stash file:' -i "$D__STASH_FILEPATH"
    prompt_desc=( \
      'Current md5 checksum of stash file:' -i "$D__STASH_FILEPATH" \
      -n 'does not match checksum recorded in' -i "$D__STASH_MD5_FILEPATH" \
      -n 'This suggests manual tinkering with framework directories' \
      -n "${BOLD}Without reliable stash," \
      "deployments may act unpredictably!${NORMAL}"
    )
    prompt_question='Ignore incorrect checksum?'
  else
    dprint_debug 'Missing checksum on stash file:' -i "$D__STASH_FILEPATH"
    prompt_desc=( \
      'There is no stored checksum for stash file at:' -i "$D__STASH_FILEPATH" \
      -n 'This suggests manual tinkering with framework directories' \
      -n "${BOLD}Without reliable stash," \
      "deployments may act unpredictably!${NORMAL}"
    )
    prompt_question='Ignore missing checksum?'
  fi

  # Prompt user and return appropriately
  if dprompt --color "$RED" --answer "$D__OPT_ANSWER" \
    --prompt "$prompt_question" -- "${prompt_desc[@]}"
  then
    dprint_debug 'Working with unverified stash'
    d__stash_store_md5
    return 0
  else
    dprint_debug 'Refused to work with unverified stash'
    return 1
  fi
}