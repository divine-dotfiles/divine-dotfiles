#!/usr/bin/env bash
#:title:        Divine Bash routine: assemble
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
## Assembles packages and deployments for further processing
#

#>  __main_assemble
#
## Dispatcher function that forks depending on routine
#
## Returns:
#.  Whatever is returned by child function
#
__main_assemble()
{
  case $D_REQ_ROUTINE in
    install|remove|refresh|check)
                __main__assemble_all_tasks;;
    attach)     __main__validate_dpl_dirs "$D_DIR_DPLS" "$D_DIR_DPL_REPOS";;
    plug)       :;;
    *)          :;;
  esac
}

#>  __main__assemble_all_tasks
#
## Collects tasks to be performed from these types of files:
#.  * Divinefile
#.  * *.dpl.sh
#
## Both types are searched for under both of the following directories:
#.  * $D_DIR_DPLS         - user-defined custom deployments
#.  * $D_DIR_DPL_REPOS    - cloned/downloaded deployments from Github
#
## Provides into the global scope:
#.  $D_QUEUE_TASKS    - (array) each taken priority contains a string 'taken'
#.  $D_QUEUE_PKGS     - (array) Each priority taken by at least one package 
#.                      contains delimited list of package names
#.  $D_QUEUE_DPLS     - (array) Each priority taken by at least one deployment 
#.                      contains delimited list of absolute canonical paths to 
#.                      *.dpl.sh files
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Returns:
#.  0 - Arrays assembled successfully
#.  0 - (script exit) Zero tasks assembled
#.  1 - (script exit) Framework’s deployment directories failed validation
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__main__assemble_all_tasks()
{
  # Make sure dpl-repos are in order
  __sort_out_dpl_repos || exit 1

  # Global storage arrays
  D_QUEUE_TASKS=()
  D_QUEUE_PKGS=()
  D_QUEUE_DPLS=()
  D_DPL_NAMES_IN_FMWK_DIRS=()
  D_DPL_PATHS_IN_FMWK_DIRS=()

  # Parse Divinefiles in all deployment directories
  __scan_for_divinefiles --enqueue "$D_DIR_DPLS" "$D_DIR_DPL_REPOS"

  # Check return code
  case $? in
    0)  # Some packages collected: ensure root stash is available
        if ! dstash --root ready; then
          # No root stash — no packages
          dprint_debug 'Divinefiles will not be processed' \
            'because root stash is not available'
          # Return queues to virgin state
          D_QUEUE_TASKS=()
          D_QUEUE_PKGS=()
        fi
        ;;
    1)  # Zero packages detected for current package manager
        dprint_debug 'Divinefiles collectively contain no packages' \
          "for current package manager ($OS_PKGMGR)"
        ;;
    2)  # No package manager detected
        dprint_debug 'Divinefiles will not be processed' \
          'because no supported package manager is detected'
        ;;
    *)  # Divinefile processing is simply not asked for
        :;;
  esac

  # Locate *.dpl.sh files in all supported directories
  __scan_for_dpl_files --fmwk-dir --enqueue "$D_DIR_DPLS" "$D_DIR_DPL_REPOS"
  
  # Check return code
  case $? in
    0)  # Some deployments collected: all good
        :;;
    1)  # Zero deployments detected, or all of them filtered out: this is fine
        dprint_debug 'Zero deployments found across all directories'
        ;;
    2)  # At least one deployment file has reserved delimiter in its path
        local list_of_illegal_dpls=() illegal_dpl
        for illegal_dpl in "${D_DPL_PATHS_WITH_DELIMITER[@]}"; do
          list_of_illegal_dpls+=( -i "$illegal_dpl" )
        done
        dprint_failure -l \
          "Illegal deployments detected at:" "${list_of_illegal_dpls[@]}" \
          -n "String '$D_CONST_DELIMITER' is reserved internal path delimiter"
        exit 1
        ;;
    *)  # Unsopported code
        :;;
  esac

  # Check if any tasks were found
  if [ ${#D_QUEUE_TASKS[@]} -eq 0 ]; then
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Nothing to do' \
      'Not a single task matches given criteria'
    exit 0
  fi

  # Validate deployments
  if ! __validate_detected_dpls --fmwk-dir; then
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Fatal error:' \
      'Illegal state of deployment directories'
    exit 1
  fi

  # Detect largest priority and number of digits in it
  local largest_priority
  for largest_priority in "${!D_QUEUE_TASKS[@]}"; do :; done
  D_REQ_MAX_PRIORITY_LEN=${#largest_priority}
  readonly D_REQ_MAX_PRIORITY_LEN

  # dprint_ode options for name announcements during package updating
  local priority_field_width=$(( D_REQ_MAX_PRIORITY_LEN + 3 + 19 ))
  local name_field_width=$(( 57 - 1 - priority_field_width ))
  D_ODE_UPDATE=( \
    "${D_ODE_NORMAL[@]}" \
    --width-4 "$priority_field_width" \
    --width-5 "$name_field_width" \
    --effects-5 b \
  ); readonly D_ODE_UPDATE

  # dprint_ode options for package/deployment name announcements
  priority_field_width=$(( D_REQ_MAX_PRIORITY_LEN + 3 + 10 ))
  name_field_width=$(( 57 - 1 - priority_field_width ))
  D_ODE_NAME=( \
    "${D_ODE_NORMAL[@]}" \
    --width-4 "$priority_field_width" \
    --width-5 "$name_field_width" \
    --effects-5 b \
  ); readonly D_ODE_NAME

  # Mark assembled containers read-only
  readonly D_QUEUE_TASKS
  readonly D_QUEUE_PKGS
  readonly D_QUEUE_DPLS

  # Return success
  return 0
}

#>  __main__validate_dpl_dirs DIR…
#
## Ensures that framework’s deployment directories collectively contain a valid 
#. set of deployments, or terminates script. __validate_detected_dpls function 
#. is used for validation.
#
## Deployments are searched for under directories passed as arguments
#
## Provides into the global scope:
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Returns:
#.  0 - Validation successful, arrays assembled
#.  1 - (script exit) Framework’s deployment directories failed validation
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
__main__validate_dpl_dirs()
{
  # Locate *.dpl.sh files in all supported directories
  __scan_for_dpl_files --fmwk-dir "$@"
  
  # Check return code
  case $? in
    0)  # Some deployments collected: all good
        :;;
    1)  # Zero deployments detected, or all of them filtered out: this is fine
        :;;
    2)  # At least one deployment file has reserved delimiter in its path
        local list_of_illegal_dpls=() illegal_dpl
        for illegal_dpl in "${D_DPL_PATHS_WITH_DELIMITER[@]}"; do
          list_of_illegal_dpls+=( -i "$illegal_dpl" )
        done
        dprint_failure -l \
          "Illegal deployments detected at:" "${list_of_illegal_dpls[@]}" \
          -n "String '$D_CONST_DELIMITER' is reserved internal path delimiter"
        exit 1
        ;;
    *)  # Unsopported code
        :;;
  esac

  # Validate deployments
  if ! __validate_detected_dpls --fmwk-dir; then
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Fatal error:' \
      'Illegal state of deployment directories'
    exit 1
  fi

  # Otherwise, return success
  return 0
}

