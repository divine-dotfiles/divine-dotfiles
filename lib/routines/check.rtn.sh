#!/usr/bin/env bash
#:title:        Divine Bash routine: check
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Checks packages and deployments as requested
#

# Marker and dependencies
readonly D__RTN_CHECK=loaded
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

#>  d__rtn_check
#
## Performs checking routine
#
# For each priority level, from smallest to largest, separately:
#.  * Checks whether packages are installed, in order they appear in Divinefile
#.  * Checks whether deployments are installed, in no particular order
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
d__rtn_check()
{
  $D__OPT_OBLITERATE && d__confirm_obliteration

  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'check' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Checking' Divine intervention"
  else
    d__announce -v -- 'Checking Divine intervention'
  fi

  # Init storage vars; iterate over taken priorities
  local d__prty d__prtys
  for d__prty in ${!D__WKLD[@]}; do

    # Switch context and compose priority string
    d__context -n -- push "Checking at priority '$d__prty'"
    d__prtys="$( printf "(%${D__WKLD_MAX_PRTY_LEN}d)" "$d__prty" )"

    # Check packages and deployments, if asked to
    d___check_pkgs; d___check_dpls

    # See if d___check_dpls returned special status
    if [ $? -eq 1 ]; then
      printf >&2 '\n'
      d__announce -! -- 'Halting Divine intervention'
      d__context -- lop
      return 1
    fi

    # Pop the priority
    d__context -n -- pop

  done

  # Announce completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Successfully 'checked' Divine intervention"
  else
    d__announce -v -- 'Successfully checked Divine intervention'
  fi
  d__context -- lop
  return 0
}

#>  d___check_pkgs
#
## INTERNAL USE ONLY
#
## For the given priority level, check if packages are installed, one by one, 
#. using their names, which have been previously assembled in $D__WKLD_PKGS 
#. array
#
## Local variables that need to be set in the calling context:
#.  $d__prty    - The priority at which to conduct processing.
#.  $d__prtys   - The priority as a fixed-width string composed for printing, 
#.                e.g. '( 300)'.
#
## Returns:
#.  0 - Always
#
d___check_pkgs()
{
  # Return if empty list of packages at the given priority
  [ -z ${D__WKLD_PKGS[$d__prty]+isset} ] && return 0

  # Storage variables
  local d__plq d__pkga_n d__pkg_n

  # Split package names on newline
  IFS=$'\n' read -r -d '' -a d__pkga_n <<<"${D__WKLD_PKGS[$d__prty]}"

  # Iterate over package names
  for d__pkg_n in "${d__pkga_n[@]}"; do

    ## Print a separating empty line; compose task name. Note: in check routine 
    #. package flags are effectively ignored
    printf >&2 '\n'; d__plq="$d__prtys Package '$BOLD$d__pkg_n$NORMAL'"

    # Early exit for dry runs
    if [ "$D__OPT_ANSWER" = false ]; then
      printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$d__plq"; continue
    fi

    # Perform check
    if d__os_pkgmgr check $d__pkg_n; then
      if d__stash -rs -- has "pkg_$( d__md5 -s $d__pkg_n )" \
        || d__stash -rs -- has installed_utils "$d__pkg_n"
      then
        # Installed with stash record
        printf >&2 '%s %s\n' "$D__INTRO_CHK_1" "$d__plq"
      else
        # Installed without stash record
        printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$d__plq"
      fi
    elif type -P -- $d__pkg_n &>/dev/null; then
      if d__stash -rs -- has "pkg_$( d__md5 -s $d__pkg_n )" \
        || d__stash -rs -- has installed_utils "$d__pkg_n"
      then
        # Installed without package manager, somehow there is a stash record
        d__notify -lx -- "Package '$d__pkg_n' is recorded" \
          "as previously installed via '$D__OS_PKGMGR'" \
          -n- 'but it now appears to be installed by other means'
        printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq"
      else
        # Installed without package manager, no stash record
        d__notify -qq -- "Package '$d__pkg_n' appears to be installed" \
          "by means other than '$D__OS_PKGMGR'"
        printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$d__plq"
      fi
    else
      if d__stash -rs -- has "pkg_$( d__md5 -s $d__pkg_n )"; then
        # Not installed, but stash record exists
        printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq"
      elif ! d__os_pkgmgr has $d__pkg_n; then
        # Not available in package manager at all
        printf >&2 '%s %s\n' "$D__INTRO_NOTAV" "$d__plq"
      else
        # Not installed, no stash record
        printf >&2 '%s %s\n' "$D__INTRO_CHK_2" "$d__plq"
      fi
    fi

  # Done iterating over package names
  done

  # Always return zero
  return 0
}

