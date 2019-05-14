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

#>  __adding__main
#
## Performs addition routine
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__adding__main()
{
  # Unless just linking: check if git is available and offer to install it
  if ! $D_ADD_LINK; then __adding__check_for_git; fi

  # Storage & status variables
  local dpl_arg
  local arg_success
  local added_anything=false errors_encountered=false

  # Iterate over script arguments
  for dpl_arg in "${D_ARGS[@]}"; do

    # Set default status
    arg_success=true

    # Announce start
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Processing '$dpl_arg'"

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
      printf >&2 '\n%s %s\n' \
        "${BOLD}${GREEN}==>${NORMAL}" \
        "Successfully added '$dpl_arg'"
      added_anything=true
    else
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Did not add '$dpl_arg'"
      errors_encountered=true
    fi

  done

  # Announce routine completion
  if $added_anything; then
    if $errors_encountered; then
      printf >&2 '\n%s %s\n' \
        "${BOLD}${YELLOW}==>${NORMAL}" \
        'Successfully added some deployments'
    else
      printf >&2 '\n%s %s\n' \
        "${BOLD}${GREEN}==>${NORMAL}" \
        'Successfully added all deployments'
    fi
  else
    if $errors_encountered; then
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Did not add any deployments'
    else
      printf >&2 '\n%s %s\n' \
        "${BOLD}${WHITE}==>${NORMAL}" \
        'Nothing to do'
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
  # Extract argument
  local repo_arg="$1"

  # Storage variables
  local user_repo is_builtin=false temp_ready=false

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
  printf >&2 '  %s\n' 'interpreting as Github repository'

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
      __adding__prompt_git_repo "https://github.com/${user_repo}" || return 1

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$temp_dest" &>/dev/null \
        || {
          # Announce failure to clone
          printf >&2 '\n%s %s\n  %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Failed to clone repository at:' \
            "https://github.com/${user_repo}"
          printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
          # Try to clean up
          rm -rf -- "$temp_dest"
          # Return
          return 1
        }
      
      # Set status
      temp_ready=true

    else

      # Repo does not exist
      return 1
    
    fi

  else

    # If curl/wget are not available, don’t bother
    if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
      return 1
    fi

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
      __adding__prompt_git_repo "https://github.com/${user_repo}" || return 1

      # Check if tar is available
      __adding__check_for_tar \
        "https://api.github.com/repos/${user_repo}/tarball" || return 1

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$temp_dest" -xzf -
      
      # Check status
      [ $? -eq 0 ] || {
        # Announce failure to clone
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to download (curl) or extract tarball repository at:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
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
      __adding__prompt_git_repo "https://github.com/${user_repo}" || return 1

      # Check if tar is available
      __adding__check_for_tar \
        "https://api.github.com/repos/${user_repo}/tarball" || return 1

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$temp_dest" -xzf -
      
      # Check status
      [ $? -eq 0 ] || {
        # Announce failure to clone
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to download (wget) or extract tarball repository at:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
        # Try to clean up
        rm -rf -- "$temp_dest"
        # Return
        return 1
      }
      
      # Set status
      temp_ready=true

    else

      # Either none of the tools were available, or repo does not exist
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
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to move deployments from temporary location at:' "$temp_dest"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }

    # All done: announce and return
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully added Github-hosted deployments from:' \
      "https://github.com/${user_repo}"
    printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
    return 0
  
  else

    # Somehow got here without successfully pulling repo: return error
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
  # Extract argument
  local repo_arg="$1"

  # Check if argument is a directory
  [ -d "$repo_arg" ] || return 1

  # Check if git is available
  git --version >&/dev/null || return 1

  # Announce start
  printf >&2 '  %s\n' 'interpreting as local repository'

  # Construct full path to directory
  local repo_path="$( cd -- "$repo_arg" && pwd -P || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to access local repository at:' "$repo_path"
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
    __adding__prompt_git_repo "$repo_path" || return 1

    # Make shallow clone of repository
    git clone --depth=1 "$repo_path" "$temp_dest" &>/dev/null \
      || {
        # Announce failure to clone
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to clone repository at:' "$repo_path"
        printf >&2 '%s\n  %s\n' 'to temporary directory at:' "$temp_dest"
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
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to move deployments from temporary location at:' "$temp_dest"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Try to clean up
      rm -rf -- "$temp_dest"
      # Return
      return 1
    }

    # All done: announce and return
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully added local git-controlled deployments from:' "$repo_path"
    printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
    return 0
    
  else

    # Either git is not available, or directory is not a git repo
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
  printf >&2 '  %s\n' 'interpreting as local directory'

  # Construct full path to directory
  local dir_path="$( cd -- "$dir_arg" && pwd -P || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to access local direcotry at:' "$dir_path"
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
  __adding__prompt_dir_or_file "$dir_path" || return 1

  # Check whether directory to be added contains any deployments
  __adding__check_for_deployments "$dir_path" "$dir_path" \
    || return 1

  # Prompt user for possible clobbering, and clobber if required
  __adding__clobber_check "$perm_dest" || return 1

  # Finally, link/copy directory to intended location
  if $D_ADD_LINK; then
    dln -- "$dir_path" "$perm_dest" || {
      # Announce failure to link
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to link deployments from local directory at:' "$dir_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  else
    cp -Rn -- "$dir_path" "$perm_dest" || {
      # Announce failure to copy
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to copy deployments from local directory at:' "$dir_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  fi

  # All done: announce and return
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully added local deployments directory at:' "$dir_path"
  printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
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
  [[ $dpl_file_name == $D_DPL_SH_SUFFIX \
    || $dpl_file_name == $D_DIVINEFILE_NAME ]] || return 1
  
  # Announce start
  printf >&2 '  %s\n' 'interpreting as local deployment file'

  # Construct full path to directory containing file
  local dpl_file_path="$( cd -- "$( dirname -- "$dpl_file_arg" )" && pwd -P \
    || exit $? )"

  # Check if directory was accessible
  if [ $? -ne 0 ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to access directory of local deployment file at:' \
      "$dpl_file_path"
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
  __adding__prompt_dir_or_file "$dpl_file_path" || return 1

  # Prompt user for possible clobbering, and clobber if required
  __adding__clobber_check "$perm_dest" || return 1

  # Finally, link/copy deployment file to intended location
  if $D_ADD_LINK; then
    dln -- "$dpl_file_path" "$perm_dest" || {
      # Announce failure to link
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to link local deployment file at:' "$dpl_file_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  else
    cp -n -- "$dpl_file_path" "$perm_dest" || {
      # Announce failure to copy
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to copy local deployment file at:' "$dpl_file_path"
      printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
      # Return
      return 1
    }
  fi

  # All done: announce and return
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully added local deployment file at:' "$dpl_file_path"
  printf >&2 '%s\n  %s\n' 'to intended location at:' "$perm_dest"
  return 0
}

#>  __adding__prompt_git_repo REPO_PATH
#
## Prompts user whether they indeed meant the git repository, path to which is 
#. passed as single argument.
#
## Returns:
#.  0 - User confirms
#.  1 - User declines
#
__adding__prompt_git_repo()
{
  # Status variable
  local yes=false

  # Depending on existence of blanket answer, devise decision
  if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
  elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
  else
  
    # User approval required

    # Extract repo address
    local repo_address="$1"

    # Prompt user if this is their choice
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Detected ${BOLD}git repository${NORMAL} at:" \
      "$repo_address"

    # Prompt user
    dprompt_key --bare --prompt 'Add it?' && yes=true || yes=false

  fi

  # Check response
  $yes && return 0 || return 1
}

#>  __adding__prompt_dir_or_file PATH
#
## Prompts user whether they indeed meant the local dir or file, path to which 
#. is passed as single argument.
#
## Returns:
#.  0 - User confirms
#.  1 - User declines
#
__adding__prompt_dir_or_file()
{
  # Status variable
  local yes=false

  # Depending on existence of blanket answer, devise decision
  if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
  elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
  else
  
    # User approval required

    # Extract repo address
    local local_path="$1" local_type

    # Detect type
    [ -d "$local_path" ] \
      && local_type="${BOLD}local directory${NORMAL}" \
      || local_type="${BOLD}local deployment file${NORMAL}"

    # Prompt user if this is their choice
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Detected $local_type at:" "$local_path"

    # Prompt user
    if $D_ADD_LINK; then
      dprompt_key --bare --prompt 'Link it?' && yes=true || yes=false
    else
      dprompt_key --bare --prompt 'Add it?' && yes=true || yes=false
    fi

  fi

  # Check response
  $yes && return 0 || return 1
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

  done < <( find "$dir_path" -mindepth 1 -name "$D_DPL_SH_SUFFIX" -print0 )

  # No deployment files: announce and return
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${RED}==>${NORMAL}" \
    "Failed to detect any deployment files in:" "$src_path"
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
    [ -d "$clobber_path" ] && clobber_type=directory || clobber_type=file

    if [ "$D_BLANKET_ANSWER" = y -a "$clobber_path" != "$D_DEPLOYMENTS_DIR" ]
    then yes=true
    elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
    else

      # Print announcement
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${YELLOW}==>${NORMAL}" \
        "A $clobber_type already exists at:" "$clobber_path"

      # Further warnings for particular cases
      if [ -d "$clobber_path" ]; then

        printf >&2 '%s %s\n' \
          "${BOLD}${YELLOW}${INVERTED}Warning!${NORMAL}" \
          'Directories are not merged. They are erased completely.'

        # Even more warning for deployment directory
        if [ "$clobber_path" = "$D_DEPLOYMENTS_DIR" ]; then
          printf >&2 '%s\n' \
            "${BOLD}Entire deployments directory will be erased!${NORMAL}"
        fi

      fi

      # Prompt user
      dprompt_key --bare --prompt 'Pre-erase?' && yes=true || yes=false

    fi

    # Check response
    if $yes; then

      # Attempt to remove pre-existing file/dir
      rm -rf -- "$clobber_path" || {
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to erase existing $clobber_type at:" "$clobber_path"
        return 1
      }

      # Pre-erased successfully
      return 0

    else

      # Refused to remove
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Refused to erase existing $clobber_type at:" "$clobber_path"
      return 1

    fi

  else

    # Path does not exist

    # Make sure parent path exists and is a directory though
    local parent_path="$( dirname -- "$clobber_path" )"
    if [ ! -d "$parent_path" ]; then
      mkdir -p -- "$parent_path" || {
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to create destination directory at:" \
          "$parent_path"
        return 1
      }
    fi

    # All good
    return 0
  
  fi
}

#>  __adding__check_for_git
#
## Checks whether git is available and, if not, offers to install it using 
#. system’s package manager, if it is available
#
## Returns:
#.  0 - Git is available or successfully installed
#.  1 - Git is not available or failed to install
#
__adding__check_for_git()
{
  # Check if git is callable
  if git --version &>/dev/null; then

    # All good, return positive
    return 0

  else

    # Prepare message for when git is not available (to avoid repetition)
    local no_git_msg='Repository cloning will not be available'

    # No git. Print warning.
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Failed to detect ${BOLD}git${NORMAL} executable"

    # Check if $OS_PKGMGR is detected
    if [ -z ${OS_PKGMGR+isset} ]; then

      # No supported package manager

      # Print warning and return
      printf >&2 '%s\n' "$no_git_msg"
      return 1
    
    else

      # Possible to try and install git using system’s package manager

      # Prompt for answer
      local yes=false
      if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
      elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
      else

        # Print question
        printf >&2 '%s' \
          "Attempt to install it using ${BOLD}${OS_PKGMGR}${NORMAL}? [y/n] "

        # Await answer
        while true; do
          read -rsn1 input
          [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
          [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
        done
        printf '\n'

      fi

      # Check if user accepted
      if $yes; then

        # Announce installation
        printf >&2 '\n%s %s\n' \
          "${BOLD}${YELLOW}==>${NORMAL}" \
          "Installing ${BOLD}git${NORMAL} using ${BOLD}${OS_PKGMGR}${NORMAL}"

        # Proceed with automated installation
        os_pkgmgr dinstall git

        # Check exit code and print status message, then return
        if [ $? -eq 0 ]; then
          printf >&2 '\n%s %s\n' \
            "${BOLD}${GREEN}==>${NORMAL}" \
            "Successfully installed ${BOLD}git${NORMAL}"
          return 0
        else
          printf >&2 '\n%s %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            "Failed to install ${BOLD}git${NORMAL}"
          printf >&2 '%s\n' "$no_git_msg"
          return 1
        fi

      else

        # Proceeding without git
        printf >&2 '\n%s %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Proceeding without ${BOLD}git${NORMAL}"
        printf >&2 '%s\n' "$no_git_msg"
        return 1

      fi
    
    fi

  fi  
}

#>  __adding__check_for_tar
#
## Checks whether tar is available and, if not, offers to install it using 
#. system’s package manager, if it is available. Informs user that tar is 
#. required to download tarball repository, path to which is passed as first 
#. argument.
#
## Returns:
#.  0 - tar is available or successfully installed
#.  1 - tar is not available or failed to install
#
__adding__check_for_tar()
{
  # Extract url of attempted tarball from arguments
  local tarball_url="$1"

  # Check if tar is callable
  if tar --version &>/dev/null; then

    # All good, return positive
    return 0

  else

    # No tar. Print warning.
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Failed to detect ${BOLD}tar${NORMAL} executable"

    # Check if $OS_PKGMGR is detected
    if [ -z ${OS_PKGMGR+isset} ]; then

      # No supported package manager

      # Print warning and return
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Refusing to download tarball repository at:' "$tarball_url"
      printf >&2 '%s\n' \
        "because ${BOLD}tar${NORMAL} is not available"
      return 1
    
    else

      # Possible to try and install tar using system’s package manager

      # Prompt for answer
      local yes=false
      if [ "$D_BLANKET_ANSWER" = y ]; then yes=true
      elif [ "$D_BLANKET_ANSWER" = n ]; then yes=false
      else

        # Print question
        printf >&2 '%s' \
          "Attempt to install it using ${BOLD}${OS_PKGMGR}${NORMAL}? [y/n] "

        # Await answer
        while true; do
          read -rsn1 input
          [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
          [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
        done
        printf '\n'

      fi

      # Check if user accepted
      if $yes; then

        # Announce installation
        printf >&2 '\n%s %s\n' \
          "${BOLD}${YELLOW}==>${NORMAL}" \
          "Installing ${BOLD}tar${NORMAL} using ${BOLD}${OS_PKGMGR}${NORMAL}"

        # Proceed with automated installation
        os_pkgmgr dinstall tar

        # Check exit code and print status message, then return
        if [ $? -eq 0 ]; then
          printf >&2 '\n%s %s\n' \
            "${BOLD}${GREEN}==>${NORMAL}" \
            "Successfully installed ${BOLD}tar${NORMAL}"
          return 0
        else
          printf >&2 '\n%s %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            "Failed to install ${BOLD}tar${NORMAL}"
          printf >&2 '\n%s %s\n  %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Refusing to download tarball repository at:' "$tarball_url"
          printf >&2 '%s\n' \
            "because ${BOLD}tar${NORMAL} is not available"
          return 1
        fi

      else

        # No tar: print warning and return
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Refusing to download tarball repository at:' "$tarball_url"
        printf >&2 '%s\n' \
          "because ${BOLD}tar${NORMAL} is not available"
        return 1

      fi
    
    fi

  fi  
}

__adding__main