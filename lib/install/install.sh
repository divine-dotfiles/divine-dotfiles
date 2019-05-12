# Driver function
main()
{
  # Colorize output
  __declare_global_colors

  # Parse arguments
  __parse_arguments "$@"

  # Main installation
  if __pull_github_repo; then

    # Optional: install shortcut command ('di' by default)
    __install_shortcut

    # Optional: pull default set of deployments
    if __add_default_dpls; then
      # Optional: run ‘di install --yes’
      __run_install \
        || report_failure 'Failed to install default deployments'
    else
      report_failure 'Failed to add default deployments'
    fi

    # Report success
    report_success 'All done'
    return 0
  fi

  # Report failure
  report_failure 'Nothing was installed'
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
    CYAN="$( tput setaf 6 )"
    WHITE="$( tput setaf 7 )"
    BOLD="$( tput bold )"
    REVERSE="$( tput rev )"
    NORMAL="$( tput sgr0 )"
  else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    WHITE=''
    BOLD=''
    REVERSE=''
    NORMAL=''
  fi
}

__parse_arguments()
{
  # Define global storage for option values
  D_QUIET=false           # Be verbose by default
  D_INSTALL_FRAMEWORK=    # Whether to install framework itself
  D_INSTALL_SHORTCUT=     # Whether to install shortcut symlink
  D_ADD_DEFAULTS=         # Whether to add default deployments
  D_RUN_INSTALL=          # Whether to run di install --yes

  # Extract arguments passed to this script (they start at $0)
  local args=( "$0" "$@" ) arg

  # Parse arguments
  for arg in "${args[@]}"; do
    case "$arg" in
      --quiet)            D_QUIET=true;;
      --verbose)          D_QUIET=false;;
      --framework-yes)    D_INSTALL_FRAMEWORK=true;;
      --framework-no)     D_INSTALL_FRAMEWORK=false;;
      --shortcut-yes)     D_INSTALL_SHORTCUT=true;;
      --shortcut-no)      D_INSTALL_SHORTCUT=false;;
      --add-defaults-yes) D_ADD_DEFAULTS=true;;
      --add-defaults-no)  D_ADD_DEFAULTS=false;;
      --run-install-yes)  D_RUN_INSTALL=true;;
      --run-install-no)   D_RUN_INSTALL=false;;
      --yes)              D_INSTALL_FRAMEWORK=true
                          D_INSTALL_SHORTCUT=true
                          D_ADD_DEFAULTS=true
                          D_RUN_INSTALL=true
                          ;;
      --no)               D_INSTALL_FRAMEWORK=false
                          D_INSTALL_SHORTCUT=false
                          D_ADD_DEFAULTS=false
                          D_RUN_INSTALL=false
                          ;;
      *)                  :;;
    esac
  done
}

__pull_github_repo()
{
  # Store location of Divine.dotfiles repository
  local user_repo="no-simpler/divine-dotfiles"

  # Install to home directory unless overridden
  [ -n "$D_INSTALL_PATH" ] || D_INSTALL_PATH="$HOME/.divine"
  debug_print "Installation directory: $D_INSTALL_PATH"

  # Check if installation directory already exists
  if [ -d "$D_INSTALL_PATH" ]; then
    debug_print 'Installation directory already exists; refusing to overwrite'
    return 1
  elif [ -e "$D_INSTALL_PATH" ]; then
    debug_print 'Installation directory is a file; refusing to overwrite'
    return 1
  fi

  # Offer to install framework
  if prompt "$D_INSTALL_FRAMEWORK" 'Install?' \
    "${BOLD}Divine.dotfiles${NORMAL} Bash framework from:" \
    "https://github.com/${user_repo}"
  then
    report_start "Installing ${BOLD}Divine.dotfiles${NORMAL}"
  else
    report_skip "Refused to install ${BOLD}Divine.dotfiles${NORMAL}"
    return 1
  fi

  # Sane umask
  umask g-w,o-w

  # Create installation directory
  mkdir -p -- "$D_INSTALL_PATH" &>/dev/null || {
    debug_print 'Failed to create installation directory'
    return 1
  }

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$D_INSTALL_PATH" &>/dev/null \
        || {
          debug_print 'Failed to clone Github repository at:' \
            "https://github.com/${user_repo}"
          rm -rf -- "$D_INSTALL_PATH"
          return 1
        }
      
    else

      # Likely unable to connect to repository
      debug_print 'Failed to connect to repository at:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_INSTALL_PATH"
      return 1
    
    fi

  else

    # Git unavailable: download instead

    # Check if tar is available
    tar --version &>/dev/null || {
      debug_print \
        'Failed to detect neither git nor tar (at least one is required)'
      rm -rf -- "$D_INSTALL_PATH"
      return 1
    }

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 ); then

      # Both curl and remote repo are available

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$D_INSTALL_PATH" -xzf -
      [ $? -eq 0 ] || {
        debug_print \
          'Failed to download (curl) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_INSTALL_PATH"
        return 1
      }

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$D_INSTALL_PATH" -xzf -
      [ $? -eq 0 ] || {
        debug_print \
          'Failed to download (wget) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_INSTALL_PATH"
        return 1
      }

    else

      # Either none of the tools were available, or repo does not exist
      debug_print 'Failed to clone or download repository from:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_INSTALL_PATH"
      return 1

    fi
  
  fi

  # Make sure primary script is executable
  chmod +x "$D_INSTALL_PATH/intervene.sh" || {
    debug_print 'Failed to set executable flag for:' \
      "$D_INSTALL_PATH/intervene.sh" 'Please, see to it yourself'
  }

  # If gotten here, all is good
  report_success \
    "Successfully installed ${BOLD}Divine.dotfiles${NORMAL} to:" \
    "$D_INSTALL_PATH"
  return 0
}

