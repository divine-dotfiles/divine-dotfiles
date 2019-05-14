#!/usr/bin/env bash
#:title:        Divine Bash script: intervene
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1.5.1-RELEASE
#:revdate:      2019.05.07
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

  # Put together the tasks to be undertaken
  __assemble_tasks

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
      -y|--yes)           D_BLANKET_ANSWER=y;;
      -n|--no)            D_BLANKET_ANSWER=n;;
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
                              y)  D_BLANKET_ANSWER=y;;
                              n)  D_BLANKET_ANSWER=n;;
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

  # If in adding routine, bail out early
  [ "$D_ROUTINE" = add ] && return 0

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

    ${bold}Task list${normal}

    Whenever a list of tasks is provided, only those tasks are performed. Task 
    names are case insensitive. Name 'divinefile' is reserved to refer to 
    Divinefile processing. Other names refer to deployments.

OPTIONS
    -y, --yes
                    Assume affirmative answer to every prompt. Deployments may 
                    override this option to make sure that user is prompted 
                    every time.
    -n, --no
                    Assume negatory answer to every prompt. In effect, skips 
                    every task.
    -f, --force     Forego checking if task is already installed (removed) 
                    before installing (removing) it. User prompts still apply.
    -t, --flat      In adding routine:
                    Make each addition a directory directly under deployments 
                    directory, as opposed to grouping additions into 
                    subdirectories by type.
                    For all other routines this is a no-opt.
    -r, --root      In adding routine:
                    Replace entire deployments directory itself with deployment 
                    directory being added. Standalone deployments are copied to 
                    root of deployments directory without erasing it.
                    For all other routines this is a no-opt.
    -l, --link      In adding routine:
                    Prefer to symlink local deployment files and directories, 
                    and do not try to clone or download repositories.
                    For adding remote deployments this is a no-opt.
                    For all other routines this is a no-opt.
    -e, --except, -i, --inverse
                    Inverse task list: filter out tasks included in it
    -q, --quiet     (default) Slightly decreases amount of status messages
    -v, --verbose   Slightly increases amount of status messages
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
${bold}$( basename -- "${BASH_SOURCE[0]}" )${normal} 1.5.1
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
  # Path to assets directory
  readonly D_ASSETS_DIR="$D_DIR/assets"

  # Path to backups directory
  readonly D_BACKUPS_DIR="$D_DIR/backups"

  # Path to lib directory
  readonly D_LIB_DIR="$D_DIR/lib"

  # Path to directory containing Bash utility scripts
  readonly D_UTILS_DIR="$D_LIB_DIR"

  # Filepath suffix for utility files
  readonly D_UTILS_SUFFIX='*.utl.sh'

  # Path to directory containing Bash helper functions for deployments
  readonly D_HELPERS_DIR="$D_LIB_DIR"

  # Filepath suffix for helper files
  readonly D_HELPERS_SUFFIX='*.dpl-hlp.sh'

  # Path to Divinefile
  readonly D_DIVINEFILE_NAME='Divinefile'
  
  # Path to deployments directory
  readonly D_DEPLOYMENTS_DIR="$D_DIR/dpl"

  # Filepath suffix for *.dpl.sh files
  readonly D_DPL_SH_SUFFIX='*.dpl.sh'

  # Prefix for backup files created by deployments
  readonly D_BACKUP_PREFIX='.dvn-backup-'

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
  )
  readonly D_PRINTC_OPTS_BASE

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
## Straight-forward helper that sources utilities this script depends on. 
#. Terminates the script on failing to source a utility (hard dependencies).
#
## Requires:
#.  $D_UTILS_DIR            - From __populate_globals
#.  $D_UTILS_SUFFIX         - From __populate_globals
#.  $D_HELPERS_DIR          - From __populate_globals
#.  $D_HELPERS_SUFFIX       - From __populate_globals
#
## Returns:
#.  0 - All utilities successfully sourced
#.  1 - (script exit) Failed to source a utility
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__import_dependencies()
{
  # Storage variable
  local script_path

  # Iterate over utility files
  while IFS= read -r -d $'\0' script_path; do
    [ -r "$script_path" -a -f "$script_path" ] || continue
    # Attempt to source the file
    source "$script_path" || {
      printf >&2 '%s: %s: %s\n' \
        "$( basename -- "${BASH_SOURCE[0]}" )" \
        'Fatal error' \
        'Failed to source dependency at:'
      printf >&2 '  %s\n' "$script_path"
      exit 1
    }
  done < <( find "$D_UTILS_DIR" -mindepth 1 -name "$D_UTILS_SUFFIX" -print0 )

  # Iterate over helper files
  while IFS= read -r -d $'\0' script_path; do
    [ -r "$script_path" -a -f "$script_path" ] || continue
    # Attempt to source the file
    source "$script_path" || {
      printf >&2 '%s: %s: %s\n' \
        "$( basename -- "${BASH_SOURCE[0]}" )" \
        'Fatal error' \
        'Failed to source dependency at:'
      printf >&2 '  %s\n' "$script_path"
      exit 1
    }
  done < <( find "$D_HELPERS_DIR" -mindepth 1 -name "$D_HELPERS_SUFFIX" \
    -print0 )
}

