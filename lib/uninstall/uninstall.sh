#!/usr/bin/env bash
#:title:        Divine.dotfiles fmwk uninstall script
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    37
#:revdate:      2019.08.05
#:revremark:    Rearrange intro message
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
  if d__pre_flight_checks \
    && d__confirm_uninstallation \
    && d__uninstall_utils \
    && d__make_backup \
    && d__erase_d_dir
  then

    # Optional: uninstall shortcut command
    d__uninstall_shortcut

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
  # Define global storage for option values
  D_OPT_QUIET=true        # Be quiet by default
  D_REMOVE_FMWK=          # Whether to perform removal of framework
  D_REMOVE_UTILS=         # Whether to perform removal of utils
  D_MAKE_BACKUP=          # Whether to leave backup of non-fmwk files

  # Extract arguments passed to this script (they start at $0)
  local args=( "$0" "$@" ) arg

  # Parse arguments
  for arg in "${args[@]}"; do
    case "$arg" in
      --quiet)            D_OPT_QUIET=true;;
      --verbose)          D_OPT_QUIET=false;;
      --framework-yes)    D_REMOVE_FMWK=true;;
      --framework-no)     D_REMOVE_FMWK=false;;
      --utils-yes)        D_REMOVE_UTILS=true;;
      --utils-no)         D_REMOVE_UTILS=false;;
      --backup-yes)       D_MAKE_BACKUP=true;;
      --backup-no)        D_MAKE_BACKUP=false;;
      --yes)              D_REMOVE_FMWK=true
                          D_REMOVE_UTILS=true
                          D_MAKE_BACKUP=true
                          ;;
      --no)               D_REMOVE_FMWK=false
                          D_REMOVE_UTILS=false
                          D_MAKE_BACKUP=false
                          ;;
      *)                  :;;
    esac
  done
}

