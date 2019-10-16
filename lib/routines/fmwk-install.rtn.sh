#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk-install
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.16
#:revremark:    Delay shortcut name check in fmwk installation
#:created_at:   2019.10.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Installs Divine.dotfiles framework and shortcut command.
#

# Marker and dependencies
readonly D__RTN_FMWK_INSTALL=loaded
d__load util workflow
d__load util stash
d__load util github
d__load util backup
d__load procedure prep-gh

#>  d__rtn_fmwk_install
#
## Performs framework installation routine.
#
## Returns:
#.  0 - Success.
#.  1 - Otherwise.
#
d__rtn_fmwk_install()
{
  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'fmwk-install' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "'Installing' Divine.dotfiles"
  else
    d__announce -v -- 'Installing Divine.dotfiles'
  fi

  # Storage & status variables
  local irc=2 iplq iarg idst ifrc=false iocc=false iemp=false itmp iaok=true
  local idir iadir snm scnm sdir sdst stgt sgd=false erra

  # Perform structured installation
  if d___get_ready; then
    if d___install_fmwk; then d___install_shortcut; irc=0
    else irc=$?; fi
  fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    d__announce -s -- "Finished 'installing' Divine.dotfiles"; return 0
  else case $irc in
    0)  d__announce -v -- 'Successfully installed Divine.dotfiles'
        d___send_pictures; return 0;;
    1)  d__announce -x -- 'Failed to install Divine.dotfiles'; return 1;;
    2)  d__announce -s -- 'Declined to install Divine.dotfiles'; return 2;;
  esac; fi
}

d___get_ready()
{
  # Compose task name; print intro with a separating empty line
  iplq='Pre-flight checks'; printf >&2 '\n%s %s\n' "$D__INTRO_CHK_N" "$iplq"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$iplq"; return 0
  fi

  # Run checks on framework and shortcut
  d___pfc_fmwk
  d___pfc_shct

  # Report
  if $iaok; then printf >&2 '%s %s\n' "$D__INTRO_SUCCS" "$iplq"; return 0
  else printf >&2 '%s %s\n' "$D__INTRO_FAILR" "$iplq"; return 1; fi
}

d___pfc_fmwk()
{
  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false ]; then return 0; fi

  # Store remote address; ensure that the remote repository exists
  iarg='no-simpler/divine-dotfiles'
  if ! d___gh_repo_exists "$iarg"; then iaok=false
    d__notify -lx -- "Github repository '$iarg' does not appear to exist"
  fi

  # Compose destination path
  idst="$D__DIR_FMWK"

  # Check if destination already exists, and if so, what is it
  if [ -e "$idst" ]; then
    if ! [ -d "$idst" ]; then iocc=true
      d__notify -l! -- 'Framework installation path is occupied by a file:' \
        -i- "$idst"
    elif [ -n "$( ls -Aq -- "$idst" 2>/dev/null )" ]; then iocc=true
      d__notify -l! -- 'Framework installation directory already exists:' \
        -i- "$idst"
    else iemp=true
      d__notify -- 'Empty directory exists at framework installation path:' \
        -i- "$idst"
    fi
  fi

  # Cut-off check for occupied installation path
  if $iocc; then
    if $D__OPT_FORCE; then ifrc=true
    else iaok=false; d__notify -l! -- 'Re-try with --force to overcome'; fi
  fi
}

d___pfc_shct()
{
  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false -o "$D__OPT_ANSWER_S" = false ]
  then return 0; fi

  # Check that shortcut name is legal
  if ! [[ $D__SHORTCUT_NAME =~ ^[A-Za-z0-9]+$ ]]; then iaok=false
    d__notify -l! -- "Chosen shortcut name '$D__SHORTCUT_NAME'" \
      'is illegal (alphanumerical characters only)'
    return 1
  fi

  # Settle on installation directory for the shortcut
  d__notify 'Choosing shortcut installation directory'
  for sdir in "${D__SHORTCUT_DIR_CANDIDATES[@]}"; do
    if ! [[ *:$sdir:* = :$PATH: ]]; then
      d__notify -- "Skipping candidate '$sdir' (not on \$PATH)"; continue
    fi
    if ! [ -d "$sdir" ]; then
      d__notify -- "Skipping candidate '$sdir' (not a directory)"; continue
    fi
    if ! [ -w "$sdir" ]; then
      d__notify -- "Skipping candidate '$sdir' (not writable)"; continue
    fi
    if [ -e "$sdir/$snm" ]; then
      d__notify -- "Skipping candidate '$sdir'" \
        "(file named '$snm' already exists in it)"
      continue
    fi
    sdst="$sdir/$snm"; break
  done

  # Ensure a directory has been chosen
  if [ -z "$sdst" ]; then iaok=false
    d__notify -lx -- 'Unable to find a writable shortcut installation' \
      'directory among candidates'
  fi

  # Perform further checks only if all good up until here
  $iaok || return 1

  # If shortcut name is occupied on $PATH, re-prompt until found good one
  if type -P -- "$D__SHORTCUT_NAME" &>/dev/null; then iaok=false
    d__notify -l! -- "Chosen shortcut name '$D__SHORTCUT_NAME'" \
      'already exists on \$PATH'
    [ "$D__OPT_ANSWER_S" = true ] && return 1
    while true; do read -r -p "Try another? ('q' to quit) " scnm
      [ "$scnm" = q ] && return 1
      if ! [[ $scnm =~ ^[A-Za-z0-9]+$ ]]
      then printf >&2 '%s\n' 'Alphanumerical characters only'; continue; fi
      if type -P -- "$scnm" &>/dev/null
      then printf >&2 '%s\n' 'Already exists on $PATH'; continue; fi
      snm="$scnm"; break
    done
  else snm="$D__SHORTCUT_NAME"; fi
}

