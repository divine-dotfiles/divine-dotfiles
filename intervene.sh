#!/usr/bin/env bash
#:title:        Divine Bash script: intervene
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.31
#:revremark:    Add more routine name synonyms, pt.2
#:created_at:   2018.03.25

## Launches the Divine intervention
#
## Launch with '-n' option for a completely harmless dry run: you will be 
#. treated to a list of skipped installations.
#

# Driver function
d__main()
{
  # Process received arguments
  d__parse_arguments "$@"

  # Settle on key globals
  d__whereami

  # Load fundamental dependencies: checks and fixes; globals; workflow utils
  d__load procedure pre-flight
  d__load procedure init-vars
  d__load util workflow

  # Perform requested routine
  d__perform_routine
}

## d__parse_arguments [ARG]...
#
## Parses arguments that were passed to this script.
#
d__parse_arguments()
{
  # Global indicators of current request's attributes
  D__REQ_ROUTINE=           # Routine to perform
  D__REQ_GROUPS=()          # Array of groups listed
  D__REQ_ARGS=()            # Array of non-option arguments
  D__REQ_BUNDLES=()         # Array of bundles to process
  D__REQ_FILTER=false       # Flag for whether particular tasks are requested
  D__REQ_PKGS=true          # Flag for whether Divinefiles are requested
  D__REQ_DPLS=true          # Flag for whether deployments are requested
  D__REQ_ERRORS=()          # Errors to print instead of launching any routine

  # Global flags for command line options
  D__OPT_INVERSE=false      # Flag for whether filtering is inverted
  D__OPT_FORCE=false        # Flag for forceful mode
  D__OPT_OBLITERATE=false   # Flag for slash-and-burn mode
  D__OPT_EXCLAM=false       # Flag for whether include '!'-dpls by default
  D__OPT_VERBOSITY=0        # Verbosity setting
  D__OPT_ANSWER=            # Blanket answer to all prompts
  D__OPT_PLUG_LINK=false    # Flag for whether copy or symlink Grail dir
  D__OPT_ANSWER_F=          # Blanket answer to framework prompts
  D__OPT_ANSWER_S=          # Blanket answer to shortcut prompts
  D__OPT_ANSWER_U=          # Blanket answer to util prompts

  # Parse options
  local args=() arg opt i rtn erra=()
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)            args+=("$@"); break;;
          y|-yes)       D__OPT_ANSWER=true D__OPT_ANSWER_F=true
                        D__OPT_ANSWER_S=true D__OPT_ANSWER_U=true;;
          n|-no)        D__OPT_ANSWER=false D__OPT_ANSWER_F=false
                        D__OPT_ANSWER_S=false D__OPT_ANSWER_U=false;;
          d|-fmwk-yes)  D__OPT_ANSWER_F=true;;
          D|-fmwk-no)   D__OPT_ANSWER_F=false;;
          s|-shct-yes)  D__OPT_ANSWER_S=true;;
          S|-shct-no)   D__OPT_ANSWER_S=false;;
          u|-util-yes)  D__OPT_ANSWER_U=true;;
          U|-util-no)   D__OPT_ANSWER_U=false;;
          b|-bundle)    if (($#)); then D__REQ_BUNDLES+=("$1"); shift
                        else erra+=( -i- "- option '$arg' requires argument" )
                        fi;;
          f|-force)     D__OPT_FORCE=true;;
          o|-obliterate)  D__OPT_OBLITERATE=true;;
          e|-except)    D__OPT_INVERSE=true;;
          w|-with-!)    D__OPT_EXCLAM=true;;
          q|-quiet)     D__OPT_VERBOSITY=0;;
          v|-verbose)   ((++D__OPT_VERBOSITY));;
          l|-link)      D__OPT_PLUG_LINK=true;;
          h|-help)      [ -z "$rtn" ] && rtn=help;;
          -version)     [ -z "$rtn" ] && rtn=version;;
          '')           erra+=( -i- "- unrecognized option '-'" );;
          -*)           erra+=( -i- "- unrecognized option '$arg'" );;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                y)  D__OPT_ANSWER=true D__OPT_ANSWER_F=true
                    D__OPT_ANSWER_S=true D__OPT_ANSWER_U=true;;
                n)  D__OPT_ANSWER=false D__OPT_ANSWER_F=false
                    D__OPT_ANSWER_S=false D__OPT_ANSWER_U=false;;
                d)  D__OPT_ANSWER_F=true;;
                D)  D__OPT_ANSWER_F=false;;
                s)  D__OPT_ANSWER_S=true;;
                S)  D__OPT_ANSWER_S=false;;
                u)  D__OPT_ANSWER_U=true;;
                U)  D__OPT_ANSWER_U=false;;
                b)  if (($#)); then D__REQ_BUNDLES+=("$1"); shift
                    else erra+=( -i- "- option '$opt' requires argument" )
                    fi;;
                f)  D__OPT_FORCE=true;;
                o)  D__OPT_OBLITERATE=true;;
                e)  D__OPT_INVERSE=true;;
                w)  D__OPT_EXCLAM=true;;
                q)  D__OPT_VERBOSITY=0;;
                v)  ((++D__OPT_VERBOSITY));;
                l)  D__OPT_PLUG_LINK=true;;
                h)  rtn=help;;
                *)  erra+=( -i- "- unrecognized option '$opt'" );;
              esac; done
        esac;;
    *)  [ -n "$arg" ] && args+=("$arg");;
  esac; done

  # If there are request errors already, cement the routine
  if ((${#erra[@]})); then readonly D__REQ_ROUTINE=usage; fi

  # Freeze some variables
  readonly D__REQ_BUNDLES
  readonly D__OPT_VERBOSITY
  readonly D__OPT_ANSWER
  readonly D__OPT_FORCE
  readonly D__OPT_OBLITERATE
  readonly D__OPT_INVERSE
  readonly D__OPT_PLUG_LINK

  # Parse arguments
  for arg in "${args[@]}"; do case $arg in
    [0-9])  D__REQ_GROUPS+=("$arg");;
    \!)     D__OPT_EXCLAM=true; D__REQ_GROUPS+=("$arg");;
    *)      D__REQ_ARGS+=("$arg");;
  esac; done

  # Freeze some variables
  readonly D__REQ_GROUPS
  readonly D__OPT_EXCLAM

  # Parse the first argument
  local rarg="${D__REQ_ARGS[0]}"; D__REQ_ARGS=("${D__REQ_ARGS[@]:1}")
  case $rarg in
    c|ch|che|check)                       rtn=check;;
    i|in|ins|install)                     rtn=install;;
    r|re|rm|rem|remove|un|uni|uninstall)  rtn=remove;;
    a|at|att|attach|ad|add)               rtn=attach;;
    d|de|dt|det|detach|del|delete)        rtn=detach;;
    p|pl|pg|plu|plug)                     rtn=plug;;
    u|up|ud|upd|update)                   rtn=update;;
    v|ve|vr|ver|version)                  rtn=version;;
    h|he|hl|hp|hel|help)                  rtn=help;;
    us|ug|usa|usage)                      rtn=usage;;
    fmwk-install|fi)                      rtn=fmwk-install;;
    fmwk-uninstall|fu|fr)                 rtn=fmwk-uninstall;;
    '') rtn=usage;;
    *)  rtn=usage erra+=( -i- "- unrecognized routine '$rarg'" );;
  esac; ((${#erra[@]})) && D__REQ_ERRORS+=("${erra[@]}")

  # Freeze some variables
  readonly D__REQ_ARGS
  
  # If routine is not cemented yet, do it
  if [ -z "$D__REQ_ROUTINE" ]; then readonly D__REQ_ROUTINE="$rtn"; fi

  # Early return options: request errors or particular routines
  if ((${#D__REQ_ERRORS[@]})); then return 0; fi
  case $D__REQ_ROUTINE in check|install|remove) :;; *) return 0;; esac

  # Check if there are normal arguments
  if [ ${#D__REQ_ARGS[@]} -gt 0 -o ${#D__REQ_GROUPS[@]} -gt 0 ]; then
  
    # Set marker; disable case sensitivity opt
    D__REQ_FILTER=true; $D__DISABLE_CASE_SENSITIVITY

    # Weed out obvious exclusions
    if $D__OPT_INVERSE; then
      for arg in "${D__REQ_ARGS[@]}"; do case $arg in
        Divinefile|dfile|df) D__REQ_PKGS=false;;
      esac; done
    else
      D__REQ_PKGS=false D__REQ_DPLS=false
      for arg in "${D__REQ_ARGS[@]}"; do case $arg in '') continue;;
        Divinefile|dfile|df) D__REQ_PKGS=true;; *) D__REQ_DPLS=true;;
      esac; done
    fi

    $D__RESTORE_CASE_SENSITIVITY

  fi

  # Freeze some variables
  readonly D__REQ_FILTER
  readonly D__REQ_PKGS
  readonly D__REQ_DPLS
}

#>  d__whereami
#
## Resolves the absolute path to the directory containing this script, allows 
#. the user to override the location of the Grail and state directories.
#
## Provides into the global scope:
#.  $D__DIR_FMWK  - (read-only) Absolute path to the directory containing this 
#.                  script, the fully canonicalized value of ${BASH_SOURCE[0]}. 
#.                  This variable is used to locate and source the framework 
#.                  components in the lib/ directory.
#.  $D__DIR_LIB   - (read-only) Merely $D__DIR_FMWK with '/lib' appended.
#.  $D__EXEC_NAME - (read-only) The name of the executable used to launch this 
#.                  script.
#.  $D__DIR       - (read-only) By default, the same as D__DIR_FMWK. This 
#.                  variable is used to locate and source the files in the 
#.                  Grail and state directories.
#.  $D__DEP_STACK - (array) Dependency stack for debugging.
#
## Reads from the global scope (note the single underscore):
#.  $D_DIR        - User-provided override for $D__DIR.
#
## Returns:
#.  0 - Always.
#
d__whereami()
{
  # Initialize dependency stack for debug
  D__DEP_STACK=()

  # DEPRECATED BLOCK; NOT USED
  # # Check that required variable names are writable
  # local var err=false
  # for var in D__DIR D__DIR_FMWK D__DIR_LIB D__EXEC_NAME; do
  #   if ! ( unset $var &>/dev/null ); then err=true
  #     printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
  #       "Required variable name '$var' is not writable"
  #   fi
  # done; $err && exit 1
  
  # $D__EXEC_NAME; $D__DIR_FMWK & $D__DIR_LIB: canonicalize and set globally
  local filepath="${BASH_SOURCE[0]}" dirpath
  readonly D__EXEC_NAME="$( basename -- "$filepath" )"
  while [ -L "$filepath" ]; do
    dirpath="$( cd -P "$( dirname -- "$filepath" )" &>/dev/null && pwd )"
    filepath="$( readlink -- "$filepath" )"
    [[ $filepath != /* ]] && filepath="$dirpath/$filepath"
  done
  filepath="$( cd -P "$( dirname -- "$filepath" )" &>/dev/null && pwd )"
  readonly D__DIR_FMWK="$filepath"
  readonly D__DIR_LIB="$D__DIR_FMWK/lib"

  # Special interpretation for 'fmwk-install' routine
  if [ "$D__REQ_ROUTINE" = fmwk-install ]; then

    # Framework installation directory
    if [ -z ${D_DIR+isset} ]; then readonly D__DIR="$HOME/.divine"
    else
      printf >&2 '\033[36m%s\033[0m\n' \
        "==> Divine directory overridden: '$D_DIR'"
      readonly D__DIR="$D_DIR"
    fi

    # Shortcut installation directory
    if [ -z ${D_SHCT_DIR+isset} ]; then
      D__SHORTCUT_DIR_CANDIDATES=( "$HOME/bin"  "$HOME/.bin" '/usr/local/bin' \
        '/usr/bin' '/bin' )
    else
      printf >&2 '\033[36m%s\033[0m\n' \
        "==> Divine shortcut directory overridden: '$D_SHCT_DIR'"
      D__SHORTCUT_DIR_CANDIDATES=("$D_SHCT_DIR")
    fi; readonly D__SHORTCUT_DIR_CANDIDATES

    # Shortcut executable name
    if [ -z ${D_SHCT_NAME+isset} ]; then readonly D__SHORTCUT_NAME='di'
    else
      printf >&2 '\033[36m%s\033[0m\n' \
        "==> Divine shortcut name overridden: '$D_SHCT_NAME'"
      readonly D__SHORTCUT_NAME="$D_SHCT_NAME"
    fi

    return 0

  fi

  # Special interpretation for 'fmwk-uninstall' routine
  if [ "$D__REQ_ROUTINE" = fmwk-uninstall ]; then

    # Framework installation directory
    if [ -z ${D_DIR+isset} ]; then readonly D__DIR="$HOME/.divine"
    else
      printf >&2 '\033[36m%s\033[0m\n' \
        "==> Divine directory overridden: '$D_DIR'"
      readonly D__DIR="$D_DIR"
    fi

    return 0

  fi

  # Regular routines

  # $D__DIR: check for override and set globally
  if [ -z ${D_DIR+isset} ]; then readonly D__DIR="$D__DIR_FMWK"
  else
    printf >&2 '\033[36m%s\033[0m\n' \
      "==> Divine directory overridden: '$D_DIR'"
    readonly D__DIR="$D_DIR"
  fi

  # Ensure Divine directory exists and is writable
  if [ -e "$D__DIR" -a ! -d "$D__DIR" ]; then
    D__REQ_ERRORS+=( -i- "- path occupied: $D__DIR" )
  elif ! mkdir -p -- "$D__DIR" &>/dev/null || ! [ -w "$D__DIR" ]; then
    D__REQ_ERRORS+=( -i- "- path not writable: $D__DIR" )
  fi

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
  local path="$D__DIR_LIB" vr="$( printf '%s\n' "$2" | tr a-z- A-Z_ )"

  # Perform different
  case $1 in
    distro-adapter)   vr="D__ADD_$vr" path+="/adapters/distro/${2}.add.sh";;
    family-adapter)   vr="D__ADF_$vr" path+="/adapters/family/${2}.adf.sh";;
    helper)           vr="D__HLP_$vr" path+="/helpers/${2}.hlp.sh";;
    procedure)        vr="D__PCD_$vr" path+="/procedures/${2}.pcd.sh";;
    routine)          vr="D__RTN_$vr" path+="/routines/${2}.rtn.sh";;
    util)             vr="D__UTL_$vr" path+="/utils/${2}.utl.sh";;
    *)                printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
                        "Called with illegal type argument: '$1'"; exit 1;;
  esac

  # Cut-off for repeated loading
  ( unset "$vr" &>/dev/null ) || return 0

  # Announce loading
  if declare -f d__notify &>/dev/null; then d__notify -qqq -- "Loading $1 '$2'"
  elif ((D__OPT_VERBOSITY>=3))
  then printf >&2 '\033[36m%s\033[0m\n' "==> Loading $1 '$2'"; fi

  # First-time loading: check if readable and source
  if ! [ -r "$path" -a -f "$path" ]; then
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      "Dependency is not a readable file: '$path'"
    exit 1
  fi
  D__DEP_STACK+=( -i- "- $1 $2" ); source "$path"; return $?
}

#>  d__perform_routine
#
## Dispatches previously detected routine; prints errors.
#
d__perform_routine()
{
  # Print request errors, if any
  if ((${#D__REQ_ERRORS[@]}))
  then d__notify -nlx -- 'Request errors:' "${D__REQ_ERRORS[@]}"; fi

  # Fork based on routine
  local rc; case $D__REQ_ROUTINE in
    check)          d__load routine check;;
    install)        d__load routine install;;
    remove)         d__load routine remove;;
    attach)         d__load routine attach;;
    detach)         d__load routine detach;;
    plug)           d__load routine plug;;
    update)         d__load routine update;;
    version)        d__load routine version;;
    help)           d__load routine help;;
    fmwk-install)   d__load routine fmwk-install;;
    fmwk-uninstall) d__load routine fmwk-uninstall;;
    *)              d__load routine usage;;
  esac; rc=$?

  # Output dependency stack and return
  d__notify -qqqq -- 'Dependencies loaded:' "${D__DEP_STACK[@]}"
  exit $rc
}

d__main "$@"