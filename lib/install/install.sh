#!/usr/bin/env bash
#:title:        Divine.dotfiles fmwk install script
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    38
#:revdate:      2019.08.05
#:revremark:    Complete rewrite of fmwk (un)installation
#:created_at:   2019.07.22

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This script installs the framework and optional components
#

# Driver function
d__main()
{
  # Colorize output
  d__declare_global_colors

  # Parse arguments
  d__parse_arguments "$@"

  # Main installation
  if d__settle_on_globals && d__pull_github_repo; then

    # Optional: install shortcut command ('di' by default)
    d__install_shortcut

  fi

  # Report summary and return
  d__report_summary && return 0 || return 1
}

d__declare_global_colors()
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

d__parse_arguments()
{
  # Global storage variables for option values
  D_OPT_QUIET=true          # Be quiet by default
  D_INSTALL_FRAMEWORK=      # Whether to install framework itself
  D_INSTALL_SHORTCUT=       # Whether to install shortcut symlink

  # Parse arguments
  local arg
  for arg do
    case "$arg" in
      --quiet)              D_OPT_QUIET=true;;
      --verbose)            D_OPT_QUIET=false;;
      --framework-yes)      D_INSTALL_FRAMEWORK=true;;
      --framework-no)       D_INSTALL_FRAMEWORK=false;;
      --shortcut-yes)       D_INSTALL_SHORTCUT=true;;
      --shortcut-no)        D_INSTALL_SHORTCUT=false;;
      --yes)                D_INSTALL_FRAMEWORK=true
                            D_INSTALL_SHORTCUT=true
                            ;;
      --no)                 D_INSTALL_FRAMEWORK=false
                            D_INSTALL_SHORTCUT=false
                            ;;
      *)                    :;;
    esac
  done
}

d__settle_on_globals()
{
  # Global variables for installation status
  D_STATUS_FRAMEWORK=false
  D_STATUS_SHORTCUT=false

  # Return early if framework is not to be installed
  [ "$D_INSTALL_FRAMEWORK" = false ] && return 1

  # Status variable
  local newline_printed=false

  # Print empty line for visual separation
  $D_OPT_QUIET || { printf >&2 '\n'; newline_printed=true; }
    
  # Check if installation directory is overridden
  if [ -n "$D_FMWK_DIR" ]; then

    # Use user-provided installation directory
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_start "Overridden installation directory: $D_FMWK_DIR"

  else
  
    # Use default installation directory
    D_FMWK_DIR="$HOME/.divine"
    dprint_debug "Installation directory: $D_FMWK_DIR"
  
  fi

  # Check if shortcut installation is not cancelled
  if [ "$D_INSTALL_SHORTCUT" != false ]; then

    # Settle on shortcut executable name
    if [ -n "$D_SHORTCUT_NAME" ]; then
    
      # Announce override
      $newline_printed || { printf >&2 '\n'; newline_printed=true; }
      dprint_start "Overridden shortcut executable name: '$D_SHORTCUT_NAME'"

    else

      # Use default shortcut name
      D_SHORTCUT_NAME='di'
      dprint_debug "Shortcut executable name: '$D_SHORTCUT_NAME'"

    fi

    # Check if user provided their installation directory for shortcut
    if [ -n "$D_SHORTCUT_DIR" ]; then

      # Announce override
      $newline_printed || { printf >&2 '\n'; newline_printed=true; }
      dprint_start "Overridden shortcut installation dir: '$D_SHORTCUT_DIR'"

      # Make user-provided installation directory the only candidate
      D_SHORTCUT_DIR_CANDIDATES=( "$D_SHORTCUT_DIR" )

    else

      # Assemble possible locations for the shortcut command
      D_SHORTCUT_DIR_CANDIDATES=( \
        "$HOME/bin" \
        "$HOME/.bin" \
        '/usr/local/bin' \
        '/usr/bin' \
        '/bin' \
      )

    fi
  
  fi

  # Status variable for assembled globals
  all_good=true

  # Verify eligibility of installation directory
  if [ -d "$D_FMWK_DIR" ]; then

    # Directory exists: announce and set failure flag
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_failure 'Installation directory already exists:' \
      "    $D_FMWK_DIR" \
      'Refusing to overwrite'
    all_good=false

  elif [ -e "$D_FMWK_DIR" ]; then

    # Path is occupied: announce and set failure flag
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_failure 'Installation path already exists:' \
      "    $D_FMWK_DIR" \
      'Refusing to overwrite'
    all_good=false

  fi

  # Check if shortcut installation is not cancelled
  if [ "$D_INSTALL_SHORTCUT" != false ]; then

    # Verify eligibility of shortcut name
    if ! [[ $D_SHORTCUT_NAME =~ ^[a-z0-9]+$ ]]; then

      # Announce illegal shortcut name; set failure flag
      $newline_printed || { printf >&2 '\n'; newline_printed=true; }
      dprint_failure \
        "Shortcut executable name '$D_SHORTCUT_NAME' is illegal" \
        '(only lowercase alphanumerical characters are allowed)'
      all_good=false

    fi

    # Verify eligibility of user-provided shortcut installation path
    if [ -n "$D_SHORTCUT_DIR" ]; then

      # Check if it is a directory on $PATH
      if ! [[ -d "$D_SHORTCUT_DIR" && ":$PATH:" == *":$D_SHORTCUT_DIR:"* ]]
      then

        # Directory exists: announce and set failure flag
        $newline_printed || { printf >&2 '\n'; newline_printed=true; }
        dprint_failure 'Shortcut installation directory is illegal:' \
          "    $D_SHORTCUT_DIR" \
          '(not a directory or not in $PATH)'
        all_good=false

      fi

    fi

  fi

  # Return appropriately
  $all_good && return 0 || return 1
}

