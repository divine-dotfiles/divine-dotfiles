#!/usr/bin/env bash
#:title:        Divine Bash routine: pkgs
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.14
#:revremark:    Initial revision
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Updates currently installed packages
#

#> __update_pkgs
#
## Shared subroutine that runs update process on detected $D__OS_PKGMGR
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Always
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__update_pkgs()
{
  # Only if packages are to be touched at all
  if $D__REQ_PACKAGES; then

    # Name current task
    local task_desc='System packages via'
    local task_name="'${D__OS_PKGMGR}'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D__REQ_MAX_PRIORITY_LEN}d) %s\n" 0 "$task_desc" )"

    # Local flag for whether to proceed
    local proceeding=true

    # Don’t proceed if missing package manager
    [ -z "$D__OS_PKGMGR" ] && {
      task_name="$task_name (package manager not found)"
      proceeding=false
    }

    # Don’t proceed if ‘-n’ option is given
    [ "$D__OPT_ANSWER" = false ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Print message about the upcoming installation
    if $proceeding; then
      dprint_ode "${D__ODE_UPDATE[@]}" -c "$YELLOW" -- \
        '>>>' 'Updating' ':' "$task_desc" "$task_name"
    fi

    # Unless given a ‘-y’ option, prompt for user’s approval
    if $proceeding && [ "$D__OPT_ANSWER" != true ]; then
      dprint_ode "${D__ODE_PROMPT[@]}" -- '' 'Confirm' ': '
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }
    fi

    # Update packages
    if $proceeding; then

      # Launch OS package manager with verbosity in mind
      if $D__OPT_QUIET; then

        # Launch quietly
        d__os_pkgmgr update &>/dev/null

      else

        # Launch normally, but re-paint output
        local line
        d__os_pkgmgr update 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
          printf "${CYAN}==> %s${NORMAL}\n" "$line"
        done

      fi

      # Check return status
      if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        dprint_ode "${D__ODE_UPDATE[@]}" -c "$GREEN" -- \
          'vvv' 'Updated' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D__ODE_UPDATE[@]}" -c "$RED" -- \
          'xxx' 'Failed to update' ':' "$task_desc" "$task_name"
      fi

    else

      # Not updating packages
      dprint_ode "${D__ODE_UPDATE[@]}" -c "$WHITE" -- \
        '---' 'Skipped updating' ':' "$task_desc" "$task_name"

    fi

  fi

  return 0
}

__update_pkgs