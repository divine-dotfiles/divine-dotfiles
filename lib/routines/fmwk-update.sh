#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk-update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.14
#:revremark:    Initial revision
#:created_at:   2019.05.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Updates Divine.dotfiles framework
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
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__updating__main()
{
  # Announce beginning
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- '‘Updating’ Divine.dotfiles'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Updating Divine.dotfiles'
  fi

  # Success marker
  local updated_successfully=false

  # Initialize global status variables
  NO_GIT=false
  NO_GITHUB=false

  # Check if necessary tools are available and offer to install them
  if ! __updating__check_or_install git; then

    # Inform of the issue
    dprint_debug 'Repository cloning will not be available'
    NO_GIT=true

    # Check of curl/wget are available (for downloading Github tarballs)
    if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
      dprint_debug 'Neither curl nor wget is detected'
      dprint_debug 'Github repositories will not be available'
      NO_GITHUB=true
    # Check if tar is available (for extracting Github tarballs)
    elif ! __updating__check_or_install tar; then
      dprint_debug 'Github repositories will not be available'
      NO_GITHUB=true
    fi
  fi

  # Announce start
  printf >&2 '\n'
  dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
    '>>>' 'Updating' ':' 'Divine.dotfiles framework'

  # Prompt user
  local proceeding=false
  if [ "$D_BLANKET_ANSWER" = true ]; then proceeding=true
  elif [ "$D_BLANKET_ANSWER" = false ]; then proceeding=false
  else
    # Prompt
    dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
    dprompt_key --bare && proceeding=true
  fi

  # Launch framework update and print result
  if $proceeding; then

    # Do pre-flight checks
    if __updating__pre_flight_checks; then

      # Do update proper, one way or another
      if __updating__update_fmwk_via_git \
        || __updating__update_fmwk_via_tar
      then
        updated_successfully=true
      fi
    
    fi

    # Report result (inner)
    if $updated_successfully; then
      dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$GREEN" -- \
        'vvv' 'Success' ':' 'Update of Divine.dotfiles framework'
    else
      dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$RED" -- \
        'xxx' 'Failed' ':' 'Update of Divine.dotfiles framework'
    fi

  else
    dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$WHITE" -- \
      '---' 'Skipped' ':' 'Update of Divine.dotfiles framework'
  fi

  # Report result (outer)
  printf >&2 '\n'
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Finished ‘updating’ Divine.dotfiles'
    return 2
  elif $updated_successfully; then
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Finished updating Divine.dotfiles'
    return 0
  else
    dprint_plaque -pcw "$RED" "$D_PLAQUE_WIDTH" \
      -- 'Failed to update Divine.dotfiles'
    return 0
  fi
}

