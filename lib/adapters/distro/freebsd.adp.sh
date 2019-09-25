#!/usr/bin/env bash
#:title:        Divine.dotfiles FreeBSD adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    No remark
#:created_at:   2019.08.08

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support FreeBSD OS distribution
#
## For reference, see lib/templates/adapters/distro.adp.sh
#

# Implement detection mechanism for distro
d__adapter_detect_os_distro()
{
  [[ $D__OSTYPE = freebsd* ]] && d__os_distro=freebsd
}

# Implement detection mechanism for package manager
d__adapter_detect_os_pkgmgr()
{
  # Check if apt-get is available
  if pkg --version &>/dev/null; then

    # Set marker variable
    d__os_pkgmgr='pkg'

    # Implement wrapper function
    d__os_pkgmgr()
    {
      # Perform action depending on first argument
      case "$1" in
        update)
          dprint_sudo 'Working with pkg requires sudo password'
          sudo pkg update
          sudo pkg upgrade -y
          ;;
        check)
          pkg info "$2" &>/dev/null
          ;;
        install)
          dprint_sudo 'Working with pkg requires sudo password'
          sudo pkg install -y "$2"
          ;;
        remove)
          dprint_sudo 'Working with pkg requires sudo password'
          sudo pkg delete -y "$2"
          ;;
        *)  return 1;;
      esac
    }

  fi
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__adapter_override_dpl_targets_for_os_distro()
{
  # Check if $D_DPL_TARGET_PATHS_FREEBSD contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_FREEBSD[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_FREEBSD" ]; then

    # $D_DPL_TARGET_PATHS_FREEBSD is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_FREEBSD[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_FREEBSD is not empty
  if [ -n "$D_DPL_TARGET_DIR_FREEBSD" ]; then

    # $D_DPL_TARGET_DIR_FREEBSD is set: use it instead
    D_DPL_TARGET_DIR=( "${D_DPL_TARGET_DIR_FREEBSD[@]}" )
    
  fi
}