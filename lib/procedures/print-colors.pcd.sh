#!/usr/bin/env bash
#:title:        Divine Bash procedure: print-colors
#:kind:         global_var
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    5
#:revdate:      2019.08.08
#:revremark:    Improve colorization fallback; add it to fmwk (un)installation
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
#. globals, so they are still safe to use, but don't produce any effect.
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
#.  0 - Color variables are set
#.  1 - At least one color variable could not be set
#.  2 - No colorization has been done
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
d__declare_global_colors()
{
  # Check if terminal is connected
  if [ -t 1 ]; then

    # Terminal connected: check if tput can be used
    if type -P tput &>/dev/null \
      && tput sgr0 &>/dev/null \
      && [ -n "$( tput colors )" ] \
      && [ "$( tput colors )" -ge 8 ]
    then

      # tput is suitable: use it
      d__colorize_with_tput && return 0 || return 1

    else

      # Unsupported tput, such as on FreeBSD: use escape sequences instead
      d__colorize_with_escseq && return 0 || return 1

    fi

  else

    # Terminal not connected: don’t colorize
    d__do_not_colorize && return 2 || return 1

  fi
}

d__colorize_with_tput()
{
  # Status variable
  local all_good=true

  # Set foreground color variables, unless already set
  [ -z ${BLACK+isset} ] \
    && readonly   BLACK="$( tput setaf 0 )" || all_good=false
  [ -z ${RED+isset} ] \
    && readonly     RED="$( tput setaf 1 )" || all_good=false
  [ -z ${GREEN+isset} ] \
    && readonly   GREEN="$( tput setaf 2 )" || all_good=false
  [ -z ${YELLOW+isset} ] \
    && readonly  YELLOW="$( tput setaf 3 )" || all_good=false
  [ -z ${BLUE+isset} ] \
    && readonly    BLUE="$( tput setaf 4 )" || all_good=false
  [ -z ${MAGENTA+isset} ] \
    && readonly MAGENTA="$( tput setaf 5 )" || all_good=false
  [ -z ${CYAN+isset} ] \
    && readonly    CYAN="$( tput setaf 6 )" || all_good=false
  [ -z ${WHITE+isset} ] \
    && readonly   WHITE="$( tput setaf 7 )" || all_good=false

  # Set background color variables, unless already set
  [ -z ${BG_BLACK+isset} ] \
    && readonly   BG_BLACK="$( tput setab 0 )" || all_good=false
  [ -z ${BG_RED+isset} ] \
    && readonly     BG_RED="$( tput setab 1 )" || all_good=false
  [ -z ${BG_GREEN+isset} ] \
    && readonly   BG_GREEN="$( tput setab 2 )" || all_good=false
  [ -z ${BG_YELLOW+isset} ] \
    && readonly  BG_YELLOW="$( tput setab 3 )" || all_good=false
  [ -z ${BG_BLUE+isset} ] \
    && readonly    BG_BLUE="$( tput setab 4 )" || all_good=false
  [ -z ${BG_MAGENTA+isset} ] \
    && readonly BG_MAGENTA="$( tput setab 5 )" || all_good=false
  [ -z ${BG_CYAN+isset} ] \
    && readonly    BG_CYAN="$( tput setab 6 )" || all_good=false
  [ -z ${BG_WHITE+isset} ] \
    && readonly   BG_WHITE="$( tput setab 7 )" || all_good=false

  # Set effects variables, unless already set
  [ -z ${BOLD+isset} ] \
    && readonly     BOLD="$( tput bold )" || all_good=false
  [ -z ${DIM+isset} ] \
    && readonly      DIM="$( tput dim )"  || all_good=false
  [ -z ${ULINE+isset} ] \
    && readonly    ULINE="$( tput smul )" || all_good=false
  [ -z ${REVERSE+isset} ] \
    && readonly  REVERSE="$( tput rev )"  || all_good=false
  [ -z ${STANDOUT+isset} ] \
    && readonly STANDOUT="$( tput smso )" || all_good=false

  # Set reset variable, unless already set
  [ -z ${NORMAL+isset} ] \
    && readonly NORMAL="$( tput sgr0 )" || all_good=false

  # Return appropriately
  $all_good && return 0 || return 1
}

