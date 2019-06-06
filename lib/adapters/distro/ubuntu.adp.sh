#!/usr/bin/env bash
#:title:        Divine.dotfiles Ubuntu adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with Ubuntu OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Check if apt-get is available
if apt-get --version &>/dev/null; then

  # Implement printer of package manager’s name
  __print_os_pkgmgr() { printf '%s\n' 'apt-get'; }

  # Implement wrapper around package manager
  os_pkgmgr()
  {
    # Perform action depending on first argument
    case "$1" in
      dupdate)  sudo apt-get update -yq; sudo apt-get upgrade -yq;;
      dcheck)   shift; dpkg-query -l "$@" &>/dev/null;;
      dinstall) shift; sudo apt-get install -yq "$@";;
      dremove)  shift; sudo apt-get remove -yq "$@";;
      *)        return 1;;
    esac
  }

fi

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
__override_d_targets_for_distro()
{
  # Check if $D_DPL_TARGET_PATHS_UBUNTU contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_UBUNTU[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_UBUNTU" ]; then

    # $D_DPL_TARGET_PATHS_UBUNTU is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_UBUNTU[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_UBUNTU is not empty
  if [ -n "$D_DPL_TARGET_DIR_UBUNTU" ]; then

    # $D_DPL_TARGET_DIR_UBUNTU is set: use it instead
    D_DPL_TARGET_DIR=( "${D_DPL_TARGET_DIR_UBUNTU[@]}" )
    
  fi
}