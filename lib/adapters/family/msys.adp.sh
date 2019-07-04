#!/usr/bin/env bash
#:title:        Divine.dotfiles msys adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with ‘msys’ family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
__override_d_targets_for_family()
{
  # Check if $D_DPL_TARGET_PATHS_MSYS contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_MSYS[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_MSYS" ]; then

    # $D_DPL_TARGET_PATHS_MSYS is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_MSYS[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_MSYS is not empty
  if [ -n "$D_DPL_TARGET_DIR_MSYS" ]; then

    # $D_DPL_TARGET_DIR_MSYS is set: use it instead
    D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_MSYS"
    
  fi
}