#>  d___check_dpls
#
## INTERNAL USE ONLY
#
## For the given priority level, checks whether deployments are installed, one 
#. by one, using their *.dpl.sh files, paths to which have been previously 
#. assembled in $D__WKLD_DPLS array
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
d___check_dpls()
{
  # Return if empty list of *.dpl.sh files at the given priority
  [ -z ${D__WKLD_DPLS[$d__prty]+isset} ] && return 0

  # Storage variables
  local d__dpla_p=() d__dpl_p d__plq d__aamd d__adsti d__i
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

  # Iterate over *.dpl.sh filepaths
  for ((d__i=0;d__i<${#d__dpla_n[@]};++d__i)); do

    # Print a separating empty line; extract dpl name; compose task name
    printf >&2 '\n'; d__dpl_n="${d__dpla_n[$d__i]}"
    d__plq="$d__prtys Deployment '$BOLD$d__dpl_n$NORMAL'"

    # Early exit for dry runs
    if [ "$D__OPT_ANSWER" = false ]; then
      printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$d__plq"; continue
    fi

    # Extract the rest of the data; settle on always-ask mode
    d__dpl_p="${d__dpla_p[$d__i]}"; d__dpl_b="${d__dpla_b[$d__i]}"
    d__dpl_d=; [ "${d__dpl_b:0:1}" = 1 ] && d__dpl_d="${d__dpla_d[$d__i]}"
    d__dpl_f=; [ "${d__dpl_b:1:1}" = 1 ] && d__dpl_f="${d__dpla_f[$d__i]}"
    d__dpl_w=; [ "${d__dpl_b:2:1}" = 1 ] && d__dpl_w="${d__dpla_w[$d__i]}"
    d__aamd=false; case $d__dpl_f in *[ac]*) d__aamd=true;; esac

    # Conditionally print intro with optional description; print location
    if $d__aamd || [ "$D__OPT_ANSWER" != true ] || (($D__OPT_VERBOSITY)); then
      printf >&2 '%s %s\n' "$D__INTRO_CHK_N" "$d__plq"
      [ -n "$d__dpl_d" ] && printf >&2 '%s %s\n' "$D__INTRO_DESCR" "$d__dpl_d"
      d__notify -q -- "Location: $d__dpl_p"
    fi

    # Conditionally prompt for user's approval
    if $d__aamd || [ "$D__OPT_ANSWER" != true ]; then
      if $d__aamd; then
        [ -n "$d__dpl_w" ] \
          && printf >&2 '%s %s\n' "$D__INTRO_WARNG" "$d__dpl_w"
        printf >&2 '%s ' "$D__INTRO_CNF_U"
      else printf >&2 '%s ' "$D__INTRO_CNF_N"; fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$d__plq"; continue
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
        printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$d__plq"
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
      unset D_ADDST_HALT
      unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

      # Get return code of d_dpl_check, or fall back to zero
      if declare -f d_dpl_check &>/dev/null; then d_dpl_check; else true; fi

      # Process return code
      case $? in
        1)  printf >&2 '%s %s\n' "$D__INTRO_CHK_1" "$d__plq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_CHK_2" "$d__plq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_CHK_3" "$d__plq";;
        4)  printf >&2 '%s %s\n' "$D__INTRO_CHK_4" "$d__plq";;
        5)  printf >&2 '%s %s\n' "$D__INTRO_CHK_5" "$d__plq";;
        6)  printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$d__plq";;
        7)  printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$d__plq";;
        8)  printf >&2 '%s %s\n' "$D__INTRO_CHK_8" "$d__plq";;
        9)  printf >&2 '%s %s\n' "$D__INTRO_CHK_9" "$d__plq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_CHK_0" "$d__plq";;
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

  # Done iterating over *.dpl.sh filepaths
  done

  # Always return zero
  return 0
}

d__rtn_check