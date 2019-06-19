#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: reconcile
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.18
#:revremark:    Initial revision
#:created_at:   2019.06.18

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments that contain multiple sub-deployments
#

#>  __catch_dcheck_code
#
## Intercepts last returned code ($?) and stores it in global array for future 
#. reference during installation/removal.
#
## Returns:
#.  The same return code it received (caught)
#
__catch_dcheck_code()
{
  # Extract last returned code ASAP
  local last_code=$?

  # Figure out current task number, assuming this function is called once per
  [ -z ${D_DPL_TASK_NUM+isset} ] && D_DPL_TASK_NUM=0 || (( D_DPL_TASK_NUM++ ))

  ## If not already, set up status array of booleans:
  #.  $D_DPL_TASK_STATUS_SUMMARY[0] - true if all tasks are unknown
  #.  $D_DPL_TASK_STATUS_SUMMARY[1] - true if all tasks are installed
  #.  $D_DPL_TASK_STATUS_SUMMARY[2] - true if all tasks are not installed
  #.  $D_DPL_TASK_STATUS_SUMMARY[3] - true if all tasks are irrelevant
  #.  $D_DPL_TASK_STATUS_SUMMARY[4] - true if all tasks are partly installed
  #.  $D_DPL_TASK_STATUS_SUMMARY[5] - true if all installed by user or OS
  #.                                  false if some installed by fmwk
  #.                                  unset if no installed parts encountered
  #
  [ -z ${D_DPL_TASK_STATUS_SUMMARY+isset} ] \
    && D_DPL_TASK_STATUS_SUMMARY=( true true true true true )

  # Small storage variable
  local i

  # Check exit code
  case $last_code in
    1)  # Installed: flip flags
        for i in 0 2 3 4; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done

        # Check if user-or-os flag is currently set
        if [ "$D_USER_OR_OS" = true ]; then

          # Installed by user or OS: no actions allowed

          # Unless some fmwk installations already detected, mark as user or OS
          [ "${D_DPL_TASK_STATUS_SUMMARY[5]}" = false ] \
            || D_DPL_TASK_STATUS_SUMMARY[5]=true

        else

          # Installed by framework: allow removal
          __multitask_hlp__current_task set can_be_removed

          # Definitely not user or OS
          D_DPL_TASK_STATUS_SUMMARY[5]=false

        fi
        ;;
    2)  # Not installed: flip flags
        for i in 0 1 3 4; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done

        # Allow installation
        __multitask_hlp__current_task set can_be_installed
        ;;
    3)  # Irrelevant: flip flags
        for i in 0 1 2 4; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done

        # Should not be touched
        __multitask_hlp__current_task set is_irrelevant
        ;;
    4)  # Partly installed: flip flags
        for i in 0 1 2 3; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done

        # Check if user-or-os flag is currently set
        if [ "$D_USER_OR_OS" = true ]; then

          # Partly installed by user or OS: allow installation
          __multitask_hlp__current_task set can_be_installed

          # Unless some fmwk installations already detected, mark as user or OS
          [ "${D_DPL_TASK_STATUS_SUMMARY[5]}" = false ] \
            || D_DPL_TASK_STATUS_SUMMARY[5]=true

        else

          # Partly installed by framework: allow installation and removal
          __multitask_hlp__current_task set can_be_installed
          __multitask_hlp__current_task set can_be_removed

          # Definitely not user or OS
          D_DPL_TASK_STATUS_SUMMARY[5]=false

        fi
        ;;
    *)  # Unknown status: flip flags
        for i in 1 2 3 4; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done

        # Allow installation and removal
        __multitask_hlp__current_task set can_be_installed
        __multitask_hlp__current_task set can_be_removed

        # With an unknown, we can’t say it’s all user or OS
        D_DPL_TASK_STATUS_SUMMARY[5]=false
        ;;
  esac

  # Re-return last code so that it can be picked up
  return $last_code
}

