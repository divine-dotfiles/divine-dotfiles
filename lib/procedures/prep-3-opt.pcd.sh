#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-3-opt
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Finish implementing three special queues
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Offers to install optional system utilities if they are not available and if 
#. at all possible
#

#>  d__run_sys_pkg_checks
#
## Driver function
#
## Returns:
#.  0 - Framework is ready to run
#.  1 - (script exit) Otherwise
#
d__run_sys_pkg_checks()
{
  # Fork depending on routine
  case $D__REQ_ROUTINE in
    attach) d__offer_git_and_friends;;
    plug)   d__offer_git_and_friends;;
    update) d__offer_git_and_friends;;
    cecf357ed9fed1037eb906633a4299ba)
      d__uninstall_all_offered_utils;;
    *)  return 0;;
  esac
}

#>  d__declare_intros
#
## Pre-declares thematical intro-panels. All of them are currently kept at 22 
#. characters wide.
#
d__declare_intros()
{
  readonly D__INTRO_SKIPD="$BOLD---$NORMAL ${BOLD}Skipped         $NORMAL :"

  readonly D__INTRO_BLANK='                      '
  readonly D__INTRO_DESCR="    ${BOLD}Description     $NORMAL :"
  
  readonly D__INTRO_CNF_N="    ${BOLD}Confirm         $NORMAL :"
  readonly D__INTRO_CNF_U="$RED$BOLD-?! Confirm         $NORMAL :"
  readonly D__INTRO_HALTN="$RED$REVERSE${BOLD}___$NORMAL $RED${BOLD}Halting         $NORMAL :"

  readonly D__INTRO_ATTNT="$YELLOW$BOLD-!- Atención        $NORMAL :"
  readonly D__INTRO_RBOOT="$MAGENTA$BOLD<-> Reboot needed   $NORMAL :"
  readonly D__INTRO_WARNG="$RED$BOLD!!! Warning         $NORMAL :"
  readonly D__INTRO_CRTCL="$RED$REVERSE${BOLD}x_x$NORMAL $RED${BOLD}Critical        $NORMAL :"

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
}

#>  d__check_github
#
## Checks whether the framework has the capacity to interact with Github (clone 
#. or download the repositories)
#
d__check_github()
{
  D__GH_METHOD=
  if git --version &>/dev/null; then D__GH_METHOD=g
  elif tar --version &>/dev/null; then
    if curl --version &>/dev/null; then D__GH_METHOD=c
    elif wget --version &>/dev/null; then D__GH_METHOD=w; fi
  fi
  readonly D__GH_METHOD
  if [ -z "$D__GH_METHOD" ]; then
    d__notify -lx -- 'Unable to work with Github repositories'
  fi
}

#>  d__offer_git_and_friends
#
## Offers various tools for working with git repositories
#
d__offer_git_and_friends()
{
  # Try to sell git as an essential tool for working with this framework
  if ! git --version &>/dev/null; then
    
    # Print warning
    dprint_alert 'Failed to detect git on current system' \
      -n 'Having git installed remedies a lot of unnecessary pain'

    # Make an offer
    if ! d__offer_system_pkg --exit-on-q git; then

      # Make announcement
      dprint_alert 'Proceeding without git'

      # Make checks and store statuses
      local curl_available wget_available tar_available
      curl --version &>/dev/null && curl_available=true || curl_available=false
      wget --version &>/dev/null && wget_available=true || wget_available=false
      tar --version &>/dev/null  && tar_available=true  || tar_available=false

      # Git is not available: check if alternative set of tools is available
      if ! ( ( $curl_available || $wget_available ) && $tar_available ); then

        # Alternative workflow is NOT available: attempt to make it so

        # Print warning
        dprint_alert 'Attempting to provide an alternative approach' \
          'to Github repositories'

        # Status variable with desired value
        local alt_flow_available=true

        # Check if both download tools are unavailable or just one
        if ! ( $curl_available || $wget_available ); then
          
          # No download tools: at least one is required
          d__offer_system_pkg --exit-on-q curl \
            || d__offer_system_pkg --exit-on-q wget \
            || alt_flow_available=false
        
        fi

        # If still hoping for alt workflow, check on tar
        if $alt_flow_available && ! $tar_available; then

          # No tar: it is required
          d__offer_system_pkg --exit-on-q tar || alt_flow_available=false

        fi

        # Check if made alt workflow available
        if ! $alt_flow_available; then

          # Verdict depends on routing
          case $D__REQ_ROUTINE in
            attach)
              # Fatal: no way to attach deployments without Github access
              dprint_failure \
                'Unable to attach deployments without tools for Github access'
              exit 1
              ;;
            plug)
              # Not fatal: there are other ways for Grail to be plugged
              dprint_alert 'Proceeding without tools for Github access'
              return 0
              ;;
            update)
              # Fatal: updates require some form of git access 
              dprint_failure \
                'Unable to update anything without git or alternative tools'
              exit 1
              ;;
          esac

        fi

      fi

    fi

  fi
}

