#!/usr/bin/env bash
#:title:        Divine Bash routine: help
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.16
#:revremark:    Prioritize arg parsing in main scripts
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Shows help and exits the script
#

# Marker and dependencies
readonly D__RTN_HELP=loaded
d__load util workflow

#>  d__rtn_help
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
d__rtn_help()
{
  # Store help summary in a variable
  local help; read -r -d '' help << EOF
NAME
    ${BOLD}${D__EXEC_NAME}${NORMAL} - launch Divine intervention

SYNOPSIS
    $D__EXEC_NAME ${BOLD}c${NORMAL}[heck]     [-ynqvew]  [-b BUNDLE]... [--] [TASK]...
    $D__EXEC_NAME ${BOLD}i${NORMAL}[nstall]   [-ynqvewf] [-b BUNDLE]... [--] [TASK]...
    $D__EXEC_NAME ${BOLD}r${NORMAL}[emove]    [-ynqvewf] [-b BUNDLE]... [--] [TASK]...

    $D__EXEC_NAME ${BOLD}a${NORMAL}[ttach]    [-yn]                     [--] REPO...
    $D__EXEC_NAME ${BOLD}d${NORMAL}[etach]    [-yn]                     [--] REPO...
    $D__EXEC_NAME ${BOLD}p${NORMAL}[lug]      [-ynl]                    [--] REPO/DIR
    $D__EXEC_NAME ${BOLD}u${NORMAL}[pdate]    [-yn]      [-b BUNDLE]... [--] [TASK]...

    $D__EXEC_NAME --version
    $D__EXEC_NAME -h|--help

DESCRIPTION
    Divine.dotfiles promotes Bash scripts to portable deployments that are 
    installed/removed in defined sequence. The term deployments includes 
    Divinefiles as a special kind.

    Full documentation is available at:
      https://github.com/no-simpler/divine-dotfiles

    This Divine intervention utility is the command line interface to the 
    Divine.dotfiles framework. The intervention utility does:

    - ${BOLD}Primary routines${NORMAL} on deployments and Divinefiles:
      - ${BOLD}Check${NORMAL} whether deployments are installed or not.
      - ${BOLD}Install${NORMAL} deployments.
      - ${BOLD}Remove${NORMAL} (uninstall) deployments.
    - ${BOLD}Attach/detach${NORMAL} third-party bundles of deployments from Github.
    - ${BOLD}Plug in${NORMAL} pre-made Grail directory from a repository or local directory.
    - ${BOLD}Update${NORMAL} framework itself, attached bundles, and Grail directory, if it 
      is a cloned repository.

    ${BOLD}Primary routines${NORMAL}

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
    - Particular deployments are requested by listing their names or single-
      digit group names, in any combination.
    - Dangerous deployments (marked with '!' flag) are ignored unless requested 
      by name (not by single-digit group name), or unless '--with-!'/'-w' 
      option is used.
    - Option '--except'/'-e' inverts filtering: all deployments are processed, 
      ${BOLD}except${NORMAL} those listed. Note, that without any arguments, 
      this is a no-opt. In this mode, dangerous deployments are still filtered 
      out by default.
    - The search can be narrowed down to particular bundles of deployments by 
      listing each with the '--bundle'/'-b' option.

    After filtering, deployments and packages from Divinefiles are sorted in 
    order of ascending priority. For uninstallation, that order is fully 
    reversed.
    
    ${BOLD}'Check' routine${NORMAL} - checks status of tasks

    Sequentially checks packages and deployments, reporting whether each 
    appears installed or not.

    ${BOLD}'Install' routine${NORMAL} - installs tasks

    Sequentially installs packages and deployments. Before starting, launches 
    the update routine on the system's package manager.

    ${BOLD}'Remove' routine${NORMAL} - removes tasks

    Sequentially uninstalls packages and deployments. Before starting, launches 
    the update routine on the system's package manager.

    ${BOLD}'Attach' routine${NORMAL} - attaches deployments from Github

    - Accepts bundles of deployments in any of two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repository 'no-simpler/divine-bundle-NAME').
      - Third-party deployment package (Github repository) in the form 
        'username/repository'.
    - Makes shallow clones of repositories (or downloads them) into internal 
      directory.
    - Records source of successfull clone/download in the Grail directory for 
      future replication/updating.
    - Prompts before overwriting.

    ${BOLD}'Detach' routine${NORMAL} - removes previously attached Github deployments

    - Accepts bundles of deployments in any of two forms:
      - Divine deployment package in the form 'NAME' (which translates to 
        Github repository 'no-simpler/divine-bundle-NAME').
      - Third-party deployment package (Github repository) in the form 
        'username/repository'.
    - If such a repository is currently attached, removes it.
    - Clears record of this repository from Grail directory.

    ${BOLD}'Plug' routine${NORMAL} - replaces Grail directory

    - Allows to quickly plug-in pre-made (and possibly version controlled) 
      version of the Grail directory, containing user's assets and deployments.
    - Accepts Grail directory in any of three forms:
      - Github repository in the form 'username/repository'.
      - Address of a git repository.
      - Path to a directory.
    - Makes shallow clones of repositories or downloads them into a built-in 
      directory; in case of plain directories - makes a copy or, optionally, a 
      symlink.
    - Prompts before overwriting.

    ${BOLD}'Update' routine${NORMAL} - updates framework, deployment repos, and Grail

    - Accepts following tasks (as arguments):
      - 'f'/'fmwk'/'framework'    : Framework itself.
      - 'g'/'grail'               : Grail directory (if it is cloned).
      - 'b'/'bdls'/'bundles'      : Attached bundles.
      - 'a'/'all'                 : (same as empty task list) All of the above.
    - Updates each task by either pulling from repository or re-downloading and 
      overwriting files one by one (where possible).

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
                    attaching of bundles. This option also works during update 
                    routine, where it specifies bundles to update.

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

    -v, --verbose   (repeatable) Gradually increase the amount of output.
                    Every instance of this option increments by one the global 
                    verbosity level of the framework. The debug output in the 
                    deployments and the framework components has the quiet 
                    level. For a message to be printed, the global verbosity 
                    level must be greater than or equal to that message's quiet 
                    level.

    -q, --quiet     (default) Reset the amount of output to the minimal level. 
                    This option reverts the global verbosity level to its 
                    defaul value of zero.

    --version       Show framework version

    -h, --help      Show this help summary

AUTHOR
    ${BOLD}Grove Pyree${NORMAL} <grayarea@protonmail.ch>

    Part of ${BOLD}Divine.dotfiles${NORMAL} <https://github.com/no-simpler/divine-dotfiles>

    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
EOF

  # Print help summary
  if less --version &>/dev/null
  then less -R <<<"$help"
  else printf >&2 '\n%s\n' "$help"; fi
  exit 0
}

d__rtn_help