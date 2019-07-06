#!/usr/bin/env bash
#:title:        Divine Bash routine: help
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.07.05
#:revremark:    Initial revision
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Shows help and exits the script
#

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
  local help
  read -r -d '' help << EOF
NAME
    ${bold}${D_EXEC_NAME}${normal} - launch Divine intervention

SYNOPSIS
    $D_EXEC_NAME ${bold}i${normal}[nstall]                [-ynqveif]… [--] [TASK]…
    $D_EXEC_NAME ${bold}r${normal}[emove]                 [-ynqveif]… [--] [TASK]…
    $D_EXEC_NAME ${bold}c${normal}[heck]                  [-ynqvei]…  [--] [TASK]…

    $D_EXEC_NAME ${bold}a${normal}[ttach]                 [-yn]…      [--] REPO…
    $D_EXEC_NAME ${bold}d${normal}[etach]                 [-yn]…      [--] REPO…
    $D_EXEC_NAME ${bold}p${normal}[lug]                   [-ynl]…     [--] REPO/DIR
    $D_EXEC_NAME ${bold}u${normal}[pdate]                 [-yn]…      [--] [TASK]…

    $D_EXEC_NAME --version
    $D_EXEC_NAME -h|--help

DESCRIPTION
    Modular cross-platform dotfiles framework. Works wherever Bash does.
    
    Launch with '-n' option for a harmless introductory dry run.

    ${bold}'Install' routine${normal} - installs tasks

    - Collects tasks from two sources in 'grail/dpls' directory:
      - Package names from special files named 'Divinefile'
      - Deployments from special scripts named '*.dpl.sh'
    - Sorts tasks by priority (${bold}ascending${normal} integer order)
    - Updates installed packages using system’s package manager
    - Performs tasks in order:
      - ${bold}Installs${normal} packages using system’s package manager
      - ${bold}Installs${normal} deployments using 'dinstall' function in each

    ${bold}'Remove' routine${normal} - removes tasks

    - Collects tasks from two sources in 'grail/dpls' directory:
      - Package names from special files named 'Divinefile'
      - Deployments from special scripts named '*.dpl.sh'
    - ${bold}Reverse${normal}-sorts tasks by priority (${bold}descending${normal} integer order)
    - Updates installed packages using system’s package manager
    - Performs tasks in order:
      - ${bold}Removes${normal} deployments using 'dremove' function in each
      - ${bold}Removes${normal} packages using system’s package manager
    
    ${bold}'Check' routine${normal} - checks status of tasks

    - Collects tasks from two sources in 'grail/dpls' directory:
      - Package names from special files named 'Divinefile'
      - Deployments from special scripts named '*.dpl.sh'
    - Sorts tasks by priority (${bold}ascending${normal} integer order)
    - Checks and reports whether each task appears installed or not

    ${bold}'Attach' routine${normal} - imports deployments from Github

    - Accepts deployments in any of two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repository 'no-simpler/divine-dpls-NAME')
      - Third-party deployment package (Github repository) in the form 
        'username/repository'
    - Makes shallow clones of repositories or downloads them into internal 
      directory
    - Records source of successfull clone/download in Grail directory for 
      future replication/updating
    - Prompts before overwriting

    ${bold}'Detach' routine${normal} - removes previously imported Github deployments

    - Accepts deployments in any of two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repository 'no-simpler/divine-dpls-NAME')
      - Third-party deployment package (Github repository) in the form 
        'username/repository'
    - If such a repository is currently attached, removes it
    - Clears record of this repository from Grail directory

    ${bold}'Plug' routine${normal} - replaces Grail directory

    - Allows to quickly plug-in pre-made (and possibly version controlled) 
      version of Grail directory, containing user’s assets and deployments
    - Accepts Grail directory in any of three forms:
      - Github repository in the form 'username/repository'
      - Address of a git repository
      - Path to a directory
    - Makes shallow clones of repositories or downloads them into a built-in 
      directory; in case of plain directories — makes a copy or, optionally, a 
      symlink
    - Prompts before overwriting

    ${bold}'Update' routine${normal} - updates framework, deployment repos, and Grail

    - Accepts following tasks (as arguments):
      - 'f'/'fmwk'/'framework'    : framework itself
      - 'g'/'grail'               : Grail directory (if it is cloned)
      - 'd'/'dpls'/'deployments'  : all attached deployments
      - 'a'/'all'                 : (same as empty task list) all of the above
    - Updates each task by either pulling from repository or re-downloading and 
      overwriting files one by one (where possible)

    ${bold}Task list${normal}

    Whenever a list of tasks is provided, only those tasks are performed. Task 
    names are case insensitive. Names 'Divinefile'/'dfile'/'df' are reserved to 
    refer to processing of Divinefiles. Other names refer to deployments or 
    deployment groups.

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

__show_help_and_exit