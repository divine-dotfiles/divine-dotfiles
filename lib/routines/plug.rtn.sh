#!/usr/bin/env bash
#:title:        Divine Bash routine: plug
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.22
#:revremark:    Shorten obliterate check in routines
#:created_at:   2019.06.26

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Replaces current Grail directory with one cloned from provided git repo or 
#. one copied from provided directory path.
#

# Marker and dependencies
readonly D__RTN_PLUG=loaded
d__load util workflow
d__load util github
d__load util backup
d__load util scan
d__load procedure offer-gh
d__load procedure check-gh

#>  d__rtn_plug
#
## Performs plugging routine.
#
d__rtn_plug()
{
  # Check if any tasks were found
  if [ ${#D__REQ_ARGS[@]} -eq 0 ]; then
    d__notify -lst 'Nothing to do' -- 'Replacement Grail not provided'
    exit 0
  fi

  $D__OPT_OBLITERATE && d__confirm_obliteration

  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'plug' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Plugging' Grail directory"
  else
    d__announce -v -- 'Plugging Grail directory'
  fi

  # Storage & status variables
  local parg pplq pdst ptmp algd=false ppcs pdcs

  # Do the deed
  d___plug_candidate
  case $? in
    0)  algd=true;;
    1)  printf >&2 '%s %s\n' "$D__INTRO_PLG_S" "$pplq";;
    2)  printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq";;
  esac

  # If plugging succeeded, sync bundles and process asset manifests
  if $algd; then
    d__load procedure sync-bundles
    d__load procedure assemble
    d__load procedure process-all-assets
  fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]
  then d__announce -s -- "'Plugged' Grail directory"; return 0
  elif $algd; then
    d__announce -v -- 'Successfully plugged Grail directory'; return 0
  else
    d__announce -x -- 'Failed to plug Grail directory'; return 1
  fi
}

d___plug_candidate()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; pplq="Grail candidate '$BOLD$parg$NORMAL'"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false ]; then return 1; fi

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_PLG_N" "$pplq"

  # Try methods until first success
  if $D__OPT_PLUG_LINK; then
    d___plug_local_dir; case $? in 0) return 0;; 1) :;; 2) return 2;; esac
  else
    d___plug_github_repo; case $? in 0) return 0;; 1) :;; 2) return 2;; esac
    d___plug_local_repo; case $? in 0) return 0;; 1) :;; 2) return 2;; esac
    d___plug_local_dir; case $? in 0) return 0;; 1) :;; 2) return 2;; esac
  fi
  return 1
}

d___plug_github_repo()
{
  # Cut-off check for Github methods
  if [ -z "$D__GH_METHOD" ]; then
    d__notify -ls -- 'Unable to interact with Github'
    return 1
  fi

  # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
  if [[ $parg =~ ^[0-9A-Za-z_.-]+$ ]]
  then parg="no-simpler/divine-bundle-$parg"
  elif [[ $parg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then :
  else
    d__notify -ls -- 'Not a valid Github repository handle'
    return 1
  fi

  # Ensure that the remote repository exists
  if ! d___gh_repo_exists "$parg"; then
    d__notify -ls -- 'Not an existing Github repository'
    return 1
  fi

  # Announce; compose destination path; print location
  pdst="$D__DIR_GRAIL"
  d__notify -l! -- 'Interpreting as Github repository' \
    -i- -t- 'Repo URL' "https://github.com/$parg"

  # Prompt for user's approval
  printf >&2 '%s ' "$D__INTRO_CNF_N"
  local ghm='Clone'; [ $D__GH_METHOD = g ] || ghm='Download'
  if ! d__prompt -p "$ghm and plug?"; then return 1; fi

  # Pull the repository into the temporary directory
  ptmp="$(mktemp -d)"; case $D__GH_METHOD in
    g)  d___clone_gh_repo "$parg" "$ptmp";;
    c)  d___curl_gh_repo "$parg" "$ptmp";;
    w)  d___wget_gh_repo "$parg" "$ptmp";;
  esac
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
    rm -rf -- "$ptmp"; return 2
  fi

  # Calculate number of deployments within the bundle
  D__EXT_DF_COUNT=0 D__EXT_DPL_COUNT=0
  d__scan_for_divinefiles --external "$ptmp" &>/dev/null
  d__scan_for_dpl_files --external "$ptmp" &>/dev/null

  # Compose success string
  ppcs="$D__EXT_DF_COUNT Divinefile"; [ $D__EXT_DF_COUNT -eq 1 ] || ppcs+='s'
  pdcs="$D__EXT_DPL_COUNT deployment"; [ $D__EXT_DPL_COUNT -eq 1 ] || pdcs+='s'
  d__notify -l! -- "Grail candidate contains $ppcs and $pdcs"

  # Back up or erase previous Grail directory
  if $D__OPT_OBLITERATE; then
    if ! rm -rf -- "$pdst" &>/dev/null; then
      d__notify -lx -- "Failed to erase old Grail directory"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      rm -rf -- "$ptmp"; return 2
    fi
  else
    if ! d__push_backup -- "$pdst" "$pdst.bak"; then
      d__notify -lx -- "Failed to back up old Grail directory"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      rm -rf -- "$ptmp"; return 2
    fi
  fi

  # Move the retrieved Grail candidate into place
  if ! mv -n -- "$ptmp" "$pdst"; then
    d__notify -lx -- "Failed to move Grail candidate into place"
    printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
    rm -rf -- "$ptmp"; return 2
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_PLG_0" "$pplq"
  return 0
}

