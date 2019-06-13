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

__queue_hlp__dcheck()
{
  # Check if deployment’s main queue is empty
  if ! [ ${#D_DPL_QUEUE_MAIN[@]} -gt 1 -o -n "$D_DPL_QUEUE_MAIN" ]; then
    dprint_debug 'Main queue is empty ($D_DPL_QUEUE_MAIN)'
    return 3
  fi

  # Rely on stashing (it is expected to be used by implementation)
  dstash ready || return 3

  # Launch pre-processing
  if ! __d__queue_hlp__pre_process; then
    dprint_debug 'Queue pre-processing signaled error'
    return 3
  fi
  
  # Storage and status variables
  local all_installed=true all_not_installed=true all_unknown=true
  local good_items_exist=false some_installed=false
  local item_stash_key

  # Global storage variables
  D_DPL_QUEUE_FLAGS=()
  D_DPL_QUEUE_STASH_KEYS=()
  D_USER_OR_OS=true

  # If necessary functions are not implemented: implement a dummy
  if ! declare -f __d__queue_hlp__item_is_installed &>/dev/null; then
    __d__queue_hlp__item_is_installed() { :; }
  fi
  if ! declare -f __d__queue_hlp__provide_stash_key &>/dev/null; then
    __d__queue_hlp__provide_stash_key() { :; }
  fi
  if ! declare -f __d__queue_hlp__post_process &>/dev/null; then
    __d__queue_hlp__post_process() { :; }
  fi

  # Iterate over items in deployment’s main queue
  for (( D_DPL_ITEM_NUM=0; \
    D_DPL_ITEM_NUM<${#D_DPL_QUEUE_MAIN[@]}; \
    D_DPL_ITEM_NUM++ )); do

    # Prepare global variables
    D_DPL_ITEM_TITLE="${D_DPL_QUEUE_MAIN[$D_DPL_ITEM_NUM]}"
    D_DPL_ITEM_STASH_KEY=
    D_DPL_ITEM_STASH_VALUE=
    
    # Allow user a chance to set stash key
    __d__queue_hlp__provide_stash_key

    # Check if function returned ‘no stash’ signal
    if [ $? -eq 1 ]; then

      # Report and otherwise do nothing
      dprint_debug "Not using stash for item '$D_DPL_ITEM_TITLE'"

    else

      # Set flag
      __queue_hlp__current_item set uses_stash

      # If stash key is empty, generate one
      [ -z "$D_DPL_ITEM_STASH_KEY" ] \
        && D_DPL_ITEM_STASH_KEY="$( dmd5 -s "$D_DPL_ITEM_TITLE" )"

      # Validate stash key
      if ! __dstash_validate_key "$D_DPL_ITEM_STASH_KEY"; then

        # Set flag, report error, and skip item
        __queue_hlp__current_item set is_invalid
        dprint_debug "Invalid item '$D_DPL_ITEM_TITLE'" \
          "(bad stash key: '$D_DPL_ITEM_STASH_KEY')"
        continue

      fi

    fi

    # Check stashing is not used for this item
    if ! __queue_hlp__current_item uses_stash; then

      # Not using stash

      # Check if item is installed
      __d__queue_hlp__item_is_installed; case $? in
        0)  # Item status is unknown
            __queue_hlp__current_item set can_be_installed
            __queue_hlp__current_item set can_be_removed
            all_installed=false
            all_not_installed=false
            dprint_debug "Status of item '$D_DPL_ITEM_TITLE' is inconclusive"
            ;;
        1)  # Item is installed
            __queue_hlp__current_item set can_be_removed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            D_USER_OR_OS=false
            ;;
        2)  # Item is not installed
            __queue_hlp__current_item set can_be_installed
            all_installed=false
            all_unknown=false
            ;;
        3)  # Bad item: set flag, report error, and skip item
            __queue_hlp__current_item set is_invalid
            dprint_debug "Invalid item '$D_DPL_ITEM_TITLE' (bad check results)"
            continue
            ;;
      esac
    
    elif dstash -s has "$D_DPL_ITEM_STASH_KEY"; then

      # Record of installation exists

      # Populate stash value
      D_DPL_ITEM_STASH_VALUE="$( dstash -s get "$D_DPL_ITEM_STASH_KEY" )"

      # Check if item is installed as advertised
      __d__queue_hlp__item_is_installed; case $? in
        0)  # Item recorded but status is unknown: assume installed
            __queue_hlp__current_item set can_be_removed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            D_USER_OR_OS=false
            dprint_debug "Assuming item '$D_DPL_ITEM_TITLE' is installed" \
              'despite inconclusive check results'
            ;;
        1)  # Item recorded and installed
            __queue_hlp__current_item set can_be_removed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            D_USER_OR_OS=false
            ;;
        2)  # Item recorded but not installed
            __queue_hlp__current_item set can_be_installed
            all_installed=false
            all_unknown=false
            dprint_debug "Item '$D_DPL_ITEM_TITLE' has stash record" \
              'but is actually not installed'
            ;;
        3)  # Bad item: set flag, report error, and skip item
            __queue_hlp__current_item set is_invalid
            dprint_debug "Invalid item '$D_DPL_ITEM_TITLE' (bad check results)"
            ;;
      esac

    else

      # No record of installation

      # Check if item is nevertheless installed
      __d__queue_hlp__item_is_installed; case $? in
        0)  # Item is not recorded and status is unknown: assume not installed
            __queue_hlp__current_item set can_be_installed
            all_installed=false
            all_unknown=false
            dprint_debug "Assuming item '$D_DPL_ITEM_TITLE' is not installed" \
              'despite inconclusive check results'
            ;;
        1)  # Item is not recorded but is installed
            some_installed=true
            all_not_installed=false
            all_unknown=false
            dprint_debug "Item '$D_DPL_ITEM_TITLE' is already installed" \
              'without stash resord'
            ;;
        2)  # Item is not recorded and not installed
            __queue_hlp__current_item set can_be_installed
            all_installed=false
            all_unknown=false
            ;;
        3)  # Bad item: set flag, report error, and skip item
            __queue_hlp__current_item set is_invalid
            dprint_debug "Invalid item '$D_DPL_ITEM_TITLE' (bad check results)"
            ;;
      esac

    fi

    # If made it to here, current item is deemed okay-ish
    good_items_exist=true

    # Also, save stash key for later
    D_DPL_QUEUE_STASH_KEYS[$D_DPL_ITEM_NUM]="$D_DPL_ITEM_STASH_KEY"

  # Done iterating over items in deployment’s main queue
  done

  # Check if there was at least one good item in queue
  if ! $good_items_exist; then
    dprint_debug 'Not a single good input item provided'
    return 3
  fi

  # Launch post-processing
  if ! __d__queue_hlp__post_process; then
    dprint_debug 'Queue post-processing signaled error'
    return 3
  fi

  # Return appropriately
  if $all_installed; then return 1
  elif $all_not_installed; then return 2
  elif $all_unknown; then return 0
  elif $some_installed; then return 4
  else return 2; fi
}