#> __assemble_tasks
#
## Collects tasks to be performed from these files:
#.  * Divinefile    - Located in directories under $D_DEPLOYMENTS_DIR
#.  * *.dpl.sh      - Located in directories under $D_DEPLOYMENTS_DIR
#
## Provides into the global scope:
#.  $D_TASK_QUEUE   - Associative array with each taken priority paired with an 
#.                    empty string
#.  $D_PACKAGES     - Associative array with each priority taken by at least 
#.                    one package paired with a semicolon-separated list of 
#.                    package names
#.  $D_DEPLOYMENTS  - Associative array with each priority taken by at least 
#.                    one deployment paired with a semicolon-separated list of 
#.                    absolute canonical paths to *.dpl.sh files
#.  $D_DPL_NAMES    - Array of deployment names used to detect duplications
#
## Returns:
#.  0 - Arrays assembled successfully
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__assemble_tasks()
{
  # In adding routine, just bail out
  [ "$D_ROUTINE" = add ] && return 0

  # Status variable
  local return_code=0

  # Global storage arrays
  D_TASK_QUEUE=()
  D_PACKAGES=()
  D_DEPLOYMENTS=()
  D_DPL_NAMES=()

  # Parse Divinefile
  __parse_divinefile

  # Locate *.dpl.sh files
  __locate_dpl_sh_files

  # Check if any tasks were found
  if [ ${#D_TASK_QUEUE[@]} -eq 0 ]; then
    printf '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Nothing to do' \
      'Not a single task matches given criteria'
    exit 0
  fi

  # Detect largest priority and number of digits in it
  local largest_priority
  for largest_priority in "${!D_TASK_QUEUE[@]}"; do :; done
  D_MAX_PRIORITY_LEN=${#largest_priority}
  readonly D_MAX_PRIORITY_LEN

  # dprint_ode options for package updating name announcements
  local priority_field_width=$(( D_MAX_PRIORITY_LEN + 3 + 19 ))
  local name_field_width=$(( 57 - 1 - priority_field_width ))
  D_PRINTC_OPTS_UP=( \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --width-4 "$priority_field_width" \
    --width-5 "$name_field_width" \
    --effects-5 b \
  ); readonly D_PRINTC_OPTS_UP

  # dprint_ode options for package/deployment name announcements
  priority_field_width=$(( D_MAX_PRIORITY_LEN + 3 + 10 ))
  name_field_width=$(( 57 - 1 - priority_field_width ))
  D_PRINTC_OPTS_NM=( \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --width-4 "$priority_field_width" \
    --width-5 "$name_field_width" \
    --effects-5 b \
  ); readonly D_PRINTC_OPTS_NM

  return 0
}

#> __parse_divinefile
#
## Collects packages to be installed from each instance of Divinefile under 
#. deployments directory
#
## Requires:
#.  $D_PKGS                 - From __parse_arguments
#.  $D_DEFAULT_PRIORITY     - From __populate_globals
#.  $OS_PKGMGR              - From Divine Bash utils: dOS (dos.utl.sh)
#
## Modifies in the global scope:
#.  $D_TASK_QUEUE   - Associative array with each taken priority paired with an 
#.                    empty string
#.  $D_PACKAGES     - Associative array with each priority taken by at least 
#.                    one package paired with a semicolon-separated list of 
#.                    package names
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Failed to read Divinefile
#.  2 - No package manager detected
#.  3 - List of deployments has been provided, and Divinefile is not in it
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__parse_divinefile()
{
  # Check if there is a package manager detected for this system
  [ -n "$OS_PKGMGR" ] || return 2

  ## Check if list of deployments has been provided, and whether Divinefile is 
  #. in it
  $D_PKGS || return 3

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Storage variables
  local divinefile_path
  local line chunks chunk
  local left_part priority mode list pkgmgr altlist

  # Iterate over every Divinefile in deployments dir
  while IFS= read -r -d $'\0' divinefile_path; do

    # Check if Divinefile is a readable file
    [ -r "$divinefile_path" -a -f "$divinefile_path" ] || continue
  
    # Iterate over lines in each Divinefile
    while IFS='' read -u 10 line || [ -n "$line" ]; do

      # Set empty defaults for the line
      left_part= priority= mode= list= pkgmgr= altlist=

      # Remove comments, trim whitespace
      line="$( dtrim -c -- "$line" )"

      # Empty line — continue
      [ -n "$line" ] || continue

      # Process priority if it is present to the left of ‘)’
      if [[ $line == *')'* ]]; then

        # Split line on first occurrence of ‘)’
        IFS=')' read -r left_part line <<<"$line"

        # Split left part on whitespace
        read -r -a chunks <<<"$left_part"
        priority="${chunks[0]}"
        mode="${chunks[1]}"

        # Remove leading zeroes from priority, if any
        priority="$( sed 's/^0*//' <<<"$priority" )"

        # Trim the rest of the line
        line="$( dtrim -- "$line" )"

      fi

      # Detect whether priority is acceptable
      [[ $priority =~ ^[0-9]+$ ]] || priority="$D_DEFAULT_PRIORITY"

      # Detect whether mode is acceptable
      [[ $mode =~ ^[airc]+$ ]] || mode=

      # Split remaining line by vertical bars
      IFS='|' read -r -a chunks <<<"$line"
      # First chunk is the default list
      list="${chunks[0]}"; chunks=("${chunks[@]:1}")

      # Iterate over remaining chunks of the line
      for chunk in "${chunks[@]}"; do

        # Ignore alt-lists without ‘:’
        [[ $line == *':'* ]] || continue

        # Split chunk on ‘:’
        IFS=':' read -r pkgmgr altlist <<<"$chunk"

        # Trim package manager list
        pkgmgr="$( dtrim -- "$pkgmgr" )"

        # Ignore empty package manager names
        [ -n "$pkgmgr" ] || continue

        # If it matches $OS_PKGMGR (case insensitively), use the alt list
        if [[ $OS_PKGMGR == $pkgmgr ]]; then
          list="$( dtrim -- "$altlist" )"
          break  # First match wins
        fi

      # Done iterating over remaining chunks of the line
      done

      # Split list by whitespace (in case there are many packages on one line)
      read -r -a chunks <<<"$list"
      # Iterate over package names
      for chunk in "${chunks[@]}"; do

        # Empty name — continue
        [ -n "$chunk" ] || continue

        # Add current priority to task queue
        D_TASK_QUEUE["$priority"]='taken'

        # If some mode is enabled, prefix it
        if [ -n "$mode" ]; then
          chunk="$mode $chunk"
        else
          # ‘---’ is a bogus mode, it will just be ignored
          chunk="--- $chunk"
        fi

        # Add current package to packages queue
        D_PACKAGES["$priority"]+="$chunk;"

      # Done iterating over package names
      done

    # Done iterating over lines in Divinefile 
    done 10<"$divinefile_path"

  # Done iterating over Divinefiles in deployments directory
  done < <( find "$D_DEPLOYMENTS_DIR" -mindepth 1 -name "$D_DIVINEFILE_NAME" \
    -print0 )

  # Restore case sensitivity
  eval "$restore_nocasematch"

  return 0
}

#> __locate_dpl_sh_files
#
## Collects deployments to be performed from *.dpl.sh files located under 
#. $D_DEPLOYMENTS_DIR
#
## Requires:
#.  $D_DEPLOYMENTS_DIR      - From __populate_globals
#.  $D_DPL_SH_SUFFIX        - From __populate_globals
#.  $D_DPL_NAME_REGEX       - From __populate_globals
#.  $D_DPL_PRIORITY_REGEX   - From __populate_globals
#.  $D_DEFAULT_PRIORITY     - From __populate_globals
#
## Modifies in the global scope:
#.  $D_TASK_QUEUE   - Associative array with each taken priority paired with an 
#.                    empty string
#.  $D_DEPLOYMENTS  - Associative array with each priority taken by at least 
#.                    one deployment paired with a semicolon-separated list of 
#.                    absolute canonical paths to *.dpl.sh files
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Failed to access $D_DEPLOYMENTS_DIR
#.  1 - (script exit) Either of the following is detected:
#.        * Deployment called ‘Divinefile’
#.        * Re-used deployment name
#.        * Deployment file with ‘;’ in its path
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__locate_dpl_sh_files()
{
  # Check if deployments directory exists
  [ -d "$D_DEPLOYMENTS_DIR" ] || return 1

  # Store current case sensitivity setting, then turn it off when needed
  local restore_nocasematch="$( shopt -p nocasematch )"

  # Iterate over directories descending from deployments dirpath
  local dirpath divinedpl_filepath name flags priority taken_name
  local restore_nocasematch
  local adding arg
  while IFS= read -r -d $'\0' divinedpl_filepath; do

    # Ensure *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Extract directory containing *.dpl.sh file
    dirpath="$( dirname -- "$divinedpl_filepath" )"

    # If file path contains ‘;’, skip (‘;’ is a reserved delimiter)
    [[ $divinedpl_filepath == *';'* ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment file with ';' in its path found at:" \
        "$divinedpl_filepath" \
        'Semicolon in path is disallowed'
      exit 1
    }

    # Set empty defaults for the file
    name= priority=

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D_DPL_NAME_REGEX/\1/p" \
      <"$divinedpl_filepath" )

    # Process name if it is present
    # Trim name, removing quotes if any
    name="$( dtrim -Q -- "$name" )"
    # Truncate name to 64 chars
    name="$( dtrim -- "${name::64}" )"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D_DPL_SH_SUFFIX}
    }

    # Turn off case sensitivity for upcoming tests
    shopt -s nocasematch

    # Check if name is ‘Divinefile’
    [[ $name =~ ^(Divinefile|dfile|df)$ ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment named '$name' found at:" \
        "$divinedpl_filepath" \
        "Name '$name' is reserved"
      exit 1
    }

    # Check if name coincides with potential group name
    [[ $name =~ ^([0-9]|!)$ ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment named '$name' found at:" \
        "$divinedpl_filepath" \
        "Name '$name' is reserved"
      exit 1
    }

    # Check if already encountered this deployment name
    for taken_name in "${D_DPL_NAMES[@]}"; do
      [[ $taken_name == $name ]] && {
        printf >&2 '%s\n%s\n  %s\n\n%s\n' \
          "Multiple deployments named '$name'" \
          'Most recent found at:' \
          "$divinedpl_filepath" \
          "Re-used deployment names are disallowed"
        exit 1
      }
    done

    # Add this deployment name to list of taken deployment names
    D_DPL_NAMES+=("$name")

    # Restore case sensitivity
    eval "$restore_nocasematch"

    # Plan to add this *.dpl.sh
    adding=true

    # If filtering, filter
    if $D_FILTERING; then

      # Extract flags assignment from *.dpl.sh file (first one wins)
      read -r flags < <( sed -n "s/$D_DPL_FLAGS_REGEX/\1/p" \
        <"$divinedpl_filepath" )
      # Process flags
      # Trim flags, removing quotes if any
      flags="$( dtrim -Q -- "$flags" )"

      # Check for filtering mode
      if $D_INVERSE_FILTER; then

        # Inverse filtering: Whatever is listed in arguments is filtered out

        # Turn off case sensitivity
        shopt -s nocasematch

        # Iterate over arguments
        for arg in "${D_ARGS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment is specifically rejected, remove it
          [[ $arg == $name ]] && { adding=false; break; }
        done

        # Also, iterate over groups
        for arg in "${D_GROUPS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment belongs to rejected group, remove it
          [[ $flags == *${arg}* ]] && { adding=false; break; }
        done

        # Restore case sensitivity
        eval "$restore_nocasematch"

      else

        # Direct filtering: Only what is listed in arguments is added

        # By default, don’t add this *.dpl.sh
        adding=false

        # Turn off case sensitivity
        shopt -s nocasematch

        # Iterate over arguments
        for arg in "${D_ARGS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment is specifically requested, add it
          [[ $arg == $name ]] && { adding=true; break; }
        done

        # Also, iterate over groups
        for arg in "${D_GROUPS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment belongs to requested group, add it
          [[ $flags == *${arg}* ]] && { adding=true; break; }
        done

        # Restore case sensitivity
        eval "$restore_nocasematch"

      fi

    fi

    # Shall we go on?
    $adding || continue

    # Extract priority assignment from *.dpl.sh file (first one wins)
    read -r priority < <( sed -n "s/$D_DPL_PRIORITY_REGEX/\1/p" \
      <"$divinedpl_filepath" )

    # Process priority if it is present
    # Trim priority
    priority="$( dtrim -Q -- "$priority" )"
    # Remove leading zeroes if any
    priority="$( sed 's/^0*//' <<<"$priority" )"
    # Detect whether priority is acceptable
    [[ $priority =~ ^[0-9]+$ ]] || priority="$D_DEFAULT_PRIORITY"

    # Add current priority to task queue
    D_TASK_QUEUE["$priority"]='taken'

    # Add current package to packages queue
    D_DEPLOYMENTS["$priority"]+="$divinedpl_filepath;"

  done < <( find "$D_DEPLOYMENTS_DIR" -mindepth 1 -name "$D_DPL_SH_SUFFIX" \
    -print0 )

  return 0
}

#> __perform_routine
#
## Sub-driver function
#
__perform_routine()
{
  if [ "$D_ROUTINE" = install ]; then
    __perform_install
  elif [ "$D_ROUTINE" = remove ]; then
    __perform_remove
  elif [ "$D_ROUTINE" = refresh ]; then
    __perform_remove && printf '\n'
    __perform_install
  elif [ "$D_ROUTINE" = check ]; then
    __perform_check
  elif [ "$D_ROUTINE" = add ]; then
    __perform_add
  fi
}

#> __perform_install
#
## Performs installation routine
#
# For each priority level, from smallest to largest, separately:
#.  * Installs packages in order they appear in Divinefile
#.  * Installs deployments in no particular order
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__perform_install()
{
  # Announce beginning
  if [ "$D_BLANKET_ANSWER" = n ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Previewing Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Applying Divine intervention'
  fi

  # Update packages if touching them at all
  __update_pkgs

  # Storage variable
  local priority

  # Iterate over taken priorities
  for priority in "${!D_TASK_QUEUE[@]}"; do

    # Install packages if asked to
    __install_pkgs "$priority"

    # Install deployments if asked to
    __install_dpls "$priority"

    # Check if __install_dpls returned special status
    case $? in
      100)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          ')))' 'Reboot required' ':' \
          'Last deployment asked for machine reboot'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      101)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          'ooo' 'Attention' ':' \
          'Last deployment asked for user’s attention'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      666)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          'x_x' 'Critical failure' ':' \
          'Last deployment reported catastrophic error'
        printf '\n'
        dprint_plaque -pcw "$RED" "$D_PLAQUE_WIDTH" \
          -- 'Aborting Divine intervention'
        return 1;;
      *)  :;;
    esac
    
  done

  # Announce completion
  printf '\n'
  if [ "$D_BLANKET_ANSWER" = n ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Successfully previewed Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Successfully applied Divine intervention'
  fi
  return 0
}

#> __update_pkgs
#
## Shared subroutine that runs update process on detected $OS_PKGMGR
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Always
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__update_pkgs()
{
  # Only if packages are to be touched at all
  if $D_PKGS; then

    # Name current task
    local task_desc='Update packages via'
    local task_name="'${OS_PKGMGR}'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" 0 "$task_desc" )"

    # Local flag for whether to proceed
    local proceeding=true

    # Don’t proceed if missing package manager
    [ -z "$OS_PKGMGR" ] && {
      task_name="$task_name (package manager not found)"
      proceeding=false
    }

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Print message about the upcoming installation
    if $proceeding; then
      dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"
    fi

    # Unless given a ‘-y’ option, prompt for user’s approval
    if $proceeding && [ "$D_BLANKET_ANSWER" != y ]; then
      dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }
    fi

    # Update packages
    if $proceeding; then
      os_pkgmgr dupdate
      if [ $? -eq 0 ]; then
        dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$GREEN" -- \
          'vvv' 'Installed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$RED" -- \
          'xxx' 'Failed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_UP[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  fi

  return 0
}

