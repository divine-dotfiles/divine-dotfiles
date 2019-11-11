#!/usr/bin/env bash
#:title:        Divine.dotfiles Fedora adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.11
#:revremark:    Rename queue arrays
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support Fedora OS distribution
#
## For reference, see lib/templates/adapters/distro.add.sh
#

# Marker and dependencies
readonly D__ADD_FEDORA=loaded
d__load util workflow

# Implement detection mechanism for package manager
d__detect_os_pkgmgr()
{
  # Check if dnf is available
  if dnf --version &>/dev/null; then

    # Set marker variable
    d__os_pkgmgr='dnf'

    # Implement wrapper function
    d__os_pkgmgr()
    {
      case "$1" in
        update)   d__require_sudo dnf; sudo dnf upgrade -y;;
        has)      dnf info "$2" &>/dev/null;;
        check)    d__require_sudo dnf; sudo dnf list --installed "$2" &>/dev/null;;
        install)  d__require_sudo dnf; sudo dnf install -y "$2";;
        remove)   d__require_sudo dnf; sudo dnf remove -y "$2";;
        *)        return 1;;
      esac
    }

  elif yum --version &>/dev/null; then

    # Set marker variable
    d__os_pkgmgr='yum'

    # Implement wrapper function
    d__os_pkgmgr()
    {
      case "$1" in
        update)   d__require_sudo yum; sudo yum update -y;;
        has)      yum info "$2" &>/dev/null;;
        check)    d__require_sudo yum; sudo yum list installed "$2" &>/dev/null;;
        install)  d__require_sudo yum; sudo yum install -y "$2";;
        remove)   d__require_sudo yum; sudo yum remove -y "$2";;
        *)        return 1;;
      esac
    }

  fi
}

# Implement overriding mechanism for $D_QUEUE_TARGETS and $D_QUEUE_TARGET_DIR
d__override_dpl_targets_for_os_distro()
{
  if [ ${#D_QUEUE_TARGETS_DEBIAN[@]} -gt 1 -o -n "$D_QUEUE_TARGETS_DEBIAN" ]
  then D_QUEUE_TARGETS=( "${D_QUEUE_TARGETS_DEBIAN[@]}" ); fi
  if [ -n "$D_QUEUE_TARGET_DIR_FEDORA" ]
  then D_QUEUE_TARGET_DIR="$D_QUEUE_TARGET_DIR_FEDORA"; fi
}