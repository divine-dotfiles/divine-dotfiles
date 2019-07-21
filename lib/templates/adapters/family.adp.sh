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
#. and placed in lib/adapters/family directory, where ‘FAMILY’ must match 
#. $D__OS_FAMILY variable’s value for OS family being adapted for. (See 
#. lib/procedures/detect-os.pcd.sh for reference on $D__OS_FAMILY).
#

#>  d__override_dpl_targets_for_os_family
#
## Provides a way for deployments to override $D_DPL_TARGET_PATHS global 
#. variable, which is used by helper functions in dln.hlp.sh and cp.hlp.sh. 
#. This function is called before contents of $D_DPL_TARGET_PATHS is settled 
#. upon.
#
d__override_dpl_targets_for_os_family()
{
  # Below is example implementation for BSD family of operating systems

  # Check if $D_DPL_TARGET_PATHS_BSD contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_BSD[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_BSD" ]; then

    # $D_DPL_TARGET_PATHS_BSD is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_BSD[@]}" )
    
  fi
}