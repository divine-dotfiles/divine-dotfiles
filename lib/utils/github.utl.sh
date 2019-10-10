#!/usr/bin/env bash
#:title:        Divine Bash utils: github
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Finish implementing three special queues
#:created_at:   2019.09.13

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## A set of utilities designed to clone Github repositories.
#

#>  d___clone_gh_repo REPO_HANDLE REPO_PATH
#
## INTERNAL USE ONLY
#
## Makes a shallow clone using Git of the Github repository REPO_HANDLE (in the 
#. form 'username/repository') into the empty/non-existent directory REPO_PATH.
#
## Returns:
#.  0 - Successfully cloned.
#.  1 - Otherwise.
#
d___clone_gh_repo()
{
  d__context -- notch
  d__context -- push "Cloning Github repository '$1'"
  d__context -- push "Cloning into: $2"
  d__cmd --qq-- git clone --depth=1 --REPO_URL-- "https://github.com/$1.git" \
    --REPO_PATH-- "$2" --else-- 'Failed to clone' || return 1
  d__context -- pop
  d__context -t 'Done' -- pop "Successfully cloned Github repository '$1'"
  d__context -- lop
  return 0
}

#>  d___curl_gh_repo REPO_HANDLE REPO_PATH
#
## INTERNAL USE ONLY
#
## Downloads using curl the latest copy of the Github repository REPO_HANDLE 
#. (in the form 'username/repository') into the empty directory REPO_PATH.
#
## Returns:
#.  0 - Successfully downloaded and untarred.
#.  1 - Otherwise.
#
d___curl_gh_repo()
{
  d__context -- notch
  d__context -- push "Downloading Github repository '$1' via curl"
  d__context -- push "Downloading into: $2"
  d__pipe --qq-- curl -sL \
    --REPO_URL-- "https://api.github.com/repos/$1/tarball" \
    --pipe-- tar --strip-components=1 -C --REPO_PATH-- "$2" -xzf - \
    --else-- 'Failed to download/untar' || return 1
  d__context -- pop
  d__context -t 'Done' -- pop \
    "Successfully downloaded and untarred Github repository '$1'"
  d__context -- lop
  return 0
}

#>  d___wget_gh_repo REPO_HANDLE REPO_PATH
#
## INTERNAL USE ONLY
#
## Downloads using wget the latest copy of the Github repository REPO_HANDLE 
#. (in the form 'username/repository') into the empty directory REPO_PATH.
#
## Returns:
#.  0 - Successfully downloaded and untarred.
#.  1 - Otherwise.
#
d___wget_gh_repo()
{
  d__context -- notch
  d__context -- push "Downloading Github repository '$1' via wget"
  d__context -- push "Downloading into: $2"
  d__pipe --qq-- wget -qO - \
    --REPO_URL-- "https://api.github.com/repos/$1/tarball" \
    --pipe-- tar --strip-components=1 -C --REPO_PATH-- "$2" -xzf - \
    --else-- 'Failed to download/untar' || return 1
  d__context -- pop
  d__context -t 'Done' -- pop \
    "Successfully downloaded and untarred Github repository '$1'"
  d__context -- lop
  return 0
}

#>  d___pull_updates_from_gh REPO_HANDLE REPO_PATH
#
## INTERNAL USE ONLY
#
## Within a directory REPO_PATH, which must be a cloned Git repository, pulls 
#. using Git from the branch 'master' on the remote 'origin', from what is 
#. assumed to be the Github repository REPO_HANDLE (in the form 
#. 'username/repository'; only used by this function in the debug output).
#
## Returns:
#.  0 - Successfully pulled from the remote.
#.  1 - Otherwise.
#
d___pull_updates_from_gh()
{
  d__context -- notch
  d__context -- push "Updating cloned repository at: $2"
  d__cmd --sb-- pushd -- --REPO_PATH-- "$2" \
    --else-- 'Unable to pull updates into inaccessible directory' || return 1
  d__context -- push "Pulling from Github repository '$1'"
  d__cmd --qq-- git pull --rebase --stat origin master \
    --else-- 'Failed to pull updates' || { popd; return 1; }
  d__context -- pop
  popd
  d__context -t 'Done' -- pop \
    "Successfully pulled updates from Github repository '$1'"
  d__context -- lop
  return 0
}

#>  d___move_root_files SRC_PATH DEST_PATH
#
## INTERNAL USE ONLY
#
## One-by-one, moves files and directories from the root of the directory at 
#. SRC_PATH to an existing directory at DEST_PATH. Overwrites existing files of 
#. the same name at the DEST_PATH.
#
## Returns:
#.  0 - Root files moved successfully.
#.  1 - Otherwise.
#
d___move_root_files()
{
  d__context -- notch
  d__context -qq -- push "Moving root children of: $1"
  d__context -qq -- push "Overwriting at: $2"
  local src_path rel_path dest_path
  while IFS= read -r -d $'\0' src_path; do
    rel_path="${src_path#"$1/"}"; dest_path="$2/$rel_path"
    d__cmd rm -rf -- --DEST_PATH-- "$dest_path" \
      --else-- "Failed to clobber: $rel_path" || return 1
    d__cmd mv -n -- --SRC_PATH-- "$src_path" --DESC_PATH-- "$dest_path" \
      --else-- "Failed to move: $rel_path" || return 1
  done < <( find "$1" -mindepth 1 -maxdepth 1 \
    \( -type f -or -type d \) -print0 )
  d__context -- pop
  d__context -t 'Done' -- pop "Updated the files at: $2"
  d__context -- lop
}

#>  d___gh_repo_exists REPO_HANDLE
#
## INTERNAL USE ONLY
#
## Checks whether the handle REPO_HANDLE (in the form 'username/repository') 
#. describes an existing and accessible Github repository.
#
## Uses in the global scope:
#>  $D__GH_METHOD - Global indicator of whether proper instruments for 
#.                  interaction with Github are available.
#
## Returns:
#.  0         - A Github repository by that handle exists and is accessible.
#.  non-zero  - Otherwise.
#
d___gh_repo_exists()
{
  case $D__GH_METHOD in
    g)  git ls-remote "https://github.com/$1.git" -q &>/dev/null;;
    c)  grep -q 200 < <( curl -I "https://api.github.com/repos/$1" \
          2>/dev/null | head -1 );;
    w)  grep -q 200 < <( wget -q --spider --server-response \
          "https://api.github.com/repos/$1" 2>&1 | head -1 );;
    *)  return 1;;
  esac
}

#>  d___path_is_gh_clone REPO_PATH REPO_HANDLE
#
## INTERNAL USE ONLY
#
## Checks whether the existing directory at REPO_PATH is a Git clone of the 
#. Github repository REPO_HANDLE (in the form 'username/repository').
#
## Returns:
#.  0 - The directory is accessible, Git is available, and the directory is a 
#.      Git clone of the given repository.
#.  1 - Otherwise: the directory is accessible, but either Git is unavailable, 
#.      or the directory is not a Git clone of the given repository.
#.  2 - The directory is inaccessible.
#
d___path_is_gh_clone()
{
  if pushd -- "$1" &>/dev/null; then
    if [ "$( git remote get-url origin 2>/dev/null )" \
      = "https://github.com/$2.git" ]
    then popd &>/dev/null; return 0
    else popd &>/dev/null; return 1; fi
  fi; return 2
}