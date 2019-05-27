#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: dstash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.1.--SNAPSHOT
#:revdate:      2019.05.27
#:revremark:    Initial revision
#:created_at:   2019.05.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function for any deployments that require persistent state
#
## Stashing allows to create/retrieve/update/delete key-value pairs that 
#. persist between invocations of deployment scripts. Each deployment gets its 
#. own stash. Stash is a specially named text file in backups directory.
#

#> dstash ready|has|set|add|get|list|unset|clear [-rs] [ KEY [VALUE] ]
#
## Main stashing command. Dispatches task based on first non-opt argument.
#
## Stash key must be a non-empty string consisting of alphanumeric characters, 
#. plus '_' and '-'.
#
## Options:
#.  -r|-root  - Use root stash, instead of deployment-specific. Root stash is 
#.              used, for example, during installation of Divine.dotfiles 
#.              framework itself.
#.  -s|--skip-checks  - Forego stash health checks. Use with care for multiple 
#.                      successive calls.
#
## Parameters:
#.  Name of task to perform, followed by appropriate arguments:
#.  ready             - (default) Return 0 if stash is ready, or 2 if not
#.  has KEY           - Check if KEY is stashed with any value
#.  set KEY [VALUE]   - Set/update KEY to VALUE; VALUE can be empty
#.  add KEY [VALUE]   - Add another VALUE to KEY; VALUE can be empty
#.  get KEY           - Print first value of KEY to stdout
#.  list KEY          - Print each value of KEY on a line to stdout
#.  unset KEY         - Remove KEY from stash completely
#.  clear             - Clear stash entirely
#
## Returns:
#.  0 - Task performed
#.  1 - Meaning differs between tasks
#.  2 - Stashing system is not operational
#
dstash()
{
  # Parse options
  local args=() root= checks=true; while (($#)); do
    case $1 in -r|--root) root=-r;; -s|--skip-checks) checks=false;; 
    *) args+=("$1");; esac; shift; done
  set -- "${args[@]}"

  # Perform pre-flight checks first, unless ordered to skip
  if $checks; then
    __dstash_pre_flight_checks $root || return 2
  else
    # Without checks, just populate necessary paths
    local stash_dirpath="$D_BACKUPS_DIR"
    [ "$root" = -r ] || stash_dirpath+="/$D_NAME"
    D_STASH_FILEPATH="$stash_dirpath/$D_STASH_FILENAME"
    D_STASH_MD5_FILEPATH="$D_STASH_FILEPATH.md5"
  fi

  # Quick return without arguments (equivalent of dstash ready)
  (($#)) || return 0

  # Dispatch task based on first argument
  local task="$1"; shift; case $task in
    ready)  return 0;;
    has)    __dstash_has "$@";;
    set)    __dstash_set "$@";;
    add)    __dstash_add "$@";;
    get)    __dstash_get "$@";;
    list)   __dstash_list "$@";;
    unset)  __dstash_unset "$@";;
    clear)  >"$D_STASH_FILEPATH" && return 0 || return 1;;
    *)      dprint_debug 'dstash called with illegal task:' -i "$1"; return 1;;
  esac

  # Return status of dispatched command
  return $?
}

#> __dstash_has [-s] KEY
#
## Checks whether KEY is currently set to any value, including empty string.
#. Extra arguments are ignored.
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
__dstash_has()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # Check for existense in stash file
  grep -q ^"$1"= -- "$D_STASH_FILEPATH" &>/dev/null && return 0 || return 1
}

#> __dstash_set KEY [VALUE]
#
## Sets first/new occurrence of KEY to VALUE. Extra arguments are ignored.
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
__dstash_set()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # If key is currently set, unset it
  if __dstash_has -s "$1"; then __dstash_unset -s "$1" || return 1; fi

  # Append record at the end
  printf '%s\n' "$1=$2" >>"$D_STASH_FILEPATH" || {
    dprint_debug 'Failed to store record:' -i "$1=$2" \
      -n 'in stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }

  # Update stash file checksum and return zero regardless
  __dstash_store_md5; return 0
}

#> __dstash_add KEY [VALUE]
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
__dstash_add()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # Append record at the end
  printf '%s\n' "$1=$2" >>"$D_STASH_FILEPATH" || {
    dprint_debug 'Failed to add record:' -i "$1=$2" \
      -n 'to stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }

  # Update stash file checksum and return zero regardless
  __dstash_store_md5; return 0
}

