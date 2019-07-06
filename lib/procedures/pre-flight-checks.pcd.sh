#!/usr/bin/env bash
#:title:        Divine Bash procedure: offer
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.07.05
#:revremark:    Initial revision
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Offers to install optional system utilities if they are not available and if 
#. at all possible; makes other global checks and preparations, e.g., stash.
#

#>  __run_pre_flight_checks
#
## Driver function
#
## Returns:
#.  0 - Framework is ready to run
#.  1 - (script exit) Otherwise
#
__run_pre_flight_checks()
{
  # Ensure Grail stash is available
  dstash --grail ready || {
    dprint_failure -l \
      'Failed to prepare Divine stashing system in Grail directory at:' \
      -i "$D_DIR_GRAIL"
    exit 1
  }

  # Ensure root stash is available
  dstash --root ready || {
    dprint_failure -l \
      'Failed to prepare Divine stashing system in state directory at:' \
      -i "$D_DIR_STASH"
    exit 1
  }
}

#>  __offer_util UTIL_NAME
#
## Checks whether UTIL_NAME is available on the system and, if not, offers to 
#. install it using system’s package manager, if it itself is available
#
## Returns:
#.  0 - UTIL_NAME is available or successfully installed
#.  1 - UTIL_NAME is not available, or user refused it, or it failed to install
#
__offer_util()
{
  # Extract util name
  local util_name="$1"

  # If command by that name is available on $PATH, return zero immediately
  case $util_name in
    git)  git --version &>/dev/null;;
    tar)  tar --version &>/dev/null;;
    *)    type -P -- "$util_name" &>/dev/null;;
  esac; [ $? -eq 0 ] && return 0

  # Print initial warning
  dprint_debug "Failed to detect $util_name executable"

  # Check if $OS_PKGMGR is detected
  if [ -z ${OS_PKGMGR+isset} ]; then

    # No option to install: report and return
    dprint_debug \
      "Unable to auto-install $util_name (no supported package manager)"
    return 1
  
  else

    # Prompt user for whether to install utility
    if dprompt_key --bare --answer "$D_OPT_ANSWER" \
      --prompt "Install $util_name using $OS_PKGMGR?"
    then

      # Announce installation
      dprint_debug "Installing $util_name"

      # Attempt installation
      if os_pkgmgr dinstall "$util_name"; then

        # Announce success
        dprint_debug "Successfully installed $util_name"

        # Make record of installation
        if dstash -r -s add util_installed "$util_name"
          dprint_debug "Recorded installation to root stash"
        else
          dprint_failure -l \
            "Failed to record installation of $util_name to root stash"
        fi

        # Return status
        return 0

      else

        # Announce and return failure
        dprint_debug "Failed to install $util_name"
        return 1
        
      fi

    else

      # Announce refusal to install and return
      dprint_debug "Proceeding without $util_name"
      return 1

    fi

  fi
}

__run_pre_flight_checks