#!/usr/bin/env bash
#:title:        Divine Bash routine: add
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.12
#:revremark:    Initial revision
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Adds deployments by either cloning, downloading, copying, or symlinking them 
#. into the deployments directory
#

#>  __perform_add
#
## Performs addition routine
#
## Returns:
#.  0 - Routine performed, all arguments added successfully
#.  1 - Routine performed, only some arguments added successfully
#.  2 - Routine performed, none of the arguments added
#.  3 - Routine terminated with nothing to do
#
__perform_add()
{
  # Announce beginning
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- '‘Adding’ deployments'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Adding deployments'
  fi

  # Initialize global status variables
  NO_GIT=false
  NO_GITHUB=false

  # Unless just linking: check if git is available and offer to install it
  if ! $D_ADD_LINK; then

    # Check if git is available (possibly install it)
    if ! __adding__check_or_install git; then

      # Inform of the issue
      dprint_debug 'Repository cloning will not be available'
      NO_GIT=true

      # Check of curl/wget are available (for downloading Github tarballs)
      if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
        dprint_debug 'Neither curl nor wget is detected'
        dprint_debug 'Github repositories will not be available'
        NO_GITHUB=true
      fi

      # Check if tar is available (for extracting Github tarballs)
      if ! __adding__check_or_install tar; then
        dprint_debug 'Github repositories will not be available'
        NO_GITHUB=true
      fi

    fi

  fi

  # Ensure root stashing is available, but make do without it as well
  dstash --root ready || {
    dprint_debug 'Root stash is not available' \
      -n 'Cloned repositories will not be registered for auto-updates'
  }

  # Storage & status variables
  local dpl_arg
  local arg_success
  local added_anything=false errors_encountered=false

  # Iterate over script arguments
  for dpl_arg in "${D_ARGS[@]}"; do

    # Set default status
    arg_success=true

    # Print newline to visually separate additions
    printf >&2 '\n'

    # Announce start
    dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
      '>>>' 'Processing' ':' "$dpl_arg"

    # Process each argument sequentially until the first hit
    if $D_ADD_LINK; then
      __adding__attempt_local_dir "$dpl_arg" \
        || __adding__attempt_local_file "$dpl_arg" \
        || arg_success=false
    else
      __adding__attempt_github_repo "$dpl_arg" \
        || __adding__attempt_local_repo "$dpl_arg" \
        || __adding__attempt_local_dir "$dpl_arg" \
        || __adding__attempt_local_file "$dpl_arg" \
        || arg_success=false
    fi
    
    # Report and set status
    if $arg_success; then
      added_anything=true
      dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$GREEN" -- \
        'vvv' 'Success' ':' "$dpl_arg"
    else
      errors_encountered=true
      dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$RED" -- \
        'xxx' 'Failed' ':' "$dpl_arg"
    fi

  done

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Finished ‘adding’ deployments'
    return 3
  elif $added_anything; then
    if $errors_encountered; then
      dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
        -- 'Successfully added some deployments'
      return 1
    else
      dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
        -- 'Successfully added all deployments'
      return 0
    fi
  else
    if $errors_encountered; then
      dprint_plaque -pcw "$RED" "$D_PLAQUE_WIDTH" \
        -- 'Failed to add deployments'
      return 2
    else
      dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
        -- 'Nothing to do'
      return 3
    fi
  fi
}

