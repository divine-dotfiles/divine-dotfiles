#!/usr/bin/env bash
#:title:        Divine Bash procedure: detect-os
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.03.15

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Search for <<CONTRIBUTE HERE>> to find the portion of the code that is 
#. intended for extension, to support additional OS distributions.
#

# Marker and dependencies
readonly D__PCD_DETECT_OS=loaded
d__load procedure prep-sys
d__load util workflow
d__load util stash
d__load procedure prep-stash

#>  d__pcd_detect_os
#
## This script provides into the global scope three read-only variables:
#.  $D__OS_FAMILY   - (read-only) Broad description of the current OS type.
#.  $D__OS_DISTRO   - (read-only) Best guess on the name of the current OS 
#.                    distribution, without version.
#.  $D__OS_PKGMGR   - (read-only) Name of the package management utility 
#.                    available on the current system.
#
## The OS family ($D__OS_FAMILY) must be recognized in order for the framework 
#. to work, the two other variables may be left empty at the price of not 
#. supporting package processing.
#
## Provides into the global scope these functions:
#.  d__os_pkgmgr  - A thin wrapper around system's package manager. Accepts the 
#.                  following commands as first argument: 'update', 'has', 
#.                  'check', 'install', and 'remove'. The second argument is 
#.                  the name of a package. Avoids prompting for user input 
#.                  (except for the sudo password). Returns whatever the 
#.                  package manager returns, or 2 when the package manager is 
#.                  not supported.
#
d__pcd_detect_os()
{
  d__context -n -- notch
  d__context -- push 'Detecting current operating system environment'
  d__detect_os_family; d__detect_os_distro_and_pkgmgr
  d__context -- lop
}

#>  d__detect_os_family
#
## Detects the OS family and stores it in a read-only global variable
#
## Provides into the global scope:
#.  $D__OS_FAMILY   - (read-only) Broad description of the current OS type:
#.                      * 'macos'
#.                      * 'linux'
#.                      * 'wsl' (Windows Subsystem for Linux)
#.                      * 'bsd'
#.                      * 'solaris'
#.                      * 'cygwin'
#.                      * 'msys'
#.  $D__OSTYPE      - Either the content of the $OSTYPE variable (modern OS's), 
#.                    or the printed value of the 'uname -s' command.
#
## Returns:
#.  0 - Success.
#.  1 - (script exit) Failed to re-assign a global variable.
#.  1 - (script exit) Failed to reliably recognize the OS family.
#
d__detect_os_family()
{
  # Switch context; init storage variable
  d__context -- push 'Detecting OS family'; local d__os_family

  # Either use $OSTYPE (modern OS's), or fall back to 'uname -s'
  if [ -n "$OSTYPE" ]; then readonly D__OSTYPE="$OSTYPE"
  else readonly D__OSTYPE="$( uname -s 2>/dev/null )"; fi

  $D__DISABLE_CASE_SENSITIVITY

  ## The block of code below, until the next comment, populates the local 
  #. variable d__os_family with the one-word handle for the current OS family. 
  #
  case $D__OSTYPE in
    darwin*)  d__os_family=macos;;
    linux*)   if grep -Fqi -e microsoft -e wsl /proc/version 2>/dev/null
              then d__os_family=wsl; else d__os_family=linux; fi;;
    freebsd*) d__os_family=bsd;;
    openbsd*) d__os_family=bsd;;
    netbsd*)  d__os_family=bsd;;
    sunos*)   d__os_family=solaris;;
    cygwin*)  d__os_family=cygwin;;
    msys*)    d__os_family=msys;;
    mingw*)   d__os_family=msys;;
    *)        d__os_family=;;
  esac

  $D__RESTORE_CASE_SENSITIVITY
  
  # Inspect detected OS family
  if [ -z "$d__os_family" ]; then
    d__fail -t 'Critical failure' -- 'Unable to detect the OS family'
    exit 1
  else readonly D__OS_FAMILY="$d__os_family"; fi

  # Finish up
  d__context -qqvt 'Detected OS family' -- pop "'$BOLD$D__OS_FAMILY$NORMAL'"
  return 0
}

