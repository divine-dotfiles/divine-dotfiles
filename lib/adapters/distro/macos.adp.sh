#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    14
#:revdate:      2019.07.22
#:revremark:    New revisioning system
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with macOS OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Implement helper that offers to install Homebrew, and does it if user agrees
d__offer_to_install_brew()
{
  # Check if Homebrew is already installed
  if HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then
    return 0
  fi

  # Inform user of the tragic circumstances
  dprint_start -l \
    'Failed to detect Homebrew (package manager for macOS, https://brew.sh/)'

  # Prompr user
  if dprompt_key -b --color "$YELLOW" --answer "$D__OPT_ANSWER" \
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
        dprint_failure -l \
          "Failed to record installation of Homebrew to root stash"
      fi

      # Announce success
      dprint_success -l "Successfully installed Homebrew"

      # Return status
      return 0

    else

      # Announce and return failure
      dprint_failure -l "Failed to install Homebrew"
      return 1

    fi

  else

    # Announce refusal to install and return
    dprint_skip -l "Refused to install Homebrew"
    return 1

  fi
}

# Offer to install Homebrew ASAP
d__offer_to_install_brew

# Afterward, check if brew is available
if HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then

  # Implement printer of package manager’s name
  d__print_os_pkgmgr_name() { printf '%s\n' 'brew'; }

  # Implement wrapper around package manager
  d__os_pkgmgr()
  {
    # Perform action depending on first argument
    case "$1" in
      update)  brew update; brew upgrade;;
      check)   shift
                HOMEBREW_NO_AUTO_UPDATE=1 brew list "$1" &>/dev/null;;
      install) shift; brew install "$1";;
      remove)  shift; brew uninstall "$1";;
      *)        return 1;;
    esac
  }

fi

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_distro()
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