#> __install_pkgs PRIORITY_LEVEL
#
## For the given priority level, installs packages, one by one, using their 
#. names, which have been previously assembled in $D_PACKAGES array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Packages installed
#.  1 - No attempt to install has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__install_pkgs()
{
  # Check whether packages are asked for
  $D_PKGS || return 1

  # Check whether package manager has been detected
  [ -n "$OS_PKGMGR" ] || return 1

  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks pkgname mode aa_mode

  # Split package names on ‘;’
  IFS=';' read -r -a chunks <<<"${D_PACKAGES[$priority]%;}"

  # Iterate over package names
  for pkgname in "${chunks[@]}"; do

    # Empty name — continue
    [ -n "$pkgname" ] || continue

    # Extract mode if it is present
    read -r mode pkgname <<<"$pkgname"
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *i* ]] && aa_mode=true

    # Name current task
    task_desc='Package'
    task_name="'$pkgname'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Don’t proceed if already installed (except when forcing)
    if $proceeding; then
      os_pkgmgr dcheck "$pkgname" && ! $D_FORCE && {
        task_name="$task_name (already installed)"
        proceeding=false
      }
    fi

    # Print newline to visually separate tasks
    printf '\n'

    # Print introduction and prompt user as necessary
    if $proceeding; then

      # Print message about the upcoming installation
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"

      ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
      #. user’s approval
      if [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != y ]; then

        # Prompt slightly differs depending on whether ‘always ask’ is enabled
        if $aa_mode; then
          dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
        else
          dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
        fi

        # Prompt user
        dprompt_key --bare && proceeding=true || {
          task_name="$task_name (declined by user)"
          proceeding=false
        }
      
      fi

    fi

    # Install package
    if $proceeding; then
      os_pkgmgr dinstall "$pkgname"
      if [ $? -eq 0 ]; then
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
          'vvv' 'Installed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
          'xxx' 'Failed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done

  return 0
}

