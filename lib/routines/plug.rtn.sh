#!/usr/bin/env bash
#:title:        Divine Bash routine: plug
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.06.26
#:revremark:    Initial revision
#:created_at:   2019.06.26

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Replaces current Grail directory with one cloned from provided git repo or 
#. one copied from provided directory path
#

#>  __perform_plug
#
## Performs plugging routine
#
## Returns:
#.  0 - Routine performed, Grail dir replaced
#.  1 - Otherwise
#
__perform_plug()
{
  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- '‘Plugging’ Grail directory'
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Plugging Grail directory'
  fi

  # Initialize global status variables
  GIT_AVAILABLE=true
  GITHUB_AVAILABLE=true

  # Unless just linking: check if git is available and offer to install it
  if ! $D__OPT_PLUG_LINK; then

    # Check if git is available
    if ! git --version &>/dev/null; then

      # Inform of the issue
      dprint_debug 'Failed to detect git' \
        -n 'Repository cloning will not be available'
      GIT_AVAILABLE=false

      # Check of curl/wget+tar are available (for downloading Github tarballs)
      if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
        dprint_debug 'Failed to detect neither curl nor wget' \
          -n 'Github repositories will not be available'
        GITHUB_AVAILABLE=false
      elif ! tar --version &>/dev/null; then
        dprint_debug 'Failed to detect tar' \
          -n 'Github repositories will not be available'
        GITHUB_AVAILABLE=false
      fi

    fi

  fi

  # Path to Grail replacement is first argument passed to the script
  local grail_arg="${D__REQ_ARGS[0]}"

  # Status variable
  local all_good=true

  if [ -n "$grail_arg" ]; then

    # Print newline as visual separator
    printf >&2 '\n'

    # Announce start
    dprint_ode "${D__ODE_NORMAL[@]}" -c "$YELLOW" -- \
      '>>>' 'Plugging' ':' "$grail_arg"

    # Process each argument sequentially until the first hit
    if $D__OPT_PLUG_LINK; then
      __plugging__attempt_local_dir "$grail_arg" \
        || all_good=false
    else
      __plugging__attempt_github_repo "$grail_arg" \
        || __plugging__attempt_local_repo "$grail_arg" \
        || __plugging__attempt_local_dir "$grail_arg" \
        || all_good=false
    fi
    
    # Report and set status
    if $all_good; then
      dprint_ode "${D__ODE_NORMAL[@]}" -c "$GREEN" -- \
        'vvv' 'Plugged' ':' "$grail_arg"
    else
      dprint_ode "${D__ODE_NORMAL[@]}" -c "$RED" -- \
        'xxx' 'Failed to plug' ':' "$grail_arg"
    fi

  else

    # Script’s first arg is empty
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" -- 'Nothing to do'
    return 1

  fi

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- '‘Plugged’ Grail directory'
    return 1
  elif $all_good; then
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Successfully plugged Grail directory'
    return 0
  else
    dprint_plaque -pcw "$RED" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Failed to plug Grail directory'
    return 1
  fi
}

