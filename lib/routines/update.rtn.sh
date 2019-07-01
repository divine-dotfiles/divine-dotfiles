#!/usr/bin/env bash
#:title:        Divine Bash routine: update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.14
#:revremark:    Initial revision
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Updates Divine.dotfiles framework, attached deployment repositories, and 
#. Grail directory itself if it is a cloned repository
#

#>  __updating__main
#
## Performs updating routine
#
## If framework directory is a cloned repository, pulls from remote and 
#. rebases. Otherwise, re-downloads from Github to temp dir and overwrites 
#. files one by one.
#
## Returns:
#.  0 - Successfully updated tasks
#.  1 - Failed to update some of the tasks
#.  2 - Skipped routine entirely
#
__updating__main()
{
  # Make sure dpl-repos are in order
  __sort_out_dpl_repos || exit 1
  
  # Announce beginning
  if [ "$D_OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_CONST_PLAQUE_WIDTH" \
      -- '‘Updating’ Divine.dotfiles framework'
  else
    dprint_plaque -pcw "$GREEN" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Updating Divine.dotfiles framework'
  fi

  # Status variables
  local all_updated=true all_failed=true all_skipped=true some_failed=false

  # Analyze environment and populate global status variables
  __updating__detect_environment

  # Update framework and analyze return status
  __updating__update_fmwk; case $? in
    0)  all_failed=false; all_skipped=false;;
    1)  all_updated=false; all_skipped=false; some_failed=true;;
    2)  all_updated=false; all_failed=false;;
  esac

  # Update Grail directory and analyze return status
  __updating__update_grail; case $? in
    0)  all_failed=false; all_skipped=false;;
    1)  all_updated=false; all_skipped=false; some_failed=true;;
    2)  all_updated=false; all_failed=false;;
  esac

  # Update attached deployment repositories and analyze return status
  __updating__update_dpls; case $? in
    0)  all_failed=false; all_skipped=false;;
    1)  all_updated=false; all_skipped=false
        all_failed=false; some_failed=true;;
    2)  all_updated=false; all_skipped=false; some_failed=true;;
    3)  all_updated=false; all_failed=false;;
  esac

  # Print newline to visually separate terminal plaque
  printf >&2 '\n'

  # Report result
  if [ "$D_OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Finished ‘updating’ Divine.dotfiles framework'
    return 2
  elif $all_skipped; then
    dprint_plaque -pcw "$WHITE" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Skipped updating Divine.dotfiles framework'
    return 2
  elif $all_updated; then
    dprint_plaque -pcw "$GREEN" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Finished updating Divine.dotfiles framework'
    return 0
  elif $all_failed; then
    dprint_plaque -pcw "$RED" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Failed to update Divine.dotfiles framework'
    return 1
  elif $some_failed; then
    dprint_plaque -pcw "$YELLOW" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Partly updated Divine.dotfiles framework'
    return 1
  else
    dprint_plaque -pcw "$GREEN" "$D_CONST_PLAQUE_WIDTH" \
      -- 'Finished updating Divine.dotfiles framework'
    return 0
  fi
}