__install_shortcut()
{
  # Compose shortcut name
  [[ -n $D_SHORTCUT_NAME && $D_SHORTCUT_NAME =~ ^[a-z0-9]+$ ]] \
    || D_SHORTCUT_NAME='di'

  # Store long-ass reference in digestible name
  local cmd="${BOLD}${D_SHORTCUT_NAME}${NORMAL}"

  # Offer to install shortcut
  if ! prompt "$D_INSTALL_SHORTCUT" 'Install?' \
    "[optional] Shortcut shell command '${cmd}'"
  then
    report_skip "Refused to install shortcut shell command '${cmd}'"
    return 1
  fi

  # Storage variable
  local new_cmd_name

  # Check if command by that name already exists (including aliases and so on)
  while command -v "$D_SHORTCUT_NAME" &>/dev/null; do

    # If predefined answer is given, no re-tries
    if [ "$D_INSTALL_SHORTCUT" = true ]; then
      report_skip \
        "Skipped installing shortcut shell command '${cmd}'" \
        'because command by that name already exists'
      return 1
    fi

    # Inform user
    report_start \
      "Command '${BOLD}${D_SHORTCUT_NAME}${NORMAL}' already exists"

    while true; do

      # Print prompt and read answer
      printf >&2 "Try another name ('q' to skip): "
      read -r new_cmd_name && printf '\n'

      # Check if user don’t want another name
      [ "$new_cmd_name" = q ] && {
        report_skip \
          'Skipped installing shortcut shell command' \
          'because command by that name already exists'
        return 1
      }

      # Check if name is valid
      [[ $new_cmd_name =~ ^[a-z0-9]+$ ]] || {
        $D_QUIET || printf >&2 '%s\n' 'Use letters and digits only'
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
  [ -n "$D_SHORTCUT_PATH" ] && shortcut_path_candidates=( \
    "$D_SHORTCUT_PATH" \
    "${shortcut_path_candidates[@]}" \
  )
  
  # Storage variables
  local shortcut_path shortcut_filepath shortcut_installed=false

  for shortcut_path in "${shortcut_path_candidates[@]}"; do

    # Check if shortcut directory exists and is on $PATH
    [[ -d "$shortcut_path" && ":$PATH:" == *":$shortcut_path:"* ]] \
      || {
        debug_print "Refusing to install shortcut to: $shortcut_path" \
          'Not a directory or not in $PATH'
        continue
      }

    # Construct full path
    shortcut_filepath="$shortcut_path/$D_SHORTCUT_NAME"

    # Announce attempt
    debug_print "Attempting to install shortcut to: $shortcut_filepath"

    # If file path is occupied, it is likely some namesake directory: skip
    [ -e "$shortcut_filepath" ] && {
      debug_print "Refusing to install shortcut to: $shortcut_filepath" \
        'Path is occupied'
      continue
    }
    
    # Create symlink, or move to next candidate on failure
    if [ -w "$shortcut_path" ]; then
      # Writing permission for directory is granted
      if ln -s -- "$D_INSTALL_PATH/intervene.sh" "$shortcut_filepath" \
        &>/dev/null
      then
        shortcut_installed=true; break
      else
        debug_print 'Failed to create symlink:' \
          "$shortcut_filepath -> $D_INSTALL_PATH/intervene.sh"
      fi
    else
      # No write permission: try sudo
      if sudo ln -s -- "$D_INSTALL_PATH/intervene.sh" "$shortcut_filepath" \
        &>/dev/null
      then
        shortcut_installed=true; break
      else
        debug_print 'Failed to create symlink with sudo:' \
          "$shortcut_filepath -> $D_INSTALL_PATH/intervene.sh"
      fi
    fi

  done

  # Re-compose command name (in case it changed)
  cmd="${BOLD}${D_SHORTCUT_NAME}${NORMAL}"

  # Report status
  if $shortcut_installed; then

    # Keep record of installation location
    if printf '%s\n' "$shortcut_filepath" \
      >"$D_INSTALL_PATH/lib/uninstall/shortcut-location"
    then
      debug_print 'Stored information about shortcut location at:' \
        "$D_INSTALL_PATH/lib/uninstall/shortcut-location"
    else
      debug_print 'Failed to store information about shortcut location at:' \
        "$D_INSTALL_PATH/lib/uninstall/shortcut-location" \
        'Uninstallation script will be unable to remove shortcut'
    fi

    # Report success
    report_success \
      "Successfully installed shortcut shell command '${cmd}' to:" \
      "$shortcut_filepath"

  else

    report_failure "Failed to install shortcut shell command '${cmd}'" \
      'because none of $PATH directories could take it'

  fi
}

__add_default_dpls()
{
  # Store location of default deployments repository
  local user_repo='no-simpler/divine-dpl-default'

  # Offer to install default deployments
  if ! prompt "$D_ADD_DEFAULTS" 'Add?' \
    '[optional] Default set of deployments from:' \
    "https://github.com/${user_repo}" \
    'Deployments are only added, not installed' \
    'Default deployments are safe and fully removable'
  then
    report_skip 'Refused to add default set of deployments from:' \
      "https://github.com/${user_repo}"
    return 1
  fi

  # Install to deployments directory
  local dpl_dir="$D_INSTALL_PATH/dpl"

  # Remove current (almost empty) deployments directory
  rm -rf -- "$dpl_dir" || {
    debug_print "Failed to pre-erase directory: $dpl_dir"
    return 1
  }

  # Create empty installation directory
  mkdir -p -- "$dpl_dir" || {
    debug_print "Failed to create deployments directory: $dpl_dir"
    return 1
  }

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Make shallow clone of repository
      git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$dpl_dir" &>/dev/null \
        || {
          debug_print 'Failed to clone default deployments repository at:' \
            "https://github.com/${user_repo}"
          return 1
        }
      
    else

      # Likely unable to connect to repository
      debug_print 'Failed to connect to default deployments repository at:' \
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
        debug_print 'Failed to download (curl) or extract tarball from' \
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
        debug_print 'Failed to download (wget) or extract tarball from' \
          "https://api.github.com/repos/${user_repo}/tarball"
        return 1
      }

    else

      # Either none of the tools were available, or repo does not exist
      debug_print \
        'Failed to clone or download default deployments repository from:' \
        "https://github.com/${user_repo}"
      return 1

    fi
  
  fi

  # If gotten here, all is good
  report_success 'Successfully added default deployments to:' \
    "$dpl_dir"
  return 0
}

