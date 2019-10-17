#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-pkgmgr
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.17
#:revremark:    Improve existing dir handling during fmwk installation
#:created_at:   2019.10.17

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Updates all installed system packages, if package manager is detected.
#

# Marker and dependencies
readonly D__PCD_PREP_PKGMGR=loaded
d__load util workflow
d__load util detect-os

# Driver function
d__pcd_prep_pkgmgr()
{
  # Cut-off check
  if [ -z "$D__OS_PKGMGR" ]; then
    d__notify -lx -- 'Skipping updating packages' \
      '(package manager not supported)'
    return 1
  fi

  # Announce
  d__notify -l! -- "Updating system packages via '$D__OS_PKGMGR'"

  # Launch OS package manager with verbosity in mind
  if (($D__OPT_VERBOSITY)); then local d__ol
    d__os_pkgmgr update 2>&1 \
      | while IFS= read -r d__ol || [ -n "$d__ol" ]
        do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
  else d__os_pkgmgr update &>/dev/null; fi

  # Check return status
  if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    d__notify -lv -- "Updated system packages via '$D__OS_PKGMGR'"
    return 0
  else
    d__notify -l! -- "System package manager '$D__OS_PKGMGR'" \
      'returned an error code while updating packages' \
      -n- 'This may or may not be problematic'
    return 1
  fi
}

d__pcd_prep_pkgmgr