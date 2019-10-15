#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support macOS OS distribution
#
## For reference, see lib/templates/adapters/distro.add.sh
#

# Marker and dependencies
readonly D__ADD_MACOS=loaded
d__load util workflow
d__load util stash
d__load procedure prep-stash

# Implement detection mechanism for package manager
d__detect_os_pkgmgr()
{
  # Offer to install Homebrew ASAP; then check if it is available
  d__adapter_offer_to_install_brew
  if ! type -P brew &>/dev/null; then return 1; else
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then
      d__notify -lx -- 'Homebrew appears to be in an error state' \
        "Please, see the output of 'brew --version'"
      return 1
    fi
  fi

  # Set marker variable
  d__os_pkgmgr='brew'

  # Implement wrapper around package manager
  d__os_pkgmgr()
  {
    case "$1" in
      update)   brew update; brew upgrade;;
      check)    HOMEBREW_NO_AUTO_UPDATE=1 brew list "$2" &>/dev/null;;
      install)  brew install "$2";;
      remove)   brew uninstall "$2";;
      *)        return 1;;
    esac
  }
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_distro()
{
  if [ ${#D_DPL_TARGET_PATHS_MACOS[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS_MACOS" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_MACOS[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_MACOS" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_MACOS"; fi
}

# Implement helper that offers to install Homebrew, and does it if user agrees
d__adapter_offer_to_install_brew()
{
  type -P brew &>/dev/null && return 0

  # Prompt user
  if ! d__prompt -!aph "$D__OPT_ANSWER" 'Install Homebrew?' -- \
    'Failed to detect Homebrew (package manager for macOS, https://brew.sh/)'
  then d__notify -ls -- 'Refused to install Homebrew'; return 0; fi

  # Switch context
  d__context -- notch
  d__context -l! -- push 'Installing Homebrew'

  # Launch installation with verbosity in mind
  local d__url='https://raw.githubusercontent.com/Homebrew/install/master/install'
  if (($D__OPT_VERBOSITY)); then local d__ol
    /usr/bin/ruby -e "$( curl -fsSL $d__url )" </dev/null 2>&1 \
      | while IFS= read -r d__ol || [ -n "$d__ol" ]
        do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
  else /usr/bin/ruby -e "$( curl -fsSL $d__url )" </dev/null &>/dev/null; fi

  # Check return code
  if ((${PIPESTATUS[0]})); then
    d__fail -- 'Homebrew installation returned an error code'; return 1
  else
    d__notify -lv -- 'Successfully installed Homebrew'
    if d__stash -rs -- set installed_homebrew; then
      d__notify -- 'Recorded installation of Homebrew to root stash'
    else
      d__fail -- 'Failed to record installation of Homebrew to root stash'
      return 0
    fi
  fi

  # Finish up
  d__context -lvt 'Done' -- pop; d__context -- lop; return 0
}