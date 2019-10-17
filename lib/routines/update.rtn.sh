#!/usr/bin/env bash
#:title:        Divine Bash routine: update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.17
#:revremark:    Split prep-gh in two
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
d__load util github
d__load util backup
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

  # Storage & status variables
  local uarg udst uplq utmp ufmk=false ugrl=false ubdl=false ubdla=()
  local uanys=false uanyf=false uanyd=false uanyn=false usc=0

  # Parse update arguments
  d___parse_update_args

  # Perform updates in order
  for uarg in fmk grl; do
    d___update_$uarg
    case $? in
      0)  uanys=true;; # Success
      1)  uanyf=true;; # Failure
      2)  uanyd=true;; # Declined
      3)  uanyn=true;; # Not chosen
    esac
  done
  d___update_bdls

  # Count statuses
  $uanys && ((++usc)); $uanyf && ((++usc))
  $uanyd && ((++usc)); $uanyn && ((++usc))

  # If any updates succeeded, process asset manifests
  if $uanys; then d__load procedure process-all-assets; fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Finished 'updating' Divine.dotfiles"; return 0
  elif [ $usc -eq 1 ] || ( [ $usc -eq 2 ] && $uanyn ); then
    if $uanys
    then d__announce -v -- 'Successfully updated Divine.dotfiles'; return 0
    elif $uanyf
    then d__announce -x -- 'Failed to update Divine.dotfiles'; return 1
    elif $uanyd
    then d__announce -s -- 'Declined to update Divine.dotfiles'; return 0
    elif $uanyn
    then d__announce -s -- 'Skipped updating Divine.dotfiles'; return 0; fi
  elif [ $usc -eq 2 ]; then
    if $uanys && $uanyf
    then d__announce -! -- 'Partly updated Divine.dotfiles'; return 1
    elif $uanys && $uanyd
    then d__announce -v -- 'Partly updated Divine.dotfiles'; return 0
    elif $uanyf && $uanyd
    then d__announce -x -- 'Failed to update Divine.dotfiles'; return 1; fi
  elif [ $usc -eq 3 ]; then
    if ! $uanys
    then d__announce -x -- 'Failed to update Divine.dotfiles'; return 1
    elif ! $uanyf
    then d__announce -v -- 'Partly updated Divine.dotfiles'; return 0
    elif ! $uanyd
    then d__announce -! -- 'Partly updated Divine.dotfiles'; return 1
    elif ! $uanyn
    then d__announce -! -- 'Partly updated Divine.dotfiles'; return 1; fi
  else
    d__announce -! -- 'Partly updated Divine.dotfiles'; return 1
  fi
}

d___parse_update_args()
{
  # If given a list of bundles, update just them by default
  if ((${#D__REQ_BUNDLES[@]}))
  then ubdl=true ubdla=("${D__REQ_BUNDLES[@]}"); fi

  # Parse update arguments
  if [ ${#D__REQ_ARGS[@]} -eq 0 ]; then
    if ! $ubdl; then ufmk=true ugrl=true ubdl=true; fi
  else for uarg in "${D__REQ_ARGS[@]}"; do case $uarg in
    a|al|all)       ufmk=true ugrl=true ubdl=true;;
    f|fr|fm|fmwk)   ufmk=true;;
    framework)      ufmk=true;;
    g|gr|grail)     ugrl=true;;
    b|bu|bundles)   ubdl=true;;
    bd|bdl|bdls)    ubdl=true;;
    d|dp|dpl|dpls)  ubdl=true;;
    deployment)     ubdl=true;;
    deployments)    ubdl=true;;
    *)              :;;
  esac; done; fi

  # If updating bundles, but not having a list yet, pull from stash
  if $ubdl && [ ${#ubdla[@]} -eq 0 ]; then
    if d__stash -gs -- has attached_bundles; then
      while read -r uarg; do ubdla+=("$uarg")
      done < <( d__stash -gs -- list attached_bundles )
    fi
  fi
}

d___update_fmk()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; uplq="$BOLD$D__FMWK_NAME$NORMAL framework"

  # Cut-off
  if ! $ufmk; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "(not selected) $uplq"
    return 3
  fi
  if [ "$D__OPT_ANSWER" = false ]
  then printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"; return 3; fi

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"

  # Store remote address; ensure that the remote repository exists
  uarg='no-simpler/divine-dotfiles'
  if ! d___gh_repo_exists "$uarg"; then
    d__notify -ls -- "Github repository '$uarg' does not appear to exist"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"; return 1
  fi

  # Compose destination path; print location
  udst="$D__DIR_FMWK"
  d__notify -q -- "Repo URL: https://github.com/$uarg"
  d__notify -q -- "Location: $udst"

  # Check if framework directory is a cloned Github repository
  if d___path_is_gh_clone "$udst" "$uarg"; then
    if [ "$D__GH_METHOD" = g ]
    then d___update_fmk_via_pull; return $?
    else
      d__notify -lxt 'Unable to update' -- 'Framework is a clone' \
        'of Github remote, but Git is currently not available on the system'
      printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"
      return 1
    fi
  else
    if [ "$D__GH_METHOD" = g ]
    then d___upgrade_fmk_to_git; return $?
    else d___crude_update_fmk; return $?; fi
  fi
}