__run_install()
{
  # Offer to install default deployments
  if ! prompt "$D_RUN_INSTALL" 'Install?' \
    '[optional] Install default deployments' \
    'Deployments added in previous step will be installed' \
    'Default deployments are safe and fully removable'
  then
    report_skip 'Refused to install default deployments'
    return 1
  fi

  # Run installation
  "$D_INSTALL_PATH"/intervene.sh install --yes

  # Return zero always
  return 0
}

debug_print()
{
  $D_QUIET && return 0
  printf >&2 "\n${CYAN}%s %s${NORMAL}\n" "==>" "$1"; shift
  while [ $# -gt 0 ]
  do printf >&2 "    ${CYAN}%s${NORMAL}\n" "$1"; shift; done; return 0
}

report_start()
{
  $D_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${YELLOW}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

prompt()
{
  # Extract predefined answer
  local predefined_answer="$1"; shift

  # Check predefined answer
  if [ "$predefined_answer" = true ]; then return 0
  elif [ "$predefined_answer" = false ]; then return 1
  fi

  # Extract prompt text
  local prompt_text="$1"; shift

  # Status variable
  local yes=false

  # Print announcement and prompt
  printf >&2 '\n%s %s\n' "${BOLD}${YELLOW}${REVERSE}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done
  printf >&2 '%s [y/n] ' "${BOLD}${YELLOW}${REVERSE} ${prompt_text} ${NORMAL}"

  # Await answer
  while true; do
    read -rsn1 input
    [[ $input =~ ^(y|Y)$ ]] && { printf >&2 'y'; yes=true;  break; }
    [[ $input =~ ^(n|N)$ ]] && { printf >&2 'n'; yes=false; break; }
  done
  printf >&2 '\n'

  # Check answer
  if $yes; then return 0; else return 1; fi
}

report_success()
{
  $D_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

report_skip()
{
  $D_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${WHITE}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

report_failure()
{
  $D_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${RED}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

main "$@"