#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk-uninstall
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.16
#:revremark:    Make fmwk (un)installation available offline
#:created_at:   2019.10.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Uninstalls Divine.dotfiles framework and shortcut command.
#

# Marker and dependencies
readonly D__RTN_FMWK_UNINSTALL=loaded
d__load util workflow
d__load util stash
d__load util backup

#>  d__rtn_fmwk_uninstall
#
## Performs framework uninstallation routine.
#
## Returns:
#.  0 - Success.
#.  1 - Otherwise.
#
d__rtn_fmwk_uninstall()
{
  # Print a separating empty line, switch context
  printf >&2 '\n'
  d__context -- notch
  d__context -- push "Performing 'fmwk-uninstall' routine"

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ] || [ "$D__OPT_ANSWER_F" = false ]; then
    d__announce -s -- "'Uninstalling' Divine.dotfiles"
  else
    d__announce -v -- 'Uninstalling Divine.dotfiles'
  fi

  # Storage & status variables
  local urc=2 uplq udst sdst erra ubrw utlc=0 utl utla

  # Perform structured installation
  if d___get_ready; then
    if d___uninstall_utils; then d___uninstall_fmwk; urc=$?
    else urc=1; fi
  fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ] || [ "$D__OPT_ANSWER_F" = false ]; then
    d__announce -s -- "Finished 'uninstalling' Divine.dotfiles"; return 0
  else case $urc in
    0)  d__announce -v -- 'Successfully uninstalled Divine.dotfiles'
        d___send_pictures; return 0;;
    1)  d__announce -x -- 'Failed to uninstall Divine.dotfiles'; return 1;;
    2)  d__announce -s -- 'Declined to uninstall Divine.dotfiles'; return 2;;
  esac; fi
}

d___get_ready()
{
  # Compose task name; print intro with a separating empty line
  uplq='Pre-flight checks'; printf >&2 '\n%s %s\n' "$D__INTRO_CHK_N" "$uplq"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_CHK_S" "$uplq"; return 0
  fi

  # Run checks on framework and utils
  if d___pfc_fmwk && d___pfc_utils; then
    printf >&2 '%s %s\n' "$D__INTRO_SUCCS" "$uplq"; return 0
  else
    printf >&2 '%s %s\n' "$D__INTRO_FAILR" "$uplq"; return 1
  fi
}

d___pfc_fmwk()
{
  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false ]; then return 1; fi

  # Compose destination path
  udst="$D__DIR"

  # Ensure directory exists
  if ! [ -e "$udst" ]; then
    d__notify -lx -- "Nothing to uninstall at: $udst"
    return 1
  fi

  # Ensure what exists is a directory
  if ! [ -d "$udst" ]; then
    d__notify -lx -- "Framework path is not a directory: $udst"
    return 1
  fi

  # Ensure that directory looks like Divine.dotfiles
  if ! [ -f "$udst/intervene.sh" ]; then
    d__notify -lx -- 'Uninstallation path does not look' \
      'like Divine.dotfiles:' -i- "$udst"
    return 1
  fi

  # Ensure stash is available
  if ! d__stash -r -- ready; then
    d__notify -lx -- "Problem accessing root stash at: $D__DIR_STASH"
    return 1
  fi

  # Ensure record of shortcut exists
  if ! d__stash -rs -- has di_shortcut; then
    d__notify -ls -- 'No record found of installing shortcut command'
    return 0
  fi

  # Retrieve shortcut location
  sdst="$( d__stash -rs -- get di_shortcut )"

  # Ensure shortcut exists at extracted path
  if ! [ -e "$sdst" ]; then
    d__notify -l! -- 'Shortcut command is missing from its recorded location:'
      -i- "$sdst" -n- 'Ignoring it'
    sdst=; return 0
  fi

  # Ensure shortcut is a symlink to framework's main executable
  if ! [ -L "$sdst" ]; then
    d__notify -l! -- 'Path to shortcut command is not a symlink:' -i- "$sdst" \
      -n- 'Ignoring it'
    sdst=; return 0
  fi

  # Ensure shortcut is a symlink to framework's main executable
  if ! [ "$sdst" -ef "$udst/intervene.sh" ]; then
    d__notify -l! -- 'Shortcut symlink at:' -i- "$sdst" \
      "does not point to framework's main executable at:" \
      -i- "$udst/intervene.sh" -n- 'Ignoring it'
    sdst=; return 0
  fi

  return 0
}

