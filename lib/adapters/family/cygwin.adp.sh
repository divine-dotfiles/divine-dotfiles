#!/usr/bin/env bash
#:title:        Divine.dotfiles cygwin adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    10
#:revdate:      2019.07.25
#:revremark:    Rewrite OS detection and adapters
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support ‘cygwin’ family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement detection mechanism
d__adapter_detect_os_family()
{
  [[ $d__ostype == cygwin* ]] && d__os_family=cygwin
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__adapter_override_dpl_targets_for_os_family()
{
  # Check if $D_DPL_TARGET_PATHS_CYGWIN contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_CYGWIN[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_CYGWIN" ]; then

    # $D_DPL_TARGET_PATHS_CYGWIN is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_CYGWIN[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_CYGWIN is not empty
  if [ -n "$D_DPL_TARGET_DIR_CYGWIN" ]; then

    # $D_DPL_TARGET_DIR_CYGWIN is set: use it instead
    D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_CYGWIN"
    
  fi
}