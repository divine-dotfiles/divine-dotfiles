#!/usr/bin/env bash
#:title:        Divine Bash routine: version
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    9
#:revdate:      2019.09.01
#:revremark:    Tweak fmwk version output
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Shows version note and exits the script
#

#>  d__show_version_and_exit
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
d__show_version_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  # Try to extract current git commit
  local commit_sha
  if cd -- "$D__DIR_FMWK"; then
    commit_sha="$( git rev-parse --short HEAD 2>/dev/null )"
  fi
  [ -n "$commit_sha" ] && commit_sha=" ($commit_sha)"

  local version_msg
  read -r -d '' version_msg << EOF
${bold}${D__FMWK_NAME}${normal} ${D__FMWK_VERSION}${commit_sha}
<https://github.com/no-simpler/divine-dotfiles>
This is free software: you are free to change and redistribute it
There is NO WARRANTY, to the extent permitted by law

Written by ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>
EOF
  # Print version message
  printf '%s\n' "$version_msg"
  exit 0
}

d__show_version_and_exit