#>  __updating__update_fmwk
#
## Attempts to update framework by means available
#
## Returns:
#.  0 - Updated successfully
#.  1 - Failed to update
#.  2 - Skipped completely, e.g., not requested
#
__updating__update_fmwk()
{
  # Print newline to visually separate updates
  printf >&2 '\n'

  # Check if updating at all
  if $UPDATING_FMWK; then

    # Print announcement
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$YELLOW" -- \
      '>>>' 'Updating' ':' 'Divine.dotfiles framework'

    # Prompt user
    if [ "$D_OPT_ANSWER" = true ]; then UPDATING_FMWK=true
    elif [ "$D_OPT_ANSWER" = false ]; then UPDATING_FMWK=false
    else
      # Prompt
      dprint_ode "${D_ODE_PROMPT[@]}" -- '' 'Confirm' ': '
      dprompt_key --bare && UPDATING_FMWK=true || UPDATING_FMWK=false
    fi

  fi

  # Check if still updating at this point
  if ! $UPDATING_FMWK; then
    # Announce skiping and return
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$WHITE" -- \
      '---' 'Skipped updating' ':' 'Divine.dotfiles framework'
    return 2
  fi

  # Status variable
  local updated_successfully=false

  # If github is not available, no updating
  if ! $GITHUB_AVAILABLE; then
    dprint_debug 'Unable to update: missing necessary tools'
  elif ! [ -d "$D_DIR_FMWK" -a -r "$D_DIR_FMWK" ]; then
    dprint_debug "Not a readable directory: $D_DIR_FMWK"
  else
    # Do update proper, one way or another
    if __updating__update_fmwk_via_git || __updating__update_fmwk_via_tar
    then
      updated_successfully=true
    fi
  fi

  # Report result
  if $updated_successfully; then
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$GREEN" -- \
      'vvv' 'Updated' ':' 'Divine.dotfiles framework'
    return 0
  else
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$RED" -- \
      'xxx' 'Failed to update' ':' 'Divine.dotfiles framework'
    return 1
  fi
}

#>  __updating__update_grail
#
## Attempts to update Grail directory by means available
#
## Returns:
#.  0 - Updated successfully
#.  1 - Failed to update
#.  2 - Skipped completely, e.g., not requested
#
__updating__update_grail()
{
  # Print newline to visually separate updates
  printf >&2 '\n'

  # Check if git is available (its the only means of Grail dir update)
  $GIT_AVAILABLE || UPDATING_GRAIL=false

  if $UPDATING_GRAIL; then

    # Check if Grail directory is a repository at all
    if git ls-remote "$D_DIR_GRAIL" -q &>/dev/null; then

      # Change into $D_DIR_GRAIL
      cd -- "$D_DIR_GRAIL" || {
        dprint_debug "Unable to cd into $D_DIR_GRAIL"
        return 1
      }

      # Check if Grail repository has ‘origin’ remote
      if ! git remote | grep -Fxq origin &>/dev/null; then

        # Repository without remote: no way to update
        dprint_debug 'Grail repository does not have a remote to pull from:' \
          -i "$D_DIR_GRAIL"
        UPDATING_GRAIL=false

      fi

    else

      # Not a repository: no way to update
      dprint_debug 'Grail directory is not a git repository:' \
        -i "$D_DIR_GRAIL"
      UPDATING_GRAIL=false

    fi

  fi

  if $UPDATING_GRAIL; then

    # Print announcement
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$YELLOW" -- \
      '>>>' 'Updating' ':' 'Grail directory'

    # Prompt user
    if [ "$D_OPT_ANSWER" = true ]; then UPDATING_GRAIL=true
    elif [ "$D_OPT_ANSWER" = false ]; then UPDATING_GRAIL=false
    else
      # Prompt
      dprint_ode "${D_ODE_PROMPT[@]}" -- '' 'Confirm' ': '
      dprompt_key --bare && UPDATING_GRAIL=true || UPDATING_GRAIL=false
    fi

  fi

  # Check if still updating at this point
  if ! $UPDATING_GRAIL; then
    # Announce skiping and return
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$WHITE" -- \
      '---' 'Skipped updating' ':' 'Grail directory'
    return 2
  fi

  # Do update proper and check result
  if __updating__update_grail_via_git; then
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$GREEN" -- \
      'vvv' 'Updated' ':' 'Grail directory'
    return 0
  else
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$RED" -- \
      'xxx' 'Failed to update' ':' 'Grail directory'
    return 1
  fi
}

