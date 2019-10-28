#!/usr/bin/env bash
#:title:        Divine Bash procedure: print-colors
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.28
#:revremark:    Check if pkg is available before handling it via pkgmgr
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Provides into the global scope a number of read-only global variables that 
#. can be used to colorize and add effects to terminal output.
#

# Marker and dependencies
readonly D__PCD_PRINT_COLORS=loaded

#>  d__pcd_print_colors
#
## This function populates read-only global variables with invisible special 
#. values, each of which changes visual formatting of the terminal output. 
#. Eight text colors and a handful of formatting effects are included. If the 
#. terminal does not appear to be connected, the globals are instead populated 
#. with empty values.
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
#.  0 - Color variables set.
#.  1 - Colorization omitted.
#
d__pcd_print_colors()
{
  # Colorize terminal if possible; define intros
  local clr=false
  if [ -t 1 ]; then
    if type -P tput &>/dev/null && tput sgr0 &>/dev/null \
      && [ -n "$( tput colors )" ] && [ "$( tput colors )" -ge 8 ]
    then d__colorize_with_tput; clr=true
    else d__colorize_with_escseq; clr=true; fi
  else d__do_not_colorize; fi
  d__define_intros; $clr && return 0 || return 1
}

d__colorize_with_tput()
{
  # Fire debug message
  if [ -n "$D__OPT_VERBOSITY" ] && (($D__OPT_VERBOSITY>2)); then
    printf >&2 '%s %s\n' "$(tput setaf 6)==>" \
      "Coloring terminal output with tput$(tput sgr0)"
  fi

  # Set foreground color variables
  readonly   BLACK="$( tput setaf 0 )"
  readonly     RED="$( tput setaf 1 )"
  readonly   GREEN="$( tput setaf 2 )"
  readonly  YELLOW="$( tput setaf 3 )"
  readonly    BLUE="$( tput setaf 4 )"
  readonly MAGENTA="$( tput setaf 5 )"
  readonly    CYAN="$( tput setaf 6 )"
  readonly   WHITE="$( tput setaf 7 )"

  # Set background color variables
  readonly   BG_BLACK="$( tput setab 0 )"
  readonly     BG_RED="$( tput setab 1 )"
  readonly   BG_GREEN="$( tput setab 2 )"
  readonly  BG_YELLOW="$( tput setab 3 )"
  readonly    BG_BLUE="$( tput setab 4 )"
  readonly BG_MAGENTA="$( tput setab 5 )"
  readonly    BG_CYAN="$( tput setab 6 )"
  readonly   BG_WHITE="$( tput setab 7 )"

  # Set effects variables
  readonly     BOLD="$( tput bold )"
  readonly      DIM="$( tput dim )"
  readonly    ULINE="$( tput smul )"
  readonly  REVERSE="$( tput rev )"
  readonly STANDOUT="$( tput smso )"

  # Set reset variable
  readonly   NORMAL="$( tput sgr0 )"

  return 0
}

d__colorize_with_escseq()
{
  # Fire debug message
  if [ -n "$D__OPT_VERBOSITY" ] && (($D__OPT_VERBOSITY>2)); then
    printf >&2 '\033[36m%s %s\033[0m\n' \
      '==> Coloring terminal output with esc sequences'
  fi

  # Set foreground color variables
  readonly   BLACK="$( printf '\033[30m' )"
  readonly     RED="$( printf '\033[31m' )"
  readonly   GREEN="$( printf '\033[32m' )"
  readonly  YELLOW="$( printf '\033[33m' )"
  readonly    BLUE="$( printf '\033[34m' )"
  readonly MAGENTA="$( printf '\033[35m' )"
  readonly    CYAN="$( printf '\033[36m' )"
  readonly   WHITE="$( printf '\033[97m' )"

  # Set background color variables
  readonly   BG_BLACK="$( printf '\033[40m' )"
  readonly     BG_RED="$( printf '\033[41m' )"
  readonly   BG_GREEN="$( printf '\033[42m' )"
  readonly  BG_YELLOW="$( printf '\033[43m' )"
  readonly    BG_BLUE="$( printf '\033[44m' )"
  readonly BG_MAGENTA="$( printf '\033[45m' )"
  readonly    BG_CYAN="$( printf '\033[46m' )"
  readonly   BG_WHITE="$( printf '\033[107m' )"

  # Set effects variables
  readonly     BOLD="$( printf '\033[1m' )"
  readonly      DIM="$( printf '\033[2m' )"
  readonly    ULINE="$( printf '\033[4m' )"
  readonly  REVERSE="$( printf '\033[7m' )"
  readonly STANDOUT="$( printf '\033[5m' )"

  # Set reset variable
  readonly   NORMAL="$( printf '\033[0m' )"

  return 0
}

