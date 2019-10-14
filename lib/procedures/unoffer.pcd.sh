#!/usr/bin/env bash
#:title:        Divine Bash procedure: unoffer
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Fix minor typo, pt. 3
#:created_at:   2019.10.13

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Uninstalls all optional dependencies that have been previously installed. 
#. This is understood to be a part of the framework uninstallation process.
#

#>  d__uninstall_all_offered_utils
#
## Removes previously offered (and thus installed) optional dependencies using 
#. the system package manager.
#
## Returns:
#.  0 - All recorded optional installations undone. This code includes the case 
#.      where there are no records of optional installations.
#.  1 - Otherwise.
#
d__uninstall_all_offered_utils()
{
  # Switch context; init storage variable
  d__context -- notch
  d__context -l -- push 'Checking for previously installed' \
    'optional dependencies'
  local utla=() utl brw=false erra=() utlc=0

  # Compile the list of previously installed optional dependencies
  if d__stash -gs -- has installed_homebrew
  then brw=true erra+=( -i- '- Homebrew' ); ((++utlc)); fi
  if d__stash -gs -- has installed_utils; then
    while read -r utl; do utla+=("$utl") erra+=( -i- "- $utl" ); ((++utlc))
    done < <( d__stash -gs -- list installed_utils )
  fi

  # Check if the list is empty
  if [ ${#erra[@]} -eq 0 ]; then
    d__context -lt 'Clear' -- pop 'Found zero previously installed' \
      'optional dependencies'
    d__context -- lop; return 0
  fi

  # Switch context; without a package manager, no-go
  d__notify -l! -- 'Previously installed optional dependencies:' "${erra[@]}"
  d__context -l!t 'Found' -- pop 'Number of previously installed' \
    "optional dependencies: $utlc"
  if [ -z "$D__OS_PKGMGR" ]; then
    d__fail -- 'Unable to uninstall optional dependencies' \
      '(no supported package manager)'
    return 1
  else
    d__context -l! -- push 'Uninstalling optional dependencies'
  fi

  # Uninstall one by one; report and return
  $brw && d___uninstall_homebrew
  for utl in "${utla[@]}"; do d___uninstall_util; done
  if ((${#erra[@]}))
  then d__fail -- 'Some uninstallations failed:' "${erra[@]}"; return 1
  else d__context -lvt 'Done' -- pop; d__context -- lop; return 0; fi
}

#>  d___uninstall_homebrew
#
## INTERNAL USE ONLY
#
## Uninstalls previously offered (and thus installed) Homebrew. Assumes the 
#. calling context is the d__uninstall_all_offered_utils function.
#
d___uninstall_homebrew()
{
  # Prepare for uninstallation
  d__context -- notch; d__context -- push 'Uninstalling Homebrew'
  local brw_us="$(mktemp)"
  if ! curl -fsSLo "$brw_us" \
    'https://raw.githubusercontent.com/Homebrew/install/master/uninstall'
  then
    d__fail -- 'Failed to download Homebrew uninstall script'
    erra+=( -i- '- Homebrew' ); rm -f -- "$brw_us"; return 1
  fi
  if ! chmod +x "$brw_us" &>/dev/null; then
    d__fail -- 'Failed to make Homebrew uninstall script executable'
    erra+=( -i- '- Homebrew' ); rm -f -- "$brw_us"; return 1
  fi

  # Launch uninstallation with verbosity in mind
  if (($D__OPT_VERBOSITY)); then local d__ol
    $brw_us --force 2>&1 | while IFS= read -r d__ol || [ -n "$d__ol" ]
      do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
  else $brw_us --force &>/dev/null; fi

  # Check return code
  if ((${PIPESTATUS[0]})); then
    d__fail -- 'Homebrew uninstall script returned an error code'
    erra+=( -i- '- Homebrew' ); rm -f -- "$brw_us"; return 1
  else
    d__notify -lv -- 'Successfully uninstalled Homebrew'
    if d__stash -rs -- unset installed_homebrew; then
      d__notify -- 'Removed installation record of Homebrew from root stash'
    else
      d__fail -- 'Failed to remove installation record of Homebrew' \
        'from root stash'
    fi
    d__context pop; d__context -- lop; rm -f -- "$brw_us"; return 0
  fi
}

#>  d___uninstall_util
#
## INTERNAL USE ONLY
#
## Uninstalls previously offered (and thus installed) utility using the package 
#. manager. Assumes the calling context is the d__uninstall_all_offered_utils 
#. function.
#
d___uninstall_util()
{
  # Prepare for uninstallation
  d__context -- notch
  d__context -- push "Uninstalling '$utl' using '$D__OS_PKGMGR'"

  # Launch uninstallation with verbosity in mind
  if (($D__OPT_VERBOSITY)); then local d__ol
    d__os_pkgmgr remove "$utl" 2>&1 \
      | while IFS= read -r d__ol || [ -n "$d__ol" ]
        do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
  else d__os_pkgmgr remove "$utl" &>/dev/null; fi

  # Check return code
  if ((${PIPESTATUS[0]})); then
    d__fail -- 'Package manager returned an error code'
    erra+=( -i- "- '$utl'" ); return 1
  else
    d__notify -lv -- "Successfully uninstalled '$utl'"
    if d__stash -rs -- unset installed_utils "$utl"; then
      d__notify -- "Removed installation record of '$utl' from root stash"
    else
      d__fail -- "Failed to remove installation record of '$utl'" \
        'from root stash'
    fi
    d__context pop; d__context -- lop; return 0
  fi
}

d__uninstall_all_offered_utils