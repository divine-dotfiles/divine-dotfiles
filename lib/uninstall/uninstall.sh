#!/usr/bin/env bash
#:title:        Divine.dotfiles fmwk uninstall script
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    34
#:revdate:      2019.07.29
#:revremark:    Add newline before main output
#:created_at:   2019.07.22

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This script uninstalls the framework and optional components
#

# Driver function
d__main()
{
  # Colorize output
  d__declare_global_colors

  # Parse arguments
  d__parse_arguments "$@"

  # Main removal
  if d__locate_installations; then

    ## Pre-removal tasks:
    #.  * Run removal routine on all installed deployments
    #.  * Remove possible stash-recorded Homebrew installation
    #.  * Remove possible stash-recorded optional utility installations
    if ! d__remove_all_dpls \
      || ! d__uninstall_homebrew \
      || ! d__uninstall_utils
    then
      dprint_failure 'Terminating uninstallation'
      return 1
    fi

    # Erase Divine.dotfiles directory
    if d__erase_d_dir; then

      # Also, remove shortcut command, if it is present
      d__uninstall_shortcut

      # Report success
      dprint_success 'All done'
      return 0

    fi

  fi

  # Report failure
  dprint_failure 'Nothing was removed'
  return 1
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
  # Define global storage for option values
  D_QUIET=false       # Be verbose by default
  D_QUIETREMOVE_FMWK=          # Whether to perform removal of framework
  D_REMOVE_UTILS=         # Whether to perform removal of utils
  D_REMOVE_BREW=          # Whether to perform removal of Homebrew
  D_RUN_REMOVE_ALL=       # Whether to attempt to remove all deployments

  # Extract arguments passed to this script (they start at $0)
  local args=( "$0" "$@" ) arg

  # Parse arguments
  for arg in "${args[@]}"; do
    case "$arg" in
      --quiet)            D_QUIET=true;;
      --verbose)          D_QUIET=false;;
      --framework-yes)    D_REMOVE_FMWK=true;;
      --framework-no)     D_REMOVE_FMWK=false;;
      --utils-yes)        D_REMOVE_UTILS=true;;
      --utils-no)         D_REMOVE_UTILS=false;;
      --brew-yes)         D_REMOVE_BREW=true;;
      --brew-no)          D_REMOVE_BREW=false;;
      --run-remove-yes)   D_RUN_REMOVE_ALL=true;;
      --run-remove-no)    D_RUN_REMOVE_ALL=false;;
      --yes)              D_REMOVE_FMWK=true
                          D_REMOVE_UTILS=true
                          D_REMOVE_BREW=true
                          D_RUN_REMOVE_ALL=true
                          ;;
      --no)               D_REMOVE_FMWK=false
                          D_REMOVE_UTILS=false
                          D_REMOVE_BREW=false
                          D_RUN_REMOVE_ALL=false
                          ;;
      *)                  :;;
    esac
  done
}

d__locate_installations()
{
  # Print empty line for visual separation
  printf >&2 '\n'
  
  # Try the usual installation directory unless overridden
  [ -n "$D_INSTALL_PATH" ] || D_INSTALL_PATH="$HOME/.divine"
  dprint_debug "Installation directory: $D_INSTALL_PATH"

  # Announce start
  dprint_start 'Collecting information about Divine.dotfiles installation'

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
    && d__check_shortcut_filepath "$D_SHORTCUT_FILEPATH" \
    && D_SHORTCUT_FILEPATHS+=( "$D_SHORTCUT_FILEPATH" )

  # Try to figure location of shortcut command
  if d__stash_root_get di_shortcut &>/dev/null; then

    # Extract stashed record
    shortcut_filepath="$( d__stash_root_get di_shortcut )"

    # Check shortcut and add to global variable
    d__check_shortcut_filepath "$shortcut_filepath" \
      && D_SHORTCUT_FILEPATHS+=( "$shortcut_filepath" )
  
  else

    # Inform user of stash-related trouble
    dprint_debug \
      'Failed to read record of previously installed shortcut from stash'
    
  fi

  # Report and return
  dprint_success \
    'Successfully collected information about Divine.dotfiles installation'
  return 0
}

d__check_shortcut_filepath()
{
  # Extract shortcut filepath
  local shortcut_filepath="$1"

  # Ensure the shortcut path exists and is a symlink
  if ! [ -L "$shortcut_filepath" ]; then
    dprint_debug "Skipping shortcut filepath: $shortcut_filepath" \
      'Not a symlink'
    return 1
  fi

  # Ensure the link points to ‘intervene.sh’ (if readlink is available)
  if type -P readlink &>/dev/null; then
    if ! [ "$( readlink -- "$shortcut_filepath" )" \
      = "$D_INSTALL_PATH/intervene.sh" ]
    then
      dprint_debug "Skipping shortcut filepath: $shortcut_filepath" \
        'Not pointing to intervene.sh'
      return 1
    fi
  fi
}

