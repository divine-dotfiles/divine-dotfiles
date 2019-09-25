#!/usr/bin/env bash
#:title:        Divine.dotfiles linux adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    No remark
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support 'linux' family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement detection mechanism
d__adapter_detect_os_family()
{
  [[ $D__OSTYPE = linux* ]] \
    && ! grep -Fqi -e microsoft -e wsl /proc/version 2>/dev/null \
    && d__os_family=linux
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__adapter_override_dpl_targets_for_os_family()
{
  # Check if $D_DPL_TARGET_PATHS_LINUX contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_LINUX[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_LINUX" ]; then

    # $D_DPL_TARGET_PATHS_LINUX is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_LINUX[@]}" )
    
  fi

  # Check if $D_DPL_TARGET_DIR_LINUX is not empty
  if [ -n "$D_DPL_TARGET_DIR_LINUX" ]; then

    # $D_DPL_TARGET_DIR_LINUX is set: use it instead
    D_DPL_TARGET_DIR="$D_DPL_TARGET_DIR_LINUX"
    
  fi
}