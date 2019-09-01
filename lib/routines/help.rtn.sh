#!/usr/bin/env bash
#:title:        Divine Bash routine: help
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    14
#:revdate:      2019.09.01
#:revremark:    Tweak bolding in miscellaneous locations
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Shows help and exits the script
#

#>  d__show_help_and_exit
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
d__show_help_and_exit()
{
  # Add bolding if available
  local bold normal
  if type -P tput &>/dev/null && tput sgr0 &>/dev/null \
    && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]
  then bold=$(tput bold); normal=$(tput sgr0)
  else bold="$(printf "\033[1m")"; NORMAL="$(printf "\033[0m")"; fi

  # Store help summary in a variable
  local help
  read -r -d '' help << EOF
NAME
    ${bold}${D__EXEC_NAME}${normal} - launch Divine intervention

SYNOPSIS
    $D__EXEC_NAME ${bold}c${normal}[heck]              [-ynqvew]  [-b BUNDLE]... [--] [TASK]...
    $D__EXEC_NAME ${bold}i${normal}[nstall]            [-ynqvewf] [-b BUNDLE]... [--] [TASK]...
    $D__EXEC_NAME ${bold}r${normal}[emove]             [-ynqvewf] [-b BUNDLE]... [--] [TASK]...

    $D__EXEC_NAME ${bold}a${normal}[ttach]             [-yn]                     [--] REPO...
    $D__EXEC_NAME ${bold}d${normal}[etach]             [-yn]                     [--] REPO...
    $D__EXEC_NAME ${bold}p${normal}[lug]               [-ynl]                    [--] REPO/DIR
    $D__EXEC_NAME ${bold}u${normal}[pdate]             [-yn]                     [--] [TASK]...

    $D__EXEC_NAME --version
    $D__EXEC_NAME -h|--help

DESCRIPTION
    Divine.dotfiles promotes Bash scripts to portable deployments that are 
    installed/removed in defined sequence. The term deployments includes 
    Divinefiles as the special kind of the former.

    Full documentation available at:
      https://github.com/no-simpler/divine-dotfiles

    This divine intervention utility is the command line interface to the 
    Divine.dotfiles framework. Intervention utility does:

    - ${bold}Primary routines${normal} on deployments and Divinefiles:
      - ${bold}Check${normal} whether deployments are installed or not.
      - ${bold}Install${normal} deployments.
      - ${bold}Uninstall${normal} deployments.
    - ${bold}Attach/detach${normal} third-party bundles of deployments from Github.
    - ${bold}Plug in${normal} pre-made Grail directory from a repository or local directory.
    - ${bold}Update${normal} framework itself, attached bundles, and Grail directory, if it 
      is a cloned repository.

    ${bold}Primary routines${normal}

    Primary routines - the core of the framework - launch respective functions 
    on deployments. Accepted values of TASK are (case-insensitive):

    - Names of deployments.
    - Reserved synonyms for Divinefiles: 'divinefile', 'dfile', 'df'.
    - Single-digit names of deployment groups: '0', '1', '2', '3', '4', '5', 
      '6', '7', '8', '9'.

    - Without any arguments, all deployments are processed.
    - By default, deployments are retrieved from two locations (at any depth):
      - User's deployments: 'grail/dpls/'.
      - Attached bundles of deployments: 'state/bundles/'.
    - Particular bundles of deployments are requested by listing them with the 
      '--bundle'/'-b' option.
    - Particular deployments are requested by listing their names or single-
      digit group names, in any combination.
    - Dangerous deployments (marked with '!' flag) are ignored unless requested 
      by name (not by single-digit group name), or unless '--with-!'/'-w' 
      option is used.
    - Option '--except'/'-e' inverts filtering: all deployments are processed, 
      ${bold}except${normal} those listed. Note, that without any arguments, 
      this is a no-opt. In this mode, dangerous deployments are still filtered 
      out by default.

    After filtering, deployments and packages from Divinefiles are sorted in 
    order of ascending priority. For uninstallation, that order is fully 
    reversed.
    
    ${bold}'Check' routine${normal} - checks status of tasks

    Sequentially checks packages and deployments, reporting whether each 
    appears installed or not

    ${bold}'Install' routine${normal} - installs tasks

    Updates installed packages using the system's package manager; then 
    sequentially installs packages and deployments.

    ${bold}'Remove' routine${normal} - removes tasks

    Updates installed packages using the system's package manager; then 
    sequentially uninstalls packages and deployments.

    ${bold}'Attach' routine${normal} - attaches deployments from Github

    - Accepts bundles of deployments in any of two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repository 'no-simpler/divine-bundle-NAME')
      - Third-party deployment package (Github repository) in the form 
        'username/repository'
    - Makes shallow clones of repositories (or downloads them) into internal 
      directory
    - Records source of successfull clone/download in the Grail directory for 
      future replication/updating
    - Prompts before overwriting

    ${bold}'Detach' routine${normal} - removes previously attached Github deployments

    - Accepts bundles of deployments in any of two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repository 'no-simpler/divine-bundle-NAME')
      - Third-party deployment package (Github repository) in the form 
        'username/repository'
    - If such a repository is currently attached, removes it
    - Clears record of this repository from Grail directory

    ${bold}'Plug' routine${normal} - replaces Grail directory

    - Allows to quickly plug-in pre-made (and possibly version controlled) 
      version of the Grail directory, containing user's assets and deployments
    - Accepts Grail directory in any of three forms:
      - Github repository in the form 'username/repository'
      - Address of a git repository
      - Path to a directory
    - Makes shallow clones of repositories or downloads them into a built-in 
      directory; in case of plain directories - makes a copy or, optionally, a 
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

OPTIONS
    -y, --yes       Assume affirmative answer to every prompt. Deployments may 
                    override this option to make sure that user is prompted 
                    every time.

    -n, --no        Assume negatory answer to every prompt. In effect, skips 
                    every task. Including this option always results in a 'dry 
                    run' where nothing is actually done.
    
    -b BUNDLE, --bundle BUNDLE
                    (repeatable) If at least one such option is provided, the 
                    search for deployments will be limited to the given 
                    attached bundles of deployments. Accepted values of BUNDLE 
                    are the same as the accepted values of REPO during 
                    attaching of bundles.

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

    -e, --except    (if no args are provided to the script, this is no-opt)
                    Inverse task list: filter out tasks included in it, instead 
                    of filtering them in

    -w, --with-!    By default, framework filters out deployments containing 
                    '!' flag. This option removes that behavior.

    -l, --link      ('plug' routine only, otherwise no-opt)
                    Prefer to symlink external Grail directory and avoid 
                    cloning or downloading repositories.

    -q, --quiet     (default) Decreases amount of status messages

    -v, --verbose   Increases amount of status messages

    --version       Show framework version

    -h, --help      Show this help summary

AUTHOR
    ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>

    Part of ${bold}Divine.dotfiles${normal} <https://github.com/no-simpler/divine-dotfiles>

    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
EOF

  # Print help summary
  if less --version &>/dev/null; then
    less -R <<<"$help"
  else
    printf '%s\n' "$help"
  fi
  exit 0
}

d__show_help_and_exit