#>  __reconcile_dcheck_codes
#
## Analyzes previously stored return codes of dcheck-like functions and 
#. combines them into a single return code.
#
## Returns:
#.  0 - Unknown
#.  1 - Installed
#.  2 - Not installed
#.  3 - Irrelevant
#.  4 - Partly installed
#
__reconcile_dcheck_codes()
{
  # First off, reset task number counter (for following installations/removals)
  unset D_DPL_TASK_NUM

  # Settle user-or-os status
  if [ "${D_DPL_TASK_STATUS_SUMMARY[5]}" = true ]; then D_USER_OR_OS=true
  else D_USER_OR_OS=false; fi

  # Storage variable for return code
  local return_code

  # Sequentially check if at least one all-code survived
  if [ "${D_DPL_TASK_STATUS_SUMMARY[0]}" = true ]; then return_code=0
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[1]}" = true ]; then return_code=1
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[2]}" = true ]; then return_code=2
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[3]}" = true ]; then return_code=3
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[4]}" = true ]; then return_code=4
  else
    # Nothing conclusive: check if any kind of installation was encountered
    if [ -z ${D_DPL_TASK_STATUS_SUMMARY[5]+isset} ]; then
      # No installations: this is a mix on ‘not installed’ and ‘irrelevant’
      return_code=2
    else
      # Some installations: call this partially installed
      return_code=4
    fi
  fi

  # Reset flag storage (for following installations/removals)
  unset D_DPL_TASK_STATUS_SUMMARY

  # Return agreed code
  return $return_code
}

#>  __task_is_installable
#
## Signals if current task has been previously detected as installable
#
## Provides into the global scope:
#.  $D_DPL_TASK_IS_FORCED - Sets this to ‘true’ if installation is being 
#.                          forced, i.e., it would not have been initiated if 
#.                          not for force option.
#
## Returns:
#.  0 - Task may be installed
#.  1 - Otherwise
#
__task_is_installable()
{
  # Make sure $D_DPL_TASK_IS_FORCED is not inherited from previous tasks
  unset D_DPL_TASK_IS_FORCED

  # Figure out current task number, assuming this function is called once per
  [ -z ${D_DPL_TASK_NUM+isset} ] && D_DPL_TASK_NUM=0 || (( D_DPL_TASK_NUM++ ))

  # If task is irrelevant, return immediately
  if __multitask_hlp__current_task is_irrelevant; then return 1; fi

  # Check pre-recorded status
  if __multitask_hlp__current_task can_be_installed; then
    # Go for it
    return 0
  else
    # Not suitable for installation: only go in forced mode
    if $D_OPT_FORCE; then D_DPL_TASK_IS_FORCED=true; return 0
    else
      # This task will be skipped: set flag and return
      __multitask_hlp__current_task set is_skipped
      return 1
    fi
  fi
}

#>  __catch_dinstall_code
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
__catch_dinstall_code()
{
  # Extract last returned code ASAP
  local last_code=$?

  # If task was irrelevant, don’t bother with anything
  if __multitask_hlp__current_task is_irrelevant; then return 0; fi

  ## If not already, set up status array of booleans:
  #.  $D_DPL_TASK_STATUS_SUMMARY[0] - true if all tasks were installed
  #.  $D_DPL_TASK_STATUS_SUMMARY[1] - true if all tasks failed to install
  #.  $D_DPL_TASK_STATUS_SUMMARY[2] - true if all tasks were skipped
  #.  $D_DPL_TASK_STATUS_SUMMARY[3] - true if at least one failure occurred
  #.                                  false if no failures occurred
  #
  [ -z ${D_DPL_TASK_STATUS_SUMMARY+isset} ] \
    && D_DPL_TASK_STATUS_SUMMARY=( true true true false )

  # If task was skipped, flip flags and return
  if __multitask_hlp__current_task is_skipped; then
    for i in 0 1; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
    return 0
  fi

  # Small storage variable
  local i

  # Check exit code
  case $last_code in
    1)    # Failed to install: flip flags
          for i in 0 2; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
          # Also, mark occurrence of failure
          D_DPL_TASK_STATUS_SUMMARY[3]=true
          ;;
    2)    # Skipped: flip flags
          for i in 0 1; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
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
          for i in 1 2; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
          ;;
  esac

  # For non-emergencies, always return a-okay
  return 0
}

#>  __reconcile_dinstall_codes
#
## Analyzes previously stored return codes of dinstall-like functions and 
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
__reconcile_dinstall_codes()
{
  # Sequentially check if at least one all-code survived
  if [ "${D_DPL_TASK_STATUS_SUMMARY[0]}" = true ]; then return 0
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[1]}" = true ]; then return 1
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[2]}" = true ]; then return 2
  else
    # Nothing conclusive: check if failure was encountered
    if [ "${D_DPL_TASK_STATUS_SUMMARY[3]}" = true ]; then
      # Some failed: call this failure
      return 1
    else
      # Mix of installed and skipped: call this installed
      return 0
    fi
  fi
}

