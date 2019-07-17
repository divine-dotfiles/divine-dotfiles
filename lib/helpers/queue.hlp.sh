#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.10
#:revremark:    Initial revision
#:created_at:   2019.06.10

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template ‘queue.dpl.sh’
#

d__queue_check()
{
  # Initialize or increment section number
  if [ -z ${D__DPL_QUEUE_CURRENT_SECTION_NUM[0]+isset} ]; then
    D__DPL_QUEUE_CURRENT_SECTION_NUM[0]=0
  else
    (( ++D__DPL_QUEUE_CURRENT_SECTION_NUM[0] ))
  fi

  # Launch pre-processing if it is implemented
  if declare -f d_queue_pre_process &>/dev/null \
    && ! d_queue_pre_process
  then
    dprint_debug 'Queue pre-processing signaled error'
    return 3
  fi
  
  # Check if deployment’s main queue is empty
  if ! [ ${#D__DPL_QUEUE_MAIN[@]} -gt 1 -o -n "$D__DPL_QUEUE_MAIN" ]; then
    dprint_debug 'Main queue is empty ($D__DPL_QUEUE_MAIN)'
    return 3
  fi

  # Rely on stashing
  d__stash ready || return 3

  # Storage and status variables
  local all_installed=true all_not_installed=true all_unknown=true
  local good_items_exist=false some_installed=false should_prompt_again=false
  local item_stash_key

  # Global storage variables
  D__USER_OR_OS=true

  # If necessary functions are not implemented: implement a dummy
  if ! declare -f d_queue_item_is_installed &>/dev/null; then
    d_queue_item_is_installed() { :; }
  fi
  if ! declare -f d_queue_item_pre_check &>/dev/null; then
    d_queue_item_pre_check() { :; }
  fi
  if ! declare -f d_queue_post_process &>/dev/null; then
    d_queue_post_process() { :; }
  fi

  # Calculate section edges
  local min max secnum=${D__DPL_QUEUE_CURRENT_SECTION_NUM[0]}

  # Calculate low edge
  if [ $secnum -eq 0 ]; then min=0
  elif [[ ${D__DPL_QUEUE_SEPARATORS[$secnum-1]} =~ ^[0-9]+$ ]]; then
    min=${D__DPL_QUEUE_SEPARATORS[$secnum-1]}
  else
    min=${#D__DPL_QUEUE_MAIN[@]}
  fi

  # Calculate high edge
  if [[ ${D__DPL_QUEUE_SEPARATORS[$secnum]} =~ ^[0-9]+$ ]]; then
    max=${D__DPL_QUEUE_SEPARATORS[$secnum]}
  else
    max=${#D__DPL_QUEUE_MAIN[@]}
  fi

  # Announce checking
  dprint_debug -n "Checking queue items $min-$max (queue section #$secnum)"

  # Iterate over items in deployment’s main queue
  for (( D__DPL_ITEM_NUM=$min; D__DPL_ITEM_NUM<$max; D__DPL_ITEM_NUM++ )); do

    # Prepare global variables
    D__DPL_ITEM_TITLE="${D__DPL_QUEUE_MAIN[$D__DPL_ITEM_NUM]}"
    D__DPL_ITEM_STASH_KEY=
    D__DPL_ITEM_STASH_VALUE=
    
    # Allow user a chance to set stash key
    d_queue_item_pre_check

    # Check if function returned ‘no stash’ signal
    if [ $? -eq 1 ]; then

      # Report and otherwise do nothing
      # dprint_debug "(Not using stash for item: $D__DPL_ITEM_TITLE)"
      :

    else

      # Set flag
      d__queue_item_status set uses_stash

      # If stash key is empty, generate one
      [ -z "$D__DPL_ITEM_STASH_KEY" ] \
        && D__DPL_ITEM_STASH_KEY="$( dmd5 -s "$D__DPL_ITEM_TITLE" )"

      # Validate stash key
      if ! d__stash_validate_key "$D__DPL_ITEM_STASH_KEY"; then

        # Set flag, report error, and skip item
        d__queue_item_status set is_invalid
        d__queue_item_dprint_debug 'Not checked' \
          -n "Bad stash key: '$D__DPL_ITEM_STASH_KEY'"
        continue

      fi

    fi

    # Check stashing is not used for this item
    if ! d__queue_item_status uses_stash; then

      # Not using stash
      unset D__DPL_ITEM_STASH_FLAG

      # Check if item is installed
      d_queue_item_is_installed; case $? in
        0)  # Item status is unknown
            d__queue_item_status set can_be_installed
            d__queue_item_status set can_be_removed
            all_installed=false
            all_not_installed=false
            d__queue_item_dprint_debug 'Unknown' '(stash disabled)'
            ;;
        1)  # Item is installed
            d__queue_item_status set can_be_removed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            D__USER_OR_OS=false
            d__queue_item_dprint_debug 'Installed' '(stash disabled)'
            ;;
        2)  # Item is not installed
            d__queue_item_status set can_be_installed
            all_installed=false
            all_unknown=false
            d__queue_item_dprint_debug 'Not installed' '(stash disabled)'
            ;;
        3)  # Bad item: set flag, report error, and skip item
            d__queue_item_status set is_invalid
            should_prompt_again=true
            d__queue_item_dprint_debug 'Invalid' '(stash disabled)'
            continue
            ;;
      esac
    
    elif d__stash -s has "$D__DPL_ITEM_STASH_KEY"; then

      # Record of installation exists
      D__DPL_ITEM_STASH_FLAG=true

      # Populate stash value
      D__DPL_ITEM_STASH_VALUE="$( d__stash -s get "$D__DPL_ITEM_STASH_KEY" )"

      # Check if item is installed as advertised
      d_queue_item_is_installed; case $? in
        0)  # Item recorded but status is unknown: assume installed
            d__queue_item_status set can_be_removed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            D__USER_OR_OS=false
            d__queue_item_dprint_debug 'Unknown' '(record exists)'
            ;;
        1)  # Item recorded and installed
            d__queue_item_status set can_be_removed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            D__USER_OR_OS=false
            d__queue_item_dprint_debug 'Installed'
            ;;
        2)  # Item recorded but not installed
            d__queue_item_status set can_be_installed
            all_installed=false
            all_unknown=false
            should_prompt_again=true
            d__queue_item_dprint_debug 'Not installed' '(removed by user or OS)'
            ;;
        3)  # Bad item: set flag, report error, and skip item
            d__queue_item_status set is_invalid
            should_prompt_again=true
            d__queue_item_dprint_debug 'Invalid' '(record exists)'
            continue
            ;;
      esac

    else

      # No record of installation
      D__DPL_ITEM_STASH_FLAG=false

      # Check if item is nevertheless installed
      d_queue_item_is_installed; case $? in
        0)  # Item is not recorded and status is unknown: assume not installed
            d__queue_item_status set can_be_installed
            all_installed=false
            all_unknown=false
            d__queue_item_dprint_debug 'Unknown' '(no record)'
            ;;
        1)  # Item is not recorded but is installed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            d__queue_item_dprint_debug 'Installed' '(by user or OS)'
            ;;
        2)  # Item is not recorded and not installed
            d__queue_item_status set can_be_installed
            all_installed=false
            all_unknown=false
            d__queue_item_dprint_debug 'Not installed'
            ;;
        3)  # Bad item: set flag, report error, and skip item
            d__queue_item_status set is_invalid
            should_prompt_again=true
            d__queue_item_dprint_debug 'Invalid' '(no record)'
            continue
            ;;
      esac

    fi

    # If made it to here, current item is deemed okay-ish
    good_items_exist=true

    # Also, save stash key for later
    D__DPL_QUEUE_STASH_KEYS[$D__DPL_ITEM_NUM]="$D__DPL_ITEM_STASH_KEY"

  # Done iterating over items in deployment’s main queue
  done

  # Check if there was at least one good item in queue
  if ! $good_items_exist; then
    dprint_debug 'Not a single good queue item provided'
    return 3
  fi

  # Launch post-processing
  if ! d_queue_post_process; then
    dprint_debug 'Queue post-processing signaled error'
    return 3
  fi

  # Check if additional user prompt is warranted
  if $should_prompt_again; then
    D__ANOTHER_PROMPT=true
    D__ANOTHER_WARNING='Irregularities detected with this deployment'
  fi

  # Return appropriately
  if $all_installed; then return 1
  elif $all_not_installed; then return 2
  elif $all_unknown; then return 0
  elif $some_installed; then return 4
  else return 2; fi
}

