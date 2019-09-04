#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: gh-fetcher
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1
#:revdate:      2019.09.04
#:revremark:    Stub github fetcher functions
#:created_at:   2019.09.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions that clone or download Github repositories into target 
#. directories.
#

#>  d__get_gh_repo [-n NAME] [--] SRC DEST
#
## Tries various methods to get a Github repository at SRC into directory at 
#. DEST. The methods attempted are, in order: clone with git, download with 
#. curl, and download with wget.
#
## If DEST exists and is not an empty directory, refuses to touch it.
#
## SRC must be in the format 'username/repository'.
#
## Options:
#.  -n NAME, --name NAME  - Use NAME in human-readable output to reference the 
#.                          content of the repository. Otherwise, messages are 
#.                          more generic.
#
## Returns:
#.  0 - SRC is a Github repository, and it is now cloned/downloaded to DEST
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Error descriptions, if any
#
d__get_gh_repo()
{
  :
}

#>  d__ensure_gh_repo [-n NAME] [--] SRC DEST
#
## If DEST is a local repository that has SRC among its remotes: pulls from 
#. that remote with 'git pull --rebase --stat', effectively updating the 
#. content to the latest revision on the master branch.
#
## Otherwise: if DEST exists, preserves it according to the backup strategy; 
#. then clones or downloads SRC into a temporary location; then moves its root 
#. elements into a directory at DEST one by one (including '.git' directory, 
#. if it is there).
#
## DEST will be canonicalized (made absolute, with all symlinks resolved) and 
#. used as such.
#
## Backup strategy for pre-existing files differs depending on whether the 
#. function is called from a deployment or from the framework code:
#.  * From a deployment: pre-existing DEST is moved in its entirety to the 
#.    deployment's backups directory, and the fact is recorded in the stash.
#.    The stash key is the md5 checksum from the string 'SRC___DEST' (triple 
#.    underscore in the middle), prefixed with 'gh_'. The stash value is the 
#.    canonicalized DEST. The actual backup is stored in $D__DPL_BACKUP_DIR, 
#.    and is named with the stash key.
#.  * From the framework: it is assumed, that this function is used to maintain 
#.    framework components, or, in other words, any pre-existing files are NOT 
#.    user's data. Thus, no backups are made. Note, that because it's the root 
#.    elements that are moved, not the cloned directory itself, additional 
#.    files in DEST are preserved. E.g., if the framework itself is updated, 
#.    the directories 'grail' and 'state' (which are not part of the 
#.    distribution) will be untouched.
#
## SRC must be in the format 'username/repository'.
#
## Options:
#.  -n NAME, --name NAME  - Use NAME in human-readable output to reference the 
#.                          content of the repository. Otherwise, messages are 
#.                          more generic.
#
## Returns:
#.  0 - SRC is a git repository, and it is now cloned/downloaded to DEST
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Error descriptions, if any
#
d__ensure_gh_repo()
{
  :
}