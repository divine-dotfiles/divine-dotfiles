#!/usr/bin/env bash
#:title:        Divine Bash script: intervene
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.6.0-RELEASE
#:revdate:      2019.05.14
#:revremark:    Streamline adding routine
#:created_at:   2018.03.25

## Launches the Divine intervention
#
## Launch with ‘-n’ option for a completely harmless dry run: you will be 
#. treated to a list of skipped installations.
#

# Driver function
__main()
{
  # Process received arguments
  __parse_arguments "$@"

  # Resolve absolute canonical path to the directory containing this script
  __populate_d_dir

  # Define constant globals
  __populate_globals

  # Import required dependencies (utilities and helpers)
  __import_dependencies

  # Perform requested routine
  __perform_routine
}

## __parse_arguments [ARG]…
#
## Parses arguments that were passed to this script
#
__parse_arguments()
{
  # Define global storage variables
  D_ROUTINE=              # Routine to perform
  D_GROUPS=()             # Array of groups listed
  D_ARGS=()               # Array of non-option arguments
  D_FILTERING=false       # Flag for whether particular tasks are requested
  D_INVERSE_FILTER=false  # Flag for whether filtering is inverted
  D_FORCE=false           # Flag for forceful mode
  D_PKGS=true             # Flag for whether Divinefile is to be processed
  D_QUIET=true            # Verbosity setting
  D_BLANKET_ANSWER=       # Blanket answer to all prompts
  D_MAX_PRIORITY_LEN=0    # Number of digits in largest priority
  D_ADD_MODE=normal       # Flag for how to organize cloned/copied deployments
  D_ADD_LINK=false        # Flag for whether copy or symlink non-repos

  # Parse the first argument
  case "$1" in
    i|install)    D_ROUTINE=install;;
    r|remove)     D_ROUTINE=remove;;
    f|refresh)    D_ROUTINE=refresh;;
    c|check)      D_ROUTINE=check;;
    a|add)        D_ROUTINE=add;;
    u|update)     D_ROUTINE=update;;
    -h|--help)    __show_help_and_exit;;
    --version)    __show_version_and_exit;;
    '')           __show_usage_and_exit;;
    *)            printf >&2 '%s: Illegal routine -- %s\n\n' \
                    "$( basename -- "${BASH_SOURCE[0]}" )" \
                    "$1"          
                  __show_usage_and_exit
                  ;;
  esac
  shift

  # Freeze some variables
  readonly D_ROUTINE
  
  # Storage variables
  local delim=false i opt restore_nocasematch arg

  # Parse remaining args for supported options
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { D_ARGS+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                 delim=true;;
      -h|--help)          __show_help_and_exit;;
      --version)          __show_version_and_exit;;
      -y|--yes)           D_BLANKET_ANSWER=true;;
      -n|--no)            D_BLANKET_ANSWER=false;;
      -f|--force)         D_FORCE=true;;
      -i|--inverse)       D_INVERSE_FILTER=true;;
      -e|--except)        D_INVERSE_FILTER=true;;
      -q|--quiet)         D_QUIET=true;;
      -v|--verbose)       D_QUIET=false;;
      -t|--flat)          D_ADD_MODE=flat;;
      -r|--root)          D_ADD_MODE=root;;
      -l|--link)          D_ADD_LINK=true;;
      -*)                 for i in $( seq 2 ${#1} ); do
                            opt="${1:i-1:1}"
                            case $opt in
                              h)  __show_help_and_exit;;
                              y)  D_BLANKET_ANSWER=true;;
                              n)  D_BLANKET_ANSWER=false;;
                              f)  D_FORCE=true;;
                              i)  D_INVERSE_FILTER=true;;
                              e)  D_INVERSE_FILTER=true;;
                              q)  D_QUIET=true;;
                              v)  D_QUIET=false;;
                              t)  D_ADD_MODE=flat;;
                              r)  D_ADD_MODE=root;;
                              l)  D_ADD_LINK=true;;
                              *)  printf >&2 '%s: Illegal option -- %s\n\n' \
                                    "$( basename -- "${BASH_SOURCE[0]}" )" \
                                    "$opt"
                                  __show_usage_and_exit;;
                            esac
                          done;;
      [0-9]|!)            D_GROUPS+=("$1");;
      *)                  D_ARGS+=("$1");;
    esac; shift
  done

  # Freeze some variables
  readonly D_QUIET
  readonly D_BLANKET_ANSWER
  readonly D_FORCE
  readonly D_INVERSE_FILTER
  readonly D_GROUPS
  readonly D_ARGS
  readonly D_ADD_MODE
  readonly D_ADD_LINK

  # In some routines: skip early
  [ "$D_ROUTINE" = add -o "$D_ROUTINE" = update ] && return 0

  # Check if there are workable arguments
  if [ ${#D_ARGS[@]} -gt 0 -o ${#D_GROUPS[@]} -gt 0 ]; then
  
    # There will be some form of filtering
    D_FILTERING=true

    # In regular filtering, packages are not processed unless asked to
    # In inverse filtering, packages are processed unless asked not to
    $D_INVERSE_FILTER || D_PKGS=false

    # Store current case sensitivity setting, then turn it off
    restore_nocasematch="$( shopt -p nocasematch )"
    shopt -s nocasematch

    # Iterate over arguments
    for arg in "${D_ARGS[@]}"; do
      # If Divinefile is asked for, flip the relevant flag
      [[ $arg =~ ^(Divinefile|dfile|df)$ ]] && {
        $D_INVERSE_FILTER && D_PKGS=false || D_PKGS=true
      }
    done

    # Restore case sensitivity
    eval "$restore_nocasematch"

  fi

  # Freeze some variables
  readonly D_FILTERING
  readonly D_PKGS

}

#> __show_help_and_exit
#
## This function is meant to be called whenever help is explicitly requested. 
#. Prints out a summary of usage scenarios and valid options.
#
## Parameters:
#.  *none*
#
## Returns:
#.  0 - (script exit) Always
#
## Prints:
#.  stdout: Help summary
#.  stderr: As little as possible
#
__show_help_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  # Store help summary in a variable
  local help script_name="$( basename -- "${BASH_SOURCE[0]}" )"
  read -r -d '' help << EOF
NAME
    ${bold}${script_name}${normal} - launch Divine intervention

SYNOPSIS
    ${script_name} i[nstall]|r[emove] [-ynqveif]… [--] [TASK]…
    ${script_name} f|refresh          [-ynqveif]… [--] [TASK]…
    ${script_name} c[heck]            [-ynqvei]…  [--] [TASK]…

    ${script_name} a[dd]              [-yntrl]…    [--] [REPO]…
    ${script_name} u[pdate]           [-yn]…

    ${script_name} --version
    ${script_name} -h|--help

DESCRIPTION
    Modular cross-platform dotfiles framework. Works wherever Bash does.
    
    Launch with '-n' option for a harmless introductory dry run.

    ${bold}Installation routine${normal}

    - Collects tasks from two sources:
      - Package names from 'Divinefile'
      - '*.dpl.sh' files from 'deployments' directory
    - Sorts tasks by priority (${bold}ascending${normal} integer order)
    - Updates installed packages using system’s package manager
    - Performs tasks in order:
      - ${bold}Installs${normal} packages using system’s package manager
      - ${bold}Installs${normal} deployments using 'dinstall' function in each

    ${bold}Removal routine${normal}

    - Collects tasks from two sources:
      - Package names from 'Divinefile'
      - '*.dpl.sh' files from 'deployments' directory
    - ${bold}Reverse${normal}-sorts tasks by priority (${bold}descending${normal} integer order)
    - Updates installed packages using system’s package manager
    - Performs tasks in order:
      - ${bold}Removes${normal} deployments using 'dremove' function in each
      - ${bold}Removes${normal} packages using system’s package manager
    
    ${bold}Refreshing routine${normal}

    - Performs removal routine
    - Performs installation routine

    ${bold}Checking routine${normal}

    - Collects tasks from two sources:
      - Package names from 'Divinefile'
      - '*.dpl.sh' files from 'deployments' directory
    - Sorts tasks by priority (${bold}ascending${normal} integer order)
    - Prints whether each task is installed or not

    ${bold}Adding routine${normal}

    - Accepts deployments in four forms:
      - Built-in Github repo in the form 'NAME' (='no-simpler/divine-dpl-NAME')
      - Github repo in the form 'username/repository'
      - Path to local git repository or directory
      - Path to local deployment file
    - Makes shallow clones of repositories or copies deployment containers into 
      deployments directory
    - Segregates additions based on where they are added from
    - Prompts before overwriting

    ${bold}Updating routine${normal}

    - Updates framework by either pulling from repository or re-downloading and 
      overwriting files one by one
    - Optionally, also tries to pull from remote for every repository currently 
      in deployments directory
    - Ignores arguments

    ${bold}Task list${normal}

    Whenever a list of tasks is provided, only those tasks are performed. Task 
    names are case insensitive. Name 'divinefile' is reserved to refer to 
    Divinefile processing. Other names refer to deployments.

OPTIONS
    -y, --yes       Assume affirmative answer to every prompt. Deployments may 
                    override this option to make sure that user is prompted 
                    every time.

    -n, --no        Assume negatory answer to every prompt. In effect, skips 
                    every task.

    -f, --force     Forego checking if task is already installed (removed) 
                    before installing (removing) it. User prompts still apply.

    -t, --flat      (only for adding routine)
                    For all other routines this is a no-opt.
                    Make each addition a directory directly under deployments 
                    directory, as opposed to grouping additions into 
                    subdirectories by type.

    -r, --root      (only for adding routine)
                    For all other routines this is a no-opt.
                    Replace entire deployments directory itself with deployment 
                    directory being added. Standalone deployments are copied to 
                    root of deployments directory without erasing it.

    -l, --link      (only for adding routine)
                    For all other routines this is a no-opt.
                    Prefer to symlink local deployment files and directories, 
                    and do not try to clone or download repositories.
                    For adding remote deployments this is a no-opt.

    -e, --except, -i, --inverse
                    Inverse task list: filter out tasks included in it

    -q, --quiet     (default) Decreases amount of status messages

    -v, --verbose   Increases amount of status messages

    --version       Show script version

    -h, --help      Show this help summary

AUTHOR
    ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>

    Part of ${bold}Divine.dotfiles${normal} <https://github.com/no-simpler/divine-dotfiles>

    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
EOF

  # Print help summary
  if which less &>/dev/null; then
    less <<<"$help"
  else
    printf '%s\n' "$help"
  fi
  exit 0
}

