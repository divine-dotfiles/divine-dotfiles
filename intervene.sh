#!/usr/bin/env bash
#:title:        Divine Bash script: intervene
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Fix minor typo
#:created_at:   2018.03.25

## Launches the Divine intervention
#
## Launch with '-n' option for a completely harmless dry run: you will be 
#. treated to a list of skipped installations.
#

# Driver function
d__main()
{
  # Fundamental checks and fixes
  d__pre_flight_checks

  # Define constant globals
  d__populate_globals

  # Process received arguments
  d__parse_arguments "$@"

  # Import required dependencies (utilities and helpers)
  d__import_dependencies

  # Perform requested routine
  d__perform_routine
}

#>  d__pre_flight_checks
#
## Checks major version of Bash; applies fixes as necessary; halts the script 
#. if something smells fishy
#
## Returns:
#.  0 - All good
#.  1 - (script exit) Unable to work in current environment
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions, if any
#
d__pre_flight_checks()
{
  # Set sane umask
  umask g-w,o-w

  # Retrieve and inspect major Bash version
  case ${BASH_VERSION:0:1} in
    3|4)
      # Prevent 'write error: Interrupted system call'
      trap '' SIGWINCH
      ;;
    5|6)
      # This is fine
      :
      ;;
    *)
      # Other Bash versions are not supported (yet?)
      printf >&2 "Divine.dotfiles: Unsupported version of Bash -- '%s'\n\n" \
        "${BASH_VERSION}"
      exit 1
      ;;
  esac
  
  # Return zero if gotten to here
  return 0
}

