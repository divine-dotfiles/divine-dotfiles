#!/usr/bin/env bash
#:title:        Divine Bash routine: pkgs
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.01
#:revremark:    Rewrite package updating for new output & intros
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Updates currently installed system packages
#

#>  d__update_pkgs
#
## Shared subroutine that runs update+upgrade process on detected $D__OS_PKGMGR
#
## Returns:
#.  0 - Always
#
d__update_pkgs()
{
  # Cut-off checks
  if ! $D__REQ_PACKAGES; then
    d__notify -qqn -- 'Skipping updating packages (Divinefiles not requested)'
    return 0
  elif [ -z "$D__OS_PKGMGR" ]; then
    d__notify -lns -- \
      'Skipping updating packages (package manager not supported)'
    return 0
  fi

  # Set marker; compose name of the task
  local proceeding=true task_name=
  task_name+="$( printf "(%${D__REQ_MAX_PRIORITY_LEN}d)" 0 )"
  task_name+=" System packages via '$BOLD$D__OS_PKGMGR$NORMAL'"

  # Print a separating empty line, then make a decision
  printf '\n'; if [ "$D__OPT_ANSWER" = false ]; then proceeding=false
  else
    printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$task_name"
    if [ "$D__OPT_ANSWER" != true ]; then
      printf >&2 '%s ' "$D__INTRO_CNF_N"; d__prompt -b || proceeding=false
    fi
  fi

  # Early exit for skipped updating
  if ! $proceeding; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$task_name"
    return 0
  fi

  # Launch OS package manager with verbosity in mind
  if (($D__OPT_VERBOSITY)); then
    local line
    d__os_pkgmgr update 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
      printf '%s\n' "$CYAN$line$NORMAL"
    done
  else d__os_pkgmgr update &>/dev/null; fi

  # Check return status
  if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$task_name"
  else
    d__notify -l! -- "System package manager '$D__OS_PKGMGR'" \
      'returned an error code while updating packages' \
      -n- 'This may or may not be problematic'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$task_name"
  fi
}

d__update_pkgs