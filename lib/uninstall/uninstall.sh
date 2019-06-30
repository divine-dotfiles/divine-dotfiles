# Driver function
main()
{
  # Colorize output
  __declare_global_colors

  # Parse arguments
  __parse_arguments "$@"

  # Main removal
  if __locate_installations; then

    # Remove possible stash-recorded Homebrew installation
    __uninstall_homebrew

    # Erase Divine.dotfiles directory
    if __erase_d_dir; then

      # Also, remove shortcut command, if it is present
      __uninstall_shortcut

      # Report success
      dprint_success 'All done'
      return 0

    fi

  fi

  # Report failure
  dprint_failure 'Nothing was removed'
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
  D_OPT_QUIET=false       # Be verbose by default
  D_REMOVE_ALL=           # Whether to perform removal

  # Extract arguments passed to this script (they start at $0)
  local args=( "$0" "$@" ) arg

  # Parse arguments
  for arg in "${args[@]}"; do
    case "$arg" in
      --quiet)            D_OPT_QUIET=true;;
      --verbose)          D_OPT_QUIET=false;;
      --yes)              D_REMOVE_ALL=true;;
      --no)               D_REMOVE_ALL=false;;
      *)                  :;;
    esac
  done
}

__locate_installations()
{
  # Try the usual installation directory unless overridden
  [ -n "$D_INSTALL_PATH" ] || D_INSTALL_PATH="$HOME/.divine"
  dprint_debug "Installation directory: $D_INSTALL_PATH"

  # Rely on existence of ‘intervene.sh’ within the dir
  if [ ! -e "$D_INSTALL_PATH" ]; then
    dprint_debug 'Installation directory does not exist; nothing to remove'
    return 1
  elif [ -f "$D_INSTALL_PATH" ]; then
    dprint_debug 'Installation directory is a file; refusing to touch'
    return 1
  elif [ ! -e "$D_INSTALL_PATH/intervene.sh" ]; then
    dprint_debug 'Installation directory does not resemble Divine.dotfiles'
    return 1
  fi
  
  # Storage variables
  local shortcut_filepath

  # Set global variable
  D_SHORTCUT_FILEPATHS=()

  # Extract user-provided shortcut path
  [ -n "$D_SHORTCUT_FILEPATH" ] \
    && __check_shortcut_filepath "$D_SHORTCUT_FILEPATH" \
    && D_SHORTCUT_FILEPATHS+=( "$D_SHORTCUT_FILEPATH" )

  # Try to figure location of shortcut command
  if dstash_root_get di_shortcut; then

    # Extract stashed record
    shortcut_filepath="$( dstash_root_get di_shortcut )"

    # Check shortcut and add to global variable
    __check_shortcut_filepath "$shortcut_filepath" \
      && D_SHORTCUT_FILEPATHS+=( "$shortcut_filepath" )
  
  else

    # Inform user of stash-related trouble
    dprint_debug \
      'Failed to read record of previously installed shortcut from stash'
    
  fi

  # All done
  return 0
}

__check_shortcut_filepath()
{
  # Extract shortcut filepath
  local shortcut_filepath="$1"

  # Ensure the shortcut path exists and is a symlink
  [ -L "$shortcut_filepath" ] || {
    dprint_debug "Skipping shortcut filepath: $shortcut_filepath" \
      'Not a symlink'
    return 1
  }

  # Ensure the link points to ‘intervene.sh’ (if readlink is available)
  if type -P readlink &>/dev/null; then
    [ "$( readlink -- "$shortcut_filepath" )" \
      = "$D_INSTALL_PATH/intervene.sh" ] \
        || {
          dprint_debug "Skipping shortcut filepath: $shortcut_filepath" \
            'Not pointing to intervene.sh'
          return 1
        }
  fi
}