d___pfc_utils()
{
  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_U" = false ]; then return 0; fi

  # Compile the list of previously installed optional dependencies
  if d__stash -rs -- has installed_homebrew
  then ubrw=true erra+=( -i- '- Homebrew' ); ((++utlc)); fi
  if d__stash -rs -- has installed_utils; then
    while read -r utl; do utla+=("$utl") erra+=( -i- "- $utl" ); ((++utlc))
    done < <( d__stash -rs -- list installed_utils )
  fi

  # Check if list is empty
  if [ $utlc -eq 0 ]; then
    d__notify -ls -- 'Found zero previously installed optional dependencies'
    return 0
  else
    d__notify -l! -- 'Previously installed optional dependencies:' "${erra[@]}"
  fi

  # If there are utils, detect OS; without a package manager, no-go
  if ((${#utla[@]})); then
    d__load procedure detect-os
    if [ -z "$D__OS_PKGMGR" ]; then
      d__notify -lx -- 'Unable to uninstall optional dependencies' \
        '(no supported package manager)'
      if $D__OPT_FORCE; then
        printf >&2 '%s ' "$D__INTRO_CNF_U"
        d__prompt -bp 'Skip & continue?' && return 0 || return 1
      else
        d__notify -l! -- 'Re-try with --force to skip this step'; return 1
      fi
    fi
  fi
}

d___uninstall_utils()
{
  # Cut-off check for number of installed utilities
  if [ $utlc -eq 0 ]; then return 0; fi

  # Сompose task name
  uplq="Previously installed optional utilities"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false -o "$D__OPT_ANSWER_U" = false ]; then
    printf >&2 '\n%s %s\n' "$D__INTRO_RMV_S" "$uplq"; return 0
  fi

  # Uninstall Homebrew
  if $ubrw; then d___uninstall_homebrew; case $? in
    0)  :;;
    1)  if $D__OPT_FORCE; then
          printf >&2 '%s ' "$D__INTRO_CNF_U"
          if d__prompt -bp 'Ignore & continue?'
          then printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$uplq"
          else printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$uplq"; return 1; fi
        else
          d__notify -l! -- 'Re-try with --force to ignore'
          printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$uplq"; return 1
        fi;;
    2)  return 1;;
  esac; fi

  # Cut-off for undetected package manager (skipped earlier)
  if ((${#utla[@]})) && [ -z "$D__OS_PKGMGR" ]; then return 0; fi

  # Uninstall utilities
  for utl in "${utla[@]}"; do d___uninstall_util; case $? in
    0)  :;;
    1)  if $D__OPT_FORCE; then
          printf >&2 '%s ' "$D__INTRO_CNF_U"
          if d__prompt -bp 'Ignore & continue?'
          then printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$uplq"
          else printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$uplq"; return 1; fi
        else
          d__notify -l! -- 'Re-try with --force to ignore'
          printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$uplq"; return 1
        fi;;
    2)  return 1;;
  esac; done

  return 0
}

d___uninstall_homebrew()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; uplq="Optional dependency '${BOLD}Homebrew$NORMAL'"

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_RMV_N" "$uplq"

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER_U" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    d__prompt -bpq 'Uninstall Homebrew?'
    case $? in
      0)  :;;
      1)  printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$uplq"; return 0;;
      2)  d__notify -l! -- 'Aborting uninstallation routine'
          printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$uplq"; return 2;;
    esac
  fi

  # Prepare for uninstallation
  local brw_us="$(mktemp)"
  if ! curl -fsSLo "$brw_us" \
    'https://raw.githubusercontent.com/Homebrew/install/master/uninstall'
  then
    d__notify -lx -- 'Failed to download Homebrew uninstall script'
    rm -f -- "$brw_us"; return 1
  fi
  if ! chmod +x "$brw_us" &>/dev/null; then
    d__notify -lx -- 'Failed to make Homebrew uninstall script executable'
    rm -f -- "$brw_us"; return 1
  fi

  # Launch uninstallation with verbosity in mind
  if (($D__OPT_VERBOSITY)); then local d__ol
    $brw_us --force 2>&1 | while IFS= read -r d__ol || [ -n "$d__ol" ]
      do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
  else $brw_us --force &>/dev/null; fi

  # Check return code
  if ((${PIPESTATUS[0]})); then
    d__notify -lx -- 'Homebrew uninstall script returned an error code'
    rm -f -- "$brw_us"; return 1
  else
    d__notify -lv -- 'Successfully uninstalled Homebrew'
    if d__stash -rs -- unset installed_homebrew; then
      d__notify -- 'Removed installation record of Homebrew from root stash'
    else
      d__notify -lx -- 'Failed to remove installation record of Homebrew' \
        'from root stash'
    fi
    rm -f -- "$brw_us"; return 0
  fi
}

