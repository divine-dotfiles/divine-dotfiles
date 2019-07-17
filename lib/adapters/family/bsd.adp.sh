#!/usr/bin/env bash
#:title:        Divine.dotfiles BSD adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with ‘BSD’ family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement overriding mechanism for $D__DPL_TARGET_PATHS and $D__DPL_TARGET_DIR
d__override_dpl_targets_for_os_family()
{
  # Check if $D__DPL_TARGET_PATHS_BSD contains at least one string
  if [ ${#D__DPL_TARGET_PATHS_BSD[@]} -gt 1 \
    -o -n "$D__DPL_TARGET_PATHS_BSD" ]; then

    # $D__DPL_TARGET_PATHS_BSD is set: use it instead
    D__DPL_TARGET_PATHS=( "${D__DPL_TARGET_PATHS_BSD[@]}" )
    
  fi

  # Check if $D__DPL_TARGET_DIR_BSD is not empty
  if [ -n "$D__DPL_TARGET_DIR_BSD" ]; then

    # $D__DPL_TARGET_DIR_BSD is set: use it instead
    D__DPL_TARGET_DIR="$D__DPL_TARGET_DIR_BSD"
    
  fi
}