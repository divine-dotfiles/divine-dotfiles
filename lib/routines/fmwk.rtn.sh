#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.02
#:revremark:    Rename local vars in tinker routine to be compatible with update
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
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
  local ustt arga uplq

  # Parse first argument to the script
  d___dispatch_tinker_task; ustt=$?

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Finished 'tinkering' with Divine.dotfiles"
    return 0
  else
    case $ustt in
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
  arga=("${D__REQ_ARGS[@]:1}")
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
  esac; ustt=$?

  # Print plaque
  case $ustt in
    0)  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq";;
    1)  printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq";;
    2)  printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq";;
    3)  printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq";;
  esac

  # Pass the status
  return $ustt
}

d___switch_to_nightly()
{
  # Print separating empty line; set task plaque; cut-off for dry-runs
  printf >&2 '\n'
  uplq="Switching framework to ${BOLD}nightly$NORMAL build"
  [ "$D__OPT_ANSWER" = false ] && return 3

  # Cut-off check against Github methods available
  case $D__GH_METHOD in
    g)  uplq+=" (Git branch 'dev')";;
    c)  uplq+=" (curl, branch 'dev')";;
    w)  uplq+=" (wget, branch 'dev')";;
    *)  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"
        d__notify -lxt 'Unable to switch build' -- \
          'No way to access Github repository'
        return 2
        ;;
  esac

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"

  # Storage variables
  local ughh udst urtc tsst=false ungh=true umet=d ufrc=false
  ughh='divine-dotfiles/divine-dotfiles'
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

  # Compose path to transition-from-version and untransitioned-version files
  local mntv="$D__DIR_STATE/$D__CONST_NAME_MNTRS" ervt= uvrs
  local untv="$D__DIR_STATE/$D__CONST_NAME_UNTRS"

  # Extract previous version
  local ovrs="$D__FMWK_VERSION"

  # Settle on method and compose prompt; check if special files are present
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
  if [ -f "$untv" ]; then
    ervt=u
    read -r uvrs <"$untv"
    d__notify -l! -- "Found record of failed update from version '$uvrs'"
  elif [ -f "$mntv" ]; then
    ervt=m
    read -r uvrs <"$mntv"
    d__notify -l! -- "Found directive to transition from version '$uvrs'"
  fi
  if [ -n "$ervt" ]; then
    if $D__OPT_FORCE; then
      ufrc=true
    else
      d__notify -l! -- 'Re-try with --force to overcome'
      popd &>/dev/null
      return 2
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

  # Launch appropriate function; save return code
  case $umet in
    p)  d___update_fmwk_via_pull;;
    c)  d___update_fmwk_to_clone;;
    d)  d___update_fmwk_via_dl;;
  esac; urtc=$?

  # Analyze return code
  if (($urtc)); then
    if [ "$urtc" -eq 1 ]; then
      [ -f "$untv" ] || printf >"$untv" '%s\n' "$ovrs"
    fi
    if $tsst; then
      if d__stash -rs -- unset 'nightly'; then
        d__notify -lv -- 'Unset stash key'
      else
        d__notify -lx -- 'Failed to unset stash key'
      fi
    fi
    popd &>/dev/null
    return $urtc
  else
    [ -n "$ervt" ] && ovrs="$uvrs"
  fi

  # Extract now-current version
  local nvrs invl
  while read -r invl || [[ -n "$invl" ]]; do
    [[ $invl = 'readonly D__FMWK_VERSION='* ]] || continue
    IFS='=' read -r invl nvrs <<<"$invl "
    if [[ $nvrs = \'*\'\  || $nvrs = \"*\"\  ]]
    then read -r nvrs <<<"${nvrs:1:${#nvrs}-3}"
    else read -r nvrs <<<"$nvrs"; fi
    break
  done <"$D__PATH_INIT_VARS"

  # Initiate transitions; delete marker files; wrap up
  d___apply_transitions; urtc=$?
  case $ervt in
    u)  rm -f -- "$untv" || d__notify -lx -- "Failed to remove: $untv";;
    m)  rm -f -- "$mntv" || d__notify -lx -- "Failed to remove: $mntv";;
    *)  :;;
  esac
  popd &>/dev/null
  return $urtc
}

d___switch_to_stable()
{
  # Print separating empty line; set task plaque; cut-off for dry-runs
  printf >&2 '\n'
  uplq="Switching framework to ${BOLD}stable$NORMAL build"
  [ "$D__OPT_ANSWER" = false ] && return 3

  # Cut-off check against Github methods available
  case $D__GH_METHOD in
    g)  uplq+=" (Git branch 'master')";;
    c)  uplq+=" (curl, branch 'master')";;
    w)  uplq+=" (wget, branch 'master')";;
    *)  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"
        d__notify -lxt 'Unable to switch build' -- \
          'No way to access Github repository'
        return 2
        ;;
  esac

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"

  # Storage variables
  local ughh udst urtc tsst=false ungh=false umet=d ufrc=false
  ughh='divine-dotfiles/divine-dotfiles'
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