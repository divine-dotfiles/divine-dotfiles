#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: reconcile
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    13
#:revdate:      2019.07.22
#:revremark:    New revisioning system
#:created_at:   2019.06.18

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments that contain multiple sub-deployments
#

d__multitask_check()
{
  # Check whether at least one task name has been provided
  if [ -z "${D_MULTITASK_NAMES+isset}" -o ${#D_MULTITASK_NAMES[@]} -eq 0 ]; then

    # No tasks: return default code
    return 0

  fi

  # Storage variables
  local task_name func_name

  # Iterate over task names
  for task_name in "${D_MULTITASK_NAMES[@]}"; do

    # Compose d_dpl_check function name for that task
    func_name="d_${task_name}_check"

    # If d_dpl_check function is implemented, run it, otherwise run a bogus func
    if declare -f -- "$func_name" &>/dev/null; then
      "$func_name"
    else
      true
    fi

    # Catch returned code
    d__multitask_catch_check_code

  # Done iterating over task names
  done

  # As the last command, combine all previously caught d_dpl_check codes
  d__multitask_reconcile_check_codes
}

d__multitask_install()
{
  # Check whether at least one task name has been provided
  if [ -z "${D_MULTITASK_NAMES+isset}" -o ${#D_MULTITASK_NAMES[@]} -eq 0 ]; then

    # No tasks: return default code
    return 0

  fi

  # Storage variables
  local task_name func_name

  # Iterate over task names
  for task_name in "${D_MULTITASK_NAMES[@]}"; do

    # Compose d_dpl_install function name for that task
    func_name="d_${task_name}_install"

    # If d_dpl_install function is implemented, run it, otherwise run a bogus func
    if declare -f -- "$func_name" &>/dev/null; then
      d__multitask_task_is_installable && "$func_name"
    else
      d__multitask_task_is_installable && true
    fi

    # Catch returned code, or return immediately (emergency exit)
    d__multitask_catch_install_code || return $?

  # Done iterating over task names
  done

  # As the last command, combine all previously caught d_dpl_install codes
  d__multitask_reconcile_install_codes
}

d__multitask_remove()
{
  # Check whether at least one task name has been provided
  if [ -z "${D_MULTITASK_NAMES+isset}" -o ${#D_MULTITASK_NAMES[@]} -eq 0 ]; then

    # No tasks: return default code
    return 0

  fi

  # Storage variables
  local task_name func_name i

  # Iterate over task names in reverse order
  for (( i=$D__MULTITASK_MAX_NUM; i>=0; i-- )); do

    # Extract task name
    task_name="${D_MULTITASK_NAMES[$i]}"

    # Compose d_dpl_remove function name for that task
    func_name="d_${task_name}_remove"

    # If d_dpl_remove function is implemented, run it, otherwise run a bogus func
    if declare -f -- "$func_name" &>/dev/null; then
      d__multitask_task_is_removable && "$func_name"
    else
      d__multitask_task_is_removable && true
    fi

    # Catch returned code, or return immediately (emergency exit)
    d__multitask_catch_remove_code || return $?

  # Done iterating over task names in reverse order
  done

  # As the last command, combine all previously caught d_dpl_remove codes
  d__multitask_reconcile_remove_codes
}

#>  d__multitask_catch_check_code
#
## Intercepts last returned code ($?) and stores it in global array for future 
#. reference during installation/removal.
#
## Returns:
#.  The same return code it received (caught)
#
d__multitask_catch_check_code()
{
  # Extract last returned code ASAP
  local last_code=$?

  # Figure out current task number, assuming this function is called once per
  [ -z ${D__MULTITASK_NUM+isset} ] && D__MULTITASK_NUM=0 || (( D__MULTITASK_NUM++ ))

  ## If not already, set up status array of booleans:
  #.  $D__MULTITASK_STATUS_SUMMARY[0] - true if all tasks are unknown
  #.  $D__MULTITASK_STATUS_SUMMARY[1] - true if all tasks are installed
  #.  $D__MULTITASK_STATUS_SUMMARY[2] - true if all tasks are not installed
  #.  $D__MULTITASK_STATUS_SUMMARY[3] - true if all tasks are irrelevant
  #.  $D__MULTITASK_STATUS_SUMMARY[4] - true if all tasks are partly installed
  #.  $D__MULTITASK_STATUS_SUMMARY[5] - true if all installed by user or OS
  #.                                  false if some installed by fmwk
  #.                                  unset if no installed parts encountered
  #
  [ -z ${D__MULTITASK_STATUS_SUMMARY+isset} ] \
    && D__MULTITASK_STATUS_SUMMARY=( true true true true true )

  # Small storage variable
  local j

  # Check exit code
  case $last_code in
    1)  # Installed: flip flags
        for j in 0 2 3 4; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done

        # Check if user-or-os flag is currently set
        if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then

          # Installed by user or OS: no actions allowed

          # Unless some fmwk installations already detected, mark as user or OS
          [ "${D__MULTITASK_STATUS_SUMMARY[5]}" = false ] \
            || D__MULTITASK_STATUS_SUMMARY[5]=true

        else

          # Installed by framework: allow removal
          d__multitask_task_status set can_be_removed

          # Definitely not user or OS
          D__MULTITASK_STATUS_SUMMARY[5]=false

        fi
        ;;
    2)  # Not installed: flip flags
        for j in 0 1 3 4; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done

        # Allow installation
        d__multitask_task_status set can_be_installed
        ;;
    3)  # Irrelevant: flip flags
        for j in 0 1 2 4; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done

        # Should not be touched
        d__multitask_task_status set is_irrelevant
        ;;
    4)  # Partly installed: flip flags
        for j in 0 1 2 3; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done

        # Check if user-or-os flag is currently set
        if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then

          # Partly installed by user or OS: allow installation
          d__multitask_task_status set can_be_installed

          # Unless some fmwk installations already detected, mark as user or OS
          [ "${D__MULTITASK_STATUS_SUMMARY[5]}" = false ] \
            || D__MULTITASK_STATUS_SUMMARY[5]=true

        else

          # Partly installed by framework: allow installation and removal
          d__multitask_task_status set can_be_installed
          d__multitask_task_status set can_be_removed

          # Definitely not user or OS
          D__MULTITASK_STATUS_SUMMARY[5]=false

        fi
        ;;
    *)  # Unknown status: flip flags
        for j in 1 2 3 4; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done

        # Allow installation and removal
        d__multitask_task_status set can_be_installed
        d__multitask_task_status set can_be_removed

        # With an unknown, we can’t say it’s all user or OS
        D__MULTITASK_STATUS_SUMMARY[5]=false
        ;;
  esac

  # Re-return last code so that it can be picked up
  return $last_code
}

#>  d__multitask_reconcile_check_codes
#
## Analyzes previously stored return codes of d_dpl_check-like functions and 
#. combines them into a single return code.
#
## Returns:
#.  0 - Unknown
#.  1 - Installed
#.  2 - Not installed
#.  3 - Irrelevant
#.  4 - Partly installed
#
d__multitask_reconcile_check_codes()
{
  # Remember total number of tasks
  D__MULTITASK_MAX_NUM=$(( $D__MULTITASK_NUM ))

  # Reset task number counter (for following installations/removals)
  unset D__MULTITASK_NUM

  # Settle user-or-os status
  if [ "${D__MULTITASK_STATUS_SUMMARY[5]}" = true ]; then D_DPL_INSTALLED_BY_USER_OR_OS=true
  else D_DPL_INSTALLED_BY_USER_OR_OS=false; fi

  # Storage variable for return code
  local return_code

  # Sequentially check if at least one all-code survived
  if [ "${D__MULTITASK_STATUS_SUMMARY[0]}" = true ]; then return_code=0
  elif [ "${D__MULTITASK_STATUS_SUMMARY[1]}" = true ]; then return_code=1
  elif [ "${D__MULTITASK_STATUS_SUMMARY[2]}" = true ]; then return_code=2
  elif [ "${D__MULTITASK_STATUS_SUMMARY[3]}" = true ]; then return_code=3
  elif [ "${D__MULTITASK_STATUS_SUMMARY[4]}" = true ]; then return_code=4
  else
    # Nothing conclusive: check if any kind of installation was encountered
    if [ -z ${D__MULTITASK_STATUS_SUMMARY[5]+isset} ]; then
      # No installations: this is a mix on ‘not installed’ and ‘irrelevant’
      return_code=2
    else
      # Some installations: call this partially installed
      return_code=4
    fi
  fi

  # Reset flag storage (for following installations/removals)
  unset D__MULTITASK_STATUS_SUMMARY

  # Return agreed code
  return $return_code
}

#>  d__multitask_task_is_installable
#
## Signals if current task has been previously detected as installable
#
## Provides into the global scope:
#.  $D__MULTITASK_IS_FORCED - Sets this to ‘true’ if installation is being 
#.                          forced, i.e., it would not have been initiated if 
#.                          not for force option.
#
## Returns:
#.  0 - Task may be installed
#.  1 - Otherwise
#
d__multitask_task_is_installable()
{
  # Make sure $D__MULTITASK_IS_FORCED is not inherited from previous tasks
  unset D__MULTITASK_IS_FORCED

  # Figure out current task number, assuming this function is called once per
  [ -z ${D__MULTITASK_NUM+isset} ] && D__MULTITASK_NUM=0 || (( D__MULTITASK_NUM++ ))

  # If task is irrelevant, return immediately
  if d__multitask_task_status is_irrelevant; then return 1; fi

  # Check pre-recorded status
  if d__multitask_task_status can_be_installed; then
    # Go for it
    return 0
  else
    # Not suitable for installation: only go in forced mode
    if $D__OPT_FORCE; then D__MULTITASK_IS_FORCED=true; return 0
    else
      # This task will be skipped: set flag and return
      d__multitask_task_status set is_skipped
      return 1
    fi
  fi
}

#>  d__multitask_catch_install_code
#
## Intercepts last returned code ($?) and stores it in global array for future 
#. reference during reconciliation of installation codes.
#
## Returns:
#.  0   - Task is either installed, failed, or skipped (non-emergency)
#.  100 - Emergency: reboot needed
#.  101 - Emergency: user attention needed
#.  666 - Emergency: critical failure
#
d__multitask_catch_install_code()
{
  # Extract last returned code ASAP
  local last_code=$?

  # If task was irrelevant, don’t bother with anything
  if d__multitask_task_status is_irrelevant; then return 0; fi

  ## If not already, set up status array of booleans:
  #.  $D__MULTITASK_STATUS_SUMMARY[0] - true if all tasks were installed
  #.  $D__MULTITASK_STATUS_SUMMARY[1] - true if all tasks failed to install
  #.  $D__MULTITASK_STATUS_SUMMARY[2] - true if all tasks were skipped
  #.  $D__MULTITASK_STATUS_SUMMARY[3] - true if at least one failure occurred
  #.                                  false if no failures occurred
  #
  [ -z ${D__MULTITASK_STATUS_SUMMARY+isset} ] \
    && D__MULTITASK_STATUS_SUMMARY=( true true true false )

  # Small storage variable
  local j

  # If task was skipped, flip flags and return
  if d__multitask_task_status is_skipped; then
    for j in 0 1; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
    return 0
  fi

  # Check exit code
  case $last_code in
    1)    # Failed to install: flip flags
          for j in 0 2; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
          # Also, mark occurrence of failure
          D__MULTITASK_STATUS_SUMMARY[3]=true
          ;;
    2)    # Skipped: flip flags
          for j in 0 1; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
          ;;
    100)  # Emergency: reboot needed
          return 100
          ;;
    101)  # Emergency: user attention needed
          return 101
          ;;
    666)  # Emergency: critical failure
          return 666
          ;;
    *)    # Installed: flip flags
          for j in 1 2; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
          ;;
  esac

  # For non-emergencies, always return a-okay
  return 0
}

