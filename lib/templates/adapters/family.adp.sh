#!/usr/bin/env bash
#:title:        Divine.dotfiles template OS family adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.04
#:revremark:    Initial revision
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with particular family of operating systems
#
## For adapter file to be sourced and used, it must be named ‘FAMILY.adp.sh’ 
#. and placed in lib/adapters/family directory. ‘FAMILY’ must match $OS_FAMILY 
#. variable’s value for OS family being adapted for. (See lib/dos.utl.sh for 
#. reference on $OS_FAMILY).
#

#>  __override_d_targets_for_family
#
## Provides a way for deployments to override $D__DPL_TARGET_PATHS global 
#. variable, which is used by helper functions in dln.hlp.sh and cp.hlp.sh. 
#. This function is called before contents of $D__DPL_TARGET_PATHS is settled 
#. upon.
#
__override_d_targets_for_family()
{
  # Below is example implementation for BSD family of operating systems

  # Check if $D__DPL_TARGET_PATHS_BSD contains at least one string
  if [ ${#D__DPL_TARGET_PATHS_BSD[@]} -gt 1 \
    -o -n "$D__DPL_TARGET_PATHS_BSD" ]; then

    # $D__DPL_TARGET_PATHS_BSD is set: use it instead
    D__DPL_TARGET_PATHS=( "${D__DPL_TARGET_PATHS_BSD[@]}" )
    
  fi
}