__uninstall_homebrew()
{
  if dstash_root_get installed_homebrew; then

    ## Homebrew has been previously auto-installed. This could only have 
    #. happened on macOS, so assume macOS environment.

    # Make temp dir for the uninstall script
    local tmpdir=$( mktemp -d )

    # Download script into that directory
    curl -fsSLo "$tmpdir/uninstall" \
      https://raw.githubusercontent.com/Homebrew/install/master/uninstall

    # Make script executable
    chmod +x "$tmpdir/uninstall"
      
    # Execute script
    $tmpdir/uninstall --force

    # Check exit code
    if [ $? -eq 0 ]; then
      dprint_success 'Homebrew has been uninstalled'
    else
      dprint_failure 'Failed to uninstall Homebrew'
    fi

  else

    # Report no record
    dprint_skip 'No record of previously auto-installed Homebrew'

  fi
}

__erase_d_dir()
{
  # Store long-ass reference in digestible name
  local name="${BOLD}Divine.dotfiles${NORMAL}"

  # Offer to uninstall framework
  if dprompt_key "$D_REMOVE_ALL" 'Uninstall?' \
    "${name} Bash framework installed at:" \
    "$D_INSTALL_PATH"
  then
    dprint_start "Uninstalling ${name}"
  else
    dprint_skip "Refused to uninstall ${name}"
    return 1
  fi

  # Straight-forward enough
  rm -rf "$D_INSTALL_PATH" || {
    dprint_debug "Failed to erase directory at: $D_INSTALL_PATH"
    return 1
  }

  # Report success
  dprint_success "Successfully uninstalled ${name} Bash framework from:" \
    "$D_INSTALL_PATH"
  return 0
}

__uninstall_shortcut()
{
  # Iterate over detected shortcut paths
  local shortcut_filepath anything_removed=false errors_encountered=false

  for shortcut_filepath in "${D_SHORTCUT_FILEPATHS[@]}"; do

    # Announce attempt
    dprint_debug "Attempting to remove shortcut command at: $shortcut_filepath"

    # Remove shortcut, using sudo if need be
    if [ -w "$( dirname -- "$shortcut_filepath" )" ]; then
      rm -f "$shortcut_filepath"
    else
      sudo rm -f "$shortcut_filepath"
    fi
    
    # Check if removal went fine
    if [ $? -eq 0 ]; then
      dprint_debug \
        "Successfully removed shortcut command at: $shortcut_filepath"
      anything_removed=true
    else
      dprint_debug "Failed to remove shortcut command at: $shortcut_filepath"
      errors_encountered=true
    fi
    
  done

  # Return status
  if $anything_removed; then
    if $errors_encountered; then
      dprint_failure 'There were problems during removal of shortcut command'
    else
      dprint_success 'Successfully removed shortcut command'
    fi
  else
    if $errors_encountered; then
      dprint_failure 'Failed to remove shortcut command'
    else
      dprint_skip 'No shortcut command to remove'
    fi
  fi
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

  # Print announcement
  printf >&2 '\n%s %s\n' "${BOLD}${YELLOW}${REVERSE}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done

  # Print additional uninstallation-specific warning
  printf >&2 '\n%s %s\n' "${BOLD}${RED}${REVERSE} CAREFUL ${NORMAL}" \
    'This will completely erase installation directory'

  # Print prompt
  printf >&2 '\n%s [y/n] ' \
    "${BOLD}${YELLOW}${REVERSE} ${prompt_text} ${NORMAL}"

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

dstash_root_get()
{
  # Key variables
  local stash_dirpath="$D_INSTALL_PATH/state/stash"
  local stash_filepath="$stash_dirpath/.dstash.cfg"
  local stash_md5_filepath="$stash_filepath.md5"

  # If stash file does not exist, return immediately
  if [ ! -e "$stash_filepath" ]; then
    return 1
  fi

  # Check that stash file has valid checksum
  local calculated_md5="$( dmd5 "$D_STASH_FILEPATH" )"
  local stored_md5="$( head -1 -- "$D_STASH_MD5_FILEPATH" 2>/dev/null )"
  [ "$calculated_md5" = "$stored_md5" ] || return 1

  # Check if requested key exists
  if grep -q ^"$1"= -- "$stash_filepath" &>/dev/null; then
    local value
    value="$( grep ^"$1"= -- "$stash_filepath" 2>/dev/null \
      | head -1 2>/dev/null )"
    value="${value#$1=}"
    printf '%s\n' "$value"
  else
    return 1
  fi
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