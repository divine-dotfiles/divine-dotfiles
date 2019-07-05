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

__show_help_and_exit