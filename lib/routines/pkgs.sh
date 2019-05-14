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
## Shared subroutine that runs update process on detected $OS_PKGMGR
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
  if $D_PKGS; then

    # Name current task
    local task_desc='Update packages via'
    local task_name="'${OS_PKGMGR}'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" 0 "$task_desc" )"

    # Local flag for whether to proceed
    local proceeding=true

    # Don’t proceed if missing package manager
    [ -z "$OS_PKGMGR" ] && {
      task_name="$task_name (package manager not found)"
      proceeding=false
    }

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Print message about the upcoming installation
    if $proceeding; then
      dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"
    fi

    # Unless given a ‘-y’ option, prompt for user’s approval
    if $proceeding && [ "$D_BLANKET_ANSWER" != y ]; then
      dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }
    fi

    # Update packages
    if $proceeding; then
      os_pkgmgr dupdate
      if [ $? -eq 0 ]; then
        dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$GREEN" -- \
          'vvv' 'Installed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$RED" -- \
          'xxx' 'Failed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  fi

  return 0
}

__update_pkgs