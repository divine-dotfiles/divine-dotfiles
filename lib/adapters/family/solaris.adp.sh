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

# Implement overriding mechanism for $D_TARGETS
__override_d_targets_for_family()
{
  # Check if $D_TARGETS_SOLARIS contains at least one string
  if [ ${#D_TARGETS_SOLARIS[@]} -gt 1 -o -n "$D_TARGETS_SOLARIS" ]; then

    # $D_TARGETS_SOLARIS is set: use it instead
    D_TARGETS=( "${D_TARGETS_SOLARIS[@]}" )
    
  fi
}