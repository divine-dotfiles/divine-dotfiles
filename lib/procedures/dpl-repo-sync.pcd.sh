#!/usr/bin/env bash
#:title:        Divine Bash procedure: dpl-repo-sync
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Remove revision numbers from all src files
#:created_at:   2019.06.28

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Ensures that records of attached deployment repositories are consistent with 
#. content of bundles directory
#

#>  d__sync_dpl_repos
#
## Synchronizes stash records of attached deployment repositories with actual 
#. content of bundles directory
#
## Returns:
#.  0 - bundles directory is consistent with records, or made so
#.  1 - Otherwise
#
d__sync_dpl_repos()
{
  # Storage variables
  local i recorded_user_repos=() recorded_user_repo user_repo
  local j actual_repo_dirs=() actual_repo_dir actual_repo_count
  local all_good=true

  # Load records of attached deployment repositories
  if d__stash -g -s has dpl_repos; then
    while read -r recorded_user_repo; do
      recorded_user_repos+=( "$recorded_user_repo" )
    done < <( d__stash -g -s list dpl_repos )
  fi

  # Load results of scanning repo directory
  if [ -r "$D__DIR_BUNDLES" -a -d "$D__DIR_BUNDLES" ]; then
    while IFS= read -r -d $'\0' actual_repo_dir; do
      actual_repo_dirs+=( "$actual_repo_dir" )
    done < <( find "$D__DIR_BUNDLES" -mindepth 2 -maxdepth 2 -type d -print0 )
  fi

  # Extract count of actual dirs
  actual_repo_count=${#actual_repo_dirs[@]}

  # Iterate over recorded repositories
  for (( i=0; i<${#recorded_user_repos[@]}; i++ )); do

    # Extract array member
    recorded_user_repo="${recorded_user_repos[$i]}"

    # Iterate over detected repo directories
    for (( j=0; j<$actual_repo_count; j++ )); do

      # Extract array member
      actual_repo_dir="${actual_repo_dirs[$j]}"

      # Check if current directory corresponds to current repo record
      [ "$D__DIR_BUNDLES/$recorded_user_repo" = "$actual_repo_dir" ] \
        || continue

      # Directory matched, remove it from further consideration
      unset actual_repo_dirs[$j]

      # Continue iteration on the outer loop
      continue 2

    # Done iterating over detected repo directories
    done

    # Recorded repo has no directory

    # Announce installation
    dprint_alert \
      "Installing missing deployments '$recorded_user_repo'"

    # Install and check status
    if ! d__sync_attach_dpl_repo "$recorded_user_repo"; then

      # Announce failure
      dprint_failure \
        "Failed to install missing deployments '$recorded_user_repo'"

      # Flip flag and continue
      all_good=false

    fi

  # Done iterating over recorded repositories
  done

  # Iterate over remaining detected repo directories
  for (( j=0; j<${#actual_repo_dirs[@]}; j++ )); do

    # Extract array member
    actual_repo_dir="${actual_repo_dirs[$j]}"

    # Compose user/repo
    user_repo="${actual_repo_dir#"$D__DIR_BUNDLES/"}"

    # Announce removal
    dprint_alert \
      "Removing unnecessary deployments '$user_repo'"

    # Remove that directory
    if ! d__sync_detach_dpl_repo "$user_repo"; then

      # Announce failure
      dprint_failure \
        "Failed to remove unnecessary deployments '$user_repo'"

      # Flip flag and continue
      all_good=false

    fi

  # Done iterating over remaining detected repo directories
  done

  # Return status
  $all_good && return 0 || return 1
}

#>  d__sync_attach_dpl_repo REPO
#
## Attempts to interpret single argument as name of Github repository and pull 
#. it in. Accepts either full 'user/repo' form or short 'built_in_repo' form 
#. for deployments distributed by author of Divine.dotfiles.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
d__sync_attach_dpl_repo()
{
  # Extract user/repo
  local user_repo="$1"; shift

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest="$D__DIR_BUNDLES/$user_repo"

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$temp_dest" &>/dev/null \
        || {
          # Announce failure to clone
          dprint_debug 'Failed to clone repository at:' \
            -i "https://github.com/${user_repo}" \
            -n 'to temporary directory at:' -i "$temp_dest"
          # Try to clean up
          rm -rf -- "$temp_dest"
          # Return
          return 1
        }

    else

      # Repo does not exist
      dprint_debug 'Non-existent repository at:' \
        -i "https://github.com/${user_repo}"
      return 1
    
    fi

  else

    # Git not available, download instead

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

      # Repo does not exist
      dprint_debug 'Non-existent repository at:' \
        -i "https://github.com/${user_repo}"
      return 1

    fi
  
  fi

  # Ensure parent directory of destination exists
  local perm_dest_parent="$( dirname -- "$perm_dest" )"
  if ! mkdir -p -- "$perm_dest_parent" &>/dev/null; then
    # Announce and return failure
    dprint_failure \
      'Failed to create a parent directory for missing deployments:' \
      -i "$perm_dest_parent"
    return 1
  fi

  # Finally, move cloned repository to intended location
  mv -n -- "$temp_dest" "$perm_dest" &>/dev/null || {
    # Announce failure to move
    dprint_debug 'Failed to move deployments from temporary location at:' \
      -i "$temp_dest" -n 'to intended location at:' -i "$perm_dest"
    # Try to clean up
    rm -rf -- "$temp_dest"
    # Return
    return 1
  }

  # All done: announce and return
  dprint_debug 'Successfully attached Github-hosted deployments from:' \
    -i "https://github.com/${user_repo}" \
    -n 'to intended location at:' -i "$perm_dest"
  return 0
}

#>  d__sync_detach_dpl_repo REPO
#
## Attempts to interpret single argument as name of Github repository and 
#. detach it. Accepts either full 'user/repo' form or short 'built_in_repo' 
#. form for deployments distributed by author of Divine.dotfiles.
#
## Returns:
#.  0 - Successfully detached deployment repository
#.  1 - Otherwise
#
d__sync_detach_dpl_repo()
{
  # Extract argument
  local user_repo="$1"

  # Construct permanent destination
  local perm_dest="$D__DIR_BUNDLES/$user_repo"

  # Check if that path exists
  if [ -e "$perm_dest" ]; then

    # Check if it is a directory
    if [ -d "$perm_dest" ]; then

      # Attempt to remove it
      if rm -rf -- "$perm_dest"; then

        dprint_debug 'Removed directory of cloned repository at:' \
          -i "$perm_dest"

      else

        # Failed to remove: report and return error
        dprint_debug 'Failed to remove directory of cloned repository at:' \
          -i "$perm_dest"
        return 1

      fi

    else

      # Path exists, but is not a directory
      dprint_debug 'Path to cloned repository is not a directory:' \
        -i "$perm_dest"
      return 1

    fi

  else

    # Path does not exist
    dprint_debug 'Path to cloned repository does not exist:' -i "$perm_dest"

  fi

  # All done: announce and return
  dprint_debug 'Successfully detached Github-hosted deployments from:' \
    -i "https://github.com/${user_repo}" \
    -n 'at their location:' -i "$perm_dest"
  return 0
}