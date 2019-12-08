#!/usr/bin/env bash
#:title:        Divine Bash utils: transitions
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.08
#:revremark:    Apply transitions on attach; block when trs fails
#:created_at:   2019.12.08

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## A function that applies transitions to both the framework and bundles.
#

# Marker and dependencies
readonly D__UTL_TRANSITIONS=loaded
d__load procedure prep-sys
d__load util workflow

#>  d___apply_transitions
#
## INTERNAL USE ONLY
#
#>  $udst
#>  $ovrs
#>  $nvrs
#>  $untv   - Path to file that keeps the latest untransitioned version
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
    n)  if [ "$D__REQ_ROUTINE" = attach ]; then
          d__notify -lv -- "Attached version $BOLD$nvrs$NORMAL"
        else
          d__notify -lv -- 'Updated from an unmarked version' \
            "to current version $BOLD$nvrs$NORMAL"
        fi
        d__context -- notch
        d__context -- push "Applying transitions onto version $nvcl"
        ;;
    on) if [ "$ovcl" = "$nvcl" ]; then
          if [ "$ovrs" = "$nvrs" ]; then
            d__notify -lv -- "Version unchanged: $BOLD$nvrs$NORMAL"
          else
            d__notify -lv -- \
              "Changed version from $BOLD$ovrs$NORMAL to $BOLD$nvrs$NORMAL"
          fi
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
      printf >"$untv" '%s\n' "$ovcl"
      d__notify -lx -- \
        "Error code after applying transition onto version $BOLD$tvcl$NORMAL" \
        -n- 'Hopefully, the failed transition has explained itself' \
        -n- 'Please, seek to eliminate the problem, then update'
      d__notify -l! -- 'Further transitions, if any, will not be applied'
      break
    else
      tras=true
      ovcl="$tvcl"
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
    d__notify -ls -- 'No relevant transition scripts found'
  fi
  d__context -- lop
  return $trtc
}