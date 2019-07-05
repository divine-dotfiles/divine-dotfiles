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
  # Framework displayed name
  readonly D_FMWK_NAME='Divine.dotfiles'

  # Paths to directories within $D_DIR
  __populate_d_dir_fmwk
  readonly D_DIR_GRAIL="$D_DIR/grail"
  readonly D_DIR_STATE="$D_DIR/state"

  # Paths to directories within $D_DIR_FMWK
  readonly D_DIR_LIB="$D_DIR_FMWK/lib"

  # Paths to directories within $D_DIR_GRAIL
  readonly D_DIR_ASSETS="$D_DIR_GRAIL/assets"
  readonly D_DIR_DPLS="$D_DIR_GRAIL/dpls"

  # Paths to directories within $D_DIR_STATE
  readonly D_DIR_BACKUPS="$D_DIR_STATE/backups"
  readonly D_DIR_STASH="$D_DIR_STATE/stash"
  readonly D_DIR_DPL_REPOS="$D_DIR_STATE/dpl-repos"

  # Path to adapters directory and adapter file suffix
  readonly D_DIR_ADAPTERS="$D_DIR_LIB/adapters"
  readonly D_DIR_ADP_FAMILY="$D_DIR_ADAPTERS/family"
  readonly D_DIR_ADP_DISTRO="$D_DIR_ADAPTERS/distro"
  readonly D_SUFFIX_ADAPTER=".adp.sh"

  # Path to routines directory and routine file suffix
  readonly D_DIR_ROUTINES="$D_DIR_LIB/routines"
  readonly D_SUFFIX_ROUTINE=".rtn.sh"

  # Path to procedures directory and procedure file suffix
  readonly D_DIR_PROCEDURES="$D_DIR_LIB/procedures"
  readonly D_SUFFIX_PROCEDURE=".pcd.sh"

  # Path to directory containing Bash utility scripts and util file suffix
  readonly D_DIR_UTILS="$D_DIR_LIB/utils"
  readonly D_SUFFIX_UTIL=".utl.sh"

  # Path to directory containing Bash helper functions and helper suffix
  readonly D_DIR_HELPERS="$D_DIR_LIB/helpers"
  readonly D_SUFFIX_HELPER=".hlp.sh"

  # Filename suffix for deployment files
  readonly D_SUFFIX_DPL_SH='.dpl.sh'

  # Filename suffix for asset manifest files
  readonly D_SUFFIX_DPL_MNF='.dpl.mnf'

  # Filename suffix for main queue manifest files
  readonly D_SUFFIX_DPL_QUE='.dpl.que'

  # Ordered list of script’s internal dependencies
  D_QUEUE_DEPENDENCIES=( \
    'procedure dep-check' \
    'util dcolors' \
    'util dprint' \
    'util dprompt' \
    'util dmd5' \
    'helper dstash' \
    'util dos' \
    'util dtrim' \
    'util dreadlink' \
    'util dmv' \
    'util dln' \
    'helper queue' \
    'helper dln' \
    'helper cp' \
    'helper multitask' \
    'helper assets' \
  ); readonly D_QUEUE_DEPENDENCIES

  # Name of Divinefile
  readonly D_CONST_NAME_DIVINEFILE='Divinefile'
  
  # Name for stash files
  readonly D_CONST_NAME_STASHFILE=".dstash.cfg"

  # Default task priority
  readonly D_CONST_DEF_PRIORITY=4096

  # Default width of information plaque
  readonly D_CONST_PLAQUE_WIDTH=80

  # Textual delimiter for internal use
  readonly D_CONST_DELIMITER=';;;'

  # Regex for extracting D_DPL_NAME from *.dpl.sh file
  readonly D_REGEX_DPL_NAME='D_DPL_NAME=\(.*\)'

  # Regex for extracting D_DPL_DESC from *.dpl.sh file
  readonly D_REGEX_DPL_DESC='D_DPL_DESC=\(.*\)'

  # Regex for extracting D_DPL_PRIORITY from *.dpl.sh file
  readonly D_REGEX_DPL_PRIORITY='D_DPL_PRIORITY=\([0-9][0-9]*\).*'

  # Regex for extracting D_DPL_FLAGS from *.dpl.sh file
  readonly D_REGEX_DPL_FLAGS='D_DPL_FLAGS=\(.*\)'

  # Regex for extracting D_DPL_WARNING from *.dpl.sh file
  readonly D_REGEX_DPL_WARNING='D_DPL_WARNING=\(.*\)'

  # dprint_ode base options (total width with single space delimiters: 80)
  D_ODE_BASE=( \
    --width-1 3 \
    --width-2 16 \
    --width-3 1 \
    --width-4 57 \
  ); readonly D_ODE_BASE

  # dprint_ode options for normal messages
  D_ODE_NORMAL=( \
    "${D_ODE_BASE[@]}" \
    --effects-1 bci \
    --effects-2 b \
    --effects-3 n \
    --effects-4 n \
  ); readonly D_ODE_NORMAL

  # dprint_ode options for user prompts
  D_ODE_PROMPT=( \
    -n \
    "${D_ODE_NORMAL[@]}" \
    --width-3 2 \
    --effects-1 n \
  ); readonly D_ODE_PROMPT

  # dprint_ode options for user prompts with danger
  D_ODE_DANGER=( \
    -n \
    "${D_ODE_NORMAL[@]}" \
    --width-3 2 \
    --effects-1 bci \
    --effects-2 bc \
  ); readonly D_ODE_DANGER

  # dprint_ode options for descriptions
  D_ODE_DESC=( \
    "${D_ODE_NORMAL[@]}" \
    --effects-1 n \
  ); readonly D_ODE_DESC

  # dprint_ode options for warnings
  D_ODE_WARN=( \
    "${D_ODE_NORMAL[@]}" \
    --effects-1 n \
    --effects-2 bc \
  ); readonly D_ODE_WARN

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
#.  $D_DIR        - user-provided override for $D_DIR below
#
## Provides into the global scope:
#.  $D_DIR_FMWK   - (read-only) Absolute path to directory containing this 
#.                  script (technically, value of ${BASH_SOURCE[0]}), all 
#.                  symlinks resolved.
#.  $D_DIR        - (read-only) Absolute path to directory containing grail and 
#.                  state directories. By default it is same as $D_DIR_FMWK. 
#.                  User is allowed to override this path.
#
## Returns:
#.  0 - Both assignments successful
#.  1 - (script exit) User provided invalid override for $D_DIR
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
  # Set $D_DIR_FMWK
  #

  # Resolve all base symlinks
  while [ -L "$filename" ]; do
    dirpath="$( cd -P "$( dirname -- "$filename" )" &>/dev/null && pwd )"
    filename="$( readlink -- "$filename" )"
    [[ $filename != /* ]] && filename="$dirpath/$filename"
  done

  # Also, resolve any non-base symlinks remaining in the path
  d_dir_fmwk="$( cd -P "$( dirname -- "$filename" )" &>/dev/null && pwd )"

  # Ensure global read-only variable with $D_DIR_FMWK path is set
  readonly D_DIR_FMWK="$d_dir_fmwk"

  #
  # Set $D_DIR
  #

  # Make default value
  d_dir="$d_dir_fmwk"

  # Check if global read-only variable with $D_DIR path is set
  if [ -z ${D_DIR+isset} ]; then

    # $D_DIR is not set: set it up
    readonly D_DIR="$d_dir"
  
  else

    # Accept $D_DIR override: make sure it is read-only
    printf >&2 '%s: %s\n' \
      'Divine dir overridden' \
      "$D_DIR"
    readonly D_DIR

  fi

  # $D_DIR is now set: check if it is a writable directory
  if mkdir -p -- "$D_DIR" && [ -w "$D_DIR" ]; then

    # Acceptable $D_DIR path
    :

  else

    # $D_DIR not a writable directory: unwork-able value
    printf >&2 '%s: %s: %s:\n  %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Fatal error' \
      '$D_DIR is not a writable directory' \
      "$D_DIR"
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
  D_REQ_ROUTINE=            # Routine to perform
  D_REQ_GROUPS=()           # Array of groups listed
  D_REQ_ARGS=()             # Array of non-option arguments
  D_REQ_FILTER=false        # Flag for whether particular tasks are requested
  D_REQ_PACKAGES=true       # Flag for whether Divinefile is to be processed
  D_REQ_MAX_PRIORITY_LEN=0  # Number of digits in largest priority
  
  # Global flags for optionscommand line options
  D_OPT_INVERSE=false       # Flag for whether filtering is inverted
  D_OPT_FORCE=false         # Flag for forceful mode
  D_OPT_QUIET=true          # Verbosity setting
  D_OPT_ANSWER=             # Blanket answer to all prompts
  D_OPT_PLUG_LINK=false     # Flag for whether copy or symlink Grail dir

  # Parse the first argument
  case "$1" in
    i|install)    D_REQ_ROUTINE=install;;
    r|remove)     D_REQ_ROUTINE=remove;;
    f|refresh)    D_REQ_ROUTINE=refresh;;
    c|check)      D_REQ_ROUTINE=check;;
    a|attach)     D_REQ_ROUTINE=attach;;
    d|detach)     D_REQ_ROUTINE=detach;;
    p|plug)       D_REQ_ROUTINE=plug;;
    u|update)     D_REQ_ROUTINE=update;;
    -h|--help)    __load routine help;;
    --version)    __load routine version;;
    '')           __load routine usage;;
    *)            printf >&2 '%s: Illegal routine -- %s\n\n' \
                    "$( basename -- "${BASH_SOURCE[0]}" )" \
                    "$1"          
                  __load routine usage
                  ;;
  esac
  shift

  # Freeze some variables
  readonly D_REQ_ROUTINE
  
  # Storage variables
  local delim=false i opt restore_nocasematch arg

  # Parse remaining args for supported options
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { [ -n "$1" ] && D_REQ_ARGS+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                 delim=true;;
      -h|--help)          __load routine help;;
      --version)          __load routine version;;
      -y|--yes)           D_OPT_ANSWER=true;;
      -n|--no)            D_OPT_ANSWER=false;;
      -f|--force)         D_OPT_FORCE=true;;
      -i|--inverse)       D_OPT_INVERSE=true;;
      -e|--except)        D_OPT_INVERSE=true;;
      -q|--quiet)         D_OPT_QUIET=true;;
      -v|--verbose)       D_OPT_QUIET=false;;
      -l|--link)          D_OPT_PLUG_LINK=true;;
      -*)                 for i in $( seq 2 ${#1} ); do
                            opt="${1:i-1:1}"
                            case $opt in
                              h)  __load routine help;;
                              y)  D_OPT_ANSWER=true;;
                              n)  D_OPT_ANSWER=false;;
                              f)  D_OPT_FORCE=true;;
                              i)  D_OPT_INVERSE=true;;
                              e)  D_OPT_INVERSE=true;;
                              q)  D_OPT_QUIET=true;;
                              v)  D_OPT_QUIET=false;;
                              l)  D_OPT_PLUG_LINK=true;;
                              *)  printf >&2 '%s: Illegal option -- %s\n\n' \
                                    "$( basename -- "${BASH_SOURCE[0]}" )" \
                                    "$opt"
                                  __load routine usage;;
                            esac
                          done;;
      [0-9]|!)            D_REQ_GROUPS+=("$1");;
      *)                  [ -n "$1" ] && D_REQ_ARGS+=("$1");;
    esac; shift
  done

  # Freeze some variables
  readonly D_OPT_QUIET
  readonly D_OPT_ANSWER
  readonly D_OPT_FORCE
  readonly D_OPT_INVERSE
  readonly D_OPT_PLUG_LINK
  readonly D_REQ_GROUPS
  readonly D_REQ_ARGS

  # In some routines: skip early
  [[ $D_REQ_ROUTINE =~ ^(attach|detach|plug|update)$ ]] && return 0

  # Check if there are workable arguments
  if [ ${#D_REQ_ARGS[@]} -gt 0 -o ${#D_REQ_GROUPS[@]} -gt 0 ]; then
  
    # There will be some form of filtering
    D_REQ_FILTER=true

    # In regular filtering, packages are not processed unless asked to
    # In inverse filtering, packages are processed unless asked not to
    $D_OPT_INVERSE || D_REQ_PACKAGES=false

    # Store current case sensitivity setting, then turn it off
    restore_nocasematch="$( shopt -p nocasematch )"
    shopt -s nocasematch

    # Iterate over arguments
    for arg in "${D_REQ_ARGS[@]}"; do
      # If Divinefile is asked for, flip the relevant flag
      [[ $arg =~ ^(Divinefile|dfile|df)$ ]] && {
        $D_OPT_INVERSE && D_REQ_PACKAGES=false || D_REQ_PACKAGES=true
      }
    done

    # Restore case sensitivity
    eval "$restore_nocasematch"

  fi

  # Freeze some variables
  readonly D_REQ_FILTER
  readonly D_REQ_PACKAGES
}

#> __import_dependencies
#
## Straight-forward helper that sources utilities and helpers this script 
#. depends on, in order. Terminates the script on failing to source a utility 
#. (hard dependencies).
#
## Requires:
#.  $D_QUEUE_DEPENDENCIES   - From __populate_globals
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
  for dependency in "${D_QUEUE_DEPENDENCIES[@]}"; do

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
  case $D_REQ_ROUTINE in
    install)
      __load routine assemble
      __load routine install;;
    remove)
      __load routine assemble
      __load routine remove;;
    refresh)
      __load routine assemble
      __load routine remove && printf '\n' && __load routine install;;
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
    routine)    filepath="${D_DIR_ROUTINES}/${name}${D_SUFFIX_ROUTINE}";;
    procedure)  filepath="${D_DIR_PROCEDURES}/${name}${D_SUFFIX_PROCEDURE}";;
    util)       filepath="${D_DIR_UTILS}/${name}${D_SUFFIX_UTIL}";;
    helper)     filepath="${D_DIR_HELPERS}/${name}${D_SUFFIX_HELPER}";;
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

  # Iterate over currently set funcs, names of which start with '__d__'
  while read -r func_assignment; do

    # Extract function’s names
    func_name=${func_assignment#'declare -f '}

    # Unset the function
    unset -f $func_name
    
  done < <( grep ^'declare -f __d__' < <( declare -F ) )
}

__main "$@"