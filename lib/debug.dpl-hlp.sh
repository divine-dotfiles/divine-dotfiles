#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: debug
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.2-SNAPSHOT
#:revdate:      2019.05.13
#:revremark:    Initial revision
#:created_at:   2019.05.11

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions quick debug output
#

#>  debug_print CHUNKS…
#
## If verbose mode is activated, prints message in debug style. Otherwise, does 
#. nothing.
#
## Parameters:
#.  $@  - Chunks of debug message, to be separated from each other by single 
#.        space.
#.        Following special marks are also accepted:
#.          '-n'  - Insert new line. When used as first argument, inserts new
#.                  line before any other output.
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - After printing composed message
#.  1 - If $D_QUIET is set to 'true'
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed message, or as little as possible
#
debug_print()
{
  # Check if $D_QUIET is set to false
  [ "$D_QUIET" = true ] && return 1

  # Compose message from arguments and print it all on the go
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }; printf >&2 '%s' "${CYAN}==>"
  local chunk; for chunk; do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$chunk";; esac
  done; printf >&2 '%s\n' "${NORMAL}"; return 0
}