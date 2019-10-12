#!/usr/bin/env bash
#:title:        Divine.dotfiles WSL adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support 'WSL' family of operating systems (Windows Subsystem for 
#. Linux)
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_family()
{
  if [ ${#D_DPL_TARGET_PATHS_LINUX[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS_LINUX" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_LINUX[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_LINUX" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_LINUX"; fi
  if [ ${#D_DPL_TARGET_PATHS_WSL[@]} -gt 1  -o -n "$D_DPL_TARGET_PATHS_WSL" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_WSL[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_WSL" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_WSL"; fi
}