#> __dstash_get KEY
#
## Prints value of provided KEY to stdout. If key does not exist prints nothing 
#. and returns non-zero. Extra arguments are ignored.
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
__dstash_get()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # If key is currently not set, return status
  __dstash_has -s "$1" || {
    dprint_debug \
      'Tried to get key:' -i "$1" -n 'from stash, but it is currently not set'
    return 1
  }

  # Get key’s value
  local value
  value="$( grep ^"$1"= -- "$D_STASH_FILEPATH" 2>/dev/null \
    | head -1 2>/dev/null )"

  # Check if retrieval was successful
  [ $? -eq 0 ] || {
    dprint_debug 'Failed to retrieve key:' -i "$1" \
      -n 'from stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }

  # Chop off the 'key=' part
  value="${value#$1=}"

  # Print value
  printf '%s\n' "$value"
}

#> __dstash_list KEY
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
__dstash_list()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # If key is currently not set, return status
  __dstash_has -s "$1" || {
    dprint_debug \
      'Tried to list key:' -i "$1" -n 'from stash, but it is currently not set'
    return 1
  }

  # List key’s values
  local value
  while read -r value; do

    # Chop off the 'key=' part
    value="${value#$1=}"

    # Print value
    printf '%s\n' "$value"

  done < <( grep ^"$1"= -- "$D_STASH_FILEPATH" 2>/dev/null )

  # Check if retrieval was successful
  [ $? -eq 0 ] || {
    dprint_debug 'Failed to retrieve key:' -i "$1" \
      -n 'from stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }
}

#> __dstash_unset [-s] KEY
#
## Unsets key by invalidating all previous assignments in stash file. Extra 
#. arguments are ignored.
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
__dstash_unset()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # Invalidate all previous assignment records
  perl -i -pe "s|^($1=.*)\$|// \$1|g" -- "$D_STASH_FILEPATH" || {
    dprint_debug 'Failed to remove key:' -i "$1" \
      -n 'in stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }

  # Update stash file checksum and return zero regardless
  __dstash_store_md5; return 0
}

#>  __dstash_pre_flight_checks [-r]
#
## Helper function that ensures that stashing is good to go
#
## Options:
#.  -r    - Use root stash, instead of deployment-specific
#
## Returns:
#.  0 - Ready for stashing
#.  1 - Otherwise
#
__dstash_pre_flight_checks()
{
  # Establish whether using root stash
  local root=false; [ "$1" = '-r' ] && {
    dprint_debug 'Working with root stash'
    root=true
  }

  # Check that $D_BACKUPS_DIR is populated
  [ -n "$D_BACKUPS_DIR" ] || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stashing accessed without $D_BACKUPS_DIR populated'
    return 1
  }

  # Check that $D_STASH_FILENAME is populated
  [ -n "$D_STASH_FILENAME" ] || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stashing accessed without $D_STASH_FILENAME populated'
    return 1
  }

  # Non-root: check if within deployment by ensuring $D_NAME is populated
  [ "$root" = false -a -z "$D_NAME" ] && {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stashing accessed without $D_NAME populated'
    return 1
  }

  # Check if perl command is available
  type -P perl &>/dev/null || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'perl command is not found in $PATH' \
      -n 'Stashing is not available without perl'
    return 1
  }

  # Check if grep command is available
  type -P grep &>/dev/null || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'grep command is not found in $PATH' \
      -n 'Stashing is not available without grep'
    return 1
  }

  # Check if head command is available
  type -P head &>/dev/null || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'head command is not found in $PATH' \
      -n 'Stashing is not available without head'
    return 1
  }

  # Check if md5 checking works
  dmd5 -s &>/dev/null || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Unable to verify md5 checksums' \
      -n 'Stashing is not available without means of checksum verification'
    return 1
  }

  # Establish directory path for stash
  local stash_dirpath="$D_BACKUPS_DIR"
  [ "$root" = false ] && stash_dirpath+="/$D_NAME"

  # Ensure directory for this deployment exists
  mkdir -p -- "$stash_dirpath" || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Failed to create stash directory at:' -i "$stash_dirpath"
    return 1
  }

  # Compose path to stash file and its checksum file
  local stash_filepath="$stash_dirpath/$D_STASH_FILENAME"
  local stash_md5_filepath="$stash_filepath.md5"

  # Ensure both stash files are not a directory
  [ -d "$stash_filepath" ] && {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stash filepath occupied by a directory:' -i "$stash_filepath"
    return 1
  }
  [ -d "$stash_md5_filepath" ] && {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stash checksum filepath occupied by a directory:' \
      -i "$stash_md5_filepath"
    return 1
  }

  # If stash file does not yet exist, create it and record checksum
  if [ ! -e "$stash_filepath" ]; then
    touch -- "$stash_filepath" || {
      dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
        'Failed to create fresh stash file at:' -i "$stash_filepath"
      return 1
    }
    dmd5 "$stash_filepath" >"$stash_md5_filepath" || {
      dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
        'Failed to create stash md5 checksum file at:' -i "$stash_md5_filepath"
      return 1
    }
  fi

  # Ensure stash file and checksum file are both writable files
  [ -f "$stash_filepath" -a -w "$stash_filepath" ] || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stash filepath is not a writable file:' -i "$stash_filepath"
    return 1
  }
  [ -f "$stash_md5_filepath" -a -w "$stash_md5_filepath" ] || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stash md5 checksum filepath is not a writable file:' \
      -i "$stash_md5_filepath"
    return 1
  }

  # Populate stash file path globally
  D_STASH_FILEPATH="$stash_filepath"
  D_STASH_MD5_FILEPATH="$stash_md5_filepath"

  # Ensure checksum is good
  __dstash_check_md5 || return 1

  # Return
  return 0
}