d__pre_flight_checks()
{
  # Global variables for installation status
  D_STATUS_FRAMEWORK=
  D_STATUS_UTILS=
  D_STATUS_BACKUP=
  D_BACKUP_LOCATION=
  D_STATUS_SHORTCUT=

  # Return early if framework is not to be uninstalled
  [ "$D_REMOVE_FMWK" = false ] && return 1

  # Status variable
  local newline_printed=false

  # Print empty line for visual separation
  $D_OPT_QUIET || { printf >&2 '\n'; newline_printed=true; }

  # Check if framework directory is overridden
  if [ -n "$D_FMWK_DIR" ]; then

    # Use user-provided framework directory
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_start "Overridden framework directory: $D_FMWK_DIR"
    D_STATUS_FRAMEWORK=false

  else
  
    # Use default framework directory
    D_FMWK_DIR="$HOME/.divine"
    dprint_debug "Framework directory: $D_FMWK_DIR"
    D_STATUS_FRAMEWORK=false
  
  fi

  # Check if stash has record of shortcut installation
  if d__stash_root has di_shortcut; then

    # Extract stashed record into global variable
    D_SHORTCUT_FILEPATH="$( d__stash_root -s get di_shortcut )"

    # Check if it is the same as user-provided location
    if [ -n "$D_SHORTCUT_FILEPATH" ]; then

      # Announce the find
      dprint_debug \
        "Recorded location of shortcut: $D_SHORTCUT_FILEPATH"
      D_STATUS_SHORTCUT=false

    else

      # Announce the lack of find
      $newline_printed || { printf >&2 '\n'; newline_printed=true; }
      dprint_failure 'Record of previously installed shortcut is empty'
      D_STATUS_SHORTCUT=empty

    fi

  else

    # Announce lack of record
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_failure 'Failed to find record of previously installed shortcut'
    D_STATUS_SHORTCUT=empty

  fi

  # Collect names of optionally installed utils
  D_INSTALLED_UTIL_NAMES=()

  # Check if there is record of Homebrew installation
  if d__stash_root -s has installed_homebrew; then

    # Set preliminary status, add to global list, report
    D_STATUS_UTILS=false
    D_INSTALLED_UTIL_NAMES+=( brew )
    dprint_debug 'Detected Homebrew installation'

  fi

  # Check if there is record of system utility installations
  if d__stash_root -s has installed_util; then

    # Collect util names into global list
    local util_name
    while read -r util_name; do D_INSTALLED_UTIL_NAMES+=( "$util_name" )
    done < <( d__stash_root -s list installed_util )

    # Set preliminary status, report
    D_STATUS_UTILS=false
    dprint_debug 'Detected optional system utility installations'

  fi

  # Status variable for assembled globals
  all_good=true
  
  # Verify eligibility of installation directory
  if [ ! -e "$D_FMWK_DIR" ]; then

    # Framework path does not exist: announce and set failure flag
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_failure 'Framework path does not exist:' \
      "    $D_FMWK_DIR" \
      'Nothing to uninstall'
    all_good=false
    D_STATUS_FRAMEWORK=empty

  elif ! [ -d "$D_FMWK_DIR" -a -w "$D_FMWK_DIR" ]; then

    # Framework path is not a directory: announce and set failure flag
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_failure 'Framework path is not a removable directory:' \
      "    $D_FMWK_DIR" \
      'Refusing to uninstall'
    all_good=false
    D_STATUS_FRAMEWORK=empty

  elif [ ! -e "$D_FMWK_DIR/intervene.sh" ]; then

    # Framework path lacks main script: announce and set failure flag
    $newline_printed || { printf >&2 '\n'; newline_printed=true; }
    dprint_failure 'Framework directory does not contain main script:' \
      "    $D_FMWK_DIR/intervene.sh" \
      'Refusing to uninstall'
    all_good=false
    D_STATUS_FRAMEWORK=empty

  else

    # Check if making backup is not disabled
    if [ "$D_MAKE_BACKUP" != false ]; then

      # Compose default backup location
      D_BACKUP_LOCATION="$D_FMWK_DIR-backup"

      # Check if that backup location is occupied
      if [ -e "$D_BACKUP_LOCATION" ]; then

        # Location occupied: try alternatives
        local i=1
        while ((i<=1000)); do
          if [ -e "${D_BACKUP_LOCATION}${i}" ]; then
            ((++i))
          else
            D_BACKUP_LOCATION="${D_BACKUP_LOCATION}${i}"
            break
          fi
        done

      fi

      # Check if settled on unoccupied location
      if [ -e "$D_BACKUP_LOCATION" ]; then

        # Could not find unoccupied location: erase var and announce
        D_BACKUP_LOCATION=
        D_STATUS_BACKUP=error
        $newline_printed || { printf >&2 '\n'; newline_printed=true; }
        dprint_failure 'Unable to find location for backup at:' \
          "    $D_FMWK_DIR-backup*" \
          '(all potential locations are occupied)'
        if [ "$D_MAKE_BACKUP" = true ]; then
          all_good=false
        else
          D_MAKE_BACKUP=false
        fi

      else

        # Settled on backup location
        D_STATUS_BACKUP=false
        dprint_debug "Location of potential backup: $D_BACKUP_LOCATION"

      fi

    fi

  fi

  # Check if stash record of shortcut installation was extracted
  if [ "$D_STATUS_SHORTCUT" = false ]; then

    # Ensure the shortcut path exists and is a symlink
    if ! [ -L "$D_SHORTCUT_FILEPATH" ]; then

      # Announce and skip
      $newline_printed || { printf >&2 '\n'; newline_printed=true; }
      dprint_failure 'Recorded shortcut path is illegal; skipping:' \
        "    $D_SHORTCUT_FILEPATH" \
        '(not a symlink)'
      D_STATUS_SHORTCUT=illegal

    fi

    # Ensure the link points to ‘intervene.sh’ (if readlink is available)
    if type -P readlink &>/dev/null \
      && ! [ "$( readlink -- "$D_SHORTCUT_FILEPATH" )" \
      = "$D_FMWK_DIR/intervene.sh" ]
    then

      # Announce and skip
      $newline_printed || { printf >&2 '\n'; newline_printed=true; }
      dprint_failure 'Recorded shortcut path is illegal; skipping:' \
        "    $D_SHORTCUT_FILEPATH" \
        '(not pointing to intervene.sh)'
      D_STATUS_SHORTCUT=illegal

    fi

  fi

  # Return appropriately
  $all_good && return 0 || return 1
}

