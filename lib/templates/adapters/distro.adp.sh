#!/usr/bin/env bash
#:title:        Divine.dotfiles template OS distro adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    14
#:revdate:      2019.08.07
#:revremark:    Grand removal of non-ASCII chars
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support a particular OS distribution
#
## For adapter file to be sourced and used, it must be named 'DISTRO.adp.sh' 
#. and placed in lib/adapters/distro directory, where 'DISTRO' must be 
#. descriptive of OS distribution being adapted to.
#

#>  d__adapter_detect_os_distro
#
## This function will be called with $D__OS_FAMILY already populated, and must 
#. use said variable and other means to judge whether current OS is the OS 
#. distribution being adapted to. Guidelines below must be followed.
#
## Expect 'nocasematch' Bash option to be enabled by caller of this function
#
## Global variables made available to this function (all read-only):
#.  $D__OS_FAMILY - One-word description of current OS family
#
## Local variables that must be set in case of successful match (no need to 
#. declare these as local, they will be declared as such by parent scope):
#.  $d__os_distro - One-word description of current OS distro. This word will 
#.                  be assigned to read-only global variable $D__OS_DISTRO, 
#.                  which in turn is then used throughout this framework and 
#.                  its deployments.
#.                  For clarity, this one word must match the name of adapter 
#.                  file, sans suffix
#.                  If this variable is set to a non-empty value, it is taken 
#.                  as indication of positive OS distro match
#
## Returns:
#.  Return code is ignored
#
d__adapter_detect_os_distro()
{
  # Below is example implementation for Debian distribution

  case $D__OS_FAMILY in
    linux|wsl)
      grep -Fqi debian <( lsb_release -a 2>/dev/null ) /etc/os-release \
        && d__os_distro=debian
      ;;
    *) return 1;;
  esac
}

#>  d__adapter_detect_os_pkgmgr
#
## This function will be called if and only if current distribution matched. 
#. This function must detect, whether a supported package manager is available 
#. on this system and, if so, implement a wrapper around it. Guidelines below 
#. must be followed.
#
## Expect 'nocasematch' Bash option to be enabled by caller of this function
#
## Global variables made available to this function (all read-only):
#.  $D__OS_FAMILY - One-word description of current OS family
#.  $D__OS_DISTRO - One-word description of current OS distribution
#
## Local variables that must be set in case of successful match (no need to 
#. declare these as local, they will be declared as such by parent scope):
#.  $d__os_pkgmgr - One-word description of current system's package manager. 
#.                  This word will be assigned to read-only global variable 
#.                  $D__OS_PKGMGR, which in turn is then used throughout this 
#.                  framework and its deployments.
#.                  For clarity, this one word must match the widely recognized 
#.                  name of the package manager's executable command
#.                  If this variable is set to a non-empty value, it is taken 
#.                  as indication of positive OS distro match
#
## Returns:
#.  Return code is ignored
#
d__adapter_detect_os_pkgmgr()
{
  # Below is example implementation for apt-get distribution

  # Check if apt-get is available
  if apt-get --version &>/dev/null; then

    # Set the expected variable
    d__os_pkgmgr='apt-get'

    # Implement the wrapper function

    #>  d__os_pkgmgr update|check|install|remove [ARG]...
    #
    ## Thin wrapper around system's package manager. Launches one of the four 
    #. routines, which are expected of any package manager out there.
    #
    ## Second argument must be relayed to package manager verbatim. User 
    #. prompts (except sudo password) should be avoided. For sudo, a call to 
    #. dprint_sudo should be included before relaying the command.
    #
    ## Arguments:
    #.  $1  - One of four routines to launch:
    #.          * 'update'   - update installed packages (other args ignored)
    #.          * 'check'    - check whether listed packages are installed
    #.          * 'install'  - install listed packages
    #.          * 'remove'   - uninstall listed packages
    #.  $2  - Package to work on
    #
    ## Returns:
    #.  Whatever underlying package manager returns
    #.  1 - Unrecognized routine
    #.  2 - Wrapper is not implemented at all
    #
    ## Prints:
    #.  Whatever underlying package manager prints
    #
    d__os_pkgmgr()
    {
      # Below is example implementation for apt-get

      # Perform action depending on first argument
      case "$1" in
        update)
          dprint_sudo 'Working with apt-get requires sudo password'
          sudo apt-get update -yq
          sudo apt-get upgrade -yq
          ;;
        check)
          grep -qFx 'install ok installed' \
            <( dpkg-query -W -f='${Status}\n' "$2" 2>/dev/null )
          ;;
        install)
          dprint_sudo 'Working with apt-get requires sudo password'
          sudo apt-get install -yq "$2"
          ;;
        remove)
          dprint_sudo 'Working with apt-get requires sudo password'
          sudo apt-get remove -yq "$2"
          ;;
        *)  return 1;;
      esac
    }

  # Done with definitions for apt-get
  fi
}

#>  d__adapter_override_dpl_targets_for_os_distro
#
## Provides a way for deployments to override $D_DPL_TARGET_PATHS global 
#. variable, which is used by helper functions in dln.hlp.sh and cp.hlp.sh. 
#. This function is called before contents of $D_DPL_TARGET_PATHS is settled 
#. upon.
#
d__adapter_override_dpl_targets_for_os_distro()
{
  # Below is example implementation for Ubuntu distribution

  # Check if $D_DPL_TARGET_PATHS_UBUNTU contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_UBUNTU[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_UBUNTU" ]; then

    # $D_DPL_TARGET_PATHS_UBUNTU is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_UBUNTU[@]}" )
    
  fi
}