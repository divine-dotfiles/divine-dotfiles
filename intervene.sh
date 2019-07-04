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
  # Ensure system dependencies are present
  __check_system_dependencies

  # Process received arguments
  __parse_arguments "$@"

  # Define constant globals
  __populate_globals

  # Import required dependencies (utilities and helpers)
  __import_dependencies

  # Perform requested routine
  __perform_routine
}

#>  __check_system_dependencies
#
## Ensures current system has all expected utilities installed, or exits the 
#. script
#
## Returns:
#.  0 - All system dependencies are present and accessible
#.  1 - (script exit) Otherwise
#
__check_system_dependencies()
{
  # Status variable
  local all_good=true
  
  # Test containers
  local test_bed

  #
  # find
  #

  # Test: this command must find just root path '/'
  test_bed="$( \
    find -L / -path / -name / -mindepth 0 -maxdepth 0 \
      \( -type f -or -type d \) -print0 2>/dev/null \
      || exit $? \
    )"

  # Check if all is well
  if [ $? -ne 0 -o "$test_bed" != '/' ]; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Missing system dependency:' \
      'find'

    # Flip flag
    all_good=false

  fi

  #
  # grep
  #

  # Status variable for grep
  local grep_good=true

  # grep no. 1

  # Test: this command must match line 'Be Eg'
  test_bed="$( \
    grep ^'Be E' <<'EOF' 2>/dev/null || exit 1 \
bEe
Be Eg
be e
EOF
    )"

  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 'Be Eg' ] && grep_good=false

  # grep no. 2

  # Test: this command must match nothing (no literal matches)
  grep -Fxq 'ma*A' <<'EOF' 2>/dev/null && grep_good=false
maA
maRa
maRA
ma*a
EOF

  # Test: this command must match line 'ma*a' (case insensitive match)
  grep -Fxqi 'ma*A' <<'EOF' 2>/dev/null || grep_good=false
maA
maRa
maRA
ma*a
EOF

  # grep conclusion

  # Check if all is well
  if ! $grep_good; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Missing system dependency:' \
      'grep'

    # Flip flag
    all_good=false

  fi

  #
  # sed
  #

  # Status variable for sed
  local sed_good=true

  # sed no. 1

  # Test: this command must yield string 'may t'
  test_bed="$( \
    sed <<<'  may t  // brittle # maro' 2>/dev/null \
      -e 's/[#].*$//' \
      -e 's|//.*$||' \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' \
      || exit $?
    )"
  
  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 'may t' ] && sed_good=false

  # sed no. 1

  # Test: this command must yield string ‘battered’ without quotes around it
  if sed -r &>/dev/null; then
    test_bed="$( \
      sed -nre 's/^"(.*)"$/\1/p' 2>/dev/null <<<'"battered"' || exit $? \
      )"
  else
    test_bed="$( \
      sed -nEe 's/^"(.*)"$/\1/p' 2>/dev/null <<<'"battered"' || exit $? \
      )"
  fi

  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 'battered' ] && sed_good=false

  # sed conclusion

  # Check if all is well
  if ! $sed_good; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Missing system dependency:' \
      'sed'

    # Flip flag
    all_good=false

  fi

  #
  # awk
  #

  # Test: this command must yield string ‘halt’
  test_bed="$( \
    awk -F  '=' '{print $3}' <<<'go==halt=pry' || exit $? \
    )"

  # Check if all is well
  if [ $? -ne 0 -o "$test_bed" != 'halt' ]; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Missing system dependency:' \
      'awk'

    # Flip flag
    all_good=false

  fi

  #
  # Shocking conclusion
  #

  if $all_good; then return 0; else exit 1; fi
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
      -h|--help)          __show_help_and_exit;;
      --version)          __show_version_and_exit;;
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
                              h)  __show_help_and_exit;;
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
                                  __show_usage_and_exit;;
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
    ${script_name} ${bold}i${normal}[nstall]                [-ynqveif]… [--] [TASK]…
    ${script_name} ${bold}r${normal}[emove]                 [-ynqveif]… [--] [TASK]…
    ${script_name} ${bold}f${normal}|refresh                [-ynqveif]… [--] [TASK]…
    ${script_name} ${bold}c${normal}[heck]                  [-ynqvei]…  [--] [TASK]…

    ${script_name} ${bold}a${normal}[ttach]                 [-yn]…      [--] REPO…
    ${script_name} ${bold}d${normal}[etach]                 [-yn]…      [--] REPO…
    ${script_name} ${bold}p${normal}[lug]                   [-ynl]…     [--] REPO/DIR
    ${script_name} ${bold}u${normal}[pdate]                 [-yn]…      [--] [TASK]…

    ${script_name} --version
    ${script_name} -h|--help

