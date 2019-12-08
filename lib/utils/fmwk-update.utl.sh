#!/usr/bin/env bash
#:title:        Divine Bash utils: fmwk-update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.08
#:revremark:    Apply transitions on attach; block when trs fails
#:created_at:   2019.11.22

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Functions that update framework itself to latest revision, while minding the 
#. possible 'nightly' mode. The fuctions expect the framework directory to be 
#. the current directory when called.
#

# Marker and dependencies
readonly D__UTL_FMWK_UPDATE=loaded
d__load util workflow
d__load util git
d__load util backup
d__load procedure prep-sys
d__load procedure offer-gh
d__load procedure check-gh

#>  d___update_fmwk_via_pull
#
## INTERNAL USE ONLY
#
#>  $ungh
#>  $ubld
#
d___update_fmwk_via_pull()
{
  # Build pull options based on nightly mode
  local uopt=( -t 'Divine.dotfiles' )
  $ungh && uopt+=( -ab dev ) || uopt+=( -ab master )

  # Pull updates for current branch
  d___pull_git_remote "${uopt[@]}" -- "$udst"
}

d___update_fmwk_to_clone()
{
  # Pull the repository into the temporary directory
  local utmp="$(mktemp -d)" uopt=( -Gt 'Divine.dotfiles' )
  $ungh && uopt+=( -fb dev )
  if ! d___clone_git_repo "${uopt[@]}" -- "$ughh" "$utmp"; then
    rm -rf -- "$utmp"
    return 2
  fi

  # Back up previous framework directory (and capture backup path)
  local d__bckp=
  if ! d__push_backup -- "$udst" "$udst.bak"; then
    d__notify -lx -- 'Failed to back up old framework directory'
    rm -rf -- "$utmp"
    return 1
  fi

  # Move the retrieved framework clone into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move framework clone into place'
    rm -rf -- "$utmp"
    return 1
  fi

  # Return Grail and state directories
  local erra=() grrp src dst
  if [[ $D__DIR_GRAIL = "$udst/"* ]]; then
    grrp="${D__DIR_GRAIL#"$udst/"}"
    src="$d__bckp/$grrp" dst="$udst/$grrp"
    if [ -d "$src" ] && ! mv -n -- "$src" "$dst"; then
      erra+=( -i- "- Grail directory" )
    fi
  fi
  src="$d__bckp/state" dst="$udst/state"
  if [ -d "$src" ] && ! mv -n -- "$src" "$dst"; then
    erra+=( -i- "- state directory" )
  fi
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to restore directories after upgrading' \
      'framework to Github clone:' "${erra[@]}"
    d__notify l! -- 'Please, move the directories manually from:' \
      -i- "$d__bckp" -n- 'to:' -i- "$udst"
  fi

  # Report success
  return 0
}

d___update_fmwk_via_dl()
{
  # Print forced intro
  printf >&2 '%s %s\n' "$D__INTRO_UPD_F" "$uplq"

  # Pull the repository into the temporary directory
  local utmp="$(mktemp -d)" uopt=( -$D__GH_METHOD -t 'Divine.dotfiles' )
  $ungh && uopt+=( -b dev )
  if ! d___dl_gh_repo "${uopt[@]}" -- "$ughh" "$utmp"; then
    rm -rf -- "$utmp"
    return 2
  fi

  # Back up previous framework directory (and capture backup path)
  local d__bckp=
  if ! d__push_backup -- "$udst" "$udst.bak"; then
    d__notify -lx -- 'Failed to back up old framework directory'
    rm -rf -- "$utmp"
    return 1
  fi

  # Move the retrieved framework copy into place
  if ! mv -n -- "$utmp" "$udst"; then
    d__notify -lx -- 'Failed to move new framework copy into place'
    rm -rf -- "$utmp"
    return 1
  fi

  # Return Grail and state directories
  local erra=() grrp src dst
  if [[ $D__DIR_GRAIL = "$udst/"* ]]; then
    grrp="${D__DIR_GRAIL#"$udst/"}"
    src="$d__bckp/$grrp" dst="$udst/$grrp"
    if [ -d "$src" ] && ! mv -n -- "$src" "$dst"; then
      erra+=( -i- "- Grail directory" )
    fi
  fi
  src="$d__bckp/state" dst="$udst/state"
  if [ -d "$src" ] && ! mv -n -- "$src" "$dst"; then
    erra+=( -i- "- state directory" )
  fi
  if ((${#erra[@]})); then
    d__notify -lx -- "Failed to restore directories after 'crudely' updating" \
      'framework:' "${erra[@]}"
    d__notify l! -- 'Please, move the directories manually from:' \
      -i- "$d__bckp" -n- 'to:' -i- "$udst"
  fi

  # Report success
  return 0
}