#>  __adding__attempt_github_repo
#
## Attempts to interpret single argument as name of Github repository and pull 
#. it in. Accepts either full ‘user/repo’ form or short ‘built_in_repo’ form 
#. for deployments distributed by author of Divine.dotfiles.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
__adding__attempt_github_repo()
{
  # In previously deteced that both git and tar are unavailable: skip
  $NO_GITHUB && return 1

  # Extract argument
  local repo_arg="$1"

  # Storage variables
  local user_repo is_builtin=false temp_ready=false cloned_repo=false

  # Accept one of two patterns: ‘builtin_repo_name’ and ‘username/repo’
  if [[ $repo_arg =~ ^[0-9A-Za-z_.-]+$ ]]; then
    is_builtin=true
    user_repo="no-simpler/divine-dpl-$repo_arg"
  elif [[ $repo_arg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then
    user_repo="$repo_arg"
  else
    # Other patterns are not checked against Github
    return 1
  fi

  # Announce start
  dprint_debug 'Interpreting as Github repository'

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest
  case $D_ADD_MODE in
    normal)
      if $is_builtin; then
        perm_dest="$D_DEPLOYMENTS_DIR/repos/divine/$repo_arg"
      else
        perm_dest="$D_DEPLOYMENTS_DIR/repos/github/$repo_arg"
      fi
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/$( basename -- "$repo_arg" )";;
    root) perm_dest="$D_DEPLOYMENTS_DIR";;
    *)    return 1;;
  esac

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Prompt user about the addition
      dprompt_key --bare --answer "$D_BLANKET_ANSWER" --prompt 'Clone it?' -- \
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
      
      # Set status
      cloned_repo=true
      temp_ready=true

    else

      # Repo does not exist
      dprint_debug 'Non-existent repository at:' \
        -i "https://github.com/${user_repo}"
      return 1
    
    fi

  else

    # Not cloning repository, tinker with destination paths again
    if [ "$D_ADD_MODE" = normal ]; then
      if $is_builtin; then
        perm_dest="$D_DEPLOYMENTS_DIR/imported/divine/$repo_arg"
      else
        perm_dest="$D_DEPLOYMENTS_DIR/imported/github/$repo_arg"
      fi
    fi

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Prompt user about the addition
      dprompt_key --bare --answer "$D_BLANKET_ANSWER" --prompt 'Download it?' \
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
    
      # Set status
      temp_ready=true

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available

      # Prompt user about the addition
      dprompt_key --bare --answer "$D_BLANKET_ANSWER" --prompt 'Download it?' \
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
      
      # Set status
      temp_ready=true

    else

      # Repo does not exist
      dprint_debug 'Non-existent repository at:' \
        -i "https://github.com/${user_repo}"
      return 1

    fi
  
  fi

  # If succeeded to get repo to temp dir, go for the kill
  if $temp_ready; then

    # Check whether directory to be added contains any deployments
    __adding__check_for_deployments "$temp_dest" \
      "https://github.com/${user_repo}" \
      || { rm -rf -- "$temp_dest"; return 1; }

    # Prompt user for possible clobbering, and clobber if required
    __adding__clobber_check "$perm_dest" || return 1

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

    # If repository was cloned, record this to root stash
    if $cloned_repo; then
      if dstash -r -s add dpl_repos "$perm_dest"; then
        dprint_debug 'Recorded location of cloned repository in root stash:' \
          -i "$perm_dest"
      else
        dprint_debug \
          'Failed to record location of cloned repository in root stash:' \
          -i "$perm_dest" \
          -n 'Update routine will be unable to update this repository'
      fi
    fi

    # All done: announce and return
    dprint_debug 'Successfully added Github-hosted deployments from:' \
      -i "https://github.com/${user_repo}" \
      -n 'to intended location at:' -i "$perm_dest"
    return 0
  
  else

    # Somehow got here without successfully pulling repo: return error
    dprint_debug 'Not supposed to get here'
    return 1
  
  fi
}

#>  __adding__attempt_local_repo
#
## Attempts to interpret single argument as path to local git repository and 
#. pull it in. Accepts any resolvable path to directory containing git repo.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
__adding__attempt_local_repo()
{
  # If it has been detected that git is unavailable: skip
  $NO_GIT && return 1

  # Extract argument
  local repo_arg="$1"

  # Check if argument is a directory
  [ -d "$repo_arg" ] || return 1

  # Check if git is available
  git --version >&/dev/null || return 1

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
  local perm_dest
  case $D_ADD_MODE in
    normal)
      perm_dest="$D_DEPLOYMENTS_DIR/repos/local/$( basename \
        -- "$repo_path" )"
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/$( basename -- "$repo_path" )";;
    root) perm_dest="$D_DEPLOYMENTS_DIR";;
    *)    return 1;;
  esac

  # First, attempt to check existense of repository using git
  if git ls-remote "$repo_path" -q &>/dev/null; then

    # Both git and local repo are available

    # Prompt user about the addition
    dprompt_key --bare --answer "$D_BLANKET_ANSWER" --prompt 'Clone it?' -- \
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
    
    # Check whether directory to be added contains any deployments
    __adding__check_for_deployments "$temp_dest" "$repo_path"  \
      || { rm -rf -- "$temp_dest"; return 1; }

    # Prompt user for possible clobbering, and clobber if required
    __adding__clobber_check "$perm_dest" || return 1

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

    # Record in root stash
    if dstash -r -s add dpl_repos "$perm_dest"; then
      dprint_debug 'Recorded location of cloned repository in root stash:' \
        -i "$perm_dest"
    else
      dprint_debug \
        'Failed to record location of cloned repository in root stash:' \
        -i "$perm_dest" \
        -n 'Update routine will be unable to update this repository'
    fi

    # All done: announce and return
    dprint_debug 'Successfully added local git-controlled deployments from:' \
      -i "$repo_path" -n 'to intended location at:' -i "$perm_dest"
    return 0
    
  else

    # Directory is not a git repo
    dprint_debug 'Not a git repository at:' -i "$repo_path"
    return 1

  fi
}

