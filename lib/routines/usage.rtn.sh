#!/usr/bin/env bash
#:title:        Divine Bash routine: usage
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    9
#:revdate:      2019.08.05
#:revremark:    script version -> framework version
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Shows usage note and exits the script
#

#> d__show_usage_and_exit
#
## Shows usage tip end exits with code 1
#
## Parameters:
#.  *none*
#
## Returns:
#.  1 - (script exit) Always
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Usage tip
#
d__show_usage_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  local usage_tip
  read -r -d '' usage_tip << EOF
Usage: ${bold}${D__EXEC_NAME}${normal} ${bold}i${normal}|${bold}install${normal}   [-ynqvewf] [TASK]…  - Install deployment(s)
   or: ${bold}${D__EXEC_NAME}${normal} ${bold}r${normal}|${bold}remove${normal}    [-ynqvewf] [TASK]…  - Uninstall deployment(s)
   or: ${bold}${D__EXEC_NAME}${normal} ${bold}c${normal}|${bold}check${normal}     [-ynqvew]  [TASK]…  - Check status of deployment(s)

   or: ${bold}${D__EXEC_NAME}${normal} ${bold}a${normal}|${bold}attach${normal}    [-yn]      REPO…    - Import deployment(s) from Github
   or: ${bold}${D__EXEC_NAME}${normal} ${bold}d${normal}|${bold}detach${normal}    [-yn]      REPO…    - Discard previously attached repo
   or: ${bold}${D__EXEC_NAME}${normal} ${bold}p${normal}|${bold}plug${normal}      [-ynl]     REPO/DIR - Plug Grail from repo or local dir
   or: ${bold}${D__EXEC_NAME}${normal} ${bold}u${normal}|${bold}update${normal}    [-yn]      [TASK]…  - Update framework/deployments/Grail

   or: ${bold}${D__EXEC_NAME}${normal} --version                       - Show framework version
   or: ${bold}${D__EXEC_NAME}${normal} -h|--help                       - Show help summary
EOF

  # Print usage tip
  printf >&2 '%s\n' "$usage_tip"
  exit 1
}

d__show_usage_and_exit