#>  d__populate_globals
#
## This function groups all constant paths and filenames so that they are 
#. easily modified, should the need arise in the future.
#
## Provides into the global scope:
#.  [ too many to list ]
#
## Returns:
#.  0 - All variables successfully assigned
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
d__populate_globals()
{
  # Framework's displayed name
  readonly D__FMWK_NAME='Divine.dotfiles'

  # Framework's displayed version
  readonly D__FMWK_VERSION='1.0.0'

  # Executable's displayed name
  readonly D__EXEC_NAME="$( basename -- "${BASH_SOURCE[0]}" )"

  # Paths to directories within $D__DIR
  d__populate_d_dir_fmwk
  readonly D__DIR_GRAIL="$D__DIR/grail"
  readonly D__DIR_STATE="$D__DIR/state"

  # Paths to directories within $D__DIR_FMWK
  readonly D__DIR_LIB="$D__DIR_FMWK/lib"

  # Paths to directories within $D__DIR_GRAIL
  readonly D__DIR_ASSETS="$D__DIR_GRAIL/assets"
  readonly D__DIR_DPLS="$D__DIR_GRAIL/dpls"

  # Paths to directories within $D__DIR_STATE
  readonly D__DIR_BACKUPS="$D__DIR_STATE/backups"
  readonly D__DIR_STASH="$D__DIR_STATE/stash"
  readonly D__DIR_BUNDLES="$D__DIR_STATE/bundles"

  # Path to adapters directory and adapter file suffix
  readonly D__DIR_ADAPTERS="$D__DIR_LIB/adapters"
  readonly D__DIR_ADP_FAMILY="$D__DIR_ADAPTERS/family"
  readonly D__DIR_ADP_DISTRO="$D__DIR_ADAPTERS/distro"
  readonly D__SUFFIX_ADAPTER=".adp.sh"

  # Path to routines directory and routine file suffix
  readonly D__DIR_ROUTINES="$D__DIR_LIB/routines"
  readonly D__SUFFIX_ROUTINE=".rtn.sh"

  # Path to procedures directory and procedure file suffix
  readonly D__DIR_PROCEDURES="$D__DIR_LIB/procedures"
  readonly D__SUFFIX_PROCEDURE=".pcd.sh"

  # Path to directory containing Bash utility scripts and util file suffix
  readonly D__DIR_UTILS="$D__DIR_LIB/utils"
  readonly D__SUFFIX_UTIL=".utl.sh"

  # Path to directory containing Bash helper functions and helper suffix
  readonly D__DIR_HELPERS="$D__DIR_LIB/helpers"
  readonly D__SUFFIX_HELPER=".hlp.sh"

  # Filename suffix for deployment files
  readonly D__SUFFIX_DPL_SH='.dpl.sh'

  # Filename suffix for asset manifest files
  readonly D__SUFFIX_DPL_MNF='.dpl.mnf'

  # Filename suffix for main queue manifest files
  readonly D__SUFFIX_DPL_QUE='.dpl.que'

  # Ordered list of script's internal dependencies
  D__INIT_TRAIN=( \
    'procedure print-colors' \
    'util dprint' \
    'util dprompt' \
    'util workflow' \
    'procedure prep-1-sys' \
    'util stash' \
    'procedure prep-2-stash' \
    'procedure detect-os' \
    'util offer' \
    'procedure prep-3-opt' \
    'util dreadlink' \
    'util github' \
    'helper github' \
    'util dmv' \
    'util dln' \
    'helper queue' \
    'helper link-queue' \
    'helper copy-queue' \
    'helper multitask' \
    'util manifests' \
    'procedure dpl-repo-sync' \
  ); readonly D__INIT_TRAIN

  # Name of Divinefile
  readonly D__CONST_NAME_DIVINEFILE='Divinefile'
  
  # Name for stash files
  readonly D__CONST_NAME_STASHFILE=".stash.cfg"

  # Default task priority
  readonly D__CONST_DEF_PRIORITY=4096

  # Default width of information plaque
  local terminal_width="$( tput cols )"
  if [[ $terminal_width =~ ^[0-9]+$ ]]; then
    readonly D__CONST_PLAQUE_WIDTH="$terminal_width"
  else
    readonly D__CONST_PLAQUE_WIDTH=80
  fi

  # Textual delimiter for internal use
  readonly D__CONST_DELIMITER=';;;'

  # Regex for extracting D_DPL_NAME from *.dpl.sh file
  readonly D__REGEX_DPL_NAME='D_DPL_NAME=\(.*\)'

  # Regex for extracting D_DPL_DESC from *.dpl.sh file
  readonly D__REGEX_DPL_DESC='D_DPL_DESC=\(.*\)'

  # Regex for extracting D_DPL_PRIORITY from *.dpl.sh file
  readonly D__REGEX_DPL_PRIORITY='D_DPL_PRIORITY=\([0-9][0-9]*\).*'

  # Regex for extracting D_DPL_FLAGS from *.dpl.sh file
  readonly D__REGEX_DPL_FLAGS='D_DPL_FLAGS=\(.*\)'

  # Regex for extracting D_DPL_WARNING from *.dpl.sh file
  readonly D__REGEX_DPL_WARNING='D_DPL_WARNING=\(.*\)'

  # dprint_ode base options (total width with single space delimiters: >=80)
  local remaining_width=$(( D__CONST_PLAQUE_WIDTH - 3 - 3 - 16 - 1 ))
  if (( remaining_width < 57 )); then remaining_width=57; fi
  D__ODE_BASE=( \
    --width-1 3 \
    --width-2 16 \
    --width-3 1 \
    --width-4 $remaining_width \
  ); readonly D__ODE_BASE

  # dprint_ode options for normal messages
  D__ODE_NORMAL=( \
    "${D__ODE_BASE[@]}" \
    --effects-1 bci \
    --effects-2 b \
    --effects-3 n \
    --effects-4 n \
  ); readonly D__ODE_NORMAL

  # dprint_ode options for user prompts
  D__ODE_PROMPT=( \
    -n \
    "${D__ODE_NORMAL[@]}" \
    --width-3 2 \
    --effects-1 n \
  ); readonly D__ODE_PROMPT

  # dprint_ode options for user prompts with danger
  D__ODE_DANGER=( \
    -n \
    "${D__ODE_NORMAL[@]}" \
    --width-3 2 \
    --effects-1 bci \
    --effects-2 bc \
  ); readonly D__ODE_DANGER

  # dprint_ode options for descriptions
  D__ODE_DESC=( \
    "${D__ODE_NORMAL[@]}" \
    --effects-1 n \
  ); readonly D__ODE_DESC

  # dprint_ode options for warnings
  D__ODE_WARN=( \
    "${D__ODE_NORMAL[@]}" \
    --effects-1 n \
    --effects-2 bc \
  ); readonly D__ODE_WARN

  return 0
}

