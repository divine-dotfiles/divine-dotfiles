#!/usr/bin/env bash
#:title:        Divine.dotfiles FreeBSD adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.08.08

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support FreeBSD OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Implement detection mechanism for package manager
d__detect_os_pkgmgr()
{
  # Check if apt-get is available
  pkg --version &>/dev/null || return 1

  # Set marker variable
  d__os_pkgmgr='pkg'

  # Implement wrapper function
  d__os_pkgmgr()
  {
    case "$1" in
      update)   d__require_sudo pkg; sudo pkg update; sudo pkg upgrade -y;;
      check)    pkg info "$2" &>/dev/null;;
      install)  d__require_sudo pkg; sudo pkg install -y "$2";;
      remove)   d__require_sudo pkg; sudo pkg delete -y "$2" ;;
      *)        return 1;;
    esac
  }
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_distro()
{
  if [ ${#D_DPL_TARGET_PATHS_FREEBSD[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS_FREEBSD" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_FREEBSD[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_FREEBSD" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_FREEBSD"; fi
}