#> __install_dpls PRIORITY_LEVEL
#
## For the given priority level, installs deployments, one by one, using their 
#. *.dpl.sh files, paths to which have been previously assembled in 
#. $D_DEPLOYMENTS array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Deployments installed
#.  1 - No attempt to install has been made
#.  100 - Reboot needed
#.  101 - User attention needed
#.  666 - Critical failure
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__install_dpls()
{
  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks divinedpl_filepath
  local name desc warning mode
  local aa_mode dpl_status
  local intro_printed

  # Split *.dpl.sh filepaths on ‘;’
  IFS=';' read -r -a chunks <<<"${D_DEPLOYMENTS[$priority]%;}"

  # Iterate over *.dpl.sh filepaths
  for divinedpl_filepath in "${chunks[@]}"; do

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f dcheck
    unset -f dinstall
    unset -f dremove
    # Expose $D_DPL_DIR variable to deployment
    D_DPL_DIR="$( dirname -- "$divinedpl_filepath" )"

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D_DPL_NAME_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process name
    # Trim name, removing quotes if any
    name="$( dtrim -Q -- "$name" )"
    # Truncate name to 64 chars
    name="$( dtrim -- "${name::64}" )"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D_DPL_SH_SUFFIX}
    }

    # Extract description assignment from *.dpl.sh file (first one wins)
    read -r desc < <( sed -n "s/$D_DPL_DESC_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process description
    # Trim description, removing quotes if any
    desc="$( dtrim -Q -- "$desc" )"

    # Extract warning assignment from *.dpl.sh file (first one wins)
    read -r warning < <( sed -n "s/$D_DPL_WARNING_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process warning
    # Trim warning, removing quotes if any
    warning="$( dtrim -Q -- "$warning" )"

    # Extract mode assignment from *.dpl.sh file (first one wins)
    read -r mode < <( sed -n "s/$D_DPL_FLAGS_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process mode
    # Trim mode, removing quotes if any
    mode="$( dtrim -Q -- "$mode" )"

    # Process $D_FLAGS
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *i* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Local flag for whether descriptive introduction has been printed
    intro_printed=false

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
    #. user’s approval
    if $proceeding && [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != y ]; then

      # Print message about the upcoming installation
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name" \
        && intro_printed=true
      # In verbose mode, print location of script to be sourced
      debug_print "Location: $divinedpl_filepath"
      # If description is available, show it
      [ -n "$desc" ] && dprint_ode "${D_PRINTC_OPTS_DSC[@]}" -- \
        '' 'Description' ':' "$desc"
      # If warning is relevant, show it
      [ -n "$warning" -a "$aa_mode" = true ] \
        && dprint_ode "${D_PRINTC_OPTS_WRN[@]}" -c "$RED" -- \
          '' 'Warning' ':' "$warning"

      # Prompt slightly differs depending on whether ‘always ask’ is enabled
      if $aa_mode; then
        dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
      else
        dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
      fi

      # Prompt user
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # Source the *.dpl.sh file
    if $proceeding; then
      # Print informative message for potential debugging of errors
      debug_print "Sourcing: $divinedpl_filepath"
      # Hold your breath…
      source "$divinedpl_filepath"
    fi

    # Try to figure out, if deployment is already installed
    if $proceeding; then

      # Get return code of dcheck, or fall back to zero
      if declare -f dcheck &>/dev/null; then
        dcheck; dpl_status=$?
      else
        dpl_status=0
      fi

      # Don’t proceed if already installed (except when forcing)
      case $dpl_status in
        1)  $D_FORCE || {
              task_name="$task_name (already installed)"
              proceeding=false
            }
            ;;
        3)  task_name="$task_name (irrelevant)"
            proceeding=false
            # continue
            ;;
        *)  :;;
      esac

    fi

    # Install deployment
    if $proceeding; then

      # Print descriptive introduction, if haven’t already
      $intro_printed || dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"

      # Get return code of dinstall, or fall back to zero
      if declare -f dinstall &>/dev/null; then
        dinstall; dpl_status=$?
      else
        dpl_status=0
      fi

      # Analyze exit code
      case $dpl_status in
        0|100|101)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
            'vvv' 'Installed' ':' "$task_desc" "$task_name";;
        2)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
            '---' 'Skipped' ':' "$task_desc" "$task_name";;
        1|666|*)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
            'xxx' 'Failed' ':' "$task_desc" "$task_name";;
      esac

      # Catch special exit codes
      [ $dpl_status -ge 100 ] && return $dpl_status
      
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

#> __perform_remove
#
## Performs removal routine, in reverse installation order
#
# For each priority level, from largest to smallest, separately:
#.  * Removes deployments in reverse installation order
#.  * Removes packages in reverse order they appear in Divinefile
#
## Returns:
#.  0 - Routine performed
#
__perform_remove()
{
  # Announce beginning
  if [ "$BLANKET_ANSWER" = n ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- '‘Undoing’ Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Undoing Divine intervention'
  fi

  # Update packages if touching them at all
  # (This is normally required even for removal)
  __update_pkgs

  # Storage variables
  local priority reversed_queue

  # Reverse the priorities
  reversed_queue=( $( IFS=$'\n' sort -nr <<<"${!D_TASK_QUEUE[*]}" ) )

  # Iterate over taken priorities
  for priority in "${reversed_queue[@]}"; do

    # Remove deployments if asked to
    __remove_dpls "$priority"

    # Check if __remove_dpls returned special status
    case $? in
      100)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          ')))' 'Reboot required' ':' \
          'Last deployment asked for machine reboot'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      101)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          'ooo' 'Attention' ':' \
          'Last deployment asked for user’s attention'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      666)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          'x_x' 'Critical failure' ':' \
          'Last deployment reported catastrophic error'
        printf '\n'
        dprint_plaque -pcw "$RED" "$D_PLAQUE_WIDTH" \
          -- 'Aborting Divine intervention'
        return 1;;
      *)  :;;
    esac    

    # Remove packages if asked to
    __remove_pkgs "$priority"

  done

  # Announce completion
  printf '\n'
  if [ "$BLANKET_ANSWER" = n ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Successfully ‘undid’ Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Successfully undid Divine intervention'
  fi
  return 0
}