#>  d__populate_d_dir_fmwk
#
## Resolves absolute path to directory containing this script, stores it in a 
#. global read-only variable as the location of the framework. Also, populates 
#. another global variable with absolute path to directory containing framework 
#. directory, which is referred to as divine directory, and may be overridden 
#. by user.
#
## Uses in the global scope:
#.  $D__DIR        - user-provided override for $D__DIR below
#
## Provides into the global scope:
#.  $D__DIR_FMWK   - (read-only) Absolute path to directory containing this 
#.                  script (technically, value of ${BASH_SOURCE[0]}), all 
#.                  symlinks resolved.
#.  $D__DIR        - (read-only) Absolute path to directory containing grail and 
#.                  state directories. By default it is same as $D__DIR_FMWK. 
#.                  User is allowed to override this path.
#
## Returns:
#.  0 - Both assignments successful
#.  1 - (script exit) User provided invalid override for $D__DIR
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
d__populate_d_dir_fmwk()
{
  # Storage variables
  local filename="${BASH_SOURCE[0]}" dirpath d_dir_fmwk d_dir

  #
  # Set $D__DIR_FMWK
  #

  # Resolve all base symlinks
  while [ -L "$filename" ]; do
    dirpath="$( cd -P "$( dirname -- "$filename" )" &>/dev/null && pwd )"
    filename="$( readlink -- "$filename" )"
    [[ $filename != /* ]] && filename="$dirpath/$filename"
  done

  # Also, resolve any non-base symlinks remaining in the path
  d_dir_fmwk="$( cd -P "$( dirname -- "$filename" )" &>/dev/null && pwd )"

  # Ensure global read-only variable with $D__DIR_FMWK path is set
  readonly D__DIR_FMWK="$d_dir_fmwk"

  #
  # Set $D__DIR
  #

  # Make default value
  d_dir="$d_dir_fmwk"

  # Check if global read-only variable with $D__DIR path is set
  if [ -z ${D__DIR+isset} ]; then

    # $D__DIR is not set: set it up
    readonly D__DIR="$d_dir"
  
  else

    # Accept $D__DIR override: make sure it is read-only
    printf >&2 '%s: %s\n' \
      'Divine dir overridden' \
      "$D__DIR"
    readonly D__DIR

  fi

  # $D__DIR is now set: check if it is a writable directory
  if mkdir -p -- "$D__DIR" && [ -w "$D__DIR" ]; then

    # Acceptable $D__DIR path
    :

  else

    # $D__DIR not a writable directory: unwork-able value
    printf >&2 '%s: %s: %s:\n  %s\n' \
      "$D__FMWK_NAME" \
      'Fatal error' \
      '$D__DIR is not a writable directory' \
      "$D__DIR"
    exit 1

  fi
}

## d__parse_arguments [ARG]...
#
## Parses arguments that were passed to this script
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
  D__REQ_MAX_PRIORITY_LEN=1 # Number of digits in largest priority
  
  # Global flags for optionscommand line options
  D__OPT_INVERSE=false       # Flag for whether filtering is inverted
  D__OPT_FORCE=false         # Flag for forceful mode
  D__OPT_EXCLAM=false        # Flag for whether include '!'-dpls by default
  D__OPT_QUIET=true          # Verbosity setting (being deprecated)
  D__OPT_VERBOSITY=0         # New verbosity setting
  D__OPT_ANSWER=             # Blanket answer to all prompts
  D__OPT_PLUG_LINK=false     # Flag for whether copy or symlink Grail dir

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
    *)  printf >&2 "%s: Ignoring unrecognized routine '%s'\n" \
          "$D__FMWK_NAME" "${D__REQ_ARGS[0]}"
        d__load routine usage;;
  esac; shift

  # Freeze some variables
  readonly D__REQ_ARGS=("${D__REQ_ARGS[@]:1}")
  readonly D__REQ_ROUTINE
  
  # Early return from this function for some routines
  case $D__REQ_ROUTINE in
    attach|detach|plug|update)          return 0;;
    cecf357ed9fed1037eb906633a4299ba)   return 0;;
  esac

  # Check if there are normal arguments
  if [ ${#D__REQ_ARGS[@]} -gt 0 -o ${#D__REQ_GROUPS[@]} -gt 0 ]; then
  
    # Set marker; store case sensitivity opt; turn it off
    D__REQ_FILTER=true
    local restore_nocasematch="$( shopt -p nocasematch )"; shopt -s nocasematch

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

    # Restore case sensitivity
    $restore_nocasematch

  fi

  # Freeze some variables
  readonly D__REQ_FILTER
  readonly D__REQ_PKGS
  readonly D__REQ_DPLS
}

#>  d__import_dependencies
#
## Straight-forward helper that sources utilities and helpers this script 
#. depends on, in order. Terminates the script on failing to source a utility 
#. (hard dependencies).
#
## Requires:
#.  $D__INIT_TRAIN   - From d__populate_globals
#
## Returns:
#.  0 - All dependencies successfully sourced
#.  1 - (script exit) Failed to source a dependency
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
d__import_dependencies()
{
  # Storage variable
  local dependency

  # Iterate over dependencies
  for dependency in "${D__INIT_TRAIN[@]}"; do

    # Load dependency or halt script
    d__load $dependency || exit 1

  done
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
  # Inspect type and compose filepath accordingly
  local d__stp d__snm d__sfp; d__stp="$1" d__snm="$2"; case $d__stp in
    routine)    d__sfp="${D__DIR_ROUTINES}/${d__snm}${D__SUFFIX_ROUTINE}";;
    procedure)  d__sfp="${D__DIR_PROCEDURES}/${d__snm}${D__SUFFIX_PROCEDURE}";;
    util)       d__sfp="${D__DIR_UTILS}/${d__snm}${D__SUFFIX_UTIL}";;
    helper)     d__sfp="${D__DIR_HELPERS}/${d__snm}${D__SUFFIX_HELPER}";;
    *)          printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
                  "Called with illegal type argument: '$d__stp'"; exit 1;;
  esac

  # If file exists, source it; otherwise report and return
  if [ -r "$d__sfp" -a -f "$d__sfp" ]; then source "$d__sfp"; return 0; fi
  printf >&2 '%s: %s\n  %s\n' "${FUNCNAME[0]}" \
    'Required script file is not a readable file:' "$d__sfp"
  exit 1
}

d__main "$@"