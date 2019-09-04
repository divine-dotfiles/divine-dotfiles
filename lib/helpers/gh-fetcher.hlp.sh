#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: gh-fetcher
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    10
#:revdate:      2019.09.04
#:revremark:    Compartmentalize re-used code; start on primaries
#:created_at:   2019.09.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions that clone or download Github repositories into target 
#. directories.
#

#>  d__ensure_gh_repo [-upP] [-n NAME] [--] SRC DEST
#
## Ensures directory at DEST contains the most recent revision of files from 
#. the Github repository at SRC.
#
## If DEST is a local repository, and url of SRC matches exactly the value 
#. printed by 'git remote get-url origin': pulls from that remote with 
#. 'git pull --rebase --stat origin master', effectively updating DEST to the 
#. latest revision on the remote master branch.
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
## Mode (one active at a time, last option wins):
#.  -u, --unrestrict      - (default) Try to pull updates from remote, then, if 
#.                          unsuccessful, try cloning/downloading.
#.  -p, --pull-only       - Only pull from remotes in already properly cloned 
#.                          repositories; don't clone or download anything.
#.  -P, --no-pull         - Do not try to pull from remotes, insted go directly 
#.                          to cloning/downloading.
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
  # Parse options
  local args=() opts opt i
  local name restricted
  while (($#)); do
    case $1 in
      --)               shift; args+=("$@"); break;;
      -p|--pull-only)   restricted=pull_only;;
      -P|--no-pull)     restricted=no_pull;;
      -u|--unrestrict)  restricted=;;
      -n|--name)        shift; (($#)) && name="$1" || break;;
      -*)   opts="$1"; shift
            for (( i=1; i<${#opts}; ++i )); do
              opt="${opts:i:1}"
              case $opt in
                p)  restricted=pull_only;;
                P)  restricted=no_pull;;
                u)  restricted=;;
                n)  if (($#)); then name="$1"; shift; else
                      dprint_debug "${FUNCNAME}: Ignoring option '$opt'" \
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
      *)    args+=("$1");;
    esac; shift
  done; set -- "${args[@]}"

  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift

  # Compose repo url from username/repository
  local repo_url
  d__validate_user_repo_and_compose_url || return 1

  # Canonicalize destination path
  d__check_and_canonicalize_dest_path || return 1

  # Check if restricted in some way
  case $restricted in
    no_pull) :;;
    *)  d__pull_updates_from_remote; case $? in 
          0) return 0;; 1) return 1;; *) :;;
        esac
        ;;
  esac

  # Determine if called within a deployment by checking dpl stash readiness
  local in_dpl=false
  if dstash ready 2>/dev/null; then

    # Set flag
    in_dpl=true

  else

    ## Not in deployment: only allow updating framework components or attached 
    #. deployments if forcing
    if [ -e "$perm_dest" ] && ! $D__OPT_FORCE; then

      # No 'crude' updating without forcing: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Refusing to overwrite existing $name at:" )
      else
        failure_report+=( 'Refusing to overwrite existing path at:' )
      fi
      failure_report+=( -i "$perm_dest" )

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  fi

  # Print debug message
  if [ -n "$name" ]; then
    dprint_debug "Attempting to clone/download $name from:" \
      -i "$repo_url" -n 'into:' -i "$perm_dest"
  else
    dprint_debug "Attempting to clone/download a Github repository from:" \
      -i "$repo_url" -n 'into:' -i "$perm_dest"
  fi

  # Compose a temporary destination for the copy of the repository
  local temp_dest="$( mktemp -d )"

  # Attempt to clone/download the remote repository
  local repo_is_cloned=
  if ! d__get_gh_repo -qln "$name" -- "$user_repo" "$temp_dest"; then

    # Unable to get the repo: print additional failure notice
    dprint_failure 'Intended destination of failed cloning/downloading:' \
      -i "$perm_dest"

    # Return failure
    return 1

  fi

  # Ensure parent dir at least exists
  if ! mkdir -p -- "$( dirname -- "$perm_dest" )" &>/dev/null; then

    # Failed to make directory: assemble failure report
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Failed to retrieve $name from:" )
    else
      failure_report+=( 'Failed to retrieve a Github repository from:' )
    fi
    failure_report+=( -i "$repo_url" -n 'into:' -i "$perm_dest" )
    failure_report+=( \
      -n "due to error during creation of destination's parent directory" \
    )

    # Attempt to remove temp dir; report and return failure
    rm -rf -- "$temp_dest"
    dprint_failure "${failure_report[@]}"
    return 1

  fi

  # Determine if called within a deployment by checking dpl stash readiness
  if dstash ready 2>/dev/null; then

    # Called within deployment: compose stashing data
    local stash_key="gh_$( dmd5 -s "${user_repo}___${perm_dest}" )"
    local stash_val="$perm_dest"
    local backup_path="$D__DPL_BACKUP_DIR/$stash_key"

    # Check if destination exists
    if [ -e "$perm_dest" ]; then

      # Check if backup location is occupied
      if [ -e "$backup_path" ]; then
      
        if rm -rf -- "$backup_path" &>/dev/null; then

          # Fire debug message
          dprint_debug 'Erased a pre-existing backup at:' -i "$backup_path"

        else

          # Failed to remove backup: assemble failure report
          local failure_report=()
          if [ -n "$name" ]; then
            failure_report+=( "Failed to overwrite $name at:" )
          else
            failure_report+=( 'Failed to overwrite at:' )
          fi
          failure_report+=( \
            -i "$perm_dest" \
            -n 'due to failure to erase the previous backup at:' \
            -i "$backup_path" \
          )

          # Attempt to remove temp dir; report and return failure
          rm -rf -- "$temp_dest"
          dprint_failure "${failure_report[@]}"
          return 1

        fi

      fi

      # Move destination to backup location
      if mv -n -- "$perm_dest" "$backup_path" &>/dev/null; then

        # Set stash records
        dstash -s set "$stash_key" "$stash_val"
        if $repo_is_cloned; then
          dstash -s set "status_$stash_key" 'cloned'
        else
          dstash -s set "status_$stash_key" 'downloaded'
        fi

        # Fire debug message
        dprint_debug 'Moved existing path at:' -i "$perm_dest" \
          -n 'to backup location at:' -i "$backup_path"

      else

        # Failed to back up: assemble failure report
        local failure_report=()
        if [ -n "$name" ]; then
          failure_report+=( "Failed to overwrite $name at:" )
        else
          failure_report+=( 'Failed to overwrite at:' )
        fi
        failure_report+=( \
          -i "$perm_dest" \
          -n 'due to failure to back it up to:' \
          -i "$backup_path" \
        )

        # Attempt to remove temp dir; report and return failure
        rm -rf -- "$temp_dest"
        dprint_failure "${failure_report[@]}"
        return 1

      fi

    # Done with checking whether destination exists
    fi

    # Move temporary copy into place
    if mv -n -- "$temp_dest" "$perm_dest" &>/dev/null; then

      # And that's it folks
      local verb; $repo_is_cloned && verb=cloned || verb=downloaded
      if [ -n "$name" ]; then
        dprint_debug "Successfully $verb $name from:" \
          -i "$repo_url" -n 'into:' -i "$perm_dest"
      else
        dprint_debug \
          "Successfully $verb a Github repository from:" \
          -i "$repo_url" -n 'into:' -i "$perm_dest"
      fi
      return 0

    else

      # Failed to move into place: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Failed to move temporary copy of $name from:" )
      else
        failure_report+=( 'Failed to move temporary copy from:' )
      fi
      failure_report+=( \
        -i "$temp_dest" \
        -n 'to its intended location at:' \
        -i "$perm_dest" \
      )

      # Attempt to remove temp dir; report and return failure
      rm -rf -- "$temp_dest"
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  # Done processing when called within deployment
  fi

  ## At this point, definitely updating a framework components or attached 
  #. deployments. No backing up, just careful overwriting, if necessary.

  # Check if destination exists
  if [ -e "$perm_dest" ]; then

    # Check if it is anything but a directory
    if ! [ -d "$perm_dest" ]; then

      # Erase pre-existing file
      if rm -rf -- "$perm_dest" &>/dev/null; then

        # Fire debug message
        dprint_debug 'Erased a pre-existing file at:' -i "$perm_dest"

      else

        # Failed to remove pre-existing file: assemble failure report
        local failure_report=()
        if [ -n "$name" ]; then
          failure_report+=( "Failed to erase pre-existing $name at:" )
        else
          failure_report+=( 'Failed to erase a pre-existing file at:' )
        fi
        failure_report+=( -i "$perm_dest" )

        # Attempt to remove temp dir; report and return failure
        rm -rf -- "$temp_dest"
        dprint_failure "${failure_report[@]}"
        return 1

      fi

    fi

  fi

  # Ensure destination exists as an empty directory
  if ! mkdir -p -- "$perm_dest" &>/dev/null; then

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

    # Attempt to remove temp dir; report and return failure
    rm -rf -- "$temp_dest"
    dprint_failure "${failure_report[@]}"
    return 1

  fi

  # Storage variables
  local src_path rel_path tgt_path

  # Iterate over root elements of cloned/downloaded repository
  while IFS= read -r -d $'\0' src_path; do

    # Extract relative path
    rel_path="${src_path#"$temp_dest/"}"

    # Construct target path
    tgt_path="$perm_dest/$rel_path"

    # Check if target path exists
    if [ -e "$tgt_path" ]; then

      # Remove pre-existing target path
      if rm -rf -- "$tgt_path"; then

        # Fire debug message
        dprint_debug "Overwritten a root file/dir: $rel_path"

      else

        # Failed to remove pre-existing target path: assemble failure report
        local failure_report=()
        failure_report+=( "Failed to overwrite root dile/dir: $rel_path" )
        if [ -n "$name" ]; then
          failure_report+=( "while moving temporary copy of $name from:" )
        else
          failure_report+=( 'while moving temporary copy from:' )
        fi
        failure_report+=( \
          -i "$temp_dest" \
          -n 'to its intended location at:' \
          -i "$perm_dest" \
          -n 'The intended location may have been messed up'
        )

        # Attempt to remove temp dir; report and return failure
        rm -rf -- "$temp_dest"
        dprint_failure "${failure_report[@]}"
        return 1
      
      fi

    fi

    # Move temporary copy into place
    if ! mv -n -- "$src_path" "$tgt_path" &>/dev/null; then

      # Failed to move root file: assemble failure report
      local failure_report=()
      failure_report+=( "Failed to move root dile/dir: $rel_path" )
      if [ -n "$name" ]; then
        failure_report+=( "while moving temporary copy of $name from:" )
      else
        failure_report+=( 'while moving temporary copy from:' )
      fi
      failure_report+=( \
        -i "$temp_dest" \
        -n 'to its intended location at:' \
        -i "$perm_dest" \
        -n 'The intended location may have been messed up'
      )

      # Attempt to remove temp dir; report and return failure
      rm -rf -- "$temp_dest"
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  # Done iterating over root elements of cloned/downloaded repository
  done < <( find "$temp_dest" -mindepth 1 -maxdepth 1 \
    \( -type f -or -type d \) -print0 )

  # And that's all she wrote
  local verb; $repo_is_cloned && verb=cloned || verb=downloaded
  if [ -n "$name" ]; then
    dprint_debug "Successfully $verb $name from:" \
      -i "$repo_url" -n 'into:' -i "$perm_dest"
  else
    dprint_debug "Successfully $verb a Github repository from:" \
      -i "$repo_url" -n 'into:' -i "$perm_dest"
  fi
  return 0
}

