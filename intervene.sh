#!/usr/bin/env bash
#:title:        Divine Bash script: intervene
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.7.0-RELEASE
#:revdate:      2019.07.01
#:revremark:    Major compartmentalization
#:created_at:   2018.03.25

## Launches the Divine intervention
#
## Launch with ‘-n’ option for a completely harmless dry run: you will be 
#. treated to a list of skipped installations.
#

# Driver function
__main()
{
  # Define constant globals
  __populate_globals

  # Process received arguments
  __parse_arguments "$@"

  # Import required dependencies (utilities and helpers)
  __import_dependencies

  # Perform requested routine
  __perform_routine
}

#> __populate_globals
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
__populate_globals()
{
  # Framework’s displayed name
  readonly D__FMWK_NAME='Divine.dotfiles'

  # Executable’s displayed name
  readonly D__EXEC_NAME="$( basename -- "${BASH_SOURCE[0]}" )"

  # Paths to directories within $D__DIR
  __populate_d_dir_fmwk
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
  readonly D__DIR_DPL_REPOS="$D__DIR_STATE/dpl-repos"

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

  # Ordered list of script’s internal dependencies
  D__QUEUE_DEPENDENCIES=( \
    'procedure dep-checks' \
    'util dcolors' \
    'util dprint' \
    'util dprompt' \
    'util dmd5' \
    'helper dstash' \
    'procedure stash-checks' \
    'util dos' \
    'helper offer' \
    'procedure util-offers' \
    'util dtrim' \
    'util dreadlink' \
    'util dmv' \
    'util dln' \
    'helper queue' \
    'helper dln' \
    'helper cp' \
    'helper multitask' \
    'helper assets' \
  ); readonly D__QUEUE_DEPENDENCIES

  # Name of Divinefile
  readonly D__CONST_NAME_DIVINEFILE='Divinefile'
  
  # Name for stash files
  readonly D__CONST_NAME_STASHFILE=".dstash.cfg"

  # Default task priority
  readonly D__CONST_DEF_PRIORITY=4096

  # Default width of information plaque
  readonly D__CONST_PLAQUE_WIDTH=80

  # Textual delimiter for internal use
  readonly D__CONST_DELIMITER=';;;'

  # Regex for extracting D__DPL_NAME from *.dpl.sh file
  readonly D__REGEX_DPL_NAME='D__DPL_NAME=\(.*\)'

  # Regex for extracting D__DPL_DESC from *.dpl.sh file
  readonly D__REGEX_DPL_DESC='D__DPL_DESC=\(.*\)'

  # Regex for extracting D__DPL_PRIORITY from *.dpl.sh file
  readonly D__REGEX_DPL_PRIORITY='D__DPL_PRIORITY=\([0-9][0-9]*\).*'

  # Regex for extracting D__DPL_FLAGS from *.dpl.sh file
  readonly D__REGEX_DPL_FLAGS='D__DPL_FLAGS=\(.*\)'

  # Regex for extracting D__DPL_WARNING from *.dpl.sh file
  readonly D__REGEX_DPL_WARNING='D__DPL_WARNING=\(.*\)'

  # dprint_ode base options (total width with single space delimiters: 80)
  D__ODE_BASE=( \
    --width-1 3 \
    --width-2 16 \
    --width-3 1 \
    --width-4 57 \
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

#> __populate_d_dir_fmwk
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
__populate_d_dir_fmwk()
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

## __parse_arguments [ARG]…
#
## Parses arguments that were passed to this script
#
__parse_arguments()
{
  # Global indicators of current request’s attributes
  D__REQ_ROUTINE=            # Routine to perform
  D__REQ_GROUPS=()           # Array of groups listed
  D__REQ_ARGS=()             # Array of non-option arguments
  D__REQ_FILTER=false        # Flag for whether particular tasks are requested
  D__REQ_PACKAGES=true       # Flag for whether Divinefile is to be processed
  D__REQ_MAX_PRIORITY_LEN=0  # Number of digits in largest priority
  
  # Global flags for optionscommand line options
  D__OPT_INVERSE=false       # Flag for whether filtering is inverted
  D__OPT_FORCE=false         # Flag for forceful mode
  D__OPT_EXCLAM=false        # Flag for whether include ‘!’-dpls by default
  D__OPT_QUIET=true          # Verbosity setting
  D__OPT_ANSWER=             # Blanket answer to all prompts
  D__OPT_PLUG_LINK=false     # Flag for whether copy or symlink Grail dir

  # Parse the first argument
  case "$1" in
    i|install)    D__REQ_ROUTINE=install;;
    r|remove)     D__REQ_ROUTINE=remove;;
    c|check)      D__REQ_ROUTINE=check;;
    a|attach)     D__REQ_ROUTINE=attach;;
    d|detach)     D__REQ_ROUTINE=detach;;
    p|plug)       D__REQ_ROUTINE=plug;;
    u|update)     D__REQ_ROUTINE=update;;
    cecf357ed9fed1037eb906633a4299ba)
                  D__REQ_ROUTINE=cecf357ed9fed1037eb906633a4299ba;;
    -h|--help)    __load routine help;;
    --version)    __load routine version;;
    '')           __load routine usage;;
    *)            printf >&2 '%s: Illegal routine -- %s\n\n' \
                    "$D__FMWK_NAME" \
                    "$1"          
                  __load routine usage
                  ;;
  esac
  shift

  # Freeze some variables
  readonly D__REQ_ROUTINE
  
  # Storage variables
  local delim=false i opt restore_nocasematch arg

  # Parse remaining args for supported options
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { [ -n "$1" ] && D__REQ_ARGS+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                 delim=true;;
      -h|--help)          __load routine help;;
      --version)          __load routine version;;
      -y|--yes)           D__OPT_ANSWER=true;;
      -n|--no)            D__OPT_ANSWER=false;;
      -f|--force)         D__OPT_FORCE=true;;
      -e|--except)        D__OPT_INVERSE=true;;
      -w|--with-!)        D__OPT_EXCLAM=true;;
      -q|--quiet)         D__OPT_QUIET=true;;
      -v|--verbose)       D__OPT_QUIET=false;;
      -l|--link)          D__OPT_PLUG_LINK=true;;
      -*)                 for i in $( seq 2 ${#1} ); do
                            opt="${1:i-1:1}"
                            case $opt in
                              h)  __load routine help;;
                              y)  D__OPT_ANSWER=true;;
                              n)  D__OPT_ANSWER=false;;
                              f)  D__OPT_FORCE=true;;
                              e)  D__OPT_INVERSE=true;;
                              w)  D__OPT_EXCLAM=true;;
                              q)  D__OPT_QUIET=true;;
                              v)  D__OPT_QUIET=false;;
                              l)  D__OPT_PLUG_LINK=true;;
                              *)  printf >&2 '%s: Illegal option -- %s\n\n' \
                                    "$D__FMWK_NAME" \
                                    "$opt"
                                  __load routine usage;;
                            esac
                          done;;
      [0-9]|!)            D__REQ_GROUPS+=("$1");;
      *)                  [ -n "$1" ] && D__REQ_ARGS+=("$1");;
    esac; shift
  done

  # Freeze some variables
  readonly D__OPT_QUIET
  readonly D__OPT_ANSWER
  readonly D__OPT_FORCE
  readonly D__OPT_INVERSE
  readonly D__OPT_EXCLAM
  readonly D__OPT_PLUG_LINK
  readonly D__REQ_GROUPS
  readonly D__REQ_ARGS

  # Early return for some routines
  case $D__REQ_ROUTINE in
    attach|detach|plug|update)          return 0;;
    cecf357ed9fed1037eb906633a4299ba)   return 0;;
  esac

  # Check if there are workable arguments
  if [ ${#D__REQ_ARGS[@]} -gt 0 -o ${#D__REQ_GROUPS[@]} -gt 0 ]; then
  
    # There will be some form of filtering
    D__REQ_FILTER=true

    # In regular filtering, packages are not processed unless asked to
    # In inverse filtering, packages are processed unless asked not to
    $D__OPT_INVERSE || D__REQ_PACKAGES=false

    # Store current case sensitivity setting, then turn it off
    restore_nocasematch="$( shopt -p nocasematch )"
    shopt -s nocasematch

    # Iterate over arguments
    for arg in "${D__REQ_ARGS[@]}"; do
      # If Divinefile is asked for, flip the relevant flag
      [[ $arg =~ ^(Divinefile|dfile|df)$ ]] && {
        $D__OPT_INVERSE && D__REQ_PACKAGES=false || D__REQ_PACKAGES=true
      }
    done

    # Restore case sensitivity
    eval "$restore_nocasematch"

  fi

  # Freeze some variables
  readonly D__REQ_FILTER
  readonly D__REQ_PACKAGES
}

#> __import_dependencies
#
## Straight-forward helper that sources utilities and helpers this script 
#. depends on, in order. Terminates the script on failing to source a utility 
#. (hard dependencies).
#
## Requires:
#.  $D__QUEUE_DEPENDENCIES   - From __populate_globals
#
## Returns:
#.  0 - All dependencies successfully sourced
#.  1 - (script exit) Failed to source a dependency
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__import_dependencies()
{
  # Storage variable
  local dependency

  # Iterate over dependencies
  for dependency in "${D__QUEUE_DEPENDENCIES[@]}"; do

    # Load dependency or halt script
    __load $dependency || exit 1

  done
}

#> __perform_routine
#
## Sub-driver function
#
__perform_routine()
{
  # Always pre-load dpl-repos routine
  __load routine dpl-repos

  # Fork based on routine
  case $D__REQ_ROUTINE in
    install)
      __load routine assemble
      __load routine install;;
    remove)
      __load routine assemble
      __load routine remove;;
    check)
      __load routine assemble
      __load routine check;;
    attach)
      __load routine assemble
      __load routine attach;;
    detach)
      __load routine detach;;
    plug)
      __load routine assemble
      __load routine plug;;
    update)
      __load routine update;;
    *)
      return 1;;
  esac
}

