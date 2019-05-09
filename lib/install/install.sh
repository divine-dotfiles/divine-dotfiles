# Driver function
main()
{
  # Colorize output
  __declare_global_colors

  # Main installation
  if __pull_github_repo; then
    # Optional: install shortcut command ('di' by default)
    __install_shortcut
    # Optional: pull default set of deployments
    __install_default_dpls
    # Report success
    printf >&2 '\n%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" 'Glowing success'
    return 0
  fi

  # Report failure
  printf >&2 '\n%s %s\n' "${BOLD}${RED}==>${NORMAL}" 'Crippling failure'
  return 1
}

__declare_global_colors()
{
  # Colorize output (shamelessly stolen off oh-my-zsh)
  local num_of_colors
  if command -v tput &>/dev/null; then num_of_colors=$( tput colors ); fi
  if [ -t 1 ] && [ -n "$num_of_colors" ] && [ "$num_of_colors" -ge 8 ]; then
    RED="$( tput setaf 1 )"
    GREEN="$( tput setaf 2 )"
    YELLOW="$( tput setaf 3 )"
    WHITE="$( tput setaf 7 )"
    BOLD="$( tput bold )"
    NORMAL="$( tput sgr0 )"
  else
    RED=''
    GREEN=''
    YELLOW=''
    WHITE=''
    BOLD=''
    NORMAL=''
  fi
}

__pull_github_repo()
{
  # Store location of Divine.dotfiles repository
  local user_repo="no-simpler/divine-dotfiles"

  # Offer to install framework
  local yes=false
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "${BOLD}Divine.dotfiles${NORMAL} Bash framework from:" \
    "https://github.com/${user_repo}"
  printf >&2 'Install? [y/n] '

  # Await answer
  while true; do
    read -rsn1 input
    [[ $input =~ ^(y|Y)$ ]] && { printf >&2 'y'; yes=true;  break; }
    [[ $input =~ ^(n|N)$ ]] && { printf >&2 'n'; yes=false; break; }
  done
  printf >&2 '\n'

  # Check answer
  $yes || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Refused to install ${BOLD}Divine.dotfiles${NORMAL}"
    return 1
  }

  # Install to home directory unless overridden
  [ -n "$D_DIR" ] || D_DIR="$HOME/.divine"

  # Check if installation directory already exists
  if [ -d "$D_DIR" ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "${BOLD}Divine.dotfiles${NORMAL} is likely already installed at:" \
      "$D_DIR"
    return 1
  elif [ -e "$D_DIR" ]; then
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Unable to install: a file occupies installation path:' "$D_DIR"
    return 1
  else
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Installing ${BOLD}Divine.dotfiles${NORMAL}"
  fi

  # Sane umask
  umask g-w,o-w

  # Create installation directory
  mkdir -p -- "$D_DIR"

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$D_DIR" &>/dev/null \
        || {
          printf >&2 '\n%s %s\n  %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Unable to install: failed to clone repository at:' \
            "https://github.com/${user_repo}"
          rm -rf -- "$D_DIR"
          return 1
        }
      
    else

      # Likely unable to connect to repository
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Unable to install: failed to connect to repository at:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_DIR"
      return 1
    
    fi

  else

    # Git unavailable: download instead

    # Check if tar is available
    tar --version &>/dev/null || {
      printf >&2 '\n%s %s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Unable to install: failed to detect neither' \
        "${BOLD}git${NORMAL} nor ${BOLD}tar${NORMAL}"
      rm -rf -- "$D_DIR"
      return 1
    }

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$D_DIR" -xzf -
      [ $? -eq 0 ] || {
        printf >&2 '\n%s %s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Unable to install:' \
          'failed to download (curl) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_DIR"
        return 1
      }

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$D_DIR" -xzf -
      [ $? -eq 0 ] || {
        printf >&2 '\n%s %s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Unable to install:' \
          'failed to download (wget) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_DIR"
        return 1
      }

    else

      # Either none of the tools were available, or repo does not exist
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Unable to install: failed to download repository from:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_DIR"
      return 1

    fi
  
  fi

  # Make sure primary script is executable
  chmod +x "$D_DIR/intervene.sh" || {
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to set executable flag for:' \
      "$D_DIR/intervene.sh"
  }

  # If gotten here, all is good
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully installed ${BOLD}Divine.dotfiles${NORMAL} to:" \
    "$D_DIR"
  return 0
}

