#!/usr/bin/env bash
#:title:        Divine Bash routine: update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.28
#:revremark:    Make location/URL alerts less visible
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Updates Divine.dotfiles framework, attached bundles, and Grail directory 
#. itself if the latter is a cloned repository.
#

# Marker and dependencies
readonly D__RTN_UPDATE=loaded
d__load util workflow
d__load util stash
d__load util git
d__load util backup
d__load util fmwk-update
d__load procedure prep-stash
d__load procedure prep-sys
d__load procedure offer-gh
d__load procedure check-gh
d__load procedure sync-bundles

#>  d__rtn_update
#
## Performs update routine.
#
## Returns:
#.  0 - Success.
#.  1 - Otherwise.
#.  1 - (script exit) Missing necessary tools.
#
d__rtn_update()
{
  # Ensure that there is a method for updating
  if [ -z "$D__GH_METHOD" ]; then
    d__notify -lxt 'Unable to update' -- 'Current system does not have' \
      'the tools to interact with Git/Github repositories'
    exit 1
  fi

  $D__OPT_OBLITERATE && d__confirm_obliteration

  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'update' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Updating' Divine.dotfiles"
  else
    d__announce -v -- 'Updating Divine.dotfiles'
  fi

  # Storage variables
  local ii uttr=() ubtr=() utsk
  local anys=false anyf=false anyd=false ucst=0

  # Parse update arguments; perform updates in order
  d___parse_update_args
  for ((ii=0;ii<${#uttr[@]};++ii)); do
    utsk=${uttr[$ii]}
    case $utsk in
      fmwk)       d___update_fmwk;;
      grail)      d___update_grail;;
      'bundle='*) d___update_bundle "${utsk#'bundle='}";;
      no_bundles) d___update_no_bundles
                  continue
                  ;;
      *)          continue;;
    esac
  done
  
  # Count statuses
  $anys && ((++ucst))
  $anyf && ((++ucst))
  $anyd && ((++ucst))

  # If any updates succeeded, process asset manifests
  if $anys; then d__load procedure process-all-assets; fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Finished 'updating' Divine.dotfiles"
    return 0
  else
    case $ucst in
      0)  d__announce -s -- 'Skipped updating Divine.dotfiles'
          return 0
          ;;
      1)  if $anys; then
            d__announce -v -- 'Successfully updated Divine.dotfiles'
            return 0
          elif $anyf; then
            d__announce -x -- 'Failed to update Divine.dotfiles'
            return 1
          elif $anyd; then
            d__announce -s -- 'Declined to update Divine.dotfiles'
            return 0
          fi
          ;;
      2)  if $anys && $anyf; then
            d__announce -! -- 'Partly updated Divine.dotfiles'
            return 1
          elif $anys && $anyd; then
            d__announce -v -- 'Partly updated Divine.dotfiles'
            return 0
          elif $anyf && $anyd; then
            d__announce -x -- 'Failed to update Divine.dotfiles'
            return 1
          fi
          ;;
      3)  d__announce -! -- 'Partly updated Divine.dotfiles'
          return 1
          ;;
    esac
  fi
}

