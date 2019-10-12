#!/usr/bin/env bash
#:title:        Divine.dotfiles template OS family adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support a particular family of operating systems.
#
## For a particular OS family to be supported, detection code must be added to 
#. lib/procedures/detect-os.pcd.sh.
#
## For the adapter file to be recognized, it must be named 'FAMILY.adp.sh', and 
#. placed in the lib/adapters/family directory, where 'FAMILY' must be the same 
#. as the handle assigned to the $D__OS_FAMILY variable during OS detection.
#

#>  d__override_dpl_targets_for_os_family
#
## Overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR.
#
## Provides a way for deployments to override target paths used by the 
#. framework's queue helpers.
#
## This function must check whether a specially named OS family-specific 
#. variable is populated and, if so, override the main variable.
#
## The overriding naming pattern is as such:
#.  D_DPL_TARGET_PATHS    is overridden by    D_DPL_TARGET_PATHS_***
#.  D_DPL_TARGET_DIR      is overridden by    D_DPL_TARGET_DIR_***
#. where '***' stands fot the value of the $D__OS_DISTRO variable in all caps.
#
# Below is an example implementation for the Ubuntu distribution.
#
d__override_dpl_targets_for_os_family()
{
  if [ ${#D_DPL_TARGET_PATHS_BSD[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS_BSD" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_BSD[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_BSD" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_BSD"; fi
}