#!/usr/bin/env bash
#:title:        Divine Bash utils: offer
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.15
#:revremark:    Finish rewriting entire framework
#:created_at:   2019.07.06

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper utils that install and remove optional packages.
#

# Marker and dependencies
readonly D__UTL_OFFER=loaded
d__load util workflow
d__load util stash
d__load procedure detect-os
d__load procedure prep-stash

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