#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.28
#:revremark:    Make location/URL alerts less visible
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Performs some under-the-hood modifications of the framework.
#

# Marker and dependencies
readonly D__RTN_FMWK=loaded
d__load util workflow
d__load util stash
d__load util git
d__load util backup
d__load util fmwk-update
d__load procedure prep-stash
d__load procedure prep-sys
d__load procedure offer-gh
d__load procedure check-gh

#>  d__rtn_fmwk
#
## Performs update routine.
#
## Returns:
#.  0 - Success.
#.  1 - Otherwise.
#.  1 - (script exit) Missing necessary tools.
#
d__rtn_fmwk()
{
  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'fmwk' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Tinkering' with Divine.dotfiles"
  else
    d__announce -v -- 'Tinkering with Divine.dotfiles'
  fi

  # Storage & status variables
  local tstt taa tplq

  # Parse first argument to the script
  d___dispatch_tinker_task; tstt=$?

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Finished 'tinkering' with Divine.dotfiles"
    return 0
  else
    case $tstt in
      0)  d__announce -v -- 'Successfully tinkered with Divine.dotfiles'
          return 0
          ;;
      1)  d__announce -x -- 'Failed to tinker with Divine.dotfiles'
          return 1
          ;;
      2)  d__announce -! -- 'Refused to tinker with Divine.dotfiles'
          return 0
          ;;
      3)  d__announce -s -- 'Skipped tinkering with Divine.dotfiles'
          return 0
          ;;
    esac
  fi
}

d___dispatch_tinker_task()
{
  # Check whether arguments are acceptable
  if [ ${#D__REQ_ARGS} -eq 0 ]; then
    d__notify -nlst 'Nothing to do' -- 'Task argument not provided'
    return 2
  fi

  # Extract other arguments; dispatch tinker task
  taa=("${D__REQ_ARGS[@]:1}")
  case ${D__REQ_ARGS[0]} in
    '') d__notify -nlst 'Nothing to do' -- 'Empty task argument given'
        return 2
        ;;
    d|n|de|ni|ng|dev|nig|ngh|nightly)           d___switch_to_nightly;;
    m|s|ma|ms|st|mas|mst|sta|stb|master|stable) d___switch_to_stable;;
    *)  d__notify -nlxt 'Unrecognized command' -- \
          "Tinker task '${D__REQ_ARGS[0]}' does not compute"
        return 2
        ;;
  esac; tstt=$?

  # Print plaque
  case $tstt in
    0)  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$tplq";;
    1)  printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$tplq";;
    2)  printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$tplq";;
    3)  printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$tplq";;
  esac

  # Pass the status
  return $tstt
}

d___switch_to_nightly()
{
  # Print separating empty line; set task plaque; cut-off for dry-runs
  printf >&2 '\n'
  tplq="Switching framework to ${BOLD}nightly$NORMAL build"
  [ "$D__OPT_ANSWER" = false ] && return 3

  # Cut-off check against Github methods available
  case $D__GH_METHOD in
    g)  tplq+=" (Git branch 'dev')";;
    c)  tplq+=" (curl, branch 'dev')";;
    w)  tplq+=" (wget, branch 'dev')";;
    *)  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$tplq"
        d__notify -lxt 'Unable to switch build' -- \
          'No way to access Github repository'
        return 2
        ;;
  esac

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$tplq"

  # Storage variables
  local ughh udst urtc tsst=false ungh=true umet=d ufrc=false
  ughh='no-simpler/divine-dotfiles'
  udst="$D__DIR_FMWK"

  # Store remote address; ensure that the remote repository exists
  if ! d___gh_repo_exists "$ughh"; then
    d__notify -ls -- "Github repository '$ughh' does not appear to exist"
    return 1
  fi

  # Compose destination path; check if it is accessible
  if ! pushd -- "$udst" &>/dev/null; then
    d__notify -lx -- "Framework directory is inaccessible: '$udst'"
    return 1
  fi

  # Print locations
  d__notify -ld -- "Repo URL: https://github.com/$ughh"
  d__notify -ld -- "Location: $udst"

  # Settle on method and compose prompt
  if d___path_is_gh_clone "$udst" "$ughh"; then
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Switching $D__FMWK_NAME to ${BOLD}nightly$NORMAL build"
      umet=p
    else
      d__notify -lxt 'Unable to switch' -- 'Framework is a clone' \
        'of Github remote, but Git is currently not available on the system'
      popd &>/dev/null
      return 2
    fi
  else
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Switching downloaded copy of $D__FMWK_NAME" \
        "to ${BOLD}nightly$NORMAL build" \
        'by upgrading it to a clone of its repository' \
        -n- 'Current framework directory will be kept'
      umet=c
    else
      if $D__OPT_FORCE; then
        d__notify -l! -- "Switching downloaded copy of $D__FMWK_NAME" \
          "to ${BOLD}nightly$NORMAL build" \
          'by re-downloading latest copy' \
          -n- 'Current framework directory will be kept'
        umet=d ufrc=true
      else
        d__notify -lx -- "The only avenue of switching $D__FMWK_NAME" \
          "to ${BOLD}nightly$NORMAL build" \
          'is to re-download latest copy'
        d__notify -l! -- 'Re-try with --force to overcome'
        popd &>/dev/null
        return 2
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
      popd &>/dev/null
      return 3
    fi
  fi

  # Check for stash record, set it if necessary
  if d__stash -rs -- has 'nightly'; then
    d__notify -ls -- 'Stash key is already set; ensuring compliance'
  else
    if d__stash -rs -- set 'nightly'; then
      tsst=true
      d__notify -lv -- 'Set stash key'
    else
      d__notify -lx -- 'Failed to set stash key'
      popd &>/dev/null
      return 1
    fi
  fi

  # Launch appropriate function; finish up
  case $umet in
    p)  d___update_fmwk_via_pull;;
    c)  d___update_fmwk_to_clone;;
    d)  d___update_fmwk_via_dl;;
  esac; urtc=$?

  # Finish up based on results
  if (($urtc)) && $tsst; then
    if d__stash -rs -- unset 'nightly'; then
      d__notify -lv -- 'Unset stash key'
    else
      d__notify -lx -- 'Failed to unset stash key'
    fi
  fi
  popd &>/dev/null
  return $urtc
}