d__queue_install()
{
  # Initialize or increment section number
  if [ -z ${D__DPL_QUEUE_CURRENT_SECTION_NUM[1]+isset} ]; then
    D__DPL_QUEUE_CURRENT_SECTION_NUM[1]=0
  else
    (( ++D__DPL_QUEUE_CURRENT_SECTION_NUM[1] ))
  fi

  # Storage and status variables
  local all_newly_installed=true all_already_installed=true all_failed=true
  local good_items_exist=false some_failed=false early_exit=false
  local exit_code

  # If necessary functions are not implemented: implement a dummy
  if ! declare -f d_queue_item_install &>/dev/null; then
    d_queue_item_install() { :; }
  fi

  # Calculate section edges
  local min max secnum=${D__DPL_QUEUE_CURRENT_SECTION_NUM[1]}

  # Calculate low edge
  if [ $secnum -eq 0 ]; then min=0
  elif [[ ${D__DPL_QUEUE_SEPARATORS[$secnum-1]} =~ ^[0-9]+$ ]]; then
    min=${D__DPL_QUEUE_SEPARATORS[$secnum-1]}
  else
    min=${#D__DPL_QUEUE_MAIN[@]}
  fi

  # Calculate high edge
  if [[ ${D__DPL_QUEUE_SEPARATORS[$secnum]} =~ ^[0-9]+$ ]]; then
    max=${D__DPL_QUEUE_SEPARATORS[$secnum]}
  else
    max=${#D__DPL_QUEUE_MAIN[@]}
  fi

  # Announce checking
  dprint_debug -n "Installing queue items $min-$max (queue section #$secnum)"

  # Iterate over items in deployment’s main queue
  for (( D__DPL_ITEM_NUM=$min; D__DPL_ITEM_NUM<$max; D__DPL_ITEM_NUM++ )); do

    # If queue item is invalid: skip silently
    if d__queue_item_status is_invalid; then continue; fi

    # Prepare global variables
    D__DPL_ITEM_TITLE="${D__DPL_QUEUE_MAIN[$D__DPL_ITEM_NUM]}"
    D__DPL_ITEM_IS_FORCED=false
    if d__queue_item_status uses_stash; then
      D__DPL_ITEM_STASH_KEY="${D__DPL_QUEUE_STASH_KEYS[$D__DPL_ITEM_NUM]}"
      if d__stash -s has "$D__DPL_ITEM_STASH_KEY"; then
        D__DPL_ITEM_STASH_FLAG=true
        D__DPL_ITEM_STASH_VALUE="$( d__stash -s get "$D__DPL_ITEM_STASH_KEY" )"
      else
        D__DPL_ITEM_STASH_FLAG=false
        D__DPL_ITEM_STASH_VALUE=
      fi
    else
      unset D__DPL_ITEM_STASH_KEY
      unset D__DPL_ITEM_STASH_FLAG
      unset D__DPL_ITEM_STASH_VALUE
    fi

    # Perform an action based on options available
    if d__queue_item_status can_be_installed; then

      # Item is considered not installed: install it
      d_queue_item_install; exit_code=$?; case $exit_code in
        0|3)  # Installed successfully
              all_already_installed=false
              all_failed=false
              d__stash -s set "$D__DPL_ITEM_STASH_KEY" "$D__DPL_ITEM_STASH_VALUE"
              d__queue_item_dprint_debug 'Installed'
              ;;
        1|4)  # Failed to install
              all_newly_installed=false
              all_already_installed=false
              some_failed=true
              d__queue_item_dprint_debug 'Failed to install'
              ;;
        2)    # Item found to be invalid during installation
              d__queue_item_dprint_debug 'Invalid'
              continue
              ;;
      esac

      # Check if early exit was requested and item is not last
      if [ $exit_code -eq 3 -o $exit_code -eq 4 ] \
        && (( D__DPL_ITEM_NUM < ( ${#D__DPL_QUEUE_MAIN[@]} - 1 ) ))
      then
        early_exit=true
      fi

    elif $D__OPT_FORCE; then

      # Set marker in global variable
      D__DPL_ITEM_IS_FORCED=true

      # Item is considered already installed, but user forces installation
      d_queue_item_install; exit_code=$?; case $exit_code in
        0|3)  # Re-installed successfully
              all_newly_installed=false
              all_failed=false
              d__stash -s set "$D__DPL_ITEM_STASH_KEY" "$D__DPL_ITEM_STASH_VALUE"
              d__queue_item_dprint_debug 'Force-installed'
              ;;
        1|4)  # Failed to re-install
              all_newly_installed=false
              all_already_installed=false
              some_failed=true
              d__queue_item_dprint_debug 'Failed to force-install'
              ;;
        2)    # Item found to be invalid during installation
              d__queue_item_dprint_debug 'Invalid'
              continue
              ;;
      esac

      # Check if early exit was requested and item is not last
      if [ $exit_code -eq 3 -o $exit_code -eq 4 ] \
        && (( D__DPL_ITEM_NUM < ( ${#D__DPL_QUEUE_MAIN[@]} - 1 ) ))
      then
        early_exit=true
      fi

    else

      # Item is considered already installed, and that’s the end of it
      all_newly_installed=false
      all_failed=false
      d__queue_item_dprint_debug 'Already installed'
    
    fi

    # If made it to here, current item is deemed okay-ish
    good_items_exist=true

    # If early exit is requested, break the cycle
    $early_exit && break
  
  # Done iterating over items in deployment’s main queue
  done

  # Check if there was at least one good item in queue
  if ! $good_items_exist; then
    dprint_debug 'Not a single queue item valid for installation'
    return 2
  fi

  # Check if early exit occurred
  if $early_exit; then
    dprint_skip -l 'Installation halted before all items were processed'
  fi

  # Return appropriately
  if $all_newly_installed; then return 0
  elif $all_already_installed; then
    dprint_skip -l 'All items already installed'
    return 0
  elif $all_failed; then
    dprint_failure -l 'All items failed to install'
    return 1
  elif $some_failed; then
    dprint_failure -l 'Some items failed to install'
    return 1
  else
    dprint_skip -l 'Some items already installed'
    return 0
  fi
}

d__queue_remove()
{
  # Initialize or decrement section number (reverse order)
  if [ -z ${D__DPL_QUEUE_CURRENT_SECTION_NUM[1]+isset} ]; then
    D__DPL_QUEUE_CURRENT_SECTION_NUM[1]="${#D__DPL_QUEUE_SEPARATORS[@]}"
  else
    (( --D__DPL_QUEUE_CURRENT_SECTION_NUM[1] ))
  fi

  # Storage and status variables
  local all_newly_removed=true all_already_removed=true all_failed=true
  local good_items_exist=false some_failed=false early_exit=false
  local exit_code

  # If necessary functions are not implemented: implement a dummy
  if ! declare -f d_queue_item_remove &>/dev/null; then
    d_queue_item_remove() { :; }
  fi

  # Calculate section edges
  local min max secnum=${D__DPL_QUEUE_CURRENT_SECTION_NUM[1]}

  # Calculate low edge
  if [ $secnum -eq 0 ]; then min=0
  elif [[ ${D__DPL_QUEUE_SEPARATORS[$secnum-1]} =~ ^[0-9]+$ ]]; then
    min=${D__DPL_QUEUE_SEPARATORS[$secnum-1]}
  else
    min=${#D__DPL_QUEUE_MAIN[@]}
  fi

  # Calculate high edge
  if [[ ${D__DPL_QUEUE_SEPARATORS[$secnum]} =~ ^[0-9]+$ ]]; then
    max=${D__DPL_QUEUE_SEPARATORS[$secnum]}
  else
    max=${#D__DPL_QUEUE_MAIN[@]}
  fi

  # Announce checking
  dprint_debug -n "Removing queue items $min-$max (queue section #$secnum)"

  # Iterate over items in deployment’s main queue (in reverse order)
  for (( D__DPL_ITEM_NUM=$max-1; D__DPL_ITEM_NUM>=$min; D__DPL_ITEM_NUM-- )); do

    # If queue item is invalid: skip silently
    if d__queue_item_status is_invalid; then continue; fi

    # Prepare global variables
    D__DPL_ITEM_TITLE="${D__DPL_QUEUE_MAIN[$D__DPL_ITEM_NUM]}"
    D__DPL_ITEM_IS_FORCED=false
    if d__queue_item_status uses_stash; then
      D__DPL_ITEM_STASH_KEY="${D__DPL_QUEUE_STASH_KEYS[$D__DPL_ITEM_NUM]}"
      if d__stash -s has "$D__DPL_ITEM_STASH_KEY"; then
        D__DPL_ITEM_STASH_FLAG=true
        D__DPL_ITEM_STASH_VALUE="$( d__stash -s get "$D__DPL_ITEM_STASH_KEY" )"
      else
        D__DPL_ITEM_STASH_FLAG=false
        D__DPL_ITEM_STASH_VALUE=
      fi
    else
      unset D__DPL_ITEM_STASH_KEY
      unset D__DPL_ITEM_STASH_FLAG
      unset D__DPL_ITEM_STASH_VALUE
    fi

    # Perform an action based on options available
    if d__queue_item_status can_be_removed; then

      # Item is considered installed: remove it
      d_queue_item_remove; exit_code=$?; case $exit_code in
        0|3)  # Removed successfully
              all_already_removed=false
              all_failed=false
              d__stash -s unset "$D__DPL_ITEM_STASH_KEY"
              d__queue_item_dprint_debug 'Removed'
              ;;
        1|4)  # Failed to remove
              all_newly_removed=false
              all_already_removed=false
              some_failed=true
              d__queue_item_dprint_debug 'Failed to remove'
              ;;
        2)    # Item found to be invalid during installation
              d__queue_item_dprint_debug 'Invalid'
              continue
              ;;
      esac

      # Check if early exit was requested and item is not last
      if [ $exit_code -eq 3 -o $exit_code -eq 4 ] \
        && (( D__DPL_ITEM_NUM > 0 ))
      then
        early_exit=true
      fi

    elif $D__OPT_FORCE; then

      # Set marker in global variable
      D__DPL_ITEM_IS_FORCED=true

      # Item is considered already not installed, but user forces removal
      d_queue_item_remove; exit_code=$?; case $exit_code in
        0|3)  # Re-removed successfully
              all_newly_removed=false
              all_failed=false
              d__stash -s unset "$D__DPL_ITEM_STASH_KEY"
              d__queue_item_dprint_debug 'Force-removed'
              ;;
        1|4)  # Failed to re-remove
              all_newly_removed=false
              all_already_removed=false
              some_failed=true
              d__queue_item_dprint_debug 'Failed to force-remove'
              ;;
        2)    # Item found to be invalid during removal
              d__queue_item_dprint_debug 'Invalid'
              continue
              ;;
      esac

      # Check if early exit was requested and item is not last
      if [ $exit_code -eq 3 -o $exit_code -eq 4 ] \
        && (( D__DPL_ITEM_NUM > 0 ))
      then
        early_exit=true
      fi

    else

      # Item is considered already not installed, and that’s the end of it
      all_newly_removed=false
      all_failed=false
      d__queue_item_dprint_debug 'Already not installed'
    
    fi

    # If made it to here, current item is deemed okay-ish
    good_items_exist=true

    # If early exit is requested, break the cycle
    $early_exit && break
  
  # Done iterating over items in deployment’s main queue
  done

  # Check if there was at least one good item in queue
  if ! $good_items_exist; then
    dprint_debug 'Not a single queue item valid for removal'
    return 2
  fi

  # Check if early exit occurred
  if $early_exit; then
    dprint_skip -l 'Removal halted before all items were processed'
  fi

  # Return appropriately
  if $all_newly_removed; then return 0
  elif $all_already_removed; then
    dprint_skip -l 'All items already removed'
    return 0
  elif $all_failed; then
    dprint_failure -l 'All items failed to remove'
    return 1
  elif $some_failed; then
    dprint_failure -l 'Some items failed to remove'
    return 1
  else
    dprint_skip -l 'Some items already removed'
    return 0
  fi
}

