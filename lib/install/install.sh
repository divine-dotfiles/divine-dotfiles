# Driver function
main()
{
  # Colorize output
  __declare_global_colors

  # Parse arguments
  __parse_arguments "$@"

  # Main installation
  if __pull_github_repo; then

    # Create 'assets' and 'dpl' directories
    __create_empty_dirs

    # Optional: install shortcut command ('di' by default)
    __install_shortcut

    # Status flag
    local anything_attached=false

    # Optional: pull Divine deployments 'core' package (default packages)
    if __attach_dpls_core; then
      dprint_success "Attached Divine deployments 'core' package"
      anything_attached=true
    else
      dprint_failure "Failed to attach Divine deployments 'core' package"
    fi

    # Optional: pull deployment repos requested through installation args
    if __attach_requested_dpls; then
      anything_attached=true
    fi

    # Optional: if any deployments were attached, run ‘di install --yes’
    if $anything_attached; then
      __run_install \
        || dprint_failure 'Failed while running installation routine'
    fi

    # Report success
    dprint_success 'All done'
    return 0
  fi

  # Report failure
  dprint_failure 'Nothing was installed'
  return 1
}

__declare_global_colors()
{
  # Colorize output (shamelessly stolen off oh-my-zsh)
  local num_of_colors
  if type -P tput &>/dev/null; then num_of_colors=$( tput colors ); fi
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
  D_OPT_QUIET=false         # Be verbose by default
  D_INSTALL_FRAMEWORK=      # Whether to install framework itself
  D_INSTALL_SHORTCUT=       # Whether to install shortcut symlink
  D_ATTACH_DPLS_CORE=       # Whether to attach default deployments
  D_ATTACH_REQUESTED_DPLS=  # Whether to attach default deployments
  D_RUN_INSTALL=            # Whether to run di install --yes
  D_REQUESTED_DPLS=()       # Storage for user-requested attachments

  # Extract arguments passed to this script (they start at $0)
  local args=( "$0" "$@" ) arg

  # Parse arguments
  for arg in "${args[@]}"; do
    case "$arg" in
      --quiet)              D_OPT_QUIET=true;;
      --verbose)            D_OPT_QUIET=false;;
      --framework-yes)      D_INSTALL_FRAMEWORK=true;;
      --framework-no)       D_INSTALL_FRAMEWORK=false;;
      --shortcut-yes)       D_INSTALL_SHORTCUT=true;;
      --shortcut-no)        D_INSTALL_SHORTCUT=false;;
      --dpls-core-yes)      D_ATTACH_DPLS_CORE=true;;
      --dpls-core-no)       D_ATTACH_DPLS_CORE=false;;
      --requested-dpls-yes) D_ATTACH_REQUESTED_DPLS=true;;
      --requested-dpls-no)  D_ATTACH_REQUESTED_DPLS=false;;
      --run-install-yes)    D_RUN_INSTALL=true;;
      --run-install-no)     D_RUN_INSTALL=false;;
      --yes)                D_INSTALL_FRAMEWORK=true
                            D_INSTALL_SHORTCUT=true
                            D_ATTACH_DPLS_CORE=true
                            D_ATTACH_REQUESTED_DPLS=true
                            D_RUN_INSTALL=true
                            ;;
      --no)                 D_INSTALL_FRAMEWORK=false
                            D_INSTALL_SHORTCUT=false
                            D_ATTACH_DPLS_CORE=false
                            D_ATTACH_REQUESTED_DPLS=false
                            D_RUN_INSTALL=false
                            ;;
      *)                    D_REQUESTED_DPLS+=( "$arg" );;
    esac
  done
}