d__remove_all_dpls()
{
  # Offer to remove deployments
  dprompt_key "$D_RUN_REMOVE_ALL" --or-quit 'Remove?' \
    '[optional] Run removal routine' \
    'Framework will run removal routine on all deployments currently present'

  # Check exit status
  case $? in
    0)  dprint_start 'Running removal routine on all deployments';;
    1)  dprint_skip 'Refused to run removal routine on all deployments'
        return 0
        ;;
    *)  dprint_skip 'Refused to run removal routine on all deployments'
        return 1
        ;;
  esac

  # Run installation
  if $D_QUIET; then
    if [ "$D_RUN_REMOVE_ALL" = true ]; then
      "$D_INSTALL_PATH"/intervene.sh remove --with-! --yes
    else
      "$D_INSTALL_PATH"/intervene.sh remove --with-!
    fi
  else
    if [ "$D_RUN_REMOVE_ALL" = true ]; then
      "$D_INSTALL_PATH"/intervene.sh remove --with-! --yes --verbose
    else
      "$D_INSTALL_PATH"/intervene.sh remove --with-! --verbose
    fi
  fi

  # Report status
  if [ $? -eq 0 ]; then
    dprint_success 'Successfully removed all current deployments'
  else
    dprint_failure 'Failed to remove all current deployments'
  fi

  # Is user happy?
  dprompt_key "$D_RUN_REMOVE_ALL" 'Proceed with uninstallation?' \
    'Please, confirm whether previous stage ran satisfactory'

  # Return status based on user’s choice
  return $?
}

d__uninstall_homebrew()
{
  # Check stash records
  if ! d__stash_root_get installed_homebrew &>/dev/null; then
    # No record of Homebrew installation: silently return a-ok
    return 0
  fi

  # Offer to remove Homebrew
  dprompt_key "$D_REMOVE_BREW" --or-quit 'Remove?' \
    '[optional] Remove Homebrew' \
    'Detected Homebrew that has been installed by this framework'

  # Check exit status
  case $? in
    0)  dprint_start 'Removing Homebrew';;
    1)  dprint_skip 'Refused to remove Homebrew'
        return 0
        ;;
    *)  dprint_skip 'Refused to remove Homebrew'
        return 1
        ;;
  esac

  ## Homebrew has been previously auto-installed. This could only have 
  #. happened on macOS, so assume macOS environment.

  # Make temp dir for the uninstall script
  local tmpdir=$( mktemp -d )

  # Download script into that directory
  if curl -fsSLo "$tmpdir/uninstall" \
    https://raw.githubusercontent.com/Homebrew/install/master/uninstall
  then

    # Make script executable
    if chmod +x "$tmpdir/uninstall"; then

      # Execute script with verbosity in mind
      if $D_QUIET; then

        # Run script quietly
        $tmpdir/uninstall --force &>/dev/null

      else

        # Run script normally, but re-paint output
        local line
        $tmpdir/uninstall --force 2>&1 \
          | while IFS= read -r line || [ -n "$line" ]; do
            printf "${CYAN}==> %s${NORMAL}\n" "$line"
          done

      fi

      # Report status
      if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        dprint_success 'Successfully removed Homebrew'
      else
        dprint_failure 'Failed to remove Homebrew'
      fi

    else

      dprint_failure \
        'Failed to set executable flag on Homebrew uninstallation script'

    fi

  else
      dprint_failure 'Failed to download Homebrew uninstallation script'
  fi

  # Is user happy?
  dprompt_key "$D_REMOVE_BREW" 'Proceed with uninstallation?' \
    'Please, confirm whether previous stage ran satisfactory'

  # Return status based on user’s choice
  return $?
}

d__uninstall_utils()
{
  # Check stash records
  if ! d__stash_root_get installed_util &>/dev/null; then
    # No record of utility installations: silently return a-ok
    return 0
  fi

  # Offer to remove deployments
  dprompt_key "$D_REMOVE_UTILS" --or-quit 'Remove?' \
    '[optional] Remove optional utilities' \
    'Detected optional utilities that have been installed by this framework'

  # Check exit status
  case $? in
    0)  dprint_start 'Removing optional utilities';;
    1)  dprint_skip 'Refused to remove optional utilities'
        return 0
        ;;
    *)  dprint_skip 'Refused to remove optional utilities'
        return 1
        ;;
  esac

  # Run removal
  if $D_QUIET; then
    if [ "$D_REMOVE_UTILS" = true ]; then
      "$D_INSTALL_PATH"/intervene.sh cecf357ed9fed1037eb906633a4299ba --yes
    else
      "$D_INSTALL_PATH"/intervene.sh cecf357ed9fed1037eb906633a4299ba
    fi
  else
    if [ "$D_REMOVE_UTILS" = true ]; then
      "$D_INSTALL_PATH"/intervene.sh cecf357ed9fed1037eb906633a4299ba \
        --yes --verbose
    else
      "$D_INSTALL_PATH"/intervene.sh cecf357ed9fed1037eb906633a4299ba \
        --verbose
    fi
  fi

  # Report status
  if [ $? -eq 0 ]; then
    dprint_success 'Successfully removed optional utilities'
  else
    dprint_failure 'Failed to remove optional utilities'
  fi

  # Is user happy?
  dprompt_key "$D_REMOVE_UTILS" 'Proceed with uninstallation?' \
    'Please, confirm whether previous stage ran satisfactory'

  # Return status based on user’s choice
  return $?
}

