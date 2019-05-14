#!/usr/bin/env bash
#:title:        Divine Bash routine: install
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.14
#:revremark:    Initial revision
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Installs packages and deployments as requested
#

#> __perform_install
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
__perform_install()
{
  # Announce beginning
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Previewing Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Applying Divine intervention'
  fi

  # Update packages if touching them at all
  __source_routine "$D_ROUTINES_DIR/pkgs.sh"

  # Storage variable
  local priority

  # Iterate over taken priorities
  for priority in "${!D_TASK_QUEUE[@]}"; do

    # Install packages if asked to
    __install_pkgs "$priority"

    # Install deployments if asked to
    __install_dpls "$priority"

    # Check if __install_dpls returned special status
    case $? in
      100)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          ')))' 'Reboot required' ':' \
          'Last deployment asked for machine reboot'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      101)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          'ooo' 'Attention' ':' \
          'Last deployment asked for user’s attention'
        printf '\n'
        dprint_plaque -pcw "$YELLOW" "$D_PLAQUE_WIDTH" \
          -- 'Pausing Divine intervention'
        return 1;;
      666)
        printf '\n'
        dprint_ode "${D_PRINTC_OPTS_NRM[@]}" -c "$YELLOW" -- \
          'x_x' 'Critical failure' ':' \
          'Last deployment reported catastrophic error'
        printf '\n'
        dprint_plaque -pcw "$RED" "$D_PLAQUE_WIDTH" \
          -- 'Aborting Divine intervention'
        return 1;;
      *)  :;;
    esac
    
  done

  # Announce completion
  printf '\n'
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Successfully previewed Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Successfully applied Divine intervention'
  fi
  return 0
}

#> __install_pkgs PRIORITY_LEVEL
#
## For the given priority level, installs packages, one by one, using their 
#. names, which have been previously assembled in $D_PACKAGES array
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
__install_pkgs()
{
  # Check whether packages are asked for
  $D_PKGS || return 1

  # Check whether package manager has been detected
  [ -n "$OS_PKGMGR" ] || return 1

  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks pkgname mode aa_mode

  # Split package names on ‘;’
  IFS=';' read -r -a chunks <<<"${D_PACKAGES[$priority]%;}"

  # Iterate over package names
  for pkgname in "${chunks[@]}"; do

    # Empty name — continue
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
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = false ] && proceeding=false

    # Don’t proceed if already installed (except when forcing)
    if $proceeding; then
      os_pkgmgr dcheck "$pkgname" && ! $D_FORCE && {
        task_name="$task_name (already installed)"
        proceeding=false
      }
    fi

    # Print newline to visually separate tasks
    printf '\n'

    # Print introduction and prompt user as necessary
    if $proceeding; then

      # Print message about the upcoming installation
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"

      ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
      #. user’s approval
      if [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != true ]; then

        # Prompt slightly differs depending on whether ‘always ask’ is enabled
        if $aa_mode; then
          dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
        else
          dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
        fi

        # Prompt user
        dprompt_key -bbbb && proceeding=true || {
          task_name="$task_name (declined by user)"
          proceeding=false
        }
      
      fi

    fi

    # Install package
    if $proceeding; then
      os_pkgmgr dinstall "$pkgname"
      if [ $? -eq 0 ]; then
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
          'vvv' 'Installed' ':' "$task_desc" "$task_name"
      else
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
          'xxx' 'Failed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done

  return 0
}

