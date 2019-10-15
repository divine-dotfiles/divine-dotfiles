#!/usr/bin/env bash
#:title:        Divine Bash routine: detach
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2019.06.28

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Detaches bundles of deployments by removing their directories and clearing 
#. their installation record.
#

# Marker and dependencies
readonly D__RTN_DETACH=loaded
d__load util workflow
d__load util stash
d__load util scan
d__load procedure prep-stash
d__load procedure prep-gh
d__load procedure sync-bundles

#>  d__rtn_detach
#
## Performs detach routine
#
## Returns:
#.  0 - All bundles detached.
#.  0 - (script exit) Zero bundle names given.
#.  1 - At least one given bundle was not detached.
#
d__rtn_detach()
{
  # Check if any tasks were found
  if [ ${#D__REQ_ARGS[@]} -eq 0 ]; then
    d__notify -lst 'Nothing to do' -- 'Not a single bundle name given'
    exit 0
  fi

  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'detach' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Detaching' bundles"
  else
    d__announce -v -- 'Detaching bundles'
  fi

  # Storage & status variables
  local barg bdst bplq bany=false ball=true bpcs bdcs

  # Iterate over script arguments
  for barg in "${D__REQ_ARGS[@]}"
  do d___detach_bundle && bany=true || ball=false; done

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]
  then d__announce -s -- "Finished 'detaching' bundles"; return 0
  elif $bany; then
    if $ball; then
      d__announce -v -- 'Successfully detached bundles'; return 0
    else
      d__announce -! -- 'Partly detached bundles'; return 1
    fi
  else
    d__announce -x -- 'Failed to detach bundles'; return 1
  fi
}

#>  d___detach_bundle
#
## INTERNAL USE ONLY
#
d___detach_bundle()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; bplq="Bundle '$BOLD$barg$NORMAL'"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_DTC_S" "$bplq"; return 1
  fi

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_DTC_N" "$bplq"

  # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
  if [[ $barg =~ ^[0-9A-Za-z_.-]+$ ]]
  then barg="no-simpler/divine-bundle-$barg"
  elif [[ $barg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then :
  else
    d__notify -lx -- "Invalid bundle identifier '$barg'"
    printf >&2 '%s %s\n' "$D__INTRO_DTC_2" "$bplq"; return 1
  fi

  # Compose destination path; print location
  bdst="$D__DIR_BUNDLES/$barg"
  d__notify -q -- "Location: $bdst"

  # Check if such bundle directory exists
  if [ -e "$bdst" ]; then
    if ! [ -d "$bdst" ]; then
      d__notify -ls -- "Local path to bundle '$barg' is occupied" \
        'by a non-directory:' -i- "$bdst"
      printf >&2 '%s %s\n' "$D__INTRO_DTC_1" "$bplq"; return 1
    fi
  else
    d__notify -ls -- "Bundle '$barg' appears to be already" \
      "${BOLD}not$NORMAL attached"
    printf >&2 '%s %s\n' "$D__INTRO_DTC_S" "$bplq"; return 1
  fi

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b
    then printf >&2 '%s %s\n' "$D__INTRO_DTC_S" "$bplq"; return 1; fi
  fi

  # Calculate number of deployments within the bundle
  D__EXT_DF_COUNT=0 D__EXT_DPL_COUNT=0
  d__scan_for_divinefiles --external "$bdst" &>/dev/null
  d__scan_for_dpl_files --external "$bdst" &>/dev/null

  # Remove bundle directory
  if ! rm -rf -- "$bdst"; then
    d__notify -lx -- "Failed to remove directory of bundle '$barg'"
    printf >&2 '%s %s\n' "$D__INTRO_DTC_1" "$bplq"
    return 1
  fi

  # Compose success string; report success
  bpcs="$D__EXT_DF_COUNT Divinefile"; [ $D__EXT_DF_COUNT -eq 1 ] || bpcs+='s'
  bdcs="$D__EXT_DPL_COUNT deployment"; [ $D__EXT_DPL_COUNT -eq 1 ] || bdcs+='s'
  d__notify -lv -- "Detached $bpcs and $bdcs"

  # Unset stash record
  if  d__stash -gs -- unset attached_bundles "$barg"; then
    d__notify -- "Removed record of bundle '$barg' from Grail stash"
  else
    d__notify -lx -- "Failed to remove record of bundle '$utl'" \
      'from Grail stash'
  fi
  printf >&2 '%s %s\n' "$D__INTRO_DTC_0" "$bplq"
  return 0
}

d__rtn_detach