d__pull_github_repo()
{
  # Print empty line for visual separation
  printf >&2 '\n'
  
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
  if mkdir -p -- "$D_FMWK_DIR" &>/dev/null; then
    dprint_failure 'Created installation directory:' \
      "    $D_FMWK_DIR"
  else
    dprint_failure 'Failed to create installation directory:' \
      "    $D_FMWK_DIR"
    return 1
  fi

  # Store location of Divine.dotfiles repository
  local user_repo="no-simpler/divine-dotfiles"

  # First, attempt to check existense of repository using git
  if git --version &>/dev/null; then

    if git ls-remote "https://github.com/${user_repo}.git" -q &>/dev/null; then

      # Both git and remote repo are available

      # Make shallow clone of repository
      if git clone --depth=1 "https://github.com/${user_repo}.git" \
        "$D_FMWK_DIR" &>/dev/null
      then

        # Announce success
        dprint_debug 'Cloned Github repository at:' \
          "https://github.com/${user_repo}"

      else

        # Announce and return failure
        dprint_failure 'Failed to clone Github repository at:' \
          "https://github.com/${user_repo}"
        rm -rf -- "$D_FMWK_DIR"
        return 1

      fi
      
    else

      # Likely unable to connect to repository
      dprint_failure 'Failed to connect to Github repository at:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_FMWK_DIR"
      return 1
    
    fi

  else

    # Git unavailable: download instead

    # Check if tar is available
    tar --version &>/dev/null || {
      dprint_failure 'Failed to detect neither git nor tar' \
        '(at least one is required to install framework)'
      rm -rf -- "$D_FMWK_DIR"
      return 1
    }

    # Attempt curl and Github API
    if grep -q 200 < <( curl -I "https://api.github.com/repos/${user_repo}" \
      2>/dev/null | head -1 )
    then

      # Both curl and remote repo are available

      # Download and untar in one fell swoop
      curl -sL "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$D_FMWK_DIR" -xzf -

      # Check status
      if [ $? -eq 0 ]; then

        # Announce success
        dprint_debug \
          'Downloaded (curl) and extracted tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
      
      else

        # Announce and return failure
        dprint_failure \
          'Failed to download (curl) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_FMWK_DIR"
        return 1

      fi

    # Attempt wget and Github API
    elif grep -q 200 < <( wget -q --spider --server-response \
      "https://api.github.com/repos/${user_repo}" 2>&1 | head -1 ); then

      # Both wget and remote repo are available

      # Download and untar in one fell swoop
      wget -qO - "https://api.github.com/repos/${user_repo}/tarball" \
        | tar --strip-components=1 -C "$D_FMWK_DIR" -xzf -

      # Check status
      if [ $? -eq 0 ]; then

        # Announce success
        dprint_debug \
          'Downloaded (wget) or extracted tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"

      else

        # Announce and return failure
        dprint_failure \
          'Failed to download (wget) or extract tarball repository from:' \
          "https://api.github.com/repos/${user_repo}/tarball"
        rm -rf -- "$D_FMWK_DIR"
        return 1

      fi

    else

      # Either none of the tools were available, or repo does not exist
      dprint_failure 'Failed to clone or download repository from:' \
        "https://github.com/${user_repo}"
      rm -rf -- "$D_FMWK_DIR"
      return 1

    fi
  
  fi

  # Make sure primary script is executable
  if chmod +x "$D_FMWK_DIR/intervene.sh"; then

    # Announce success
    dprint_debug 'Successfully set executable flag for:' \
      "    $D_FMWK_DIR/intervene.sh"

  else

    # Announce failure
    dprint_failure 'Failed to set executable flag for:' \
      "    $D_FMWK_DIR/intervene.sh" 'Please, see to it yourself'

  fi

  # Storage variables
  local dirs_to_create dir_to_create all_good=true

  # Assemble list of directories
  dirs_to_create=( \
    "$D_FMWK_DIR/grail/assets" \
    "$D_FMWK_DIR/grail/dpls" \
    "$D_FMWK_DIR/state/backups" \
    "$D_FMWK_DIR/state/stash" \
    "$D_FMWK_DIR/state/dpl-repos" \
  )

  # Create each directory for future use
  for dir_to_create in "${dirs_to_create[@]}"; do

    # Create directory, or announce failure
    if mkdir -p -- "$dir_to_create"; then
      dprint_debug   "Created directory          : $dir_to_create"
    else
      dprint_failure "Failed to create directory : $dir_to_create"
      all_good=false
    fi

  done

  # Check status of directories
  if $all_good; then
    dprint_debug 'Successfully created internal directories'
  else
    dprint_failure 'Failed to create internal directories'
  fi

  # If gotten here, all is good
  D_STATUS_FRAMEWORK=true
  dprint_success \
    "Successfully installed ${BOLD}Divine.dotfiles${NORMAL} to:" \
    "    $D_FMWK_DIR"
  return 0
}