#>  __adding__attempt_local_dir
#
## Attempts to interpret single argument as path to local directory containing 
#. deployments and pull it in
#
## Returns:
#.  0 - Successfully pulled in deployment directory
#.  1 - Otherwise
#
__adding__attempt_local_dir()
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
  local perm_dest
  case $D_ADD_MODE in
    normal)
      perm_dest="$D_DEPLOYMENTS_DIR/imported/$( basename -- "$dir_path" )"
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/$( basename -- "$dir_path" )";;
    root) perm_dest="$D_DEPLOYMENTS_DIR";;
    *)    return 1;;
  esac

  # Prompt user about the addition
  local prompt; $D_ADD_LINK && prompt='Link it?' || prompt='Copy it?'
  dprompt_key --bare --answer "$D_BLANKET_ANSWER" --prompt "$prompt" -- \
    "Detected ${BOLD}local directory${NORMAL} at:" -i "$dir_path" \
      || return 1

  # Check whether directory to be added contains any deployments
  __adding__check_for_deployments "$dir_path" "$dir_path" \
    || return 1

  # Prompt user for possible clobbering, and clobber if required
  __adding__clobber_check "$perm_dest" || return 1

  # Finally, link/copy directory to intended location
  if $D_ADD_LINK; then
    dln -- "$dir_path" "$perm_dest" || {
      # Announce failure to link
      dprint_debug 'Failed to link deployments from local directory at:' \
        -i "$dir_path" -n 'to intended location at:' -i "$perm_dest"
      # Return
      return 1
    }
  else
    cp -Rn -- "$dir_path" "$perm_dest" || {
      # Announce failure to copy
      dprint_debug 'Failed to copy deployments from local directory at:' \
        -i "$dir_path" -n 'to intended location at:' -i "$perm_dest"
      # Return
      return 1
    }
  fi

  # All done: announce and return
  dprint_debug 'Successfully added local deployments directory at:' \
    -i "$dir_path" -n 'to intended location at:' -i "$perm_dest"
  return 0
}

#>  __adding__attempt_local_file
#
## Attempts to interpret single argument as path to local ‘*.dpl.sh’ file and 
#. pull it in
#
## Returns:
#.  0 - Successfully pulled in deployment file
#.  1 - Otherwise
#
__adding__attempt_local_file()
{
  # Extract argument
  local dpl_file_arg="$1"

  # Check if argument is a directory
  [ -f "$dpl_file_arg" -a -r "$dpl_file_arg" ] || return 1

  # Check if argument conforms to deployment naming
  local dpl_file_name="$( basename -- "$dpl_file_arg" )"
  [[ $dpl_file_name == *$D_DPL_SH_SUFFIX \
    || $dpl_file_name == $D_DIVINEFILE_NAME ]] || return 1
  
  # Announce start
  dprint_debug 'Interpreting as local deployment file'

  # Construct full path to directory containing file
  local dpl_file_path="$( cd -- "$( dirname -- "$dpl_file_arg" )" && pwd -P \
    || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    dprint_debug 'Failed to access directory of local deployment file at:' \
      -i "$dpl_file_path"
    return 1
  fi

  # Attach filename
  dpl_file_path+="/$dpl_file_name"

  # Construct permanent destination
  local perm_dest
  case $D_ADD_MODE in
    normal)
      perm_dest="$D_DEPLOYMENTS_DIR/imported/standalone/$dpl_file_name"
      ;;
    flat) perm_dest="$D_DEPLOYMENTS_DIR/standalone/$dpl_file_name";;
    root) perm_dest="$D_DEPLOYMENTS_DIR/$dpl_file_name";;
    *)    return 1;;
  esac

  # Prompt user about the addition
  local prompt; $D_ADD_LINK && prompt='Link it?' || prompt='Copy it?'
  dprompt_key --bare --answer "$D_BLANKET_ANSWER" --prompt "$prompt" -- \
    "Detected ${BOLD}local deployment file${NORMAL} at:" \
    -i "$dpl_file_path" \
      || return 1

  # Prompt user for possible clobbering, and clobber if required
  __adding__clobber_check "$perm_dest" || return 1

  # Finally, link/copy deployment file to intended location
  if $D_ADD_LINK; then
    dln -- "$dpl_file_path" "$perm_dest" || {
      # Announce failure to link
      dprint_debug 'Failed to link local deployment file at:' \
        -i "$dpl_file_path" -n 'to intended location at:' -i "$perm_dest"
      # Return
      return 1
    }
  else
    cp -n -- "$dpl_file_path" "$perm_dest" || {
      # Announce failure to copy
      dprint_debug 'Failed to copy local deployment file at:' \
        -i "$dpl_file_path" -n 'to intended location at:' -i "$perm_dest"
      # Return
      return 1
    }
  fi

  # All done: announce and return
  dprint_debug 'Successfully added local deployment file at:' \
    -i "$dpl_file_path" -n 'to intended location at:' -i "$perm_dest"
  return 0
}