DESCRIPTION
    Modular cross-platform dotfiles framework. Works wherever Bash does.
    
    Launch with '-n' option for a harmless introductory dry run.

    ${bold}'Install' routine${normal} - installs tasks

    - Collects tasks from two sources:
      - Package names from 'Divinefile'
      - '*.dpl.sh' files from 'deployments' directory
    - Sorts tasks by priority (${bold}ascending${normal} integer order)
    - Updates installed packages using system’s package manager
    - Performs tasks in order:
      - ${bold}Installs${normal} packages using system’s package manager
      - ${bold}Installs${normal} deployments using 'dinstall' function in each

    ${bold}'Remove' routine${normal} - removes tasks

    - Collects tasks from two sources:
      - Package names from 'Divinefile'
      - '*.dpl.sh' files from 'deployments' directory
    - ${bold}Reverse${normal}-sorts tasks by priority (${bold}descending${normal} integer order)
    - Updates installed packages using system’s package manager
    - Performs tasks in order:
      - ${bold}Removes${normal} deployments using 'dremove' function in each
      - ${bold}Removes${normal} packages using system’s package manager
    
    ${bold}'Refresh' routine${normal} - removes, then installs tasks

    - Performs removal routine on requested tasks
    - Performs installation routine on requested tasks

    ${bold}'Check' routine${normal} - checks status of tasks

    - Collects tasks from two sources:
      - Package names from 'Divinefile'
      - '*.dpl.sh' files from 'deployments' directory
    - Sorts tasks by priority (${bold}ascending${normal} integer order)
    - Prints whether each task is installed or not

    ${bold}'Attach' routine${normal} - imports deployments from Github

    - Accepts deployments in two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repo 'no-simpler/divine-dpls-NAME')
      - Third-party deployment package (Github repo) in the form 
        'username/repository'
    - Makes shallow clones of repositories or downloads them into internal 
      directory
    - Records source of successfull clone/download in Grail directory for 
      future replication
    - Prompts before overwriting

    ${bold}'Detach' routine${normal} - removes deployments previously imported from Github

    - Accepts deployments in any of two forms:
      - Divine Github repository with deployments in the form 'NAME' (which 
        translates to 'no-simpler/divine-dpls-NAME')
      - Github repository with deployments in the form 'username/repository'
    - If such a repository is currently present, removes it
    - Clears record of this repository in Grail directory

    ${bold}'Plug' routine${normal} - replaces Grail directory

    - Allows to quickly plug-in pre-made (and possibly version controlled) 
      version of Grail directory, containing user assets and custom deployments
    - Accepts Grail directory in any of three forms:
      - Github repository in the form 'username/repository'
      - Address of a git repository
      - Path to a directory
    - Makes shallow clones of repositories or downloads them into a built-in 
      directory
    - Prompts before overwriting

    ${bold}'Update' routine${normal} - updates framework, deployment repos, and Grail

    - Accepts following tasks:
      - 'f'/'fmwk'/'framework'    : framework itself
      - 'd'/'dpls'/'deployments'  : all attached deployments
      - 'g'/'grail'               : Grail directory
      - 'a'/'all'                 : (same as empty task list) all of the above
    - Updates each task by either pulling from repository or re-downloading and 
      overwriting files one by one (where possible)

    ${bold}Task list${normal}

    Whenever a list of tasks is provided, only those tasks are performed. Task 
    names are case insensitive. Name 'divinefile' is reserved to refer to 
    processing of Divinefiles. Other names refer to deployments or deployment 
    groups.