d__erase_d_dir()
{
  # Store long-ass reference in digestible name
  local name="${BOLD}Divine.dotfiles${NORMAL}"

  # Offer to uninstall framework
  if dprompt_key "$D_REMOVE_FMWK" --main-rm 'Uninstall?' \
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
    dprint_failure "Failed to erase directory at: $D_INSTALL_PATH"
    return 1
  }

  # Report success
  dprint_success "Successfully uninstalled ${name} Bash framework from:" \
    "$D_INSTALL_PATH"
  return 0
}

d__uninstall_shortcut()
{
  # Announce start
  if [ ${#D_SHORTCUT_FILEPATHS[@]} -gt 0 ]; then
    dprint_start 'Removing shortcut command'
  fi

  # Iterate over detected shortcut paths
  local shortcut_filepath anything_removed=false errors_encountered=false
  local shortcut_dirpath

  for shortcut_filepath in "${D_SHORTCUT_FILEPATHS[@]}"; do

    # Announce attempt
    dprint_debug "Attempting to remove shortcut command at: $shortcut_filepath"

    # Extract dirpath
    shortcut_dirpath="$( dirname -- "$shortcut_filepath" )"

    # Remove shortcut, using sudo if need be
    if [ -w "$shortcut_dirpath" ]; then
      rm -f "$shortcut_filepath"
    else
      if ! sudo -n true 2>/dev/null; then
        dprint_start "Removing within $shortcut_dirpath requires sudo password"
      fi
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
  $D_QUIET && return 0
  printf >&2 "${CYAN}%s %s${NORMAL}\n" "==>" "$1"; shift
  while [ $# -gt 0 ]
  do printf >&2 "    ${CYAN}%s${NORMAL}\n" "$1"; shift; done; return 0
}

dprint_start()
{
  printf >&2 '%s %s\n' "${BOLD}${YELLOW}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_skip()
{
  printf >&2 '%s %s\n' "${BOLD}${WHITE}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_success()
{
  printf >&2 '%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprint_failure()
{
  printf >&2 '%s %s\n' "${BOLD}${RED}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done; return 0
}

dprompt_key()
{
  # Extract predefined answer
  local predefined_answer="$1"; shift
  local main_rm=false; [ "$1" = '--main-rm' ] && { main_rm=true; shift; }
  local or_quit=false; [ "$1" = '--or-quit' ] && { or_quit=true; shift; }

  # Check predefined answer
  if [ "$predefined_answer" = true ]; then return 0
  elif [ "$predefined_answer" = false ]; then return 1
  fi

  # Extract prompt text
  local prompt_text="$1"; shift

  # Status variable
  local yes=false

  # Print announcement
  printf >&2 '%s %s\n' "${BOLD}${YELLOW}${REVERSE}==>${NORMAL}" "$1"; shift
  while [ $# -gt 0 ]; do printf >&2 '    %s\n' "$1"; shift; done

  # Print additional uninstallation-specific warning
  $main_rm && \
    printf >&2 '%s %s\n' "${BOLD}${RED}${REVERSE} CAREFUL ${NORMAL}" \
      'This will completely erase installation directory'

  # Print prompt
  local choices
  $or_quit && choices+=' [y/n/q]' || choices+=' [y/n]'
  printf >&2 "%s $choices " \
    "${BOLD}${YELLOW}${REVERSE} ${prompt_text} ${NORMAL}"

  # Await answer
  while true; do
    read -rsn1 input
    [[ $input =~ ^(y|Y)$ ]] && { printf >&2 'y'; yes=true;  break; }
    [[ $input =~ ^(n|N)$ ]] && { printf >&2 'n'; yes=false; break; }
    $or_quit && [[ $input =~ ^(q|Q)$ ]] && { printf >&2 'q'; return 2; }
  done
  printf >&2 '\n'

  # Check answer
  if $yes; then return 0; else return 1; fi
}

d__stash_root_get()
{
  # Key variables
  local stash_dirpath="$D_INSTALL_PATH/state/stash"
  local stash_filepath="$stash_dirpath/.stash.cfg"
  local stash_md5_filepath="$stash_filepath.md5"

  # If stash file does not exist, return immediately
  if [ ! -e "$stash_filepath" ]; then return 1; fi

  # Check that stash file has valid checksum
  local calculated_md5="$( dmd5 "$stash_filepath" )"
  local stored_md5="$( head -1 -- "$stash_md5_filepath" 2>/dev/null )"
  [ "$calculated_md5" = "$stored_md5" ] || return 1

  # Check if requested key exists and print it if it is
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

d__main "$@"