#>  d__multitask_reconcile_install_codes
#
## Analyzes previously stored return codes of d_dpl_install-like functions and 
#. combines them into a single return code.
#
## Returns:
#.  0   - Successfully installed
#.  1   - Failed to install
#.  2   - Skipped completely
#.  100 - Reboot needed
#.  101 - User attention needed
#.  666 - Critical failure
#
d__multitask_reconcile_install_codes()
{
  # Sequentially check if at least one all-code survived
  if [ "${D__MULTITASK_STATUS_SUMMARY[0]}" = true ]; then return 0
  elif [ "${D__MULTITASK_STATUS_SUMMARY[1]}" = true ]; then return 1
  elif [ "${D__MULTITASK_STATUS_SUMMARY[2]}" = true ]; then return 2
  else
    # Nothing conclusive: check if failure was encountered
    if [ "${D__MULTITASK_STATUS_SUMMARY[3]}" = true ]; then
      # Some failed: call this failure
      return 1
    else
      # Mix of installed and skipped: call this installed
      return 0
    fi
  fi
}

#>  d__multitask_task_is_removable
#
## Signals if current task has been previously detected as removable
#
## Provides into the global scope:
#.  $D__MULTITASK_IS_FORCED - Sets this to ‘true’ if removal is being forced, 
#.                          i.e., it would not have been initiated if not for 
#.                          force option.
#
## Returns:
#.  0 - Task may be removed
#.  1 - Otherwise
#
d__multitask_task_is_removable()
{
  # Make sure $D__MULTITASK_IS_FORCED is not inherited from previous tasks
  unset D__MULTITASK_IS_FORCED

  # Figure out current task number, assuming this function is called once per
  if [ -z ${D__MULTITASK_NUM+isset} ]; then
    D__MULTITASK_NUM="$D__MULTITASK_MAX_NUM"
  else
    (( D__MULTITASK_NUM-- ))
  fi

  # If task is irrelevant, return immediately
  if d__multitask_task_status is_irrelevant; then return 1; fi

  # Check pre-recorded status
  if d__multitask_task_status can_be_removed; then
    # Go for it
    return 0
  else
    # Not suitable for removal: only go in forced mode
    if $D__OPT_FORCE; then D__MULTITASK_IS_FORCED=true; return 0
    else
      # This task will be skipped: set flag and return
      d__multitask_task_status set is_skipped
      return 1
    fi
  fi
}