d___update_fmk_via_pull()
{
  # Notify and perform excellently
  d__notify -- 'Updating by pulling from Github remote'
  if ! d___pull_updates_from_gh "$uarg" "$udst"; then
    d__notify -lx -- "Failed to pull updates from Github remote"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"; return 1
  fi
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"; return 0
}

d___upgrade_fmk_to_git()
{
  # Announce; compose destination path; print location
  d__notify -l! -- 'Replacing current framework copy with Github clone' \
    -i- -t- 'Repo URL' "https://github.com/$uarg" \
    -n- 'Current framework directory will be kept'

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b
    then printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"; return 2; fi
  fi

  # Pull the repository into the temporary directory
  utmp="$(mktemp -d)"; d___clone_gh_repo "$uarg" "$utmp"
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Back up previous framework directory (and capture backup path)
  local d__bckp=; if ! d__push_backup -- "$udst" "$udst.bak"; then
    d__notify -lx -- 'Failed to back up old framework directory'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Move the retrieved framework clone into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move framework clone into place'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Return Grail and state directories
  local erra=() src="$d__bckp/grail" dst="$udst/grail"
  if ! mv -n -- "$src" "$dst"
  then erra+=( -i- "- Grail directory" ); fi
  src="$d__bckp/state" dst="$udst/state"
  if ! mv -n -- "$src" "$dst"
  then erra+=( -i- "- state directory" ); fi
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to restore directories after upgrading' \
      'framework to Github clone:' "${erra[@]}"
    d__notify l! -- 'Please, move the directories manually from:' \
      -i- "$d__bckp" -n- 'to:' -i- "$udst"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    return 0
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"
  return 0
}

