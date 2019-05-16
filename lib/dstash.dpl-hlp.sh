#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: dstash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.15
#:revremark:    Initial revision
#:created_at:   2019.05.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function for any deployments that require persistent state
#
## Stashing allows to create/retrieve/update/delete key-value pairs that 
#. persist between invocations of deployment scripts. Each deployment gets its 
#. own stash. Text file in backups directory is used for storage.
#

#> dstash ready|has|set|get|pop|rm|clear [-r|--root] [ KEY [VALUE] ]
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
#
## Parameters:
#.  Name of task to perform, followed by appropriate arguments:
#.  ready             - (default) Return 0 if stash is ready, or 2 if not
#.  has KEY           - Check if KEY is stashed with any value
#.  set KEY [VALUE]   - Set/update KEY to VALUE; VALUE can be empty
#.  get KEY           - Print value of KEY to stdout
#.  pop KEY           - Print value of KEY to stdout; then remove it
#.  rm KEY            - Remove KEY from stash
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
  local args=() root=; while (($#)); do
    case $1 in -r|--root) root=-r;; *) args+=("$1");; esac; shift; done
  set -- "${args[@]}"

  # Always perform pre-flight checks first
  __dstash_pre_flight_checks $root || return 2

  # Quick return without arguments (equivalent of dstash ready)
  (($#)) || return 0

  # Extract task name
  local task="$1"; shift

  # Dispatch task based on first argument
  case $task in
    ready)  return 0;;
    has)    __dstash_has "$@";;
    set)    __dstash_set "$@";;
    get)    __dstash_get "$@";;
    pop)    __dstash_pop "$@";;
    rm)     __dstash_rm "$@";;
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

#> __dstash_set KEY VALUE
#
## Sets KEY to VALUE. Extra arguments are ignored.
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
  if __dstash_has -s "$1"; then __dstash_rm -s "$1" || return 1; fi

  # Append record at the end
  printf '%s\n' "$1=$2" >>"$D_STASH_FILEPATH" || {
    dprint_debug 'Failed to store record:' -i "$1=$2" \
      -n 'in stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }
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

#> __dstash_pop KEY
#
## Prints value of provided KEY to stdout, then unsets KEY. If key does not 
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
#.  1 - Key is invalid, not provided, failed to get/print key, or failed to 
#.      unset key
#
__dstash_pop()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # Delegate printing of value
  __dstash_get -s "$1" || return 1

  # Delegate unsetting of key
  __dstash_rm -s "$1" || return 1
}

#> __dstash_rm [-s] KEY
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
__dstash_rm()
{
  # Validate arguments
  if [ "$1" = -s ]; then shift; else __dstash_validate_key "$1" || return 1; fi

  # Invalidate all previous assignment records
  perl -i -pe "s|^($1=.*)\$|// \$1|g" -- "$D_STASH_FILEPATH" || {
    dprint_debug 'Failed to remove key:' -i "$1" \
      -n 'in stash file at:' -i "$D_STASH_FILEPATH"
    return 1
  }
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

  # Establish directory path for stash
  local stash_dirpath="$D_BACKUPS_DIR"
  [ "$root" = false ] && stash_dirpath+="/$D_NAME"

  # Ensure directory for this deployment exists
  mkdir -p -- "$stash_dirpath" || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Failed to create stash directory at:' -i "$stash_dirpath"
    return 1
  }

  # Compose path to stash file
  local stash_filepath="$stash_dirpath/$D_STASH_FILENAME"

  # Ensure stash file is not a directory
  [ -d "$stash_filepath" ] && {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stash filepath occupied by a directory:' -i "$stash_filepath"
    return 1
  }

  # If stash file does not yet exist, create it
  if [ ! -e "$stash_filepath" ]; then
    touch -- "$stash_filepath" || {
      dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
        'Failed to create fresh stash file at:' -i "$stash_filepath"
      return 1
    }
  fi

  # Ensure stash file is a writable file
  [ -f "$stash_filepath" -a -w "$stash_filepath" ] || {
    dprint_debug "$( basename -- "${BASH_SOURCE[0]}" ):" \
      'Stash file path is not a writable file:' -i "$stash_filepath"
    return 1
  }

  # Populate stash file path globally
  D_STASH_FILEPATH="$stash_filepath"

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