__queue_hlp__dinstall()
{
  # Storage and status variables
  local all_newly_installed=true all_already_installed=true all_failed=true
  local good_items_exist=false some_failed=false

  # If necessary functions are not implemented: implement a dummy
  if ! declare -f __d__queue_hlp__install_item &>/dev/null; then
    __d__queue_hlp__install_item() { :; }
  fi

  # Iterate over items in deployment’s main queue
  for (( D_DPL_ITEM_NUM=0; \
    D_DPL_ITEM_NUM<${#D_DPL_QUEUE_MAIN[@]}; \
    D_DPL_ITEM_NUM++ )); do

    # If queue item is invalid: skip silently
    if __queue_hlp__current_item is_invalid; then continue; fi

    # Prepare global variables
    D_DPL_ITEM_TITLE="${D_DPL_QUEUE_MAIN[$D_DPL_ITEM_NUM]}"
    D_DPL_ITEM_STASH_KEY="${D_DPL_QUEUE_STASH_KEYS[$D_DPL_ITEM_NUM]}"
    D_DPL_ITEM_STASH_VALUE="$( dstash -s get "$D_DPL_ITEM_STASH_KEY" )"
    D_DPL_ITEM_IS_FORCED=false

    # Perform an action based on options available
    if __queue_hlp__current_item can_be_installed; then

      # Item is considered not installed: install it
      __d__queue_hlp__install_item; case $? in
        0)  # Installed successfully
            all_already_installed=false
            all_failed=false
            dstash -s set "$D_DPL_ITEM_STASH_KEY" "$D_DPL_ITEM_STASH_VALUE"
            dprint_debug "Installed item '$D_DPL_ITEM_TITLE'"
            ;;
        1)  # Failed to install
            all_newly_installed=false
            all_already_installed=false
            some_failed=true
            dprint_debug "Failed to install item '$D_DPL_ITEM_TITLE'"
            ;;
        2)  # Item found to be invalid during installation
            dprint_debug "Item '$D_DPL_ITEM_TITLE' found to be invalid" \
              'during installation'
            continue
            ;;
      esac

    elif $D_OPT_FORCE; then

      # Set marker in global variable
      D_DPL_ITEM_IS_FORCED=true

      # Item is considered already installed, but user forces installation
      __d__queue_hlp__install_item; case $? in
        0)  # Re-installed successfully
            all_newly_installed=false
            all_failed=false
            dstash -s set "$D_DPL_ITEM_STASH_KEY" "$D_DPL_ITEM_STASH_VALUE"
            dprint_debug "Re-installed item '$D_DPL_ITEM_TITLE'"
            ;;
        1)  # Failed to re-install
            all_newly_installed=false
            all_already_installed=false
            some_failed=true
            dprint_debug "Failed to re-install item '$D_DPL_ITEM_TITLE'"
            ;;
        2)  # Item found to be invalid during installation
            dprint_debug "Item '$D_DPL_ITEM_TITLE' found to be invalid" \
              'during re-installation'
            continue
            ;;
      esac

    else

      # Item is considered already installed, and that’s the end of it
      all_newly_installed=false
      all_failed=false
    
    fi

    # If made it to here, current item is deemed okay-ish
    good_items_exist=true
  
  # Done iterating over items in deployment’s main queue
  done

  # Check if there was at least one good item in queue
  if ! $good_items_exist; then
    dprint_debug 'Not a single input item valid for installation'
    return 2
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