d__colorize_with_escseq()
{
  # Status variable
  local all_good=true

    # Set foreground color variables, unless already set
    [ -z ${BLACK+isset} ] \
      && readonly   BLACK="$( printf "\033[30m" )" || all_good=false
    [ -z ${RED+isset} ] \
      && readonly     RED="$( printf "\033[31m" )" || all_good=false
    [ -z ${GREEN+isset} ] \
      && readonly   GREEN="$( printf "\033[32m" )" || all_good=false
    [ -z ${YELLOW+isset} ] \
      && readonly  YELLOW="$( printf "\033[33m" )" || all_good=false
    [ -z ${BLUE+isset} ] \
      && readonly    BLUE="$( printf "\033[34m" )" || all_good=false
    [ -z ${MAGENTA+isset} ] \
      && readonly MAGENTA="$( printf "\033[35m" )" || all_good=false
    [ -z ${CYAN+isset} ] \
      && readonly    CYAN="$( printf "\033[36m" )" || all_good=false
    [ -z ${WHITE+isset} ] \
      && readonly   WHITE="$( printf "\033[97m" )" || all_good=false

    # Set background color variables, unless already set
    [ -z ${BG_BLACK+isset} ] \
      && readonly   BG_BLACK="$( printf "\033[40m" )" || all_good=false
    [ -z ${BG_RED+isset} ] \
      && readonly     BG_RED="$( printf "\033[41m" )" || all_good=false
    [ -z ${BG_GREEN+isset} ] \
      && readonly   BG_GREEN="$( printf "\033[42m" )" || all_good=false
    [ -z ${BG_YELLOW+isset} ] \
      && readonly  BG_YELLOW="$( printf "\033[43m" )" || all_good=false
    [ -z ${BG_BLUE+isset} ] \
      && readonly    BG_BLUE="$( printf "\033[44m" )" || all_good=false
    [ -z ${BG_MAGENTA+isset} ] \
      && readonly BG_MAGENTA="$( printf "\033[45m" )" || all_good=false
    [ -z ${BG_CYAN+isset} ] \
      && readonly    BG_CYAN="$( printf "\033[46m" )" || all_good=false
    [ -z ${BG_WHITE+isset} ] \
      && readonly   BG_WHITE="$( printf "\033[107m" )" || all_good=false

    # Set effects variables, unless already set
    [ -z ${BOLD+isset} ] \
      && readonly     BOLD="$( printf "\033[1m" )" || all_good=false
    [ -z ${DIM+isset} ] \
      && readonly      DIM="$( printf "\033[2m" )" || all_good=false
    [ -z ${ULINE+isset} ] \
      && readonly    ULINE="$( printf "\033[4m" )" || all_good=false
    [ -z ${REVERSE+isset} ] \
      && readonly  REVERSE="$( printf "\033[7m" )" || all_good=false
    [ -z ${STANDOUT+isset} ] \
      && readonly STANDOUT="$( printf "\033[5m" )" || all_good=false

    # Set reset variable, unless already set
    [ -z ${NORMAL+isset} ] \
      && readonly NORMAL="$( printf "\033[0m" )" || all_good=false

  # Return appropriately
  $all_good && return 0 || return 1
}

d__do_not_colorize()
{
  # Status variable
  local all_good=true

    # Set foreground color variables, unless already set
    [ -z ${BLACK+isset} ] \
      && readonly   BLACK='' || all_good=false
    [ -z ${RED+isset} ] \
      && readonly     RED='' || all_good=false
    [ -z ${GREEN+isset} ] \
      && readonly   GREEN='' || all_good=false
    [ -z ${YELLOW+isset} ] \
      && readonly  YELLOW='' || all_good=false
    [ -z ${BLUE+isset} ] \
      && readonly    BLUE='' || all_good=false
    [ -z ${MAGENTA+isset} ] \
      && readonly MAGENTA='' || all_good=false
    [ -z ${CYAN+isset} ] \
      && readonly    CYAN='' || all_good=false
    [ -z ${WHITE+isset} ] \
      && readonly   WHITE='' || all_good=false

    # Set background color variables, unless already set
    [ -z ${BG_BLACK+isset} ] \
      && readonly   BG_BLACK='' || all_good=false
    [ -z ${BG_RED+isset} ] \
      && readonly     BG_RED='' || all_good=false
    [ -z ${BG_GREEN+isset} ] \
      && readonly   BG_GREEN='' || all_good=false
    [ -z ${BG_YELLOW+isset} ] \
      && readonly  BG_YELLOW='' || all_good=false
    [ -z ${BG_BLUE+isset} ] \
      && readonly    BG_BLUE='' || all_good=false
    [ -z ${BG_MAGENTA+isset} ] \
      && readonly BG_MAGENTA='' || all_good=false
    [ -z ${BG_CYAN+isset} ] \
      && readonly    BG_CYAN='' || all_good=false
    [ -z ${BG_WHITE+isset} ] \
      && readonly   BG_WHITE='' || all_good=false

    # Set effects variables, unless already set
    [ -z ${BOLD+isset} ] \
      && readonly     BOLD='' || all_good=false
    [ -z ${DIM+isset} ] \
      && readonly      DIM='' || all_good=false
    [ -z ${ULINE+isset} ] \
      && readonly    ULINE='' || all_good=false
    [ -z ${REVERSE+isset} ] \
      && readonly  REVERSE='' || all_good=false
    [ -z ${STANDOUT+isset} ] \
      && readonly STANDOUT='' || all_good=false

    # Set reset variable, unless already set
    [ -z ${NORMAL+isset} ] \
      && readonly NORMAL='' || all_good=false

  # Return appropriately
  $all_good && return 0 || return 1
}

d__declare_global_colors
unset -f d__declare_global_colors
unset -f d__colorize_with_tput
unset -f d__colorize_with_escseq
unset -f d__do_not_colorize