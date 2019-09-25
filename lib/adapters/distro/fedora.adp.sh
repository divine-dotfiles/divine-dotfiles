#!/usr/bin/env bash
#:title:        Divine.dotfiles Fedora adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    No remark
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support Fedora OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Implement detection mechanism for distro
d__adapter_detect_os_distro()
{
  case $D__OS_FAMILY in
    linux|wsl) grep -Fqi fedora /etc/fedora-release && d__os_distro=fedora;;
    *) return 1;;
  esac
}

# Implement detection mechanism for package manager
d__adapter_detect_os_pkgmgr()
{
  # Check if dnf is available
  if dnf --version &>/dev/null; then

    # Set marker variable
    d__os_pkgmgr='dnf'

    # Implement wrapper function
    d__os_pkgmgr()
    {
      # Perform action depending on first argument
      case "$1" in
        update)
          dprint_sudo 'Working with dnf requires sudo password'
          sudo dnf upgrade -y
          ;;
        check)
          dprint_sudo 'Working with dnf requires sudo password'
          sudo dnf list --installed "$2" &>/dev/null
          ;;
        install)
          dprint_sudo 'Working with dnf requires sudo password'
          sudo dnf install -y "$2"
          ;;
        remove)
          dprint_sudo 'Working with dnf requires sudo password'
          sudo dnf remove -y "$2"
          ;;
        *)  return 1;;
      esac
    }

  elif yum --version &>/dev/null; then

    # Set marker variable
    d__os_pkgmgr='yum'

    # Implement wrapper function
    d__os_pkgmgr()
    {
      # Perform action depending on first argument
      case "$1" in
        update)
          dprint_sudo 'Working with yum requires sudo password'
          sudo yum update -y
          ;;
        check)
          dprint_sudo 'Working with yum requires sudo password'
          sudo yum list installed "$2" &>/dev/null
          ;;
        install)
          dprint_sudo 'Working with yum requires sudo password'
          sudo yum install -y "$2"
          ;;
        remove)
          dprint_sudo 'Working with yum requires sudo password'
          sudo yum remove -y "$2"
          ;;
        *)  return 1;;
      esac
    }

  fi
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__adapter_override_dpl_targets_for_os_distro()
{
  # Check if $D_DPL_TARGET_PATHS_DEBIAN contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_DEBIAN[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_DEBIAN" ]; then

    # $D_DPL_TARGET_PATHS_DEBIAN is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_DEBIAN[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_FEDORA is not empty
  if [ -n "$D_DPL_TARGET_DIR_FEDORA" ]; then

    # $D_DPL_TARGET_DIR_FEDORA is set: use it instead
    D_DPL_TARGET_DIR=( "${D_DPL_TARGET_DIR_FEDORA[@]}" )
    
  fi
}