__pull_github_repo()
{
  # Store location of Divine.dotfiles repository
  local user_repo="no-simpler/divine-dotfiles"

  # Install to home directory unless overridden
  [ -n "$D_INSTALL_PATH" ] || D_INSTALL_PATH="$HOME/.divine"
  dprint_debug "Installation directory: $D_INSTALL_PATH"

  # Check if installation directory already exists
  if [ -d "$D_INSTALL_PATH" ]; then
    dprint_debug 'Installation directory already exists; refusing to overwrite'
    return 1
  elif [ -e "$D_INSTALL_PATH" ]; then
    dprint_debug 'Installation path already exists; refusing to overwrite'
    return 1
  fi

  # Offer to install framework
  if dprompt_key "$D_INSTALL_FRAMEWORK" 'Install?' \
    "${BOLD}Divine.dotfiles${NORMAL} Bash framework from:" \
    "https://github.com/${user_repo}"
  then
    dprint_start "Installing ${BOLD}Divine.dotfiles${NORMAL}"
  else
    dprint_skip "Refused to install ${BOLD}Divine.dotfiles${NORMAL}"
    return 1
  fi

  # Sane umask
  umask g-w,o-w

  # Create installation directory
  mkdir -p -- "$D_INSTALL_PATH" &>/dev/null || {
    dprint_debug 'Failed to create installation directory'
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
          dprint_debug 'Failed to clone Github repository at:' \
            "https://github.com/${user_repo}"
          rm -rf -- "$D_INSTALL_PATH"
          return 1
        }
      
    else

      # Likely unable to connect to repository
      dprint_debug 'Failed to connect to repository at:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_INSTALL_PATH"
      return 1
    
    fi

  else

    # Git unavailable: download instead

    # Check if tar is available
    tar --version &>/dev/null || {
      dprint_debug \
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
        dprint_debug \
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
        dprint_debug \
          'Failed to download (wget) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_INSTALL_PATH"
        return 1
      }

    else

      # Either none of the tools were available, or repo does not exist
      dprint_debug 'Failed to clone or download repository from:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_INSTALL_PATH"
      return 1

    fi
  
  fi

  # Make sure primary script is executable
  chmod +x "$D_INSTALL_PATH/intervene.sh" || {
    dprint_debug 'Failed to set executable flag for:' \
      "$D_INSTALL_PATH/intervene.sh" 'Please, see to it yourself'
  }

  # If gotten here, all is good
  dprint_success \
    "Successfully installed ${BOLD}Divine.dotfiles${NORMAL} to:" \
    "$D_INSTALL_PATH"
  return 0
}

__create_empty_dirs()
{
  # Storage variables
  local dirs_to_create dir_to_create

  # Assemble list of directories
  dirs_to_create=( \
    "$D_INSTALL_PATH/grail/assets" \
    "$D_INSTALL_PATH/grail/dpls" \
    "$D_INSTALL_PATH/state/backups" \
    "$D_INSTALL_PATH/state/stash" \
    "$D_INSTALL_PATH/state/dpl-repos" \
  )

  # Create each directory for future use
  for dir_to_create in "${dirs_to_create[@]}"; do

    # Create directory, or announce failure
    mkdir -p -- "$dir_to_create" || {
      dprint_debug "Failed to create directory: $dir_to_create"
    }

  done
}

