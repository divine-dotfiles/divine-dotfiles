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
  
  __populate_os_pkgmgr
  unset -f __populate_os_pkgmgr
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

#>  __populate_os_pkgmgr
#
## Detects particular OS package management utility and stores its name in a 
#. read-only global variable. This function is meant to be expanded for 
#. particular required utilities.
#
## Requires:
#.  $OS_DISTRO  - From __populate_os_distro
#
## Provides into the global scope:
#.  $OS_PKGMGR  - (read-only) Name of the package management utility available 
#.                on the current system, e.g.:
#.                  * ‘brew’    (macOS)
#.                  * ‘apt-get’ (Debian, Ubuntu)
#.                  * ‘dnf’     (Fedora)
#.                  * ‘yum’     (older Fedora)
#.                  * unset     - Not recognized
#.  os_pkgmgr - Thin wrapper around system’s package manager. Accepts the 
#.              following commands as first argument: ‘dupdate’, ‘dcheck’, 
#.              ‘dinstall’, and ‘dremove’. Remaining arguments are relayed to 
#.              package manager verbatim. Avoids prompting for user input 
#.              (except sudo password). Returns whatever the package manager 
#.              returns, or -1 for unrecognized package manager.
#
## Returns:
#.  0 - Variable populated successfully
#.  1 - Could not re-assign the variable (already assigned)
#.  2 - Could not reliably recognize the utility
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__populate_os_pkgmgr()
{
  # Storage variable
  local os_pkgmgr

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  ## Detect particular package manager, if it is supported
  #
  ## This section of the code should be extended according to particular needs.
  #. E.g., if one requires particular workflows for macOS’s brew, Ubuntu’s or 
  #. Debian’s apt-get, then these three utilities should be 
  #. detected here, possibly among others.
  #
  local return_code=0
  case "$OS_DISTRO" in
    macos)

      # (Special case) Offer to install Homebrew
      if ! HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null \
        && dstash --root ready &>/dev/null
      then

        # Inform user of the tragic circumstances
        printf >&2 '%s\n' \
          'Failed to detect Homebrew (package manager for macOS)'
        printf >&2 '  %s\n' \
          'https://brew.sh/'

        # Prompt user
        local yes=false
        if [ "$D_BLANKET_ANSWER" = true ]; then yes=true
        elif [ "$D_BLANKET_ANSWER" = false ]; then yes=false
        else

          # Print question
          printf >&2 '%s' 'Would you like to install it? [y/n] '

          # Await answer
          while true; do
            read -rsn1 input
            [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
            [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
          done
          printf '\n'

        fi

        # Check if user accepted
        if $yes; then

          # Announce installation
          printf >&2 '%s\n' 'Installing Homebrew'

          # Proceed with automated installation
          /usr/bin/ruby -e \
            "$( curl -fsSL \
            https://raw.githubusercontent.com/Homebrew/install/master/install \
            )" </dev/null

          # Check exit code and print status message
          if [ $? -eq 0 ]; then
            printf >&2 '%s\n' 'Successfully installed Homebrew'
            dstash --root set installed_homebrew
          else
            printf >&2 '%s\n' 'Failed to install Homebrew'
          fi

        else

          # Proceeding without Homebrew
          printf >&2 '%s\n' 'Proceeding without Homebrew'

        fi

      fi

      # Trying for macOS’s brew
      if HOMEBREW_NO_AUTO_UPDATE=1 brew --version &>/dev/null; then

        # Set global variable
        os_pkgmgr='brew'

        # Implement wrapper aroung package manager
        os_pkgmgr() {
          case "$1" in
            dupdate)  brew update; brew upgrade;;
            dcheck)   shift
                      HOMEBREW_NO_AUTO_UPDATE=1 brew list "$@" &>/dev/null;;
            dinstall) shift; brew install "$@";;
            dremove)  shift; brew uninstall "$@";;
            *)        return 1;;
          esac
        }

      fi
      ;;
    ubuntu|debian)
      # Trying for Ubuntu or Debian’s apt-get
      if apt-get --version &>/dev/null; then

        # Set global variable
        os_pkgmgr='apt-get'

        # Implement wrapper aroung package manager
        os_pkgmgr() {
          case "$1" in
            dupdate)  sudo apt-get update -yq; sudo apt-get upgrade -yq;;
            dcheck)   shift; dpkg-query -l "$@" &>/dev/null;;
            dinstall) shift; sudo apt-get install -yq "$@";;
            dremove)  shift; sudo apt-get remove -yq "$@";;
            *)        return 1;;
          esac
        }

      fi
      ;;
    fedora)
      # Trying for Fedora’s dnf
      if dnf --version &>/dev/null; then

        # Set global variable
        os_pkgmgr='dnf'

        # Implement wrapper aroung package manager
        os_pkgmgr() {
          case "$1" in
            dupdate)  sudo dnf upgrade -yq;;
            dcheck)   shift; sudo dnf list --installed "$@" &>/dev/null;;
            dinstall) shift; sudo dnf install -yq "$@";;
            dremove)  shift; sudo dnf remove -yq "$@";;
            *)        return 1;;
          esac
        }

      # Or else for Fedora’s older yum
      elif yum --version &>/dev/null; then

        # Set global variable
        os_pkgmgr='yum'

        # Implement wrapper aroung package manager
        os_pkgmgr() {
          case "$1" in
            dupdate)  sudo yum update -y;;
            dcheck)   shift; sudo yum list installed "$@" &>/dev/null;;
            dinstall) shift; sudo yum install -y "$@";;
            dremove)  shift; sudo yum remove -y "$@";;
            *)        return 1;;
          esac
        }

      fi
      ;;
    *)
      # If not certain, do not touch global variables at all
      return_code=2
      ;;
  esac

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Report and return
  if [ -z "$os_pkgmgr" ]; then

    # Failed to detect OS package manager: not fatal, but should be noted
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      'Current OS package manager is not recognized'

    # Implement dummy wrapper
    os_pkgmgr() { return -1; }

    return 2

  elif [ "$os_pkgmgr" = "$OS_PKGMGR" ]; then

    # $OS_PKGMGR is set to correct value: ensure it is read-only
    ( unset OS_PKGMGR 2>/dev/null ) && readonly OS_PKGMGR
    return 0

  elif ( unset OS_PKGMGR 2>/dev/null ); then

    # $OS_PKGMGR is set to incorrect value but is not read-only: set and make
    readonly OS_PKGMGR="$os_pkgmgr"
    return 0
  
  else

    # $OS_PKGMGR is set to incorrect value and is read-only: report error
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      '$OS_PKGMGR is already set to incorrect value and is read-only'
    printf >&2 '%s: %s\n' 'Detected OS package manager    ' "$os_pkgmgr"
    printf >&2 '%s: %s\n' 'Content of $OS_PKGMGR variable ' "$OS_PKGMGR"

    # Implement dummy wrapper
    os_pkgmgr() { return -1; }

    return 1
  
  fi
}

__main
unset -f __main