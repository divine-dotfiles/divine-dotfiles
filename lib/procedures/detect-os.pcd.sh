#!/usr/bin/env bash
#:title:        Divine Bash procedure: detect-os
#:kind:         global_var,func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    3
#:revdate:      2019.07.25
#:revremark:    Rewrite OS detection and adapters
#:created_at:   2019.03.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Provides into the global scope three read-only variables:
#.  $D__OS_FAMILY  - (read-only) Broad description of the current OS type.
#.  $D__OS_DISTRO  - (read-only) Best guess on the name of the current OS 
#.                distribution, without version.
#.  $D__OS_PKGMGR  - (read-only) Name of the package management utility available 
#.                on the current system.
#
## Provides into the global scope these functions:
#.  d__os_pkgmgr - Thin wrapper around system’s package manager. Accepts the 
#.              following commands as first argument: ‘update’, ‘check’, 
#.              ‘install’, and ‘remove’. Remaining arguments are relayed to 
#.              package manager verbatim. Avoids prompting for user input 
#.              (except sudo password). Returns whatever the package manager 
#.              returns, or -1 for unrecognized package manager.
#
## List of supported distros ($D__OS_DISTRO) and utilities ($D__OS_PKGMGR) is not 
#. meant to be exhaustive, but instead is meant to be easily expandable for 
#. particular use cases.
#
## Failing to make a good guess for one of the variables, script leaves it 
#. untouched (unset). Running the script twice will NOT overwrite values that 
#. are already detected and set.
#

# Driver function
d__detect_os()
{
  d__detect_os_family
  d__detect_os_distro_and_pkgmgr
}

#>  d__detect_os_family
#
## Detects the OS family and stores it in a read-only global variable
#
## Provides into the global scope:
#.  $D__OS_FAMILY  - (read-only) Broad description of the current OS type:
#.                  * ‘macos’
#.                  * ‘linux’
#.                  * ‘wsl’ (Windows Subsystem for Linux)
#.                  * ‘bsd’
#.                  * ‘solaris’
#.                  * ‘cygwin’
#.                  * ‘msys’
#
## Returns:
#.  0 - Variable populated successfully
#.  1 - (script exit) Either of scenarios occurred:
#.        * Could not re-assign the variable (already assigned and read-only)
#.        * Could not reliably recognize the OS
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
d__detect_os_family()
{
  # Storage variables
  local adapter_filepath

  # Output variable that is to be set by adapter
  local d__os_family
  
  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Check if $OSTYPE is populated, as is the case in most modern OS’s
  if [ -n "$OSTYPE" ]; then

    # Pass this down to adapter
    local -r d__ostype="$OSTYPE"

  else

    # $OSTYPE is empty or unset: rely on ‘uname -s’
    local -r d__ostype="$( uname -s 2>/dev/null )"

  fi

  # Iterate over OS family adapter files in their respective directory
  while IFS= read -r -d $'\0' adapter_filepath; do

    # Unset any previous incarnation of adapter functions
    unset -f d__adapter_detect_os_family
    unset -f d__adapter_override_dpl_targets_for_os_family

    # Load the adapter
    source "$adapter_filepath"

    # Run d__adapter_detect_os_family function
    d__adapter_detect_os_family &>/dev/null

    # If OS family is successfully detected, break immediately
    [ -n "$d__os_family" ] && break

  # Done iterating over OS family adapter files in their respective directory
  done < <( find -L "$D__DIR_ADP_FAMILY" -name "*$D__SUFFIX_ADAPTER" -print0 )

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Analyze detected OS family
  if [ -z "$d__os_family" ]; then

    # Failed to detect OS family: announce and exit script
    dprint_failure -l 'Failed to detect OS family'
    exit 1

  elif [ "$d__os_family" = "$D__OS_FAMILY" ]; then

    # $D__OS_FAMILY is set to correct value: ensure it is read-only
    ( unset D__OS_FAMILY 2>/dev/null ) && readonly D__OS_FAMILY

  elif ( unset D__OS_FAMILY 2>/dev/null ); then

    # $D__OS_FAMILY is not set to correct value, but is writable
    readonly D__OS_FAMILY="$d__os_family"
  
  else

    # $D__OS_FAMILY is not set to correct value and is read-only: report error
    dprint_failure -l \
      'Internal variable $D__OS_FAMILY is already set and is read-only' \
      "Detected OS family                : $d__os_family" \
      "Content of \$D__OS_FAMILY variable : $D__OS_FAMILY"
    exit 1
  
  fi

  # If additional adapter functions are not implemented, implement dummies
  if ! declare -f d__adapter_override_dpl_targets_for_os_family &>/dev/null
  then
    d__adapter_override_dpl_targets_for_os_family() { return 1; }
  fi

  # Return success
  return 0
}

