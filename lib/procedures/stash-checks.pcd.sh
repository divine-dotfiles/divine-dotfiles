#!/usr/bin/env bash
#:title:        Divine Bash procedure: stash-checks
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    5
#:revdate:      2019.08.07
#:revremark:    Grand removal of non-ASCII chars
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Prepares global stashing system
#

#>  d__run_stash_checks
#
## Driver function
#
## Returns:
#.  0 - Framework is ready to run
#.  1 - (script exit) Otherwise
#
d__run_stash_checks()
{
  # Ensure Grail stash is available
  d__stash --grail ready || {
    dprint_failure -l \
      'Failed to prepare Divine stashing system in Grail directory at:' \
      -i "$D__DIR_GRAIL"
    exit 1
  }

  # Ensure root stash is available
  d__stash --root ready || {
    dprint_failure -l \
      'Failed to prepare Divine stashing system in state directory at:' \
      -i "$D__DIR_STASH"
    exit 1
  }
}

d__run_stash_checks
unset -f d__run_stash_checks