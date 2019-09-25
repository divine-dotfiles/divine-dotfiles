#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Remove revision numbers from all src files
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support macOS OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Implement detection mechanism for distro
d__adapter_detect_os_distro()
{
  case $D__OS_FAMILY in macos) d__os_distro=macos;; *) return 1;; esac
}

# Implement detection mechanism for package manager
d__adapter_detect_os_pkgmgr()
{
  # Offer to install Homebrew ASAP
  d__adapter_offer_to_install_brew

  # Afterward, check if brew is available
  if type -P brew &>/dev/null; then

    # Check if brew is in error state
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then
      d__notify -lx -- 'Homebrew appears to be in an error state' \
        "Please, see the output of 'brew --version'"
      return 1
    fi

    # Set marker variable
    d__os_pkgmgr='brew'

    # Implement wrapper around package manager
    d__os_pkgmgr()
    {
      # Perform action depending on first argument
      case "$1" in
        update)  brew update; brew upgrade;;
        check)   HOMEBREW_NO_AUTO_UPDATE=1 brew list "$2" &>/dev/null;;
        install) brew install "$2";;
        remove)  brew uninstall "$2";;
        *)  return 1;;
      esac
    }

  fi
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__adapter_override_dpl_targets_for_os_distro()
{
  # Check if $D_DPL_TARGET_PATHS_MACOS contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_MACOS[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_MACOS" ]; then

    # $D_DPL_TARGET_PATHS_MACOS is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_MACOS[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_MACOS is not empty
  if [ -n "$D_DPL_TARGET_DIR_MACOS" ]; then

    # $D_DPL_TARGET_DIR_MACOS is set: use it instead
    D_DPL_TARGET_DIR=( "${D_DPL_TARGET_DIR_MACOS[@]}" )
    
  fi
}

# Implement helper that offers to install Homebrew, and does it if user agrees
d__adapter_offer_to_install_brew()
{
  # Check if Homebrew is already installed
  if type -P brew &>/dev/null; then
    return 0
  fi

  # Inform user of the tragic circumstances
  dprint_alert \
    'Failed to detect Homebrew (package manager for macOS, https://brew.sh/)'

  # Prompr user
  if dprompt -b --color "$YELLOW" --answer "$D__OPT_ANSWER" \
    --prompt "Install Homebrew?"
  then

    # Announce installation
    dprint_debug 'Installing Homebrew'

    # Launch installation with verbosity in mind
    if $D__OPT_QUIET; then

      # Launch quietly
      /usr/bin/ruby -e \
        "$( curl -fsSL \
        https://raw.githubusercontent.com/Homebrew/install/master/install \
        )" </dev/null &>/dev/null

    else

      # Launch normally, but re-paint output
      local line
      /usr/bin/ruby -e \
        "$( curl -fsSL \
        https://raw.githubusercontent.com/Homebrew/install/master/install \
        )" </dev/null 2>&1 \
        | while IFS= read -r line || [ -n "$line" ]; do
          printf "${CYAN}==> %s${NORMAL}\n" "$line"
        done

    fi

    # Check exit code and print status message
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then

      # Make record of installation
      if d__stash -r -s add installed_homebrew; then
        dprint_debug "Recorded installation of Homebrew to root stash"
      else
        dprint_failure \
          "Failed to record installation of Homebrew to root stash"
      fi

      # Announce success
      dprint_success "Successfully installed Homebrew"

      # Return status
      return 0

    else

      # Announce and return failure
      dprint_failure "Failed to install Homebrew"
      return 1

    fi

  else

    # Announce refusal to install and return
    dprint_skip "Refused to install Homebrew"
    return 1

  fi
}