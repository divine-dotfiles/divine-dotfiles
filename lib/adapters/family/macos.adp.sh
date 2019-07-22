#!/usr/bin/env bash
#:title:        Divine.dotfiles macOS adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    9
#:revdate:      2019.07.22
#:revremark:    New revisioning system
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. interface with ‘macOS’ family of operating systems
#
## For reference, see lib/templates/adapters/family.adp.sh
#

# Implement overriding mechanism for $D_DPL_TARGET_PATHS and $D_DPL_TARGET_DIR
d__override_dpl_targets_for_os_family()
{
  # On macOS targets are overridden by d__override_dpl_targets_for_os_distro
  :
}