#>  d__detect_os_distro_and_pkgmgr
#
## Detects current OS distribution, as well as system’s package manager; stores 
#. this info in read-only global variables
#
## Requires:
#.  $D__OS_FAMILY  - From d__detect_os_family
#
## Provides into the global scope:
#.  $D__OS_DISTRO   - (read-only) Best guess on the name of the current OS 
#.                    distribution, without version, e.g.:
#.                      * ‘macos’
#.                      * ‘ubuntu’
#.                      * ‘debian’
#.                      * ‘fedora’
#.                      * unset     - Not recognized
#.  $D__OS_PKGMGR   - (read-only) Widely recognized name of package management 
#.                    utility available on the current system, e.g.:
#.                      * ‘brew’    - macOS
#.                      * ‘apt-get’ - Debian, Ubuntu
#.                      * ‘dnf’     - Fedora
#.                      * ‘yum’     - older Fedora
#.                      * unset     - Not recognized
#.  d__os_pkgmgr    - Thin wrapper around system’s package manager. Accepts the 
#.                    following commands as first argument: ‘update’, ‘check’, 
#.                    ‘install’, and ‘remove’. Remaining arguments are relayed 
#.                    to package manager verbatim. Avoids prompting for user 
#.                    input (except sudo password). Returns whatever the 
#.                    package manager returns, or 2 for unrecognized package 
#.                    manager.
#
## Returns:
#.  0 - Variables populated successfully
#.  1 - (script exit) Could not re-assign a variable (already assigned)
#.  1 - Could not reliably recognize distribution or package manager
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
d__detect_os_distro_and_pkgmgr()
{
  # Storage variables
  local adapter_filepath all_good=true

  # Output variable that is to be set by adapter
  local d__os_distro
  
  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Iterate over OS distro adapter files in their respective directory
  while IFS= read -r -d $'\0' adapter_filepath; do

    # Unset any previous incarnation of adapter functions
    unset -f d__adapter_detect_os_distro
    unset -f d__adapter_detect_os_pkgmgr
    unset -f d__adapter_override_dpl_targets_for_os_distro

    # Load the adapter
    source "$adapter_filepath"

    # Run d__adapter_detect_os_distro function
    d__adapter_detect_os_distro &>/dev/null

    # If OS distro is successfully detected, break immediately
    [ -n "$d__os_distro" ] && break

  # Done iterating over OS distro adapter files in their respective directory
  done < <( find -L "$D__DIR_ADP_DISTRO" -name "*$D__SUFFIX_ADAPTER" -print0 )

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Analyze detected OS distro
  if [ "$d__os_distro" = "$D__OS_DISTRO" ]; then

    # $D__OS_DISTRO is set to correct value: ensure it is read-only
    ( unset D__OS_DISTRO 2>/dev/null ) && readonly D__OS_DISTRO

  elif ( unset D__OS_DISTRO 2>/dev/null ); then

    # $D__OS_DISTRO is not set to correct value, but is writable
    readonly D__OS_DISTRO="$d__os_distro"
  
  else

    # $D__OS_DISTRO is not set to correct value and is read-only: report error
    dprint_failure -l \
      'Internal variable $D__OS_DISTRO is already set and is read-only' \
      "Detected OS distribution          : $d__os_distro" \
      "Content of \$D__OS_DISTRO variable : $D__OS_DISTRO"
    exit 1
  
  fi

  # Check if distro is undetected
  if [ -z "$d__os_distro" ]; then

    # Failed to detect OS distro: announce, unset functions, set flag
    dprint_failure -l 'Failed to detect current OS distribution'
    unset -f d__adapter_detect_os_distro
    unset -f d__adapter_detect_os_pkgmgr
    unset -f d__adapter_override_dpl_targets_for_os_distro
    all_good=false

  fi

  # If additional adapter functions are not implemented, implement dummies
  if ! declare -f d__adapter_override_dpl_targets_for_os_distro &>/dev/null
  then
    d__adapter_override_dpl_targets_for_os_distro() { return 1; }
  fi

  # Pre-unset package manager wrapper function
  unset -f d__os_pkgmgr

  # Run function that is ought to detect system’s package manager
  d__adapter_detect_os_pkgmgr &>/dev/null

  # Analyze detected OS package manager
  if [ "$d__os_pkgmgr" = "$D__OS_PKGMGR" ]; then

    # $D__OS_PKGMGR is set to correct value: ensure it is read-only
    ( unset D__OS_PKGMGR 2>/dev/null ) && readonly D__OS_PKGMGR

  elif ( unset D__OS_PKGMGR 2>/dev/null ); then

    # $D__OS_PKGMGR is not set to correct value, but is writable
    readonly D__OS_PKGMGR="$d__os_pkgmgr"
  
  else

    # $D__OS_PKGMGR is not set to correct value and is read-only: report error
    dprint_failure -l \
      'Internal variable $D__OS_PKGMGR is already set and is read-only' \
      "Detected OS package manager       : $d__os_pkgmgr" \
      "Content of \$D__OS_PKGMGR variable : $D__OS_PKGMGR"
    exit 1
  
  fi

  # Check if pkgmgr is undetected
  if [ -z "$d__os_pkgmgr" ]; then

    # Failed to detect OS pkgmgr: announce, unset functions, set flag
    dprint_failure -l 'Failed to detect current OS’s package manager'
    unset -f d__os_pkgmgr
    all_good=false

  fi

  # If package manager wrapper is not implemented, implement dummy
  if ! declare -f d__os_pkgmgr &>/dev/null; then
    d__os_pkgmgr() { return 2; }
  fi

  # Return appropriate status
  $all_good && return 0 || return 1
}

d__detect_os