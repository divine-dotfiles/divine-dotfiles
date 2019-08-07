#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    11
#:revdate:      2019.08.07
#:revremark:    Grand removal of non-ASCII chars
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support 'macOS' family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement detection mechanism
d__adapter_detect_os_family()
{
  [[ $d__ostype == darwin* ]] && d__os_family=macos
}

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__adapter_override_dpl_targets_for_os_family()
{
  # On macOS targets are overridden by d__adapter_override_dpl_targets_for_os_distro
  :
}