#> __show_usage_and_exit
#
## Shows usage tip end exits with code 1
#
## Parameters:
#.  *none*
#
## Returns:
#.  1 - (script exit) Always
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Usage tip
#
__show_usage_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  local usage_tip script_name="$( basename -- "${BASH_SOURCE[0]}" )"
  read -r -d '' usage_tip << EOF
Usage: ${bold}${script_name}${normal} ${bold}i${normal}|${bold}install${normal} [-ynqveif] [TASK]…   - Launch installation
   or: ${bold}${script_name}${normal} ${bold}r${normal}|${bold}remove${normal}  [-ynqveif] [TASK]…   - Launch removal
   or: ${bold}${script_name}${normal} ${bold}f${normal}|${bold}refresh${normal} [-ynqveif] [TASK]…   - Launch refreshing
   or: ${bold}${script_name}${normal} ${bold}c${normal}|${bold}check${normal}   [-ynqvei]  [TASK]…   - Launch checking
   or: ${bold}${script_name}${normal} ${bold}a${normal}|${bold}add${normal}     [-yntrl]   [SRC]…    - Add deployment from repo/dir/file
   or: ${bold}${script_name}${normal} ${bold}u${normal}|${bold}update${normal}  [-yn]                - Update framework
   or: ${bold}${script_name}${normal} --version                      - Show script version
   or: ${bold}${script_name}${normal} -h|--help                      - Show help summary