d___install_fmwk()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; iplq="$BOLD$D__FMWK_NAME$NORMAL framework"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$iplq"; return 2
  fi

  # Print intro; print locations
  printf >&2 '%s %s\n' "$D__INTRO_INS_N" "$iplq"
  d__notify -q -- "Repo URL: https://github.com/$iarg"
  d__notify -q -- "Location: $idst"

  # Conditionally prompt for user's approval
  if $ifrc; then
    printf >&2 '%s ' "$D__INTRO_CNF_U"
    if ! d__prompt -bp 'Back up & install anew?'
    then printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$iplq"; return 1; fi
  elif [ "$D__OPT_ANSWER_F" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -bp 'Install?'
    then printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$iplq"; return 1; fi
  fi

  # Pull the repository into the temporary directory
  itmp="$(mktemp -d)"; case $D__GH_METHOD in
    g)  d___clone_gh_repo "$iarg" "$itmp";;
    c)  d___curl_gh_repo "$iarg" "$itmp";;
    w)  d___wget_gh_repo "$iarg" "$itmp";;
  esac
  if (($?)); then
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    rm -rf -- "$itmp"; return 1
  fi

  # Pre-erase empty directory at installation path
  if $iemp && ! rm -rf -- "$idst" &>/dev/null; then
    d__notify -lx -- 'Failed to erase empty directory at:' -i- "$idst"
    rm -rf -- "$itmp"; return 1
  fi

  # Back up previous framework directory
  if ! d__push_backup -- "$idst" "$idst.bak"; then
    d__notify -lx -- 'Failed to back up old framework directory'
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    rm -rf -- "$itmp"; return 1
  fi

  # Move the retrieved framework into place
  if ! mv -n -- "$itmp" "$idst"; then
    d__notify -lx -- 'Failed to move framework directory into place'
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    rm -rf -- "$itmp"; return 1
  fi

  # Compile list of directories to create; create them, or report error
  iadir=( \
    "$D__DIR_ASSETS" "$D__DIR_DPLS" "$D__DIR_BACKUPS" \
    "$D__DIR_STASH" "$D__DIR_BUNDLES" "$D__DIR_BUNDLE_BACKUPS" \
  )
  for idir in "${iadir[@]}"; do
    if ! mkdir -p -- "$idir" &>/dev/null; then erra+=( -i- "$idir" ); fi
  done
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to create framework directories:' "${erra[@]}"
    return 0
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_INS_0" "$iplq"
  return 0
}

d___install_shortcut()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; iplq="Shortcut command '$BOLD$snm$NORMAL'"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_S" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$iplq"; return 2
  fi

  # Compose target; print intro; print locations
  sdst="$D__DIR_FMWK/intervene.sh"
  printf >&2 '%s %s\n' "$D__INTRO_INS_N" "$iplq"
  d__notify -q -- "Location: $sdst"
  d__notify -q -- "Target  : $stgt"

  # Install shortcut
  if ! ln -s -- "$stgt" "$sdst" &>/dev/null; then
    d__notify -lx -- "Failed to create symlink at: '$sdst'"
    printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$iplq"
    return 1
  fi

  # Set stash record
  if d__stash -r -- set di_shortcut "$sdst"; then
    d__notify -- "Recorded installing shortcut to root stash"
  else
    d__notify -lx -- "Failed to record installing shortcut to root stash"
  fi

  # Report success
  printf >&2 '%s %s\n' "$D__INTRO_INS_0" "$iplq"
  sgd=true; return 0
}

d___send_pictures()
{
  # Print empty line for visual separation; compose main command for output
  printf >&2 '\n'; local mcmd
  if $sgd; then mcmd="$snm"
  else mcmd="$D__DIR_FMWK/intervene.sh"; fi

  # Print plaque
  cat <<EOF
${REVERSE}- ${BOLD}D i v i n e . d o t f i l e s${NORMAL}${REVERSE} -${NORMAL}
     ${GREEN}${REVERSE}${BOLD} i n s t a l l e d ${NORMAL}
             ${GREEN}${REVERSE}-_-${NORMAL}

Have you heard the good news?
You can now access ${BOLD}Divine.dotfiles${NORMAL} in shell using:
    $ $BOLD$mcmd$NORMAL

For help, try:
    ${BOLD}https://github.com/no-simpler/divine-dotfiles${NORMAL}
    ...or $BOLD$D__DIR_FMWK/README.adoc$NORMAL
    ...or $ $BOLD$mcmd --help$NORMAL

Your personal deployments and assets go into Grail directory at:
    $BOLD$D__DIR_FMWK/grail$NORMAL
(It is a good idea to take your Grail under version control)

For a joy ride, try our bundled Divine deployments using:
    $ $BOLD$mcmd attach essentials$NORMAL && $BOLD$mcmd install$NORMAL
(More info on these at: https://github.com/no-simpler/divine-bundle-essentials)
    
Thank you, and have a safe and productive day.
EOF

  # Return success
  return 0
}

d__rtn_fmwk_install