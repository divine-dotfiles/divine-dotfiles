#!/usr/bin/env bash
#:title:        Divine.dotfiles WSL adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with ‘WSL’ family of operating systems (Windows Subsystem for 
#. Linux)
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement overriding mechanism for $D_TARGETS
__override_d_targets_for_family()
{
  # Start with generic linux override, then try WSL-specific one
  
  # Check if $D_TARGETS_LINUX contains at least one string
  if [ ${#D_TARGETS_LINUX[@]} -gt 1 -o -n "$D_TARGETS_LINUX" ]; then

    # $D_TARGETS_LINUX is set: use it instead
    D_TARGETS=( "${D_TARGETS_LINUX[@]}" )
    
  fi

  # Check if $D_TARGETS_WSL contains at least one string
  if [ ${#D_TARGETS_WSL[@]} -gt 1 -o -n "$D_TARGETS_WSL" ]; then

    # $D_TARGETS_WSL is set: use it instead
    D_TARGETS=( "${D_TARGETS_WSL[@]}" )
    
  fi
}