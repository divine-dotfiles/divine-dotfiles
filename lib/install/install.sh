#!/usr/bin/env bash
#:title:        Divine.dotfiles fmwk install script
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.15
#:revremark:    Temporarily switch to dev branch for fmwk (un)installation
#:created_at:   2019.07.22

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This script installs the framework and optional components.
#

# Driver function
d__main()
{
  # Fundamental checks and fixes
  d__load procedure pre-flight

  # Prepare global variables
  d__init_vars

  # Process received arguments
  d__parse_arguments "$@"

  # Perform framework installation routine
  d__load routine fmwk-install
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
  if declare -f d__notify &>/dev/null; then d__notify -- "Loading $1 '$2'"
  else printf >&2 "==> Loading %s '%s'\n" "$1" "$2"; fi
  if curl --version &>/dev/null; then curl -fsSL $url >$tmp
  elif wget --version &>/dev/null; then wget -qO $tmp $url; fi
  if (($?)); then
    printf >&2 '==> Failed to download Divine dependency from:\n        %s' \
      "$url"; rm -f $tmp; exit 1
  fi
  D__DEP_STACK+=( -i- "- $1 $2" ); source $tmp; rc=$?; rm -f $tmp; return $?
}

#>  d__init_vars
#
## This function groups all constant paths, filenames, and other keywords used 
#. by the framework.
#
## Provides into the global scope:
#.  [ too many to list, read on ]
#
## Returns:
#.  0 - Always.
#
d__init_vars()
{
  # Framework's displayed name
  readonly D__FMWK_NAME='Divine.dotfiles'

  # Framework's displayed version
  readonly D__FMWK_VERSION='1.0.0'

  # Framework installation directory
  if [ -z ${D_DIR+isset} ]; then
    readonly D__DIR_FMWK="$HOME/.divine"
  else
    printf >&2 "==> Divine directory overridden: '%s'\n" "$D_DIR"
    readonly D__DIR_FMWK="$D_DIR"
  fi

  # Shortcut installation directory
  if [ -z ${D_SHCT_DIR+isset} ]; then
    D__SHORTCUT_DIR_CANDIDATES=( \
      "$HOME/bin" \
      "$HOME/.bin" \
      '/usr/local/bin' \
      '/usr/bin' \
      '/bin' \
    )
  else
    printf >&2 "==> Divine shortcut directory overridden: '%s'\n" "$D_SHCT_DIR"
    D__SHORTCUT_DIR_CANDIDATES=("$D_SHCT_DIR")
  fi; readonly D__SHORTCUT_DIR_CANDIDATES

  # Shortcut executable name
  if [ -z ${D_SHCT_NAME+isset} ]; then
    readonly D__SHORTCUT_NAME='di'
  else
    printf >&2 "==> Divine shortcut name overridden: '%s'\n" "$D_SHCT_NAME"
    readonly D__SHORTCUT_NAME="$D_SHCT_NAME"
  fi

  # Paths to directories within $D__DIR_FMWK
  readonly D__DIR_GRAIL="$D__DIR_FMWK/grail"
  readonly D__DIR_STATE="$D__DIR_FMWK/state"

  # Paths to directories within $D__DIR_GRAIL
  readonly D__DIR_ASSETS="$D__DIR_GRAIL/assets"
  readonly D__DIR_DPLS="$D__DIR_GRAIL/dpls"

  # Paths to directories within $D__DIR_STATE
  readonly D__DIR_BACKUPS="$D__DIR_STATE/backups"
  readonly D__DIR_STASH="$D__DIR_STATE/stash"
  readonly D__DIR_BUNDLES="$D__DIR_STATE/bundles"
  readonly D__DIR_BUNDLE_BACKUPS="$D__DIR_STATE/bundle-backups"

  # Global indicators of current request's attributes
  D__REQ_ARGS=()            # Array of non-option arguments

  # Global flags for command line options
  D__OPT_FORCE=false        # Flag for forceful mode
  D__OPT_VERBOSITY=0        # New verbosity setting
  D__OPT_ANSWER=            # Blanket answer to all prompts
  D__OPT_ANSWER_F=          # Blanket answer to framework prompts
  D__OPT_ANSWER_S=          # Blanket answer to shortcut prompts

  return 0
}

## d__parse_arguments [ARG]...
#
## Parses arguments that were passed to this script.
#
d__parse_arguments()
{
  # Parse options
  local arg opt i
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)            D__REQ_ARGS+=("$@"); break;;
          y|-yes)       D__OPT_ANSWER=true
                        D__OPT_ANSWER_F=true
                        D__OPT_ANSWER_S=true;;
          n|-no)        D__OPT_ANSWER=false
                        D__OPT_ANSWER_F=false
                        D__OPT_ANSWER_S=false;;
          d|-fmwk-yes)  D__OPT_ANSWER_F=true;;
          D|-fmwk-no)   D__OPT_ANSWER_F=false;;
          s|-shct-yes)  D__OPT_ANSWER_S=true;;
          S|-shct-no)   D__OPT_ANSWER_S=false;;
          f|-force)     D__OPT_FORCE=true;;
          q|-quiet)     D__OPT_VERBOSITY=0;;
          v|-verbose)   ((++D__OPT_VERBOSITY));;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                y)  D__OPT_ANSWER=true
                    D__OPT_ANSWER_F=true
                    D__OPT_ANSWER_S=true;;
                n)  D__OPT_ANSWER=false
                    D__OPT_ANSWER_F=false
                    D__OPT_ANSWER_S=false;;
                d)  D__OPT_ANSWER_F=true;;
                D)  D__OPT_ANSWER_F=false;;
                s)  D__OPT_ANSWER_S=true;;
                S)  D__OPT_ANSWER_S=false;;
                f)  D__OPT_FORCE=true;;
                q)  D__OPT_VERBOSITY=0;;
                v)  ((++D__OPT_VERBOSITY));;
                *)  printf >&2 "%s: Unrecognized option '%s'\n" \
                      "$D__FMWK_NAME" "$opt"; exit 1;;
              esac; done
        esac;;
    *)  [ -n "$arg" ] && D__REQ_ARGS+=("$arg");;
  esac; done

  # Freeze variables
  readonly D__REQ_ARGS
  readonly D__OPT_VERBOSITY
  readonly D__OPT_ANSWER
  readonly D__OPT_ANSWER_F
  readonly D__OPT_ANSWER_S
}

d__main "$@"