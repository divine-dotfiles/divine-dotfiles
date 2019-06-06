#!/usr/bin/env bash
#:title:        Divine Bash utils: dOS
#:kind:         global_var,func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.1.0-RELEASE
#:revdate:      2019.03.25
#:revremark:    Release revision
#:created_at:   2019.03.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Provides into the global scope three read-only variables:
#.  $OS_FAMILY  - (read-only) Broad description of the current OS type.
#.  $OS_DISTRO  - (read-only) Best guess on the name of the current OS 
#.                distribution, without version.
#.  $OS_PKGMGR  - (read-only) Name of the package management utility available 
#.                on the current system.
#
## Provides into the global scope these functions:
#.  os_pkgmgr - Thin wrapper around system’s package manager. Accepts the 
#.              following commands as first argument: ‘dupdate’, ‘dcheck’, 
#.              ‘dinstall’, and ‘dremove’. Remaining arguments are relayed to 
#.              package manager verbatim. Avoids prompting for user input 
#.              (except sudo password). Returns whatever the package manager 
#.              returns, or -1 for unrecognized package manager.
#
## List of supported distros ($OS_DISTRO) and utilities ($OS_PKGMGR) is not 
#. meant to be exhaustive, but instead is meant to be easily expandable for 
#. particular use cases.
#
## Failing to make a good guess for one of the variables, script leaves it 
#. untouched (unset). Running the script twice will NOT overwrite values that 
#. are already detected and set.
#

# Driver function
__main()
{
  __populate_os_family
  unset -f __populate_os_family

  __populate_os_distro
  unset -f __populate_os_distro
  
  __load_os_adapter
  unset -f __load_os_adapter
}

#>  __populate_os_family
#
## Detects the OS family and stores it in a read-only global variable. Only 
#. OS’s that are normally thought of as supporting Bash are considered, e.g., 
#. no Windows.
#
## Provides into the global scope:
#.  $OS_FAMILY  - (read-only) Broad description of the current OS type, e.g.:
#.                  * ‘macos’
#.                  * ‘linux’
#.                  * ‘wsl’
#.                  * ‘bsd’
#.                  * ‘solaris’
#.                  * ‘cygwin’
#.                  * ‘msys’
#.                  * unset     - Not recognized
#
## Returns:
#.  0 - Variable populated successfully
#.  1 - Could not re-assign the variable (already assigned and read-only)
#.  2 - Could not reliably recognize the OS
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__populate_os_family()
{
  # Storage variable
  local os_family

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch
  
  ## Detect the broad family of OS’s.
  #
  ## This uses $OSTYPE built-in bash variable and falls back to `uname -s`. 
  #. Such set-up should hold pretty well.
  #
  case "$OSTYPE" in
    darwin*)
      os_family='macos'
      ;;
    linux*)
      if [[ "$( 2>/dev/null </proc/version )" =~ (microsoft|wsl) ]]; then
        os_family='wsl'
      else
        os_family='linux'
      fi
      ;;
    freebsd*|openbsd*|netbsd*)
      os_family='bsd'
      ;;
    solaris*)
      os_family='solaris'
      ;;
    cygwin*)
      os_family='cygwin'
      ;;
    msys*)
      os_family='msys'
      ;;
    *)
      # In case $OSTYPE is misbehaving
      case "$( uname -s 2>/dev/null )" in
        darwin*)
          os_family='macos'
          ;;
        linux*)
          if [[ "$( 2>/dev/null </proc/version )" =~ (microsoft|wsl) ]]; then
            os_family='wsl'
          else
            os_family='linux'
          fi
          ;;
        freebsd*|openbsd*|netbsd*)
          os_family='bsd'
          ;;
        sunos*)
          os_family='solaris'
          ;;
        cygwin*)
          os_family='cygwin'
          ;;
        msys*|mingw*)
          os_family='msys'
          ;;
        *)
          os_family=
          ;;
      esac
      ;;
  esac

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Report and return
  if [ -z "$os_family" ]; then

    # Failed to detect OS family: not fatal, but should be noted
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" 'Failed to detect OS family'
    return 2

  elif [ "$os_family" = "$OS_FAMILY" ]; then

    # $OS_FAMILY is set to correct value: ensure it is read-only
    ( unset OS_FAMILY 2>/dev/null ) && readonly OS_FAMILY
    return 0

  elif ( unset OS_FAMILY 2>/dev/null ); then

    # $OS_FAMILY is set to incorrect value but is not read-only: set and make
    readonly OS_FAMILY="$os_family"
    return 0
  
  else

    # $OS_FAMILY is set to incorrect value and is read-only: report error
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      '$OS_FAMILY is already set to incorrect value and is read-only'
    printf >&2 '%s: %s\n' 'Detected OS family             ' "$os_family"
    printf >&2 '%s: %s\n' 'Content of $OS_FAMILY variable ' "$OS_FAMILY"
    return 1
  
  fi
}