d__install_shortcut()
{
  # Print empty line for visual separation
  printf >&2 '\n'
  
  # Store long-ass reference in digestible variable
  local cmd="${BOLD}${D_SHORTCUT_NAME}${NORMAL}"

  # Offer to install shortcut
  if dprompt_key "$D_INSTALL_SHORTCUT" 'Install?' \
    "[optional] Shortcut executable command '$cmd'"
  then
    dprint_start "Installing shortcut shell command '$cmd'"
  else
    dprint_skip "Refused to install shortcut shell command '$cmd'"
    return 1
  fi

  # Storage variable
  local new_cmd_name

  # Check if command by that name already exists (including aliases and so on)
  while command -v "$D_SHORTCUT_NAME" &>/dev/null; do

    # If predefined answer is given, no re-tries
    if [ "$D_INSTALL_SHORTCUT" = true ]; then
      dprint_skip \
        "Skipped installing shortcut shell command '$cmd'" \
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
        dprint_skip 'Skipped installing shortcut shell command'
        return 1
      }

      # Check if name is valid
      if ! [[ $new_cmd_name =~ ^[a-z0-9]+$ ]]; then

        # Announce and go for re-try
        printf >&2 '(only lowercase alphanumerical characters are allowed)\n'
        continue

      fi

      # Accept new name and try it on next iteration of the outer loop
      D_SHORTCUT_NAME="$new_cmd_name"
      break
    
    done

  done
  
  # Storage variables
  local shortcut_path shortcut_filepath shortcut_installed=false

  for shortcut_path in "${D_SHORTCUT_DIR_CANDIDATES[@]}"; do

    # Check if shortcut directory exists and is on $PATH
    [[ -d "$shortcut_path" && ":$PATH:" == *":$shortcut_path:"* ]] \
      || {
        dprint_debug "Refusing to install shortcut to: $shortcut_path" \
          '(not a directory or not in $PATH)'
        continue
      }

    # Construct full path
    shortcut_filepath="$shortcut_path/$D_SHORTCUT_NAME"

    # Announce attempt
    dprint_debug "Attempting to install shortcut to: $shortcut_filepath"

    # If file path is occupied, it is likely some namesake directory: skip
    [ -e "$shortcut_filepath" ] && {
      dprint_debug "Refusing to install shortcut to: $shortcut_filepath" \
        '(path is occupied)'
      continue
    }
    
    # Create symlink, or move to next candidate on failure
    if [ -w "$shortcut_path" ]; then

      # Writing permission for directory is granted
      if ln -s -- "$D_FMWK_DIR/intervene.sh" "$shortcut_filepath" \
        &>/dev/null
      then
        shortcut_installed=true; break
      else
        dprint_failure 'Failed to create symlink:' \
          "$shortcut_filepath -> $D_FMWK_DIR/intervene.sh"
      fi

    else

      # No write permission: try sudo

      # Check if password is going to be required
      if ! sudo -n true 2>/dev/null; then
        dprint_start 'Sudo password is required to install shortcut at:' \
          "    $shortcut_filepath"
      fi

      # Do the deed
      if sudo ln -s -- "$D_FMWK_DIR/intervene.sh" \
        "$shortcut_filepath" &>/dev/null
      then
        shortcut_installed=true; break
      else
        dprint_failure 'Failed to create symlink (with sudo):' \
          "$shortcut_filepath -> $D_FMWK_DIR/intervene.sh"
      fi

    fi

  done

  # Re-compose command name (in case it changed)
  cmd="${BOLD}${D_SHORTCUT_NAME}${NORMAL}"

  # Report status
  if $shortcut_installed; then

    # Keep record of installation location
    if d__stash_root_add di_shortcut "$shortcut_filepath"; then
      dprint_debug 'Stored shortcut location in root stash'
    else
      dprint_failure 'Failed to store shortcut location in root stash' \
        'Uninstallation script will be unable to remove shortcut'
    fi

    # Report and return success
    D_STATUS_SHORTCUT=true
    dprint_success \
      "Successfully installed shortcut shell command '$cmd' to:" \
      "    $shortcut_filepath"
    return 0

  else

    # Report and return failure
    dprint_failure "Failed to install shortcut shell command '$cmd'" \
      '(none of the candidate locations would take it)'
    return 1

  fi
}

