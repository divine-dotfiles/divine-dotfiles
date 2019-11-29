#!/usr/bin/env bash
#:title:        Divine Bash utils: fmwk-update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.29
#:revremark:    Slightly tweak wording on version update output
#:created_at:   2019.11.22

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Groups functions that update framework itself to latest revision, while 
#. minding the possible 'nightly' mode. The fuctions expect the framework 
#. directory to be the current directory when called.
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

#>  d___apply_transitions
#
## INTERNAL USE ONLY
#
#>  $udst
#>  $ovrs
#>  $nvrs
#
d___apply_transitions()
{
  # Prepare storage variables
  local ii vrar ovma ovmi ovpa nvma nvmi nvpa trsf trsn tvma tvmi tvpa
  local ovcl nvcl tvcl vdgr=false tras=false traf=false gdvr= trtc

  # Validate old version and extract its components
  if [ -n "$ovrs" ]; then
    IFS=. read -r -a vrar <<<"$ovrs"
    ovma="${vrar[0]}" ovmi="${vrar[1]}" ovpa="${vrar[2]}"
    while [[ -n "$ovma" && ! $ovma =~ ^[0-9]+$ ]]; do ovma="${ovma:1}"; done
    while [[ -n "$ovmi" && ! $ovmi =~ ^[0-9]+$ ]]
    do ovmi="${ovmi::${#ovmi}-1}"; done
    while [[ -n "$ovpa" && ! $ovpa =~ ^[0-9]+$ ]]
    do ovpa="${ovpa::${#ovpa}-1}"; done
    if [[ $ovma =~ ^[0-9]+$ && $ovmi =~ ^[0-9]+$ && $ovpa =~ ^[0-9]+$ ]]; then
      gdvr+=o ovcl="$ovma.$ovmi.$ovpa"
      d__notify -- "Valid previous version: $BOLD$ovcl$NORMAL"
    else
      d__notify -x -- "Invalid previous version: $ovrs"
    fi
  else
    d__notify -- 'Empty previous version'
  fi

  # Validate new version and extract its components
  if [ -n "$nvrs" ]; then
    IFS=. read -r -a vrar <<<"$nvrs"
    nvma="${vrar[0]}" nvmi="${vrar[1]}" nvpa="${vrar[2]}"
    while [[ -n "$nvma" && ! $nvma =~ ^[0-9]+$ ]]
    do nvma="${nvma:1}"; done
    while [[ -n "$nvmi" && ! $nvmi =~ ^[0-9]+$ ]]
    do nvmi="${nvmi::${#nvmi}-1}"; done
    while [[ -n "$nvpa" && ! $nvpa =~ ^[0-9]+$ ]]
    do nvpa="${nvpa::${#nvpa}-1}"; done
    if [[ $nvma =~ ^[0-9]+$ && $nvmi =~ ^[0-9]+$ && $nvpa =~ ^[0-9]+$ ]]; then
      gdvr+=n nvcl="$nvma.$nvmi.$nvpa"
      d__notify -- "Valid current version: $BOLD$nvcl$NORMAL"
    else
      d__notify -lx -- "Invalid current version: $nvrs"
    fi
  else
    d__notify -- 'Empty current version'
  fi

  # If both versions are good, ensure they compare correctly
  case $gdvr in
    '') d__notify -- 'Versioning is not used'
        return 0
        ;;
    o)  d__notify -lx -- "Updated from previous version $BOLD$ovrs$NORMAL" \
          'to an unmarked version'
        return 1
        ;;
    n)  d__notify -lv -- 'Updated from an unmarked version' \
          "to current version $BOLD$nvrs$NORMAL"
        d__context -- notch
        d__context -- push "Applying transitions onto version $nvcl"
        ;;
    on) if [ "$ovcl" = "$nvcl" ]; then
          d__notify -lv -- "Version already up to date: $BOLD$nvrs$NORMAL"
          return 0
        fi
        if [[ $ovma -gt $nvma ]]; then vdgr=true
        elif [[ $ovma -eq $nvma ]]; then
          if [[ $ovmi -gt $nvmi ]]; then vdgr=true
          elif [[ $ovmi -eq $nvmi ]]; then
            [[ $ovpa -gt $nvpa ]] && vdgr=true
          fi
        fi
        if $vdgr; then
          d__notify -lx -- 'Updated to a downgraded version,' \
            "from $BOLD$ovrs$NORMAL to $BOLD$nvrs$NORMAL"
          return 1
        fi
        d__notify -lv -- \
          "Updated version from $BOLD$ovrs$NORMAL to $BOLD$nvrs$NORMAL"
        d__context -- notch
        d__context -- push "Applying transitions between versions $ovcl->$nvcl"
        ;;
  esac

  $D__ENABLE_DOTGLOB
  $D__ENABLE_NULLGLOB

  # Iterate over transition files in transitions directory
  for trsf in "$udst/$D__CONST_DIRNAME_TRS/"*; do

    # Process only files with .trs.sh suffixes
    [ -f "$trsf" ] || continue
    [[ $trsf = *$D__SUFFIX_TRS_SH ]] || continue

    # Parse and validate transition version and extract its components
    trsn="$( basename -- "$trsf" )"; tvrs="${trsn%$D__SUFFIX_TRS_SH}"
    IFS=. read -r -a vrar <<<"$tvrs"
    tvma="${vrar[0]}" tvmi="${vrar[1]}" tvpa="${vrar[2]}"
    while [[ -n "$tvma" && ! $tvma =~ ^[0-9]+$ ]]
    do tvma="${tvma:1}"; done
    while [[ -n "$tvmi" && ! $tvmi =~ ^[0-9]+$ ]]
    do tvmi="${tvmi::${#tvmi}-1}"; done
    while [[ -n "$tvpa" && ! $tvpa =~ ^[0-9]+$ ]]
    do tvpa="${tvpa::${#tvpa}-1}"; done
    if [[ $tvma =~ ^[0-9]+$ && $tvmi =~ ^[0-9]+$ && $tvpa =~ ^[0-9]+$ ]]; then
      tvcl="$tvma.$tvmi.$tvpa"
      d__notify -- "Valid transition version: $BOLD$tvcl$NORMAL"
    else
      d__notify -lx -- "Incorrectly named transition script: '$trsn'"
      continue
    fi

    # Check if transition is newer than the previous version, if any
    if [[ $gdvr = on ]]; then
      vdgr=false
      if [[ $ovma -gt $tvma ]]; then vdgr=true
      elif [[ $ovma -eq $tvma ]]; then
        if [[ $ovmi -gt $tvmi ]]; then vdgr=true
        elif [[ $ovmi -eq $tvmi ]]; then
          [[ $ovpa -ge $tvpa ]] && vdgr=true
        fi
      fi
      if $vdgr; then
        d__notify -s -- "Skipping old transition script: '$trsn'"
        continue
      fi
    fi

    # Check if transition is not older than the current version
    vdgr=false
    if [[ $tvma -gt $nvma ]]; then vdgr=true
    elif [[ $tvma -eq $nvma ]]; then
      if [[ $tvmi -gt $nvmi ]]; then vdgr=true
      elif [[ $tvmi -eq $nvmi ]]; then
        [[ $tvpa -gt $nvpa ]] && vdgr=true
      fi
    fi
    if $vdgr; then
      d__notify -ls -- "Skipping future transition script: '$trsn'"
      continue
    fi

    # Source the transition file
    d__context -- push "Applying transition script: '$trsn'"
    source "$trsf"
    if (($?)); then
      traf=true
      d__notify -lx -- \
        "Error code after applying transition onto version $BOLD$tvcl$NORMAL"
    else
      tras=true
      d__notify -lv -- \
        "Successfully applied transition onto version $BOLD$tvcl$NORMAL"
    fi
    d__context -- pop

  # Done iterating over transition files in transitions directory
  done

  $D__RESTORE_DOTGLOB
  $D__RESTORE_NULLGLOB

  # Report status and return
  if $tras && $traf; then
    trtc=1
    d__notify -lx -- 'Failed to apply some transitions'
  elif $tras; then
    trtc=0
    d__notify -lv -- 'Successfully applied all transitions'
  elif $traf; then
    trtc=1
    d__notify -lx -- 'Failed to apply all transitions'
  else
    trtc=0
    d__notify -ls -- \
      'No transition scripts found between previous and current versions'
  fi
  d__context -- lop
  return $trtc
}