#>  __populate_os_distro
#
## Detects particular OS distributions and stores it in a read-only global 
#. variable. This function is meant to be expanded for particular required 
#. distributions.
#
## Requires:
#.  $OS_FAMILY  - From __populate_os_family
#
## Provides into the global scope:
#.  $OS_DISTRO  - (read-only) Best guess on the name of the current OS 
#.                distribution, without version, e.g.:
#.                  * ‘macos’
#.                  * ‘ubuntu’
#.                  * ‘debian’
#.                  * ‘fedora’
#.                  * unset     - Not recognized
#
## Returns:
#.  0 - Variable populated successfully
#.  1 - Could not re-assign the variable (already assigned)
#.  2 - Could not reliably recognize the distro
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__populate_os_distro()
{
  # Storage variable
  local os_distro

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  ## Detect particular distro, if it is supported
  #
  ## This section of the code should be extended according to particular needs.
  #. E.g., if one requires particular workflows for macOS, Ubuntu, and Debian, 
  #. then these three distributions should be detected here, possibly among 
  #. others.
  #
  local return_code=0
  case "$OS_FAMILY" in
    macos)
      # For now, no need for detecting particular macOS version
      os_distro='macos'
      ;;
    linux|wsl)
      if cat /etc/os-release 2>/dev/null | grep -qi ubuntu; then
        # Ubuntu 12+
        os_distro='ubuntu'
      elif lsb_release -a 2>/dev/null | grep -qi debian; then
        # Debian 6+
        os_distro='debian'
      elif cat /etc/fedora-release 2>/dev/null | grep -qi fedora; then
        # Fedora 18+
        os_distro='fedora'
      fi
      ;;
    *)
      os_distro=
      ;;
  esac

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Report and return
  if [ -z "$os_distro" ]; then

    # Failed to detect OS distro: not fatal, but should be noted
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      'Current OS distro is not recognized'
    return 2

  elif [ "$os_distro" = "$OS_DISTRO" ]; then

    # $OS_DISTRO is set to correct value: ensure it is read-only
    ( unset OS_DISTRO 2>/dev/null ) && readonly OS_DISTRO
    return 0

  elif ( unset OS_DISTRO 2>/dev/null ); then

    # $OS_DISTRO is set to incorrect value but is not read-only: set and make
    readonly OS_DISTRO="$os_distro"
    return 0
  
  else

    # $OS_DISTRO is set to incorrect value and is read-only: report error
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      '$OS_DISTRO is already set to incorrect value and is read-only'
    printf >&2 '%s: %s\n' 'Detected OS distro             ' "$os_distro"
    printf >&2 '%s: %s\n' 'Content of $OS_DISTRO variable ' "$OS_DISTRO"
    return 1
  
  fi
}