#> __remove_pkgs PRIORITY_LEVEL
#
## For the given priority level, removes packages, one by one, using their 
#. names, which have been previously assembled in $D_PACKAGES array. Operates 
#. in reverse order.
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Packages removed
#.  1 - No attempt to remove has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__remove_pkgs()
{
  # Check whether packages are asked for
  $D_PKGS || return 1

  # Check whether package manager has been detected
  [ -n "$OS_PKGMGR" ] || return 1

  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks i pkgname mode aa_mode

  # Split package names on ‘;’
  IFS=';' read -r -a chunks <<<"${D_PACKAGES[$priority]%;}"

  # Iterate over package names in reverse order
  for (( i=${#chunks[@]}-1; i>=0; i-- )); do

    # Get package name
    pkgname="${chunks[$i]}"

    # Empty name — continue
    [ -n "$pkgname" ] || continue

    # Extract mode if it is present
    read -r mode pkgname <<<"$pkgname"
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *r* ]] && aa_mode=true

    # Name current task
    task_desc='Package'
    task_name="'$pkgname'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Don’t proceed if already removed (except when forcing)
    if $proceeding; then
      ! os_pkgmgr dcheck "$pkgname" && ! $D_FORCE && {
        task_name="$task_name (already removed)"
        proceeding=false
      }
    fi

    # Print newline to visually separate tasks
    printf '\n'

    # Print introduction and prompt user as necessary
    if $proceeding; then

      # Print message about the upcoming removal
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Removing' ':' "$task_desc" "$task_name"

      ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
      #. user’s approval
      if [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != y ]; then


        # Prompt slightly differs depending on whether ‘always ask’ is enabled
        if $aa_mode; then
          dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
        else
          dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
        fi

        # Prompt user
        dprompt_key --bare && proceeding=true || {
          task_name="$task_name (declined by user)"
          proceeding=false
        }

      fi

    fi

    # Remove package
    if $proceeding; then
      os_pkgmgr dremove "$pkgname"
      if [ $? -eq 0 ]; then
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
          'vvv' 'Removed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
          'xxx' 'Failed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done

  return 0
}

#> __remove_dpls PRIORITY_LEVEL
#
## For the given priority level, removes deployments, one by one, using their 
#. *.dpl.sh files, paths to which have been previously assembled in 
#. $D_DEPLOYMENTS array. Operates in reverse order.
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Deployments removed
#.  1 - No attempt to remove has been made
#.  100 - Reboot needed
#.  101 - User attention needed
#.  666 - Critical failure
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__remove_dpls()
{
  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks i divinedpl_filepath
  local name desc warning mode
  local aa_mode dpl_status
  local intro_printed

  # Split *.dpl.sh filepaths on ‘;’
  IFS=';' read -r -a chunks <<<"${D_DEPLOYMENTS[$priority]%;}"

  # Iterate over *.dpl.sh filepaths
  for (( i=${#chunks[@]}-1; i>=0; i-- )); do

    # Extract *.dpl.sh filepath
    divinedpl_filepath="${chunks[$i]}"

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f dcheck
    unset -f dinstall
    unset -f dremove
    # Expose $D_DPL_DIR variable to deployment
    D_DPL_DIR="$( dirname -- "$divinedpl_filepath" )"

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D_DPL_NAME_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process name
    # Trim name, removing quotes if any
    name="$( dtrim -Q -- "$name" )"
    # Truncate name to 64 chars
    name="$( dtrim -- "${name::64}" )"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D_DPL_SH_SUFFIX}
    }

    # Extract description assignment from *.dpl.sh file (first one wins)
    read -r desc < <( sed -n "s/$D_DPL_DESC_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process description
    # Trim description, removing quotes if any
    desc="$( dtrim -Q -- "$desc" )"

    # Extract warning assignment from *.dpl.sh file (first one wins)
    read -r warning < <( sed -n "s/$D_DPL_WARNING_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process warning
    # Trim warning, removing quotes if any
    warning="$( dtrim -Q -- "$warning" )"

    # Extract mode assignment from *.dpl.sh file (first one wins)
    read -r mode < <( sed -n "s/$D_DPL_FLAGS_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process mode
    # Trim mode, removing quotes if any
    mode="$( dtrim -Q -- "$mode" )"

    # Process $D_FLAGS
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *r* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Flag about whether descriptive introduction has been printed
    intro_printed=false

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
    #. user’s approval
    if $proceeding && [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != y ]; then

      # Print message about the upcoming removal
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Removing' ':' "$task_desc" "$task_name" \
        && intro_printed=true
      # In verbose mode, print location of script to be sourced
      debug_print "Location: $divinedpl_filepath"
      # If description is available, show it
      [ -n "$desc" ] && dprint_ode "${D_PRINTC_OPTS_DSC[@]}" -- \
        '' 'Description' ':' "$desc"
      # If warning is relevant, show it
      [ -n "$warning" -a "$aa_mode" = true ] \
        && dprint_ode "${D_PRINTC_OPTS_WRN[@]}" -c "$RED" -- \
          '' 'Warning' ':' "$warning"

      # Prompt slightly differs depending on whether ‘always ask’ is enabled
      if $aa_mode; then
        dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
      else
        dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
      fi

      # Prompt user
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # Source the *.dpl.sh file
    if $proceeding; then
      # Print informative message for potential debugging of errors
      debug_print "Sourcing: $divinedpl_filepath"
      # Hold your breath…
      source "$divinedpl_filepath"
    fi

    # Try to figure out, if deployment is already removed
    if $proceeding; then

      # Get return code of dcheck, or fall back to zero
      if declare -f dcheck &>/dev/null; then
        dcheck; dpl_status=$?
      else
        dpl_status=0
      fi

      # Don’t proceed if already removed (except when forcing)
      case $dpl_status in
        2)  $D_FORCE || {
              task_name="$task_name (already removed)"
              proceeding=false
            }
            ;;
        3)  task_name="$task_name (irrelevant)"
            proceeding=false
            # continue
            ;;
        *)  :;;
      esac

    fi

    # Remove deployment
    if $proceeding; then

      # Print descriptive introduction if haven’t already
      $intro_printed || dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
          '>>>' 'Removing' ':' "$task_desc" "$task_name"

      # Get return code of dremove, or fall back to zero
      if declare -f dremove &>/dev/null; then
        dremove; dpl_status=$?
      else
        dpl_status=0
      fi

      # Analyze exit code
      case $dpl_status in
        0|100|101)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
            'vvv' 'Removed' ':' "$task_desc" "$task_name";;
        2)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
            '---' 'Skipped' ':' "$task_desc" "$task_name";;
        1|666|*)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
            'xxx' 'Failed' ':' "$task_desc" "$task_name";;
      esac

      # Catch special exit codes
      [ $dpl_status -ge 100 ] && return $dpl_status

    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

#> __perform_check
#
## Performs checking routine
#
# For each priority level, from smallest to largest, separately:
#.  * Checks whether packages are installed, in order they appear in Divinefile
#.  * Checks whether deployments are installed, in no particular order
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__perform_check()
{
  # Announce beginning
  if [ "$D_BLANKET_ANSWER" = n ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- '‘Checking’ Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Checking Divine intervention'
  fi

  # Storage variable
  local priority

  # Iterate over taken priorities
  for priority in "${!D_TASK_QUEUE[@]}"; do

    # Install packages if asked to
    __check_pkgs "$priority"

    # Install deployments if asked to
    __check_dpls "$priority"
    
  done

  # Announce completion
  printf '\n'
  if [ "$D_BLANKET_ANSWER" = n ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Successfully ‘checked’ Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Successfully checked Divine intervention'
  fi
  return 0
}

#> __check_pkgs PRIORITY_LEVEL
#
## For the given priority level, check if packages are installed, one by one, 
#. using their names, which have been previously assembled in $D_PACKAGES array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Packages checked
#.  1 - No attempt to check has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__check_pkgs()
{
  # Check whether packages are asked for
  $D_PKGS || return 1

  # Check whether package manager has been detected
  [ -n "$OS_PKGMGR" ] || return 1

  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks pkgname mode

  # Split package names on ‘;’
  IFS=';' read -r -a chunks <<<"${D_PACKAGES[$priority]%;}"

  # Iterate over package names
  for pkgname in "${chunks[@]}"; do

    # Empty name — continue
    [ -n "$pkgname" ] || continue

    # Extract mode if it is present
    read -r mode pkgname <<<"$pkgname"
    # Mode is ignored when checking packages (unlike deployments)

    # Name current task
    task_desc='Package'
    task_name="'$pkgname'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Perform check
    if $proceeding; then
      if os_pkgmgr dcheck "$pkgname"; then
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
          'vvv' 'Installed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
          'xxx' 'Not installed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done

  return 0
}

#> __check_dpls PRIORITY_LEVEL
#
## For the given priority level, checks whether deployments are installed, one 
#. by one, using their *.dpl.sh files, paths to which have been previously 
#. assembled in $D_DEPLOYMENTS array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Deployments checked
#.  1 - No attempt to check has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__check_dpls()
{
  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks divinedpl_filepath
  local name desc warning mode
  local aa_mode dpl_status

  # Split *.dpl.sh filepaths on ‘;’
  IFS=';' read -r -a chunks <<<"${D_DEPLOYMENTS[$priority]%;}"

  # Iterate over *.dpl.sh filepaths
  for divinedpl_filepath in "${chunks[@]}"; do

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f dcheck
    unset -f dinstall
    unset -f dremove
    # Expose $D_DPL_DIR variable to deployment
    D_DPL_DIR="$( dirname -- "$divinedpl_filepath" )"

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D_DPL_NAME_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process name
    # Trim name, removing quotes if any
    name="$( dtrim -Q -- "$name" )"
    # Truncate name to 64 chars
    name="$( dtrim -- "${name::64}" )"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D_DPL_SH_SUFFIX}
    }

    # Extract description assignment from *.dpl.sh file (first one wins)
    read -r desc < <( sed -n "s/$D_DPL_DESC_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process description
    # Trim description, removing quotes if any
    desc="$( dtrim -Q -- "$desc" )"

    # Extract warning assignment from *.dpl.sh file (first one wins)
    read -r warning < <( sed -n "s/$D_DPL_WARNING_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process warning
    # Trim warning, removing quotes if any
    warning="$( dtrim -Q -- "$warning" )"

    # Extract mode assignment from *.dpl.sh file (first one wins)
    read -r mode < <( sed -n "s/$D_DPL_FLAGS_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process mode
    # Trim mode, removing quotes if any
    mode="$( dtrim -Q -- "$mode" )"

    # Process $D_FLAGS
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *c* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = n ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
    #. user’s approval
    if $proceeding && [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != y ]; then

      # Print message about the upcoming checking
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Checking' ':' "$task_desc" "$task_name" \
        && intro_printed=true
      # In verbose mode, print location of script to be sourced
      debug_print "Location: $divinedpl_filepath"
      # If description is available, show it
      [ -n "$desc" ] && dprint_ode "${D_PRINTC_OPTS_DSC[@]}" -- \
        '' 'Description' ':' "$desc"
      # If warning is relevant, show it
      [ -n "$warning" -a "$aa_mode" = true ] \
        && dprint_ode "${D_PRINTC_OPTS_WRN[@]}" -c "$RED" -- \
          '' 'Warning' ':' "$warning"

      # Prompt slightly differs depending on whether ‘always ask’ is enabled
      if $aa_mode; then
        dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
      else
        dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
      fi

      # Prompt user
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # Source the *.dpl.sh file
    if $proceeding; then
      # Print informative message for potential debugging of errors
      debug_print "Sourcing: $divinedpl_filepath"
      # Hold your breath…
      source "$divinedpl_filepath"
    fi

    # Check if deployment is installed and report
    if $proceeding; then

      # Get return code of dcheck, or fall back to zero
      if declare -f dcheck &>/dev/null; then
        dcheck; dpl_status=$?
      else
        dpl_status=0
      fi

      # Process return code
      case $dpl_status in
        1)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
            'vvv' 'Installed' ':' "$task_desc" "$task_name"
          ;;
        2)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
            'xxx' 'Not installed' ':' "$task_desc" "$task_name"
          ;;
        3)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$MAGENTA" -- \
            '~~~' 'Irrelevant' ':' "$task_desc" "$task_name"
          ;;
        *)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$BLUE" -- \
            '???' 'Unknown' ':' "$task_desc" "$task_name"
          ;;
      esac

    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

