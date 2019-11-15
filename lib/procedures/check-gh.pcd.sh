#!/usr/bin/env bash
#:title:        Divine Bash procedure: check-gh
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.18
#:revremark:    Improve debug output of utility choices
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Checks availability of tools necessary to interact with Github.
#

# Marker and dependencies
readonly D__PCD_CHECK_GH=loaded
d__load util workflow

# Driver function
d__pcd_check_gh()
{
  d__check_gh_access
}

#>  d__check_gh_access
#
## Checks whether the system has the capacity to retrieve Github repositories. 
#. Stores the result in a global variable for later reference by other 
#. framework components, such as the gh-queue helper.
#
## Modifies in the global scope:
#.  D__GH_METHOD      - Following values are possible:
#.                        * 'g' - Github repositories may be cloned via Git.
#.                        * 'c' - Github repositories may be downloaded via 
#.                                curl and then untarred.
#.                        * 'w' - Github repositories may be downloaded via 
#.                                wget and then untarred.
#.                        * '' (empty)  - There is no way to retrieve Github 
#.                                        repositories on this system.
#
## Returns:
#.  0 - At least one method of retrieving Github repositories is available.
#.  1 - Otherwise.
#
d__check_gh_access()
{
  D__GH_METHOD=
  if git --version &>/dev/null; then
    D__GH_METHOD=g
    d__notify -qqq -- "Using Git to retrieve Github repositories"
  elif tar --version &>/dev/null; then
    if curl --version &>/dev/null; then
      D__GH_METHOD=c
      d__notify -qqq -- "Using 'curl' utility to retrieve Github repositories"
    elif wget --version &>/dev/null; then
      D__GH_METHOD=w
      d__notify -qqq -- "Using 'wget' utility to retrieve Github repositories"
    fi
  fi
  readonly D__GH_METHOD
  if [ -z "$D__GH_METHOD" ]
  then d__notify -lx -- 'Unable to work with Github repositories'; return 1; fi
  return 0
}

d__pcd_check_gh