d___plug_local_repo()
{
  # Cut-off check for Github methods
  if ! [ "$D__GH_METHOD" = g ]; then
    d__notify -ls -- 'Unable to interact with Git repositories'
    return 1
  fi

  # Ensure that the repository exists
  if ! git ls-remote "$parg" -q &>/dev/null; then
    d__notify -ls -- 'Not an existing Git repository'
    return 1
  fi

  # Announce; compose paths; print location
  parg="$( cd -- "$parg" &>/dev/null && pwd -P || exit $? )"
  if (($?)); then
    d__notify -ls -- 'Not an accessible directory'
    return 1
  fi
  pdst="$D__DIR_GRAIL"
  d__notify -l! -- 'Interpreting as Git repository' \
    -i- -t- 'Repo path' "$parg"

  # Prompt for user's approval
  printf >&2 '%s ' "$D__INTRO_CNF_N"
  if ! d__prompt -p 'Clone and plug?'; then return 1; fi

  # Pull the repository into the temporary directory
  ptmp="$(mktemp -d)"
  if ! d___clone_git_repo "$parg" "$ptmp"; then
    printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
    rm -rf -- "$ptmp"; return 2
  fi

  # Calculate number of deployments within the bundle
  D__EXT_DF_COUNT=0 D__EXT_DPL_COUNT=0
  d__scan_for_divinefiles --external "$ptmp" &>/dev/null
  d__scan_for_dpl_files --external "$ptmp" &>/dev/null

  # Compose success string
  ppcs="$D__EXT_DF_COUNT Divinefile"; [ $D__EXT_DF_COUNT -eq 1 ] || ppcs+='s'
  pdcs="$D__EXT_DPL_COUNT deployment"; [ $D__EXT_DPL_COUNT -eq 1 ] || pdcs+='s'
  d__notify -l! -- "Grail candidate contains $ppcs and $pdcs"

  # Back up or erase previous Grail directory
  if $D__OPT_OBLITERATE; then
    if ! rm -rf -- "$pdst" &>/dev/null; then
      d__notify -lx -- "Failed to erase old Grail directory"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      rm -rf -- "$ptmp"; return 2
    fi
  else
    if ! d__push_backup -- "$pdst" "$pdst.bak"; then
      d__notify -lx -- "Failed to back up old Grail directory"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      rm -rf -- "$ptmp"; return 2
    fi
  fi

  # Move the retrieved Grail candidate into place
  if ! mv -n -- "$ptmp" "$pdst"; then
    d__notify -lx -- "Failed to move Grail candidate into place"
    printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
    rm -rf -- "$ptmp"; return 2
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_PLG_0" "$pplq"
  return 0
}

d___plug_local_dir()
{
  # Ensure that the directory exists
  if ! [ -d "$parg" ]; then
    d__notify -ls -- 'Not a local directory'
    return 1
  fi

  # Announce; compose paths; print location
  parg="$( cd -- "$parg" &>/dev/null && pwd -P || exit $? )"
  if (($?)); then
    d__notify -ls -- 'Not an accessible directory'
    return 1
  fi
  pdst="$D__DIR_GRAIL"
  d__notify -l! -- 'Interpreting as local directory' \
    -i- -t- 'Dir path' "$parg"

  # Prompt for user's approval
  printf >&2 '%s ' "$D__INTRO_CNF_N"
  local ldm='Plug a copy?'; $D__OPT_PLUG_LINK && ldm='Plug via symlink?'
  if ! d__prompt -p "$ldm"; then return 1; fi

  # Calculate number of deployments within the bundle
  D__EXT_DF_COUNT=0 D__EXT_DPL_COUNT=0
  d__scan_for_divinefiles --external "$parg" &>/dev/null
  d__scan_for_dpl_files --external "$parg" &>/dev/null

  # Compose success string
  ppcs="$D__EXT_DF_COUNT Divinefile"; [ $D__EXT_DF_COUNT -eq 1 ] || ppcs+='s'
  pdcs="$D__EXT_DPL_COUNT deployment"; [ $D__EXT_DPL_COUNT -eq 1 ] || pdcs+='s'
  d__notify -l! -- "Grail candidate contains $ppcs and $pdcs"

  # Back up or erase previous Grail directory
  if $D__OPT_OBLITERATE; then
    if ! rm -rf -- "$pdst" &>/dev/null; then
      d__notify -lx -- "Failed to erase old Grail directory"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      rm -rf -- "$ptmp"; return 2
    fi
  else
    if ! d__push_backup -- "$pdst" "$pdst.bak"; then
      d__notify -lx -- "Failed to back up old Grail directory"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      rm -rf -- "$ptmp"; return 2
    fi
  fi

  # Plug with appropriate method
  if $D__OPT_PLUG_LINK; then
    if ! ln -s -- "$parg" "$pdst"; then
      d__notify -lx -- "Failed to symlink Grail candidate into place"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      return 2
  else
    if ! cp -Rn -- "$parg" "$pdst"; then
      d__notify -lx -- "Failed to copy Grail candidate into place"
      printf >&2 '%s %s\n' "$D__INTRO_PLG_1" "$pplq"
      return 2
    fi
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_PLG_0" "$pplq"
  return 0
}

#>  d___clone_git_repo REPO_SRC REPO_PATH
#
## INTERNAL USE ONLY
#
## Makes a shallow clone using Git of the Git repository at REPO_SRC into the 
#. empty/non-existent directory REPO_PATH.
#
## Returns:
#.  0 - Successfully cloned.
#.  1 - Otherwise.
#
d___clone_git_repo()
{
  d__context -- notch
  d__context -- push "Cloning Git repository: $1"
  d__context -- push "Cloning into: $2"
  d__cmd --qq-- git clone --depth=1 --REPO_SRC-- "$1" \
    --REPO_PATH-- "$2" --else-- 'Failed to clone' || return 1
  d__context -- pop
  d__context -t 'Done' -- pop 'Successfully cloned Git repository'
  d__context -- lop
  return 0
}

d__rtn_plug