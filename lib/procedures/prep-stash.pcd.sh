#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-stash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Ensures that both Grail-level and root-level stash are ready-to-go, or exits 
#. the script.
#

# Marker and dependencies
readonly D__PCD_PREP_STASH=loaded
d__load util workflow
d__load util stash

# Driver function
d__pcd_prep_stash()
{
  local erra=()
  d__stash -g -- ready || erra+=( -i- "- Grail stash at: $D__DIR_GRAIL" )
  d__stash -r -- ready || erra+=( -i- "- root stash at: $D__DIR_STASH" )
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to prepare stashing systems:' "${erra[@]}"
    exit 1
  fi
}

d__pcd_prep_stash