#>  __scan_for_divinefiles [--enqueue] DIR…
#
## Collects packages to be installed from each instance of Divinefile found 
#. within provided directories
#
## Requires:
#.  $D_REQ_PACKAGES         - From __parse_arguments
#.  $D_DIR_DPLS             - From __populate_globals
#.  $D_DIR_DPL_REPOS        - From __populate_globals
#.  $D_CONST_DEF_PRIORITY   - From __populate_globals
#.  $OS_PKGMGR              - From Divine Bash utils: dOS (dos.utl.sh)
#
## Modifies in the global scope:
#.  * with ‘--enqueue’ option:
#.  $D_QUEUE_TASKS    - Associative array with each taken priority paired with 
#.                      an empty string
#.  $D_QUEUE_PKGS     - Associative array with each priority taken by at least 
#.                      one package paired with a semicolon-separated list of 
#.                      package names
#
## Options:
#.  --enqueue   - Signals to add detected packages to framework queues, which 
#.                are then used in check/install/remove routines.
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Total of zero packages could be found across given dirs, which may 
#.      include inaccessible dirs
#.  2 - (only with ‘--enqueue’) Package manager not detected
#.  3 - (only with ‘--enqueue’) Divinefile processing is not asked for
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__scan_for_divinefiles()
{
  # Parse options
  local args=() enqueueing=false
  while (($#)); do
    case $1 in --enqueue) enqueueing=true;; *) args+=("$1");; esac; shift
  done; set -- "${args[@]}"

  # Special checks for queueing mode
  if $enqueueing; then

    # Check if there is a package manager detected for this system
    [ -n "$OS_PKGMGR" ] || return 2

    # Check if Divinefile processing is asked for
    $D_REQ_PACKAGES || return 3
  
  fi

  # Variable for directory path
  local dpl_dir_path

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Storage variables
  local divinefile_path
  local line chunks chunk
  local left_part priority mode list pkgmgr altlist
  local pkg_counter=0

  # Iterate over given directories
  for dpl_dir_path do

    # Check if given directory is readable
    [ -r "$dpl_dir_path" -a -d "$dpl_dir_path" ] || continue

    # Iterate over every Divinefile in that deployments dir
    while IFS= read -r -d $'\0' divinefile_path; do

      # Check if Divinefile is a readable file
      [ -r "$divinefile_path" -a -f "$divinefile_path" ] || continue
    
      # Iterate over lines in each Divinefile
      while IFS='' read -u 10 line || [ -n "$line" ]; do

        # Set empty defaults for the line
        left_part= priority= mode= list= pkgmgr= altlist=

        # Remove comments, trim whitespace
        line="$( dtrim -c -- "$line" )"

        # Empty line — continue
        [ -n "$line" ] || continue

        # Process priority if it is present to the left of ‘)’
        if [[ $line == *')'* ]]; then

          # Split line on first occurrence of ‘)’
          IFS=')' read -r left_part line <<<"$line"

          # Split left part on whitespace
          read -r -a chunks <<<"$left_part"
          priority="${chunks[0]}"
          mode="${chunks[1]}"

          # Remove leading zeroes from priority, if any
          priority="$( sed 's/^0*//' <<<"$priority" )"

          # Trim the rest of the line
          line="$( dtrim -- "$line" )"

        fi

        # Detect whether priority is acceptable
        [[ $priority =~ ^[0-9]+$ ]] || priority="$D_CONST_DEF_PRIORITY"

        # Detect whether mode is acceptable
        [[ $mode =~ ^[airc]+$ ]] || mode=

        # Split remaining line by vertical bars
        IFS='|' read -r -a chunks <<<"$line"
        # First chunk is the default list
        list="${chunks[0]}"; chunks=("${chunks[@]:1}")

        # Iterate over remaining chunks of the line
        for chunk in "${chunks[@]}"; do

          # Ignore alt-lists without ‘:’
          [[ $line == *':'* ]] || continue

          # Split chunk on ‘:’
          IFS=':' read -r pkgmgr altlist <<<"$chunk"

          # Trim package manager list
          pkgmgr="$( dtrim -- "$pkgmgr" )"

          # Ignore empty package manager names
          [ -n "$pkgmgr" ] || continue

          # If it matches $OS_PKGMGR (case insensitively), use the alt list
          if [[ $OS_PKGMGR == $pkgmgr ]]; then
            list="$( dtrim -- "$altlist" )"
            break  # First match wins
          fi

        # Done iterating over remaining chunks of the line
        done

        # Split list by whitespace (in case there are >1 pkg on one line)
        read -r -a chunks <<<"$list"
        # Iterate over package names
        for chunk in "${chunks[@]}"; do

          # Empty name — continue
          [ -n "$chunk" ] || continue

          # Name containing delimiter — continue
          [[ $chunk == *"$D_CONST_DELIMITER"* ]] && continue

          # At this point there is definitely a package, increment counter
          (( ++pkg_counter ))

          # Proceed with global arrays only if queueing
          $enqueueing || continue

          # Add current priority to task queue
          D_QUEUE_TASKS["$priority"]='taken'

          # If some mode is enabled, prefix it
          if [ -n "$mode" ]; then
            chunk="$mode $chunk"
          else
            # ‘---’ is a bogus mode, it will just be ignored
            chunk="--- $chunk"
          fi

          # Add current package to packages queue
          D_QUEUE_PKGS["$priority"]+="$chunk$D_CONST_DELIMITER"

        # Done iterating over package names
        done

      # Done iterating over lines in Divinefile 
      done 10<"$divinefile_path"

    # Done iterating over every Divinefile in that deployments dir
    done < <( find -L "$dpl_dir_path" -mindepth 1 -maxdepth 14 \
      -name "$D_CONST_NAME_DIVINEFILE" -print0 )

  # Done iterating over given directories
  done
    
  # Restore case sensitivity
  eval "$restore_nocasematch"

  # If no packages are found, return error
  [ $pkg_counter -eq 0 ] && return 1

  # Otherwise, success
  return 0
}

