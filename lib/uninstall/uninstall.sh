#!/usr/bin/env bash
#:title:        Divine.dotfiles fmwk uninstall script
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.16
#:revremark:    Prioritize arg parsing in main scripts
#:created_at:   2019.07.22

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This script uninstalls the framework and optional components.
#

# Driver function
d__main()
{
  # Process received arguments
  d__parse_arguments "$@"

  # Settle on key globals
  d__wherefrom

  # Load fundamental dependencies: checks and fixes; globals; workflow utils
  d__load procedure pre-flight
  d__load procedure init-vars
  d__load util workflow

  # Perform framework uninstallation routine
  d__perform_routine
}

## d__parse_arguments [ARG]...
#
## Parses arguments that were passed to this script.
#
d__parse_arguments()
{
  # Global indicators of current request's attributes
  D__REQ_ARGS=()            # Array of non-option arguments
  D__REQ_ERRORS=()          # Errors to print instead of launching any routine

  # Global flags for command line options
  D__OPT_FORCE=false        # Flag for forceful mode
  D__OPT_VERBOSITY=0        # Verbosity setting
  D__OPT_ANSWER=            # Blanket answer to all prompts
  D__OPT_ANSWER_F=          # Blanket answer to framework prompts
  D__OPT_ANSWER_U=          # Blanket answer to util prompts

  # Parse options
  local arg opt i
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)            D__REQ_ARGS+=("$@"); break;;
          y|-yes)       D__OPT_ANSWER=true
                        D__OPT_ANSWER_F=true
                        D__OPT_ANSWER_U=true;;
          n|-no)        D__OPT_ANSWER=false
                        D__OPT_ANSWER_F=false
                        D__OPT_ANSWER_U=false;;
          d|-fmwk-yes)  D__OPT_ANSWER_F=true;;
          D|-fmwk-no)   D__OPT_ANSWER_F=false;;
          u|-util-yes)  D__OPT_ANSWER_U=true;;
          U|-util-no)   D__OPT_ANSWER_U=false;;
          f|-force)     D__OPT_FORCE=true;;
          q|-quiet)     D__OPT_VERBOSITY=0;;
          v|-verbose)   ((++D__OPT_VERBOSITY));;
          '') D__REQ_ERRORS+=( -i- "- unrecognized option '-'" );;
          -*) D__REQ_ERRORS+=( -i- "- unrecognized option '$arg'" );;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                y)  D__OPT_ANSWER=true
                    D__OPT_ANSWER_F=true
                    D__OPT_ANSWER_U=true;;
                n)  D__OPT_ANSWER=false
                    D__OPT_ANSWER_F=false
                    D__OPT_ANSWER_U=false;;
                d)  D__OPT_ANSWER_F=true;;
                D)  D__OPT_ANSWER_F=false;;
                u)  D__OPT_ANSWER_U=true;;
                U)  D__OPT_ANSWER_U=false;;
                f)  D__OPT_FORCE=true;;
                q)  D__OPT_VERBOSITY=0;;
                v)  ((++D__OPT_VERBOSITY));;
                *)  D__REQ_ERRORS+=( -i- "- unrecognized option '$opt'" );;
              esac; done
        esac;;
    *)  [ -n "$arg" ] && D__REQ_ARGS+=("$arg");;
  esac; done

  # Freeze variables
  readonly D__REQ_ARGS
  readonly D__OPT_VERBOSITY
  readonly D__OPT_ANSWER
  readonly D__OPT_ANSWER_F
  readonly D__OPT_ANSWER_U
}

