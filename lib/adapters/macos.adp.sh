#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    Implement d flag for pkgs to remove with deps
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support macOS OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
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
      has)      HOMEBREW_NO_AUTO_UPDATE=1 brew info "$2" &>/dev/null;;
      check)    HOMEBREW_NO_AUTO_UPDATE=1 brew list "$2" &>/dev/null;;
      install)  brew install "$2";;
      remove)   brew uninstall "$2";;
      *)        return 1;;
    esac
  }

  # Implement optional d__os_pkgmgr_remove_with_deps wrapper
  d__os_pkgmgr_remove_with_deps()
  {
    HOMEBREW_NO_AUTO_UPDATE=1 brew list "$1" &>/dev/null && return 0
    local orig_leaves=()  # array of brew leaves before uninstalling
    local new_leaves  # array of new brew leaves after uninstalling
    local ii jj  # temp containers
    while read -r ii; do orig_leaves+=("$ii"); done < <( brew leaves )
    brew uninstall "$1" || return 1
    while true; do
      new_leaves=()
      while read -r ii; do
        for jj in "${orig_leaves[@]}"; do [ "$ii" = "$jj" ] && continue 2; done
        new_leaves+=("$ii")
      done < <( brew leaves )
      [ ${#new_leaves[@]} -eq 0 ] && break
      for ii in "${new_leaves[@]}"; do
        if ! brew uninstall "$ii"; then
          local err_msg=("Failed to uninstall dependency '$ii'")
          err_msg+=('while uninstalling these:')
          for jj in "${new_leaves[@]}"; do err_msg+=( -i- "- '$jj'" ); done
          d__notify -lx -- "${err_msg[@]}"
          return 1
        fi
      done
    done
    return 0
  }
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

  # Launch installation
  local d__url='https://raw.githubusercontent.com/Homebrew/install/master/install'
  /usr/bin/ruby -e "$( curl -fsSL $d__url )" </dev/null

  # Check return code
  if (($?)); then
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