#>  __updating__pre_flight_checks
#
## Ensures directory is ready for update
#
## Returns:
#.  0 - Ready for updating
#.  1 - Otherwise
#
__updating__pre_flight_checks()
{
  # If github is not available, no updating
  $NO_GITHUB && {
    dprint_debug 'Unable to update: missing necessary tools'
    return 1
  }

  # Check that $D_DIR is a readable directory
  [ -d "$D_DIR" -a -r "$D_DIR" ] || {
    dprint_debug 'Not a readable directory:' -i "$D_DIR"
    return 1
  }

  # Otherwise, return zero
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
  $NO_GIT && {
    dprint_debug 'Unable to update via git'
    return 1
  }

  # Ensure $D_DIR is a git repo
  git ls-remote "$D_DIR" -q &>/dev/null || {
    dprint_debug 'Not a git repository:' -i "$D_DIR"
    return 1
  }

  # Change into $D_DIR
  cd -- "$D_DIR" || {
    dprint_debug "Unable to cd into $D_DIR"
    return 1
  }

  # Pull and rebase and check for errors
  if git pull --rebase --stat origin master; then
    dprint_debug 'Successfully pulled from Github repo to:' \
      -i "$D_DIR"
    return 0
  else
    dprint_debug 'There was an error while pulling from Github repo to:' \
      -i "$D_DIR"
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
  # Set download location
  local user_repo='no-simpler/divine-dotfiles'

  # Prompt user
  if ! dprompt_key --bare -p 'Attempt to download?' -a "$D_BLANKET_ANSWER" -- \
    'It is possible to download a fresh copy of Divine.dotfiles from:' \
    -i "https://github.com/${user_repo}" \
    -n 'and overwrite files in your framework directory at:' -i "$D_DIR" \
    -n 'thus performing a ‘crude’ update'
  then
    dprint_debug 'Refused to perform ‘crude’ update'
    return 1
  fi

  # Construct temporary destination path (as global var)
  TEMP_DEST="$( mktemp -d )"

  # Status variable
  local temp_ready=false

  # Attempt curl and Github API
  if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
    2>/dev/null | head -1 ); then

    # Both curl and remote repo are available

    # Download and untar in one fell swoop
    curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
      | tar --strip-components=1 -C "$TEMP_DEST" -xzf -
    
    # Check status
    [ $? -eq 0 ] || {
      # Announce failure to download
      dprint_debug \
        'Failed to download (curl) or extract tarball repository at:' \
        -i "https://api.github.com/repos/${user_repo}/tarball" \
        -n 'to temporary directory at:' -i "$TEMP_DEST"
      # Try to clean up
      rm -rf -- "$TEMP_DEST"
      # Return
      return 1
    }
  
    # Set status
    temp_ready=true

  # Attempt wget and Github API
  elif grep -q 200 < <( wget -q --spider --server-response \
    "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

    # Both wget and remote repo are available

    # Download and untar in one fell swoop
    wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
      | tar --strip-components=1 -C "$TEMP_DEST" -xzf -
    
    # Check status
    [ $? -eq 0 ] || {
      # Announce failure to download
      dprint_debug \
        'Failed to download (wget) or extract tarball repository at:' \
        -i "https://api.github.com/repos/${user_repo}/tarball" \
        -n 'to temporary directory at:' -i "$TEMP_DEST"
      # Try to clean up
      rm -rf -- "$TEMP_DEST"
      # Return
      return 1
    }
    
    # Set status
    temp_ready=true

  else

    # Repository is inaccessible
    dprint_debug 'Unable to access repository at:' \
      -i "https://github.com/${user_repo}"
    return 1

  fi

  # If succeeded in getting repo to temp dir, copy and overwrite files
  if $temp_ready; then

    # Prompt user for possible clobbering, and clobber if required
    if ! dprompt_key --bare -p 'Overwrite files?' -a "$D_BLANKET_ANSWER" -- \
      'Fresh copy of Divine.dotfiles has been downloaded to temp dir at:' \
      -i "$TEMP_DEST" \
      -n 'and is ready to be copied over existing files in:' -i "$D_DIR"
    then
      # Try to clean up
      rm -rf -- "$TEMP_DEST"
      # Report and return
      dprint_debug 'Refused to perform ‘crude’ update'
      return 1
    fi

    # Storage variables
    local from relative to

    # Copy root files (not direcoties)
    while IFS= read -r -d $'\0' from; do
      # Do the job on the file
      __updating__overwrite_fmwk_file "$from" || return 1
    done < <( find "$TEMP_DEST" -mindepth 1 -maxdepth 1 \
      -type f -print0 )

    # Copy files (not directories) in lib/ dir, down to considerable depth
    while IFS= read -r -d $'\0' from; do
      # Do the job on the file
      __updating__overwrite_fmwk_file "$from" || return 1
    done < <( find "$TEMP_DEST/lib" -mindepth 1 -maxdepth 10 \
      -type f -print0 )

    # Clean up
    rm -rf -- "$TEMP_DEST"

    # All done: announce and return
    dprint_debug \
      'Successfully overwritten all Divine.dotfiles components at:' \
      -i "$D_DIR"
    return 0
  
  else

    # Somehow got here without successfully pulling repo: return error
    dprint_debug 'Not supposed to get here'
    return 1
  
  fi
}

#>  __updating__overwrite_fmwk_file FULL_PATH
#
## Copies given file to $D_DIR, overwriting existing file there. $TEMP_DEST is 
#. expected to be a prefix within FULL_PATH.
#
## Returns:
#.  0 - Successfully did the job
#.  1 - There was a fatal error (halt the update)
#
__updating__overwrite_fmwk_file()
{
  # Extract args
  local from="$1"; shift

  # Extract relative path
  local relative="${from#$TEMP_DEST}"

  # Construct 'to' path
  local to="$D_DIR/$relative"

  # Pre-erase existing file
  if [ -e "$to" ]; then
    rm -rf -- "$to" || {
      # Try to clean up
      rm -rf -- "$TEMP_DEST"
      # Report and return
      dprint_debug "Failed to overwrite existing file '$relative' at:" \
        -i "$to"
      return 1
    }
  fi

  # Make sure parent directory for destination exists
  mkdir -p -- "$( dirname -- "$to" )" || {
    # Try to clean up
    rm -rf -- "$TEMP_DEST"
    # Report and return
    dprint_debug "Failed to create parent destination directory at:" \
      -i "$to"
    return 1
  }

  # Move new file
  mv -n -- "$from" "$to" || {
    # Try to clean up
    rm -rf -- "$TEMP_DEST"
    # Report and return
    dprint_debug "Failed to move file '$relative' from:" \
        -i "$from" -n 'to:' -i "$to"
    return 1
  }
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

__updating__main