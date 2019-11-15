#!/usr/bin/env bash
#:title:        Divine Bash procedure: offer-gh
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.17
#:revremark:    Split prep-gh in two
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Offers to install optional system utilities if they are not available and if 
#. at all possible.
#

# Marker and dependencies
readonly D__PCD_OFFER_GH=loaded
d__load util workflow
d__load util offer

# Driver function
d__pcd_offer_gh()
{
  d__offer_gh_access
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
    fi
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

d__pcd_offer_gh