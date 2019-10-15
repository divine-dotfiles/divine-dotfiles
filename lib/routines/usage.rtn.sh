#!/usr/bin/env bash
#:title:        Divine Bash routine: usage
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Shows usage note and exits the script
#

# Marker and dependencies
readonly D__RTN_USAGE=loaded
d__load procedure print-colors

#>  d__rtn_usage
#
## Shows usage tip end exits with code 1
#
## Parameters:
#.  *none*
#
## Returns:
#.  1 - (script exit) Always
#
d__rtn_usage()
{
  local usage_tip; read -r -d '' usage_tip << EOF
${BOLD}${D__FMWK_NAME}${NORMAL} usage:

  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}c${NORMAL}|${BOLD}check${NORMAL}   [-ynqvew]  [-b BUNDLE]... [TASK]...  - Check dpls
  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}i${NORMAL}|${BOLD}install${NORMAL} [-ynqvewf] [-b BUNDLE]... [TASK]...  - Install dpls
  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}r${NORMAL}|${BOLD}remove${NORMAL}  [-ynqvewf] [-b BUNDLE]... [TASK]...  - Uninstall dpls

  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}a${NORMAL}|${BOLD}attach${NORMAL}  [-yn]   REPO...                      - Attach bundles
  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}d${NORMAL}|${BOLD}detach${NORMAL}  [-yn]   REPO...                      - Detach bundles
  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}p${NORMAL}|${BOLD}plug${NORMAL}    [-ynl]  REPO/DIR...                  - Plug Grail
  ${BOLD}${D__EXEC_NAME}${NORMAL} ${BOLD}u${NORMAL}|${BOLD}update${NORMAL}  [-yn]   [fmwk|dpls|grail]...         - Update parts

  ${BOLD}${D__EXEC_NAME}${NORMAL} --version                                      - Show version
  ${BOLD}${D__EXEC_NAME}${NORMAL} -h|--help                                      - Show help
EOF

  # Print usage tip
  printf >&2 '%s\n' "$usage_tip"
  exit 1
}

d__rtn_usage