#!/usr/bin/env bash
#:title:        Divine.dotfiles template OS distro adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support a particular OS distribution and its system package manager.
#
## For a particular OS distribution to be recognized, detection code must be 
#. added to lib/procedures/detect-os.pcd.sh.
#
## For the adapter file to be recognized, it must be named 'DISTRO.adp.sh', and 
#. placed in the lib/adapters directory. The 'DISTRO' part must be the same as 
#. the handle assigned to the $D__OS_DISTRO variable during OS detection.
#

#>  d__detect_os_pkgmgr
#
## This function is called only if the current distribution matched. The code 
#. in this function should detect whether a supported system package manager is 
#. available and, if so, implement a wrapper around it. Guidelines below must 
#. be followed.
#
## The calling context of this function is guaranteed to have the 'nocasematch' 
#. Bash option enabled.
#
## The following global variables are made available to this function (all 
#. read-only):
#.  $D__OS_FAMILY   - The one-word handle of the current OS family.
#.  $D__OS_DISTRO   - The one-word handle of the current OS distribution.
#
## The following local variables must be populated (assigned to) within this 
#. function to signal to the calling context that the package manager has been 
#. successfully detected (the calling context declares these variables local 
#. and initializes each to an empty string before calling this function):
#.  $d__os_pkgmgr   - The one-word handle of the detected system package 
#.                    manager. This word will be assigned to read-only global 
#.                    variable $D__OS_PKGMGR, which in turn is then used 
#.                    throughout this framework and its deployments.
#.                    For clarity, the word must match the widely recognized 
#.                    name of the package manager's executable command (e.g., 
#.                    'apt-get').
#.                    After this function is called, any non-empty value in 
#.                    this variable is taken as an indication of the positive 
#.                    match on the package manager.
#
## The following functions must be implemented within this function in case the 
#. package manager has been successfully detected:
#.  d__os_pkgmgr    - See the description below.
#
## Returns:
#.  Return code is ignored.
#
## Below is an example implementation for the 'apt-get' package manager.
#
d__detect_os_pkgmgr()
{
  # Check if apt-get is available
  apt-get --version &>/dev/null || return 1

  # Set marker variable
  d__os_pkgmgr='apt-get'

  # Implement wrapper function

  #>  d__os_pkgmgr update|check|install|remove [ARG]...
  #
  ## Thin wrapper around the system package manager. Launches one of the five 
  #. basic commands.
  #
  ## The second argument (package name) must be relayed to the package manager 
  #. verbatim. User prompts should be avoided; the sole exception to this is 
  #. the warning about an upcoming prompt for sudo password: a call to 
  #. 'd__require_sudo PKGMGR_NAME' should be included immediately prior to the 
  #. sudo command.
  #
  ## Arguments:
  #.  $1  - One of five routines to launch:
  #.          * 'update'  - Updates all installed packages. Other arguments 
  #.                        should be ignored.
  #.          * 'has'     - Checks whether the single provided package can be 
  #.                        installed, i.e., whether it exists at all in the 
  #.                        currently available repositories. Must return zero 
  #.                        if it is, and non-zero otherwise. Also, this call 
  #.                        to the package manager must be completely silent 
  #.                        (&>/dev/null).
  #.          * 'check'   - Checks whether the single provided package is 
  #.                        installed. Must return zero if it is, and non-zero 
  #.                        otherwise. Also, this call to the package manager 
  #.                        must be completely silent (&>/dev/null).
  #.          * 'install' - Installs the single provided package. Must return 
  #.                        zero if the installation is successful and non-zero 
  #.                        otherwise.
  #.          * 'remove'  - Uninstalls the single provided package. Must return 
  #.                        zero if the uninstallation is successful and 
  #.                        non-zero otherwise.
  #.  $2  - Name of the package to check/install/remove.
  #
  ## Additional return codes:
  #.  1 - Unrecognized routine
  #.  2 - Wrapper is not implemented at all
  #
  ## Prints:
  #.  Whatever the underlying package manager prints
  #
  d__os_pkgmgr()
  {
    case "$1" in
      update)   d__require_sudo apt-get; sudo apt-get update -y; sudo apt-get upgrade -y;;
      has)      apt-cache show "$2" &>/dev/null;;
      check)    grep -qFx 'install ok installed' <( dpkg-query -W -f='${Status}\n' "$2" 2>/dev/null );;
      install)  d__require_sudo apt-get; sudo apt-get install -y "$2";;
      remove)   d__require_sudo apt-get; sudo apt-get remove -y "$2";;
      *)        return 1;;
    esac
  }
}