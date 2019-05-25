#!/usr/bin/env bash
#:title:        Divine deployment annotated template
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.3.0-RELEASE
#:revdate:      2019.05.24
#:revremark:    Ready for distribution
#:created_at:   2018.03.25

## This is a valid deployment script for Divine.dotfiles repository
#. <https://github.com/no-simpler/divine-dotfiles>
#
## Usage:
#.  1. Copy example ‘*.dpl.sh’ file to anywhere inside ‘deployments’ directory
#.  2. Name the file after whatever you are deploying, e.g., ‘shell-rc.dpl.sh’
#.  3. Fill out whichever part of the file you need (all are optional), e.g.:
#.    3.1. Assign provided global variables
#.    3.2. Implement ‘dcheck’   function following its guidelines
#.    3.3. Implement ‘dinstall’ function following its guidelines
#.    3.4. Implement ‘dremove’  function following its guidelines
#
## Expect these global variables to be available to this script during Divine 
#. intervention:
#.  $D_DIR      - (read-only) Absolute canonical path to directory containing 
#.                ‘intervene.sh’ script that is currently being executed
#.  $D_DPL_DIR  - Absolute canonical path to directory of this deployment, 
#.                i.e., directory containing this script
#.  $D_BACKUPS_DIR
#.              - Absolute canonical path to backups directory
#.  $D_LIB_DIR  - Absolute canonical path to lib directory
#.  $D_ROUTINE  - (read-only) The routine currently being executed. Either 
#.                ‘install’ or ‘remove’.
#.  $D_BLANKET_ANSWER
#.              - (read-only) If user has given a blanket answer, this variable 
#.                will be populated with either ‘y’ or ‘n’, otherwise empty
#.  $D_QUIET    - (read-only) This variable will contain either ‘true’ or 
#.                ‘false’ (never empty) based on user’s verbosity setting
#.  $D_FILTERING
#.              - (read-only) This variable will contain either ‘true’ or 
#.                ‘false’ (never empty) based on whether user has listed 
#.                specific deployments to run (evidently, this one included)
#.  $D_PKGS     - (read-only) This variable will contain either ‘true’ or 
#.                ‘false’ (never empty) based on whether packages are processed 
#.                during this Divine intervention
#.  $OS_FAMILY  - (read-only) Broad description of the current OS type, e.g.:
#.                  * ‘macos’
#.                  * ‘linux’
#.                  * ‘wsl’
#.                  * ‘bsd’
#.                  * ‘solaris’
#.                  * ‘cygwin’
#.                  * ‘msys’
#.                  * unset     - Not recognized
#.  $OS_DISTRO  - (read-only) Best guess on the name of the current OS 
#.                distribution, without version, e.g.:
#.                  * ‘macos’
#.                  * ‘ubuntu’
#.                  * ‘debian’
#.                  * ‘fedora’
#.                  * unset     - Not recognized
#.  $OS_PKGMGR  - (read-only) Name of the package management utility available 
#.                on the current system, e.g.:
#.                  * ‘brew’    (macOS)
#.                  * ‘apt-get’ (Debian, Ubuntu)
#.                  * ‘dnf’     (Fedora)
#.                  * ‘yum’     (older Fedora)
#.                  * unset     - Not recognized
#
## NOTE: To add more recognized OS distributions or package managers, extend 
#. ‘__populate_os_distro’ and ‘__populate_os_pkgmgr’ functions respectively, 
#. both implemented in ‘lib/dos.utl.sh’
#
## Also, intervention script scans ‘lib’ directory and sources every file named 
#. ‘*.utl.sh’ and ‘*.dpl-hlp.sh’. Check those out for various helpful utilities 
#. that can be freely used in deployment scripts.
#
## This template is valid as is, although in this form it does nothing
#
## Do not include regular code outside of pre-defined functions and variables. 
#. During Divine intervention this script is sourced once (assuming it is not 
#. skipped). Insulating code within provided functions allows to avoid 
#. undesired side-effects.
#

