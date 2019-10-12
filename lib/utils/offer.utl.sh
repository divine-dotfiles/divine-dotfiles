#!/usr/bin/env bash
#:title:        Divine Bash utils: offer
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.07.06

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper utils that install and remove optional packages.
#

#>  d__offer_pkg [--or-quit] UTIL_NAME
#
## Checks whether UTIL_NAME is available on the system and, if not, offers to 
#. install it using system's package manager, if it itself is available.
#
## Options:
#.  --or-quit   - On top of the usual yes/no, gives the user an additional 
#.                third option 'q', which does not install anything and returns 
#.                a different code.
#
## Returns:
#.  0 - The UTIL_NAME is already available, or successfully installed.
#.  1 - The user refused to install the UTIL_NAME, or it failed to install.
#.  2 - (with --or-quit) The user chose the 'q' option.
#
d__offer_pkg()
{
  # Parse args; switch context
  local or_q=; if [ "$1" = --or-quit ]; then or_q='-q'; shift; fi
  local utl="$1"
  d__context -- notch
  d__context -- push "Checking for optional dependency '$utl'"

  # Check whether the util is available
  case $utl in
    git)  git --version &>/dev/null;;
    tar)  tar --version &>/dev/null;;
    curl) curl --version &>/dev/null;;
    wget) wget --version &>/dev/null;;
    *)    type -P -- "$utl" &>/dev/null;;
  esac
  if [ $? -eq 0 ]; then
    d__context -t 'Found' -- pop "Optional dependency '$utl'"
    d__context -- lop; return 0
  fi

  # Switch context; without a package manager, no-go
  d__context -l!t 'Not found' -- pop "Optional dependency '$utl'"
  if [ -z "$D__OS_PKGMGR" ]; then
    d__fail -- "Unable to offer optional dependency '$utl'" \
      '(no supported package manager)'
    return 1
  else d__context -- push "Offering optional dependency '$utl'"; fi

  # Prompt user and check response
  d__prompt -!ap "$D__OPT_ANSWER" "Install '$utl'?" $or_q
  case $? in
    0)  # Switch context
        d__context -l! -- push "Installing optional dependency '$utl'" \
          "using '$D__OS_PKGMGR'"

        # Launch installation with verbosity in mind
        if (($D__OPT_VERBOSITY)); then local d__ol
          d__os_pkgmgr install "$utl" 2>&1 \
            | while IFS= read -r d__ol || [ -n "$d__ol" ]
              do printf >&2 '%s\n' "$CYAN$d__ol$NORMAL"; done
        else d__os_pkgmgr install "$utl" &>/dev/null; fi

        # Check return code
        if ((${PIPESTATUS[0]})); then
          d__fail -- 'Package manager returned an error code'
          return 1
        else
          d__notify -lv -- "Successfully installed '$utl'"
          if d__stash -rs -- set installed_util "$utl"; then
            d__notify -- "Recorded installation of '$utl' to root stash"
          else
            d__fail -- "Failed to record installation of '$utl'" \
              'to root stash'
            return 0
          fi
        fi

        # Finish up
        d__context -lvt 'Done' -- pop; d__context -- lop; return 0
        ;;
    1)  d__context -l!t 'Refused' -- pop "Proceeding without '$utl'"
        d__context -- lop; return 1;;
    2)  d__context -lxt 'Refused' -- pop "Halting in absence of '$utl'"
        d__context -- lop; return 2;;
  esac
}

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