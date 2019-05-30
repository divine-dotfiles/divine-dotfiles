#!/usr/bin/env bash
#:title:        Divine Bash routine: check
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
## Checks packages and deployments as requested
#

#> __perform_check
#
## Performs checking routine
#
# For each priority level, from smallest to largest, separately:
#.  * Checks whether packages are installed, in order they appear in Divinefile
#.  * Checks whether deployments are installed, in no particular order
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__perform_check()
{
  # Announce beginning
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- '‘Checking’ Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Checking Divine intervention'
  fi

  # Storage variable
  local priority

  # Iterate over taken priorities
  for priority in "${!D_TASK_QUEUE[@]}"; do

    # Install packages if asked to
    __check_pkgs "$priority"

    # Install deployments if asked to
    __check_dpls "$priority"
    
  done

  # Announce completion
  printf '\n'
  if [ "$D_BLANKET_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D_PLAQUE_WIDTH" \
      -- 'Successfully ‘checked’ Divine intervention'
  else
    dprint_plaque -pcw "$GREEN" "$D_PLAQUE_WIDTH" \
      -- 'Successfully checked Divine intervention'
  fi
  return 0
}

#> __check_pkgs PRIORITY_LEVEL
#
## For the given priority level, check if packages are installed, one by one, 
#. using their names, which have been previously assembled in $D_PACKAGES array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Packages checked
#.  1 - No attempt to check has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__check_pkgs()
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
  local chunks pkgname mode

  # Split package names on ‘;’
  IFS=';' read -r -a chunks <<<"${D_PACKAGES[$priority]%;}"

  # Iterate over package names
  for pkgname in "${chunks[@]}"; do

    # Empty name — continue
    [ -n "$pkgname" ] || continue

    # Extract mode if it is present
    read -r mode pkgname <<<"$pkgname"
    # Mode is ignored when checking packages (unlike deployments)

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

    # Print newline to visually separate tasks
    printf '\n'

    # Perform check
    if $proceeding; then
      if os_pkgmgr dcheck "$pkgname"; then        
        # Check if record of installation exists in root stash
        if dstash --root --skip-checks has "pkg_$( dmd5 -s "$pkgname" )"; then
          # Installed by this framework
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
            'vvv' 'Installed' ':' "$task_desc" "$task_name"
        else
          # Installed by user or OS
          task_name="$task_name (installed by user or OS)"
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$MAGENTA" -- \
            '~~~' 'Installed' ':' "$task_desc" "$task_name"
        fi
      else
        dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
          'xxx' 'Not installed' ':' "$task_desc" "$task_name"
      fi
    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done

  return 0
}

#> __check_dpls PRIORITY_LEVEL
#
## For the given priority level, checks whether deployments are installed, one 
#. by one, using their *.dpl.sh files, paths to which have been previously 
#. assembled in $D_DEPLOYMENTS array
#
## Requires:
#.  * Divine Bash utils: dOS (dps.utl.sh)
#.  * Divine Bash utils: dprint (dprint.utl.sh)
#
## Returns:
#.  0 - Deployments checked
#.  1 - No attempt to check has been made
#
## Prints:
#.  stdout: Progress messages
#.  stderr: As little as possible
#
__check_dpls()
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

  # Split *.dpl.sh filepaths on ‘;’
  IFS=';' read -r -a chunks <<<"${D_DEPLOYMENTS[$priority]%;}"

  # Iterate over *.dpl.sh filepaths
  for divinedpl_filepath in "${chunks[@]}"; do

    # Check if *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Unset any variables that might have been set by previous deployments
    __unset_d_vars
    # Empty out storage variables
    name=
    desc=
    mode=
    # Undefine global functions
    unset -f dcheck
    unset -f dinstall
    unset -f dremove

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
    [[ $mode = *c* ]] && aa_mode=true

    # Name current task
    task_desc='Deployment'
    task_name="'$name'"

    # Prefix priority
    task_desc="$( printf \
      "(%${D_MAX_PRIORITY_LEN}d) %s\n" \
      "$priority" "$task_desc" )"

    # Local flag for whether to proceed
    proceeding=true

    # Don’t proceed if ‘-n’ option is given
    [ "$D_BLANKET_ANSWER" = false ] && proceeding=false

    # Print newline to visually separate tasks
    printf '\n'

    ## Unless given a ‘-y’ option (or unless aa_mode is enabled), prompt for 
    #. user’s approval
    if $proceeding && [ "$aa_mode" = true -o "$D_BLANKET_ANSWER" != true ]
    then

      # Print message about the upcoming checking
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
        '>>>' 'Checking' ':' "$task_desc" "$task_name" \
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
      dprompt_key --bare && proceeding=true || {
        task_name="$task_name (declined by user)"
        proceeding=false
      }

    fi

    # Source the *.dpl.sh file and do all pre- and post- sourcing tasks
    if $proceeding; then

      # Expose variables to deployment
      D_NAME="$name"
      D_DPL_DIR="$( dirname -- "$divinedpl_filepath" )"
      D_DPL_ASSETS_DIR="$D_ASSETS_DIR/$D_NAME"
      D_DPL_BACKUPS_DIR="$D_BACKUPS_DIR/$D_NAME"

      # Print debug message
      dprint_debug "Sourcing: $divinedpl_filepath"

      # Hold your breath…
      source "$divinedpl_filepath"

      # Immediately after sourcing, ensure all assets are copied
      __prepare_dpl_assets || proceeding=false

    fi

    # Check if deployment is installed and report
    if $proceeding; then

      # Get return code of dcheck, or fall back to zero
      if declare -f dcheck &>/dev/null; then
        dcheck; dpl_status=$?
      else
        dpl_status=0
      fi

      # Process return code
      case $dpl_status in
        1)
          if [ "$D_USER_OR_OS" = true ]; then
            task_name="$task_name (installed by user or OS)"
            dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$MAGENTA" -- \
              '~~~' 'Installed' ':' "$task_desc" "$task_name"
          else
            dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$GREEN" -- \
              'vvv' 'Installed' ':' "$task_desc" "$task_name"
          fi
          ;;
        2)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$RED" -- \
            'xxx' 'Not installed' ':' "$task_desc" "$task_name"
          ;;
        3)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$MAGENTA" -- \
            '~~~' 'Irrelevant' ':' "$task_desc" "$task_name"
          ;;
        4)
          if [ "$D_USER_OR_OS" = true ]; then
            task_name="$task_name (partly installed by user or OS)"
          fi
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$YELLOW" -- \
            'vx-' 'Partly installed' ':' "$task_desc" "$task_name"
          ;;
        *)
          dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$BLUE" -- \
            '???' 'Unknown' ':' "$task_desc" "$task_name"
          ;;
      esac

    else
      dprint_ode "${D_PRINTC_OPTS_NM[@]}" -c "$WHITE" -- \
        '---' 'Skipped' ':' "$task_desc" "$task_name"
    fi

  done
  
  return 0
}

__perform_check