#>  __load_os_adapter
#
## Scans adapters dir for files ‘$OS_FAMILY.adp.sh’ and ‘$OS_DISTRO.adp.sh’ and 
#. sources each, if found, in that order. After sourcing both, ensures as best 
#. it can that required functions are implemented, or terminates the script.
#
## Requires:
#.  $OS_FAMILY  - From __populate_os_family
#.  $OS_DISTRO  - From __populate_os_distro
#
## Provides into the global scope:
#.  $OS_PKGMGR  - (read-only) Widely recognized name of package management 
#.                utility available on the current system, e.g.:
#.                  * ‘brew’    - macOS
#.                  * ‘apt-get’ - Debian, Ubuntu
#.                  * ‘dnf’     - Fedora
#.                  * ‘yum’     - older Fedora
#.                  * unset     - Not recognized
#.  os_pkgmgr - Thin wrapper around system’s package manager. Accepts the 
#.              following commands as first argument: ‘dupdate’, ‘dcheck’, 
#.              ‘dinstall’, and ‘dremove’. Remaining arguments are relayed to 
#.              package manager verbatim. Avoids prompting for user input 
#.              (except sudo password). Returns whatever the package manager 
#.              returns, or -1 for unrecognized package manager.
#
## Returns:
#.  0 - Adapter loaded successfully
#.  1 - Non-fatal problem with adapter
#.  2 - Arguably fatal problem with adapter
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__load_os_adapter()
{
  # Set up variables
  local family_adapter distro_adapter

  # Status variables
  local all_good=true should_halt=false

  # If OS family is detected and family adapter exists, source it
  if [ -n "$OS_FAMILY" ]; then

    # Compose path to adapter
    family_adapter="${D_ADAPTERS_FAMILY_DIR}/${OS_FAMILY}${D_ADAPTER_SUFFIX}"

    # Check if it is a readable file
    if [ -r "$family_adapter" -a -f "$family_adapter" ]; then

      source "$family_adapter"

    else

      # Report error
      $D_QUIET || printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
        "No adapter detected for current OS family: $OS_FAMILY"

    fi

  fi

  # If OS distro is detected and distro adapter exists, source it
  if [ -n "$OS_DISTRO" ]; then

    # Compose path to adapter
    distro_adapter="${D_ADAPTERS_DISTRO_DIR}/${OS_DISTRO}${D_ADAPTER_SUFFIX}"

    # Check if it is a readable file
    if [ -r "$distro_adapter" -a -f "$distro_adapter" ]; then

      source "$distro_adapter"

    else

      # Report error
      $D_QUIET || printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
        "No adapter detected for current OS distro: $OS_DISTRO"

    fi

  fi

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Check if __print_os_pkgmgr is implemented
  if declare -f __print_os_pkgmgr &>/dev/null; then

    # Storage variable
    local os_pkgmgr="$( __print_os_pkgmgr 2>/dev/null || exit $? )"

    # Check if __print_os_pkgmgr ran without a snag
    if [ $? -eq 0 ]; then

      # Check if os_pkgmgr is properly detected
      if [ -z "$os_pkgmgr" ]; then

        # Failed to detect OS package manager: not fatal, but should be noted
        printf >&2 '%s: %s %s\n' "${FUNCNAME[0]}" \
          'Package manager is not recognized for current OS:' \
          "$OS_FAMILY ($OS_DISTRO)"
        all_good=false

      elif [[ $os_pkgmgr = $OS_PKGMGR ]]; then

        # $OS_PKGMGR is set to correct value: ensure it is read-only
        ( unset OS_PKGMGR 2>/dev/null ) && readonly OS_PKGMGR
        all_good=false

      elif ( unset OS_PKGMGR 2>/dev/null ); then

        # $OS_PKGMGR is set to incorrect value but is writable: set and make
        readonly OS_PKGMGR="$os_pkgmgr"
        all_good=false
      
      else

        # $OS_PKGMGR is set to incorrect value and is read-only: report error
        printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
          '$OS_PKGMGR is already set to incorrect value and is read-only'
        printf >&2 '%s: %s\n' 'Detected OS package manager    ' "$os_pkgmgr"
        printf >&2 '%s: %s\n' 'Content of $OS_PKGMGR variable ' "$OS_PKGMGR"
        printf >&2 '%s: %s\n' 'Detected OS                    ' \
          "$OS_FAMILY ($OS_DISTRO)"
        all_good=false
        should_halt=true
      
      fi

    else

      # Function __print_os_pkgmgr returned non-zero
      printf >&2 '%s: %s %s\n' "${FUNCNAME[0]}" \
          'Failed to detect package manager on current OS:' \
          "$OS_FAMILY ($OS_DISTRO)"
      all_good=false

    fi

  else

    # Function __print_os_pkgmgr is not implemented
    printf >&2 '%s: %s %s\n' "${FUNCNAME[0]}" \
      'Package manager is not supported on current OS:' \
      "$OS_FAMILY ($OS_DISTRO)"
    all_good=false

  fi

  # Check if adapter implements os_pkgmgr function
  if ! declare -f os_pkgmgr &>/dev/null; then

    # Not implemented: report and implement dummy wrapper
    printf >&2 '%s: %s %s\n' "${FUNCNAME[0]}" \
      'Package manager wrapper is not implemented on current OS:' \
      "$OS_FAMILY ($OS_DISTRO)"
    os_pkgmgr() { return -1; }
    all_good=false

  fi

  # Check if adapter implements __override_d_targets_for_distro function
  if ! declare -f __override_d_targets_for_distro &>/dev/null; then

    # Not implemented: implement dummy function
    __override_d_targets_for_distro() { return 1; }

  fi

  # Check if adapter implements __override_d_targets_for_family function
  if ! declare -f __override_d_targets_for_family &>/dev/null; then

    # Not implemented: implement dummy function
    __override_d_targets_for_family() { return 1; }

  fi

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Return
  if $all_good; then return 0
  elif $should_halt; then return 2
  else return 1; fi
}

__main
unset -f __main