#!/usr/bin/env bash
#:title:        Divine Bash utils: dcheck
#:kind:         func(script,interactive)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.14
#:revremark:    Initial revision
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Set of similar functions. Each checks if a certain crucial utility is 
#. available in current OS, or interactively offers to install it if possible.
#

#>  densure UTIL_NAME
#
## Checks whether UTIL_NAME is available and, if not, offers to install it 
#. using system’s package manager, if it is available
#
## Returns:
#.  0 - UTIL_NAME is available or successfully installed
#.  1 - UTIL_NAME is not available or failed to install
#
densure()
{
  # Extract util name
  local util_name="$1"

  # If command by that name is available, return zero immediately
  command -v "$util_name" &>/dev/null && return 0

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
    if dprompt_key --answer "$D_BLANKET_ANSWER" \
      "Package manager $OS_PKGMGR is available" \
      --prompt "Install $util_name using $OS_PKGMGR?"
    then

      # Announce installation
      dprint_debug "Installing $util_name"

      # Attempt installation
      os_pkgmgr dinstall "$util_name"

      # Check status code of installation
      if [ $? -eq 0 ]; then
        dprint_debug "Successfully installed $util_name"
        return 0
      else
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