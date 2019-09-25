#!/usr/bin/env bash
#:title:        Divine Bash routine: attach
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    No remark
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Attaches deployments by either cloning or downloading provided Github 
#. repositories
#

#>  d__perform_attach_routine
#
## Performs attach routine
#
## Returns:
#.  0 - Routine performed, at least one argument attached
#.  1 - Routine performed, failed to attach any of the arguments
#.  2 - Routine terminated with nothing to do
#
d__perform_attach_routine()
{
  # Synchronize dpl repos
  d__sync_dpl_repos || exit 1

  # Print empty line for visual separation
  printf >&2 '\n'
  
  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- "'Attaching' deployments"
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Attaching deployments'
  fi

  # Global status variable
  GIT_AVAILABLE=true

  # Check if git is available
  if ! git --version &>/dev/null; then

    # Inform of the issue
    dprint_debug 'Failed to detect git' \
      -n 'Repository cloning will not be available'
    GIT_AVAILABLE=false

  fi

  # Storage & status variables
  local dpl_arg
  local attached_anything=false errors_encountered=false

  # Iterate over script arguments
  for dpl_arg in "${D__REQ_ARGS[@]}"; do

    # Print newline to visually separate attachments
    printf >&2 '\n'

    # Announce start
    dprint_ode "${D__ODE_NORMAL[@]}" -c "$YELLOW" -- \
      '>>>' 'Attaching' ':' "$dpl_arg"

    # Try to attach deployments
    if d__attach_dpl_repo "$dpl_arg"; then
      attached_anything=true
      dprint_ode "${D__ODE_NORMAL[@]}" -c "$GREEN" -- \
        'vvv' 'Attached' ':' "$dpl_arg"
    else
      errors_encountered=true
      dprint_ode "${D__ODE_NORMAL[@]}" -c "$RED" -- \
        'xxx' 'Failed to attach' ':' "$dpl_arg"
    fi

  done

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- "Finished 'attaching' deployments"
    return 2
  elif $attached_anything; then
    if $errors_encountered; then
      dprint_plaque -pcw "$YELLOW" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Successfully attached some deployments'
      return 0
    else
      dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Successfully attached all deployments'
      return 0
    fi
  else
    if $errors_encountered; then
      dprint_plaque -pcw "$RED" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Failed to attach deployments'
      return 1
    else
      dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Nothing to do'
      return 2
    fi
  fi
}