#>  d__uninstall_all_offered_utils
#
## Removes previously offered and subsequently installed utils
#
d__uninstall_all_offered_utils()
{
  # Storage variable
  local installed_utils=() installed_util

  # Check if there are any utilities recorded
  if d__stash -r -s has installed_util; then

    # Check if $D__OS_PKGMGR is detected
    if [ -z "$D__OS_PKGMGR" ]; then

      # No option to uninstall: report and exit
      dprint_failure \
        "Unable to uninstall system utilities (no supported package manager)"
      exit 1

    fi

    # Read list from stash
    while read -r installed_util; do
      installed_utils+=( "$installed_util" )
    done < <( d__stash -r -s list installed_util )

  fi

  # Status variable
  local all_good=true anything_uninstalled=false

  # Remove Homebrew if installed
  d__uninstall_homebrew && anything_uninstalled=true || all_good=false

  # Iterate over installed utils
  for installed_util in "${installed_utils[@]}"; do

    # Announce un-installation
    dprint_debug "Uninstalling $installed_util"

    # Launch OS package manager with verbosity in mind
    if $D__OPT_QUIET; then

      # Launch quietly
      d__os_pkgmgr remove "$installed_util" &>/dev/null

    else

      # Launch normally, but re-paint output
      local d__ol
      d__os_pkgmgr remove "$installed_util" 2>&1 \
        | while IFS= read -r d__ol || [ -n "$d__ol" ]; do
        printf "${CYAN}==> %s${NORMAL}\n" "$d__ol"
      done

    fi

    # Check return status
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then

      # Announce success and unset stash variable
      dprint_success "Successfully uninstalled $installed_util"
      d__stash -r -s unset installed_util "$installed_util"
      anything_uninstalled=true

    else

      # Announce and remember failure
      dprint_failure "Failed to uninstall $installed_util"
      all_good=false
      
    fi

  # Done iterating over installed utils
  done

  # Exit with appropriate status
  if $all_good; then
    exit 0
  else
    $anything_uninstalled && exit 1 || exit 2
  fi
}

#>  d__uninstall_homebrew
#
## Removes previously offered and subsequently installed Homebrew
#
d__uninstall_homebrew()
{
  # Check if there is any work to do
  if ! d__stash -r -s has installed_homebrew; then
    # No record of Homebrew installation: silently return a-ok
    return 0
  fi

  # Announce start
  dprint_debug 'Uninstalling Homebrew'

  ## Homebrew has been previously auto-installed. This could only have 
  #. happened on macOS, so assume macOS environment.

  # Make temp dir for the uninstall script
  local tmpdir=$( mktemp -d )

  # Status variable
  local all_good=false

  # Download script into that directory
  if curl -fsSLo "$tmpdir/uninstall" \
    https://raw.githubusercontent.com/Homebrew/install/master/uninstall
  then

    # Make script executable
    if chmod +x "$tmpdir/uninstall"; then

      # Execute script with verbosity in mind
      if $D__OPT_QUIET; then

        # Run script quietly
        $tmpdir/uninstall --force &>/dev/null

      else

        # Run script normally, but re-paint output
        local d__ol
        $tmpdir/uninstall --force 2>&1 \
          | while IFS= read -r d__ol || [ -n "$d__ol" ]; do
            printf "${CYAN}==> %s${NORMAL}\n" "$d__ol"
          done

      fi

      # Report status
      if [ "${PIPESTATUS[0]}" -eq 0 ]; then

        # Announce, erase stash record, and save status
        dprint_success 'Successfully uninstalled Homebrew'
        d__stash -r -s unset installed_homebrew
        all_good=true

      else

        # Announce failure
        dprint_failure 'Failed to uninstall Homebrew'

      fi

    else

      # Announce failure
      dprint_failure \
        'Failed to set executable flag on Homebrew uninstallation script'

    fi

  else

    # Announce failure
    dprint_failure 'Failed to download Homebrew uninstallation script'

  fi

  # Remove temp dir
  rm -rf -- "$tmpdir"

  # Return appropriately
  $all_good && return 0 || return 1
}

d__run_sys_pkg_checks
unset -f d__run_sys_pkg_checks
d__declare_intros
unset -f d__declare_intros
d__check_github
unset -f d__check_github