d___crude_update_fmk()
{
  # Only proceed in force mode
  if $D__OPT_FORCE; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_F" "$uplq"
  else
    d__notify -l! -- 'The only avenue of updating framework seems to be' \
      'to re-download a new copy from Github'
    d__notify -l! -- "Re-try with --force to perform such 'crude' update"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"
    return 1
  fi

  # Announce; compose destination path; print location
  d__notify -l! -- 'Downloading a new copy of the framework from Github' \
    -i- -t- 'Repo URL' "https://github.com/$uarg" \
    -n- 'Current framework directory will be kept'

  # Conditionally prompt for user's approval
  printf >&2 '%s ' "$D__INTRO_CNF_U"
  if ! d__prompt -b
  then printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"; return 2; fi

  # Pull the repository into the temporary directory
  utmp="$(mktemp -d)"; case $D__GH_METHOD in
    c)  d___curl_gh_repo "$uarg" "$utmp";;
    w)  d___wget_gh_repo "$uarg" "$utmp";;
  esac
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Back up previous framework directory (and capture backup path)
  local d__bckp=; if ! d__push_backup -- "$udst" "$udst.bak"; then
    d__notify -lx -- 'Failed to back up old framework directory'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Move the retrieved framework copy into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move new framework copy into place'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Return Grail and state directories
  local erra=() src="$d__bckp/grail" dst="$udst/grail"
  if ! mv -n -- "$src" "$dst"
  then erra+=( -i- "- Grail directory" ); fi
  src="$d__bckp/state" dst="$udst/state"
  if ! mv -n -- "$src" "$dst"
  then erra+=( -i- "- state directory" ); fi
  if ((${#erra[@]})); then
    d__notify -lx -- "Failed to restore directories after 'crudely' updating" \
      'framework:' "${erra[@]}"
    d__notify l! -- 'Please, move the directories manually from:' \
      -i- "$d__bckp" -n- 'to:' -i- "$udst"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    return 0
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"
  return 0
}

d___update_grl()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; uplq="The ${BOLD}Grail$NORMAL directory"

  # Cut-off checks
  if ! $ugrl; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "(not selected) $uplq"
    return 3
  fi
  if [ "$D__OPT_ANSWER" = false ]
  then printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"; return 3; fi

  # Cut-off check against git
  if ! [ "$D__GH_METHOD" = g ]; then
    d__notify -lx -- 'Unable to check status of Grail directory' \
      'because current system does not have Git'
    return 1
  fi

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"

  # Check if framework directory is a git repository
  if ! git ls-remote "$D__DIR_GRAIL" -q &>/dev/null; then
    d__notify -ls -- 'Grail directory is not a Git repository'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
    return 3
  fi

  # Check if Grail directory is accessible
  if ! pushd -- "$D__DIR_GRAIL" &>/dev/null; then
    d__notify -lx -- 'Grail directory is inaccessible'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    return 1
  fi

  # Check if Grail repository has 'origin' remote
  if ! git remote 2>/dev/null | grep -Fxq origin &>/dev/null; then
    d__notify -lx -- 'Grail repository does not have a remote to pull from'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
    popd &>/dev/null; return 3
  fi

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b
    then
      printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"
      popd &>/dev/null; return 2
    fi
  fi

  # Pull and rebase with verbosity in mind
  d__notify -- 'Updating by pulling from Git remote'
  if (($D__OPT_VERBOSITY)); then local d__ol
    git pull --rebase --stat origin master 2>&1 \
      | while IFS= read -r d__ol || [ -n "$d__ol" ]
        do printf >&2 '%s\n' "${CYAN}$d__ol${NORMAL}"; done
  else git pull --rebase --stat origin master &>/dev/null; fi

  # Check status
  if ((${PIPESTATUS[0]})); then
    d__notify -lx -- 'Git returned error code while pulling from remote into' \
      'Grail repository'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    popd &>/dev/null; return 1
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"
  popd &>/dev/null; return 0
}

d___update_bdls()
{
  # Compose task name; if not updating bundles, skip gracefully
  uplq="Attached ${BOLD}bundles$NORMAL"
  if ! $ubdl; then
    printf >&2 '\n%s %s\n' "$D__INTRO_UPD_S" "(not selected) $uplq"
    uanyn=true; return 0
  fi
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '\n%s %s\n' "$D__INTRO_UPD_S" "$uplq"
    uanyn=true; return 0
  fi

  # If list of bundles is empty, then there are certainly no attached bundles
  if [ ${#ubdla[@]} -eq 0 ]; then
    printf >&2 '\n%s %s\n' "$D__INTRO_UPD_S" \
      "There are no attached ${BOLD}bundles$NORMAL"
    uanyn=true; return 0
  fi

  # Update bundles sequentially
  for uarg in "${ubdla[@]}"; do
    d___update_bdl
    case $? in 0) uanys=true;; 1) uanyf=true;; 2) uanyd=true;; esac
  done
}

