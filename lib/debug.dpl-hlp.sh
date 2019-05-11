#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: debug
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.11
#:revremark:    Initial revision
#:created_at:   2019.05.11

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions quick debug output
#

#>  debug_print MSG
#
## If verbose mode is activated, prints message in debug-style. Otherwise, does 
#. nothing.
#
## Parameters:
#.  $1  - Debug message to print
#
## Returns:
#.  0 - If successfully printed debug message
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - With $D_QUIET set to false — first argument, stylized.
#.            Otherwise, as little as possible
#
debug_print()
{
  # Check if $D_QUIET is set to false
  [ "$D_QUIET" = false ] || return 1

  # Get message
  local msg="$1"

  # Trim message
  msg="$( dtrim -- "$msg" )"

  # Check message length
  [ -n "$msg" ] || return 1

  # Print using dprint_msg
  dprint_msg --color "$CYAN" \
    --width-1 3 --width-2 86 \
    --effects-1 cb --effects-2 n \
    -- '==>' "$msg"
}