#> __perform_add
#
## Performs addition routine
#
## For each argument, look it up as a git repository and, if found, make a 
#. shallow copy of it in deployments directory
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__perform_add()
{
  # If not linking, check if git is available, offer to install it
  if ! $D_ADD_LINK; then __adding__check_for_git; fi

  # Storage variable
  local dpl_arg

  # Status variables
  local arg_success
  local added_anything=false errors_encountered=false

  # Iterate over script arguments
  for dpl_arg in "${D_ARGS[@]}"; do

    # Set default status
    arg_success=true

    # Announce start
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Processing '$dpl_arg'"

    # Process each argument sequentially until the first hit
    if $D_ADD_LINK; then
      __adding__attempt_local_dir "$dpl_arg" \
        || __adding__attempt_local_file "$dpl_arg" \
        || arg_success=false
    else
      __adding__attempt_github_repo "$dpl_arg" \
        || __adding__attempt_local_repo "$dpl_arg" \
        || __adding__attempt_local_dir "$dpl_arg" \
        || __adding__attempt_local_file "$dpl_arg" \
        || arg_success=false
    fi
    
    # Report and set status
    if $arg_success; then
      printf >&2 '\n%s %s\n' \
        "${BOLD}${GREEN}==>${NORMAL}" \
        "Successfully added '$dpl_arg'"
      added_anything=true
    else
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Did not add '$dpl_arg'"
      errors_encountered=true
    fi

  done

  # Announce routine completion
  if $added_anything; then
    if $errors_encountered; then
      printf >&2 '\n%s %s\n' \
        "${BOLD}${YELLOW}==>${NORMAL}" \
        'Successfully added some deployments'
    else
      printf >&2 '\n%s %s\n' \
        "${BOLD}${GREEN}==>${NORMAL}" \
        'Successfully added all deployments'
    fi
  else
    if $errors_encountered; then
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Did not add any deployments'
    else
      printf >&2 '\n%s %s\n' \
        "${BOLD}${WHITE}==>${NORMAL}" \
        'Nothing to do'
    fi
  fi
}

#>  __adding__attempt_github_repo
#
## Attempts to interpret single argument as name of Github repository and pull 
#. it in. Accepts either full ‘user/repo’ form or short ‘built_in_repo’ form 
#. for deployments distributed by author of Divine.dotfiles.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
__adding__attempt_github_repo()
{
  # Extract argument
  local repo_arg="$1"

  # Storage variables
  local user_repo is_builtin=false temp_ready=false

  # Accept one of two patterns: ‘builtin_repo_name’ and ‘username/repo’
  if [[ $repo_arg =~ ^[0-9A-Za-z_.-]+$ ]]; then
    is_builtin=true
    user_repo="no-simpler/divine-dpl-$repo_arg"
  elif [[ $repo_arg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then
    user_repo="$repo_arg"
  else
    # Other patterns are not checked against Github
    return 1
  fi

  # Announce start
  printf >&2 '  %s\n' 'interpreting as Github repository'

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest
  case $D_ADD_MODE in
    normal)
      if $is_builtin; then
        perm_dest="$D_DEPLOYMENTS_DIR/repos/divine/$repo_arg"
      else
        perm_dest="$D_DEPLOYMENTS_DIR/repos/github/$repo_arg"
      fi
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/$( basename -- "$repo_arg" )";;
    root) perm_dest="$D_DEPLOYMENTS_DIR";;
    *)    return 1;;
  esac

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Prompt user about the addition
      __adding__prompt_git_repo "https://github.com/${user_repo}" || return 1

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$temp_dest" &>/dev/null \
        || {
          # Announce failure to clone
          printf >&2 '\n%s %s\n  %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Failed to clone repository at:' \
            "https://github.com/${user_repo}"
          printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
          # Try to clean up
          rm -rf -- "$temp_dest"
          # Return
          return 1
        }
      
      # Set status
      temp_ready=true

    else

      # Repo does not exist
      return 1
    
    fi

  else

    # If curl/wget are not available, don’t bother
    if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
      return 1
    fi

    # Not cloning repository, tinker with destination paths again
    if [ "$D_ADD_MODE" = normal ]; then
      if $is_builtin; then
        perm_dest="$D_DEPLOYMENTS_DIR/imported/divine/$repo_arg"
      else
        perm_dest="$D_DEPLOYMENTS_DIR/imported/github/$repo_arg"
      fi
    fi

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Prompt user about the addition
      __adding__prompt_git_repo "https://github.com/${user_repo}" || return 1

      # Check if tar is available
      __adding__check_for_tar \
        "https://api.github.com/repos/${user_repo}/tarball" || return 1

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$temp_dest" -xzf -
      
      # Check status
      [ $? -eq 0 ] || {
        # Announce failure to clone
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to download (curl) or extract tarball repository at:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Return
        return 1
      }
    
      # Set status
      temp_ready=true

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available

      # Prompt user about the addition
      __adding__prompt_git_repo "https://github.com/${user_repo}" || return 1

      # Check if tar is available
      __adding__check_for_tar \
        "https://api.github.com/repos/${user_repo}/tarball" || return 1

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$temp_dest" -xzf -
      
      # Check status
      [ $? -eq 0 ] || {
        # Announce failure to clone
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to download (wget) or extract tarball repository at:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Return
        return 1
      }
      
      # Set status
      temp_ready=true

    else

      # Either none of the tools were available, or repo does not exist
      return 1

    fi
  
  fi

  # If succeeded to get repo to temp dir, go for the kill
  if $temp_ready; then

    # Check whether directory to be added contains any deployments
    __adding__check_for_deployments "$temp_dest" \
      "https://github.com/${user_repo}" \
      || { rm -rf -- "$temp_dest"; return 1; }

    # Prompt user for possible clobbering, and clobber if required
    __adding__clobber_check "$perm_dest" || return 1

    # Finally, move cloned repository to intended location
    mv -n -- "$temp_dest" "$perm_dest" || {
      # Announce failure to move
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to move deployments from temporary location at:' "$temp_dest"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }

    # All done: announce and return
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully added Github-hosted deployments from:' \
      "https://github.com/${user_repo}"
    printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
    return 0
  
  else

    # Somehow got here without successfully pulling repo: return error
    return 1
  
  fi
}