d__confirm_uninstallation()
{
  # Print empty line for visual separation
  printf >&2 '\n'

  # Storage variable
  local report_lines=()
  
  # Print general intro
  report_lines+=( \
    "This will remove ${BOLD}Divine.dotfiles${NORMAL} located at:" \
    "    $D_FMWK_DIR" \
  )

  # Print shortcut-related info
  case $D_STATUS_SHORTCUT in
    false)
      report_lines+=( \
        'and its shortcut shell command at:' \
        "    $D_SHORTCUT_FILEPATH" \
      )
      ;;
    empty)
      report_lines+=( \
        'without touching shortcut shell command, which appears absent' \
      )
      ;;
    illegal)
      report_lines+=( \
        'without touching illegal shortcut shell command at:' \
        "    $D_SHORTCUT_FILEPATH" \
      )
      ;;
    *)
      report_lines+=( \
        'without touching shortcut shell command' \
      )
      ;;
  esac

  # Print backup-related intro
  case $D_MAKE_BACKUP in
    true)
      report_lines+=( \
        'Potentially valuable files will be backed up to:' \
        "    $D_BACKUP_LOCATION" \
      )
      ;;
    false)
      report_lines+=( \
        "$RED$REVERSE$BOLD All files will be removed without backup! $NORMAL" \
      )
      ;;
    *)
      report_lines+=( \
        'You will be prompted to back up potentially valuable files to:' \
        "    $D_BACKUP_LOCATION" \
      )
      ;;
  esac

  # Print utils-related intro
  if [ "$D_STATUS_UTILS" = false ]; then

    # Compose human-readable list of utilities
    local list_of_util_names="$D_INSTALLED_UTIL_NAMES" i
    for (( i=1; i<${#D_INSTALLED_UTIL_NAMES[@]}; i++ )); do
      list_of_util_names+=", ${D_INSTALLED_UTIL_NAMES[$i]}"
    done
    case $D_REMOVE_UTILS in
      true)
        report_lines+=( \
          'System utilities installed by the framework will be uninstalled:' \
          "    $list_of_util_names" \
        )
        ;;
      false)
        report_lines+=( \
          'System utilities installed by the framework will remain:' \
          "    $list_of_util_names" \
        )
        ;;
      *)
        local long_line='You will be prompted to uninstall'
        long_line+='system utilities installed by the framework:'
        report_lines+=( \
          "$long_line" \
          "    $list_of_util_names" \
        )
        ;;
    esac
  fi

  # Print uninstallation suggestion
  if [ "$D_MAKE_BACKUP" != true ] \
    || [ -z "$D_REMOVE_FMWK" -o -z "$D_MAKE_BACKUP" ]
  then

    # Compose uninstall command
    local cmd
    if [ "$D_STATUS_SHORTCUT" = false ]; then
      cmd="$( basename -- "$D_SHORTCUT_FILEPATH" )"
    else
      cmd="$D_FMWK_DIR/intervene.sh"
    fi
    cmd+=' remove'

    # Suggest uninstalling deployments first
    report_lines+=( \
      'Please, consider first uninstalling current deployments using:' \
      "    $cmd" \
    )

  fi

  # Prompt user
  if dprompt_key "$D_REMOVE_FMWK" 'Uninstall Divine.dotfiles?' \
    "${report_lines[@]}"
  then
    dprint_debug "Proceeding to uninstall ${BOLD}Divine.dotfiles${NORMAL}"
    return 0
  else
    dprint_skip "Refused to uninstall ${BOLD}Divine.dotfiles${NORMAL}"
    return 1
  fi
}