#> __scan_for_dpl_files [--fmwk-dir|--ext-dir] [--enqueue] DIR…
#
## Scans all provided directories for deployment files (*.dpl.sh). Output of 
#. this function is dumped into varying set of global variables, depending on 
#. directory qualifier (‘--*-dir’ option).
#
## Requires:
#.  $D_SUFFIX_DPL_SH        - From __populate_globals
#.  $D_REGEX_DPL_NAME       - From __populate_globals
#.  $D_REGEX_DPL_PRIORITY   - From __populate_globals
#.  $D_CONST_DEF_PRIORITY   - From __populate_globals
#
## Modifies in the global scope:
#.  * with ‘--fmwk-dir’ qualifier or without any directory qualifier:
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#.  * with ‘--ext-dir’ qualifier:
#.  $D_DPL_NAMES_IN_EXT_DIRS  - (array) Names of deployments in external dirs
#.  $D_DPL_PATHS_IN_EXT_DIRS  - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#.  * with ‘--enqueue’ option:
#.  $D_QUEUE_TASKS  - (array) Priorities are used as array indices. Every 
#.                    priority with at least one task associated with it 
#.                    contains a string 'taken'.
#.  $D_QUEUE_DPLS   - (array) Priorities are used as array indices. Every 
#.                    priority with at least one deployment associated with it 
#.                    contains delimited list of paths to deployment files.
#.  * when there are deployments with illegal characters in their paths:
#.  $D_DPL_PATHS_WITH_DELIMITER - (array) Paths to deployment files that 
#.                                contain reserved character pattern
#
## Options:
#.  --fmwk-dir  - (default) Signals that directories passed as arguments are 
#.                framework directories, e.g., $D_DIR_DPLS
#.  --ext-dir   - Signals that directories passed as arguments are external 
#.                directories, e.g., dirs being added to user’s collection
#.  --enqueue   - Signals to also add detected deployments to framework queues, 
#.                which are then used in check/install/remove routines.
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Total of zero deployments could be found across given dirs, which may 
#.      include inaccessible dirs
#.  2 - At least one deployment file contains $D_CONST_DELIMITER in its path; 
#.      array $D_DPL_PATHS_WITH_DELIMITER is filled with paths to such 
#.      deployments
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__scan_for_dpl_files()
{
  # Parse options
  local args=() dir_type=fmwk enqueueing=false
  while (($#)); do
    case $1 in --fmwk-dir) dir_type=fmwk;; --ext-dir) dir_type=ext;;
    --enqueue) enqueueing=true;; *) args+=("$1");; esac; shift
  done; set -- "${args[@]}"

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Storage variables
  local dpl_dir
  local divinedpl_filepath dirpath name flags priority
  local adding
  local taken_name j name_already_taken
  local d_dpl_names=() d_dpl_name_paths=() d_dpl_paths_with_delimiter=()

  # Iterate over given directories
  for dpl_dir do

    # Check if deployments directory is readable
    [ -d "$dpl_dir" -a -r "$dpl_dir" ] || continue

    # Iterate over deployment files in current deployment directory
    while IFS= read -r -d $'\0' divinedpl_filepath; do

      # Ensure *.dpl.sh is a readable file
      [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

      # If file path contains reserved delimiter $D_CONST_DELIMITER, skip
      [[ $divinedpl_filepath == *"$D_CONST_DELIMITER"* ]] && {
        d_dpl_paths_with_delimiter+=( "$divinedpl_filepath" )
        continue
      }

      # Extract directory containing *.dpl.sh file
      dirpath="$( dirname -- "$divinedpl_filepath" )"

      # Set empty defaults for the file
      name= flags= priority=

      # Extract name assignment from *.dpl.sh file (first one wins)
      read -r name < <( sed -n "s/$D_REGEX_DPL_NAME/\1/p" \
        <"$divinedpl_filepath" )

      # Process name if it is present
      # Trim name, removing quotes if any
      name="$( dtrim -Q -- "$name" )"
      # Truncate name to 64 chars
      name="$( dtrim -- "${name::64}" )"
      # Detect whether name is not empty
      [ -n "$name" ] || {
        # Fall back to name precefing *.dpl.sh suffix
        name="$( basename -- "$divinedpl_filepath" )"
        name=${name%$D_SUFFIX_DPL_SH}
      }

      # Check if already encountered this deployment name and keep status flag
      name_already_taken=false
      for (( j=0; j<${#d_dpl_names[@]}; j++ )); do

        # Extract this previously taken name
        taken_name="${d_dpl_names[$j]}"

        # Check if current name coincides with one previously taken
        if [[ $taken_name == $name ]]; then

          # Flip flag
          name_already_taken=true

          # Add path to list of them
          d_dpl_name_paths[$j]+="$divinedpl_filepath$D_CONST_DELIMITER"
        
        fi

      done

      # If name is new, add it as new
      if ! $name_already_taken; then
        d_dpl_names+=( "$name" )
        d_dpl_name_paths+=( "$divinedpl_filepath$D_CONST_DELIMITER" )
      fi

      # Continue only when enqueueing
      $enqueueing || continue

      # Plan to queue up this *.dpl.sh
      adding=true

      # Extract flags assignment from *.dpl.sh file (first one wins)
      read -r flags < <( sed -n "s/$D_REGEX_DPL_FLAGS/\1/p" \
        <"$divinedpl_filepath" )
      # Trim flags, removing quotes, if any
      flags="$( dtrim -Q -- "$flags" )"

      # Run dpl through filters
      __run_dpl_through_filters "$name" "$flags" || adding=false

      # Shall we go on?
      $adding || continue

      # Extract priority assignment from *.dpl.sh file (first one wins)
      read -r priority < <( sed -n "s/$D_REGEX_DPL_PRIORITY/\1/p" \
        <"$divinedpl_filepath" )

      # Process priority if it is present
      # Trim priority
      priority="$( dtrim -Q -- "$priority" )"
      # Remove leading zeroes if any
      priority="$( sed 's/^0*//' <<<"$priority" )"
      # Detect whether priority is acceptable
      [[ $priority =~ ^[0-9]+$ ]] || priority="$D_CONST_DEF_PRIORITY"

      # Mark current priority as taken
      D_QUEUE_TASKS["$priority"]='taken'

      # Queue up current deployment
      D_QUEUE_DPLS["$priority"]+="$divinedpl_filepath$D_CONST_DELIMITER"

    # Done iterating over deployment files in current deployment directory
    done < <( find -L "$dpl_dir" -mindepth 1 -maxdepth 14 \
      -name "*$D_SUFFIX_DPL_SH" -print0 )

  # Done iterating over given directories
  done

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Check if illegal deployment paths are encountered
  if [ ${#d_dpl_paths_with_delimiter[@]} -gt 0 ]; then
    
    # Populate global variable
    D_DPL_PATHS_WITH_DELIMITER=( "${d_dpl_paths_with_delimiter[@]}" )

    # Return appropriate code
    return 2

  fi

  # Check how many distinct deployment names are found
  [ ${#d_dpl_names[@]} -eq 0 ] && return 1

  # After iteration: populate global arrays
  case $dir_type in
    fmwk) D_DPL_NAMES_IN_FMWK_DIRS=( "${d_dpl_names[@]}" )
          D_DPL_PATHS_IN_FMWK_DIRS=( "${d_dpl_name_paths[@]}" )
          ;;
    ext)  D_DPL_NAMES_IN_EXT_DIRS=( "${d_dpl_names[@]}" )
          D_DPL_PATHS_IN_EXT_DIRS=( "${d_dpl_name_paths[@]}" )
          ;;
    *)    :;;
  esac

  return 0
}

#>  __run_dpl_through_filters NAME FLAGS
#
## Performs filtering duty: checks given name and flags of a deployment against 
#. scripts arguments to decide whether this deployment should be queued up or 
#. not.
#
## Returns:
#.  0 - Deployment should be queued up
#.  1 - Otherwise
#
__run_dpl_through_filters()
{
  # Extract name and flags
  local name="$1"; shift
  local flags="$1"; shift

  # Check if any filtering is asked for
  if $D_REQ_FILTER; then

    # Storage variables
    local arg

    # Check for filtering mode
    if $D_OPT_INVERSE; then

      # Inverse filtering: Whatever is listed in arguments is filtered out

      # In inverse mode always reject deployments in ‘!’ group
      [[ $flags == *'!'* ]] && return 1

      # Iterate over groups
      for arg in "${D_REQ_GROUPS[@]}"; do
        # If this deployment belongs to rejected group, remove it
        [[ $flags == *"$arg"* ]] && return 1
      done

      # Iterate over arguments
      for arg in "${D_REQ_ARGS[@]}"; do
        # If this deployment is specifically rejected, remove it
        [[ $name == $arg ]] && return 1
      done

      # Otherwise, this is good to go
      return 0

    else

      # Direct filtering: Only what is listed in arguments is added

      # Status variables
      local group_matched=false exclam_requested=false

      # Iterate over groups
      for arg in "${D_REQ_GROUPS[@]}"; do
        # If this deployment belongs to requested group, mark it
        [[ $flags == *"$arg"* ]] && group_matched=true
        # Also, remember, if ‘!’ group is requested
        [ "$arg" = '!' ] && exclam_requested=true
      done

      # Check if group matched
      if $group_matched; then
        # Check if ‘!’ group has been requested
        if $exclam_requested; then
          # Group match is always valid
          return 0
        else
          # Group match is only valid if dpl is not marked with ‘!’ flag
          [[ $flags == *'!'* ]] || return 0
        fi
      fi

      # Iterate over arguments
      for arg in "${D_REQ_ARGS[@]}"; do
        # If this deployment is specifically requested, add it
        [[ $name == $arg ]] && return 0
      done

      # Otherwise, this is a no-go
      return 1

    fi

  else

    # If not filtering, just filter out ‘!’-flagged dpls
    [[ $flags == *'!'* ]] && return 1 || return 0

  fi
}

#>  __validate_detected_dpls [--fmwk-dir|--ext-dir] [PREFIX_TO_REMOVE]
#
## Validates deployments, previously detected by __scan_for_dpl_files from one 
#. of possible sources:
#.  * Framework directories (‘--fmwk-dir’).
#.  * External directories (‘--ext-dir’).
#
## Validation rules are as follows:
#.  * Names must not be reserved (uses __validate_dpl_name function).
#.  * Each name must occur no more than once.
#
## Requires in the global scope:
#.  * with ‘--fmwk-dir’ qualifier or without any directory qualifier:
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#.  * with ‘--ext-dir’ qualifier:
#.  $D_DPL_NAMES_IN_EXT_DIRS  - (array) Names of deployments in external dirs
#.  $D_DPL_PATHS_IN_EXT_DIRS  - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Options:
#.  --fmwk-dir  - (default) Signals to validate deployments previously detected 
#.                in framework directories
#.  --ext-dir   - Signals to validate deployments previously detected in 
#.                external directories
#
## Argument:
#.  $1  - If provided, this textual prefix will be removed from paths in error 
#.        messages for clarity
#
## Returns:
#.  0 - All previously detected deployments are valid
#.  1 - Otherwise
#
__validate_detected_dpls()
{
  # Parse option and argument
  local validating_ext=false
  case $1 in
    --ext-dir)  validating_ext=true;;
    --fmwk_dir) validating_ext=false;;
  esac; shift
  local prefix="$1"; shift

  # Storage and status variables
  local i arr_len err_intro
  local cur_dpl_name cur_dpl_paths_str cur_dpl_paths
  local err_msg err_path
  local all_good=true

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Calculate array length and intro for potential error messages
  if $validating_ext; then
    arr_len=${#D_DPL_NAMES_IN_EXT_DIRS[@]}
    err_intro='Attempted to add'
  else
    arr_len=${#D_DPL_NAMES_IN_FMWK_DIRS[@]}
    err_intro='Detected'
  fi

  # Iterate over names of detected deployments
  for (( i=0; i<$arr_len; i++ )); do

    # Extract name and paths string
    if $validating_ext; then
      cur_dpl_name="${D_DPL_NAMES_IN_EXT_DIRS[$i]}"
      cur_dpl_paths_str="${D_DPL_PATHS_IN_EXT_DIRS[$i]}"
    else
      cur_dpl_name="${D_DPL_NAMES_IN_FMWK_DIRS[$i]}"
      cur_dpl_paths_str="${D_DPL_PATHS_IN_FMWK_DIRS[$i]}"
    fi

    # Collect paths to deployment files with this name
    cur_dpl_paths=()
    while [[ $cur_dpl_paths_str ]]; do
      cur_dpl_paths+=( "${cur_dpl_paths_str%%"$D_CONST_DELIMITER"*}" )
      cur_dpl_paths_str="${cur_dpl_paths_str#*"$D_CONST_DELIMITER"}"
    done

    # Validate name
    if ! __validate_dpl_name "$cur_dpl_name"; then

      # Compose error message
      err_msg=()
      err_msg+=( "$err_intro deployment named '$cur_dpl_name' at:" )
      for err_path in "${cur_dpl_paths[@]}"; do
        err_msg+=( -i "${err_path#"$prefix"}" )
      done
      err_msg+=( -n "Name '$cur_dpl_name' is reserved" )

      # Print error message
      dprint_failure -l "${err_msg[@]}"

      # Flip flag
      all_good=false

    fi

    # Check if name is encountered in more than one deployment
    if [ ${#cur_dpl_paths[@]} -gt 1 ]; then

      # Compose error message
      err_msg=()
      err_msg+=( "$err_intro multiple deployments named '$cur_dpl_name' at:" )
      for err_path in "${cur_dpl_paths[@]}"; do
        err_msg+=( -i "${err_path#"$prefix"}" )
      done
      err_msg+=( -n "Deployment names must be unique" )

      # Print error message
      dprint_failure -l "${err_msg[@]}"

      # Flip flag
      all_good=false

    fi

  done

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # If already with error, return
  $all_good && return 0 || return 1
}

#>  __validate_dpl_name NAME
#
## Checks if provided textual deployment name is valid, i.e., it does not 
#. coincide with reserved phrases, such as ‘Divinefile’ or pre-defined names of 
#. deployment groups.
#
## Returns:
#.  0 - Name is valid
#.  1 - Otherwise
#
__validate_dpl_name()
{
  # Extract name
  local name="$1"; shift

  # Check if name is ‘Divinefile’ or other reserved alias
  [[ $name =~ ^(Divinefile|dfile|df)$ ]] && return 1

  # Check if name coincides with potential group name
  [[ $name =~ ^([0-9]|!)$ ]] && return 1

  # Otherwise return all clear
  return 0
}

#>  __cross_validate_dpls_before_merging [PREFIX_TO_REMOVE]
#
## Confirms that deployments, previously detected in external directories, 
#. would not conflict with deployments, previously detected in framework 
#. directories, if merged together. Both sources are assumed to have been 
#. individually validated prior to running this function.
#
## Validation rules are as follows:
#.  * When combined, each deployment name must occur no more than once.
#
## Requires in the global scope:
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#.  $D_DPL_NAMES_IN_EXT_DIRS  - (array) Names of deployments in external dirs
#.  $D_DPL_PATHS_IN_EXT_DIRS  - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Argument:
#.  $1  - If provided, this textual prefix will be removed from external 
#.        directory paths in error messages for clarity
#
## Returns:
#.  0 - All previously detected deployments are cross-valid (ready to merge)
#.  1 - Otherwise
#
__cross_validate_dpls_before_merging()
{
  # Extract prefix
  local prefix="$1"; shift

  # Storage variables
  local i j cur_dpl_name cur_dpl_paths_str temp_path

  # Status variables
  local all_good=true

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Iterate over names of deployments detected in external dirs
  for (( j=0; j<${#D_DPL_NAMES_IN_EXT_DIRS[@]}; j++ )); do

    # Extract name of current dpl in ext dir
    cur_dpl_name="${D_DPL_NAMES_IN_EXT_DIRS[$j]}"

    # Iterate over names of deployments detected in framework dirs
    for (( i=0; i<${#D_DPL_NAMES_IN_FMWK_DIRS[@]}; i++ )); do

      # Look for internal name that matches external name
      [ "${D_DPL_NAMES_IN_FMWK_DIRS[$i]}" = "$cur_dpl_name" ] || continue

      # Name exists in both internal and external dirs

      # Start composing error message
      err_msg=()

      # Extract paths to where this deployment is located in ext dirs
      err_msg+=( "Attempted to add deployment named '$cur_dpl_name' at:" )
      cur_dpl_paths_str="${D_DPL_PATHS_IN_EXT_DIRS[$j]}"
      while [[ $cur_dpl_paths_str ]]; do
        temp_path="${cur_dpl_paths_str%%"$D_CONST_DELIMITER"*}"
        err_msg+=( -i "${temp_path#"$prefix"}" )
        cur_dpl_paths_str="${cur_dpl_paths_str#*"$D_CONST_DELIMITER"}"
      done

      # Extract paths to where this deployment is located in fmwk dirs
      err_msg+=( "Deployment named '$cur_dpl_name' already exists at:" )
      cur_dpl_paths_str="${D_DPL_PATHS_IN_FMWK_DIRS[$i]}"
      while [[ $cur_dpl_paths_str ]]; do
        err_msg+=( -i "${cur_dpl_paths_str%%"$D_CONST_DELIMITER"*}" )
        cur_dpl_paths_str="${cur_dpl_paths_str#*"$D_CONST_DELIMITER"}"
      done

      # Add final verdict
      err_msg+=( -n 'Deployment names must be unique' )

      # Print error message
      dprint_failure -l "${err_msg[@]}"

      # Flip flag
      all_good=false

      # First match is enough
      break

    done

  done

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Finally, return
  $all_good && return 0 || return 1
}

#>  __merge_records_of_dpls_in_ext_dir EXT_DIRPATH FMWK_DIRPATH
#
## Merges all records of deployments detected in external directories into 
#. records of deployments detected in framework directories. Does not actually 
#. move the files.
#
## Assumes that all validations have been performed prior to calling this 
#. function.
#
## Requires in the global scope:
#.  $D_DPL_NAMES_IN_FMWK_DIRS - (array) Names of deployments in framework dirs
#.  $D_DPL_PATHS_IN_FMWK_DIRS - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#.  $D_DPL_NAMES_IN_EXT_DIRS  - (array) Names of deployments in external dirs
#.  $D_DPL_PATHS_IN_EXT_DIRS  - (array) Index of each name contains delimited 
#.                              list of paths to deployment files
#
## Arguments:
#.  $1  - Path to directory currently holding external deployments
#.  $2  - Path to directory to hold external deployments after merging
#
## Returns:
#.  0 - Always
#
__merge_records_of_dpls_in_ext_dir()
{
  # Extract src and tgt dirs
  local src_dir="$1"; shift
  local tgt_dir="$1"; shift

  # Storage variables
  local j temp

  # Iterate over deployments detected in external dirs
  for (( j=0; j<${#D_DPL_NAMES_IN_EXT_DIRS[@]}; j++ )); do

    # Add name to main array
    D_DPL_NAMES_IN_FMWK_DIRS+=( "${D_DPL_NAMES_IN_EXT_DIRS[$j]}" )

    # Extract, modify, and merge path
    temp="${D_DPL_PATHS_IN_EXT_DIRS[$j]#"$src_dir"}"
    D_DPL_PATHS_IN_FMWK_DIRS+=( "${tgt_dir}${temp}" )

  done

  # All done
  return 0
}

__main_assemble