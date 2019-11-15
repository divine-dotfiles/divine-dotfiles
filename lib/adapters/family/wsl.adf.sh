#!/usr/bin/env bash
#:title:        Divine.dotfiles WSL adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.11
#:revremark:    Rename queue arrays
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support 'WSL' family of operating systems (Windows Subsystem for 
#. Linux)
#
## For reference, see lib/templates/adapters/family.adf.sh
#

# Marker and dependencies
readonly D__ADF_WSL=loaded

# Implement overriding mechanism for $D_QUEUE_TARGETS and $D_QUEUE_TARGET_DIR
d__override_dpl_targets_for_os_family()
{
  if [ ${#D_QUEUE_TARGETS_LINUX[@]} -gt 1 -o -n "$D_QUEUE_TARGETS_LINUX" ]
  then D_QUEUE_TARGETS=( "${D_QUEUE_TARGETS_LINUX[@]}" ); fi
  if [ -n "$D_QUEUE_TARGET_DIR_LINUX" ]
  then D_QUEUE_TARGET_DIR="$D_QUEUE_TARGET_DIR_LINUX"; fi
  if [ ${#D_QUEUE_TARGETS_WSL[@]} -gt 1  -o -n "$D_QUEUE_TARGETS_WSL" ]
  then D_QUEUE_TARGETS=( "${D_QUEUE_TARGETS_WSL[@]}" ); fi
  if [ -n "$D_QUEUE_TARGET_DIR_WSL" ]
  then D_QUEUE_TARGET_DIR="$D_QUEUE_TARGET_DIR_WSL"; fi
}