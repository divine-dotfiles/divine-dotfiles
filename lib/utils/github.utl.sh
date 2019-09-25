#!/usr/bin/env bash
#:title:        Divine Bash utils: github
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Start implementing low-level parts of GH util
#:created_at:   2019.09.13

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## A set of utilities designed to clone Github repositories.
#

#>  d___clone_gh_repo
#
## INTERNAL USE ONLY
#
## Makes a shallow clone of the provided Github repository into the provided 
#. directory using Git.
#
## Local variables that must be populated in the calling scope:
#>  $repo_path    - The path to the local directory that will hold the clone. 
#.                  If it exists it must be empty.
#>  $repo_handle  - The handle of the Github repository to clone, in the form 
#.                  'username/repository'.
#
## Returns:
#.  0 - Git reported the success of the cloning operation.
#.  1 - Git reported an error while cloning.
#
d___clone_gh_repo()
{
  d__context -- notch
  d__context -- push "Cloning Github repository '$repo_handle'"
  d__cmd --qq-- git clone --depth=1 \
    --REPO_URL-- "https://github.com/$repo_handle.git" \
    --REPO_PATH-- "$repo_path" \
    --else-- 'Failed to clone' || return 3
  d__context -t 'Done' -- pop 'Successfully cloned'
  d__context -- lop
  return 0
}

#>  d___curl_gh_repo
#
## INTERNAL USE ONLY
#
## Downloads the latest copy of the provided Github repository into the 
#. provided directory using curl.
#
## Local variables that must be populated in the calling scope:
#>  $repo_path    - The path to the local directory that will hold the clone. 
#.                  If it exists it must be empty.
#>  $repo_handle  - The handle of the Github repository to clone, in the form 
#.                  'username/repository'.
#
## Returns:
#.  0 - Download is successful.
#.  1 - There was an error during downloading and untarring.
#
d___curl_gh_repo()
{
  d__context -- notch
  d__context -- push "Downloading Github repository '$repo_handle' via curl"
  d__pipe --qq-- curl -sL \
    --REPO_URL-- "https://api.github.com/repos/$repo_handle/tarball" \
    --pipe-- tar --strip-components=1 -C --REPO_PATH-- "$repo_path" -xzf - \
    --else-- 'Failed to download/untar' || return 3
  d__context -t 'Done' -- pop 'Successfully downloaded and untarred'
  d__context -- lop
  return 0
}

#>  d___wget_gh_repo
#
## INTERNAL USE ONLY
#
## Downloads the latest copy of the provided Github repository into the 
#. provided directory using wget.
#
## Local variables that must be populated in the calling scope:
#>  $repo_path    - The path to the local directory that will hold the clone. 
#.                  If it exists it must be empty.
#>  $repo_handle  - The handle of the Github repository to clone, in the form 
#.                  'username/repository'.
#
## Returns:
#.  0 - Download is successful.
#.  1 - There was an error during downloading and untarring.
#
d___wget_gh_repo()
{
  d__context -- notch
  d__context -- push "Downloading Github repository '$repo_handle' via wget"
  d__pipe --qq-- wget -qO - \
    --REPO_URL-- "https://api.github.com/repos/$repo_handle/tarball" \
    --pipe-- tar --strip-components=1 -C --REPO_PATH-- "$repo_path" -xzf - \
    --else-- 'Failed to download/untar' || return 3
  d__context -t 'Done' -- pop 'Successfully downloaded and untarred'
  d__context -- lop
  return 0
}

#>  d___pull_updates_from_gh
#
## INTERNAL USE ONLY
#
## Within the repo directory, pulls from the latest branch 'master' from the 
#. remote 'origin'.
#
## Local variables that must be populated in the calling scope:
#>  $repo_path  - The path to the local directory that is a cloned repository.
#
## Returns:
#.  0 - Successfully pulled from the remote.
#.  1 - Otherwise.
#
d___pull_updates_from_gh()
{
  :
}

#>  d___download_updates_from_gh
#
## INTERNAL USE ONLY
#
## Downloads the latest version of a repository into a temp directory, then 
#. overwrites each root element at the path to the local copy.
#
## Local variables that must be populated in the calling scope:
#>  $repo_handle  - The handle of the Github repository that is to be 
#.                  downloaded from, in the form 'username/repository'.
#>  $repo_path    - The path to the local directory is to be updated with the 
#.                  latest content of the repository.
#
## Returns:
#.  0 - Successfully downloaded and overwritten each root file/directory.
#.  1 - Otherwise.
#
d___download_updates_from_gh()
{
  :
}

#>  d___gh_repo_exists
#
## INTERNAL USE ONLY
#
## Checks whether the provided handle describes an existing and accessible 
#. Github repository.
#
## Local variables that must be populated in the calling scope:
#>  $D__GH_METHOD - Global indicator of whether proper instruments for 
#.                  interaction with Github are available.
#>  $repo_handle  - The handle that is to be checked against Github, in the 
#.                  form 'username/repository'.
#
## Returns:
#.  0         - A Github repository by that handle exists and is accessible.
#.  non-zero  - Otherwise.
#
d___gh_repo_exists()
{
  case $D__GH_METHOD in
    g)  git ls-remote "https://github.com/$repo_handle.git" -q &>/dev/null;;
    c)  grep -q 200 < <( curl -I "https://api.github.com/repos/$repo_handle" \
          2>/dev/null | head -1 );;
    w)  grep -q 200 < <( wget -q --spider --server-response \
          "https://api.github.com/repos/$repo_handle" 2>&1 | head -1 );;
    *)  return 1;;
  esac
}

#>  d___path_is_gh_clone
#
## INTERNAL USE ONLY
#
## Checks whether the provided directory is a Git clone of the provided Github 
#. repository.
#
## Local variables that must be populated in the calling scope:
#>  $repo_path    - The path to the local directory that is to be checked.
#>  $repo_handle  - The handle of the Github repository to check against, in 
#.                  the form 'username/repository'.
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
  if pushd -- "$repo_path" &>/dev/null; then
    if [ "$( git remote get-url origin 2>/dev/null )" \
      = "https://github.com/$repo_handle.git" ]
    then popd; return 0
    else popd; return 1; fi
  fi; return 2
}