#>  __task_is_removable
#
## Signals if current task has been previously detected as removable
#
## Provides into the global scope:
#.  $D_DPL_TASK_IS_FORCED - Sets this to ‘true’ if removal is being forced, 
#.                          i.e., it would not have been initiated if not for 
#.                          force option.
#
## Returns:
#.  0 - Task may be removed
#.  1 - Otherwise
#
__task_is_removable()
{
  # Make sure $D_DPL_TASK_IS_FORCED is not inherited from previous tasks
  unset D_DPL_TASK_IS_FORCED

  # Figure out current task number, assuming this function is called once per
  [ -z ${D_DPL_TASK_NUM+isset} ] && D_DPL_TASK_NUM=0 || (( D_DPL_TASK_NUM++ ))

  # If task is irrelevant, return immediately
  if __multitask_hlp__current_task is_irrelevant; then return 1; fi

  # Check pre-recorded status
  if __multitask_hlp__current_task can_be_removed; then
    # Go for it
    return 0
  else
    # Not suitable for removal: only go in forced mode
    if $D_OPT_FORCE; then D_DPL_TASK_IS_FORCED=true; return 0
    else
      # This task will be skipped: set flag and return
      __multitask_hlp__current_task set is_skipped
      return 1
    fi
  fi
}

#>  __catch_dremove_code
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
__catch_dremove_code()
{
  # Extract last returned code ASAP
  local last_code=$?

  # If task was irrelevant, don’t bother with anything
  if __multitask_hlp__current_task is_irrelevant; then return 0; fi

  ## If not already, set up status array of booleans:
  #.  $D_DPL_TASK_STATUS_SUMMARY[0] - true if all tasks were removed
  #.  $D_DPL_TASK_STATUS_SUMMARY[1] - true if all tasks failed to remove
  #.  $D_DPL_TASK_STATUS_SUMMARY[2] - true if all tasks were skipped
  #.  $D_DPL_TASK_STATUS_SUMMARY[3] - true if at least one failure occurred
  #.                                  false if no failures occurred
  #
  [ -z ${D_DPL_TASK_STATUS_SUMMARY+isset} ] \
    && D_DPL_TASK_STATUS_SUMMARY=( true true true false )

  # If task was skipped, flip flags and return
  if __multitask_hlp__current_task is_skipped; then
    for i in 0 1; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
    return 0
  fi

  # Small storage variable
  local i

  # Check exit code
  case $last_code in
    1)    # Failed to install: flip flags
          for i in 0 2; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
          # Also, mark occurrence of failure
          D_DPL_TASK_STATUS_SUMMARY[3]=true
          ;;
    2)    # Skipped: flip flags
          for i in 0 1; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
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
          for i in 1 2; do D_DPL_TASK_STATUS_SUMMARY[$i]=false; done
          ;;
  esac

  # For non-emergencies, always return a-okay
  return 0
}

#>  __reconcile_dremove_codes
#
## Analyzes previously stored return codes of dremove-like functions and 
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
__reconcile_dremove_codes()
{
  # Sequentially check if at least one all-code survived
  if [ "${D_DPL_TASK_STATUS_SUMMARY[0]}" = true ]; then return 0
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[1]}" = true ]; then return 1
  elif [ "${D_DPL_TASK_STATUS_SUMMARY[2]}" = true ]; then return 2
  else
    # Nothing conclusive: check if failure was encountered
    if [ "${D_DPL_TASK_STATUS_SUMMARY[3]}" = true ]; then
      # Some failed: call this failure
      return 1
    else
      # Mix of removed and skipped: call this removed
      return 0
    fi
  fi
}

#>  __multitask_hlp__current_task [ set FLAG ] | FLAG
#
## Convenience wrapper for storing pre-defined boolean flags in global array
#
__multitask_hlp__current_task()
{
  # Check if first argument is the word ‘set’
  if [ "$1" = set ]; then

    # Setting flag: ditch first arg and add necessary flag
    shift; case $1 in
      is_irrelevant)      D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]+='x';;
      can_be_installed)   D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]+='i';;
      can_be_removed)     D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]+='r';;
      is_skipped)         D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]+='s';;
      *)                  return 1;;
    esac

  else

    # Checking flag: return 0/1 based on presence of requested flag
    case $1 in
      is_irrelevant)      [[ ${D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]} == *x* ]];;
      can_be_installed)   [[ ${D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]} == *i* ]];;
      can_be_removed)     [[ ${D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]} == *r* ]];;
      is_skipped)         [[ ${D_DPL_TASK_FLAGS[$D_DPL_TASK_NUM]} == *s* ]];;
      *)                  return 1;;
    esac

  fi
}