#>  __plugging__attempt_github_repo
#
## Attempts to interpret single argument as name of Github repository and pull 
#. it in. Accepts only full ‘user/repo’ form.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
__plugging__attempt_github_repo()
{
  # In previously deteced that both git and tar are unavailable: skip
  $GITHUB_AVAILABLE || return 1

  # Extract argument
  local repo_arg="$1"

  # Storage variables
  local user_repo

  # Accept one pattern: ‘username/repo’
  if [[ $repo_arg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then
    user_repo="$repo_arg"
  else
    # Other patterns are not checked against Github
    dprint_debug "Not a valid Github repository handle: $repo_arg"
    return 1
  fi

  # Announce start
  dprint_debug 'Interpreting as Github repository'

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest="$D__DIR_GRAIL"

  # First, attempt to check existense of repository using git
  if $GIT_AVAILABLE; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Prompt user about the plug
      dprompt_key --bare --answer "$D__OPT_ANSWER" --prompt 'Clone it?' -- \
        "Detected ${BOLD}Github repository${NORMAL} at:" \
        -i "https://github.com/${user_repo}" || return 1

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

    # Not cloning repository, download instead

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Prompt user about the plug
      dprompt_key --bare --answer "$D__OPT_ANSWER" --prompt 'Download it?' \
        -- "Detected ${BOLD}Github repository${NORMAL} (tarball) at:" \
        -i "https://github.com/${user_repo}" || return 1

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

      # Prompt user about the plug
      dprompt_key --bare --answer "$D__OPT_ANSWER" --prompt 'Download it?' \
        -- "Detected ${BOLD}Github repository${NORMAL} (tarball) at:" \
        -i "https://github.com/${user_repo}" || return 1

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

  # Prompt user for possible clobbering, and clobber if required, run checks
  __plugging__run_checks_and_prompts "$perm_dest" "$temp_dest" \
    "https://github.com/${user_repo}" \
    || { rm -rf -- "$temp_dest"; return 1; }

  # Finally, move cloned repository to intended location
  mv -n -- "$temp_dest" "$perm_dest" || {
    # Announce failure to move
    dprint_debug 'Failed to move deployments from temporary location at:' \
      -i "$temp_dest" -n 'to intended location at:' -i "$perm_dest"
    # Try to clean up
    rm -rf -- "$temp_dest"
    # Return
    return 1
  }

  # Put dpl-repos directory to order
  if ! __sort_out_dpl_repos; then

    # Announce failure
    dprint_failure -l 'Failed to match deployment repositories at:' \
      -i "$D__DIR_DPL_REPOS" -n 'with newly plugged Grail directory'

  fi

  # Scan main directories for deployments
  __scan_for_dpl_files --fmwk-dir "$D__DIR_DPLS" "$D__DIR_DPL_REPOS"

  # Validate deployments
  if __validate_detected_dpls --fmwk-dir; then

    # Also, prepare any of the possible assets
    __process_all_asset_manifests_in_dpl_dirs

  else

    # Announce failure
    dprint_failure -l 'Illegal state of deployment directories'

  fi

  # All done: announce and return
  dprint_debug 'Successfully plugged Github-hosted Grail directory from:' \
    -i "https://github.com/${user_repo}" \
    -n 'to intended location at:' -i "$perm_dest"
  return 0
}

#>  __plugging__attempt_local_repo
#
## Attempts to interpret single argument as path to local git repository and 
#. pull it in. Accepts any resolvable path to directory containing git repo.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
__plugging__attempt_local_repo()
{
  # If it has been detected that git is unavailable: skip
  $GIT_AVAILABLE || return 1

  # Extract argument
  local repo_arg="$1"

  # Check if argument is a directory
  [ -d "$repo_arg" ] || return 1

  # Announce start
  dprint_debug 'Interpreting as local repository'

  # Construct full path to directory
  local repo_path="$( cd -- "$repo_arg" && pwd -P || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    dprint_debug 'Failed to access local repository at:' -i "$repo_path"
    return 1
  fi

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest="$D__DIR_GRAIL"

  # First, attempt to check existense of repository using git
  if git ls-remote "$repo_path" -q &>/dev/null; then

    # Both git and local repo are available

    # Prompt user about the plug
    dprompt_key --bare --answer "$D__OPT_ANSWER" --prompt 'Clone it?' -- \
      "Detected ${BOLD}local git repository${NORMAL} at:" -i "$repo_path" \
        || return 1

    # Make shallow clone of repository
    git clone --depth=1 "$repo_path" "$temp_dest" &>/dev/null \
      || {
        # Announce failure to clone
        dprint_debug 'Failed to clone repository at:' -i "$repo_path" \
          -n 'to temporary directory at:' -i "$temp_dest"
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Return
        return 1
      }
    
    # Prompt user for possible clobbering, and clobber if required, run checks
    __plugging__run_checks_and_prompts "$perm_dest" "$temp_dest" "$repo_path" \
      || { rm -rf -- "$temp_dest"; return 1; }

    # Finally, move cloned repository to intended location
    mv -n -- "$temp_dest" "$perm_dest" || {
      # Announce failure to move
      dprint_debug 'Failed to move deployments from temporary location at:' \
        -i "$temp_dest" -n 'to intended location at:' -i "$perm_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }

    # Put dpl-repos directory to order
    if ! __sort_out_dpl_repos; then

      # Announce failure
      dprint_failure -l 'Failed to match deployment repositories at:' \
        -i "$D__DIR_DPL_REPOS" -n 'with newly plugged Grail directory'

    fi

    # Scan main directories for deployments
    __scan_for_dpl_files --fmwk-dir "$D__DIR_DPLS" "$D__DIR_DPL_REPOS"

    # Validate deployments
    if __validate_detected_dpls --fmwk-dir; then

      # Also, prepare any of the possible assets
      __process_all_asset_manifests_in_dpl_dirs

    else

      # Announce failure
      dprint_failure -l 'Illegal state of deployment directories'
      
    fi

    # All done: announce and return
    dprint_debug \
      'Successfully plugged local git-controlled Grail directory from:' \
      -i "$repo_path" -n 'to intended location at:' -i "$perm_dest"
    return 0
    
  else

    # Directory is not a git repo
    dprint_debug 'Not a git repository at:' -i "$repo_path"
    return 1

  fi
}

#>  __plugging__attempt_local_dir
#
## Attempts to interpret single argument as path to local Grail directory and 
#. pull (or link) it in
#
## Returns:
#.  0 - Successfully pulled in deployment directory
#.  1 - Otherwise
#
__plugging__attempt_local_dir()
{
  # Extract argument
  local dir_arg="$1"

  # Check if argument is a directory
  [ -d "$dir_arg" ] || return 1

  # Announce start
  dprint_debug 'Interpreting as local directory'

  # Construct full path to directory
  local dir_path="$( cd -- "$dir_arg" && pwd -P || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    dprint_debug 'Failed to access local directory at:' -i "$dir_path"
    return 1
  fi

  # Construct permanent destination
  local perm_dest="$D__DIR_GRAIL"

  # Prompt user about the plug
  local prompt; $D__OPT_PLUG_LINK && prompt='Link it?' || prompt='Copy it?'
  dprompt_key --bare --answer "$D__OPT_ANSWER" --prompt "$prompt" -- \
    "Detected ${BOLD}local directory${NORMAL} at:" -i "$dir_path" \
      || return 1

  # Prompt user for possible clobbering, and clobber if required, run checks
  __plugging__run_checks_and_prompts "$perm_dest" "$dir_path" "$dir_path" \
    || return 1

  # Finally, link/copy directory to intended location
  if $D__OPT_PLUG_LINK; then
    dln -- "$dir_path" "$perm_dest" || {
      # Announce failure to link
      dprint_debug 'Failed to link local Grail directory at:' \
        -i "$dir_path" -n 'to intended location at:' -i "$perm_dest"
      # Return
      return 1
    }
  else
    cp -Rn -- "$dir_path" "$perm_dest" || {
      # Announce failure to copy
      dprint_debug 'Failed to copy local Grail directory at:' \
        -i "$dir_path" -n 'to intended location at:' -i "$perm_dest"
      # Return
      return 1
    }
  fi

  # Put dpl-repos directory to order
  if ! __sort_out_dpl_repos; then

    # Announce failure
    dprint_failure -l 'Failed to match deployment repositories at:' \
      -i "$D__DIR_DPL_REPOS" -n 'with newly plugged Grail directory'

  fi

  # Scan main directories for deployments
  __scan_for_dpl_files --fmwk-dir "$D__DIR_DPLS" "$D__DIR_DPL_REPOS"

  # Validate deployments
  if __validate_detected_dpls --fmwk-dir; then

    # Also, prepare any of the possible assets
    __process_all_asset_manifests_in_dpl_dirs

  else

    # Announce failure
    dprint_failure -l 'Illegal state of deployment directories'
    
  fi

  # Also, prepare any of the possible assets
  __process_all_asset_manifests_in_dpl_dirs

  # All done: announce and return
  dprint_debug 'Successfully plugged local Grail directory at:' \
    -i "$dir_path" -n 'to intended location at:' -i "$perm_dest"
  return 0
}

#>  __plugging__run_checks_and_prompts CLOBBER_PATH EXT_PATH SRC_ADDR
#
## Checks whether EXT_PATH contains any deployments, and whether those 
#. deployments are valid and merge-able
#
## Prompts user whether they indeed want to clobber (pre-erase) path that 
#. already exists. Given positive answer, proceeds with removal, and returns 
#. non-zero on failure.
#
## Returns:
#.  0 - Checks succeeded, user agreed
#.  1 - Otherwise
#
__plugging__run_checks_and_prompts()
{
  # Extract clobber path, external path, and source address
  local clobber_path="$1"; shift
  local ext_path="$1"; shift
  local src_addr="$1"; shift

  # Survey deployments in external dir
  __scan_for_dpl_files --ext-dir "$ext_path/dpls"

  # Check return code
  case $? in
    0)  # Some deployments collected: all good
        :;;
    1)  # Zero deployments detected in ext dir: this is normal, announce only
        dprint_debug \
          'No deployments detected in Grail directory obtained from:' \
          -i "$src_addr"
        ;;
    2)  # At least one deployment file has reserved delimiter in its path
        local list_of_illegal_dpls=() illegal_dpl
        for illegal_dpl in "${D__DPL_PATHS_WITH_DELIMITER[@]}"; do
          list_of_illegal_dpls+=( -i "$illegal_dpl" )
        done
        dprint_debug \
          "Illegal deployments detected at:" "${list_of_illegal_dpls[@]}" \
          -n "String '$D__CONST_DELIMITER' is reserved internal path delimiter"
        return 1
        ;;
    *)  # Unsopported code
        :;;
  esac
  
  # Check if external Grail directory contains valid deployments
  if ! __validate_detected_dpls --ext-dir "$ext_path/"; then

    # Prompt user
    if ! dprompt_key --bare --prompt 'Proceed?' --answer "$D__OPT_ANSWER" -- \
      'Grail directory obtained from:' -i "$src_addr" \
      -n 'contains invalid deployments (reserved or duplicate names)'
    then
      dprint_debug 'Refused to plug Grail directory with invalid deployments'
      return 1
    fi

  fi

  # Check if clobber path exists
  if [ -e "$clobber_path" ]; then

    # Detect type of existing entity
    local clobber_type
    [ -d "$clobber_path" ] && clobber_type='directory' || clobber_type='file'
    [ -L "$clobber_path" ] && clobber_type="symlinked $clobber_type"

    # Compose prompt description
    local prompt_desc=()

    # Warning about clobbering
    prompt_desc+=( "A $clobber_type already exists at:" -i "$clobber_path" )

    # Further warning for directories
    if [ -d "$clobber_path" ]; then

      # Warn about directories being erased, not merged
      prompt_desc+=( -n "${BOLD}${YELLOW}${REVERSE} Warning! ${NORMAL}" )
      prompt_desc+=( \
        'Directories are not merged. They are erased completely.' \
      )

      # Warn about reprecussions for user data
      if [ -L "$clobber_path" ]; then
        prompt_desc+=( \
          -n "${BOLD}Current Grail directory will be unlinked!${NORMAL}" \
        )
      else
        prompt_desc+=( \
          -n "${BOLD}Current Grail directory will be erased!${NORMAL}" \
        )
      fi

    fi

    if dprompt_key --bare --prompt 'Pre-erase?' --answer "$answer" -- \
      "${prompt_desc[@]}"; then

      # Attempt to remove pre-existing file/dir
      rm -rf -- "$clobber_path" || {
        dprint_debug "Failed to erase existing $clobber_type at:" \
          -i "$clobber_path"
        return 1
      }

      # Pre-erased successfully

    else

      # Refused to erase
      dprint_debug "Refused to erase existing $clobber_type at:" \
        -i "$clobber_path"
      return 1
    
    fi

  else

    # Path does not exist

    # Make sure parent path exists and is a directory though
    local parent_path="$( dirname -- "$clobber_path" )"
    if [ ! -d "$parent_path" ]; then
      mkdir -p -- "$parent_path" || {
        dprint_debug 'Failed to create destination directory at:' \
          -i "$parent_path"
        return 1
      }
    fi

    # All good
  
  fi

  # Finally, if made it here, return success
  return 0
}

__perform_plug