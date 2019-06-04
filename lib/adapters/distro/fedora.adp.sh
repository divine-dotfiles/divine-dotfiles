#!/usr/bin/env bash
#:title:        Divine.dotfiles Fedora adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with Fedora OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Check if dnf is available
if dnf --version &>/dev/null; then

  # Implement printer of package manager’s name
  __print_os_pkgmgr() { printf '%s\n' 'dnf'; }

  # Implement wrapper around package manager
  os_pkgmgr()
  {
    # Perform action depending on first argument
    case "$1" in
      dupdate)  sudo dnf upgrade -yq;;
      dcheck)   shift; sudo dnf list --installed "$@" &>/dev/null;;
      dinstall) shift; sudo dnf install -yq "$@";;
      dremove)  shift; sudo dnf remove -yq "$@";;
      *)        return 1;;
    esac
  }

# Else check if yum is available
elif yum --version &>/dev/null; then

  # Implement printer of package manager’s name
  __print_os_pkgmgr() { printf '%s\n' 'yum'; }

  # Implement wrapper around package manager
  os_pkgmgr()
  {
    # Perform action depending on first argument
    case "$1" in
      dupdate)  sudo yum update -y;;
      dcheck)   shift; sudo yum list installed "$@" &>/dev/null;;
      dinstall) shift; sudo yum install -y "$@";;
      dremove)  shift; sudo yum remove -y "$@";;
      *)        return 1;;
    esac
  }

fi

# Implement overriding mechanism for $D_TARGETS and $D_TARGET_DIR
__override_d_targets_for_distro()
{
  # Check if $D_TARGETS_DEBIAN contains at least one string
  if [ ${#D_TARGETS_DEBIAN[@]} -gt 1 -o -n "$D_TARGETS_DEBIAN" ]; then

    # $D_TARGETS_DEBIAN is set: use it instead
    D_TARGETS=( "${D_TARGETS_DEBIAN[@]}" )
    
  fi

  # Check if $D_TARGET_DIR_FEDORA is not empty
  if [ -n "$D_TARGET_DIR_FEDORA" ]; then

    # $D_TARGET_DIR_FEDORA is set: use it instead
    D_TARGET_DIR=( "${D_TARGET_DIR_FEDORA[@]}" )
    
  fi
}