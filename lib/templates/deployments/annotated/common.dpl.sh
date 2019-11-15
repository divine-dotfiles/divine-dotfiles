#!/usr/bin/env bash
#:title:        Divine deployment annotated template
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Fix minor typo
#:created_at:   2018.03.25

## This is a valid deployment script for Divine.dotfiles framework
#. <https://github.com/no-simpler/divine-dotfiles>
#
## Usage:
#.  1. Copy this template to anywhere under 'grail/dpls' directory
#.  2. Rename the file after whatever you are deploying, e.g., 'my-dpl.dpl.sh'
#.  3. Fill out whichever parts of this file you need (all are optional):
#.    3.1. Assign provided global variables
#.    3.2. Implement 'd_dpl_check'   function following its guidelines
#.    3.3. Implement 'd_dpl_install' function following its guidelines
#.    3.4. Implement 'd_dpl_remove'  function following its guidelines
#
## Below are some of the global variables that are available to this script 
#. during Divine intervention:
#.  $D__DPL_DIR         - Absolute canonical path to directory containing 
#.                        deployment script
#.  $D__DPL_ASSET_DIR   - Absolute canonical path to directory alotted for 
#.                        asset files of this deployment
#.  $D__OS_FAMILY       - (read-only) Broad description of the current OS type. 
#.                        Each file in 'lib/adapters/family' represents a 
#.                        supported OS family. Empty, when not recognized.
#.  $D__OS_DISTRO       - (read-only) Best guess on the name of the current OS 
#.                        distribution, without version. Each file in 'lib/
#.                        adapters/distro represents a supported OS distro. 
#.                        Empty, when not recognized.
#.  $D__OS_PKGMGR       - (read-only) Name of the package management utility 
#.                        available on current system. Normally coincides with 
#.                        executable name, e.g.:
#.                          * brew        - macOS
#.                          * apt-get     - Debian, Ubuntu
#.                          * dnf         - Fedora
#.                          * yum         - older Fedora
#.                          * [empty]     - Not recognized
#
## NOTE: To add more recognized OS distributions or package managers, add 
#. distro adapters to 'lib/adapters/distro'.
#
## This template is valid as is, although in this form it does nothing
#
## During Divine intervention, each deployment script script is sourced once or 
#. not at all
#

#> $D_DPL_NAME
#
## Name of this deployment
#
## Whitespace is trimmed on both sides. If the variable is not assigned, 
#. defaults to the name of deployment file, sans '.dpl.sh' suffix.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_DPL_NAME=

#> $D_DPL_DESC
#
## Description of this deployment, shown before prompting for confirmation
#
## One line only. Trimmed on both sides. If empty, no description is shown.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_DPL_DESC=

#> $D_DPL_PRIORITY
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
D_DPL_PRIORITY=4096

#> $D_DPL_FLAGS
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
#.  !     - Make deployment part of '!' group
#.  [0-9] - Make deployment part of one of the ten numbered groups
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_DPL_FLAGS=

#> $D_DPL_WARNING
#
## Warning shown before prompting for confirmation, but only if relevant flag 
#. in $D_DPL_FLAGS is in effect. E.g., if deployment is marked with 'i' flag, 
#. this warning will be shown before every installation.
#
## One line only. Trimmed on both sides. If empty, no warning is shown.
#
## NOTE: Keep this assignment on its own line! The value is not read by Bash 
#. interpreter, but is rather extracted using a regular expression. Quotes are 
#. allowed (they are stripped in processing).
#
D_DPL_WARNING=

