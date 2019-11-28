#!/usr/bin/env bash
#:title:        Divine Bash routine: remove
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.28
#:revremark:    Return informative code from install/remove routines
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Removes packages and deployments as requested
#

# Marker and dependencies
readonly D__RTN_REMOVE=loaded
d__load util workflow
d__load util stash
d__load util offer
d__load util git
d__load util backup
d__load util assets
d__load util items
d__load helper multitask
d__load helper queue
d__load helper link-queue
d__load helper copy-queue
d__load helper gh-queue
d__load helper inject
d__load procedure prep-stash
d__load procedure offer-gh
d__load procedure check-gh
d__load procedure sync-bundles
d__load procedure assemble

#>  d__rtn_remove
#
## Performs removal routine, in reverse installation order
#
# For each priority level, from largest to smallest, separately:
#.  * Removes deployments in reverse installation order
#.  * Removes packages in reversed order of appearance in Divinefile
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
d__rtn_remove()
{
  $D__OPT_OBLITERATE && d__confirm_obliteration

  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'remove' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Undoing' Divine intervention"
  else
    d__announce -v -- 'Undoing Divine intervention'
  fi

  # Update packages if touching them at all
  # (This is normally required even for removal)
  d__load procedure update-pkgs

  # Storage variables; set up proxy file for statuses
  local d__prtya=(${!D__WKLD[@]}) d__prty d__prtys d__i
  local d__anys=false d__anyf=false d__anyn=false d__prxf
  d__prxf="$(mktemp)"

  # Iterate over taken priorities
  for ((d__i=${#d__prtya[@]}-1;d__i>=0;--d__i)); do

    # Extract priority; switch context and compose priority string
    d__prty="${d__prtya[$d__i]}"
    d__context -n -- push "Removing at priority '$d__prty'"
    d__prtys="$( printf "(%${D__WKLD_MAX_PRTY_LEN}d)" "$d__prty" )"

    # Remove deployments, if asked to; check if returned special status 
    d___remove_dpls; if [ $? -eq 1 ]; then
      printf >&2 '\n'
      d__announce -! -- 'Halting Divine intervention'
      d__context -- lop
      return 1
    fi

    # Remove packages, if asked to
    d___remove_pkgs

    # Pop the priority
    d__context -n -- pop

  done

  # Remove proxy file
  rm -f -- $d__prxf

  # Announce completion and return appropriately
  printf >&2 '\n'
  local d__rrtc=0
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Successfully 'undid' Divine intervention"
  else
    if $d__anys && $d__anyf && $d__anyn; then
      d__rrtc=1
      d__announce -x -- 'Partly undid Divine intervention'
    elif $d__anys && $d__anyf; then
      d__rrtc=1
      d__announce -x -- 'Partly undid Divine intervention'
    elif $d__anys && $d__anyn; then
      d__rrtc=2
      d__announce -! -- 'Partly undid Divine intervention'
    elif $d__anyf && $d__anyn; then
      d__rrtc=1
      d__announce -! -- 'Partly undid Divine intervention'
    elif $d__anys; then
      d__rrtc=0
      d__announce -v -- 'Successfully undid Divine intervention'
    elif $d__anyf; then
      d__rrtc=1
      d__announce -x -- 'Failed to undo Divine intervention'
    elif $d__anyn; then
      d__rrtc=2
      d__announce -! -- 'Refused to undo Divine intervention'
    fi
  fi
  d__context -- lop
  return $d__rrtc
}

#>  d___remove_pkgs
#
## INTERNAL USE ONLY
#
## For the given priority level, removes packages, one by one, using their 
#. names, which have been previously assembled in $D__WKLD_PKGS array. 
#. Operates in reversed installation order.
#
## Local variables that need to be set in the calling context:
#.  $d__prty    - The priority at which to conduct processing.
#.  $d__prtys   - The priority as a fixed-width string composed for printing, 
#.                e.g. '( 300)'.
#
## Returns:
#.  0 - Always
#
d___remove_pkgs()
{
  # Return if empty list of packages at the given priority
  [ -z ${D__WKLD_PKGS[$d__prty]+isset} ] && return 0

  # Storage variables
  local d__plq d__pkga_n d__pkga_b d__pkga_f d__pkg_n d__pkg_b d__pkg_f d__i
  local d__aamd d__frcd d__shr d__shs d__prtc=

  # Split package names on newline
  IFS=$'\n' read -r -d '' -a d__pkga_n <<<"${D__WKLD_PKGS[$d__prty]}"
  if [ "$D__OPT_ANSWER" != false ]; then
    IFS=$'\n' read -r -d '' -a d__pkga_b <<<"${D__WKLD_PKG_BITS[$d__prty]}"
    IFS=$'\n' read -r -d '' -a d__pkga_f <<<"${D__WKLD_PKG_FLAGS[$d__prty]}"
  fi

  # Iterate over package names in reverse order
  for ((d__i=${#d__pkga_n[@]}-1;d__i>=0;--d__i)); do

    # Process status from previous iteration; set default value
    case $d__prtc in
      0)  d__anys=true;;
      1)  d__anyf=true;;
      2)  d__anyn=true;;
      *)  :;;
    esac
    d__prtc=1

    # Print a separating empty line; extract pkg name; compose task name
    printf >&2 '\n'; d__pkg_n="${d__pkga_n[$d__i]}"
    d__plq="$d__prtys Package '$BOLD$d__pkg_n$NORMAL'"

    # Early exit for dry runs
    if [ "$D__OPT_ANSWER" = false ]; then
      printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"; continue
    fi

    # Print intro
    printf >&2 '%s %s\n' "$D__INTRO_RMV_N" "$d__plq"

    # Extract the rest of the data
    d__pkg_b="${d__pkga_b[$d__i]}"
    d__pkg_f=; [ "$d__pkg_b" = 1 ] && d__pkg_f="${d__pkga_f[$d__i]}"

    # Pre-set default statuses
    d__frcd=false d__shr=false d__shs=false

    # Perform check prior to processing
    if d__os_pkgmgr check $d__pkg_n; then
      if d__stash -rs -- has "pkg_$( d__md5 -s $d__pkg_n )"; then
        # Installed with stash record
        d__shr=true d__shs=true
      elif d__stash -rs -- has installed_utils "$d__pkg_n"; then
        # Installed through offer
        d__notify -l! -- "Package '$d__pkg_n' appears to be installed" \
          "by $D__FMWK_NAME itself"
        if $D__OPT_FORCE; then d__frcd=true d__shr=true d__shs=true
        else
          d__notify -l! -- 'Re-try with --force to overcome'
          printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$d__plq"
          d__prtc=0
          continue
        fi
      else
        # Installed without stash record
        d__notify -l! -- "Package '$d__pkg_n' appears to be installed" \
          "via '$D__OS_PKGMGR' manually"
        if $D__OPT_FORCE; then d__frcd=true d__shr=true
        else
          d__notify -l! -- 'Re-try with --force to overcome'
          printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$d__plq"
          d__prtc=0
          continue
        fi
      fi
    elif type -P -- $d__pkg_n &>/dev/null; then
      if d__stash -rs -- has "pkg_$( d__md5 -s $d__pkg_n )"; then
        # Installed without package manager, somehow there is a stash record
        d__notify -lx -- "Package '$d__pkg_n' is recorded" \
          "as previously installed via '$D__OS_PKGMGR'" \
          -n- 'but it now appears to be installed by other means'
        if $D__OPT_FORCE; then d__frcd=true d__shs=true
        else
          d__notify -l! -- 'Re-try with --force to overcome'
          printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq"; continue
        fi
      elif d__stash -rs -- has installed_utils "$d__pkg_n"; then
        # Installed without package manager, somehow there is an offer record
        d__notify -lx -- "Package '$d__pkg_n' is recorded" \
          "as previously installed by $D__FMWK_NAME itself" \
          -n- 'but it now appears to be installed by other means'
        if $D__OPT_FORCE; then d__frcd=true d__shs=true
        else
          d__notify -l! -- 'Re-try with --force to overcome'
          printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq"; continue
        fi
      else
        # Installed without package manager, no stash record
        if $D__OPT_FORCE; then
          d__notify -lx -- "Package '$d__pkg_n' appears to be installed" \
            "by means other than '$D__OS_PKGMGR'" -n- 'Unable to remove'
        else
          d__notify -l! -- "Package '$d__pkg_n' appears to be installed" \
            "by means other than '$D__OS_PKGMGR'"
        fi
        printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$d__plq"
        d__prtc=0
        continue
      fi
    else
      if d__stash -rs -- has "pkg_$( d__md5 -s $d__pkg_n )"; then
        # Not installed, but stash record exists
        d__notify -lx -- \
          "Package '$d__pkg_n' is recorded as previously installed" \
          -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
          -n- '(which may be due to manual tinkering)'
        if $D__OPT_FORCE; then d__frcd=true d__shs=true
        else
          d__notify -l! -- 'Re-try with --force to overcome'
          printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq"; continue
        fi
      elif d__stash -rs -- has installed_utils "$d__pkg_n"; then
        # Not installed, but offer record exists
        d__notify -lx -- \
          "Package '$d__pkg_n' is recorded as previously installed" \
          "by $D__FMWK_NAME itself" \
          -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
          -n- '(which may be due to manual tinkering)'
        if $D__OPT_FORCE; then d__frcd=true d__shs=true
        else
          d__notify -l! -- 'Re-try with --force to overcome'
          printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq"; continue
        fi
      else
        # Not installed, no stash record
        printf >&2 '%s %s\n' "$D__INTRO_RMV_A" "$d__plq"
        d__rtc=0
        continue
      fi
    fi

    # Check whether that particular package is available in package manager
    if ! d__os_pkgmgr has $d__pkg_n; then
      d__notify -qs -- \
        "Package '$d__pkg_n' is currently not available from '$D__OS_PKGMGR'"
      printf >&2 '%s %s\n' "$D__INTRO_NOTAV" "$d__plq"
      d__prtc=2
      continue
    fi

    # Settle on always-ask mode; if forcing, print force intro
    d__aamd=false; case $d__pkg_f in *[ar]*) d__aamd=true;; esac
    if $d__frcd; then printf >&2 '%s %s\n' "$D__INTRO_RMV_F" "$d__plq"; fi

    # Conditionally prompt for user's approval
    if $d__aamd || $d__frcd || [ "$D__OPT_ANSWER" != true ]; then
      if $d__aamd || $d__frcd; then printf >&2 '%s ' "$D__INTRO_CNF_U"
      else printf >&2 '%s ' "$D__INTRO_CNF_N"; fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"
        d__prtc=2
        continue
      fi
    fi

    # Launch OS package manager
    if $d__shr; then
      d__os_pkgmgr remove $d__pkg_n
      if (($?)); then
        d__notify -lx -- 'Package manager returned an error code' \
          "while removing package '$d__pkg_n'"
        printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$d__plq"; continue
      fi
    fi

    # Unset stash record
    if $d__shs; then
      d__stash -rs -- unset "pkg_$( d__md5 -s $d__pkg_n )" \
        && d__stash -rs -- unset installed_utils "$d__pkg_n"
      if (($?)); then
        d__notify -lx -- "Failed to unset stash record for package '$d__pkg_n'"
        printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$d__plq"; continue
      fi
    fi

    # Report
    d__prtc=0
    printf >&2 '%s %s\n' "$D__INTRO_RMV_0" "$d__plq"

  # Done iterating over package names in reverse order
  done

  # Process last status
  case $d__prtc in
    0)  d__anys=true;;
    1)  d__anyf=true;;
    2)  d__anyn=true;;
    *)  :;;
  esac

  # Always return zero
  return 0
}