__install_shortcut()
{
  # Compose shortcut name
  [[ -n $D_SHORTCUT_NAME && $D_SHORTCUT_NAME =~ ^[a-z0-9]+$ ]] \
    || D_SHORTCUT_NAME='di'

  # Offer to install shortcut
  local yes=false
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "[optional] Shortcut shell command '${BOLD}${D_SHORTCUT_NAME}${NORMAL}'"
  printf >&2 'Install? [y/n] '

  # Await answer
  while true; do
    read -rsn1 input
    [[ $input =~ ^(y|Y)$ ]] && { printf >&2 'y'; yes=true;  break; }
    [[ $input =~ ^(n|N)$ ]] && { printf >&2 'n'; yes=false; break; }
  done
  printf >&2 '\n'

  # Check answer
  $yes || {
    printf >&2 '\n%s %s %s\n' \
      "${BOLD}${WHITE}==>${NORMAL}" \
      'Refused to install shortcut shell command' \
      "'${BOLD}${D_SHORTCUT_NAME}${NORMAL}'"
    return 1
  }

  # Storage variable
  local new_cmd_name

  # Check if command by that name already exists (including aliases and so on)
  while command -v "$D_SHORTCUT_NAME" &>/dev/null; do

    # Inform user
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Command '${BOLD}${D_SHORTCUT_NAME}${NORMAL}' already exists"

    while true; do

      # Print prompt and read answer
      printf >&2 "Try another name ('q' to skip): "
      read -r new_cmd_name && printf '\n'

      # Check if user don’t want another name
      [ "$new_cmd_name" = q ] && {
        printf >&2 '\n%s %s %s\n  %s\n' \
          "${BOLD}${WHITE}==>${NORMAL}" \
          'Skipped installing shortcut shell command' \
          "'${BOLD}${D_SHORTCUT_NAME}${NORMAL}'" \
          "because command '$D_SHORTCUT_NAME' already exists"
        return 1
      }

      # Check if name is valid
      [[ $new_cmd_name =~ ^[a-z0-9]+$ ]] || {
        printf >&2 '%s\n' 'Use letters and digits only'
        continue
      }

      # Accept new name and try it on next iteration of the outer loop
      D_SHORTCUT_NAME="$new_cmd_name"
      break
    
    done

  done
  
  # Assemble possible locations for the shortcut
  local shortcut_path_candidates=( \
    "$HOME/bin" \
    "$HOME/.bin" \
    '/usr/local/bin' \
    '/usr/bin' \
    '/bin' \
  )

  # If provided with directory for shortcut, prefix it to candidates
  [ -d "$D_SHORTCUT_PATH" ] && shortcut_path_candidates=( \
    "$D_SHORTCUT_PATH" \
    "${shortcut_path_candidates[@]}" \
  )
  
  # Storage variables
  local shortcut_path shortcut_filepath shortcut_installed=false

  for shortcut_path in "${shortcut_path_candidates[@]}"; do

    # Check if shortcut directory exists and is on $PATH
    [[ -d "$shortcut_path" && ":$PATH:" == *":$shortcut_path:"* ]] \
      || continue

    # Construct full path
    shortcut_filepath="$shortcut_path/$D_SHORTCUT_NAME"

    # If file path is occupied, it is likely some namesake directory: skip
    [ -e "$shortcut_filepath" ] && continue
    
    # Create symlink, or move to next candidate on failure
    ln -s -- "$D_DIR/intervene.sh" "$shortcut_filepath" &>/dev/null \
      && { shortcut_installed=true; break; }

  done

  # Report status
  if $shortcut_installed; then
    # Keep record of installation location
    printf '%s\n' "$shortcut_filepath" \
      >"$D_DIR/lib/uninstall/shortcut-location"
    # Report success
    printf >&2 '\n%s %s %s\n  %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully installed shortcut shell command' \
      "'${BOLD}${D_SHORTCUT_NAME}${NORMAL}' to:" \
      "$shortcut_filepath"
  else  
    printf >&2 '\n%s %s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to install shortcut shell command' \
      "'${BOLD}${D_SHORTCUT_NAME}${NORMAL}'" \
      'because none of $PATH directories could take it'
  fi
}

__install_default_dpls()
{
  # Store location of default deployments repository
  local user_repo='no-simpler/divine-dpl-default'

  # Offer to install default deployments
  local yes=false
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    '[optional] Default set of deployments from:' \
    "https://github.com/${user_repo}"
  printf >&2 'Install? [y/n] '

  # Await answer
  while true; do
    read -rsn1 input
    [[ $input =~ ^(y|Y)$ ]] && { printf >&2 'y'; yes=true;  break; }
    [[ $input =~ ^(n|N)$ ]] && { printf >&2 'n'; yes=false; break; }
  done
  printf >&2 '\n'

  # Check answer
  $yes || {
    printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${WHITE}==>${NORMAL}" \
      'Refused to install default set of deployments from:' \
      "https://github.com/${user_repo}"
    return 1
  }

  # Install to deployments directory
  local dpl_dir="$D_DIR/dpl"

  # Remove current (almost empty) deployments directory
  rm -rf -- "$dpl_dir"

  # Create empty installation directory
  mkdir -p -- "$dpl_dir"

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$dpl_dir" &>/dev/null \
        || {
          printf >&2 '\n%s %s\n  %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Failed to clone default deployments repository at:' \
            "https://github.com/${user_repo}"
          return 1
        }
      
    else

      # Likely unable to connect to repository
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to connect to default deployments repository at:' \
        "https://github.com/${user_repo}"
      return 1
    
    fi

  else

    # Git unavailable: download instead

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$dpl_dir" -xzf -
      [ $? -eq 0 ] || {
        printf >&2 '\n%s %s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to download (curl) or extract' \
          'tarball of default deployments repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        return 1
      }

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$dpl_dir" -xzf -
      [ $? -eq 0 ] || {
        printf >&2 '\n%s %s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to download (wget) or extract' \
          'tarball of default deployments repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        return 1
      }

    else

      # Either none of the tools were available, or repo does not exist
      printf >&2 '\n%s %s\n  %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to download default deployments repository from:' \
        "https://github.com/${user_repo}"
      return 1

    fi
  
  fi

  # If gotten here, all is good
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully installed default deployments to:" \
    "$dpl_dir"
  return 0
}

main