#>  d__get_gh_repo [-ql] [-n NAME] [--] SRC DEST
#
## Tries various methods to get a Github repository at SRC into directory at 
#. DEST. The methods attempted are, in order: clone with git, download with 
#. curl, and download with wget.
#
## DEST will be canonicalized (made absolute, with all symlinks resolved) and 
#. used as such.
#
## If DEST exists and is not an empty directory, refuses to touch it.
#
## SRC must be in the format 'username/repository'.
#
## Options:
#.  -n NAME, --name NAME  - Use NAME in human-readable output to reference the 
#.                          content of the repository. Otherwise, messages are 
#.                          more generic.
#.  -q, --quiet           - Slightly decrease the amount of non-critical output
#.  -l, --lenient         - Slightly decrease the amount of argument checks. 
#.                          Critical failures will still appear as normal.
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
  local name quiet=false lenient=false
  while (($#)); do
    case $1 in
      --)           shift; args+=("$@"); break;;
      -q|--quiet)   quiet=true;;
      -l|--lenient) lenient=true;;
      -n|--name)    shift; (($#)) && name="$1" || break;;
      -*)   opts="$1"; shift
            for (( i=1; i<${#opts}; ++i )); do
              opt="${opts:i:1}"
              case $opt in
                q)  quiet=true;;
                l)  lenient=true;;
                n)  if (($#)); then name="$1"; shift; else
                      dprint_debug "${FUNCNAME}: Ignoring option '$opt'" \
                        'without its required argument'
                    fi
                    ;;
                *)  dprint_debug "${FUNCNAME}:" \
                      "Ignoring unrecognized option: '$opt'"
                    ;;
              esac
            done
            continue
            ;;
      *)    args+=("$1");;
    esac; shift
  done; set -- "${args[@]}"

  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift

  # Check if lenient on checks
  if $lenient; then

    # Compose full repo url
    local repo_url="https://github.com/$user_repo"

  else

    # Non lenient: perform extensive argument checks

    # Compose repo url from username/repository
    local repo_url; d__validate_user_repo_and_compose_url || return 1

    # Canonicalize destination path
    d__check_and_canonicalize_dest_path || return 1

    # Check if destination exists as anything but an empty directory
    if [ -e "$perm_dest" ] \
      && ! [ -d "$perm_dest" -a -z "$( ls -A -- "$perm_dest" 2>/dev/null )" ]
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

  fi

  # Internal flag for whether a directory was created
  local perm_dest_created=false

  # Check if destination path does not exist
  if ! [ -e "$perm_dest" ]; then

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

  # Print debug message
  if ! $quiet; then
    if [ -n "$name" ]; then
      dprint_debug "Attempting to clone/download $name from:" \
        -i "$repo_url" -n 'into:' -i "$perm_dest"
    else
      dprint_debug "Attempting to clone/download a Github repository from:" \
        -i "$repo_url" -n 'into:' -i "$perm_dest"
    fi
  fi

  # Internal marker for type of installation
  local repo_is_cloned_int

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
        repo_is_cloned_int=true
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
        repo_is_cloned_int=false
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
        repo_is_cloned_int=false
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

  # If set, modigy outer marker
  if ! [ -z ${repo_is_cloned+isset} ]; then
    repo_is_cloned="$repo_is_cloned_int"
  fi

  # If gotten here, all is good
  if ! $quiet; then
    local verb; $repo_is_cloned_int && verb=cloned || verb=downloaded
    if [ -n "$name" ]; then
      dprint_debug "Successfully $verb $name from:" \
        -i "$repo_url" -n 'into:' -i "$perm_dest"
    else
      dprint_debug "Successfully $verb a Github repository from:" \
        -i "$repo_url" -n 'into:' -i "$perm_dest"
    fi
  fi
  return 0
}