#>  __dstash_validate_key KEY
#
## Checks if KEY is safe for stashing. Practically, it means ensuring that key 
#. consists of allowed characters only, which are: ASCII letters (both cases) 
#. and digits, underscore (_), and hyphen (-).
#
## Returns:
#.  0 - Key is acceptable
#.  1 - Otherwise
#
__dstash_validate_key()
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

#>  __dstash_store_md5
#
## Stores calculated md5 checksum of stash file into pre-defined file. No file 
#. existence checks are performed
#
## Returns:
#.  0 - Successfully stored checksum
#.  1 - Otherwise
#
__dstash_store_md5()
{
  # Store current md5 checksum to intended file, or report error
  dmd5 "$D_STASH_FILEPATH" >"$D_STASH_MD5_FILEPATH" || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Failed to create md5 checksum file at:' -i "$D_STASH_MD5_FILEPATH"
    return 1
  }
}

#>  __dstash_check_md5
#
## Checks whether checksum file at pre-defined path contains current md5 hash 
#. of stash file. If not, issues a warning and prompts user on whether they 
#. which to continue anyway. If they do, updates stored checksum.
#
## Returns:
#.  0 - Either checksum matches, or user is okay with mismatch
#.  1 - Otherwise
#
__dstash_check_md5()
{
  # Calculate current checksum; extract stored one
  local calculated_md5="$( dmd5 "$D_STASH_FILEPATH" )"
  local stored_md5="$( head -1 -- "$D_STASH_MD5_FILEPATH" 2>/dev/null )"

  # If checksums match: return immediately
  [ "$calculated_md5" = "$stored_md5" ] && return 0

  # Otherwise, compose prompt
  local prompt_desc prompt_question
  if [ ${#stored_md5} -eq 32 ]; then
    dprint_debug 'Mismatched checksum on stash file:' -i "$D_STASH_FILEPATH"
    prompt_desc=( \
      'Current md5 checksum of stash file:' -i "$D_STASH_FILEPATH" \
      -n 'does not match checksum recorded in' -i "$D_STASH_MD5_FILEPATH" \
      -n 'This suggests manual tinkering with framework directories' \
      -n "${BOLD}Without reliable stash," \
      "deployments may act unpredictably!${NORMAL}"
    )
    prompt_question='Ignore incorrect checksum?'
  else
    dprint_debug 'Missing checksum on stash file:' -i "$D_STASH_FILEPATH"
    prompt_desc=( \
      'There is no stored checksum for stash file at:' -i "$D_STASH_FILEPATH" \
      -n 'This suggests manual tinkering with framework directories' \
      -n "${BOLD}Without reliable stash," \
      "deployments may act unpredictably!${NORMAL}"
    )
    prompt_question='Ignore missing checksum?'
  fi

  # Prompt user and return appropriately
  if dprompt_key --color "$RED" --answer "$D_BLANKET_ANSWER" \
    --prompt "$prompt_question" -- "${prompt_desc[@]}"
  then
    dprint_debug 'Working with unverified stash'
    __dstash_store_md5
    return 0
  else
    dprint_debug 'Refused to work with unverified stash'
    return 1
  fi
}