#>  __adding__attempt_local_repo
#
## Attempts to interpret single argument as path to local git repository and 
#. pull it in. Accepts any resolvable path to directory containing git repo.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
__adding__attempt_local_repo()
{
  # Extract argument
  local repo_arg="$1"

  # Check if argument is a directory
  [ -d "$repo_arg" ] || return 1

  # Check if git is available
  git --version >&/dev/null || return 1

  # Announce start
  printf >&2 '  %s\n' 'interpreting as local repository'

  # Construct full path to directory
  local repo_path="$( cd -- "$repo_arg" && pwd -P || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to access local repository at:' "$repo_path"
    return 1
  fi

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest
  case $D_ADD_MODE in
    normal)
      perm_dest="$D_DEPLOYMENTS_DIR/repos/local/$( basename \
        -- "$repo_path" )"
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/$( basename -- "$repo_path" )";;
    root) perm_dest="$D_DEPLOYMENTS_DIR";;
    *)    return 1;;
  esac

  # First, attempt to check existense of repository using git
  if git ls-remote "$repo_path" -q &>/dev/null; then

    # Both git and local repo are available

    # Prompt user about the addition
    __adding__prompt_git_repo "$repo_path" || return 1

    # Make shallow clone of repository
    git clone --depth=1 "$repo_path" "$temp_dest" &>/dev/null \
      || {
        # Announce failure to clone
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to clone repository at:' "$repo_path"
        printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Return
        return 1
      }
    
    # Check whether directory to be added contains any deployments
    __adding__check_for_deployments "$temp_dest" "$repo_path"  \
      || { rm -rf -- "$temp_dest"; return 1; }

    # Prompt user for possible clobbering, and clobber if required
    __adding__clobber_check "$perm_dest" || return 1

    # Finally, move cloned repository to intended location
    mv -n -- "$temp_dest" "$perm_dest" || {
      # Announce failure to move
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to move deployments from temporary location at:' "$temp_dest"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }

    # All done: announce and return
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully added local git-controlled deployments from:' "$repo_path"
    printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
    return 0
    
  else

    # Either git is not available, or directory is not a git repo
    return 1

  fi
}

#>  __adding__attempt_local_dir
#
## Attempts to interpret single argument as path to local directory containing 
#. deployments and pull it in
#
## Returns:
#.  0 - Successfully pulled in deployment directory
#.  1 - Otherwise
#
__adding__attempt_local_dir()
{
  # Extract argument
  local dir_arg="$1"

  # Check if argument is a directory
  [ -d "$dir_arg" ] || return 1

  # Announce start
  printf >&2 '  %s\n' 'interpreting as local directory'

  # Construct full path to directory
  local dir_path="$( cd -- "$dir_arg" && pwd -P || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to access local direcotry at:' "$dir_path"
    return 1
  fi

  # Construct permanent destination
  local perm_dest
  case $D_ADD_MODE in
    normal)
      perm_dest="$D_DEPLOYMENTS_DIR/imported/$( basename -- "$dir_path" )"
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/$( basename -- "$dir_path" )";;
    root) perm_dest="$D_DEPLOYMENTS_DIR";;
    *)    return 1;;
  esac

  # Prompt user about the addition
  __adding__prompt_dir_or_file "$dir_path" || return 1

  # Check whether directory to be added contains any deployments
  __adding__check_for_deployments "$dir_path" "$dir_path" \
    || return 1

  # Prompt user for possible clobbering, and clobber if required
  __adding__clobber_check "$perm_dest" || return 1

  # Finally, link/copy directory to intended location
  if $D_ADD_LINK; then
    dln -- "$dir_path" "$perm_dest" || {
      # Announce failure to link
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to link deployments from local directory at:' "$dir_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  else
    cp -Rn -- "$dir_path" "$perm_dest" || {
      # Announce failure to copy
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to copy deployments from local directory at:' "$dir_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  fi

  # All done: announce and return
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully added local deployments directory at:' "$dir_path"
  printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
  return 0
}

#>  __adding__attempt_local_file
#
## Attempts to interpret single argument as path to local ‘*.dpl.sh’ file and 
#. pull it in
#
## Returns:
#.  0 - Successfully pulled in deployment file
#.  1 - Otherwise
#
__adding__attempt_local_file()
{
  # Extract argument
  local dpl_file_arg="$1"

  # Check if argument is a directory
  [ -f "$dpl_file_arg" -a -r "$dpl_file_arg" ] || return 1

  # Check if argument conforms to deployment naming
  local dpl_file_name="$( basename -- "$dpl_file_arg" )"
  [[ $dpl_file_name == $D_DPL_SH_SUFFIX \
    || $dpl_file_name == $D_DIVINEFILE_NAME ]] || return 1
  
  # Announce start
  printf >&2 '  %s\n' 'interpreting as local deployment file'

  # Construct full path to directory containing file
  local dpl_file_path="$( cd -- "$( dirname -- "$dpl_file_arg" )" && pwd -P \
    || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to access directory of local deployment file at:' \
      "$dpl_file_path"
    return 1
  fi

  # Attach filename
  dpl_file_path+="/$dpl_file_name"

  # Construct permanent destination
  local perm_dest
  case $D_ADD_MODE in
    normal)
      perm_dest="$D_DEPLOYMENTS_DIR/imported/standalone/$dpl_file_name"
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/standalone/$dpl_file_name";;
    root) perm_dest="$D_DEPLOYMENTS_DIR/$dpl_file_name";;
    *)    return 1;;
  esac

  # Prompt user about the addition
  __adding__prompt_dir_or_file "$dpl_file_path" || return 1

  # Prompt user for possible clobbering, and clobber if required
  __adding__clobber_check "$perm_dest" || return 1

  # Finally, link/copy deployment file to intended location
  if $D_ADD_LINK; then
    dln -- "$dpl_file_path" "$perm_dest" || {
      # Announce failure to link
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to link local deployment file at:' "$dpl_file_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  else
    cp -n -- "$dpl_file_path" "$perm_dest" || {
      # Announce failure to copy
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to copy local deployment file at:' "$dpl_file_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  fi

  # All done: announce and return
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully added local deployment file at:' "$dpl_file_path"
  printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
  return 0
}

#>  __adding__prompt_git_repo REPO_PATH
#
## Prompts user whether they indeed meant the git repository, path to which is 
#. passed as single argument.
#
## Returns:
#.  0 - User confirms
#.  1 - User declines
#
__adding__prompt_git_repo()
{
  # Status variable
  local yes=false

  # Depending on existence of blanket answer, devise decision
  if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
  elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
  else
  
    # User approval required

    # Extract repo address
    local repo_address="$1"

    # Prompt user if this is their choice
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Detected ${BOLD}git repository${NORMAL} at:" \
      "$repo_address"

    # Prompt user
    dprompt_key --bare --prompt 'Add it?' && yes=true || yes=false

  fi

  # Check response
  $yes && return 0 || return 1
}

#>  __adding__prompt_dir_or_file PATH
#
## Prompts user whether they indeed meant the local dir or file, path to which 
#. is passed as single argument.
#
## Returns:
#.  0 - User confirms
#.  1 - User declines
#
__adding__prompt_dir_or_file()
{
  # Status variable
  local yes=false

  # Depending on existence of blanket answer, devise decision
  if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
  elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
  else
  
    # User approval required

    # Extract repo address
    local local_path="$1" local_type

    # Detect type
    [ -d "$local_path" ] \
      && local_type="${BOLD}local directory${NORMAL}" \
      || local_type="${BOLD}local deployment file${NORMAL}"

    # Prompt user if this is their choice
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Detected $local_type at:" "$local_path"

    # Prompt user
    if $D_ADD_LINK; then
      dprompt_key --bare --prompt 'Link it?' && yes=true || yes=false
    else
      dprompt_key --bare --prompt 'Add it?' && yes=true || yes=false
    fi

  fi

  # Check response
  $yes && return 0 || return 1
}

#>  __adding__check_for_deployments PATH SRC_PATH
#
## Checks whether PATH contains any ‘*.dpl.sh’ files, and, if not, warns user 
#. of that.
#
## Returns:
#.  0 - PATH contains at least one deployment
#.  1 - Otherwise
#
__adding__check_for_deployments()
{
  # Extract directory path and source path
  local dir_path="$1"; shift
  local src_path="$1"; shift
  local divinedpl_filepath

  # Iterate over candidates for deployment file
  while IFS= read -r -d $'\0' divinedpl_filepath; do

    # Check if candidate is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] && {
      # Return on first hit
      return 0
    }

  done < <( find "$dir_path" -mindepth 1 -name "$D_DPL_SH_SUFFIX" -print0 )

  # No deployment files: announce and return
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${RED}==>${NORMAL}" \
    "Failed to detect any deployment files in:" "$src_path"
  return 1
}