#>  d__wherefrom
#
## Prepares installation path of framework to uninstall from; accepts override.
#
## Provides into the global scope:
#.  $D__DIR_FMWK  - (read-only) Absolute path to the directory where the 
#.                  framework is to be uninstalled from.
#.  $D__DIR_LIB   - (read-only) Merely $D__DIR_FMWK with '/lib' appended.
#.  $D__EXEC_NAME - (read-only) Not used in this routine, included for 
#.                  compatibility. Set meaninglessly to 'di'.
#.  $D__DIR       - (read-only) Not directly used in this routine, included for 
#.                  compatibility. Set to the value of $D__DIR_FMWK.
#.  $D__DEP_STACK - (array) Dependency stack for debugging.
#
## Reads from the global scope (note the single underscores):
#.  $D_DIR        - User-provided override for $D__DIR_FMWK.
#
## Returns:
#.  0 - Always.
#
d__wherefrom()
{
  # Initialize dependency stack for debug
  D__DEP_STACK=()

  # Framework installation directory
  if [ -z ${D_DIR+isset} ]; then
    readonly D__DIR_FMWK="$HOME/.divine"
  else
    printf >&2 '\033[36m%s\033[0m\n' \
      "==> Divine directory overridden: '$D_DIR'"
    readonly D__DIR_FMWK="$D_DIR"
  fi

  # Compatibility variables
  readonly D__DIR_LIB="$D__DIR_FMWK/lib"
  readonly D__EXEC_NAME='di'
  readonly D__DIR="$D__DIR_FMWK"

  return 0
}

#>  d__load TYPE NAME
#
## Sources sub-script by type and name. Implements protection against repeated 
#. loading.
#
## Arguments:
#.  $1  - Type of script:
#.          * 'distro-adapter'
#.          * 'family-adapter'
#.          * 'helper'
#.          * 'procedure'
#.          * 'routine'
#.          * 'util'
#.  $2  - Name of script file, without path or suffix.
#
## Returns:
#.  0 - Success: script loaded.
#.  1 - (script exit) Otherwise.
#
d__load()
{
  # Init vars; transform subject name
  local vr="$( printf '%s\n' "$2" | tr a-z- A-Z_ )" tmp rc
  local url='https://raw.github.com/no-simpler/divine-dotfiles/dev/lib'

  # Perform different
  case $1 in
    distro-adapter)   vr="D__ADD_$vr" url+="/adapters/distro/${2}.add.sh";;
    family-adapter)   vr="D__ADF_$vr" url+="/adapters/family/${2}.adf.sh";;
    helper)           vr="D__HLP_$vr" url+="/helpers/${2}.hlp.sh";;
    procedure)        vr="D__PCD_$vr" url+="/procedures/${2}.pcd.sh";;
    routine)          vr="D__RTN_$vr" url+="/routines/${2}.rtn.sh";;
    util)             vr="D__UTL_$vr" url+="/utils/${2}.utl.sh";;
    *)                printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
                        "Called with illegal type argument: '$1'"; exit 1;;
  esac

  # Cut-off for repeated loading
  ( unset "$vr" &>/dev/null ) || return 0

  ## First-time loading: make temp dest, announce intention, download into 
  #. temp, source temp, delete temp, return last code from sourced script
  #
  tmp="$(mktemp)"
  if declare -f d__notify &>/dev/null; then d__notify -l -- "Loading $1 '$2'"
  else printf >&2 '\033[36m%s\033[0m\n' "==> Loading $1 '$2'"; fi
  if curl --version &>/dev/null; then curl -fsSL $url >$tmp
  elif wget --version &>/dev/null; then wget -qO $tmp $url; fi
  if (($?)); then
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      "Dependency is not a readable file: '$path'"
    exit 1
  fi
  D__DEP_STACK+=( -i- "- $1 $2" ); source $tmp; rc=$?; rm -f $tmp; return $?
}

#>  d__perform_routine
#
## Dispatches framework uninstallation routine.
#
d__perform_routine()
{
  # Print request errors, if any
  if ((${#D__REQ_ERRORS[@]}))
  then d__notify -nlx -- 'Request errors:' "${D__REQ_ERRORS[@]}"; exit 1; fi

  # Load routine
  d__load routine fmwk-uninstall; exit $?
}

d__main "$@"