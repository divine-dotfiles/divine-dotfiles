#!/usr/bin/env bash
#:title:        Divine Bash routine: install
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Remove revision numbers from all src files
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Installs packages and deployments as requested
#

#>  d__perform_install_routine
#
## Performs installation routine
#
# For each priority level, from smallest to largest, separately:
#.  * Installs packages in order they appear in Divinefile
#.  * Installs deployments in no particular order
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
d__perform_install_routine()
{
  # Print empty line for visual separation
  printf >&2 '\n'

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Previewing Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Applying Divine intervention'
  fi

  # Update packages if touching them at all
  d__load routine pkgs

  # Storage variable
  local priority

  # Iterate over taken priorities
  for priority in "${!D__WORKLOAD[@]}"; do

    # Install packages if asked to
    d__install_pkgs "$priority"

    # Install deployments if asked to
    d__install_dpls "$priority"

    # Check if d__install_dpls returned special status
    case $? in
      100)
        printf '\n'
        dprint_ode "${D__ODE_NORMAL[@]}" -c "$YELLOW" -- \
          ')))' 'Reboot required' ':' \
          'Last deployment asked for machine reboot'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D__CONST_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      101)
        printf '\n'
        dprint_ode "${D__ODE_NORMAL[@]}" -c "$YELLOW" -- \
          'ooo' 'Attention' ':' \
          "Last deployment asked for user's attention"
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D__CONST_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      102)
        printf '\n'
        dprint_ode "${D__ODE_NORMAL[@]}" -c "$YELLOW" -- \
          'x_x' 'Critical failure' ':' \
          'Last deployment reported catastrophic error'
        printf '\n'
        dprint_plaque -pcw "$RED" "$D__CONST_PLAQUE_WIDTH" \
          -- 'Aborting Divine intervention'
        return 1;;
      *)  :;;
    esac
    
  done

  # Announce completion
  printf '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Successfully previewed Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Successfully applied Divine intervention'
  fi
  return 0
}

#>  d__install_pkgs PRIORITY_LEVEL
#
## For the given priority level, installs packages, one by one, using their 
#. names, which have been previously assembled in $D__WORKLOAD_PKGS array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Packages installed
#.  1 - No attempt to install has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
d__install_pkgs()
{
  # Check whether packages are asked for
  $D__REQ_PACKAGES || return 1

  # Check whether package manager has been detected
  [ -n "$D__OS_PKGMGR" ] || return 1

  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local pkg_str chunks=() pkgname mode aa_mode

  # Split package names on $D__CONST_DELIMITER
  pkg_str="${D__WORKLOAD_PKGS[$priority]}"
  while [[ $pkg_str ]]; do
    chunks+=( "${pkg_str%%"$D__CONST_DELIMITER"*}" )
    pkg_str="${pkg_str#*"$D__CONST_DELIMITER"}"
  done

  # Iterate over package names
  for pkgname in "${chunks[@]}"; do

    # Empty name - continue
    [ -n "$pkgname" ] || continue

    # Extract mode if it is present
    read -r mode pkgname <<<"$pkgname"
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *i* ]] && aa_mode=true

    # Name current task
    task_desc='Package'
    task_name="'$pkgname'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D__REQ_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don't proceed if '-n' option is given
    [ "$D__OPT_ANSWER" = false ] && proceeding=false

    # Don't proceed if already installed (except when forcing)
    if $proceeding; then
      if d__os_pkgmgr check "$pkgname"; then
        task_name="$task_name (already installed)"
        $D__OPT_FORCE || proceeding=false
      fi
    fi

    # Print newline to visually separate tasks
    printf '\n'

    # Print introduction and prompt user as necessary
    if $proceeding; then

      # Print message about the upcoming installation
      dprint_ode "${D__ODE_NAME[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"

      ## Unless given a '-y' option (or unless aa_mode is enabled), prompt for 
      #. user's approval
      if [ "$aa_mode" = true -o "$D__OPT_ANSWER" != true ]; then

        # Prompt slightly differs depending on whether 'always ask' is enabled
        if $aa_mode; then
          dprint_ode "${D__ODE_DANGER[@]}" -c "$RED" -- '!!!' 'Danger' ': '
        else
          dprint_ode "${D__ODE_PROMPT[@]}" -- '' 'Confirm' ': '
        fi

        # Prompt user
        dprompt --bare && proceeding=true || {
          task_name="$task_name (declined by user)"
          proceeding=false
        }
      
      fi

    fi

    # Install package
    if $proceeding; then

      # Launch OS package manager with verbosity in mind
      if $D__OPT_QUIET; then

        # Launch quietly
        d__os_pkgmgr install "$pkgname" &>/dev/null

      else

        # Launch normally, but re-paint output
        local line
        d__os_pkgmgr install "$pkgname" 2>&1 \
          | while IFS= read -r line || [ -n "$line" ]; do
          printf "${CYAN}==> %s${NORMAL}\n" "$line"
        done

      fi

      # Check return status
      if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        d__stash --root --skip-checks set "pkg_$( dmd5 -s "$pkgname" )"
        dprint_ode "${D__ODE_NAME[@]}" -c "$GREEN" -- \
          'vvv' 'Installed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D__ODE_NAME[@]}" -c "$RED" -- \
          'xxx' 'Failed' ':' "$task_desc" "$task_name"
      fi

    else

      # Not installing
      dprint_ode "${D__ODE_NAME[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"

    fi

  done

  return 0
}