#>  __updating__update_dpls
#
## Attempts to update attached deployment repositories by means available
#
## Returns:
#.  0 - Successfully updated all recorded repositories
#.  1 - Failed to update at least one repository
#.  2 - Failed to update all repositories
#.  3 - Skipped completely, e.g., not requested or nothing to do
#
__updating__update_dpls()
{
  # Storage and status variables
  local all_updated=true all_failed=true all_skipped=true some_failed=false
  local dpl_repo_dir dpl_repo dpl_repos=() proceeding nl_printed=false

  # Print newline to visually separate updates
  printf >&2 '\n' && nl_printed=true

  # Check if grail stash is available (required for deployment repositories)
  if $UPDATING_DPLS && ! dstash --grail ready; then
    # No deployment updates for you
    dprint_debug 'Grail stash is not available: no deployment updates'
    UPDATING_DPLS=false
  fi

  # Check if proceeding
  if $UPDATING_DPLS; then

    # Populate list of repos
    if dstash -g -s has dpl_repos; then
      while read -r dpl_repo; do
        dpl_repos+=( "$dpl_repo" )
      done < <( dstash -g -s list dpl_repos )
    fi

    # Check if list is empty
    [ ${#dpl_repos[@]} -eq 0 ] && {
      dprint_debug 'No deployment repositories recorded in Grail stash'
      UPDATING_DPLS=false
    }

  fi

  # Check if proceeding
  if ! $UPDATING_DPLS; then
    # Announce skiping and return
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$WHITE" -- \
      '---' 'Skipped updating' ':' 'Attached deployments'
    return 3
  fi

  # Iterate over list of cloned deployment repositories from Grail stash
  for dpl_repo in "${dpl_repos[@]}"; do

    # Print newline to visually separate updates
    $nl_printed || printf >&2 '\n'

    # Print announcement
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$YELLOW" -- \
      '>>>' 'Updating' ':' "Dpls repo '$dpl_repo'"
    nl_printed=false

    # Prompt user
    if [ "$D_OPT_ANSWER" = true ]; then proceeding=true
    elif [ "$D_OPT_ANSWER" = false ]; then proceeding=false
    else
      # Prompt
      dprint_ode "${D_ODE_PROMPT[@]}" -- '' 'Confirm' ': '
      dprompt_key --bare && proceeding=true || proceeding=false
    fi

    # Check if still updating at this point
    if ! $proceeding; then
      # Announce and skip
      dprint_ode "${D_ODE_NORMAL[@]}" -c "$WHITE" -- \
        '---' 'Skipped updating' ':' "Dpls repo '$dpl_repo'"
      all_updated=false
      all_failed=false
      continue
    fi

    # If github is not available, no updating
    if ! $GITHUB_AVAILABLE; then
      dprint_debug 'Unable to update: missing necessary tools'
    else
      # Do update proper
      if __updating__update_dpl_repo_via_git "$D_DIR_DPL_REPOS/$dpl_repo" \
        || __updating__update_dpl_repo_via_tar "$dpl_repo"
      then
        dprint_ode "${D_ODE_NORMAL[@]}" -c "$GREEN" -- \
          'vvv' 'Updated' ':' "Dpls repo '$dpl_repo'"
        all_failed=false
        all_skipped=false
        continue
      fi
    fi

    # If gotten here: not updated
    dprint_ode "${D_ODE_NORMAL[@]}" -c "$RED" -- \
      'xxx' 'Failed to update' ':' "Dpls repo '$dpl_repo'"
    all_updated=false
    all_skipped=false
    some_failed=true
    
  done

  # Report
  if $all_updated; then return 0
  elif $all_skipped; then return 3
  elif $all_failed; then return 2
  elif $some_failed; then 1
  else return 0; fi
}

#>  __updating__detect_environment
#
## Analyzes current system environment and fills relevant global variables
#
## Returns:
#.  0 - Always
#
__updating__detect_environment()
{
  # Initialize global status variables
  UPDATING_FMWK=false
  UPDATING_DPLS=false
  UPDATING_GRAIL=false
  GIT_AVAILABLE=true
  GITHUB_AVAILABLE=true

  # Check if there are any arguments provided to the script
  if [ "$D_OPT_ANSWER" = false ]; then

    # Updating nothing
    UPDATING_FMWK=false
    UPDATING_DPLS=false
    UPDATING_GRAIL=false

  elif [ ${#D_REQ_ARGS[@]} -eq 0 ]; then
    
    # No arguments: update everything
    UPDATING_FMWK=true
    UPDATING_DPLS=true
    UPDATING_GRAIL=true

  else

    # Iterate over arguments to figure out what to update
    local arg
    for arg in "${D_REQ_ARGS[@]}"; do
      case $arg in
        a|all)                    UPDATING_FMWK=true
                                  UPDATING_DPLS=true
                                  UPDATING_GRAIL=true;;
        f|fmwk|framework)         UPDATING_FMWK=true;;
        d|dpl|dpls|deployments)   UPDATING_DPLS=true;;
        g|grail)                  UPDATING_GRAIL=true;;
        *)                        :;;
      esac
    done

  fi

  # Check if necessary tools are available and offer to install them
  if ! __updating__check_or_install git; then

    # Inform of the issue
    dprint_debug 'Updates via git pull will not be available'
    GIT_AVAILABLE=false

    # Check of curl/wget+tar are available (for downloading Github tarballs)
    if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
      dprint_debug 'Neither curl nor wget is detected'
      dprint_debug \
        "'Crude' updates via re-downloading Github repo will not be available"
      GITHUB_AVAILABLE=false
    elif ! __updating__check_or_install tar; then
      dprint_debug \
        "'Crude' updates via re-downloading Github repo will not be available"
      GITHUB_AVAILABLE=false
    fi
  fi

  return 0
}