#> __install_dpls PRIORITY_LEVEL
#
## For the given priority level, installs deployments, one by one, using their 
#. *.dpl.sh files, paths to which have been previously assembled in 
#. $D_DEPLOYMENTS array
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
#.  666 - Critical failure
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__install_dpls()
{
  # Extract priority
  local priority
  priority="$1"; shift

  # Check if priority has been passed
  [ -n "$priority" ] || return 1

  # Storage variables
  local task_desc task_name proceeding
  local chunks divinedpl_filepath
  local name desc warning mode
  local aa_mode dpl_status
  local intro_printed

  # Split *.dpl.sh filepaths on ‘;’
  IFS=';' read -r -a chunks <<<"${D_DEPLOYMENTS[$priority]%;}"

  # Iterate over *.dpl.sh filepaths
  for divinedpl_filepath in "${chunks[@]}"; do

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f dcheck
    unset -f dinstall
    unset -f dremove
    # Expose $D_DPL_DIR variable to deployment
    D_DPL_DIR="$( dirname -- "$divinedpl_filepath" )"

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D_DPL_NAME_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process name
    # Trim name, removing quotes if any
    name="$( dtrim -Q -- "$name" )"
    # Truncate name to 64 chars
    name="$( dtrim -- "${name::64}" )"
    # Detect whether name is not empty
    [ -n "$name" ] || {
      # Fall back to name precefing *.dpl.sh suffix
      name="$( basename -- "$divinedpl_filepath" )"
      name=${name%$D_DPL_SH_SUFFIX}
    }

    # Extract description assignment from *.dpl.sh file (first one wins)
    read -r desc < <( sed -n "s/$D_DPL_DESC_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process description
    # Trim description, removing quotes if any
    desc="$( dtrim -Q -- "$desc" )"

    # Extract warning assignment from *.dpl.sh file (first one wins)
    read -r warning < <( sed -n "s/$D_DPL_WARNING_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process warning
    # Trim warning, removing quotes if any
    warning="$( dtrim -Q -- "$warning" )"

    # Extract mode assignment from *.dpl.sh file (first one wins)
    read -r mode < <( sed -n "s/$D_DPL_FLAGS_REGEX/\1/p" \
      <"$divinedpl_filepath" )
    # Process mode
    # Trim mode, removing quotes if any
    mode="$( dtrim -Q -- "$mode" )"

    # Process $D_FLAGS
    aa_mode=false
    [[ $mode = *a* ]] && aa_mode=true
    [[ $mode = *i* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Local flag for whether descriptive introduction has been printed
    intro_printed=false

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = false ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
    #. user’s approval
    if $proceeding && [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != true ]; then

      # Print message about the upcoming installation
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name" \
        && intro_printed=true
      # In verbose mode, print location of script to be sourced
      dprint_debug "Location: $divinedpl_filepath"
      # If description is available, show it
      [ -n "$desc" ] && dprint_ode "${D_PRINTC_OPTS_DSC[@]}" -- \
        '' 'Description' ':' "$desc"
      # If warning is relevant, show it
      [ -n "$warning" -a "$aa_mode" = true ] \
        && dprint_ode "${D_PRINTC_OPTS_WRN[@]}" -c "$RED" -- \
          '' 'Warning' ':' "$warning"

      # Prompt slightly differs depending on whether ‘always ask’ is enabled
      if $aa_mode; then
        dprint_ode "${D_PRINTC_OPTS_DNG[@]}" -c "$RED" -- '!!!' 'Danger' ': '
      else
        dprint_ode "${D_PRINTC_OPTS_PMT[@]}" -- '' 'Confirm' ': '
      fi

      # Prompt user
      dprompt_key -bbbb && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # Source the *.dpl.sh file
    if $proceeding; then
      # Print informative message for potential debugging of errors
      dprint_debug "Sourcing: $divinedpl_filepath"
      # Hold your breath…
      source "$divinedpl_filepath"
    fi

    # Try to figure out, if deployment is already installed
    if $proceeding; then

      # Get return code of dcheck, or fall back to zero
      if declare -f dcheck &>/dev/null; then
        dcheck; dpl_status=$?
      else
        dpl_status=0
      fi

      # Don’t proceed if already installed (except when forcing)
      case $dpl_status in
        1)  $D_FORCE || {
              task_name="$task_name (already installed)"
              proceeding=false
            }
            ;;
        3)  task_name="$task_name (irrelevant)"
            proceeding=false
            # continue
            ;;
        *)  :;;
      esac

    fi

    # Install deployment
    if $proceeding; then

      # Print descriptive introduction, if haven’t already
      $intro_printed || dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Installing' ':' "$task_desc" "$task_name"

      # Get return code of dinstall, or fall back to zero
      if declare -f dinstall &>/dev/null; then
        dinstall; dpl_status=$?
      else
        dpl_status=0
      fi

      # Analyze exit code
      case $dpl_status in
        0|100|101)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
            'vvv' 'Installed' ':' "$task_desc" "$task_name";;
        2)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
            '---' 'Skipped' ':' "$task_desc" "$task_name";;
        1|666|*)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
            'xxx' 'Failed' ':' "$task_desc" "$task_name";;
      esac

      # Catch special exit codes
      [ $dpl_status -ge 100 ] && return $dpl_status
      
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

__perform_install