d__do_not_colorize()
{
  # Fire debug message
  [ -n "$D__OPT_VERBOSITY" ] && (($D__OPT_VERBOSITY>2)) \
    && printf >&2 '%s\n' '==> Omitting coloring of terminal output'

  # Set foreground color variables
  readonly BLACK= RED= GREEN= YELLOW= BLUE= MAGENTA= CYAN= WHITE=

  # Set background color variables
  readonly BG_BLACK= BG_RED= BG_GREEN= BG_YELLOW= BG_BLUE= BG_MAGENTA=
  readonly BG_CYAN= BG_WHITE=

  # Set effects and reset variables
  readonly BOLD= DIM= ULINE= REVERSE= STANDOUT= NORMAL=

  return 0
}

#>  d__define_intros
#
## Pre-declares thematical intro-panels. All of them are currently kept at 22 
#. characters wide.
#
d__define_intros()
{
  readonly D__INTRO_SKIPD="$BOLD---$NORMAL ${BOLD}Skipped         $NORMAL :"

  readonly D__INTRO_BLANK='                      '
  readonly D__INTRO_DESCR="    ${BOLD}Description     $NORMAL :"
  
  readonly D__INTRO_CNF_N="    ${BOLD}Confirm         $NORMAL :"
  readonly D__INTRO_CNF_U="$RED$BOLD-?! Confirm         $NORMAL :"
  readonly D__INTRO_HALTN="$RED$REVERSE${BOLD}___$NORMAL $RED${BOLD}Halting         $NORMAL :"

  readonly D__INTRO_ATTNT="$YELLOW$BOLD-!- Atención        $NORMAL :"
  readonly D__INTRO_RBOOT="$MAGENTA$BOLD<-> Help wanted     $NORMAL :"
  readonly D__INTRO_WARNG="$RED$BOLD!!! Warning         $NORMAL :"
  readonly D__INTRO_CRTCL="$RED$REVERSE${BOLD}x_x$NORMAL $RED${BOLD}Critical        $NORMAL :"
  readonly D__INTRO_SUCCS="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Success         $NORMAL :"
  readonly D__INTRO_FAILR="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failure         $NORMAL :"
  readonly D__INTRO_NOTAV="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Not available   $NORMAL :"

  readonly D__INTRO_CHK_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Checking        $NORMAL :"
  readonly D__INTRO_CHK_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-checking  $NORMAL :"
  readonly D__INTRO_CHK_S="$BOLD---$NORMAL ${BOLD}Skipped checking$NORMAL :"
  readonly D__INTRO_CHK_0="$BLUE$REVERSE$BOLD???$NORMAL ${BOLD}Unknown         $NORMAL :"
  readonly D__INTRO_CHK_1="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Installed       $NORMAL :"
  readonly D__INTRO_CHK_2="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Not installed   $NORMAL :"
  readonly D__INTRO_CHK_3="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Irrelevant      $NORMAL :"
  readonly D__INTRO_CHK_4="$GREEN$REVERSE${BOLD}vv$NORMAL$YELLOW${BOLD}x$NORMAL ${BOLD}Partly installed$NORMAL :"
  readonly D__INTRO_CHK_5="$GREEN$REVERSE${BOLD}v??$NORMAL ${BOLD}Likely installed$NORMAL :"
  readonly D__INTRO_CHK_6="$RED$REVERSE${BOLD}x_x$NORMAL $RED${BOLD}Manually removed$NORMAL :"
  readonly D__INTRO_CHK_7="$MAGENTA$REVERSE${BOLD}vvv$NORMAL ${BOLD}Installed by usr$NORMAL :"
  readonly D__INTRO_CHK_8="$MAGENTA$REVERSE${BOLD}vv$NORMAL$MAGENTA${BOLD}x$NORMAL ${BOLD}Prt. ins. by usr$NORMAL :"
  readonly D__INTRO_CHK_9="$RED$REVERSE${BOLD}x??$NORMAL ${BOLD}Likely not instd$NORMAL :"

  readonly D__INTRO_INS_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Installing      $NORMAL :"
  readonly D__INTRO_INS_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-installing$NORMAL :"
  readonly D__INTRO_INS_S="$BOLD---$NORMAL ${BOLD}Skipped inst.   $NORMAL :"
  readonly D__INTRO_INS_A="$BOLD---$NORMAL ${BOLD}Already inst.   $NORMAL :"
  readonly D__INTRO_INS_0="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Installed       $NORMAL :"
  readonly D__INTRO_INS_1="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failed to inst. $NORMAL :"
  readonly D__INTRO_INS_2="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Refused to inst.$NORMAL :"
  readonly D__INTRO_INS_3="$GREEN$REVERSE${BOLD}vv$NORMAL$YELLOW${BOLD}x$NORMAL ${BOLD}Partly installed$NORMAL :"

  readonly D__INTRO_RMV_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Removing        $NORMAL :"
  readonly D__INTRO_RMV_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-removing  $NORMAL :"
  readonly D__INTRO_RMV_S="$BOLD---$NORMAL ${BOLD}Skipped removing$NORMAL :"
  readonly D__INTRO_RMV_A="$BOLD---$NORMAL ${BOLD}Already removed $NORMAL :"
  readonly D__INTRO_RMV_0="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Removed         $NORMAL :"
  readonly D__INTRO_RMV_1="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failed to remove$NORMAL :"
  readonly D__INTRO_RMV_2="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Refused to rmv. $NORMAL :"
  readonly D__INTRO_RMV_3="$GREEN$REVERSE${BOLD}vv$NORMAL$YELLOW${BOLD}x$NORMAL ${BOLD}Partly removed  $NORMAL :"

  readonly D__INTRO_UPD_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Updating        $NORMAL :"
  readonly D__INTRO_UPD_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-updating  $NORMAL :"
  readonly D__INTRO_UPD_S="$BOLD---$NORMAL ${BOLD}Skipped updating$NORMAL :"
  readonly D__INTRO_UPD_0="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Updated         $NORMAL :"
  readonly D__INTRO_UPD_1="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failed to update$NORMAL :"
  readonly D__INTRO_UPD_2="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Refused to upd. $NORMAL :"
  readonly D__INTRO_UPD_3="$GREEN$REVERSE${BOLD}vv$NORMAL$YELLOW${BOLD}x$NORMAL ${BOLD}Partly updated  $NORMAL :"

  readonly D__INTRO_QCH_N="$CYAN$BOLD>>> Checking        $NORMAL $CYAN:"
  readonly D__INTRO_QCH_F="$CYAN$BOLD>>> Force-checking  $NORMAL $CYAN:"
  readonly D__INTRO_QCH_S="$CYAN$BOLD--- Skipped checking$NORMAL $CYAN:"
  readonly D__INTRO_QCH_0="$CYAN$REVERSE$BOLD???$NORMAL $CYAN${BOLD}Unknown         $NORMAL $CYAN:"
  readonly D__INTRO_QCH_1="$CYAN$REVERSE${BOLD}vvv$NORMAL $CYAN${BOLD}Installed       $NORMAL $CYAN:"
  readonly D__INTRO_QCH_2="$CYAN$REVERSE${BOLD}xxx$NORMAL $CYAN${BOLD}Not installed   $NORMAL $CYAN:"
  readonly D__INTRO_QCH_3="$CYAN$REVERSE$BOLD~~~$NORMAL $CYAN${BOLD}Irrelevant      $NORMAL $CYAN:"
  readonly D__INTRO_QCH_4="$CYAN$REVERSE${BOLD}vv$NORMAL$CYAN${BOLD}x Partly installed$NORMAL $CYAN:"
  readonly D__INTRO_QCH_5="$CYAN$REVERSE${BOLD}v??$NORMAL $CYAN${BOLD}Likely installed$NORMAL $CYAN:"
  readonly D__INTRO_QCH_6="$CYAN$REVERSE${BOLD}x_x$NORMAL $CYAN${BOLD}Manually removed$NORMAL $CYAN:"
  readonly D__INTRO_QCH_7="$CYAN$REVERSE${BOLD}vvv$NORMAL $CYAN${BOLD}Installed by usr$NORMAL $CYAN:"
  readonly D__INTRO_QCH_8="$CYAN$REVERSE${BOLD}vv$NORMAL$CYAN${BOLD}x Prt. ins. by usr$NORMAL $CYAN:"
  readonly D__INTRO_QCH_9="$CYAN$REVERSE${BOLD}x??$NORMAL $CYAN${BOLD}Likely not instd$NORMAL $CYAN:"

  readonly D__INTRO_QIN_N="$CYAN$BOLD>>> Installing      $NORMAL $CYAN:"
  readonly D__INTRO_QIN_F="$CYAN$BOLD>>> Force-installing$NORMAL $CYAN:"
  readonly D__INTRO_QIN_S="$CYAN$BOLD--- Skipped inst.   $NORMAL $CYAN:"
  readonly D__INTRO_QIN_A="$CYAN$BOLD--- Already inst.   $NORMAL $CYAN:"
  readonly D__INTRO_QIN_0="$CYAN$REVERSE${BOLD}vvv$NORMAL $CYAN${BOLD}Installed       $NORMAL $CYAN:"
  readonly D__INTRO_QIN_1="$CYAN$REVERSE${BOLD}xxx$NORMAL $CYAN${BOLD}Failed to inst. $NORMAL $CYAN:"
  readonly D__INTRO_QIN_2="$CYAN$REVERSE$BOLD~~~$NORMAL $CYAN${BOLD}Refused to inst.$NORMAL $CYAN:"
  readonly D__INTRO_QIN_3="$CYAN$REVERSE${BOLD}vv$NORMAL$CYAN${BOLD}x Partly installed$NORMAL $CYAN:"

  readonly D__INTRO_QRM_N="$CYAN$BOLD>>> Removing        $NORMAL $CYAN:"
  readonly D__INTRO_QRM_F="$CYAN$BOLD>>> Force-removing  $NORMAL $CYAN:"
  readonly D__INTRO_QRM_S="$CYAN$BOLD--- Skipped removing$NORMAL $CYAN:"
  readonly D__INTRO_QRM_A="$CYAN$BOLD--- Already removed $NORMAL $CYAN:"
  readonly D__INTRO_QRM_0="$CYAN$REVERSE${BOLD}vvv$NORMAL $CYAN${BOLD}Removed         $NORMAL $CYAN:"
  readonly D__INTRO_QRM_1="$CYAN$REVERSE${BOLD}xxx$NORMAL $CYAN${BOLD}Failed to remove$NORMAL $CYAN:"
  readonly D__INTRO_QRM_2="$CYAN$REVERSE$BOLD~~~$NORMAL $CYAN${BOLD}Refused to rmv. $NORMAL $CYAN:"
  readonly D__INTRO_QRM_3="$CYAN$REVERSE${BOLD}vv$NORMAL$CYAN${BOLD}x Partly removed  $NORMAL $CYAN:"

  readonly D__INTRO_ATC_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Attaching       $NORMAL :"
  readonly D__INTRO_ATC_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-attaching $NORMAL :"
  readonly D__INTRO_ATC_S="$BOLD---$NORMAL ${BOLD}Skipped attching$NORMAL :"
  readonly D__INTRO_ATC_0="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Attached        $NORMAL :"
  readonly D__INTRO_ATC_1="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failed to attach$NORMAL :"
  readonly D__INTRO_ATC_2="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Refused to attch$NORMAL :"

  readonly D__INTRO_DTC_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Detaching       $NORMAL :"
  readonly D__INTRO_DTC_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-detaching $NORMAL :"
  readonly D__INTRO_DTC_S="$BOLD---$NORMAL ${BOLD}Skipped detching$NORMAL :"
  readonly D__INTRO_DTC_0="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Detached        $NORMAL :"
  readonly D__INTRO_DTC_1="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failed to detach$NORMAL :"
  readonly D__INTRO_DTC_2="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Refused to detch$NORMAL :"

  readonly D__INTRO_PLG_N="$YELLOW$BOLD>>>$NORMAL ${BOLD}Plugging        $NORMAL :"
  readonly D__INTRO_PLG_F="$YELLOW$BOLD>>>$NORMAL ${BOLD}Force-plugging  $NORMAL :"
  readonly D__INTRO_PLG_S="$BOLD---$NORMAL ${BOLD}Skipped plugging$NORMAL :"
  readonly D__INTRO_PLG_0="$GREEN$REVERSE${BOLD}vvv$NORMAL ${BOLD}Plugged         $NORMAL :"
  readonly D__INTRO_PLG_1="$RED$REVERSE${BOLD}xxx$NORMAL ${BOLD}Failed to plug  $NORMAL :"
  readonly D__INTRO_PLG_2="$WHITE$REVERSE$BOLD~~~$NORMAL ${BOLD}Refused to plug $NORMAL :"
}

d__pcd_print_colors