#>  __updating__update_fmwk_via_git
#
## Tries to pull & rebase from remote Github repo
#
## Returns:
#.  0 - Successfully updated
#.  1 - Otherwise
#
__updating__update_fmwk_via_git()
{
  # Check if git has been previously detected as unavailable
  $GIT_AVAILABLE || {
    dprint_debug 'Unable to update via git'
    return 1
  }

  # Ensure $D_DIR_FMWK is a git repo
  git ls-remote "$D_DIR_FMWK" -q &>/dev/null || {
    dprint_debug 'Not a git repository:' -i "$D_DIR_FMWK"
    return 1
  }

  # Change into $D_DIR_FMWK
  cd -- "$D_DIR_FMWK" || {
    dprint_debug "Unable to cd into $D_DIR_FMWK"
    return 1
  }

  # Pull and rebase and check for errors
  if git pull --rebase --stat origin master; then
    dprint_debug 'Successfully pulled from Github repo to:' \
      -i "$D_DIR_FMWK"
    return 0
  else
    dprint_debug 'There was an error while pulling from Github repo to:' \
      -i "$D_DIR_FMWK"
    return 1
  fi
}

#>  __updating__update_grail_via_git
#
## Tries to pull & rebase from remote git repo
#
## Returns:
#.  0 - Successfully updated
#.  1 - Otherwise
#
__updating__update_grail_via_git()
{
  # Change into $D_DIR_GRAIL
  cd -- "$D_DIR_GRAIL" || {
    dprint_debug "Unable to cd into $D_DIR_GRAIL"
    return 1
  }

  # Pull and rebase and check for errors
  if git pull --rebase --stat origin master; then
    dprint_debug 'Successfully pulled from remote to:' \
      -i "$D_DIR_GRAIL"
    return 0
  else
    dprint_debug 'There was an error while pulling from remote to:' \
      -i "$D_DIR_GRAIL"
    return 1
  fi
}