#>  d__gh_clone_check SRC DEST
#
## Implemented check primary that detects whether the Github repository at SRC 
#. appears to be cloned/downloaded into the DEST, and how does that correspond 
#. to current records in stash
#
d__gh_clone_check()
{
  # Rely on stashing
  dstash ready || return 3

  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift

  # Compose stashing data
  local stash_key="gh_$( dmd5 -s "${user_repo}___${perm_dest}" )"
  local stash_val="$perm_dest"
  local backup_path="$D__DPL_BACKUP_DIR/$stash_key"

  # Check if stash has a record
  if dstash -s has "$stash_key"; then

    ## Stash record exists and almost certainly with the right value (chance of 
    #. md5 checksum collision is negligible)
    #

    # Check if repo has been recorded as cloned or downloaded
    if [ "$( dstash -s get "status_$stash_key" )" = 'cloned' ]; then

      # Check if a cloned repository resides at the given path
      if d__check_if_dest_is_proper_clone; then

        # Recorded as clone, and destination is a proper clone: installed
        return 1

      else

        # Recorded as clone, but destination is not a proper clone

        # Print output based on current state of destination
        if [ -d "$perm_dest" ]; then
          dprint_alert \
            "Despite record of cloning Github repository $user_repo" \
            -n "into: $perm_dest" \
            -n 'that directory is currently not the clone'        
        else
          dprint_alert \
            "Despite record of cloning Github repository $user_repo" \
            -n "into: $perm_dest" \
            -n 'that path is currently not a directory'        
        fi

      fi
    
    else

      # Repository is recorded as downloaded

      # Check if destination is a non-empty dir
      if [ -d "$perm_dest" ]; then

        if [ -n "$( ls -A -- "$perm_dest" 2>/dev/null )" ]; then

          # Recorded as downloaded, but there is no way to tell
          dprint_alert \
            "Github repository $user_repo is recorded as downloaded" \
            -n "into: $perm_dest" \
            -n 'but there is no way to confirm it'
          D_DPL_NEEDS_ANOTHER_PROMPT=true
          return 1

        else

          # Recorded as downloaded, but directory is empty
          dprint_alert \
            "Despite record of downloading Github repository $user_repo" \
            -n "into: $perm_dest" \
            -n 'that directory is currently empty'

        fi

      else

        # Recorded as downloaded, but not a directory
        dprint_alert \
          "Despite record of downloading Github repository $user_repo" \
          -n "into: $perm_dest" \
          -n 'that path is currently not a directory'

      fi

    fi

    # At this point, something is not right

    # Check if forcing
    if $D__OPT_FORCE; then

      # In force mode, allow this with another prompt
      D_DPL_NEEDS_ANOTHER_PROMPT=true
      return 0

    else

      # In normal mode, inform of force option and mark irrelevant
      case $D__REQ_ROUTINE in
        check)    return 0;;
        install)  dprint_alert 'Retry with --force option to install anyway';;
        remove)   dprint_alert 'Retry with --force option to remove anyway';;
      esac
      return 3

    fi

  else

    # No stash record

    # Check if a cloned repository resides at the given path
    if d__check_if_dest_is_proper_clone; then

      # No record, but destination is a proper clone: installed by user or OS
      dprint_debug "No record of cloning Github repository $user_repo" \
        -n "into: $perm_dest" \
        -n 'but the directory is nevertheless a clone of that repository'
      D_DPL_INSTALLED_BY_USER_OR_OS=true
      return 1

    else

      # No record, and destination is not a proper clone

      # Print output based on current state of destination
      if [ -e "$perm_dest" ]; then
        if [ -d "$perm_dest"]; then
          dprint_alert "Cloning Github repository $user_repo" \
            -n "into: $perm_dest" \
            -n 'will overwrite the existing directory (it will be backed up)'
        else
          dprint_alert "Cloning Github repository $user_repo" \
            -n "into: $perm_dest" \
            -n 'will overwrite the existing file (it will be backed up)'
        fi
      fi

      D_DPL_NEEDS_ANOTHER_PROMPT=true
      return 2

    fi

  fi
}