#> $D_NAME
#
## Name of this deployment
#
## Trimmed on both sides, truncated to 64 chars. If empty, name of deployment 
#. file, sans ‘.dpl.sh’ suffix, is used.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_NAME=

#> $D_DESC
#
## Description of this deployment, shown before prompting for confirmation
#
## One line only. Trimmed on both sides. If empty, no description is shown.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_DESC=

#> $D_PRIORITY
#
## Priority of this deployment
#
## Smaller numbers are installed earlier. Deployments with same priority are 
#. processed in no particular order. For removal, the order is fully 
#. reversed.
#
## Non-negative integer, or else falls back to global default of 4096.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_PRIORITY=4096

#> $D_FLAGS
#
## A flag is a character that causes special treatment of this deployment. This 
#. variable may contain any number of flags. Repetition is insignificant. 
#. Unrecognized flags are ignored.
#
## User prompting mode flags:
#.  i   - Prompt before [i]nstalling, even with --yes option
#.  r   - Prompt before [r]emoving, even with --yes option
#.  c   - Prompt before [c]hecking, even with --yes option
#.  a   - Prompt before [a]ll above operations, even with --yes option
#
## Deployment grouping flags:
#.  !     - Make deployment part of ‘!’ group
#.  [0-9] - Make deployment part of one of the ten numbered groups
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_FLAGS=

#> $D_WARNING
#
## Warning shown before prompting for confirmation, but only if relevant flag 
#. in $D_FLAGS is in effect. E.g., if deployment is marked with ‘i’ flag, this 
#. warning will be shown before every installation.
#
## One line only. Trimmed on both sides. If empty, no warning is shown.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_WARNING=

#> dcheck
#
## Exit code of this function describes current status of this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0 - “Unknown”: prompt, then install/remove
#.      User will be prompted whether to proceed with installing/removing this 
#.      deployment, then the appropriate function will be called. Prompt is 
#.      affected by both command line options (‘--yes’ and ‘--no’) and 
#.      deployment flags ($D_FLAGS), such as ‘always-prompt’.
#.  1 - “Installed”
#.      During installation routine:  this deployment will be skipped.
#.      During removal routive:       same as 0.
#.  2 - “Not installed”
#.      During installation routine:  same as 0.
#.      During removal routive:       this deployment will be skipped.
#.  3 - “Irrelevant”
#.      During installation routine:  this deployment will be skipped.
#.      During removal routive:       this deployment will be skipped.
#.  4 - “Partly installed”: prompt, then install/remove
#.      Same as 0 functionally, but output slightly changes to signal to user 
#.      that deployment is halfway between installed and not installed.
#.  5 - “Installed by user or OS”
#.      Same as 3 functionally, but output slightly changes to signal to user 
#.      that deployment is installed by means other than this framework and 
#.      thus will not be touched.
#
dcheck()
{
  return 0
}

#> dinstall
#
## Installs this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0   - Successfully installed
#.  1   - Failed to install
#.        Something went wrong, and hopefully things have been cleaned up (it’s 
#.        up to you of course). The overall installation routine will continue.
#.  2   - Skipped completely
#.        Something went wrong, and the whole deployment can be disregarded 
#.        (skipped). This is in case dcheck hasn’t caught skip condition.
#.  100 - Reboot needed
#.        User will be asked for reboot.
#.        Divine intervention will shut down gracefully without moving on.
#.  101 - User attention needed
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down gracefully without moving on.
#.  666 - Critical failure
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down without moving on.
# 
dinstall()
{
  return 0
}

#> dremove
#
## Removes this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0   - Successfully removed
#.  1   - Failed to remove
#.        Something went wrong, and hopefully things have been cleaned up (it’s 
#.        up to you of course). The overall removal routine will continue.
#.  2   - Skipped completely
#.        Something went wrong, and the whole deployment can be disregarded 
#.        (skipped). This is in case dcheck hasn’t caught skip condition.
#.  100 - Reboot needed
#.        User will be asked for reboot.
#.        Divine intervention will shut down gracefully without moving on.
#.  101 - User attention needed
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down gracefully without moving on.
#.  666 - Critical failure
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down without moving on.
# 
dremove()
{
  return 0
}