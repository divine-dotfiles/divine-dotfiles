#!/usr/bin/env bash
#:title:        Divine Bash routine: usage
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.07.05
#:revremark:    Initial revision
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Shows usage note and exits the script
#

#> __show_usage_and_exit
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
__show_usage_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  local usage_tip script_name="$( basename -- "${BASH_SOURCE[0]}" )"
  read -r -d '' usage_tip << EOF
Usage: ${bold}${script_name}${normal} ${bold}i${normal}|${bold}install${normal}   [-ynqveif] [TASK]…  - Launch installation
   or: ${bold}${script_name}${normal} ${bold}r${normal}|${bold}remove${normal}    [-ynqveif] [TASK]…  - Launch removal
   or: ${bold}${script_name}${normal} ${bold}f${normal}|${bold}refresh${normal}   [-ynqveif] [TASK]…  - Launch removal, then installation
   or: ${bold}${script_name}${normal} ${bold}c${normal}|${bold}check${normal}     [-ynqvei]  [TASK]…  - Launch checking

   or: ${bold}${script_name}${normal} ${bold}a${normal}|${bold}attach${normal}    [-yn]      REPO…    - Add deployment(s) from Github repo
   or: ${bold}${script_name}${normal} ${bold}d${normal}|${bold}detach${normal}    [-yn]      REPO…    - Remove previously attached repo
   or: ${bold}${script_name}${normal} ${bold}p${normal}|${bold}plug${normal}      [-ynl]     REPO/DIR - Plug Grail from repo or dir
   or: ${bold}${script_name}${normal} ${bold}u${normal}|${bold}update${normal}    [-yn]      [TASK]…  - Update framework/deployments/Grail

   or: ${bold}${script_name}${normal} --version                       - Show script version
   or: ${bold}${script_name}${normal} -h|--help                       - Show help summary
EOF

  # Print usage tip
  printf >&2 '%s\n' "$usage_tip"
  exit 1
}

__show_usage_and_exit