d__uninstall_utils()
{
  # Check if utils are staged for uninstallation
  if ! [ "$D_STATUS_UTILS" = false ]; then
    # No record of utility installations: silently return a-ok
    return 0
  fi

  # Print empty line for visual separation
  printf >&2 '\n'

  # Offer to uninstall utilities
  if dprompt_key "$D_REMOVE_UTILS" 'Uninstall?' \
    '[optional] Uninstall system utilities installed by the framework'
  then
    dprint_start 'Uninstalling system utilities installed by the framework'
  else
    dprint_skip \
      'Refused to uninstall system utilities installed by the framework'
    return 0
  fi

  # Run removal
  if $D_OPT_QUIET; then
    if [ "$D_REMOVE_UTILS" = true ]; then
      "$D_FMWK_DIR"/intervene.sh cecf357ed9fed1037eb906633a4299ba --yes
    else
      "$D_FMWK_DIR"/intervene.sh cecf357ed9fed1037eb906633a4299ba
    fi
  else
    if [ "$D_REMOVE_UTILS" = true ]; then
      "$D_FMWK_DIR"/intervene.sh cecf357ed9fed1037eb906633a4299ba \
        --yes --verbose
    else
      "$D_FMWK_DIR"/intervene.sh cecf357ed9fed1037eb906633a4299ba \
        --verbose
    fi
  fi

  # Report status
  case $? in
    0)
      D_UNINSTALLED_UTIL_NAMES=( "${D_INSTALLED_UTIL_NAMES[@]}" )
      D_INSTALLED_UTIL_NAMES=()
      dprint_success \
        'Successfully uninstalled system utilities installed by the framework'
      D_STATUS_UTILS=true
      return 0
      ;;
    1)
      # Storage variables
      local tmp="${D_INSTALLED_UTIL_NAMES[@]}" i j

      # Collect names of currently still available utilities
      D_INSTALLED_UTIL_NAMES=()

      # Check if there is still a record of Homebrew installation
      if d__stash_root -s has installed_homebrew; then
        D_INSTALLED_UTIL_NAMES+=( brew )
      fi

      # Check if there are still records of system utility installations
      if d__stash_root -s has installed_util; then

        # Collect util names into global list
        local util_name
        while read -r util_name; do D_INSTALLED_UTIL_NAMES+=( "$util_name" )
        done < <( d__stash_root -s list installed_util )

      fi

      # Make list of uninstalled ones
      D_UNINSTALLED_UTIL_NAMES=()
      for i in "${tmp[@]}"; do
        for j in "${D_INSTALLED_UTIL_NAMES[@]}"; do
          [[ $i = $j ]] && continue 2
        done
        D_UNINSTALLED_UTIL_NAMES+=( "$i" )
      done

      # Report and return
      dprint_failure \
        'Failed to uninstall some system utilities installed by the framework'
      D_STATUS_UTILS=error
      return 1
      ;;
    *)
      dprint_failure \
        'Failed to uninstall system utilities installed by the framework'
      D_STATUS_UTILS=error
      return 1
      ;;
  esac
}

d__make_backup()
{
  # Check if backup location is staged
  if [ -z "$D_BACKUP_LOCATION" ]; then
    # No backup location prepared, silently return
    return 0
  fi

  # Print empty line for visual separation
  printf >&2 '\n'

  # Offer to make backup
  if dprompt_key "$D_MAKE_BACKUP" 'Make backup?' \
    '[optional] Retain backup of potentially valuable files'
  then
    dprint_start 'Backing up potentially valuable files'
  else
    dprint_skip 'Refused to back up potentially valuable files'
    return 0
  fi

  # Make temporary location
  local tmpdir="$( mktemp -d )"

  # Status variable
  local something_backed_up=false all_good=true

  # Check if Grail dir exists
  if [ -d "$D_FMWK_DIR/grail" ]; then

    # Move grail directory to temp location
    if mv -n -- "$D_FMWK_DIR/grail" "$tmpdir/grail"; then

      # Successfully moved: leave record
      dprint_debug "Backed up: $D_FMWK_DIR/grail"
      something_backed_up=true

    else

      # Failed to move to backup location
      dprint_failure 'Failed to move Grail directory from:' \
        "    $D_FMWK_DIR/grail" \
        'to temporary location at:' \
        "    $tmpdir/grail"
      all_good=false

    fi

  fi
  
  # Check if state dir exists
  if [ -d "$D_FMWK_DIR/state" ]; then

    # Move state directory to temp location
    if mv -n -- "$D_FMWK_DIR/state" "$tmpdir/state"; then

      # Successfully moved: leave record
      dprint_debug "Backed up: $D_FMWK_DIR/state"
      something_backed_up=true

    else

      # Failed to move to backup location
      dprint_failure 'Failed to move state directory from:' \
        "    $D_FMWK_DIR/state" \
        'to temporary location at:' \
        "    $tmpdir/state"
      all_good=false

    fi

  fi

  # Check if everything went good
  if $all_good; then

    # Check if anything has been backed up
    if $something_backed_up; then

      # Move temporary directory into place
      if mv -n -- "$tmpdir" "$D_BACKUP_LOCATION"; then

        # Success: announce and return
        dprint_success \
          'Successfully backed up potentially valuable files to:' \
          "    $D_BACKUP_LOCATION"
        rm -rf -- "$tmpdir"
        D_STATUS_BACKUP=true
        return 0

      else

        # Failure: announce, clear backup location, return
        dprint_failure 'Failed to move potentially valuable files' \
          'from temporary directory at:' "    $tmpdir" \
          'to backup location at:' "    $D_BACKUP_LOCATION"
        D_STATUS_BACKUP=error
        return 1

      fi

    else

      # There was nothing to back up: announce skip, return success
      dprint_skip 'There were no potentially valuable files to back up'
      rm -rf -- "$tmpdir"
      return 0

    fi
  
  else

    # Failed to back up at least one directory: announce, clear path, return
    dprint_failure 'Failed to back up potentially valuable files'
    D_STATUS_BACKUP=error
    return 1

  fi
}