#>  d__attach_dpl_repo
#
## Attempts to interpret single argument as name of Github repository and pull 
#. it in. Accepts either full 'user/repo' form or short 'built_in_repo' form 
#. for deployments distributed by author of Divine.dotfiles.
#
## Returns:
#.  0 - Successfully pulled in deployment repository
#.  1 - Otherwise
#
d__attach_dpl_repo()
{
  # Extract argument
  local repo_arg="$1"

  # Storage variables
  local user_repo

  # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
  if [[ $repo_arg =~ ^[0-9A-Za-z_.-]+$ ]]; then
    user_repo="no-simpler/divine-bundle-$repo_arg"
  elif [[ $repo_arg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then
    user_repo="$repo_arg"
  else
    # Other patterns are not checked against Github
    dprint_debug "Invalid Github repository handle: $repo_arg"
    return 1
  fi

  # Construct temporary destination path
  local temp_dest="$( mktemp -d )"

  # Construct permanent destination
  local perm_dest="$D__DIR_BUNDLES/$user_repo"

  # First, attempt to check existense of repository using git
  if $GIT_AVAILABLE; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Prompt user about the attachment
      dprompt --bare --answer "$D__OPT_ANSWER" --prompt 'Clone it?' -- \
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

    # Git not available, download instead

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Prompt user about the attachment
      dprompt --bare --answer "$D__OPT_ANSWER" --prompt 'Download it?' \
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

      # Prompt user about the attachment
      dprompt --bare --answer "$D__OPT_ANSWER" --prompt 'Download it?' \
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
  d__run_pre_attach_checks "$perm_dest" "$temp_dest" \
    "https://github.com/${user_repo}" \
    || { rm -rf -- "$temp_dest"; return 1; }

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

  # Record this to Grail stash
  if d__stash -g -s add dpl_repos "$user_repo"; then
    dprint_debug "Recorded attached repository '$user_repo' in Grail stash"
  else
    dprint_debug \
      "Failed to record attached repository '$user_repo' in Grail stash"
    # Try to clean up
    rm -rf -- "$perm_dest" || {
      dprint_debug 'Failed to remove useless deployments from:' \
        -i "$perm_dest"
    }
    # Return
    return 1
  fi

  # Merge records of external dpls into records of framework dpls
  d__merge_records_of_dpls_in_ext_dir "$temp_dest" "$perm_dest"

  # Also, prepare any of the possible assets
  d__process_all_asset_manifests_in_dpl_dirs

  # All done: announce and return
  dprint_debug 'Successfully attached Github-hosted deployments from:' \
    -i "https://github.com/${user_repo}" \
    -n 'to intended location at:' -i "$perm_dest"
  return 0
}

#>  d__run_pre_attach_checks CLOBBER_PATH EXT_PATH SRC_ADDR
#
## Checks whether EXT_PATH contains any deployments, and whether those 
#. deployments are valid and attach-able
#
## Prompts user whether they indeed want to clobber (pre-erase) path that 
#. already exists. Given positive answer, proceeds with removal, and returns 
#. non-zero on failure.
#
## Returns:
#.  0 - Checks succeeded, user agreed
#.  1 - Otherwise
#
d__run_pre_attach_checks()
{
  # Extract clobber path, external path, and source address
  local clobber_path="$1"; shift
  local ext_path="$1"; shift
  local src_addr="$1"; shift

  # Survey deployments in external dir
  d__scan_for_dpl_files --ext-dir "$ext_path"

  # Check return code
  case $? in
    0)  # Some deployments collected: all good
        :;;
    1)  # Zero deployments detected in ext dir
        dprint_debug 'Failed to detect any deployment files in:' -i "$src_addr"
        return 1
        ;;
    2)  # At least one deployment file has reserved delimiter in its path
        local list_of_illegal_dpls=() illegal_dpl
        for illegal_dpl in "${D__LIST_OF_ILLEGAL_DPL_PATHS[@]}"; do
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
  
  # Immediately validate deployments being attached
  d__validate_detected_dpls --ext-dir "$ext_path/" || return 1

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
      prompt_desc+=( -n "${BOLD}${YELLOW}${REVERSE} Warning! ${NORMAL}" )
      prompt_desc+=( \
        'Directories are not merged. They are erased completely.' \
      )
    fi

    if dprompt --bare --prompt 'Pre-erase?' --answer "$D__OPT_ANSWER" -- \
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

    # After clobbering in dpls dir, re-scan them for deployments
    d__scan_for_dpl_files --fmwk-dir "$D__DIR_DPLS" "$D__DIR_BUNDLES"
    
    # Check return code
    case $? in
      0)  # Some deployments collected: all good
          :;;
      1)  # Zero deployments detected: this is fine too
          :;;
      2)  ## At least one deployment file has reserved delimiter in its path. 
          #. This is very much not expected: dpl dirs have already been 
          #. validated and only quick user intervention would cause this.
          local list_of_illegal_dpls=() illegal_dpl
          for illegal_dpl in "${D__LIST_OF_ILLEGAL_DPL_PATHS[@]}"; do
            list_of_illegal_dpls+=( -i "$illegal_dpl" )
          done
          dprint_failure \
            "Illegal deployments detected at:" "${list_of_illegal_dpls[@]}" \
            -n "String '$D__CONST_DELIMITER' is reserved internal path delimiter"
          exit 1
          ;;
      *)  # Unsopported code
          :;;
    esac

    ## No need to re-validate: dpls are pre-validated, and removing some of 
    #. them can not cause new errors

  else

    # Path does not exist

    # Make sure parent path exists and is a directory
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

  # Check if deployments being attached are merge-able
  d__cross_validate_dpls_before_merging "$ext_path/" || return 1

  # Finally, if made it here, return success
  return 0
}

d__perform_attach_routine