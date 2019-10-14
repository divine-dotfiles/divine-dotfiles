#!/usr/bin/env bash
#:title:        Divine Bash procedure: sync-bundles
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Ensures that records of attached bundles of deployments are consistent with 
#. the actual content of the bundles directory.
#

# Marker and dependencies
readonly D__PCD_SYNC_BUNDLES=loaded
d__load procedure prep-sys
d__load util workflow
d__load procedure prep-gh
d__load util github

#>  d__pcd_sync_bundles
#
## Clones/downloads missing bundles; deletes extra bundles.
#
## Returns:
#.  0 - The bundles directory is made consistent with the records.
#.  1 - (script exit) Otherwise.
#
d__pcd_sync_bundles()
{
  # Switch context
  d__context -- notch
  d__context -- push 'Synchronizing bundles directory with Grail stash records'

  # Storage variables
  local i j recba=() recb recc actba=() actb actc erra=()

  # Compile list of recorded bundles
  if d__stash -gs -- has attached_bundles; then
    while read -r recb; do recba+=("$recb")
    done < <( d__stash -gs -- list attached_bundles )
  fi; recc=${#recba[@]}

  # Compile list of actual bundle directories
  if [ -e "$D__DIR_BUNDLES" -a ! -d "$D__DIR_BUNDLES" ]; then
    d__fail -- "Path to bundles directory is occupied: '$D__DIR_BUNDLES'"
    exit 1
  elif [ -r "$D__DIR_BUNDLES" -a -d "$D__DIR_BUNDLES" ]; then
    while IFS= read -r -d $'\0' actb; do
      actba+=( "$actb" )
      if ! [ -d "$actb" ]; then
        erra+=( -i- "- path to potential bundle directory is occupied: $actb" )
      fi
    done < <( find "$D__DIR_BUNDLES" -mindepth 2 -maxdepth 2 -print0 )
  fi; actc=${#actba[@]}

  # Check for non-directories in bundles directory
  if ((${#erra[@]})); then
    d__fail -- 'Illegal state of bundles directory:' "${erra[@]}"
    exit 1
  fi

  # Cross-reference directories to records
  for ((j=0;j<$actc;++j)); do
    for ((i=0;i<$recc;++i)); do
      if [ "${actba[$j]}" = "$D__DIR_BUNDLES/${recba[$i]}" ]
      then unset recba[$i] actba[$j]; continue 2; fi
    done
    actba[$j]="${actba[$j]#"$D__DIR_BUNDLES/"}"
  done

  # Report inconsistencies if they are present
  for recb in "${recba[@]}"
  do erra+=( -i- "- missing bundle '$recb'" ); done
  for actb in "${actba[@]}"
  do erra+=( -i- "- unrecorded bundle '$actb'" ); done
  if [ ${#erra[@]} -eq 0 ]; then d__context -- lop; return 0; fi
  d__notify -l! -- 'Bundles directory is inconsistent' \
    'with Grail stash records:' "${erra[@]}"
  if ((${#recba[@]})) && [ -z "$D__GH_METHOD" ]; then
    d__fail -- 'There is no way to retrieve missing bundles from Github'
    exit 1
  fi

  # Synchronize
  erra=()
  for recb in "${recba[@]}"; do
    if [ -e "$D__BUNDLES_DIR/$recb" ]; then
      erra+=( -i- "- path to directory of bundle '$recb' is occupied" )
      continue
    fi
    if ! d___gh_repo_exists "$recb"
    then erra+=( -i- "- invalid Github repo handle '$recb'" ); continue; fi
    case $D__GH_METHOD in
      g)  d___clone_gh_repo "$recb" "$D__BUNDLES_DIR/$recb";;
      c)  mkdir -p &>/dev/null -- "$D__BUNDLES_DIR/$recb" \
            && d___curl_gh_repo "$recb" "$D__BUNDLES_DIR/$recb";;
      w)  mkdir -p &>/dev/null -- "$D__BUNDLES_DIR/$recb" \
            && d___wget_gh_repo "$recb" "$D__BUNDLES_DIR/$recb";;
    esac
    if (($?))
    then d__notify -l -- 'Retrieved missing bundle '$recb''
    else erra+=( -i- "- failed to retrieve missing bundle '$recb'" ); fi
  done
  for actb in "${actba[@]}"; do
    if rm -rf -- "$actb"
    then d__notify -l -- 'Deleted unrecorded bundle '$actb''
    else erra+=( -i- "- failed to delete unrecorded bundle '$actb'" ); fi
  done

  # Report results and return
  if ((${#erra[@]})); then
    d__fail -- 'Unable to fully synchronize bundles directory' \
      'with Grail stash records:' "${erra[@]}"
    exit 1
  else d__context -- lop; return 0; fi
}

d__pcd_sync_bundles