#>  d___remove_dpls
#
## INTERNAL USE ONLY
#
## For the given priority level, removes deployments, one by one, using their 
#. *.dpl.sh files, paths to which have been previously assembled in 
#. $D__WKLD_DPLS array. Operates in reversed installation order.
#
## Local variables that need to be set in the calling context:
#.  $d__prty    - The priority at which to conduct processing.
#.  $d__prtys   - The priority as a fixed-width string composed for printing, 
#.                e.g. '( 300)'.
#
## Returns:
#.  0 - Deployments processed (incl. zero deployments)
#.  1 - Routine aborted: last deployment requested halting of the script
#
d___remove_dpls()
{
  # Return if empty list of *.dpl.sh files at the given priority
  [ -z ${D__WKLD_DPLS[$d__prty]+isset} ] && return 0

  # Storage variables
  local d__dpla_p=() d__dpl_p d__plq d__rtc d__aamd d__frcd d__adsti d__i
  local d__dpla_b d__dpla_n d__dpla_d d__dpla_f d__dpla_w
  local d__dpl_b d__dpl_n d__dpl_d d__dpl_f d__dpl_w

  # Extract data by splitting on newline
  IFS=$'\n' read -r -d '' -a d__dpla_n <<<"${D__WKLD_DPL_NAMES[$d__prty]}"
  if [ "$D__OPT_ANSWER" != false ]; then
    IFS=$'\n' read -r -d '' -a d__dpla_p <<<"${D__WKLD_DPLS[$d__prty]}"
    IFS=$'\n' read -r -d '' -a d__dpla_b <<<"${D__WKLD_DPL_BITS[$d__prty]}"
    IFS=$'\n' read -r -d '' -a d__dpla_d <<<"${D__WKLD_DPL_DESCS[$d__prty]}"
    IFS=$'\n' read -r -d '' -a d__dpla_f <<<"${D__WKLD_DPL_FLAGS[$d__prty]}"
    IFS=$'\n' read -r -d '' -a d__dpla_w <<<"${D__WKLD_DPL_WARNS[$d__prty]}"
  fi

  # Clear status
  d___write_status

  # Iterate over *.dpl.sh filepaths in reverse order
  for ((d__i=${#d__dpla_n[@]}-1;d__i>=0;--d__i)); do

    # Process status from previous iteration; set default value
    case $( d___read_status ) in
      0)  d__anys=true;;
      1)  d__anyf=true;;
      2)  d__anyn=true;;
      *)  :;;
    esac
    d___write_status 1

    # Print a separating empty line; extract dpl name; compose task name
    printf >&2 '\n'; d__dpl_n="${d__dpla_n[$d__i]}"
    d__plq="$d__prtys Deployment '$BOLD$d__dpl_n$NORMAL'"

    # Early exit for dry runs
    if [ "$D__OPT_ANSWER" = false ]; then
      printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"; continue
    fi

    # Extract the rest of the data; settle on always-ask mode
    d__dpl_p="${d__dpla_p[$d__i]}"; d__dpl_b="${d__dpla_b[$d__i]}"
    d__dpl_d=; [ "${d__dpl_b:0:1}" = 1 ] && d__dpl_d="${d__dpla_d[$d__i]}"
    d__dpl_f=; [ "${d__dpl_b:1:1}" = 1 ] && d__dpl_f="${d__dpla_f[$d__i]}"
    d__dpl_w=; [ "${d__dpl_b:2:1}" = 1 ] && d__dpl_w="${d__dpla_w[$d__i]}"
    d__aamd=false; case $d__dpl_f in *[ar]*) d__aamd=true;; esac

    # Print intro; conditionally add optional description; print location
    printf >&2 '%s %s\n' "$D__INTRO_RMV_N" "$d__plq"
    if [ -n "$d__dpl_d" ] \
      && ( $d__aamd || [ "$D__OPT_ANSWER" != true ] || (($D__OPT_VERBOSITY)) )
    then
      printf >&2 '%s %s\n' "$D__INTRO_DESCR" "$d__dpl_d"
    fi
    d__notify -q -- "Location: $d__dpl_p"

    # Conditionally prompt for user's approval
    if $d__aamd || [ "$D__OPT_ANSWER" != true ]; then
      if $d__aamd; then
        [ -n "$d__dpl_w" ] \
          && printf >&2 '%s %s\n' "$D__INTRO_WARNG" "$d__dpl_w"
        printf >&2 '%s ' "$D__INTRO_CNF_U"
      else printf >&2 '%s ' "$D__INTRO_CNF_N"; fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"
        d___write_status 2
        continue
      fi
    fi

    # Open subshell for a laughable illusion of 'security'
    (

      # Announce
      d__notify -qqq -- 'Entered sub-shell'

      # Expose variables to deployment
      D_DPL_NAME="$d__dpl_n"
      D_DPL_PRIORITY="$d__prty"
      readonly D__DPL_SH_PATH="$d__dpl_p"
      D__DPL_MNF_PATH="${d__dpl_p%$D__SUFFIX_DPL_SH}"
      readonly D__DPL_QUE_PATH="${D__DPL_MNF_PATH}$D__SUFFIX_DPL_QUE"
      unset D_ADDST_QUEUE_MNF_PATH
      readonly D__DPL_MNF_PATH+="$D__SUFFIX_DPL_MNF"
      readonly D__DPL_DIR="$( dirname -- "$d__dpl_p" )"
      readonly D__DPL_ASSET_DIR="$D__DIR_ASSETS/$D_DPL_NAME"
      readonly D__DPL_BACKUP_DIR="$D__DIR_BACKUPS/$D_DPL_NAME"

      # Process the asset manifest, if it exists
      if ! d__process_asset_manifest_of_current_dpl; then
        d__notify -lx -- 'Failed to process deployment assets'
        printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"
        d__notify -qqq -- 'Exiting sub-shell'
        exit
      fi

      # Print debug message
      d__notify -qq -- "Sourcing: $d__dpl_p"

      # Hold your breath...
      source "$d__dpl_p"

      # Process queue manifest (after sourcing, to allow path customization)
      d__process_queue_manifest_of_current_dpl

      # Clear add-statuses
      unset D_ADDST_PROMPT D_ADDST_HALT
      unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

      # Get return code of d_dpl_check, or fall back to zero
      if declare -f d_dpl_check &>/dev/null; then d_dpl_check; d__rtc=$?
      else d__rtc=0; fi

      # Process return code; pre-set default force status
      d__frcd=false
      case $d__rtc in
        1)  # Fully installed
            :;;
        2)  # Fully not installed
            if $D__OPT_FORCE; then d__frcd=true
              d__notify -l! -- \
                "Deployment '$d__dpl_n' appears to be already not installed"
            else
              printf >&2 '%s %s\n' "$D__INTRO_RMV_A" "$d__plq"
              d__notify -qqq -- 'Exiting sub-shell'
              d___write_status 0
              exit
            fi;;
        3)  # Irrelevant or invalid
            printf >&2 '%s %s\n' "$D__INTRO_CHK_3" "$d__plq"
            d__notify -qqq -- 'Exiting sub-shell'
            d___write_status 0
            exit;;
        4)  # Partly installed
            d__notify -l! -- \
              "Deployment '$d__dpl_n' appears to be only partly installed";;
        5)  # Likely installed (unknown)
            d__notify -l! -- \
              "Deployment '$d__dpl_n' is recorded as previously installed" \
              -n- 'but there is no way to confirm that it is indeed installed'
            if $D__OPT_FORCE; then d__frcd=true
            else
              d__notify -l! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_CHK_5" "$d__plq"
              d__notify -qqq -- 'Exiting sub-shell'; exit
            fi;;
        6)  # Manually removed (tinkered with)
            d__notify -lx -- \
              "Deployment '$d__dpl_n' is recorded as previously installed" \
              -n- "but does ${BOLD}not$NORMAL appear to be installed" \
              -n- 'right now (which may be due to manual tinkering)'
            if $D__OPT_FORCE; then d__frcd=true
            else
              d__notify -l! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"
              d__notify -qqq -- 'Exiting sub-shell'; exit
            fi;;
        7)  # Fully installed (by user or OS)
            d__notify -l! -- \
              "Deployment '$d__dpl_n' appears to be fully installed" \
              'by means other than installing this deployment'
            if $D__OPT_FORCE; then d__frcd=true
            else
              d__notify -l! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$d__plq"
              d__notify -qqq -- 'Exiting sub-shell'; exit
            fi;;
        8)  # Partly installed (by user or OS)
            d__notify -l! -- \
              "Deployment '$d__dpl_n' appears to be partly installed" \
              'by means other than installing this deployment'
            if $D__OPT_FORCE; then d__frcd=true
            else
              d__notify -l! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_CHK_8" "$d__plq"
              d__notify -qqq -- 'Exiting sub-shell'; exit
            fi;;
        9)  # Likely not installed (unknown)
            d__notify -l! -- \
              "Deployment '$d__dpl_n' is ${BOLD}not$NORMAL recorded" \
              'as previously installed' -n- 'but there is no way to confirm' \
              "that it is indeed ${BOLD}not$NORMAL installed"
            if $D__OPT_FORCE; then d__frcd=true
            else
              d__notify -l! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_CHK_9" "$d__plq"
              d__notify -qqq -- 'Exiting sub-shell'; exit
            fi;;
        *)  # Truly unknown
            :;;
      esac

      # Catch add-statuses
      if ((${#D_ADDST_ATTENTION[@]})); then
        for d__adsti in "${D_ADDST_ATTENTION[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_ATTNT" "$d__adsti"
        done
      fi
      if ((${#D_ADDST_HELP[@]})); then
        for d__adsti in "${D_ADDST_HELP[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_RBOOT" "$d__adsti"
        done
      fi
      if ((${#D_ADDST_WARNING[@]})); then
        for d__adsti in "${D_ADDST_WARNING[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_WARNG" "$d__adsti"
        done
      fi
      if ((${#D_ADDST_CRITICAL[@]})); then
        for d__adsti in "${D_ADDST_CRITICAL[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_CRTCL" "$d__adsti"
        done
      fi

      # Catch the halting add-status
      if [ "$D_ADDST_HALT" = true ]; then
        printf >&2 '%s %s\n' "$D__INTRO_HALTN" \
          "Deployment '$d__dpl_n' has requested to halt the routine"
        d__notify -qqq -- 'Exiting sub-shell'
        return 1
      fi

      # If forcing, print a forceful intro
      $d__frcd && printf >&2 '%s %s\n' "$D__INTRO_RMV_F" "$d__plq"

      # Re-prompt if forcing or if caught a prompt add-status
      if $d__frcd || [ "$D_ADDST_PROMPT" = true ]; then
        printf >&2 '%s ' "$D__INTRO_CNF_U"
        if ! d__prompt -b; then
          printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$d__plq"
          d__notify -qqq -- 'Exiting sub-shell'
          d___write_status 2
          exit
        fi
      fi

      # Clear add-statuses again
      unset D_ADDST_HALT
      unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

      ## Expose additional variables to the deployment. These are not readonly 
      #. because they might be further changed by the underlying helpers, e.g., 
      #. multitask or queue.
      D__DPL_CHECK_CODE="$d__rtc"
      D__DPL_IS_FORCED="$d__frcd"

      # Get return code of d_dpl_remove, or fall back to zero
      if declare -f d_dpl_remove &>/dev/null; then d_dpl_remove; d__rtc=$?
      else d__rtc=0; fi

      # Process return code
      case $d__rtc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$d__plq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$d__plq"
            d___write_status 2
            ;;
        3)  printf >&2 '%s %s\n' "$D__INTRO_RMV_3" "$d__plq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_RMV_0" "$d__plq"
            d___write_status 0
            ;;
      esac

      # Catch add-statuses
      if ((${#D_ADDST_ATTENTION[@]})); then
        for d__adsti in "${D_ADDST_ATTENTION[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_ATTNT" "$d__adsti"
        done
      fi
      if ((${#D_ADDST_HELP[@]})); then
        for d__adsti in "${D_ADDST_HELP[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_RBOOT" "$d__adsti"
        done
      fi
      if ((${#D_ADDST_WARNING[@]})); then
        for d__adsti in "${D_ADDST_WARNING[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_WARNG" "$d__adsti"
        done
      fi
      if ((${#D_ADDST_CRITICAL[@]})); then
        for d__adsti in "${D_ADDST_CRITICAL[@]}"; do
          printf >&2 '%s %s\n' "$D__INTRO_CRTCL" "$d__adsti"
        done
      fi

      # Catch the halting add-status
      if [ "$D_ADDST_HALT" = true ]; then
        printf >&2 '%s %s\n' "$D__INTRO_HALTN" \
          "Deployment '$d__dpl_n' has requested to halt the routine"
        d__notify -qqq -- 'Exiting sub-shell'
        return 1
      fi

      # Announce
      d__notify -qqq -- 'Exiting sub-shell'

    # Close subshell
    )

  # Done iterating over *.dpl.sh filepaths in reverse order
  done

  # Process last status
  case $( d___read_status ) in
    0)  d__anys=true;;
    1)  d__anyf=true;;
    2)  d__anyn=true;;
    *)  :;;
  esac

  # Always return zero
  return 0
}

d___write_status() { printf >$d__prxf '%s\n' "$1"; }
d___read_status() { local ii; read -r ii <$d__prxf; printf '%s\n' "$ii"; }

d__rtn_remove