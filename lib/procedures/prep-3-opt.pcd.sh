#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-3-opt
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Offers to install optional system utilities if they are not available and if 
#. at all possible.
#

# Driver function
d__run_opt_checks()
{
  d__offer_gh_access
  d__check_gh_access
}

#>  d__offer_gh_access
#
## Offers various tools for retrieving Github repositories.
#
d__offer_gh_access()
{
  # Check if git is there; offer it if not
  git --version &>/dev/null && return 0
  d__notify -l!t 'No Git' -- 'Failed to detect Git on current system' -n- \
    "${YELLOW}Having Git installed remedies a lot of unnecessary pain${NORMAL}"
  d__offer_pkg --or-quit git
  case $? in 0) return 0;; 1) :;; 2) exit 1;; esac

  # No git: check for downloading/untarring options
  local htar=false hcurl=false hwget=false
  tar --version &>/dev/null && htar=true
  curl --version &>/dev/null && hcurl=true
  wget --version &>/dev/null && hwget=true
  if $htar && ( $hcurl || $hwget ); then return 0; fi

  # No dl/untar: check if tar is available and offer it if not
  if ! $htar; then
    d__notify -l!t 'No tar' -- 'Failed to detect tar on current system' -n- \
      "${YELLOW}Having tar installed allows to download" \
      "archived Github repositories${NORMAL}"
    d__offer_pkg --or-quit tar
    case $? in 0) :;; 1) return 1;; 2) exit 1;; esac
  fi

  # Tar is available: check if curl/wget is available, offer them if not
  if ! $hcurl && ! $hwget; then
    if ! $hcurl; then
      d__notify -l!t 'No curl' -- 'Failed to detect curl on current system' \
        -n- "${YELLOW}Having curl installed allows to download" \
        "Github repositories${NORMAL}"
      d__offer_pkg --or-quit curl
      case $? in 0) hcurl=true;; 1) return 1;; 2) exit 1;; esac
    if ! $hcurl && ! $hwget; then
      d__notify -l!t 'No wget' -- 'Failed to detect wget on current system' \
        -n- "${YELLOW}Having wget installed allows to download" \
        "Github repositories${NORMAL}"
      d__offer_pkg --or-quit wget
      case $? in 0) :;; 1) return 1;; 2) exit 1;; esac
    fi
  fi

  # Down here its success
  return 0
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
  if git --version &>/dev/null; then D__GH_METHOD=g
  elif tar --version &>/dev/null; then
    if curl --version &>/dev/null; then D__GH_METHOD=c
    elif wget --version &>/dev/null; then D__GH_METHOD=w; fi
  fi
  readonly D__GH_METHOD
  if [ -z "$D__GH_METHOD" ]
  then d__notify -lx -- 'Unable to work with Github repositories'; return 1; fi
  return 0
}

d__run_opt_checks