d___uninstall_util()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; uplq="Optional dependency '$BOLD$utl$NORMAL'"

  # Print intro
  printf >&2 '%s %s\n' "$D__INTRO_RMV_N" "$uplq"

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER_U" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    d__prompt -bpq "Uninstall $utl?"
    case $? in
      0)  :;;
      1)  printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$uplq"; return 0;;
      2)  d__notify -l! -- 'Aborting uninstallation routine'
          printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$uplq"; return 2;;
    esac
  fi

  # Launch uninstallation with verbosity in mind
  if (($D__OPT_VERBOSITY)); then local d__ol
    d__os_pkgmgr remove "$utl" 2>&1 \
      | while IFS= read -r d__ol || [ -n "$d__ol" ]
        do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
  else d__os_pkgmgr remove "$utl" &>/dev/null; fi

  # Check return code
  if ((${PIPESTATUS[0]})); then
    d__notify -lx -- 'Package manager returned an error code'
    return 1
  else
    d__notify -lv -- "Successfully uninstalled '$utl'"
    if d__stash -rs -- unset installed_utils "$utl"; then
      d__notify -- "Removed installation record of '$utl' from root stash"
    else
      d__notify -lx -- "Failed to remove installation record of '$utl'" \
        'from root stash'
    fi
    return 0
  fi
}

d___uninstall_fmwk()
{
  # Print a separating empty line; compose task name
  printf >&2 '\n'; uplq="$BOLD$D__FMWK_NAME$NORMAL framework"

  # Early exit for dry runs
  if [ "$D__OPT_ANSWER_F" = false ]; then
    printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$uplq"; return 2
  fi

  # Print intro; print locations
  printf >&2 '%s %s\n' "$D__INTRO_RMV_N" "$uplq"
  d__notify -q -- 'Repo URL: https://github.com/no-simpler/divine-dotfiles'
  d__notify -q -- "Location: $udst"

  # Conditionally prompt for user's approval
  if [ "$D__OPT_ANSWER_F" != true ]; then
    printf >&2 '%s ' "$D__INTRO_CNF_N"
    if ! d__prompt -bp 'Uninstall?'
    then printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$uplq"; return 2; fi
  fi

  # Remove shortcut command, if exists
  if [ -n "$sdst" ] && ! rm -f -- "$sdst"; then
    d__notify -lx -- 'Failed to remove shortcut command at:' -i- "$sdst"
  fi

  # Remove shortcut command, if exists
  if d__stash -rs -- has di_shortcut && ! d__stash -rs -- unset di_shortcut
  then
    d__notify -lx -- 'Failed to remove record' \
      'of shortcut command location from root stash'
  fi

  # Back up previous framework directory (and capture backup path)
  local d__bckp=; if ! d__push_backup -- "$udst" "$udst.bak"; then
    d__notify -lx -- 'Failed to back up framework directory'
    printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$uplq"
    return 1
  fi

  # Report success
  d__notify -lv -- 'Backup of uninstalled framework is retained at:' \
    -i- "$d__bckp" -n- 'You can safely delete it manually'
  printf >&2 '%s %s\n' "$D__INTRO_RMV_0" "$uplq"
  return 0
}

d___send_pictures()
{
  # Print empty line for visual separation; compose main command for output
  printf >&2 '\n'; local mcmd

  # Print plaque
  cat <<EOF
${REVERSE}- ${BOLD}D i v i n e . d o t f i l e s${NORMAL}${REVERSE} -${NORMAL}
   ${GREEN}${REVERSE}${BOLD} u n i n s t a l l e d ${NORMAL}
             ${GREEN}${REVERSE}x_x${NORMAL}

We hate to see you leave, but we love watching you go.
EOF

  # Return success
  return 0
}

d__rtn_fmwk_uninstall