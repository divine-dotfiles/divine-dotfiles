#!/usr/bin/env bash
#:title:        Divine.dotfiles Ubuntu adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.27
#:revremark:    Add 'has' command to d__os_pkgmgr wrapper
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support Ubuntu OS distribution
#
## For reference, see lib/templates/adapters/distro.add.sh
#

# Marker and dependencies
readonly D__ADD_UBUNTU=loaded
d__load procedure prep-sys
d__load util workflow

# Implement detection mechanism for package manager
d__detect_os_pkgmgr()
{
  # Check if apt-get is available
  apt-get --version &>/dev/null || return 1

  # Set marker variable
  d__os_pkgmgr='apt-get'

  # Implement wrapper function
  d__os_pkgmgr()
  {
    case "$1" in
      update)   d__require_sudo apt-get; sudo apt-get update -y; sudo apt-get upgrade -y;;
      has)      apt-cache show "$2" &>/dev/null;;
      check)    grep -qFx 'install ok installed' <( dpkg-query -W -f='${Status}\n' "$2" 2>/dev/null );;
      install)  d__require_sudo apt-get; sudo apt-get install -y "$2";;
      remove)   d__require_sudo apt-get; sudo apt-get remove -y "$2";;
      *)        return 1;;
    esac
  }
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_distro()
{
  if [ ${#D_DPL_TARGET_PATHS_UBUNTU[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS_UBUNTU" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_UBUNTU[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_UBUNTU" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_UBUNTU"; fi
}