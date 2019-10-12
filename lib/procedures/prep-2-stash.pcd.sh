#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-2-stash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Ensures that both Grail-level and root-level stash are ready-to-go, or exits 
#. the script.
#

# Driver function
d__run_stash_checks()
{
  local erra=()
  d__stash -g -- ready || erra+=( -i- "- Grail stash at: $D__DIR_GRAIL" )
  d__stash -r -- ready || erra+=( -i- "- root stash at: $D__DIR_STASH" )
  if ((${#erra[@]})); then
    d__notify -lx -- 'Failed to prepare stashing systems:' "${erra[@]}"
    exit 1
  fi
}

d__run_stash_checks