d___switch_to_stable()
{
  # Print separating empty line; set task plaque; cut-off for dry-runs
  printf >&2 '\n'
  tplq="Switching framework to ${BOLD}stable$NORMAL build"
  [ "$D__OPT_ANSWER" = false ] && return 3

  # Cut-off check against Github methods available
  case $D__GH_METHOD in
    g)  tplq+=" (Git branch 'master')";;
    c)  tplq+=" (curl, branch 'master')";;
    w)  tplq+=" (wget, branch 'master')";;
    *)  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$tplq"
        d__notify -lxt 'Unable to switch build' -- \
          'No way to access Github repository'
        return 2
        ;;
  esac

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$tplq"

  # Storage variables
  local ughh udst urtc tsst=false ungh=false umet=d ufrc=false
  ughh='no-simpler/divine-dotfiles'
  udst="$D__DIR_FMWK"

  # Store remote address; ensure that the remote repository exists
  if ! d___gh_repo_exists "$ughh"; then
    d__notify -ls -- "Github repository '$ughh' does not appear to exist"
    return 1
  fi

  # Compose destination path; check if it is accessible
  if ! pushd -- "$udst" &>/dev/null; then
    d__notify -lx -- "Framework directory is inaccessible: '$udst'"
    return 1
  fi

  # Print locations
  d__notify -ld -- "Repo URL: https://github.com/$ughh"
  d__notify -ld -- "Location: $udst"

  # Settle on method and compose prompt
  if d___path_is_gh_clone "$udst" "$ughh"; then
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Switching $D__FMWK_NAME to ${BOLD}stable$NORMAL build"
      umet=p
    else
      d__notify -lxt 'Unable to switch' -- 'Framework is a clone' \
        'of Github remote, but Git is currently not available on the system'
      popd &>/dev/null
      return 2
    fi
  else
    if [ "$D__GH_METHOD" = g ]; then
      d__notify -l! -- "Switching downloaded copy of $D__FMWK_NAME" \
        "to ${BOLD}stable$NORMAL build" \
        'by upgrading it to a clone of its repository' \
        -n- 'Current framework directory will be kept'
      umet=c
    else
      if $D__OPT_FORCE; then
        d__notify -l! -- "Switching downloaded copy of $D__FMWK_NAME" \
          "to ${BOLD}stable$NORMAL build" \
          'by re-downloading latest copy' \
          -n- 'Current framework directory will be kept'
        umet=d ufrc=true
      else
        d__notify -lx -- "The only avenue of switching $D__FMWK_NAME" \
          "to ${BOLD}stable$NORMAL build" \
          'is to re-download latest copy'
        d__notify -l! -- 'Re-try with --force to overcome'
        popd &>/dev/null
        return 2
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
      popd &>/dev/null
      return 3
    fi
  fi

  # Check for stash record, set it if necessary
  if d__stash -rs -- has 'nightly'; then
    if d__stash -rs -- unset 'nightly'; then
      tsst=true
      d__notify -lv -- 'Unset stash key'
    else
      d__notify -lx -- 'Failed to unset stash key'
      popd &>/dev/null
      return 1
    fi
  else
    d__notify -ls -- 'Stash key is already unset; ensuring compliance'
  fi

  # Launch appropriate function; finish up
  case $umet in
    p)  d___update_fmwk_via_pull;;
    c)  d___update_fmwk_to_clone;;
    d)  d___update_fmwk_via_dl;;
  esac; urtc=$?

  # Finish up based on results
  if (($urtc)) && $tsst; then
    if d__stash -rs -- set 'nightly'; then
      d__notify -lv -- 'Set stash key'
    else
      d__notify -lx -- 'Failed to set stash key'
    fi
  fi
  popd &>/dev/null
  return $urtc
}

d__rtn_fmwk