#>  __adding__clobber_check PATH
#
## Prompts user whether they indeed want to clobber (pre-erase) path that 
#. already exists. Given positive answer, proceeds with removal, and returns 
#. non-zero on failure.
#
## Returns:
#.  0 - User confirms
#.  1 - User declines, or removal of directory failed
#
__adding__clobber_check()
{
  # Extract clobber path
  local clobber_path="$1"

  # Status variable
  local yes=false

  # Check if clobber path exists
  if [ -e "$clobber_path" ]; then

    # Detect type of existing entity
    local clobber_type
    [ -d "$clobber_path" ] && clobber_type=directory || clobber_type=file

    if [ "$D_BLANKET_ANSWER" = y -a "$clobber_path" != "$D_DEPLOYMENTS_DIR" ]
    then yes=true
    elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
    else

      # Print announcement
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${YELLOW}==>${NORMAL}" \
        "A $clobber_type already exists at:" "$clobber_path"

      # Further warnings for particular cases
      if [ -d "$clobber_path" ]; then

        printf >&2 '%s %s\n' \
          "${BOLD}${YELLOW}${INVERTED}Warning!${NORMAL}" \
          'Directories are not merged. They are erased completely.'

        # Even more warning for deployment directory
        if [ "$clobber_path" = "$D_DEPLOYMENTS_DIR" ]; then
          printf >&2 '%s\n' \
            "${BOLD}Entire deployments directory will be erased!${NORMAL}"
        fi

      fi

      # Prompt user
      dprompt_key --bare --prompt 'Pre-erase?' && yes=true || yes=false

    fi

    # Check response
    if $yes; then

      # Attempt to remove pre-existing file/dir
      rm -rf -- "$clobber_path" || {
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to erase existing $clobber_type at:" "$clobber_path"
        return 1
      }

      # Pre-erased successfully
      return 0

    else

      # Refused to remove
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Refused to erase existing $clobber_type at:" "$clobber_path"
      return 1

    fi

  else

    # Path does not exist

    # Make sure parent path exists and is a directory though
    local parent_path="$( dirname -- "$clobber_path" )"
    if [ ! -d "$parent_path" ]; then
      mkdir -p -- "$parent_path" || {
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to create destination directory at:" \
          "$parent_path"
        return 1
      }
    fi

    # All good
    return 0
  
  fi
}

#>  __adding__check_for_git
#
## Checks whether git is available and, if not, offers to install it using 
#. system’s package manager, if it is available
#
## Returns:
#.  0 - Git is available or successfully installed
#.  1 - Git is not available or failed to install
#
__adding__check_for_git()
{
  # Check if git is callable
  if git --version &>/dev/null; then

    # All good, return positive
    return 0

  else

    # Prepare message for when git is not available (to avoid repetition)
    local no_git_msg='Repository cloning will not be available'

    # No git. Print warning.
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Failed to detect ${BOLD}git${NORMAL} executable"

    # Check if $OS_PKGMGR is detected
    if [ -z ${OS_PKGMGR+isset} ]; then

      # No supported package manager

      # Print warning and return
      printf >&2 '%s\n' "$no_git_msg"
      return 1
    
    else

      # Possible to try and install git using system’s package manager

      # Prompt for answer
      local yes=false
      if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
      elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
      else

        # Print question
        printf >&2 '%s' \
          "Attempt to install it using ${BOLD}${OS_PKGMGR}${NORMAL}? [y/n] "

        # Await answer
        while true; do
          read -rsn1 input
          [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
          [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
        done
        printf '\n'

      fi

      # Check if user accepted
      if $yes; then

        # Announce installation
        printf >&2 '\n%s %s\n' \
          "${BOLD}${YELLOW}==>${NORMAL}" \
          "Installing ${BOLD}git${NORMAL} using ${BOLD}${OS_PKGMGR}${NORMAL}"

        # Proceed with automated installation
        os_pkgmgr dinstall git

        # Check exit code and print status message, then return
        if [ $? -eq 0 ]; then
          printf >&2 '\n%s %s\n' \
            "${BOLD}${GREEN}==>${NORMAL}" \
            "Successfully installed ${BOLD}git${NORMAL}"
          return 0
        else
          printf >&2 '\n%s %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            "Failed to install ${BOLD}git${NORMAL}"
          printf >&2 '%s\n' "$no_git_msg"
          return 1
        fi

      else

        # Proceeding without git
        printf >&2 '\n%s %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Proceeding without ${BOLD}git${NORMAL}"
        printf >&2 '%s\n' "$no_git_msg"
        return 1

      fi
    
    fi

  fi  
}

#>  __adding__check_for_tar
#
## Checks whether tar is available and, if not, offers to install it using 
#. system’s package manager, if it is available. Informs user that tar is 
#. required to download tarball repository, path to which is passed as first 
#. argument.
#
## Returns:
#.  0 - tar is available or successfully installed
#.  1 - tar is not available or failed to install
#
__adding__check_for_tar()
{
  # Extract url of attempted tarball from arguments
  local tarball_url="$1"

  # Check if tar is callable
  if tar --version &>/dev/null; then

    # All good, return positive
    return 0

  else

    # No tar. Print warning.
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Failed to detect ${BOLD}tar${NORMAL} executable"

    # Check if $OS_PKGMGR is detected
    if [ -z ${OS_PKGMGR+isset} ]; then

      # No supported package manager

      # Print warning and return
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Refusing to download tarball repository at:' "$tarball_url"
      printf >&2 '%s\n' \
        "because ${BOLD}tar${NORMAL} is not available"
      return 1
    
    else

      # Possible to try and install tar using system’s package manager

      # Prompt for answer
      local yes=false
      if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
      elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
      else

        # Print question
        printf >&2 '%s' \
          "Attempt to install it using ${BOLD}${OS_PKGMGR}${NORMAL}? [y/n] "

        # Await answer
        while true; do
          read -rsn1 input
          [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
          [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
        done
        printf '\n'

      fi

      # Check if user accepted
      if $yes; then

        # Announce installation
        printf >&2 '\n%s %s\n' \
          "${BOLD}${YELLOW}==>${NORMAL}" \
          "Installing ${BOLD}tar${NORMAL} using ${BOLD}${OS_PKGMGR}${NORMAL}"

        # Proceed with automated installation
        os_pkgmgr dinstall tar

        # Check exit code and print status message, then return
        if [ $? -eq 0 ]; then
          printf >&2 '\n%s %s\n' \
            "${BOLD}${GREEN}==>${NORMAL}" \
            "Successfully installed ${BOLD}tar${NORMAL}"
          return 0
        else
          printf >&2 '\n%s %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            "Failed to install ${BOLD}tar${NORMAL}"
          printf >&2 '\n%s %s\n  %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Refusing to download tarball repository at:' "$tarball_url"
          printf >&2 '%s\n' \
            "because ${BOLD}tar${NORMAL} is not available"
          return 1
        fi

      else

        # No tar: print warning and return
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Refusing to download tarball repository at:' "$tarball_url"
        printf >&2 '%s\n' \
          "because ${BOLD}tar${NORMAL} is not available"
        return 1

      fi
    
    fi

  fi  
}

# Launch driver function
__main "$@"