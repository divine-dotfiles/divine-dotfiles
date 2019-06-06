#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with macOS OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Check if brew is available
if HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then

  # Implement printer of package manager’s name
  __print_os_pkgmgr() { printf '%s\n' 'brew'; }

  # Implement wrapper around package manager
  os_pkgmgr()
  {
    # Perform action depending on first argument
    case "$1" in
      dupdate)  brew update; brew upgrade;;
      dcheck)   shift
                HOMEBREW_NO_AUTO_UPDATE=1 brew list "$@" &>/dev/null;;
      dinstall) shift; brew install "$@";;
      dremove)  shift; brew uninstall "$@";;
      *)        return 1;;
    esac
  }

fi

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
__override_d_targets_for_distro()
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
__offer_to_install_brew()
{
  # Check if Homebrew is already installed
  if HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then
    return 0
  fi

  # Only proceed if root stash is available
  dstash --root ready &>/dev/null || return 1

  # Inform user of the tragic circumstances
  printf >&2 '%s\n' \
    'Failed to detect Homebrew (package manager for macOS, https://brew.sh/)'

  # Prompt user
  local yes=false
  if [ "$D_OPT_ANSWER" = true ]; then yes=true
  elif [ "$D_OPT_ANSWER" = false ]; then yes=false
  else

    # Print question
    printf >&2 '%s' 'Would you like to install it? [y/n] '

    # Await answer
    while true; do
      read -rsn1 input
      [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
      [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
    done
    printf '\n'

  fi

  # Check if user accepted
  if $yes; then

    # Announce installation
    printf >&2 '%s\n' 'Installing Homebrew'

    # Proceed with automated installation
    /usr/bin/ruby -e \
      "$( curl -fsSL \
      https://raw.githubusercontent.com/Homebrew/install/master/install \
      )" </dev/null

    # Check exit code and print status message
    if [ $? -eq 0 ]; then
      printf >&2 '%s\n' 'Successfully installed Homebrew'
      dstash -r -s set installed_homebrew
    else
      printf >&2 '%s\n' 'Failed to install Homebrew'
    fi

  else

    # Proceeding without Homebrew
    printf >&2 '%s\n' 'Proceeding without Homebrew'

  fi
}

# Run helper as soon as file is sourced
__offer_to_install_brew