#>  __updating__update_fmwk_via_tar
#
## Prompts, then tries to download Github tarball and extract it over existing 
#. files
#
## Returns:
#.  0 - Successfully updated
#.  1 - Otherwise
#
__updating__update_fmwk_via_tar()
{
  # Only attempt ‘crude’ update with --force option
  if ! $D_OPT_FORCE; then
    dprint_debug \
      "'Crude' update (downloading repo) is only available with --force option"
    return 1
  fi

  # Set user/repository to download from
  local user_repo='no-simpler/divine-dotfiles'

  # Compose temporary destination directory
  local temp_dest="$( mktemp -d )"

  # Prompt user
  if ! dprompt_key --bare -p 'Attempt to download?' -a "$D_OPT_ANSWER" -- \
    'It is possible to download a fresh copy of Divine.dotfiles from:' \
    -i "https://github.com/${user_repo}" \
    -n 'and overwrite files in your framework directory at:' -i "$D_DIR_FMWK" \
    -n 'thus performing a ‘crude’ update'
  then
    dprint_debug 'Refused to perform ‘crude’ update'
    return 1
  fi

  # Attempt curl and Github API
  if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
    2>/dev/null | head -1 ); then

    # Both curl and remote repo are available

    # Download and untar in one fell swoop
    curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
      | tar --strip-components=1 -C "$temp_dest" -xzf -
    
    # Check status
    [ $? -eq 0 ] || {
      # Announce failure to download
      dprint_debug \
        'Failed to download (curl) or extract tarball repository at:' \
        -i "https://api.github.com/repos/${user_repo}/tarball" \
        -n 'to temporary directory at:' -i "$temp_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }
  
  # Attempt wget and Github API
  elif grep -q 200 < <( wget -q --spider --server-response \
    "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

    # Both wget and remote repo are available

    # Download and untar in one fell swoop
    wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
      | tar --strip-components=1 -C "$temp_dest" -xzf -
    
    # Check status
    [ $? -eq 0 ] || {
      # Announce failure to download
      dprint_debug \
        'Failed to download (wget) or extract tarball repository at:' \
        -i "https://api.github.com/repos/${user_repo}/tarball" \
        -n 'to temporary directory at:' -i "$temp_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }
    
  else

    # Repository is inaccessible
    dprint_debug 'Unable to access repository at:' \
      -i "https://github.com/${user_repo}"
    return 1

  fi

  # Prompt user for possible clobbering, and clobber if required
  if ! dprompt_key --bare -p 'Overwrite files?' -a "$D_OPT_ANSWER" -- \
    'Fresh copy of Divine.dotfiles has been downloaded to temp dir at:' \
    -i "$temp_dest" \
    -n 'and is ready to be copied over existing files in:' -i "$D_DIR_FMWK"
  then
    # Try to clean up
    rm -rf -- "$temp_dest"
    # Report and return
    dprint_debug 'Refused to perform ‘crude’ update'
    return 1
  fi

  # Make sure directory exists
  mkdir -p -- "$D_DIR_FMWK" || {
    # Try to clean up
    rm -rf -- "$temp_dest"
    # Report and return
    dprint_debug "Failed to create destination directory at:" \
      -i "$D_DIR_FMWK"
    return 1
  }
  
  # Storage variables
  local src_path rel_path tgt_path

  # Copy files and directories at root level
  while IFS= read -r -d $'\0' src_path; do

    # Extract relative path
    rel_path="${src_path#"$temp_dest/"}"

    # Construct target path
    tgt_path="$D_DIR_FMWK/$rel_path"

    # Pre-erase existing file
    if [ -e "$tgt_path" ]; then
      rm -rf -- "$tgt_path" || {
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Report and return
        dprint_debug "Failed to overwrite existing file '$rel_path' at:" \
          -i "$tgt_path"
        return 1
      }
    fi

    # Move new file
    mv -n -- "$src_path" "$tgt_path" || {
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Report and return
      dprint_debug "Failed to move file '$rel_path' from:" \
          -i "$src_path" -n 'to:' -i "$tgt_path"
      return 1
    }

  done < <( find "$temp_dest" -mindepth 1 -maxdepth 1 \
    \( -type f -or -type d \) -print0 )

  # Clean up
  rm -rf -- "$temp_dest"

  # All done: announce and return
  dprint_debug \
    'Successfully overwritten all Divine.dotfiles components at:' \
    -i "$D_DIR_FMWK"
  return 0
}

#>  __updating__update_dpl_repo_via_git PATH
#
## Tries to pull & rebase from remote Github repo
#
## Returns:
#.  0 - Successfully updated
#.  1 - Otherwise
#
__updating__update_dpl_repo_via_git()
{
  # Check if git has been previously detected as unavailable
  $GIT_AVAILABLE || {
    dprint_debug 'Unable to update via git'
    return 1
  }

  # Extract path to repository being updated
  local repo_path="$1"; shift

  # Ensure $D_DIR_FMWK is a git repo
  git ls-remote "$repo_path" -q &>/dev/null || {
    dprint_debug 'Not a git repository:' -i "$repo_path"
    return 1
  }

  # Change into $repo_path
  cd -- "$repo_path" || {
    dprint_debug "Unable to cd into $repo_path"
    return 1
  }

  # Pull and rebase and check for errors
  if git pull --rebase --stat origin master; then
    dprint_debug 'Successfully pulled from remote repo to:' \
      -i "$repo_path"
    return 0
  else
    dprint_debug 'There was an error while pulling from remote repo to:' \
      -i "$repo_path"
    return 1
  fi
}

#>  __updating__update_dpl_repo_via_tar USER_REPO
#
## Prompts, then tries to download Github tarball and extract it over existing 
#. files
#
## Returns:
#.  0 - Successfully updated
#.  1 - Otherwise
#
__updating__update_dpl_repo_via_tar()
{
  # Only attempt ‘crude’ update with --force option
  if ! $D_OPT_FORCE; then
    dprint_debug \
      "'Crude' update (downloading repo) is only available with --force option"
    return 1
  fi

  # Set user/repository to download from
  local user_repo="$1"; shift

  # Compose temporary destination directory
  local temp_dest="$( mktemp -d )"

  # Compose permanent destination directory
  local perm_dest="$D_DIR_DPL_REPOS/$user_repo"

  # Prompt user
  if ! dprompt_key --bare -p 'Attempt to download?' -a "$D_OPT_ANSWER" -- \
    'It is possible to download a fresh copy of deployments from:' \
    -i "https://github.com/${user_repo}" \
    -n 'and overwrite files in your directory at:' -i "$perm_dest" \
    -n 'thus performing a ‘crude’ update'
  then
    dprint_debug 'Refused to perform ‘crude’ update'
    return 1
  fi

  # Attempt curl and Github API
  if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
    2>/dev/null | head -1 ); then

    # Both curl and remote repo are available

    # Download and untar in one fell swoop
    curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
      | tar --strip-components=1 -C "$temp_dest" -xzf -
    
    # Check status
    [ $? -eq 0 ] || {
      # Announce failure to download
      dprint_debug \
        'Failed to download (curl) or extract tarball repository at:' \
        -i "https://api.github.com/repos/${user_repo}/tarball" \
        -n 'to temporary directory at:' -i "$temp_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }
  
  # Attempt wget and Github API
  elif grep -q 200 < <( wget -q --spider --server-response \
    "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

    # Both wget and remote repo are available

    # Download and untar in one fell swoop
    wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
      | tar --strip-components=1 -C "$temp_dest" -xzf -
    
    # Check status
    [ $? -eq 0 ] || {
      # Announce failure to download
      dprint_debug \
        'Failed to download (wget) or extract tarball repository at:' \
        -i "https://api.github.com/repos/${user_repo}/tarball" \
        -n 'to temporary directory at:' -i "$temp_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }
    
  else

    # Repository is inaccessible
    dprint_debug 'Unable to access repository at:' \
      -i "https://github.com/${user_repo}"
    return 1

  fi

  # Prompt user for possible clobbering, and clobber if required
  if ! dprompt_key --bare -p 'Overwrite files?' -a "$D_OPT_ANSWER" -- \
    'Fresh copy of repository has been downloaded to temp dir at:' \
    -i "$temp_dest" \
    -n 'and is ready to be copied over existing files in:' -i "$perm_dest"
  then
    # Try to clean up
    rm -rf -- "$temp_dest"
    # Report and return
    dprint_debug 'Refused to perform ‘crude’ update'
    return 1
  fi

  # Make sure directory exists
  mkdir -p -- "$D_DIR_DPL_REPOS/$user_repo" || {
    # Try to clean up
    rm -rf -- "$temp_dest"
    # Report and return
    dprint_debug "Failed to create destination directory at:" \
      -i "$D_DIR_DPL_REPOS/$user_repo"
    return 1
  }

  # Storage variables
  local src_path rel_path tgt_path

  # Copy files and directories at root level
  while IFS= read -r -d $'\0' src_path; do

    # Extract relative path
    rel_path="${src_path#"$temp_dest/"}"

    # Construct target path
    tgt_path="$D_DIR_DPL_REPOS/$user_repo/$rel_path"

    # Pre-erase existing file
    if [ -e "$tgt_path" ]; then
      rm -rf -- "$tgt_path" || {
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Report and return
        dprint_debug "Failed to overwrite existing file '$rel_path' at:" \
          -i "$tgt_path"
        return 1
      }
    fi

    # Move new file
    mv -n -- "$src_path" "$tgt_path" || {
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Report and return
      dprint_debug "Failed to move file '$rel_path' from:" \
          -i "$src_path" -n 'to:' -i "$tgt_path"
      return 1
    }

  done < <( find "$temp_dest" -mindepth 1 -maxdepth 1 \
    \( -type f -or -type d \) -print0 )

  # Clean up
  rm -rf -- "$temp_dest"

  # All done: announce and return
  dprint_debug \
    'Successfully overwritten all deployment files at:' \
    -i "$D_DIR_DPL_REPOS/$user_repo"
  return 0
}

#>  __updating__check_or_install UTIL_NAME
#
## Checks whether UTIL_NAME is available and, if not, offers to install it 
#. using system’s package manager, if it is available
#
## Returns:
#.  0 - UTIL_NAME is available or successfully installed
#.  1 - UTIL_NAME is not available or failed to install
#
__updating__check_or_install()
{
  # Extract util name
  local util_name="$1"

  # If command by that name is available on $PATH, return zero immediately
  case $util_name in
    git)  git --version &>/dev/null;;
    tar)  tar --version &>/dev/null;;
  esac
  [ $? -eq 0 ] && return 0

  # Print initial warning
  dprint_debug "Failed to detect $util_name executable"

  # Check if $OS_PKGMGR is detected
  if [ -z ${OS_PKGMGR+isset} ]; then

    # No option to install: report and return
    dprint_debug \
      "Unable to auto-install $util_name (no supported package manager)"
    return 1
  
  else

    # Prompt user for whether to install utility
    if dprompt_key --bare --answer "$D_OPT_ANSWER" \
      "Package manager $OS_PKGMGR is available" \
      --prompt "Install $util_name using $OS_PKGMGR?"
    then

      # Announce installation
      dprint_debug "Installing $util_name"

      # Attempt installation
      os_pkgmgr dinstall "$util_name"

      # Check status code of installation
      if [ $? -eq 0 ]; then
        dprint_debug "Successfully installed $util_name"
        return 0
      else
        dprint_debug "Failed to install $util_name"
        return 1
      fi

    else

      # Announce refusal to install and return
      dprint_debug "Proceeding without $util_name"
      return 1

    fi

  fi
}

__updating__main