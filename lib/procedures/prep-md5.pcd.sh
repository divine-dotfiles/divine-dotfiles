#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-md5
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Ensures current system has capability of calculating md5 checksum.
#

# Marker and dependencies
readonly D__PCD_PREP_MD5=loaded
d__load procedure prep-sys
d__load util workflow

d__pcd_prep_md5()
{
  # Settle on utility for generating md5 checksums across the fmwk
  if md5sum --version &>/dev/null; then
    d__notify -qqq -- "Using 'md5sum' utility to calculate md5 checksums"
    d__md5()
    {
      local md5; if [ "$1" = -s ]; then
        md5="$( printf %s "$2" | md5sum | awk '{print $1}' )"
      else md5="$( md5sum -- "$1" | awk '{print $1}' )"; fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      d__notify -lxt 'Critical failure' -- \
        "Failed to calculate a valid md5 checksum using 'md5sum'"
      return 1
    }
  elif md5 -r <<<test &>/dev/null; then
    d__notify -qqq -- "Using 'md5' utility to calculate md5 checksums"
    d__md5()
    {
      local md5; if [ "$1" = -s ]; then
        md5="$( md5 -rs "$2" | awk '{print $1}' )"
      else md5="$( md5 -r -- "$1" | awk '{print $1}' )"; fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      d__notify -lxt 'Critical failure' -- \
        "Failed to calculate a valid md5 checksum using 'md5 -r'"
      return 1
    }
  elif openssl version &>/dev/null; then
    d__notify -qqq -- "Using 'openssl' utility to calculate md5 checksums"
    d__md5()
    {
      local md5; if [ "$1" = -s ]; then
        md5="$( printf %s "$2" | openssl md5 | awk '{print $1}' )"
      else md5="$( openssl md5 -- "$1" | awk '{print $1}' )"; fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      d__notify -lxt 'Critical failure' -- \
        "Failed to calculate a valid md5 checksum using 'md5sum'"
      return 1
    }
  else
    d__notify -lxt 'Shutting down' -- 'No way to calculate md5 checksums'
    exit 1
  fi
}

d__pcd_prep_md5