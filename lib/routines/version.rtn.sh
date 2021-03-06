#!/usr/bin/env bash
#:title:        Divine Bash routine: version
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Shows version note and exits the script
#

# Marker and dependencies
readonly D__RTN_VERSION=loaded
d__load procedure print-colors

#>  d__rtn_version
#
## Shows framework version and exits with code 0
#
## Parameters:
#.  *none*
#
## Returns:
#.  0 - (script exit) Always
#
## Prints:
#.  stdout: Version message
#.  stderr: As little as possible
#
d__rtn_version()
{
  # Try to extract current git commit
  local commit_sha
  if pushd -- "$D__DIR_FMWK" &>/dev/null; then
    commit_sha="$( git rev-parse --short HEAD 2>/dev/null )"
    popd &>/dev/null
  fi
  [ -n "$commit_sha" ] && commit_sha=" $DIM($commit_sha)$NORMAL"

  local version_msg; read -r -d '' version_msg << EOF
${BOLD}${D__FMWK_NAME} ${D__FMWK_VERSION}${NORMAL}${commit_sha}
<https://github.com/divine-dotfiles/divine-dotfiles>
This is free software: you are free to change and redistribute it
There is NO WARRANTY, to the extent permitted by law

Written by ${BOLD}Grove Pyree${NORMAL} <grayarea@protonmail.ch>
EOF
  # Print version message
  printf >&2 '\n%s\n' "$version_msg"
  exit 0
}

d__rtn_version