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
    if ! sudo -n true 2>/dev/null; then
      dprint_start -l "Working with dnf requires sudo password"
    fi
    case "$1" in
      dupdate)  sudo dnf upgrade -yq;;
      dcheck)   shift; sudo dnf list --installed "$1" &>/dev/null;;
      dinstall) shift; sudo dnf install -yq "$1";;
      dremove)  shift; sudo dnf remove -yq "$1";;
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
    if ! sudo -n true 2>/dev/null; then
      dprint_start -l "Working with yum requires sudo password"
    fi
    case "$1" in
      dupdate)  sudo yum update -y;;
      dcheck)   shift; sudo yum list installed "$1" &>/dev/null;;
      dinstall) shift; sudo yum install -y "$1";;
      dremove)  shift; sudo yum remove -y "$1";;
      *)        return 1;;
    esac
  }

fi

# Implement overriding mechanism for $D__DPL_TARGET_PATHS and $D__DPL_TARGET_DIR
__override_d_targets_for_distro()
{
  # Check if $D__DPL_TARGET_PATHS_DEBIAN contains at least one string
  if [ ${#D__DPL_TARGET_PATHS_DEBIAN[@]} -gt 1 \
    -o -n "$D__DPL_TARGET_PATHS_DEBIAN" ]; then

    # $D__DPL_TARGET_PATHS_DEBIAN is set: use it instead
    D__DPL_TARGET_PATHS=( "${D__DPL_TARGET_PATHS_DEBIAN[@]}" )
    
  fi

  # Check if $D__DPL_TARGET_DIR_FEDORA is not empty
  if [ -n "$D__DPL_TARGET_DIR_FEDORA" ]; then

    # $D__DPL_TARGET_DIR_FEDORA is set: use it instead
    D__DPL_TARGET_DIR=( "${D__DPL_TARGET_DIR_FEDORA[@]}" )
    
  fi
}