#>  d__multitask_catch_remove_code
#
## Intercepts last returned code ($?) and stores it in global array for future 
#. reference during reconciliation of removal codes.
#
## Returns:
#.  0   - Task is either removed, failed, or skipped (non-emergency)
#.  100 - Emergency: reboot needed
#.  101 - Emergency: user attention needed
#.  666 - Emergency: critical failure
#
d__multitask_catch_remove_code()
{
  # Extract last returned code ASAP
  local last_code=$?

  # If task was irrelevant, don’t bother with anything
  if d__multitask_task_status is_irrelevant; then return 0; fi

  ## If not already, set up status array of booleans:
  #.  $D__MULTITASK_STATUS_SUMMARY[0] - true if all tasks were removed
  #.  $D__MULTITASK_STATUS_SUMMARY[1] - true if all tasks failed to remove
  #.  $D__MULTITASK_STATUS_SUMMARY[2] - true if all tasks were skipped
  #.  $D__MULTITASK_STATUS_SUMMARY[3] - true if at least one failure occurred
  #.                                  false if no failures occurred
  #
  [ -z ${D__MULTITASK_STATUS_SUMMARY+isset} ] \
    && D__MULTITASK_STATUS_SUMMARY=( true true true false )

  # Small storage variable
  local j

  # If task was skipped, flip flags and return
  if d__multitask_task_status is_skipped; then
    for j in 0 1; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
    return 0
  fi

  # Check exit code
  case $last_code in
    1)    # Failed to install: flip flags
          for j in 0 2; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
          # Also, mark occurrence of failure
          D__MULTITASK_STATUS_SUMMARY[3]=true
          ;;
    2)    # Skipped: flip flags
          for j in 0 1; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
          ;;
    100)  # Emergency: reboot needed
          return 100
          ;;
    101)  # Emergency: user attention needed
          return 101
          ;;
    666)  # Emergency: critical failure
          return 666
          ;;
    *)    # Installed: flip flags
          for j in 1 2; do D__MULTITASK_STATUS_SUMMARY[$j]=false; done
          ;;
  esac

  # For non-emergencies, always return a-okay
  return 0
}