#>  d_dpl_check
#
## Exit code of this function describes current status of this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0 - "Unknown"
#.      If the user has agreed to process this deployment by either hitting 'y' 
#.      during prompt or providing '--yes' option, this deployment will be 
#.      installed/removed as normal.
#.  1 - "Installed"
#.      During installation routine:  this deployment will be skipped.
#.      During removal routive:       same as 0.
#.  2 - "Not installed"
#.      During installation routine:  same as 0.
#.      During removal routive:       this deployment will be skipped.
#.  3 - "Irrelevant"
#.      During installation routine:  this deployment will be skipped.
#.      During removal routive:       this deployment will be skipped.
#.  4 - "Partly installed"
#.      Same as 0 functionally, but output slightly changes to signal to user 
#.      that deployment is halfway between installed and not installed.
#
## Optional global variables:
#.  $D_DPL_NEEDS_ANOTHER_PROMPT
#.            - Set this one to 'true' to ensure that user is prompted again 
#.              about whether they are sure they want to proceed. This 
#.              additional prompt is not affected by '--yes' option.
#.  $D_DPL_NEEDS_ANOTHER_WARNING
#.            - If $D_DPL_NEEDS_ANOTHER_PROMPT is set to 'true', this textual 
#.              warning will be printed. Use this to explain possible 
#.              consequences.
#.  $D_DPL_INSTALLED_BY_USER_OR_OS
#.            - Set this one to 'true' to signal that all parts of current 
#.              deployment that are detected to be already installed, have been 
#.              installed by user or OS, not by this framework. This affects 
#.              following return codes:
#.                * 1 (installed)         - removes ability to remove
#.                * 4 (partly installed)  - removes ability to remove
#.              In both cases output is modified to inform user. This is useful 
#.              for deployments designed to not touch anything done by user 
#.              manually.
#
## The following table summarizes how d_dpl_check affects framework behavior:
#. +-----------------------------------------------------------+
#. | Allowed actions depending on return status of d_dpl_check |
#. +-----------------------------------------------------------+
#. |             |  normal  |  D_DPL_INSTALLED_BY |  '--force' |
#. |             |          |   _USER_OR_OS=true  |   option   |
#. +-------------+----------+---------------------+------------+
#. |             |          |                     |   install  |
#. +      1      +----------+---------------------+------------+
#. |  installed  |  remove  |                     |   remove   |
#. +-------------+----------+---------------------+------------+
#. |      4      |  install |       install       |   install  |
#. +    partly   +----------+---------------------+------------+
#. |  installed  |  remove  |                     |   remove   |
#. +-------------+----------+---------------------+------------+
#. |      2      |  install |       install       |   install  |
#. +     not     +----------+---------------------+------------+
#. |  installed  |          |                     |   remove   |
#. +-------------+----------+---------------------+------------+
#. |             |  install |       install       |   install  |
#. +      0      +----------+---------------------+------------+
#. |   unknown   |  remove  |        remove       |   remove   |
#. +-------------+----------+---------------------+------------+
#. |             |          |                     |            |
#. +      3      +----------+---------------------+------------+
#. |  irrelevant |          |                     |            |
#. +-------------+----------+---------------------+------------+
#
d_dpl_check()
{
  return 0
}

#>  d_dpl_install
#
## Installs this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0   - Successfully installed
#.  1   - Failed to install
#.        Something went wrong, and hopefully things have been cleaned up (it's 
#.        up to you of course). The overall installation routine will continue.
#.  2   - Skipped completely
#.        Something went wrong, and the whole deployment can be disregarded 
#.        (skipped). This is in case d_dpl_check hasn't caught skip condition.
#.  100 - Reboot needed
#.        User will be asked for reboot.
#.        Divine intervention will shut down gracefully without moving on.
#.  101 - User attention needed
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down gracefully without moving on.
#.  102 - Critical failure
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down without moving on.
# 
d_dpl_install()
{
  return 0
}

#>  d_dpl_remove
#
## Removes this deployment
#
## Both stdout and stderr will be shown to the user. If this function is not 
#. defined, exit code of 0 is assumed. Same for non-standard exit codes.
#
## Exit codes and their meaning:
#.  0   - Successfully removed
#.  1   - Failed to remove
#.        Something went wrong, and hopefully things have been cleaned up (it's 
#.        up to you of course). The overall removal routine will continue.
#.  2   - Skipped completely
#.        Something went wrong, and the whole deployment can be disregarded 
#.        (skipped). This is in case d_dpl_check hasn't caught skip condition.
#.  100 - Reboot needed
#.        User will be asked for reboot.
#.        Divine intervention will shut down gracefully without moving on.
#.  101 - User attention needed
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down gracefully without moving on.
#.  102 - Critical failure
#.        You are expected to print explanation to the user.
#.        Divine intervention will shut down without moving on.
# 
d_dpl_remove()
{
  return 0
}