d___update_bdl()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; uplq="Bundle '$BOLD$uarg$NORMAL'"

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_N" "$uplq"

  # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
  if [[ $uarg =~ ^[0-9A-Za-z_.-]+$ ]]
  then uarg="no-simpler/divine-bundle-$uarg"
  elif [[ $uarg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then :
  else
    d__notify -lx -- "Invalid bundle identifier '$uarg'"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"; return 1
  fi

  # Ensure that the remote repository exists
  if ! d___gh_repo_exists "$uarg"; then
    d__notify -lx -- "Github repository '$uarg' does not appear to exist"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"; return 1
  fi

  # Compose destination path; print location
  udst="$D__DIR_BUNDLES/$uarg"
  d__notify -q -- "Repo URL: https://github.com/$uarg"
  d__notify -q -- "Location: $udst"

  # Check if bundle directory is a cloned Github repository
  if d___path_is_gh_clone "$udst" "$uarg"; then
    if [ "$D__GH_METHOD" = g ]
    then d___update_bdl_via_pull; return $?
    else
      d__notify -lxt 'Unable to update' -- 'Bundle is a clone' \
        'of Github remote, but Git is currently not available on the system'
      printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"
      return 1
    fi
  else
    if [ "$D__GH_METHOD" = g ]
    then d___upgrade_bdl_to_git; return $?
    else d___crude_update_bdl; return $?; fi
  fi
}

d___update_bdl_via_pull()
{
  # Notify and perform excellently
  d__notify -- 'Updating by pulling from Github remote'
  if ! d___pull_updates_from_gh "$uarg" "$udst"; then
    d__notify -lx -- "Failed to pull updates from Github remote"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"; return 1
  fi
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"; return 0
}

d___upgrade_bdl_to_git()
{
  # Announce; compose destination path; print location
  d__notify -l! -- 'Replacing current bundle copy with Github clone' \
    -i- -t- 'Repo URL' "https://github.com/$uarg" \
    -n- "Current bundle directory will be kept"

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -b
    then printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"; return 2; fi
  fi

  # Pull the repository into the temporary directory
  utmp="$(mktemp -d)"; d___clone_gh_repo "$uarg" "$utmp"
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Back up previous bundle directory
  if ! d__push_backup -- "$udst" "$D__DIR_BUNDLE_BACKUPS/$uarg.bak"; then
    d__notify -lx -- 'Failed to back up old bundle directory'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Move the retrieved bundle clone into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move bundle clone into place'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"
  return 0
}

d___crude_update_bdl()
{
  # Only proceed in force mode
  if $D__OPT_FORCE; then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_F" "$uplq"
  else
    d__notify -l! -- "The only avenue of updating bundle '$uarg' seems to be" \
      'to re-download a new copy from Github'
    d__notify -l! -- "Re-try with --force to perform such 'crude' update"
    printf >&2 '%s %s\n' "$D__INTRO_UPD_2" "$uplq"
    return 1
  fi

  # Announce; compose destination path; print location
  d__notify -l! -- 'Downloading a new copy of the bundle from Github' \
    -i- -t- 'Repo URL' "https://github.com/$uarg" \
    -n- "Current bundle directory will be kept"

  # Conditionally prompt for user's approval
  printf >&2 '%s ' "$D__INTRO_CNF_U"
  if ! d__prompt -b
  then printf >&2 '%s %s\n' "$D__INTRO_UPD_S" "$uplq"; return 2; fi

  # Pull the repository into the temporary directory
  utmp="$(mktemp -d)"; case $D__GH_METHOD in
    c)  d___curl_gh_repo "$uarg" "$utmp";;
    w)  d___wget_gh_repo "$uarg" "$utmp";;
  esac
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Back up previous bundle directory
  if ! d__push_backup -- "$udst" "$D__DIR_BUNDLE_BACKUPS/$uarg.bak"; then
    d__notify -lx -- 'Failed to back up old bundle directory'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Move the retrieved bundle copy into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move new bundle copy into place'
    printf >&2 '%s %s\n' "$D__INTRO_UPD_1" "$uplq"
    rm -rf -- "$utmp"; return 1
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_UPD_0" "$uplq"
  return 0
}

d__rtn_update