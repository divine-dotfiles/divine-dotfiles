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
#.    3.2. Implement ‘d_dpl_check’   function following its guidelines
#.    3.3. Implement ‘d_dpl_install’ function following its guidelines
#.    3.4. Implement ‘d_dpl_remove’  function following its guidelines
#
## Expect these global variables to be available to this script during Divine 
#. intervention:
#.  $D__DIR_FMWK - (read-only) Absolute canonical path to directory containing 
#.                ‘intervene.sh’ script that is currently being executed
#.  $D__DPL_DIR  - Absolute canonical path to directory of this deployment, 
#.                i.e., directory containing this script
#.  $D__DIR_BACKUPS
#.              - Absolute canonical path to backups directory
#.  $D__DIR_LIB
#.              - Absolute canonical path to lib directory
#.  $D__REQ_ROUTINE
#.              - (read-only) The routine currently being executed. Either 
#.                ‘install’ or ‘remove’.
#.  $D__OPT_ANSWER
#.              - (read-only) If user has given a blanket answer, this variable 
#.                will be populated with either ‘y’ or ‘n’, otherwise empty
#.  $D__OPT_QUIET
#.              - (read-only) This variable will contain either ‘true’ or 
#.                ‘false’ (never empty) based on user’s verbosity setting
#.  $D__REQ_FILTER
#.              - (read-only) This variable will contain either ‘true’ or 
#.                ‘false’ (never empty) based on whether user has listed 
#.                specific deployments to run (evidently, this one included)
#.  $D__REQ_PACKAGES
#.              - (read-only) This variable will contain either ‘true’ or 
#.                ‘false’ (never empty) based on whether packages are processed 
#.                during this Divine intervention
#.  $D__OS_FAMILY  - (read-only) Broad description of the current OS type, e.g.:
#.                  * ‘macos’
#.                  * ‘linux’
#.                  * ‘wsl’
#.                  * ‘bsd’
#.                  * ‘solaris’
#.                  * ‘cygwin’
#.                  * ‘msys’
#.                  * unset     - Not recognized
#.  $D__OS_DISTRO  - (read-only) Best guess on the name of the current OS 
#.                distribution, without version, e.g.:
#.                  * ‘macos’
#.                  * ‘ubuntu’
#.                  * ‘debian’
#.                  * ‘fedora’
#.                  * unset     - Not recognized
#.  $D__OS_PKGMGR  - (read-only) Name of the package management utility available 
#.                on the current system, e.g.:
#.                  * ‘brew’    (macOS)
#.                  * ‘apt-get’ (Debian, Ubuntu)
#.                  * ‘dnf’     (Fedora)
#.                  * ‘yum’     (older Fedora)
#.                  * unset     - Not recognized
#
## NOTE: To add more recognized OS distributions or package managers, add 
#. distro adapters to lib/adapters/distro
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

#> $D__DPL_NAME
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
D__DPL_NAME=

#> $D__DPL_DESC
#
## Description of this deployment, shown before prompting for confirmation
#
## One line only. Trimmed on both sides. If empty, no description is shown.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D__DPL_DESC=

#> $D__DPL_PRIORITY
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
D__DPL_PRIORITY=4096

#> $D__DPL_FLAGS
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
D__DPL_FLAGS=

#> $D__DPL_WARNING
#
## Warning shown before prompting for confirmation, but only if relevant flag 
#. in $D__DPL_FLAGS is in effect. E.g., if deployment is marked with ‘i’ flag, 
#. this warning will be shown before every installation.
#
## One line only. Trimmed on both sides. If empty, no warning is shown.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D__DPL_WARNING=

#> d_dpl_check
#
## Exit code of this function describes current status of this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0 - “Unknown”
#.      If the user has agreed to process this deployment by either hitting ‘y’ 
#.      during prompt or providing ‘--yes’ option, this deployment will be 
#.      installed/removed as normal.
#.  1 - “Installed”
#.      During installation routine:  this deployment will be skipped.
#.      During removal routive:       same as 0.
#.  2 - “Not installed”
#.      During installation routine:  same as 0.
#.      During removal routive:       this deployment will be skipped.
#.  3 - “Irrelevant”
#.      During installation routine:  this deployment will be skipped.
#.      During removal routive:       this deployment will be skipped.
#.  4 - “Partly installed”
#.      Same as 0 functionally, but output slightly changes to signal to user 
#.      that deployment is halfway between installed and not installed.
#
## Optional global variables:
#.  $D__ANOTHER_PROMPT   - Set this one to 'true' to ensure that user is 
#.                        prompted again about whether they are sure they want 
#.                        to proceed. This additional prompt is not affected by 
#.                        ‘--yes’ command line option.
#.  $D__ANOTHER_WARNING  - If $D__ANOTHER_PROMPT is set to 'true', this textual 
#.                        warning will be printed. Use this to explain possible 
#.                        consequences.
#.  $D__USER_OR_OS       - Set this one to 'true' to signal that all parts of 
#.                        current deployment that are detected to be already 
#.                        installed, have been installed by user or OS, not by 
#.                        this framework. This affects following return codes:
#.                          * 1 (installed) — removes ability to remove
#.                          * 4 (partly installed) — removes ability to remove
#.                        In both cases output is modified to inform user.
#.                        This is useful for deployments designed to not touch 
#.                        anything done by user manually.
#
## The following table summarizes how d_dpl_check affects framework behavior:
#. +------------------------------------------------------------------+
#. |       Allowed actions depending on return status of d_dpl_check       |
#. +------------------------------------------------------------------+
#. |                    |  normal  | D__USER_OR_OS=true | '-f' option |
#. +--------------------+----------+--------------------+-------------+
#. |                    |          |                    |   d_dpl_install  |
#. +          1         +----------+--------------------+-------------+
#. |     'installed'    |  d_dpl_remove |                    |    d_dpl_remove  |
#. +--------------------+----------+--------------------+-------------+
#. |                    | d_dpl_install |      d_dpl_install      |   d_dpl_install  |
#. +          4         +----------+--------------------+-------------+
#. | 'partly installed' |  d_dpl_remove |                    |    d_dpl_remove  |
#. +--------------------+----------+--------------------+-------------+
#. |                    | d_dpl_install |      d_dpl_install      |   d_dpl_install  |
#. +          2         +----------+--------------------+-------------+
#. |   'not installed'  |          |                    |    d_dpl_remove  |
#. +--------------------+----------+--------------------+-------------+
#. |                    | d_dpl_install |      d_dpl_install      |   d_dpl_install  |
#. +          0         +----------+--------------------+-------------+
#. |      'unknown'     |  d_dpl_remove |       d_dpl_remove      |    d_dpl_remove  |
#. +--------------------+----------+--------------------+-------------+
#. |                    |          |                    |             |
#. +          3         +----------+--------------------+-------------+
#. |    'irrelevant'    |          |                    |             |
#. +--------------------+----------+--------------------+-------------+
#
d_dpl_check()
{
  return 0
}

#> d_dpl_install
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
#.        (skipped). This is in case d_dpl_check hasn’t caught skip condition.
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
d_dpl_install()
{
  return 0
}

#> d_dpl_remove
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
#.        (skipped). This is in case d_dpl_check hasn’t caught skip condition.
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
d_dpl_remove()
{
  return 0
}