__install_shortcut()
{
  # Compose shortcut name
  [[ -n $D_SHORTCUT_NAME && $D_SHORTCUT_NAME =~ ^[a-z0-9]+$ ]] \
    || D_SHORTCUT_NAME='di'

  # Store long-ass reference in digestible name
  local cmd="${BOLD}${D_SHORTCUT_NAME}${NORMAL}"

  # Offer to install shortcut
  if ! dprompt_key "$D_INSTALL_SHORTCUT" 'Install?' \
    "[optional] Shortcut shell command '${cmd}'"
  then
    dprint_skip "Refused to install shortcut shell command '${cmd}'"
    return 1
  fi

  # Storage variable
  local new_cmd_name

  # Check if command by that name already exists (including aliases and so on)
  while command -v "$D_SHORTCUT_NAME" &>/dev/null; do

    # If predefined answer is given, no re-tries
    if [ "$D_INSTALL_SHORTCUT" = true ]; then
      dprint_skip \
        "Skipped installing shortcut shell command '${cmd}'" \
        'because command by that name already exists'
      return 1
    fi

    # Inform user
    dprint_start \
      "Command '${BOLD}${D_SHORTCUT_NAME}${NORMAL}' already exists"

    while true; do

      # Print prompt and read answer
      printf >&2 "Try another name ('q' to skip): "
      read -r new_cmd_name && printf '\n'

      # Check if user don’t want another name
      [ "$new_cmd_name" = q ] && {
        dprint_skip \
          'Skipped installing shortcut shell command' \
          'because command by that name already exists'
        return 1
      }

      # Check if name is valid
      [[ $new_cmd_name =~ ^[a-z0-9]+$ ]] || {
        $D_OPT_QUIET || printf >&2 '%s\n' 'Use letters and digits only'
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
        dprint_debug "Refusing to install shortcut to: $shortcut_path" \
          'Not a directory or not in $PATH'
        continue
      }

    # Construct full path
    shortcut_filepath="$shortcut_path/$D_SHORTCUT_NAME"

    # Announce attempt
    dprint_debug "Attempting to install shortcut to: $shortcut_filepath"

    # If file path is occupied, it is likely some namesake directory: skip
    [ -e "$shortcut_filepath" ] && {
      dprint_debug "Refusing to install shortcut to: $shortcut_filepath" \
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
        dprint_debug 'Failed to create symlink:' \
          "$shortcut_filepath -> $D_INSTALL_PATH/intervene.sh"
      fi
    else
      # No write permission: try sudo
      if sudo ln -s -- "$D_INSTALL_PATH/intervene.sh" \
        "$shortcut_filepath" &>/dev/null
      then
        shortcut_installed=true; break
      else
        dprint_debug 'Failed to create symlink with sudo:' \
          "$shortcut_filepath -> $D_INSTALL_PATH/intervene.sh"
      fi
    fi

  done

  # Re-compose command name (in case it changed)
  cmd="${BOLD}${D_SHORTCUT_NAME}${NORMAL}"

  # Report status
  if $shortcut_installed; then

    # Keep record of installation location
    if dstash_root_set di_shortcut "$shortcut_filepath"; then
      dprint_debug 'Stored shortcut location in root stash'
    else
      dprint_debug 'Failed to store shortcut location in root stash' \
        'Uninstallation script will be unable to remove shortcut'
    fi

    # Report success
    dprint_success \
      "Successfully installed shortcut shell command '${cmd}' to:" \
      "$shortcut_filepath"

  else

    dprint_failure "Failed to install shortcut shell command '${cmd}'" \
      'because none of $PATH directories could take it'

  fi
}

__attach_dpls_core()
{
  # Store location of default deployments repository
  local user_repo='no-simpler/divine-dpls-core'

  # Offer to install core package
  if ! dprompt_key "$D_ATTACH_DPLS_CORE" 'Attach?' \
    '[optional] Default set of deployments from:' \
    "https://github.com/${user_repo}" \
    'Deployments are only attached, not installed' \
    'Divine deployments are generally safe and fully removable'
  then
    dprint_skip 'Refused to attach default set of deployments from:' \
      "https://github.com/${user_repo}"
    return 1
  fi

  # Run attach routine
  "$D_INSTALL_PATH"/intervene.sh attach "$user_repo" --yes

  # Return whatever routine returns
  return $?
}

__attach_requested_dpls()
{
  # If no arguments are provided, skip silently
  [ ${#D_REQUESTED_DPLS[@]} -eq 0 ] && return 1

  # Offer to install requested deployments
  if ! dprompt_key "$D_ATTACH_REQUESTED_DPLS" 'Attach?' \
    '[optional] Attach additional deployments, as requested in command line'
  then
    dprint_skip 'Refused to attach additional deployments'
    return 1
  fi

  # Run attach routine
  "$D_INSTALL_PATH"/intervene.sh attach "${D_REQUESTED_DPLS[@]}" --yes

  # Return whatever routine returns
  return $?
}

__run_install()
{
  # Offer to install deployments
  if ! dprompt_key "$D_RUN_INSTALL" 'Install?' \
    '[optional] Install deployments' \
    'Deployments attached in previous step(s) will be installed' \
    'Divine deployments are generally safe and fully removable'
  then
    dprint_skip 'Refused to install deployments'
    return 1
  fi

  # Run installation
  "$D_INSTALL_PATH"/intervene.sh install --yes

  # Return zero always
  return 0
}

dprint_debug()
{
  $D_OPT_QUIET && return 0
  printf >&2 "\n${CYAN}%s %s${NORMAL}\n" "==>" "$1"; shift
  while [ $# -gt 0 ]
  do printf >&2 "    ${CYAN}%s${NORMAL}\n" "$1"; shift; done; return 0
}

dprint_start()
{
  $D_OPT_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${YELLOW}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_skip()
{
  $D_OPT_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${WHITE}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_success()
{
  $D_OPT_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_failure()
{
  $D_OPT_QUIET && return 0
  printf >&2 '\n%s %s\n' "${BOLD}${RED}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprompt_key()
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

dstash_root_set()
{
  # Key variables
  local stash_dirpath="$D_INSTALL_PATH/state/stash"
  local stash_filepath="$stash_dirpath/.dstash.cfg"
  local stash_md5_filepath="$stash_filepath.md5"

  # Root stash file must be empty (as this is fresh installation)
  if [ -e "$stash_filepath" ]; then
    return 1
  else
    touch -- "$stash_filepath"
    dmd5 "$stash_filepath" >"$stash_md5_filepath"
  fi

  # Check that stash file has valid checksum
  local calculated_md5="$( dmd5 "$D_STASH_FILEPATH" )"
  local stored_md5="$( head -1 -- "$D_STASH_MD5_FILEPATH" 2>/dev/null )"
  [ "$calculated_md5" = "$stored_md5" ] || return 1

  # Append record at the end, update stored md5
  printf '%s\n' "$1=$2" >>"$D_STASH_FILEPATH"
  dmd5 "$stash_filepath" >"$stash_md5_filepath"
}

dmd5()
{
  local md5
  md5="$( md5sum -- "$1" 2>/dev/null | awk '{print $1}' )"
  if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
  md5="$( md5 -r -- "$1" 2>/dev/null | awk '{print $1}' )"
  if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
  md5="$( openssl md5 -- "$1" 2>/dev/null | awk '{print $1}' )"
  if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
  return 1
}

main "$@"
