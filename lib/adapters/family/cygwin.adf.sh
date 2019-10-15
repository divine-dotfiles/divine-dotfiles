#!/usr/bin/env bash
#:title:        Divine.dotfiles cygwin adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support 'cygwin' family of operating systems
#
## For reference, see lib/templates/adapters/family.adf.sh
#

# Marker and dependencies
readonly D__ADF_CYGWIN=loaded

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_family()
{
  if [ ${#D_DPL_TARGET_PATHS_CYGWIN[@]} -gt 1 -o -n "$D_DPL_TARGET_PATHS_CYGWIN" ]
  then D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_CYGWIN[@]}" ); fi
  if [ -n "$D_DPL_TARGET_DIR_CYGWIN" ]
  then D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_CYGWIN"; fi
}