EOF

  # Print usage tip
  printf >&2 '%s\n' "$usage_tip"
  exit 1
}

#> __show_version_and_exit
#
## Shows script version and exits with code 0
#
## Parameters:
#.  *none*
#
## Returns:
#.  0 - (script exit) Always
#
## Prints:
#.  stdout: Version message
#.  stderr: As little as possible
#
__show_version_and_exit()
{
  # Add bolding if available
  local bold normal
  if which tput &>/dev/null; then bold=$(tput bold); normal=$(tput sgr0); fi

  local version_msg
  read -r -d '' version_msg << EOF
${bold}$( basename -- "${BASH_SOURCE[0]}" )${normal} 1.6.0
Part of ${bold}Divine.dotfiles${normal} <https://github.com/no-simpler/divine-dotfiles>
This is free software: you are free to change and redistribute it
There is NO WARRANTY, to the extent permitted by law

Written by ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>
EOF
  # Print version message
  printf '%s\n' "$version_msg"
  exit 0
}

#> __populate_d_dir
#
## Resolves absolute location of the script in which this function is *defined* 
#. and stores it globally, unless it is already occupied and readonly.
#
## Requires:
#.  Bash >=3.2
#
## Parameters:
#.  *none*
#
## Provides into the global scope:
#.  $D_DIR  - (read-only) Absolute path to directory containing 
#.            ${BASH_SOURCE[0]}, all symlinks resolved.
#
## Returns:
#.  Status of $D_DIR assignment
#.  1 - (script exit) If $D_DIR has already been set. It is NOT overwritten.
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__populate_d_dir()
{
  # (Possibly relative) path to this script and a temp var
  local filename="${BASH_SOURCE[0]}" dirpath
  # Resolve all base symlinks
  while [ -L "$filename" ]; do
    dirpath="$( cd -P "$( dirname -- "$filename" )" &>/dev/null && pwd )"
    filename="$( readlink -- "$filename" )"
    [[ $filename != /* ]] && filename="$dirpath/$filename"
  done
  # Set global read-only variable with this script’s dirpath
  if [ -z ${D_DIR+isset} ]; then
    # Also, resolve any non-base symlinks remaining in the path
    readonly \
      D_DIR="$( cd -P "$( dirname -- "$filename" )" &>/dev/null && pwd )"
  else
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Fatal error' \
      'Global variable $D_DIR is already set'
    exit 1
  fi
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
  readonly D_FMWK='Divine.dotfiles'

  # Path to backups directory
  readonly D_BACKUPS_DIR="$D_DIR/backups"

  # Path to lib directory
  readonly D_LIB_DIR="$D_DIR/lib"

  # Path to routines directory and routine file suffix
  readonly D_ROUTINES_DIR="$D_LIB_DIR/routines"
  readonly D_ROUTINE_SUFFIX=".rtn.sh"

  # Path to directory containing Bash utility scripts util file suffix
  readonly D_UTILS_DIR="$D_LIB_DIR"
  readonly D_UTIL_SUFFIX=".utl.sh"

  # Path to directory containing Bash helper functions and helper suffix
  readonly D_HELPERS_DIR="$D_LIB_DIR/helpers"
  readonly D_HELPER_SUFFIX=".hlp.sh"

  # Ordered list of script’s utility and helper dependencies
  D_DEPENDENCIES=( \
    "util dcolors" \
    "util dprint" \
    "util dprompt" \
    "util dmd5" \
    "helper dstash" \
    "util dos" \
    "util dtrim" \
    "util dreadlink" \
    "util dln" \
    "helper dln" \
    "util dmv" \
  ); readonly D_DEPENDENCIES

  # Path to Divinefile
  readonly D_DIVINEFILE_NAME='Divinefile'
  
  # Path to deployments directory
  readonly D_DEPLOYMENTS_DIR="$D_DIR/dpl"

  # Filepath suffix for *.dpl.sh files
  readonly D_DPL_SH_SUFFIX='*.dpl.sh'

  # Prefix for backup files created by deployments
  readonly D_BACKUP_PREFIX='.dvn-backup-'

  # Name for stash files
  readonly D_STASH_FILENAME="stash.cfg"

  # Regex for extracting D_NAME from *.dpl.sh file
  readonly D_DPL_NAME_REGEX='D_NAME=\(.*\)'

  # Regex for extracting D_DESC from *.dpl.sh file
  readonly D_DPL_DESC_REGEX='D_DESC=\(.*\)'

  # Regex for extracting D_WARNING from *.dpl.sh file
  readonly D_DPL_WARNING_REGEX='D_WARNING=\(.*\)'

  # Regex for extracting D_PRIORITY from *.dpl.sh file
  readonly D_DPL_PRIORITY_REGEX='D_PRIORITY=\([0-9][0-9]*\).*'

  # Regex for extracting D_FLAGS from *.dpl.sh file
  readonly D_DPL_FLAGS_REGEX='D_FLAGS=\(.*\)'

  # Default task priority
  readonly D_DEFAULT_PRIORITY=4096

  # Default width of information plaque
  readonly D_PLAQUE_WIDTH=80

  # dprint_ode base options (total width with single space delimiters: 80)
  D_PRINTC_OPTS_BASE=( \
    --width-1 3 \
    --width-2 16 \
    --width-3 1 \
    --width-4 57 \
  ); readonly D_PRINTC_OPTS_BASE

  # dprint_ode options for normal messages
  D_PRINTC_OPTS_NRM=( \
    "${D_PRINTC_OPTS_BASE[@]}" \
    --effects-1 bci \
    --effects-2 b \
    --effects-3 n \
    --effects-4 n \
  ); readonly D_PRINTC_OPTS_NRM

  # dprint_ode options for user prompts
  D_PRINTC_OPTS_PMT=( \
    -n \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --width-3 2 \
    --effects-1 n \
  ); readonly D_PRINTC_OPTS_PMT

  # dprint_ode options for user prompts with danger
  D_PRINTC_OPTS_DNG=( \
    -n \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --width-3 2 \
    --effects-1 bci \
    --effects-2 bc \
  ); readonly D_PRINTC_OPTS_DNG

  # dprint_ode options for descriptions
  D_PRINTC_OPTS_DSC=( \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --effects-1 n \
  ); readonly D_PRINTC_OPTS_DSC

  # dprint_ode options for warnings
  D_PRINTC_OPTS_WRN=( \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --effects-1 n \
    --effects-2 bc \
  ); readonly D_PRINTC_OPTS_WRN

  return 0
}

#> __import_dependencies
#
## Straight-forward helper that sources utilities and helpers this script 
#. depends on, in order. Terminates the script on failing to source a utility 
#. (hard dependencies).
#
## Requires:
#.  $D_DEPENDENCIES     - From __populate_globals
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
  for dependency in "${D_DEPENDENCIES[@]}"; do

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
  case $D_ROUTINE in
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
    add)
      __load routine add;;
    update)
      __load routine fmwk-update;;
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
    routine)  filepath="${D_ROUTINES_DIR}/${name}${D_ROUTINE_SUFFIX}";;
    util)     filepath="${D_UTILS_DIR}/${name}${D_UTIL_SUFFIX}";;
    helper)   filepath="${D_HELPERS_DIR}/${name}${D_HELPER_SUFFIX}";;
    *)        printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
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
  local var_assignment var_name var_is_readonly

  # Iterate over currently set variables, names of which start with 'D_'
  while read -r var_assignment; do

    # Extract variables names
    var_name="$( awk -F  '=' '{print $1}' <<<"$var_assignment" )"

    # If variable is not read-only (i.e., non-essential) — unset it
    ( unset $var_name 2>/dev/null ) && unset $var_name
    
  done < <( grep ^D_ < <( set -o posix; set ) )
}

# Launch driver function
__main "$@"