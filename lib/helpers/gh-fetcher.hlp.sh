#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: gh-fetcher
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    3
#:revdate:      2019.09.04
#:revremark:    Add check for empty destination; silence dreadlink
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
  # Parse options
  local args=() opts opt i
  local name
  while (($#)); do
    case $1 in
      --)         shift; args+=("$@"); break;;
      -n|--name)  shift; (($#)) && name="$1" || break;;
      -*)         opts="$1"; shift
                  for (( i=1; i<${#opts}; ++i )); do
                    opt="${opts:i:1}"
                    case $opt in
                      n)  if (($#)); then name="$1"; shift; else
                            dprint_debug \
                              "${FUNCNAME}: Ignoring option '$opt'" \
                              'without its required argument'
                          fi
                          ;;
                      *)  dprint_debug \
                            "${FUNCNAME}: Ignoring unrecognized option: '$opt'"
                          ;;
                    esac
                  done
                  continue
                  ;;
      *)          args+=("$1");;
    esac; shift
  done; set -- "${args[@]}"

  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift

  # Check if username/repository is valid
  if [[ $user_repo =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then

    # Compose full repo url
    local repo_url="https://github.com/$user_repo"

  else

    # Refuse to work with the argument
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Refusing to retrieve $name" )
    else
      failure_report+=( 'Refusing to retrieve a Github repository' )
    fi
    failure_report+=( 'due to invalid repository handle:' -i "$user_repo" )

    # Report and return failure
    dprint_failure "${failure_report[@]}"
    return 1

  fi

  # Check if given path is empty
  if [ -z "$perm_dest" ]; then

    # Unacceptable: assemble failure report
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Refusing to retrieve $name from:" )
    else
      failure_report+=( 'Refusing to retrieve a Github repository from:' )
    fi
    failure_report+=( -i "$repo_url" -n 'because no destination is provided' )

    # Report and return failure
    dprint_failure "${failure_report[@]}"
    return 1

  fi

  # Canonicalize destination path
  perm_dest="$( dreadlink -qm -- "$perm_dest" 2>/dev/null )"

  # Internal flag for whether a directory was created
  local perm_dest_created=false

  # Check if destination path exists
  if [ -e "$perm_dest" ]; then

    # Check if destination is anything but an empty directory
    if ! [ -d "$perm_dest" -a -z "$( ls -A -- "$perm_dest" 2>/dev/null )" ]
    then

      # Unacceptable: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Refusing to retrieve $name from:" )
      else
        failure_report+=( 'Refusing to retrieve a Github repository from:' )
      fi
      failure_report+=( -i "$repo_url" -n 'into:' -i "$perm_dest" )
      if [ -d "$perm_dest" ]; then
        failure_report+=( -n 'because that directory exists and is not empty' )
      elif [ -f "$perm_dest" ]; then
        failure_report+=( -n 'because a file already exists at that location' )
      else
        failure_report+=( -n 'because that location is occupied' )
      fi

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  else

    # Make sure the directory exists
    if mkdir -p -- "$perm_dest" &>/dev/null; then

      # Set flag
      perm_dest_created=true

    else

      # Failed to make directory: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Failed to retrieve $name from:" )
      else
        failure_report+=( 'Failed to retrieve a Github repository from:' )
      fi
      failure_report+=( -i "$repo_url" -n 'into:' -i "$perm_dest" )
      failure_report+=( \
        -n 'due to error during creation of destination directory' \
      )

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  fi

  if [ -n "$name" ]; then
    dprint_debug \
      "Attempting to clone/download $name from a Github repository: $user_repo"
  else
    dprint_debug "Attempting to clone/download a Github repository: $user_repo"
  fi

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    dprint_debug 'Git is available'

    if git ls-remote "${repo_url}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      dprint_debug 'Github repository appears to exist; cloning'

      # Make shallow clone of repository
      if git clone --depth=1 "${repo_url}.git" "$perm_dest" &>/dev/null
      then

        # Announce success
        dprint_debug 'Cloned Github repository from:' -i "$repo_url" \
          -n 'into:' -i "$perm_dest"

      else

        # Failed to clone: assemble failure report
        local failure_report=()
        if [ -n "$name" ]; then
          failure_report+=( "Failed to clone $name from:" )
        else
          failure_report+=( 'Failed to clone a Github repository from:' )
        fi
        failure_report+=( -i "${repo_url}.git" -n 'into:' -i "$perm_dest" )

        # Remove destination directory if it has been created
        $perm_dest_created && rm -rf -- "$perm_dest"

        # Report and return failure
        dprint_failure "${failure_report[@]}"
        return 1

      fi
      
    else

      # Failed to connect to repo: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Failed to retrieve $name from:" )
      else
        failure_report+=( 'Failed to retrieve a Github repository from:' )
      fi
      failure_report+=( -i "${repo_url}.git" )
      failure_report+=( -n 'because the repository appears to not exist' )

      # Remove destination directory if it has been created
      $perm_dest_created && rm -rf -- "$perm_dest"

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  else

    # Git unavailable: download instead
    dprint_debug 'Git is not available'

    # Check if tar is available
    if tar --version &>/dev/null; then

      # Fire debug message
      dprint_debug 'tar is available'

    else

      # Tar is not available: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Refusing to retrieve $name from:" )
      else
        failure_report+=( 'Refusing to retrieve a Github repository from:' )
      fi
      failure_report+=( -i "$repo_url" )
      failure_report+=( -n 'because both Git and tar are not available' )

      # Remove destination directory if it has been created
      $perm_dest_created && rm -rf -- "$perm_dest"

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 )
    then

      # Both curl and remote repo are available
      dprint_debug \
        'curl is available; Github repository appears to exist; downloading'

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$perm_dest" -xzf -

      # Check status
      if [ $? -eq 0 ]; then

        # Announce success
        dprint_debug 'Downloaded and untarred a Github repository from:' \
          -i "https://api.github.com/repos/${user_repo}/tarball" \
          -n 'into:' -i "$perm_dest" -n 'using curl and tar'

      else

        # Failed to clone: assemble failure report
        local failure_report=()
        if [ -n "$name" ]; then
          failure_report+=( "Failed to download and untar $name from:" )
        else
          failure_report+=( \
            'Failed to download and untar a Github repository from:' \
          )
        fi
        failure_report+=( \
          -i "https://api.github.com/repos/${user_repo}/tarball" \
          -n 'into:' -i "$perm_dest" -n 'using curl and tar' \
        )

        # Remove destination directory if it has been created
        $perm_dest_created && rm -rf -- "$perm_dest"

        # Report and return failure
        dprint_failure "${failure_report[@]}"
        return 1

      fi

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available
      dprint_debug \
        'wget is available; Github repository appears to exist; downloading'

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$perm_dest" -xzf -

      # Check status
      if [ $? -eq 0 ]; then

        # Announce success
        dprint_debug 'Downloaded and untarred a Github repository from:' \
          -i "https://api.github.com/repos/${user_repo}/tarball" \
          -n 'into:' -i "$perm_dest" -n 'using wget and tar'

      else

        # Failed to clone: assemble failure report
        local failure_report=()
        if [ -n "$name" ]; then
          failure_report+=( "Failed to download and untar $name from:" )
        else
          failure_report+=( \
            'Failed to download and untar a Github repository from:' \
          )
        fi
        failure_report+=( \
          -i "https://api.github.com/repos/${user_repo}/tarball" \
          -n 'into:' -i "$perm_dest" -n 'using wget and tar' \
        )

        # Remove destination directory if it has been created
        $perm_dest_created && rm -rf -- "$perm_dest"

        # Report and return failure
        dprint_failure "${failure_report[@]}"
        return 1

      fi

    else

      # Either none of the tools were available, or repo does not exist
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Refusing to retrieve $name from:" )
      else
        failure_report+=( 'Refusing to retrieve a Github repository from:' )
      fi
      failure_report+=( -i "$repo_url" )
      if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
        failure_report+=( -n 'because git, curl, and wget are not available' )
      else
        failure_report+=( -n 'because the repository appears to not exist' )
      fi

      # Remove destination directory if it has been created
      $perm_dest_created && rm -rf -- "$perm_dest"

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi
  
  fi

  # If gotten here, all is good
  return 0
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