OPTIONS
    -y, --yes       Assume affirmative answer to every prompt. Deployments may 
                    override this option to make sure that user is prompted 
                    every time.

    -n, --no        Assume negatory answer to every prompt. In effect, skips 
                    every task.

    -f, --force     By default, framework tries NOT to:
                      * re-install something that appears already installed;
                      * remove something that appears not installed;
                      * remove something that appears installed by means other 
                        than this framework.
                    This option signals that such considerations are to be 
                    forgone. Note, however, that it is mostly up to authors of 
                    deployments to honor this option. Divine deployments 
                    (distributed separately) are designed with this option in 
                    mind.

    -l, --link      ('plug' routine only, otherwise no-opt)
                    Prefer to symlink external Grail directory and avoid 
                    cloning or downloading repositories.

    -e, --except, -i, --inverse
                    Inverse task list: filter out tasks included in it, instead 
                    of filtering them in

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
Usage: ${bold}${script_name}${normal} ${bold}i${normal}|${bold}install${normal}   [-ynqveif] [TASK]…  - Launch installation
   or: ${bold}${script_name}${normal} ${bold}r${normal}|${bold}remove${normal}    [-ynqveif] [TASK]…  - Launch removal
   or: ${bold}${script_name}${normal} ${bold}f${normal}|${bold}refresh${normal}   [-ynqveif] [TASK]…  - Launch removal, then installation
   or: ${bold}${script_name}${normal} ${bold}c${normal}|${bold}check${normal}     [-ynqvei]  [TASK]…  - Launch checking

   or: ${bold}${script_name}${normal} ${bold}a${normal}|${bold}attach${normal}    [-yn]      REPO…    - Add deployment(s) from Github repo
   or: ${bold}${script_name}${normal} ${bold}d${normal}|${bold}detach${normal}    [-yn]      REPO…    - Remove previously attached repo
   or: ${bold}${script_name}${normal} ${bold}p${normal}|${bold}plug${normal}      [-ynl]     REPO/DIR - Plug Grail from repo or dir
   or: ${bold}${script_name}${normal} ${bold}u${normal}|${bold}update${normal}    [-yn]      [TASK]…  - Update framework/deployments/Grail

   or: ${bold}${script_name}${normal} --version                       - Show script version
   or: ${bold}${script_name}${normal} -h|--help                       - Show help summary
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
${bold}$( basename -- "${BASH_SOURCE[0]}" )${normal} 1.7.0
Part of ${bold}Divine.dotfiles${normal} <https://github.com/no-simpler/divine-dotfiles>
This is free software: you are free to change and redistribute it
There is NO WARRANTY, to the extent permitted by law

Written by ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>
EOF
  # Print version message
  printf '%s\n' "$version_msg"
  exit 0
}

#> __populate_d_dir_fmwk
#
## Resolves absolute path to directory containing this script, stores it in a 
#. global read-only variable as the location of the framework. Also, populates 
#. another global variable with absolute path to directory containing framework 
#. directory, which is referred to as divine directory, and may be overridden 
#. by user.
#
## Requires:
#.  Bash >=3.2
#
## Parameters:
#.  *none*
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
#.                  
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

  # Ordered list of script’s utility and helper dependencies
  D_QUEUE_DEPENDENCIES=( \
    "util dcolors" \
    "util dprint" \
    "util dprompt" \
    "util dmd5" \
    "helper dstash" \
    "util dos" \
    "util dtrim" \
    "util dreadlink" \
    "util dmv" \
    "util dln" \
    "helper queue" \
    "helper dln" \
    "helper cp" \
    "helper multitask" \
    "helper assets" \
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
    routine)  filepath="${D_DIR_ROUTINES}/${name}${D_SUFFIX_ROUTINE}";;
    util)     filepath="${D_DIR_UTILS}/${name}${D_SUFFIX_UTIL}";;
    helper)   filepath="${D_DIR_HELPERS}/${name}${D_SUFFIX_HELPER}";;
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