#>  d__install_dpls PRIORITY_LEVEL
#
## For the given priority level, installs deployments, one by one, using their 
#. *.dpl.sh files, paths to which have been previously assembled in 
#. $D__WORKLOAD_DPLS array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Deployments installed
#.  1 - No attempt to install has been made
#.  100 - Reboot needed
#.  101 - User attention needed
#.  102 - Critical failure
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
d__install_dpls()
{
  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local dpl_str chunks=() divinedpl_filepath
  local name desc warning mode
  local aa_mode dpl_status
  local intro_printed

  # Split *.dpl.sh filepaths on $D__CONST_DELIMITER
  dpl_str="${D__WORKLOAD_DPLS[$priority]}"
  while [[ $dpl_str ]]; do
    chunks+=( "${dpl_str%%"$D__CONST_DELIMITER"*}" )
    dpl_str="${dpl_str#*"$D__CONST_DELIMITER"}"
  done

  # Iterate over *.dpl.sh filepaths
  for divinedpl_filepath in "${chunks[@]}"; do

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f d_dpl_check
    unset -f d_dpl_install
    unset -f d_dpl_remove

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D__REGEX_DPL_NAME/\1/p" \
      <"$divinedpl_filepath" )
    # Process name
    # Remove quotes, trim to 64 chars, trim whitespace
    [[ $name = \'*\' || $name = \"*\" ]] && name="${name:1:${#name}-2}"
    read -r name <<<"${name::64}"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D__SUFFIX_DPL_SH}
    }

    # Extract description assignment from *.dpl.sh file (first one wins)
    read -r desc < <( sed -n "s/$D__REGEX_DPL_DESC/\1/p" \
      <"$divinedpl_filepath" )
    # Process description
    # Trim description, removing quotes if any
    [[ $desc = \'*\' || $desc = \"*\" ]] && desc="${desc:1:${#desc}-2}"
    read -r desc <<<"$desc"

    # Extract warning assignment from *.dpl.sh file (first one wins)
    read -r warning < <( sed -n "s/$D__REGEX_DPL_WARNING/\1/p" \
      <"$divinedpl_filepath" )
    # Process warning
    # Trim warning, removing quotes if any
    [[ $warning = \'*\' || $warning = \"*\" ]] \
      && warning="${warning:1:${#warning}-2}"
    read -r warning <<<"$warning"

    # Extract mode assignment from *.dpl.sh file (first one wins)
    read -r mode < <( sed -n "s/$D__REGEX_DPL_FLAGS/\1/p" \
      <"$divinedpl_filepath" )
    # Process mode
    # Trim mode, removing quotes if any
    [[ $mode = \'*\' || $mode = \"*\" ]] && mode="${mode:1:${#mode}-2}"
    read -r mode <<<"$mode"

    # Process $D_DPL_FLAGS
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *i* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D__REQ_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Local flag for whether descriptive introduction has been printed
    intro_printed=false

    # Don't proceed if '-n' option is given
    [ "$D__OPT_ANSWER" = false ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    # Conditionally print intro
    if $proceeding && [ "$aa_mode" = true -o "$D__OPT_ANSWER" != true \
      -o "$D__OPT_QUIET" = false ]
    then

      # Print message about the upcoming installation
      dprint_ode "${D__ODE_NAME[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name" \
        && intro_printed=true
      # If description is available, show it
      [ -n "$desc" ] && dprint_ode "${D__ODE_DESC[@]}" -- \
        '' 'Description' ':' "$desc"
      
    fi
    
    ## Unless given a '-y' option (or unless aa_mode is enabled), prompt for 
    #. user's approval
    if $proceeding && [ "$aa_mode" = true -o "$D__OPT_ANSWER" != true ]
    then

      # In verbose mode, print location of script to be sourced
      dprint_debug "Location: $divinedpl_filepath"
      # If warning is relevant, show it
      [ -n "$warning" -a "$aa_mode" = true ] \
        && dprint_ode "${D__ODE_WARN[@]}" -c "$RED" -- \
          '' 'Warning' ':' "$warning"

      # Prompt slightly differs depending on whether 'always ask' is enabled
      if $aa_mode; then
        dprint_ode "${D__ODE_DANGER[@]}" -c "$RED" -- '!!!' 'Danger' ': '
      else
        dprint_ode "${D__ODE_PROMPT[@]}" -- '' 'Confirm' ': '
      fi

      # Prompt user
      dprompt --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # If still proceeding, enter the final stage
    if $proceeding; then

      # Open subshell to isolate deployment code
      (

        # Announce
        dprint_debug 'Entered sub-shell'

        # Expose variables to deployment
        D_DPL_NAME="$name"
        D_DPL_PRIORITY="$priority"
        readonly D__DPL_SH_PATH="$divinedpl_filepath"
        D__DPL_MNF_PATH="${divinedpl_filepath%$D__SUFFIX_DPL_SH}"
        D_DPL_QUE_PATH="${D__DPL_MNF_PATH}$D__SUFFIX_DPL_QUE"
        readonly D__DPL_MNF_PATH+="$D__SUFFIX_DPL_MNF"
        readonly D__DPL_DIR="$( dirname -- "$divinedpl_filepath" )"
        readonly D__DPL_ASSET_DIR="$D__DIR_ASSETS/$D_DPL_NAME"
        readonly D__DPL_BACKUP_DIR="$D__DIR_BACKUPS/$D_DPL_NAME"

        # Process the asset manifest, if it exists
        d__process_asset_manifest_of_current_dpl || exit 2

        # Print debug message
        dprint_debug "Sourcing: $divinedpl_filepath"

        # Hold your breath...
        source "$divinedpl_filepath"

        # Process queue manifest (after sourcing, to allow path customization)
        d__process_queue_manifest_of_current_dpl

        # Get return code of d_dpl_check, or fall back to zero
        if declare -f d_dpl_check &>/dev/null; then
          d_dpl_check; dpl_status=$?
        else
          dpl_status=0
        fi

        # Don't proceed if already installed (except when forcing)
        case $dpl_status in
          1)  if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then
                task_name="$task_name (installed by user or OS)"
                $D__OPT_FORCE || exit 3
              else
                task_name="$task_name (already installed)"
                $D__OPT_FORCE || exit 4
              fi
              ;;
          3)  exit 5;;
          4)  if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then
                task_name="$task_name (partly installed by user or OS)"
              else
                task_name="$task_name (partly installed)"
              fi
              ;;
          *)  :;;
        esac

        # Check if dpl requested another prompt
        if [ "$D_DPL_NEEDS_ANOTHER_PROMPT" = true ]; then

          # Print descriptive introduction, if haven't already
          if ! $intro_printed; then
            dprint_ode "${D__ODE_NAME[@]}" -c "$YELLOW" -- \
              '>>>' 'Installing' ':' "$task_desc" "$task_name"
            [ -n "$desc" ] && dprint_ode "${D__ODE_DESC[@]}" -- \
              '' 'Description' ':' "$desc"
          fi

          # If there was a warning provided, print it
          if [ -n "$D_DPL_NEEDS_ANOTHER_WARNING" ]; then
            dprint_ode "${D__ODE_WARN[@]}" -c "$RED" -- \
              '' 'Warning' ':' "$D_DPL_NEEDS_ANOTHER_WARNING"
          fi

          # Prompt user
          dprint_ode "${D__ODE_DANGER[@]}" -c "$RED" -- '!!!' 'Danger' ': '
          dprompt --bare || exit 6

        fi

        # Print descriptive introduction, if haven't already
        $intro_printed || dprint_ode "${D__ODE_NAME[@]}" -c "$YELLOW" -- \
          '>>>' 'Installing' ':' "$task_desc" "$task_name"

        # Expose check code to deployment
        D__DPL_CHECK_CODE="$dpl_status"

        # Get return code of d_dpl_install, or fall back to zero
        if declare -f d_dpl_install &>/dev/null; then
          d_dpl_install; dpl_status=$?
        else
          dpl_status=0
        fi

        # Analyze exit code
        case $dpl_status in
          0|100|101)
            dprint_ode "${D__ODE_NAME[@]}" -c "$GREEN" -- \
              'vvv' 'Installed' ':' "$task_desc" "$task_name";;
          2)
            dprint_ode "${D__ODE_NAME[@]}" -c "$WHITE" -- \
              '---' 'Skipped' ':' "$task_desc" "$task_name";;
          1|102|*)
            dprint_ode "${D__ODE_NAME[@]}" -c "$RED" -- \
              'xxx' 'Failed' ':' "$task_desc" "$task_name";;
        esac

        # Catch special exit codes
        case $dpl_status in
          100)  exit 7;;
          101)  exit 8;;
          102)  exit 9;;
          *)    :;;
        esac

        # Exit subshell properly
        exit 0
      
      )

      # Store subshell exit status
      dpl_status=$?

      # Announce
      dprint_debug 'Exited sub-shell'

      # Tentatively set failure flag
      proceeding=false

      # Check exit status of subshell
      case $dpl_status in
        0)  # Subshell ran successfully: restore flag
            proceeding=true
            ;;
        1)  # General failure: return critical failure
            dprint_failure \
              'Something went spectacularly wrong within the subshell'
            dprint_ode "${D__ODE_NAME[@]}" -c "$RED" -- \
              'xxx' 'Failed' ':' "$task_desc" "$task_name"
            return 102
            ;;
        2)  # Asset assembly failed: retain failure flag
            dprint_failure 'Failed to process deployment assets'
            ;;
        3)  # Already installed by user or OS
            task_name="$task_name (installed by user or OS)"
            ;;
        4)  # Already installed by framework
            task_name="$task_name (already installed)"
            ;;
        5)  # Irrelevant deployment
            task_name="$task_name (irrelevant)"
            ;;
        6)  # User declined prompt
            task_name="$task_name (declined by user)"
            ;;
        7)  # Installation returned special code 100
            return 100
            ;;
        8)  # Installation returned special code 101
            return 101
            ;;
        9)  # Installation returned special code 102
            return 102
            ;;
        *)  # Unsupported: retain failure flag
            :
            ;;
      esac

    fi

    # Make a final check for whether arrived here without bailing
    if ! $proceeding; then
      dprint_ode "${D__ODE_NAME[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

d__perform_install_routine