#>  d__multitask_reconcile_remove_codes
#
## Analyzes previously stored return codes of d_dpl_remove-like functions and 
#. combines them into a single return code.
#
## Returns:
#.  0   - Successfully removed
#.  1   - Failed to remove
#.  2   - Skipped completely
#.  100 - Reboot needed
#.  101 - User attention needed
#.  666 - Critical failure
#
d__multitask_reconcile_remove_codes()
{
  # Sequentially check if at least one all-code survived
  if [ "${D__MULTITASK_STATUS_SUMMARY[0]}" = true ]; then return 0
  elif [ "${D__MULTITASK_STATUS_SUMMARY[1]}" = true ]; then return 1
  elif [ "${D__MULTITASK_STATUS_SUMMARY[2]}" = true ]; then return 2
  else
    # Nothing conclusive: check if failure was encountered
    if [ "${D__MULTITASK_STATUS_SUMMARY[3]}" = true ]; then
      # Some failed: call this failure
      return 1
    else
      # Mix of removed and skipped: call this removed
      return 0
    fi
  fi
}

#>  d__multitask_task_status [ set FLAG ] | FLAG
#
## Convenience wrapper for storing pre-defined boolean flags in global array
#
d__multitask_task_status()
{
  # Check if first argument is the word ‘set’
  if [ "$1" = set ]; then

    # Setting flag: ditch first arg and add necessary flag
    shift; case $1 in
      is_irrelevant)      D__MULTITASK_FLAGS[$D__MULTITASK_NUM]+='x';;
      can_be_installed)   D__MULTITASK_FLAGS[$D__MULTITASK_NUM]+='i';;
      can_be_removed)     D__MULTITASK_FLAGS[$D__MULTITASK_NUM]+='r';;
      is_skipped)         D__MULTITASK_FLAGS[$D__MULTITASK_NUM]+='s';;
      *)                  return 1;;
    esac

  else

    # Checking flag: return 0/1 based on presence of requested flag
    case $1 in
      is_irrelevant)      [[ ${D__MULTITASK_FLAGS[$D__MULTITASK_NUM]} == *x* ]];;
      can_be_installed)   [[ ${D__MULTITASK_FLAGS[$D__MULTITASK_NUM]} == *i* ]];;
      can_be_removed)     [[ ${D__MULTITASK_FLAGS[$D__MULTITASK_NUM]} == *r* ]];;
      is_skipped)         [[ ${D__MULTITASK_FLAGS[$D__MULTITASK_NUM]} == *s* ]];;
      *)                  return 1;;
    esac

  fi
}