#>  __load TYPE NAME
#
## Sources sub-script by name, deducing location by provided type. It is 
#. expected that necessary function call is present in sourced file.
#
## Arguments:
#.  $1  - Type of script:
#.          * 'routine'
#.          * 'util'
#.          * 'helper'
#.  $2  - Name of script file, without path or suffix
#
## Returns:
#.  1 - Failed to source script
#.  Otherwise, last return code (last command in sourced file)
#.  1 - (script exit) Unrecognized type
#
__load()
{
  # Check type and compose filepath accordingly
  local type="$1"; shift; local name="$1" filepath; case $type in
    routine)    filepath="${D__DIR_ROUTINES}/${name}${D__SUFFIX_ROUTINE}";;
    procedure)  filepath="${D__DIR_PROCEDURES}/${name}${D__SUFFIX_PROCEDURE}";;
    util)       filepath="${D__DIR_UTILS}/${name}${D__SUFFIX_UTIL}";;
    helper)     filepath="${D__DIR_HELPERS}/${name}${D__SUFFIX_HELPER}";;
    *)          printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
                  "Called with illegal type argument: '$type'"; exit 1;;
  esac; shift

  # Check if file exists and source it
  if [ -r "$filepath" -a -f "$filepath" ]; then
    # Source script
    source "$filepath"
    # Return last command’s status
    return $?
  else
    # Report failed sourcing and return
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      "Required script file is not a readable file:"
    printf >&2 '  %s\n' "$filepath"
    return 1
  fi
}

#>  __unset_d_vars
#
## There are a number of standard variables temporarily used by deployments. It 
#. is best to unset those between deployments to ensure no unintended data 
#. retention occurs.
#
__unset_d_vars()
{
  # Storage variables
  local var_assignment var_name

  # Iterate over currently set variables, names of which start with 'D_'
  while read -r var_assignment; do

    # Extract variable’s name
    var_name="$( awk -F  '=' '{print $1}' <<<"$var_assignment" )"

    # If variable is not read-only (i.e., non-essential) — unset it
    ( unset $var_name 2>/dev/null ) && unset $var_name
    
  done < <( grep ^D_ < <( set -o posix; set ) )
}

#>  __unset_d_funcs
#
## There are a number of standard functions temporarily used by deployments. It 
#. is best to unset those between deployments to ensure no unintended data 
#. retention occurs.
#
__unset_d_funcs()
{
  # Storage variables
  local func_assignment func_name

  # Iterate over currently set funcs, names of which start with 'd_'
  while read -r func_assignment; do

    # Extract function’s names
    func_name=${func_assignment#'declare -f '}

    # Unset the function
    unset -f $func_name
    
  done < <( grep ^'declare -f d_' < <( declare -F ) )
}

__main "$@"