#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: offer
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.07.06
#:revremark:    Initial revision
#:created_at:   2019.07.06

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper function that offers to install required/optional dependency
#

#>  __offer_util [--exit-on-q] UTIL_NAME
#
## Checks whether UTIL_NAME is available on the system and, if not, offers to 
#. install it using system’s package manager, if it itself is available
#
## Options:
#.  --exit-on-q   - If user refuses to install and chooses not to proceed at 
#.                  all by selecting ‘q’ response to prompt, exit the entire 
#.                  script immediately instead of returning appropriate status
#
## Returns:
#.  0 - UTIL_NAME is available or successfully installed
#.  1 - UTIL_NAME is not available, or user refused it, or it failed to install
#.  2 - User refused to install and chose to not proceed at all
#.  1 - (script exit) (with --exit-on-q) User refused to install and chose to 
#.      not proceed at all
#
__offer_util()
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
  dprint_debug "Failed to detect $util_name executable"

  # Check if $OS_PKGMGR is detected
  if [ -z ${OS_PKGMGR+isset} ]; then

    # No option to install: report and return
    dprint_failure -l \
      "Unable to auto-install $util_name (no supported package manager)"
    return 1
  
  else

    # Prompt user for whether to install utility
    dprompt_key --bare --or-quit \
      --prompt "Install $util_name using $OS_PKGMGR?"

    # Check status
    case $? in
      0)  # Agreed to install

          # Announce installation
          dprint_debug "Installing $util_name"

          # Attempt installation
          if os_pkgmgr dinstall "$util_name"; then

            # Announce success
            dprint_success -l "Successfully installed $util_name"

            # Make record of installation
            if dstash -r -s add util_installed "$util_name"; then
              dprint_debug "Recorded installation to root stash"
            else
              dprint_failure -l \
                "Failed to record installation of $util_name to root stash"
            fi

            # Return status
            return 0

          else

            # Announce and return failure
            dprint_failure -l "Failed to install $util_name"
            return 1
            
          fi

          # Done with installation
          ;;

      1)  # Refused to install

          # Announce refusal to install and return
          dprint_skip -l "Refused to install $util_name"
          return 1

          # Done with refusal
          ;;
      
      *)  # Refused to proceed at all

          # Announce exiting and exit the script
          dprint_failure -l "Refused to proceed without $util_name"
          if $exit_on_q; then exit 1; else return 2; fi

          # Done with exiting
          ;;
    esac

  fi
}