d__erase_d_dir()
{
  # Print empty line for visual separation
  printf >&2 '\n'

  # Announce start
  dprint_start 'Removing framework directory'

  # Remove framework directory
  if rm -rf -- "$D_FMWK_DIR"; then

    # Announce success, mark status, return
    dprint_success "Successfully removed framework directory at:" \
      "$D_FMWK_DIR"
    D_STATUS_FRAMEWORK=true
    return 0

  else

    # Announce and return failure
    dprint_failure "Failed to remove framework directory at:" \
      "$D_FMWK_DIR"
    D_STATUS_FRAMEWORK=error
    return 1

  fi
}

d__uninstall_shortcut()
{
  # Check if shortcut filepath is staged for removal
  if ! [ "$D_STATUS_SHORTCUT" = false ]; then
    # Nothing to remove: silently return
    return 0
  fi

  # Print empty line for visual separation
  printf >&2 '\n'

  # Announce start
  dprint_start 'Removing shortcut shell command'

  # Storage variables
  local shortcut_dirpath

  # Extract dirpath
  shortcut_dirpath="$( dirname -- "$D_SHORTCUT_FILEPATH" )"

  # Check if user has writing permissions of directory containing shortcut
  if [ -w "$shortcut_dirpath" ]; then

    # Just remove the shortcut
    rm -f -- "$D_SHORTCUT_FILEPATH"

  else

    # Check if password is going to be required
    if ! sudo -n true 2>/dev/null; then
      dprint_start 'Sudo password is required to remove shortcut shell command'
    fi

    # Remove shortcut with sudo
    sudo rm -f -- "$D_SHORTCUT_FILEPATH"

  fi

  # Check if removal went fine
  if [ $? -eq 0 ]; then

    # Announce success, set status, return
    dprint_success 'Successfully removed shortcut shell command'
    D_STATUS_SHORTCUT=true
    return 0

  else
  
    # Announce and return failure
    dprint_failure 'Failed to remove shortcut shell command'
    D_STATUS_SHORTCUT=error
    return 1

  fi
}

