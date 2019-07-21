#!/usr/bin/env bash
#:title:        Divine.dotfiles Solaris adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with ‘Solaris’ family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_family()
{
  # Check if $D_DPL_TARGET_PATHS_SOLARIS contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_SOLARIS[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_SOLARIS" ]; then

    # $D_DPL_TARGET_PATHS_SOLARIS is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_SOLARIS[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_SOLARIS is not empty
  if [ -n "$D_DPL_TARGET_DIR_SOLARIS" ]; then

    # $D_DPL_TARGET_DIR_SOLARIS is set: use it instead
    D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_SOLARIS"
    
  fi
}