#>  d__queue_item_status [ set FLAG ] | FLAG
#
## Convenience wrapper for storing pre-defined boolean flags in global array
#
d__queue_item_status()
{
  # Check if first argument is the word ‘set’
  if [ "$1" = set ]; then

    # Setting flag: ditch first arg and add necessary flag
    shift; case $1 in
      is_invalid)         D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]+='x';;
      uses_stash)         D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]+='s';;
      can_be_installed)   D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]+='i';;
      can_be_removed)     D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]+='r';;
      *)                  return 1;;
    esac

  else

    # Checking flag: return 0/1 based on presence of requested flag
    case $1 in
      is_invalid)         [[ ${D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]} == *x* ]];;
      uses_stash)         [[ ${D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]} == *s* ]];;
      can_be_installed)   [[ ${D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]} == *i* ]];;
      can_be_removed)     [[ ${D__DPL_QUEUE_FLAGS[$D__DPL_ITEM_NUM]} == *r* ]];;
      *)                  return 1;;
    esac

  fi
}

#>  d__queue_item_dprint_debug TITLE [CHUNK]…
#
## Tiny helper that unifies debug message format for queue items
#
d__queue_item_dprint_debug()
{
  local width=24
  local title="$1"; shift
  if [ ${#title} -le $width ]; then
    title="$( printf "%-${width}s" "$title" )"
  fi
  dprint_debug "${title:0:$width}: $D__DPL_ITEM_TITLE" "$@"
}

#>  d__queue_split [POSITION]
#
## Adds a separation point into the queue either at current length (to continue 
#. populating the next section of the queue), or at a given length. Queue 
#. helpers process first available queue segment and move to the next one only 
#. on next iteration.
#
d__queue_split()
{
  # Grab argument
  local position="$1"; shift

  # Flip debug flag
  D__DPL_QUEUE_IS_SPLIT=true

  # Check if argument is numeric and less than current queue length
  if [[ $position =~ ^[0-9]+$ ]] && [ $position -lt ${#D__DPL_QUEUE_MAIN[@]} ]
  then
    D__DPL_QUEUE_SEPARATORS+=( $position )
    return 0
  fi

  # Otherwise, just add separation point at current queue length
  D__DPL_QUEUE_SEPARATORS+=( ${#D__DPL_QUEUE_MAIN[@]} )
  return 0
}