d__report_summary()
{
  # Print empty line for visual separation
  printf >&2 '\n'

  # Storage variables 
  local report_lines=() anything_removed=false
  local v="${REVERSE}${GREEN}${BOLD}v${NORMAL}"
  local x="${REVERSE}${RED}${BOLD}x${NORMAL}"
  local s="${REVERSE}${BOLD}-${NORMAL}"

  # Check status of framework
  case $D_STATUS_FRAMEWORK in
    true)
      report_lines+=( \
        "$v Framework erased at: $D_FMWK_DIR" \
      )
      anything_removed=true
      ;;
    error)
      report_lines+=( \
        "$x Failed to erase framework at: $D_FMWK_DIR" \
      )
      ;;
    *)
      report_lines+=( \
        "$s Framework untouched at: $D_FMWK_DIR" \
      )
      ;;
  esac

  # Compose list of uninstalled utils
  local list_of_uninstalled_utils="$D_UNINSTALLED_UTIL_NAMES" i
  for (( i=1; i<${#D_UNINSTALLED_UTIL_NAMES[@]}; i++ )); do
    list_of_uninstalled_utils+=", ${D_UNINSTALLED_UTIL_NAMES[$i]}"
  done
  [ -n "$list_of_uninstalled_utils" ] || list_of_uninstalled_utils='[none]'

  # Compose list of utils that failed to uninstall
  local list_of_installed_utils="$D_INSTALLED_UTIL_NAMES"
  for (( i=1; i<${#D_INSTALLED_UTIL_NAMES[@]}; i++ )); do
    list_of_installed_utils+=", ${D_INSTALLED_UTIL_NAMES[$i]}"
  done
  [ -n "$list_of_installed_utils" ] || list_of_installed_utils='[none]'

  # Check status of uninstalling system utils
  case $D_STATUS_UTILS in
    true)
      report_lines+=( \
        "  $v Successfully uninstalled: $list_of_uninstalled_utils" \
      )
      anything_removed=true
      ;;
    false)
      report_lines+=( \
        "  $s Remain installed: $list_of_installed_utils" \
      )
      ;;
    error)
      if [ ${#D_UNINSTALLED_UTIL_NAMES[@]} -eq 0 ]; then
        report_lines+=( \
          "  $s Successfully uninstalled: $list_of_uninstalled_utils" \
        )
      else
        report_lines+=( \
          "  $v Successfully uninstalled: $list_of_uninstalled_utils" \
        )
        anything_removed=true
      fi
      report_lines+=( \
        "  $x Failed to uninstall: $list_of_installed_utils" \
      )
      ;;
    *)
      :
      ;;
  esac

  # Check status of backup
  case $D_STATUS_BACKUP in
    true)
      report_lines+=( \
        "  $v Backup created at: $D_BACKUP_LOCATION" \
      )
      anything_removed=true
      ;;
    false)
      report_lines+=( \
        "  $s Nothing to back up" \
      )
      ;;
    error)
      if [ -n "$D_BACKUP_LOCATION" ]; then
        report_lines+=( \
          "  $x Failed to back up to: $D_BACKUP_LOCATION" \
        )
        anything_removed=true
      else
        report_lines+=( \
          "  $x Failed to generate backup path" \
        )
      fi
      ;;
    *)
      report_lines+=( \
        "  $s No backup created" \
      )
      ;;
  esac

  # Chack status of shortcut
  case $D_STATUS_SHORTCUT in
    true)
      report_lines+=( \
        "  $v Shortcut removed at: $D_SHORTCUT_FILEPATH" \
      )
      anything_removed=true
      ;;
    empty)
      report_lines+=( \
        "  $s No shortcut recorded" \
      )
      ;;
    illegal)
      report_lines+=( \
        "  $x Illegal shortcut recorded: $D_SHORTCUT_FILEPATH" \
      )
      ;;
    error)
      report_lines+=( \
        "  $x Failed to remove shortcut at: $D_SHORTCUT_FILEPATH" \
      )
      ;;
    *)
      :
      ;;
  esac

  # Check if anything was removed
  if $anything_removed; then

    # Report and return based on whether the main task is done
    if [ "$D_STATUS_FRAMEWORK" = true ]; then

      # Framework is removed: report and return as success
      dprint_success "${report_lines[@]}"
      return 0

    else

      # Framework is NOT removed: report and return as failure
      dprint_failure "${report_lines[@]}"
      return 1

    fi

  else

    # Essentially nothing was done
    dprint_failure 'Nothing was removed'
    return 1

  fi
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

d__stash_root()
{
  # Key variables
  local stash_dirpath="$D_FMWK_DIR/state/stash"
  local stash_filepath="$stash_dirpath/.stash.cfg"
  local stash_md5_filepath="$stash_filepath.md5"

  # If stash file does not exist, return immediately
  if [ ! -e "$stash_filepath" ]; then return 1; fi

  # Check that stash file has valid checksum
  if [ "$1" = -s ]; then shift; else
    if ! [ "$( dmd5 "$stash_filepath" )" \
      = "$( head -1 -- "$stash_md5_filepath" 2>/dev/null )" ]
    then
      dprint_failure 'Checksum mismatch on root stash file at:' \
        "    $stash_filepath"
      return 1
    fi
  fi

  # Pick action based on first argument
  case $1 in
    has)
      grep -q ^"$2"= -- "$stash_filepath" &>/dev/null \
        && return 0 || return 1
      ;;
    get)
      local value
      value="$( grep ^"$2"= -- "$stash_filepath" 2>/dev/null \
        | head -1 2>/dev/null )"
      value="${value#$2=}"
      printf '%s\n' "$value"
      ;;
    list)
      local value
      while read -r value; do
        value="${value#$2=}"
        printf '%s\n' "$value"
      done < <( grep ^"$2"= -- "$stash_filepath" 2>/dev/null )
      ;;
    *)    return 1;;
  esac
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