#>  __adding__check_for_deployments PATH SRC_PATH
#
## Checks whether PATH contains any ‘*.dpl.sh’ files, and, if not, warns user 
#. of that.
#
## Returns:
#.  0 - PATH contains at least one deployment
#.  1 - Otherwise
#
__adding__check_for_deployments()
{
  # Extract directory path and source path
  local dir_path="$1"; shift
  local src_path="$1"; shift
  local divinedpl_filepath

  # Iterate over candidates for deployment file
  while IFS= read -r -d $'\0' divinedpl_filepath; do

    # Check if candidate is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] && {
      # Return on first hit
      return 0
    }

  done < <( find -L "$dir_path" -mindepth 1 -maxdepth 10 \
    -name "*$D_DPL_SH_SUFFIX" -print0 )

  # No deployment files: announce and return
  dprint_debug 'Failed to detect any deployment files in:' -i "$src_path"
  return 1
}

#>  __adding__clobber_check PATH
#
## Prompts user whether they indeed want to clobber (pre-erase) path that 
#. already exists. Given positive answer, proceeds with removal, and returns 
#. non-zero on failure.
#
## Returns:
#.  0 - User confirms
#.  1 - User declines, or removal of directory failed
#
__adding__clobber_check()
{
  # Extract clobber path
  local clobber_path="$1"

  # Status variable
  local yes=false

  # Check if clobber path exists
  if [ -e "$clobber_path" ]; then

    # Detect type of existing entity
    local clobber_type
    [ -d "$clobber_path" ] && clobber_type='directory' || clobber_type='file'
    [ -L "$clobber_path" ] && clobber_type="symlinked $clobber_type"

    # Compose pre-defined answer
    local answer="$D_BLANKET_ANSWER"

    # Compose prompt description
    local prompt_desc=()

    # Warning about clobbering
    prompt_desc+=( "A $clobber_type already exists at:" -i "$clobber_path" )

    # Further warning for directories
    if [ -d "$clobber_path" -a ! -L "$clobber_path" ]; then
      prompt_desc+=( -n "${BOLD}${YELLOW}${REVERSE} Warning! ${NORMAL}" )
      prompt_desc+=( \
        'Directories are not merged. They are erased completely.' \
      )
    fi

    # Further still for deployments directory
    if [ "$clobber_path" = "$D_DEPLOYMENTS_DIR" ]; then

      if [ -L "$clobber_path" ]; then
        prompt_desc+=( \
          -n "${BOLD}Entire deployments directory will be unlinked!${NORMAL}" \
        )
      else
        prompt_desc+=( \
          -n "${BOLD}Entire deployments directory will be erased!${NORMAL}" \
        )
      fi

      # If clobbering deployments directory, blanket answer is not enough
      [ "$D_BLANKET_ANSWER" = true ] && answer=

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
      return 0
    
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
    return 0
  
  fi
}

#>  __adding__check_or_install UTIL_NAME
#
## Checks whether UTIL_NAME is available and, if not, offers to install it 
#. using system’s package manager, if it is available
#
## Returns:
#.  0 - UTIL_NAME is available or successfully installed
#.  1 - UTIL_NAME is not available or failed to install
#
__adding__check_or_install()
{
  # Extract util name
  local util_name="$1"

  # If command by that name is available, return zero immediately
  command -v "$util_name" &>/dev/null && return 0

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
    if dprompt_key --bare --answer "$D_BLANKET_ANSWER" \
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

__perform_add