d__report_summary()
{
  # Print empty line for visual separation
  printf >&2 '\n'

  # Check if framework itself was installed
  if ! $D_STATUS_FRAMEWORK; then

    # Not installed: announce and return failure
    dprint_failure 'Nothing was installed'
    return 1

  fi

  # Compose main command
  local main_cmd
  if $D_STATUS_SHORTCUT; then
    main_cmd="$D_SHORTCUT_NAME"
  else
    main_cmd="$D_FMWK_DIR/intervene.sh"
  fi

  # Announce success
  dprint_success \
    "You can now access ${BOLD}Divine.dotfiles${NORMAL} in shell using:" \
    "    $main_cmd" \
    "Your personal deployments and assets go into Grail directory at:" \
    "    $D_FMWK_DIR/grail" \
    '(It is a good idea to take your Grail under version control)'
  dprint_success \
    "If this is your first time, try our bundled Divine deployments using:" \
    "    $main_cmd attach core" \
    'More info on these at: https://github.com/no-simpler/divine-dpls-core'
  dprint_success \
    "To install/remove attached deployments, use:" \
    "    $main_cmd install" \
    "    $main_cmd remove"
  dprint_success 'Thank you and have a safe and productive day.'

  # Return success
  return 0
}

dprint_debug()
{
  $D_OPT_QUIET && return 0
  printf >&2 "${CYAN}==> %s${NORMAL}\n" "$1"; shift
  while (($#)); do printf >&2 "    ${CYAN}%s${NORMAL}\n" "$1"; shift; done
  return 0
}

dprint_start()
{
  printf >&2 "${BOLD}${YELLOW}==>${NORMAL} %s\n" "$1"; shift
  while (($#)); do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_skip()
{
  printf >&2 "${BOLD}${WHITE}==>${NORMAL} %s\n" "$1"; shift
  while (($#)); do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_success()
{
  printf >&2 "${BOLD}${GREEN}==>${NORMAL} %s\n" "$1"; shift
  while (($#)); do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_failure()
{
  printf >&2 "${BOLD}${RED}==>${NORMAL} %s\n" "$1"; shift
  while (($#)); do printf >&2 '    %s\n' "$1"; shift; done; return 0
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
  printf >&2 '%s %s\n' "${BOLD}${YELLOW}${REVERSE}==>${NORMAL}" "$1"; shift
  while (($#)); do printf >&2 '    %s\n' "$1"; shift; done
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

d__stash_root_add()
{
  # Key variables
  local stash_dirpath="$D_FMWK_DIR/state/stash"
  local stash_filepath="$stash_dirpath/.stash.cfg"
  local stash_md5_filepath="$stash_filepath.md5"

  # Check if root stash file exists
  if [ -e "$stash_filepath" ]; then
    # Stash file exists: check that proper checksum is stored for it
    if ! [ "$( dmd5 "$stash_filepath" )" \
      = "$( head -1 -- "$stash_md5_filepath" 2>/dev/null )" ]
    then
      dprint_failure 'Checksum mismatch on root stash file at:' \
        "    $stash_filepath"
      return 1
    fi
  else
    # No stash file: create fresh one and store its checksum
    touch -- "$stash_filepath"
    dmd5 "$stash_filepath" >"$stash_md5_filepath"
  fi

  # Append record at the end, update stored checksum
  printf '%s\n' "$1=$2" >>"$stash_filepath"
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

d__main "$@"