#>  d__gh_clone_install SRC DEST
#
## Implemented install primary that entirely delegates to the helper
#
d__gh_clone_install() { d__ensure_gh_repo "$1" "$2"; }

#>  d__gh_clone_remove SRC DEST
#
## Implemented remove primary that entirely delegates to the helper
#
d__gh_clone_remove()
{
  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift

  # Compose stashing data
  local stash_key="gh_$( dmd5 -s "${user_repo}___${perm_dest}" )"
  local stash_val="$perm_dest"
  local backup_path="$D__DPL_BACKUP_DIR/$stash_key"

  # Check if stash has a record
  if dstash -s has "$stash_key"; then
    
    :

  else

    :

  fi
}

#>  d__validate_user_repo_and_compose_url
#
## INTERNAL USE ONLY
#
## IN:
#.  > $user_repo
#.  > $name
#
## OUT:
#.  < $repo_url
#.  < 1
#
d__validate_user_repo_and_compose_url()
{
  if [[ $user_repo =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then

    # Compose full repo url
    repo_url="https://github.com/$user_repo"

  else

    # Refuse to work with the argument
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Refusing to retrieve $name" )
    else
      failure_report+=( 'Refusing to retrieve a Github repository' )
    fi
    failure_report+=( -n "due to invalid repository handle: $user_repo'" )

    # Report and return failure
    dprint_failure "${failure_report[@]}"
    return 1

  fi
}

#>  d__check_and_canonicalize_dest_path
#
## INTERNAL USE ONLY
#
## IN:
#.  > $perm_dest
#.  > $repo_url
#.  > $name
#
## OUT:
#.  < $perm_dest
#.  < 1
#
d__check_and_canonicalize_dest_path()
{
  # Check if given destination path is empty
  if [ -z "$perm_dest" ]; then

    # Unacceptable: assemble failure report
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Refusing to retrieve $name from:" )
    else
      failure_report+=( 'Refusing to retrieve a Github repository from:' )
    fi
    failure_report+=( -i "$repo_url" -n 'because no destination is given' )

    # Report and return failure
    dprint_failure "${failure_report[@]}"
    return 1

  fi

  # Canonicalize destination path
  perm_dest="$( dreadlink -qm -- "$perm_dest" 2>/dev/null )"
}

#>  d__check_if_dest_is_proper_clone
#
## INTERNAL USE ONLY
#
## IN:
#.  > $perm_dest
#.  > $repo_url
#.  > $restricted
#.  > $name
#
## OUT:
#.  < 0 - quit out (success)
#.  < 1 - quit out (fail)
#.  < 2 - continue
#
d__pull_updates_from_remote()
{
  # Check if destination can be changed into and if it is a proper clone
  if d__check_if_dest_is_proper_clone; then

    # Fire debug message
    if [ "$restricted" = pull_only ]; then
      if [ -n "$name" ]; then
        dprint_debug "Pulling updates for $name from a Github repository:" \
          -i "$repo_url" -n 'into:' -i "$perm_dest"
      else
        dprint_debug "Pulling updates from a Github repository:" \
          -i "$repo_url" -n 'into:' -i "$perm_dest"
      fi
    else
      if [ -n "$name" ]; then
        dprint_debug "Detected that $name from:" \
          -i "$repo_url" -n 'is already cloned into:' -i "$perm_dest" \
          -n 'Proceeding to pull updates from remote'
      else
        dprint_debug "Detected that a Github repository from:" \
          -i "$repo_url" -n 'is already cloned into:' -i "$perm_dest" \
          -n 'Proceeding to pull updates from remote'
      fi
    fi

    # Pull from remote, minding the global verbosity setting
    if $D__OPT_QUIET; then

      # Pull and rebase quietly
      git pull --rebase --stat origin master &>/dev/null

    else

      # Pull and rebase normally, but re-paint output
      local line
      git pull --rebase --stat origin master 2>&1 \
        | while IFS= read -r line || [ -n "$line" ]; do
        printf "${CYAN}==> %s${NORMAL}\n" "$line"
      done

    fi

    # Check return status
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then

      # Assemble success report
      local success_report=()
      if [ -n "$name" ]; then
        success_report+=( "Successfully updated $name at:" )
      else
        success_report+=( 'Successfully updated the local copy at:' )
      fi
      success_report+=( \
        -i "$perm_dest" \
        -n 'from the remote Github repository:' \
        -i "$repo_url" \
      )

      # Report and return success
      dprint_debug "${success_report[@]}"
      return 0

    else

      # Failed to update

      # Check if restricted to updating
      if [ "$restricted" = pull_only ]; then

        # Unacceptable: assemble failure report
        local failure_report=()
        if [ -n "$name" ]; then
          failure_report+=( "Failed to update $name at:" )
        else
          failure_report+=( 'Failed to update the local copy at:' )
        fi
        failure_report+=( \
          -i "$perm_dest" \
          -n 'from the remote Github repository:' \
          -i "$repo_url" \
        )

        # Report and return failure
        dprint_failure "${failure_report[@]}"
        return 1

      fi

    fi

  else

    # Destination is not a proper clone

    # Check if restricted to updating
    if [ "$restricted" = pull_only ]; then

      # Go no further: assemble failure report
      local failure_report=()
      if [ -n "$name" ]; then
        failure_report+=( "Unable to update $name at:" )
      else
        failure_report+=( 'Unable to update the local directory at:' )
      fi
      failure_report+=( \
        -i "$perm_dest" \
        -n 'because it is not a clone of the expected Github repository:' \
        -i "$repo_url" \
      )

      # Report and return failure
      dprint_failure "${failure_report[@]}"
      return 1

    fi

  fi

  # Not updated, but not restricted either: continue
  return 2
}

#>  d__check_if_dest_is_proper_clone
#
## INTERNAL USE ONLY
#
## IN:
#.  > $perm_dest
#.  > $repo_url
#
## OUT:
#.  < 0/1
#
d__check_if_dest_is_proper_clone()
{
  # Check if destination can be changed into and if it is a proper clone
  if cd -- "$perm_dest" &>/dev/null \
    && [ "$( git remote get-url origin 2>/dev/null )" = "${repo_url}.git" ]
  then return 0; else return 1; fi
}