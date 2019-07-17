#!/usr/bin/env bash
#:title:        Divine.dotfiles template OS distro adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with particular OS distribution
#
## For adapter file to be sourced and used, it must be named ‘DISTRO.adp.sh’ 
#. and placed in lib/adapters/distro directory. ‘DISTRO’ must match $D__OS_DISTRO 
#. variable’s value for distro being adapted for. (See lib/dos.utl.sh for 
#. reference on $D__OS_DISTRO).
#

# Conditionally implement next two functions (if package manager is available)
if apt-get --version &>/dev/null; then

#>  d__print_os_pkgmgr_name
#
## Prints widely recognized name of package manager (e.g., ‘brew’ or ‘yum’) to 
#. stdout. Printed string will be put into readonly global $D__OS_PKGMGR.
#
d__print_os_pkgmgr_name() {
  # Below is example implementation for Debian

  # Print name and return
  printf '%s\n' 'apt-get'
}

#>  d__os_pkgmgr update|check|install|remove [ARG]…
#
## Thin wrapper around system’s package manager. Launches one of the four 
#. routines, which are supported by virtually any package manager out there.
#
## All arguments except first must be relayed to package manager verbatim. Must 
#. avoid prompting for user input (except sudo password).
#
## Arguments:
#.  $1  - One of four routines to launch:
#.          * ‘dupdate’   - update installed packages (other args ignored)
#.          * ‘dcheck’    - check whether listed packages are installed
#.          * ‘dinstall’  - install listed packages
#.          * ‘dremove’   - uninstall listed packages
#.  $@  - Packages to work on
#
## Returns:
#.  Whatever underlying package manager returns, or 1 for unrecognized routine
#
## Prints:
#.  Whatever underlying package manager prints
#
d__os_pkgmgr()
{
  # Below is example implementation for apt-get

  # Perform action depending on first argument
  if ! sudo -n true 2>/dev/null; then
    dprint_start -l "Working with apt-get requires sudo password"
  fi
  case "$1" in
    update)  sudo apt-get update -yq; sudo apt-get upgrade -yq;;
    check)   shift; $( dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -qFx 'install ok installed' );;
    install) shift; sudo apt-get install -yq "$1";;
    remove)  shift; sudo apt-get remove -yq "$1";;
    *)        return 1;;
  esac
}

# Done with conditional implementations
fi

#>  __override_d_targets_for_distro
#
## Provides a way for deployments to override $D__DPL_TARGET_PATHS global 
#. variable, which is used by helper functions in dln.hlp.sh and cp.hlp.sh. 
#. This function is called before contents of $D__DPL_TARGET_PATHS is settled 
#. upon.
#
__override_d_targets_for_distro()
{
  # Below is example implementation for Ubuntu distribution

  # Check if $D__DPL_TARGET_PATHS_UBUNTU contains at least one string
  if [ ${#D__DPL_TARGET_PATHS_UBUNTU[@]} -gt 1 \
    -o -n "$D__DPL_TARGET_PATHS_UBUNTU" ]; then

    # $D__DPL_TARGET_PATHS_UBUNTU is set: use it instead
    D__DPL_TARGET_PATHS=( "${D__DPL_TARGET_PATHS_UBUNTU[@]}" )
    
  fi
}