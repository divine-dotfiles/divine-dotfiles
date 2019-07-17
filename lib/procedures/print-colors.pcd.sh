#!/usr/bin/env bash
#:title:        Divine Bash procedure: print-colors
#:kind:         global_var
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    2.0.0-RELEASE
#:revdate:      2019.03.22
#:revremark:    Lib ready for deployment
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Provides into the global scope a number of read-only global variables that 
#. can be used to colorize and add effects to terminal output.
#

#>  d__declare_global_colors
#
## Provides global read-only variables that allow delimiting portions of a text 
#. string to be colored or formatted using various effects. If the terminal 
#. does not support at least 8 colors, assigns empty strings to all the 
#. globals, so they are still safe to use, but don’t produce any effect.
#
## Requires:
#.  bash >=3.2
#.  tput
#.  tput colors >=8
#
## Parameters:
#.  *none*
#
## Provides into the global scope:
#.  $BLACK, $RED, $GREEN,
#.    $YELLOW, $BLUE, $MAGENTA,
#.    $CYAN, $WHITE                 - (read-only) Starts coloring text
#.  $BG_BLACK, $BG_RED, $BG_GREEN,
#.    $BG_YELLOW, $BG_BLUE, $BG_MAGENTA,
#.    $BG_CYAN, $BG_WHITE           - (read-only) Starts coloring background
#.  $BOLD, $DIM, $ULINE,
#.    $REVERSE, $STANDOUT           - (read-only) Starts formatting
#.  $NORMAL                         - (read-only) Stops all of the above
#
## Returns:
#.  0 - Success
#.  1 - Terminal does NOT support at least 8 colors
#.  2 - Some or all of variables are already set
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
d__declare_global_colors()
{
  # Storage variable
  local num_of_colors

  # Get number of colors supported by terminal
  if type -P tput &>/dev/null; then num_of_colors=$( tput colors ); fi

  # Status variable
  local return_code=0

  # Check if terminal supports 8+ colors
  if [ -n "$num_of_colors" ] && [ "$num_of_colors" -ge 8 ]; then

    # Coloring output

    # Set foreground color variables, unless already set
    [ -z ${BLACK+isset} ] \
      && readonly   BLACK="$( tput setaf 0 )" || return_code=2
    [ -z ${RED+isset} ] \
      && readonly     RED="$( tput setaf 1 )" || return_code=2
    [ -z ${GREEN+isset} ] \
      && readonly   GREEN="$( tput setaf 2 )" || return_code=2
    [ -z ${YELLOW+isset} ] \
      && readonly  YELLOW="$( tput setaf 3 )" || return_code=2
    [ -z ${BLUE+isset} ] \
      && readonly    BLUE="$( tput setaf 4 )" || return_code=2
    [ -z ${MAGENTA+isset} ] \
      && readonly MAGENTA="$( tput setaf 5 )" || return_code=2
    [ -z ${CYAN+isset} ] \
      && readonly    CYAN="$( tput setaf 6 )" || return_code=2
    [ -z ${WHITE+isset} ] \
      && readonly   WHITE="$( tput setaf 7 )" || return_code=2

    # Set background color variables, unless already set
    [ -z ${BG_BLACK+isset} ] \
      && readonly   BG_BLACK="$( tput setab 0 )" || return_code=2
    [ -z ${BG_RED+isset} ] \
      && readonly     BG_RED="$( tput setab 1 )" || return_code=2
    [ -z ${BG_GREEN+isset} ] \
      && readonly   BG_GREEN="$( tput setab 2 )" || return_code=2
    [ -z ${BG_YELLOW+isset} ] \
      && readonly  BG_YELLOW="$( tput setab 3 )" || return_code=2
    [ -z ${BG_BLUE+isset} ] \
      && readonly    BG_BLUE="$( tput setab 4 )" || return_code=2
    [ -z ${BG_MAGENTA+isset} ] \
      && readonly BG_MAGENTA="$( tput setab 5 )" || return_code=2
    [ -z ${BG_CYAN+isset} ] \
      && readonly    BG_CYAN="$( tput setab 6 )" || return_code=2
    [ -z ${BG_WHITE+isset} ] \
      && readonly   BG_WHITE="$( tput setab 7 )" || return_code=2

    # Set effects variables, unless already set
    [ -z ${BOLD+isset} ] \
      && readonly     BOLD="$( tput bold )" || return_code=2
    [ -z ${DIM+isset} ] \
      && readonly      DIM="$( tput dim )"  || return_code=2
    [ -z ${ULINE+isset} ] \
      && readonly    ULINE="$( tput smul )" || return_code=2
    [ -z ${REVERSE+isset} ] \
      && readonly  REVERSE="$( tput rev )"  || return_code=2
    [ -z ${STANDOUT+isset} ] \
      && readonly STANDOUT="$( tput smso )" || return_code=2

    # Set reset variable, unless already set
    [ -z ${NORMAL+isset} ] \
      && readonly NORMAL="$( tput sgr0 )" || return_code=2

  else

    # Not coloring output

    # Store appropriate return code
    return_code=1

    # Set foreground color variables, unless already set
    [ -z ${BLACK+isset} ] \
      && readonly   BLACK='' || return_code=2
    [ -z ${RED+isset} ] \
      && readonly     RED='' || return_code=2
    [ -z ${GREEN+isset} ] \
      && readonly   GREEN='' || return_code=2
    [ -z ${YELLOW+isset} ] \
      && readonly  YELLOW='' || return_code=2
    [ -z ${BLUE+isset} ] \
      && readonly    BLUE='' || return_code=2
    [ -z ${MAGENTA+isset} ] \
      && readonly MAGENTA='' || return_code=2
    [ -z ${CYAN+isset} ] \
      && readonly    CYAN='' || return_code=2
    [ -z ${WHITE+isset} ] \
      && readonly   WHITE='' || return_code=2

    # Set background color variables, unless already set
    [ -z ${BG_BLACK+isset} ] \
      && readonly   BG_BLACK='' || return_code=2
    [ -z ${BG_RED+isset} ] \
      && readonly     BG_RED='' || return_code=2
    [ -z ${BG_GREEN+isset} ] \
      && readonly   BG_GREEN='' || return_code=2
    [ -z ${BG_YELLOW+isset} ] \
      && readonly  BG_YELLOW='' || return_code=2
    [ -z ${BG_BLUE+isset} ] \
      && readonly    BG_BLUE='' || return_code=2
    [ -z ${BG_MAGENTA+isset} ] \
      && readonly BG_MAGENTA='' || return_code=2
    [ -z ${BG_CYAN+isset} ] \
      && readonly    BG_CYAN='' || return_code=2
    [ -z ${BG_WHITE+isset} ] \
      && readonly   BG_WHITE='' || return_code=2

    # Set effects variables, unless already set
    [ -z ${BOLD+isset} ] \
      && readonly     BOLD='' || return_code=2
    [ -z ${DIM+isset} ] \
      && readonly      DIM='' || return_code=2
    [ -z ${ULINE+isset} ] \
      && readonly    ULINE='' || return_code=2
    [ -z ${REVERSE+isset} ] \
      && readonly  REVERSE='' || return_code=2
    [ -z ${STANDOUT+isset} ] \
      && readonly STANDOUT='' || return_code=2

    # Set reset variable, unless already set
    [ -z ${NORMAL+isset} ] \
      && readonly NORMAL='' || return_code=2

  fi

  # Report
  return $return_code
}

d__declare_global_colors
unset -f d__declare_global_colors