#>  d__detect_os_distro_and_pkgmgr
#
## Detects current OS distribution, as well as system's package manager; stores 
#. this info in read-only global variables
#
## Requires:
#.  $D__OSTYPE
#.  $D__OS_FAMILY
#
## Provides into the global scope:
#.  $D__OS_DISTRO   - (read-only) Best guess on the name of the current OS 
#.                    distribution, without version, e.g.:
#.                      * 'macos'
#.                      * 'ubuntu'
#.                      * 'debian'
#.                      * 'fedora'
#.                      * 'freebsd'
#.                      * unset     - Not recognized
#.  $D__OS_PKGMGR   - (read-only) Widely recognized name of package management 
#.                    utility available on the current system, e.g.:
#.                      * 'brew'    - macOS
#.                      * 'apt-get' - Debian, Ubuntu
#.                      * 'dnf'     - Fedora
#.                      * 'yum'     - older Fedora
#.                      * unset     - Not recognized
#.  d__os_pkgmgr  - A thin wrapper around system's package manager. Accepts the 
#.                  following commands as first argument: 'update', 'has', 
#.                  'check', 'install', and 'remove'. The second argument is 
#.                  the name of a package. Avoids prompting for user input 
#.                  (except for the sudo password). Returns whatever the 
#.                  package manager returns, or 2 when the package manager is 
#.                  not supported.
#
## Returns:
#.  0 - Success.
#.  1 - (script exit) Failed to re-assign a global variable.
#.  1 - Failed to reliably recognize the OS distribution or package manager.
#
d__detect_os_distro_and_pkgmgr()
{
  # Switch context; init storage variable
  d__context -- push 'Detecting OS distribution'; local d__os_distro
  
  $D__DISABLE_CASE_SENSITIVITY

  ## The block of code below, until the next comment, must populate the local 
  #. variable d__os_distro with the one-word handle for the current OS distro. 
  #. This handle is then used to locate and source the OS distro adapter at 
  #. lib/adapters/<OS_DISTRO>.adp.sh.
  #
  ## If extending the framework with support for additional OS distros, one 
  #. should both modify the code block below and create the corresponding 
  #. adapter.
  #
  ## For reference on adapters see lib/templates/adapters/distro.adp.sh.
  #

  # <<CONTRIBUTE HERE>>
  case $D__OS_FAMILY in
    macos)  d__os_distro=macos;;
    bsd)    case $D__OSTYPE in
              freebsd*) d__os_distro=freebsd;;
            esac;;
    linux|wsl)
      if grep -Fqi ubuntu /etc/os-release; then d__os_distro=ubuntu
      elif grep -Fqi debian <( lsb_release -a 2>/dev/null ) /etc/os-release
      then d__os_distro=debian
      elif grep -Fqi fedora /etc/fedora-release; then d__os_distro=fedora
      fi;;
    *)  d__os_distro=;;
  esac
  # <<END OF CONTRIBUTION BLOCK>>

  $D__RESTORE_CASE_SENSITIVITY

  # Inspect detected OS distro
  if [ -z "$d__os_distro" ]; then
    d__notify -l!t 'Unsuported OS' -- \
      'Unable to detect a supported OS distribution' \
      -n- 'System package processing will be unavailable'
    readonly D__OS_DISTRO= D__OS_PKGMGR=; d__context -- pop; return 1
  else readonly D__OS_DISTRO="$d__os_distro"; fi

  # Load adapter file
  d__load adapter $D__OS_DISTRO

  # Switch context
  d__context -qqvt 'Detected OS distribution' -- pop \
    "'$BOLD$D__OS_DISTRO$NORMAL'"
  d__context -- push 'Detecting OS package manager'

  # Run detector of package manager
  d__detect_os_pkgmgr

  # Inspect detected OS package manager
  if [ -z "$d__os_pkgmgr" ]; then
    d__notify -l!t 'Unsuported package manager' -- \
      'Unable to detect a supported OS package manager' \
      -n- 'System package processing will be unavailable'
    readonly D__OS_PKGMGR=; d__context -- pop; return 1
  else readonly D__OS_PKGMGR="$d__os_pkgmgr"; fi

  d__context -qqvt 'Detected OS package manager' -- pop \
    "'$BOLD$D__OS_PKGMGR$NORMAL'"
  return 0
}

d__pcd_detect_os