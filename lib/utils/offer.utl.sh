#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: offer
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    17
#:revdate:      2019.09.23
#:revremark:    Move offer to utils
#:created_at:   2019.07.06

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function that offers to install required/optional dependency
#

#>  d__offer_system_pkg [--exit-on-q] UTIL_NAME
#
## Checks whether UTIL_NAME is available on the system and, if not, offers to 
#. install it using system's package manager, if it itself is available
#
## Options:
#.  --exit-on-q   - If user refuses to install and chooses not to proceed at 
#.                  all by selecting 'q' response to prompt, exit the entire 
#.                  script immediately instead of returning appropriate status
#
## Returns:
#.  0 - UTIL_NAME is available or successfully installed
#.  1 - UTIL_NAME is not available, or user refused it, or it failed to install
#.  2 - User refused to install and chose to not proceed at all
#.  1 - (script exit) (with --exit-on-q) User refused to install and chose to 
#.      not proceed at all
#
d__offer_system_pkg()
{
  # Check for option
  local exit_on_q=false
  [ "$1" = '--exit-on-q' ] && { exit_on_q=true; shift; }

  # Extract util name
  local util_name="$1"

  # If command by that name is available on $PATH, return zero immediately
  case $util_name in
    git)  git --version &>/dev/null;;
    tar)  tar --version &>/dev/null;;
    curl) curl --version &>/dev/null;;
    wget) wget --version &>/dev/null;;
    *)    type -P -- "$util_name" &>/dev/null;;
  esac; [ $? -eq 0 ] && return 0

  # Print initial warning
  dprint_debug "Failed to detect $util_name executable on \$PATH"

  # Check if $D__OS_PKGMGR is detected
  if [ -z ${D__OS_PKGMGR+isset} ]; then

    # No option to install: report and return
    dprint_failure \
      "Unable to auto-install $util_name (no supported package manager)"
    return 1
  
  else

    # Prompt user for whether to install utility
    dprompt -b --color "$YELLOW" --or-quit --answer "$D__OPT_ANSWER" \
      --prompt "Install $util_name using $D__OS_PKGMGR?"

    # Check status
    case $? in
      0)  # Agreed to install

          # Announce installation
          dprint_alert "Installing $util_name"

          # Launch OS package manager with verbosity in mind
          if $D__OPT_QUIET; then

            # Launch quietly
            d__os_pkgmgr install "$util_name" &>/dev/null

          else

            # Launch normally, but re-paint output
            local line
            d__os_pkgmgr install "$util_name" 2>&1 \
              | while IFS= read -r line || [ -n "$line" ]; do
              printf "${CYAN}==> %s${NORMAL}\n" "$line"
            done

          fi

          # Check return status
          if [ "${PIPESTATUS[0]}" -eq 0 ]; then

            # Make record of installation
            if d__stash -r -s add installed_util "$util_name"; then
              dprint_debug "Recorded installation of $util_name to root stash"
            else
              dprint_failure \
                "Failed to record installation of $util_name to root stash"
            fi

            # Announce success
            dprint_success "Successfully installed $util_name"

            # Return status
            return 0

          else

            # Announce and return failure
            dprint_failure "Failed to install $util_name"
            return 1
            
          fi

          # Done with installation
          ;;

      1)  # Refused to install

          # Announce refusal to install and return
          dprint_skip "Refused to install $util_name"
          return 1

          # Done with refusal
          ;;
      
      *)  # Refused to proceed at all

          # Announce exiting and exit the script
          dprint_failure \
            "Refused to install $util_name or proceed without it"
          if $exit_on_q; then exit 1; else return 2; fi

          # Done with exiting
          ;;
    esac

  fi
}