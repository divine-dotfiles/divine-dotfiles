# Driver function
main()
{
  # Colorize output
  __declare_global_colors

  # Status variable
  local removal_successful=false

  # Main removal
  if __locate_installations; then
    # Erase Divine.dotfiles directory
    if __erase_d_dir; then
      # Also, remove shortcut command, if it is present
      __uninstall_shortcut
      # Report success
      printf >&2 '\n%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" 'Glowing success'
      return 0
    fi
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
  if [ -t 1] && [ -n "$num_of_colors" ] && [ "$num_of_colors" -ge 8 ]; then
    RED="$( tput setaf 1 )"
    GREEN="$( tput setaf 2 )"
    YELLOW="$( tput setaf 3 )"
    WHITE="$( tput setaf 7 )"
    BOLD="$( tput bold )"
    REVERSE="$( tput rev )"
    NORMAL="$( tput sgr0 )"
  else
    RED=''
    GREEN=''
    YELLOW=''
    WHITE=''
    BOLD=''
    REVERSE=''
    NORMAL=''
  fi
}

__locate_installations()
{
  # Try the usual installation directory unless overridden
  [ -n "$D_DIR" ] || D_DIR="$HOME/.divine"

  # Rely on existence of ‘intervene.sh’ within the dir
  [ -f "${D_DIR}/intervene.sh" ] || {
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Failed to recognize Divine.dotfiles insatllation directory at:"
      "$D_DIR"
    return 1
  }
  
  # Storage variables
  local shortcut_memo_path="$D_DIR/lib/uninstall/shortcut-location"
  local shortcut_filepath

  # Try to figure location of shortcut command
  if [ -f "$shortcut_memo_path" ]; then

    # Read stored memo
    shortcut_filepath="$( cat "$shortcut_memo_path" | head -1 )"

    # Ensure the shortcut path exists and is a symlink
    [ -x "$shortcut_filepath" -a -L "$shortcut_filepath" ] || return 0

    # Ensure the link points to ‘intervene.sh’
    [ "$( readlink -- "$shortcut_filepath" )" = "$D_DIR/intervene.sh" ] \
      || return 0

    # Set global variable
    D_SHORTCUT_FILEPATH="$shortcut_filepath"
    
  fi

  # All done
  return 0
}

__uninstall_shortcut()
{
  # Straight-forward enough
  rm -f "$D_SHORTCUT_FILEPATH" || {
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to uninstall shortcut command at:' \
      "$D_SHORTCUT_FILEPATH"
    return 1
  }

  # Report success
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully uninstalled shortcut command at:'
    "$D_SHORTCUT_FILEPATH"
  return 0
}

__erase_d_dir()
{
  # Offer to uninstall framework
  local yes=false
  printf >&2 '\n%s %s\n  %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "${BOLD}Divine.dotfiles${NORMAL} Bash framework installed at:"
    "$D_DIR"
  printf >&2 '%s %s\n' \
    "${BOLD}${RED}${REVERSE} CAREFUL ${NORMAL}" \
    'This will completely erase installation directory'
  printf >&2 'Uninstall? [y/n] '

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
      "${BOLD}${WHITE}==>${NORMAL}" \
      "Refused to uninstall ${BOLD}Divine.dotfiles${NORMAL}"
    return 1
  }

  # Straight-forward enough
  rm -rf "$D_DIR" || {
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to erase directory at:' \
      "$D_DIR"
    return 1
  }

  # Report success
  printf >&2 '\n%s %s %s\n  %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully uninstalled' \
    "${BOLD}Divine.dotfiles${NORMAL} Bash framework from:"
    "$D_DIR"
  return 0
}

main