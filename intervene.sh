#!/usr/bin/env bash
#:title:        Divine Bash script: intervene
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2018.03.25

## Launches the Divine intervention
#
## Launch with '-n' option for a completely harmless dry run: you will be 
#. treated to a list of skipped installations.
#

# Driver function
d__main()
{
  # Locate yourself
  d__whereami

  # Fundamental checks and fixes
  d__load procedure pre-flight

  # Prepare global variables used by the framework
  d__load procedure init-vars

  # Process received arguments
  d__parse_arguments "$@"

  # Import internal dependencies
  d__initialize_fmwk

  # Perform requested routine
  d__perform_routine
}

## d__parse_arguments [ARG]...
#
## Parses arguments that were passed to this script
#
d__parse_arguments()
{
  # Parse options
  local args=() arg opt i
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          y|-yes)       D__OPT_ANSWER=true;;
          n|-no)        D__OPT_ANSWER=false;;
          b|-bundle)    if (($#)); then shift; D__REQ_BUNDLES+=("$1")
                        else printf >&2 "%s: Ignoring option '%s' %s\n" \
                          "$D__FMWK_NAME" "$arg" 'without required argument'
                        fi;;
          f|-force)     D__OPT_FORCE=true;;
          e|-except)    D__OPT_INVERSE=true;;
          w|-with-!)    D__OPT_EXCLAM=true;;
          q|-quiet)     D__OPT_QUIET=true; D__OPT_VERBOSITY=0;;
          v|-verbose)   D__OPT_QUIET=false; ((++D__OPT_VERBOSITY));;
          l|-link)      D__OPT_PLUG_LINK=true;;
          h|-help)      d__load routine help;;
          -version)     d__load routine version;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                y)  D__OPT_ANSWER=true;;
                n)  D__OPT_ANSWER=false;;
                b)  if (($#)); then shift; D__REQ_BUNDLES+=("$1")
                    else printf >&2 "%s: Ignoring option '%s' %s\n" \
                      "$D__FMWK_NAME" "$opt" 'without required argument'
                    fi;;
                f)  D__OPT_FORCE=true;;
                e)  D__OPT_INVERSE=true;;
                w)  D__OPT_EXCLAM=true;;
                q)  D__OPT_QUIET=true; D__OPT_VERBOSITY=0;;
                v)  D__OPT_QUIET=false; ((++D__OPT_VERBOSITY));;
                l)  D__OPT_PLUG_LINK=true;;
                h)  d__load routine help;;
                *)  printf >&2 "%s: Ignoring unrecognized option '%s'\n" \
                      "$D__FMWK_NAME" "$opt"
                    d__load routine usage;;
              esac; done
        esac;;
    *)  [ -n "$arg" ] && args+=("$arg");;
  esac; done

  # Freeze some variables
  readonly D__REQ_BUNDLES
  readonly D__OPT_QUIET
  readonly D__OPT_VERBOSITY
  readonly D__OPT_ANSWER
  readonly D__OPT_FORCE
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
  case ${D__REQ_ARGS[0]} in
    i|in|ins|install)                   D__REQ_ROUTINE=install;;
    r|re|rem|remove|un|uni|uninstall)   D__REQ_ROUTINE=remove;;
    c|ch|che|check)                     D__REQ_ROUTINE=check;;
    a|at|att|attach|ad|add)             D__REQ_ROUTINE=attach;;
    d|de|det|detach|del|delete)         D__REQ_ROUTINE=detach;;
    p|pl|plu|plug)                      D__REQ_ROUTINE=plug;;
    u|up|upd|update)                    D__REQ_ROUTINE=update;;
    cecf357ed9fed1037eb906633a4299ba)   D__REQ_ROUTINE="${D__REQ_ARGS[0]}";;
    '') d__load routine usage;;
    *)  printf >&2 "%s: Ignoring unrecognized routine '%s'\n" \
          "$D__FMWK_NAME" "${D__REQ_ARGS[0]}"
        d__load routine usage;;
  esac; D__REQ_ARGS=("${D__REQ_ARGS[@]:1}")

  # Freeze some variables
  readonly D__REQ_ARGS
  readonly D__REQ_ROUTINE
  
  # Early return from this function for some routines
  case $D__REQ_ROUTINE in
    attach|detach|plug|update)          return 0;;
    cecf357ed9fed1037eb906633a4299ba)   return 0;;
  esac

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