d___parse_update_args()
{
  # Variables to track selections
  local uslf=false uslg=false uslb=false erra=()

  # Check if given a list of bundles
  if ((${#D__REQ_BUNDLES[@]})); then

    # Iterate over list of given bundles
    for ughh in "${D__REQ_BUNDLES[@]}"; do

      # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
      if [[ $ughh =~ ^[0-9A-Za-z_.-]+$ ]]; then
        ughh="no-simpler/divine-bundle-$ughh"
      elif [[ $ughh =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then
        :
      else
        erra+=( -i- "- invalid bundle identifier '$ughh'" )
        continue
      fi

      # Check if such a directory exists
      if ! [ -d "$D__DIR_BUNDLES/$ughh" ]; then
        erra+=( -i- "- bundle '$ughh' does not appear to be attached" )
        continue
      fi

      # Add bundle to update train
      ubtr+=("bundle=$ughh")
    
    # Done iterating over list of given bundles
    done

    # If there are illegal bundles, print an alert and stop
    if ((${#erra[@]})); then
      local beex='All'; ((${#ubtr[@]})) && beex='Some'
      d__notify -nl! -- "$beex of the given bundles are invalid:" \
        "${erra[@]}" -n- 'Stopping just in case'
      return 1
    fi

    # If given bundles are valid, implicitly enable bundle updating
    ((${#ubtr[@]})) && uslb=true
  
  # Done checking if given a list of bundles
  fi

  # Parse update arguments
  if [ ${#D__REQ_ARGS[@]} -eq 0 ]; then

    # With zero args update everything, UNLESS bundles are given
    $uslb || { uslf=true; uslg=true; uslb=true; }

  else

    # With non-zero args, iterate over them
    for ii in "${D__REQ_ARGS[@]}"; do case $ii in
      a|al|all)           uslf=true; uslg=true; uslb=true;;
      f|fr|fm|fmwk)       uslf=true;;
      framework)          uslf=true;;
      g|gr|grail)         uslg=true;;
      b|bu|bundles)       uslb=true;;
      bd|bdl|bdls)        uslb=true;;
      d|dp|dpl|dpls)      uslb=true;;
      de|dep|deps)        uslb=true;;
      deployment)         uslb=true;;
      deployments)        uslb=true;;
      *)                  erra+=( -i- "- unrecognized argument '$ii'" );;
    esac; done
  
  # Done parsing update arguments
  fi

  # If there are illegal arguments, print an alert and stop
  if ((${#erra[@]})); then
    d__notify -nl! -- "There are problems with the request:" "${erra[@]}" \
      -n- 'Stopping just in case'
    return 1
  fi

  # If updating bundles, but not having a list yet, pull from stash
  if $uslb && [ ${#ubtr[@]} -eq 0 ]; then
    if d__stash -gs -- has attached_bundles; then
      while read -r ughh; do
        ubtr+=("bundle=$ughh")
      done < <( d__stash -gs -- list attached_bundles )
    fi
  fi

  # Assemble update train
  $uslf && uttr+=(fmwk)
  $uslg && uttr+=(grail)
  if $uslb; then
    if ((${#ubtr[@]})); then
      uttr+=("${ubtr[@]}")
    else
      uttr+=(no_bundles)
    fi
  fi

  # If zero update tasks found, print alert
  if [ ${#uttr[@]} -eq 0 ]; then
    d__notify -nls -- 'No update tasks provided'
    return 1
  fi

  return 0
}

#>  d___update_pre
#
## INTERNAL USE ONLY
#
#>  $uplq
#>  $udst
#
#<  0 - good to go
#<  1 - otherwise
#
d___update_pre()
{
  # Print a separating empty line
  printf >&2 '\n'

  # Cut-off for dry-runs
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
    return 1
  fi

  # Ensure that destination directory exists
  if ! pushd -- "$udst" &>/dev/null; then
    d__notify -lx -- "Unable to access directory to be updated: '$udst'"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"
    anyf=true
    return 1
  fi

  # Print intro and return
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"
  return 0
}

#>  d___update_report
#
## INTERNAL USE ONLY
#
#>  $1      - return code for update
#>  $uplq
#
#<  $?      - $1, if supported, otherwise 1
#
d___update_report()
{
  popd &>/dev/null
  case $1 in
    0)  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"
        anys=true
        return 0
        ;;
    1)  printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
        anyf=true
        return 1
        ;;
    2)  printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"
        anyf=true
        return 2
        ;;
    3)  printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
        anyd=true
        return 3
        ;;
    *)  return 1;;
  esac
}

d___update_fmwk()
{
  # Set up key variables; call pre-processing function
  local uplq="$BOLD$D__FMWK_NAME$NORMAL framework"
  local ughh='no-simpler/divine-dotfiles'
  local udst="$D__DIR_FMWK"
  d___update_pre || return 1

  # Ensure that remote repository exists
  if ! d___gh_repo_exists "$ughh"; then
    d__notify -ls -- "Github repository '$ughh' does not appear to exist"
    d___update_report 2
    return 1
  fi

  # Print locations
  d__notify -ld -- "Repo URL: https://github.com/$ughh"
  d__notify -ld -- "Location: $udst"

  # Check for current status of nightly mode
  local ungh=false ubld='stable'
  d__stash -rs -- has 'nightly' && { ungh=true; ubld='nightly'; }

  # Settle on method and compose prompt
  local umet=d ufrc=false
  if d___path_is_gh_clone "$udst" "$ughh"; then
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- \
        "Pulling latest revision of $D__FMWK_NAME ($BOLD$ubld$NORMAL build)"
      umet=p
    else
      d__notify -lxt 'Unable to update' -- 'Framework is a clone' \
        'of Github remote, but Git is currently not available on the system'
      d___update_report 2
      return 1
    fi
  else
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Upgrading downloaded copy of $D__FMWK_NAME" \
        "to a clone of its repository ($BOLD$ubld$NORMAL build)" \
        -n- 'Current framework directory will be kept'
      umet=c
    else
      if $D__OPT_FORCE; then
        d__notify -l! -- "Re-downloading latest copy of $D__FMWK_NAME" \
          "($BOLD$ubld$NORMAL build)" \
          -n- 'Current framework directory will be kept'
        umet=d ufrc=true
      else
        d__notify -lx -- "The only avenue of updating $D__FMWK_NAME" \
          "is to re-download latest copy ($BOLD$ubld$NORMAL build)"
        d__notify -l! -- 'Re-try with --force to overcome'
        d___update_report 2
        return 1
      fi
    fi
  fi

  # Launch appropriate function; finish up
  case $umet in
    p)  d___update_fmwk_via_pull;;
    c)  d___update_fmwk_to_clone;;
    d)  d___update_fmwk_via_dl;;
  esac
  d___update_report $? && return 0 || return 1
}

d___update_grail()
{
  # Set up key variables; call pre-processing function
  local uplq="${BOLD}Grail$NORMAL directory"
  local udst="$D__DIR_GRAIL"
  d___update_pre || return 1

  # Cut-off check against git
  if ! [ "$D__GH_METHOD" = g ]; then
    d__notify -lx -- 'Unable to check status of Grail directory' \
      'because current system does not Git'
    d___update_report 3
    return 1
  fi

  # Check if Grail directory is a git repository
  if ! git ls-remote "$udst" -q &>/dev/null; then
    d__notify -ls -- 'Grail directory is not a Git repository'
    d___update_report 3
    return 1
  fi

  # Figure out current branch
  local cbrn="$( git rev-parse --abbrev-ref HEAD 2>/dev/null )" prtc=0
  case $cbrn in
    '')     d__notify -lx -- \
              'Unable to detect current branch of Git repo in Grail directory'
            d___update_report 2
            return 1
            ;;
    'HEAD') d__notify -lx -- 'Unable to update Git repo in Grail directory' \
              "because it is in 'detached HEAD' state"
            d___update_report 2
            return 1
            ;;
  esac

  # Validate remote and extract its address
  if ! git ls-remote --exit-code origin "$cbrn" &>/dev/null; then
    d__notify -ls -- "Unable to find branch '$cbrn' on remote 'origin'" \
      'of Git repo in Grail directory'
    d___update_report 2
    return 1
  fi
  local usrc="$( git config --get remote.origin.url 2>/dev/null )"
  if [ -z "$usrc" ]; then
    d__notify -lx -- "Unable to detect address of remote 'origin'" \
      'of Git repo in Grail directory'
    d___update_report 2
    return 1
  fi
  if [[ $usrc = 'https://github.com/'* ]]; then
    usrc="${usrc%.git}"
    usrc="Github repository '${usrc#https://github.com/}'"
  else
    usrc="Git repository at '$usrc'"
  fi

  # Print locations
  d__notify -ld -- "Origin  : $usrc"
  d__notify -ld -- "Location: $udst"

  # Prompt user
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b; then
      d___update_report 3
      return 1
    fi
  fi

  # Launch routine; finish up
  d___pull_git_remote -t 'Grail directory' -- "$udst"
  d___update_report $? && return 0 || return 1
}

d___update_bundle()
{
  # Set up key variables; call pre-processing function
  local ughh="$1"
  local uplq="Attached bundle '$BOLD$ughh$NORMAL'"
  local udst="$D__DIR_BUNDLES/$ughh"
  d___update_pre || return 1

  # Ensure that remote repository exists
  if ! d___gh_repo_exists "$ughh"; then
    d__notify -ls -- "Github repository '$ughh' does not appear to exist"
    d___update_report 2
    return 1
  fi

  # Print locations
  d__notify -ld -- "Repo URL: https://github.com/$ughh"
  d__notify -ld -- "Location: $udst"

  # Settle on method and compose prompt
  local umet=d ufrc=false
  if d___path_is_gh_clone "$udst" "$ughh"; then
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Pulling latest revision of bundle '$ughh'"
      umet=p
    else
      d__notify -lxt 'Unable to update' -- 'Bundle '$ughh' is a clone' \
        'of Github remote, but Git is currently not available on the system'
      d___update_report 2
      return 1
    fi
  else
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Upgrading downloaded copy of bundle '$ughh'" \
        'to a clone of its repository' \
        -n- 'Current bundle directory will be kept'
      umet=c
    else
      if $D__OPT_FORCE; then
        d__notify -lx -- "Re-downloading latest copy of bundle '$ughh'" \
          -n- 'Current bundle directory will be kept'
        umet=d ufrc=true
      else
        d__notify -l! -- "The only avenue of updating bundle '$ughh'" \
          'is to re-download latest copy'
        d__notify -l! -- 'Re-try with --force to overcome'
        d___update_report 2
        return 1
      fi
    fi
  fi

  # Prompt user
  if $ufrc || [ "$D__OPT_ANSWER" != true ]; then
    if $ufrc; then
      printf >&2 '%s ' "$D__INTRO_CNF_U"
    else
      printf >&2 '%s ' "$D__INTRO_CNF_N"
    fi
    if ! d__prompt -b; then
      d___update_report 3
      return 1
    fi
  fi

  # Launch appropriate function; finish up
  case $umet in
    p)  d___pull_git_remote -t "bundle '$ughh'" -- "$udst";;
    c)  d___update_bundle_to_clone;;
    d)  d___update_bundle_via_dl;;
  esac
  d___update_report $? && return 0 || return 1
}

d___update_no_bundles()
{
  # Do a quick skipping dance
  local uplq="Attached bundles"
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
    return 1
  fi
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"
  d__notify -ls -- 'There are no bundles attached to the Grail directory'
  printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
  anyd=true
  return 0
}

d___update_bundle_to_clone()
{
  # Pull the repository into the temporary directory
  local utmp="$(mktemp -d)" uopt=( -Gt "bundle '$ughh'" )
  if ! d___clone_git_repo "${uopt[@]}" -- "$ughh" "$utmp"; then
    rm -rf -- "$utmp"
    return 2
  fi

  # Back up previous bundle directory
  if ! d__push_backup -- "$udst" "$D__DIR_BUNDLE_BACKUPS/$ughh.bak"; then
    d__notify -lx -- 'Failed to back up old bundle directory'
    rm -rf -- "$utmp"
    return 1
  fi

  # Move the retrieved bundle clone into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move bundle clone into place'
    rm -rf -- "$utmp"
    return 1
  fi

  # Report success
  return 0
}

d___update_bundle_via_dl()
{
  # Print forced intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_F" "$uplq"

  # Pull the repository into the temporary directory
  local utmp="$(mktemp -d)" uopt=( -$D__GH_METHOD -t "bundle '$ughh'" )
  if ! d___dl_gh_repo "${uopt[@]}" -- "$ughh" "$utmp"; then
    rm -rf -- "$utmp"
    return 2
  fi

  # Back up previous bundle directory (and capture backup path)
  if ! d__push_backup -- "$udst" "$D__DIR_BUNDLE_BACKUPS/$ughh.bak"; then
    d__notify -lx -- 'Failed to back up old bundle directory'
    rm -rf -- "$utmp"
    return 1
  fi

  # Move the retrieved bundle copy into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move new bundle copy into place'
    rm -rf -- "$utmp"
    return 1
  fi

  # Report success
  return 0
}

d__rtn_update