__queue_hlp__dremove()
{
  # Storage and status variables
  local all_newly_removed=true all_already_removed=true all_failed=true
  local good_items_exist=false some_failed=false

  # If necessary functions are not implemented: implement a dummy
  if ! declare -f __d__queue_hlp__remove_item &>/dev/null; then
    __d__queue_hlp__remove_item() { :; }
  fi

  # Iterate over items in deployment’s main queue
  for (( D_DPL_ITEM_NUM=${#D_DPL_QUEUE_MAIN[@]}-1; \
    D_DPL_ITEM_NUM>=0; \
    D_DPL_ITEM_NUM-- )); do

    # If queue item is invalid: skip silently
    if __queue_hlp__current_item is_invalid; then continue; fi

    # Prepare global variables
    D_DPL_ITEM_TITLE="${D_DPL_QUEUE_MAIN[$D_DPL_ITEM_NUM]}"
    D_DPL_ITEM_STASH_KEY="${D_DPL_QUEUE_STASH_KEYS[$D_DPL_ITEM_NUM]}"
    D_DPL_ITEM_STASH_VALUE="$( dstash -s get "$D_DPL_ITEM_STASH_KEY" )"
    D_DPL_ITEM_IS_FORCED=false

    # Perform an action based on options available
    if __queue_hlp__current_item can_be_removed; then

      # Item is considered installed: remove it
      __d__queue_hlp__remove_item; case $? in
        0)  # Removed successfully
            all_already_removed=false
            all_failed=false
            dstash -s unset "$D_DPL_ITEM_STASH_KEY"
            dprint_debug "Removed item '$D_DPL_ITEM_TITLE'"
            ;;
        1)  # Failed to remove
            all_newly_removed=false
            all_already_removed=false
            some_failed=true
            dprint_debug "Failed to remove item '$D_DPL_ITEM_TITLE'"
            ;;
        2)  # Item found to be invalid during installation
            dprint_debug "Item '$D_DPL_ITEM_TITLE' found to be invalid" \
              'during removal'
            continue
            ;;
      esac

    elif $D_OPT_FORCE; then

      # Set marker in global variable
      D_DPL_ITEM_IS_FORCED=true

      # Item is considered already not installed, but user forces removal
      __d__queue_hlp__remove_item; case $? in
        0)  # Re-removed successfully
            all_newly_removed=false
            all_failed=false
            dstash -s unset "$D_DPL_ITEM_STASH_KEY"
            dprint_debug "Re-removed item '$D_DPL_ITEM_TITLE'"
            ;;
        1)  # Failed to re-remove
            all_newly_removed=false
            all_already_removed=false
            some_failed=true
            dprint_debug "Failed to re-remove item '$D_DPL_ITEM_TITLE'"
            ;;
        2)  # Item found to be invalid during installation
            dprint_debug "Item '$D_DPL_ITEM_TITLE' found to be invalid" \
              'during re-removal'
            continue
            ;;
      esac

    else

      # Item is considered already installed, and that’s the end of it
      all_newly_removed=false
      all_failed=false
    
    fi

    # If made it to here, current item is deemed okay-ish
    good_items_exist=true
  
  # Done iterating over items in deployment’s main queue
  done

  # Check if there was at least one good item in queue
  if ! $good_items_exist; then
    dprint_debug 'Not a single input item valid for removal'
    return 2
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

#>  __queue_hlp__current_item [ set FLAG ] | FLAG
#
## Convenience wrapper for storing pre-defined boolean flags in global array
#
__queue_hlp__current_item()
{
  # Check if first argument is the word ‘set’
  if [ "$1" = set ]; then

    # Setting flag: ditch first arg and add necessary flag
    shift; case $1 in
      is_invalid)         D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]+='x';;
      uses_stash)         D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]+='s';;
      can_be_installed)   D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]+='i';;
      can_be_removed)     D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]+='r';;
      *)                  return 1;;
    esac

  else

    # Checking flag: return 0/1 based on presence of requested flag
    case $1 in
      is_invalid)         [[ ${D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]} == *x* ]];;
      uses_stash)         [[ ${D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]} == *s* ]];;
      can_be_installed)   [[ ${D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]} == *i* ]];;
      can_be_removed)     [[ ${D_DPL_QUEUE_FLAGS[$D_DPL_ITEM_NUM]} == *r* ]];;
      *)                  return 1;;
    esac

  fi
}