#>  d__initialize_fmwk
#
## Straight-forward helper that sources internal dependencies, in order. 
#. Terminates the script on first failing to source.
#
## Requires:
#.  $D__INIT_TRAIN
#
## Returns:
#.  0 - All dependencies successfully sourced
#.  1 - (script exit) Failed to source a dependency
#
d__initialize_fmwk()
{
  local d__dep
  for d__dep in "${D__INIT_TRAIN[@]}"
  do d__load $d__dep || exit 1; done
}

#>  d__perform_routine
#
## Sub-driver function
#
d__perform_routine()
{
  # Fork based on routine
  case $D__REQ_ROUTINE in
    install)  d__load routine assemble; d__load routine install;;
    remove)   d__load routine assemble; d__load routine remove;;
    check)    d__load routine assemble; d__load routine check;;
    attach)   d__load routine assemble; d__load routine attach;;
    detach)   d__load routine detach;;
    plug)     d__load routine assemble; d__load routine plug;;
    update)   d__load routine update;;
    *)        return 1;;
  esac
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
#
## Reads from the global scope:
#.  $D_DIR        - User-provided override for $D__DIR. Note the single 
#.                  underscore.
#
## Returns:
#.  0 - All assignments successful.
#.  1 - (script exit) Variable name is not writable.
#.  2 - (script exit) Invalid override for $D__DIR.
#
d__whereami()
{
  # Check that required variable names are writable
  local varname err=false
  for varname in D__DIR D__DIR_FMWK D__DIR_LIB D__EXEC_NAME; do
    if ! ( unset $varname &>/dev/null ); then err=true
      printf >&2 '==> %s\n' "Required variable name '$varname' is not writable"
    fi
  done; $err && exit 1
  
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

  # $D__DIR: check for override and set globally
  if [ -z ${D_DIR+isset} ]; then readonly D__DIR="$D__DIR_FMWK"
  else
    printf >&2 "==> Divine directory overridden: '%s'\n" "$D_DIR"
    readonly D__DIR="$D_DIR"
  fi

  # Ensure Divine directory exists and is writable
  if [ -e "$D__DIR" -a ! -d "$D__DIR" ]; then
    printf >&2 "==> Path to Divine directory is occupied: '%s'\n" "$D__DIR"
    exit 2
  fi
  if ! mkdir -p -- "$D__DIR" &>/dev/null || ! [ -w "$D__DIR" ]; then
    printf >&2 "==> Divine directory is not writable: '%s'\n" "$D__DIR"
    exit 2
  fi
}

#>  d__load TYPE NAME
#
## Sources sub-script by name, deducing location by provided type.
#
## Arguments:
#.  $1  - Type of script:
#.          * 'routine'
#.          * 'procedure'
#.          * 'util'
#.          * 'helper'
#.  $2  - Name of script file, without path or suffix.
#
## Returns:
#.  0 - Script loaded successfully.
#.  1 - (script exit) Otherwise.
#
d__load()
{
  # Inspect type and compose path to the script accordingly
  local path; case $1 in
    distro-adapter)   path="${D__DIR_LIB}/adapters/distro/${2}.adp.sh";;
    family-adapter)   path="${D__DIR_LIB}/adapters/family/${2}.adp.sh";;
    helper)           path="${D__DIR_LIB}/helpers/${2}.hlp.sh";;
    procedure)        path="${D__DIR_LIB}/procedures/${2}.pcd.sh";;
    routine)          path="${D__DIR_LIB}/routines/${2}.rtn.sh";;
    util)             path="${D__DIR_LIB}/utils/${2}.utl.sh";;
    *)                printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
                        "Called with illegal type argument: '$1'"; exit 1;;
  esac

  # If file exists, source it; otherwise report and return
  if [ -r "$path" -a -f "$path" ]; then source "$path"; return 0; fi
  printf >&2 "==> Divine dependency is not a readable file: '%s'\n" "$path"
  exit 1
}

d__main "$@"