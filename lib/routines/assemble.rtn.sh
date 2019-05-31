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

#>  __assemble_main
#
## Dispatcher function that forks depending on routine
#
## Returns:
#.  Whatever is returned by child function
#
__assemble_main()
{
  case $D_ROUTINE in
    install)    __assemble_tasks_for_main_routines;;
    remove)     __assemble_tasks_for_main_routines;;
    refresh)    __assemble_tasks_for_main_routines;;
    check)      __assemble_tasks_for_main_routines;;
    add)        :;;
  esac
}

#>  __assemble_tasks_for_main_routines
#
## Collects tasks to be performed from these files:
#.  * Divinefile    - Located in directories under $D_DEPLOYMENTS_DIR
#.  * *.dpl.sh      - Located in directories under $D_DEPLOYMENTS_DIR
#
## Provides into the global scope:
#.  $D_TASK_QUEUE       - Array: each taken priority contains a string 'taken'
#.  $D_PKG_QUEUE        - Array: each priority taken by at least one package 
#.                        contains delimited list of package names
#.  $D_DPL_QUEUE        - Array: each priority taken by at least one deployment 
#.                        contains delimited list of absolute canonical paths 
#.                        to *.dpl.sh files
#.  $D_DPL_NAMES        - Array of taken deployment names
#.  $D_DPL_NAME_PATHS   - Array: index of each taken deployment name from 
#.                        $D_DPL_NAMES contains delimited list of paths to 
#.                        deployment files
#
## Returns:
#.  0 - Arrays assembled successfully
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__assemble_tasks_for_main_routines()
{
  # Global storage arrays
  D_TASK_QUEUE=()
  D_PKG_QUEUE=()
  D_DPL_QUEUE=()
  D_DPL_NAMES=()
  D_DPL_NAME_PATHS=()

  # Parse Divinefile
  __parse_divinefile

  # If there are packages to process, ensure root stash is ready
  if [ ${#D_PKG_QUEUE[@]} -gt 0 ] && ! dstash --root ready; then
    # No root stash — no packages
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Divinefile will not be processed' \
      'Root stash is not available'
    # Erase all collected packages
    D_PKG_QUEUE=()
  fi

  # Locate *.dpl.sh files and check return status
  __locate_dpl_sh_files; case $? in 2) exit 1;; *) :;; esac

  # Check if any tasks were found
  if [ ${#D_TASK_QUEUE[@]} -eq 0 ]; then
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Nothing to do' \
      'Not a single task matches given criteria'
    exit 0
  fi

  # Validate deployments
  if ! __validate_dpls_in_main_dir; then
    printf >&2 '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Fatal error:' \
      'Illegal state of deployments directory'
    exit 1
  fi

  # Detect largest priority and number of digits in it
  local largest_priority
  for largest_priority in "${!D_TASK_QUEUE[@]}"; do :; done
  D_MAX_PRIORITY_LEN=${#largest_priority}
  readonly D_MAX_PRIORITY_LEN

  # dprint_ode options for name announcements during package updating
  local priority_field_width=$(( D_MAX_PRIORITY_LEN + 3 + 19 ))
  local name_field_width=$(( 57 - 1 - priority_field_width ))
  D_PRINTC_OPTS_UP=( \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --width-4 "$priority_field_width" \
    --width-5 "$name_field_width" \
    --effects-5 b \
  ); readonly D_PRINTC_OPTS_UP

  # dprint_ode options for package/deployment name announcements
  priority_field_width=$(( D_MAX_PRIORITY_LEN + 3 + 10 ))
  name_field_width=$(( 57 - 1 - priority_field_width ))
  D_PRINTC_OPTS_NM=( \
    "${D_PRINTC_OPTS_NRM[@]}" \
    --width-4 "$priority_field_width" \
    --width-5 "$name_field_width" \
    --effects-5 b \
  ); readonly D_PRINTC_OPTS_NM

  # Mark assembled containers read-only
  readonly D_TASK_QUEUE
  readonly D_PKG_QUEUE
  readonly D_DPL_QUEUE

  return 0
}

#>  __survey_deployments_before_adding [--no-main]
#
## Collects deployments in $D_DEPLOYMENTS_DIR and validates them, then does the 
#. same in $D_ADD_DIR, and finally analyzes possibility of merging the two set 
#. of deployments.
#
## Provides into the global scope:
#.  $D_DPL_NAMES        - Array of taken deployment names
#.  $D_DPL_NAME_PATHS   - Array: index of each taken deployment name from 
#.                        $D_DPL_NAMES contains delimited list of paths to 
#.                        deployment files
#.  $D_ADD_NAMES        - Array of deployment names to be added
#.  $D_ADD_NAME_PATHS   - Array: index of each deployment name from 
#.                        $D_ADD_NAMES contains delimited list of paths to 
#.                        deployment files
#
## Options:
#.  --no-main   - Skip processing main directory
#
## Returns:
#.  0 - Deployments in $D_ADD_DIR may be safely added
#.  1 - Otherwise
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__survey_deployments_before_adding()
{
  # Process arguments
  local process_main=true
  [ "$1" = '--no-main' ] && { process_main=false; shift; }

  # Global storage arrays
  D_DPL_NAMES=()
  D_DPL_NAME_PATHS=()
  D_ADD_NAMES=()
  D_ADD_NAME_PATHS=()

  # Locate *.dpl.sh files in both directories, check status
  if $process_main; then
    __locate_dpl_sh_files; case $? in 2) return 1;; *) :;; esac
  fi
  __locate_dpl_sh_files --add-dir; case $? in 2) return 1;; *) :;; esac

  # Make sure existing deployments are in good shape
  __validate_dpls_in_main_dir || return 1
  __validate_dpls_in_add_dir || return 1

  return 0
}

#> __parse_divinefile
#
## Collects packages to be installed from each instance of Divinefile under 
#. deployments directory
#
## Requires:
#.  $D_PKGS                 - From __parse_arguments
#.  $D_DEFAULT_PRIORITY     - From __populate_globals
#.  $OS_PKGMGR              - From Divine Bash utils: dOS (dos.utl.sh)
#
## Modifies in the global scope:
#.  $D_TASK_QUEUE   - Associative array with each taken priority paired with an 
#.                    empty string
#.  $D_PKG_QUEUE    - Associative array with each priority taken by at least 
#.                    one package paired with a semicolon-separated list of 
#.                    package names
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Failed to read Divinefile
#.  2 - No package manager detected
#.  3 - List of deployments has been provided, and Divinefile is not in it
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__parse_divinefile()
{
  # Check if there is a package manager detected for this system
  [ -n "$OS_PKGMGR" ] || return 2

  ## Check if list of deployments has been provided, and whether Divinefile is 
  #. in it
  $D_PKGS || return 3

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

  # Storage variables
  local divinefile_path
  local line chunks chunk
  local left_part priority mode list pkgmgr altlist

  # Iterate over every Divinefile in deployments dir
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
      [[ $priority =~ ^[0-9]+$ ]] || priority="$D_DEFAULT_PRIORITY"

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

      # Split list by whitespace (in case there are many packages on one line)
      read -r -a chunks <<<"$list"
      # Iterate over package names
      for chunk in "${chunks[@]}"; do

        # Empty name — continue
        [ -n "$chunk" ] || continue

        # Name containing delimiter — continue
        [[ $chunk == *"$D_DELIM"* ]] && continue

        # Add current priority to task queue
        D_TASK_QUEUE["$priority"]='taken'

        # If some mode is enabled, prefix it
        if [ -n "$mode" ]; then
          chunk="$mode $chunk"
        else
          # ‘---’ is a bogus mode, it will just be ignored
          chunk="--- $chunk"
        fi

        # Add current package to packages queue
        D_PKG_QUEUE["$priority"]+="$chunk$D_DELIM"

      # Done iterating over package names
      done

    # Done iterating over lines in Divinefile 
    done 10<"$divinefile_path"

  # Done iterating over Divinefiles in deployments directory
  done < <( find -L "$D_DEPLOYMENTS_DIR" -mindepth 1 -maxdepth 14 \
    -name "$D_DIVINEFILE_NAME" -print0 )

  # Restore case sensitivity
  eval "$restore_nocasematch"

  return 0
}

#> __locate_dpl_sh_files [--add-dir]
#
## Collects deployments from *.dpl.sh files located under $D_DEPLOYMENTS_DIR, 
#. or $D_ADD_DIR, if $D_ROUTINE is set to 'add'
#
## Requires:
#.  $D_DEPLOYMENTS_DIR      - From __populate_globals
#.  $D_DPL_SH_SUFFIX        - From __populate_globals
#.  $D_DPL_NAME_REGEX       - From __populate_globals
#.  $D_DPL_PRIORITY_REGEX   - From __populate_globals
#.  $D_DEFAULT_PRIORITY     - From __populate_globals
#
## Modifies in the global scope (with normal routines):
#.  $D_DPL_NAMES        - Array of taken deployment names
#.  $D_DPL_NAME_PATHS   - Array: index of each taken deployment name from 
#.                        $D_DPL_NAMES contains delimited list of paths to 
#.                        deployment files
#
## Modifies in the global scope (when 'add' routine):
#.  $D_ADD_NAMES        - Array of deployment names to be added
#.  $D_ADD_NAME_PATHS   - Array: index of each deployment name from 
#.                        $D_ADD_NAMES contains delimited list of paths to 
#.                        deployment files
#
## Modifies in the global scope (without --no-task-queue option):
#.  $D_TASK_QUEUE       - Array: each taken priority contains a string 'taken'
#.  $D_DPL_QUEUE        - Array: each priority taken by at least one deployment 
#.                        contains delimited list of absolute canonical paths 
#.                        to *.dpl.sh files
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Failed to access $D_DEPLOYMENTS_DIR or zero deployments found
#.  2 - Detected deployment file containing $D_DELIM in its path
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__locate_dpl_sh_files()
{
  # Quickly parse arguments
  local dpl_dir="$D_DEPLOYMENTS_DIR" using_add_dir=false
  [ "$1" = '--add-dir' ] && { dpl_dir="$D_ADD_DIR"; using_add_dir=true; }

  # Check if deployments directory is readable
  [ -d "$dpl_dir" -a -r "$dpl_dir" ] || return 1

  # Store current case sensitivity setting, then turn it off when needed
  local restore_nocasematch="$( shopt -p nocasematch )"

  # Iterate over directories descending from deployments dirpath
  local dirpath divinedpl_filepath name flags priority
  local restore_nocasematch
  local adding arg
  local taken_name j name_already_taken
  local d_dpl_names=() d_dpl_name_paths=()
  while IFS= read -r -d $'\0' divinedpl_filepath; do

    # Ensure *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Extract directory containing *.dpl.sh file
    dirpath="$( dirname -- "$divinedpl_filepath" )"

    # If file path contains reserved delimiter $D_DELIM, skip
    [[ $divinedpl_filepath == *"$D_DELIM"* ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment file path containing '$D_DELIM' found at:" \
        "$divinedpl_filepath" \
        "String '$D_DELIM' is reserved internal delimiter"
      return 2
    }

    # Set empty defaults for the file
    name= priority=

    # Extract name assignment from *.dpl.sh file (first one wins)
    read -r name < <( sed -n "s/$D_DPL_NAME_REGEX/\1/p" \
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
      name=${name%$D_DPL_SH_SUFFIX}
    }

    # Turn off case sensitivity for upcoming tests
    shopt -s nocasematch

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
        d_dpl_name_paths[$j]+="$divinedpl_filepath$D_DELIM"
      
      fi

    done

    # If name is new, add it as new
    if ! $name_already_taken; then
      d_dpl_names+=( "$name" )
      d_dpl_name_paths+=( "$divinedpl_filepath$D_DELIM" )
    fi

    # Restore case sensitivity
    eval "$restore_nocasematch"

    # Continue on only in normal routines
    [ "$D_ROUTINE" = add ] && continue

    # Plan to queue up this *.dpl.sh
    adding=true

    # If filtering, filter
    if $D_FILTERING; then

      # Extract flags assignment from *.dpl.sh file (first one wins)
      read -r flags < <( sed -n "s/$D_DPL_FLAGS_REGEX/\1/p" \
        <"$divinedpl_filepath" )
      # Process flags
      # Trim flags, removing quotes if any
      flags="$( dtrim -Q -- "$flags" )"

      # Check for filtering mode
      if $D_INVERSE_FILTER; then

        # Inverse filtering: Whatever is listed in arguments is filtered out

        # Turn off case sensitivity
        shopt -s nocasematch

        # Iterate over arguments
        for arg in "${D_ARGS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment is specifically rejected, remove it
          [[ $arg == $name ]] && { adding=false; break; }
        done

        # Also, iterate over groups
        for arg in "${D_GROUPS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment belongs to rejected group, remove it
          [[ $flags == *${arg}* ]] && { adding=false; break; }
        done

        # Restore case sensitivity
        eval "$restore_nocasematch"

      else

        # Direct filtering: Only what is listed in arguments is added

        # By default, don’t add this *.dpl.sh
        adding=false

        # Turn off case sensitivity
        shopt -s nocasematch

        # Iterate over arguments
        for arg in "${D_ARGS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment is specifically requested, add it
          [[ $arg == $name ]] && { adding=true; break; }
        done

        # Also, iterate over groups
        for arg in "${D_GROUPS[@]}"; do
          # Check if argument is empty
          [ -n "$arg" ] || continue
          # If this deployment belongs to requested group, add it
          [[ $flags == *${arg}* ]] && { adding=true; break; }
        done

        # Restore case sensitivity
        eval "$restore_nocasematch"

      fi

    fi

    # Shall we go on?
    $adding || continue

    # Extract priority assignment from *.dpl.sh file (first one wins)
    read -r priority < <( sed -n "s/$D_DPL_PRIORITY_REGEX/\1/p" \
      <"$divinedpl_filepath" )

    # Process priority if it is present
    # Trim priority
    priority="$( dtrim -Q -- "$priority" )"
    # Remove leading zeroes if any
    priority="$( sed 's/^0*//' <<<"$priority" )"
    # Detect whether priority is acceptable
    [[ $priority =~ ^[0-9]+$ ]] || priority="$D_DEFAULT_PRIORITY"

    # Mark current priority as taken
    D_TASK_QUEUE["$priority"]='taken'

    # Queue up current deployment
    D_DPL_QUEUE["$priority"]+="$divinedpl_filepath$D_DELIM"

  done < <( find -L "$dpl_dir" -mindepth 1 -maxdepth 14 \
    -name "*$D_DPL_SH_SUFFIX" -print0 )

  # Check how many deployments are found (before filtering)
  if [ ${#d_dpl_names[@]} -eq 0 ]; then return 1; fi

  # After iteration: populate global arrays
  if $using_add_dir; then
    D_ADD_NAMES=( "${d_dpl_names[@]}" )
    D_ADD_NAME_PATHS=( "${d_dpl_name_paths[@]}" )
  else
    D_DPL_NAMES=( "${d_dpl_names[@]}" )
    D_DPL_NAME_PATHS=( "${d_dpl_name_paths[@]}" )
  fi

  return 0
}

#>  __validate_dpls_in_main_dir
#
## Iterates over previously collected deployment names and paths and ensures 
#. that names are all unique and valid under current rules
#
## Requires:
#.  $D_DPL_NAMES          - Names of deployments currently in dpl directory
#.  $D_DPL_NAME_PATHS     - For each name in $D_DPL_NAMES, delimited list of 
#.                          paths to deployment files with this name
#
## Returns:
#.  0 - All names valid
#.  1 - Otherwise
#
__validate_dpls_in_main_dir()
{
  # Storage variables
  local i dpl_name dpl_str dpl_arr dpl_path

  # Status variable
  local all_good=true

  # Iterate over taken deployment names
  for (( i=0; i<${#D_DPL_NAMES[@]}; i++ )); do

    # Extract this previously taken name and its paths
    dpl_name="${D_DPL_NAMES[$i]}"
    dpl_str="${D_DPL_NAME_PATHS[$i]}"

    # Collect paths to deployment files with this name
    dpl_arr=()
    while [[ $dpl_str ]]; do
      dpl_arr+=( "${dpl_str%%"$D_DELIM"*}" )
      dpl_str="${dpl_str#*"$D_DELIM"}"
    done

    # Validate name
    __validate_dpl_name "$dpl_name" "${dpl_arr[@]}" || all_good=false

    # Check if name is encountered in more than one deployment
    if [ ${#dpl_arr[@]} -gt 1 ]; then

      # Announce
      printf >&2 '%s\n' "Multiple deployments named '$dpl_name' found at:"
      for dpl_path in "${dpl_arr[@]}"; do printf >&2 '  %s\n' "$dpl_path"; done
      printf >&2 '\n%s\n' "Deployment names must be unique"

      # Flip flag
      all_good=false

    fi

  done

  # If already with error, return
  $all_good && return 0 || return 1
}

#>  __validate_dpls_in_add_dir
#
## Iterates over previously collected deployment names and paths and ensures 
#. that names are all unique and valid under current rules
#
## Requires:
#.  $D_ADD_NAMES          - Names of deployments considered for addition to dpl 
#.                          directory
#.  $D_ADD_NAME_PATHS     - For each name in $D_ADD_NAMES, delimited list of 
#.                          paths to deployment files with this name
#
## Returns:
#.  0 - All names valid
#.  1 - Otherwise
#
__validate_dpls_in_add_dir()
{
  # Additional storage variables
  local j add_name add_str add_arr add_path temp

  # Status variable
  local all_good=true

  # Iterate over deployments being newly added
  for (( j=0; j<${#D_ADD_NAMES[@]}; j++ )); do

    # Extract name being added
    add_name="${D_ADD_NAMES[$j]}"
    add_str="${D_ADD_NAME_PATHS[$j]}"

    # Collect paths to deployment files with this name
    add_arr=()
    while [[ $add_str ]]; do
      temp="${add_str%%"$D_DELIM"*}"
      add_arr+=( "${temp#"$D_ADD_DIR/"}" )
      add_str="${add_str#*"$D_DELIM"}"
    done

    # Validate name
    __validate_dpl_name --add "$add_name" "${add_arr[@]}" || all_good=false

    # Check if name is encountered in more than one added deployment
    if [ ${#add_arr[@]} -gt 1 ]; then

      # Announce
      printf >&2 '%s\n' \
        "Attempted to add multiple deployments named '$add_name' at:"
      for add_path in "${add_arr[@]}"; do printf >&2 '  %s\n' "$add_path"; done
      printf >&2 '\n%s\n' "Deployment names must be unique"

      # Flip flag
      all_good=false

    fi

  done

  # Finally, return
  $all_good && return 0 || return 1
}

#>  __validate_dpls_before_adding
#
## Iterates over previously collected deployment names and paths and ensures 
#. that names are all unique and valid under current rules
#
## Requires:
#.  $D_DPL_NAMES          - Names of deployments currently in dpl directory
#.  $D_DPL_NAME_PATHS     - For each name in $D_DPL_NAMES, delimited list of 
#.                          paths to deployment files with this name
#.  $D_ADD_NAMES          - Names of deployments considered for addition to dpl 
#.                          directory
#.  $D_ADD_NAME_PATHS     - For each name in $D_ADD_NAMES, delimited list of 
#.                          paths to deployment files with this name
#
## Returns:
#.  0 - All names valid
#.  1 - Otherwise
#
__validate_dpls_before_adding()
{
  # Storage variables
  local i dpl_name dpl_str dpl_arr dpl_path
  local j add_name add_str add_arr add_path temp

  # Status variables
  local all_good=true

  # Store current case sensitivity setting, then turn it off when needed
  local restore_nocasematch="$( shopt -p nocasematch )"

  # Iterate over deployments being newly added
  for (( j=0; j<${#D_ADD_NAMES[@]}; j++ )); do

    # Extract name being added
    add_name="${D_ADD_NAMES[$j]}"
    add_str="${D_ADD_NAME_PATHS[$j]}"

    # Collect paths to deployment files with this name
    add_arr=()
    while [[ $add_str ]]; do
      temp="${add_str%%"$D_DELIM"*}"
      add_arr+=( "${temp#"$D_ADD_DIR/"}" )
      add_str="${add_str#*"$D_DELIM"}"
    done

    # Turn off case sensitivity for upcoming tests
    shopt -s nocasematch

    # Search for existing dpl by that name
    dpl_arr=()
    for (( i=0; i<${#D_DPL_NAMES[@]}; i++ )); do

      # Extract this previously taken name
      dpl_name="${D_DPL_NAMES[$i]}"

      # Compare names
      [[ $add_name = $dpl_name ]] || continue

      # Extract paths of this deployment name
      dpl_str="${D_DPL_NAME_PATHS[$i]}"

      # Collect paths to deployment files with this name
      while [[ $dpl_str ]]; do
        dpl_arr+=( "${dpl_str%%"$D_DELIM"*}" )
        dpl_str="${dpl_str#*"$D_DELIM"}"
      done

      # First match is enough
      break

    done

    # Restore case sensitivity
    eval "$restore_nocasematch"

    # Check if main directory already contains this dpl name
    if [ ${#dpl_arr[@]} -gt 0 ]; then

      # Announce
      printf >&2 '%s\n' "Attempted to add deployment named '$add_name' at:"
      for add_path in "${add_arr[@]}"; do printf >&2 '  %s\n' "$add_path"; done
      printf >&2 '%s\n' "Deployment named '$dpl_name' already exists at:"
      for dpl_path in "${dpl_arr[@]}"; do printf >&2 '  %s\n' "$dpl_path"; done
      printf >&2 '\n%s\n' "Deployment names must be unique"

      # Flip flag
      all_good=false

    fi

  done

  # Finally, return
  $all_good && return 0 || return 1
}

#>  __validate_dpl_name [--add] NAME PATH…
#
## Check if deployment name (along with paths to files with this name) are 
#. fully valid
#
## Returns:
#.  0 - Name and paths are valid
#.  1 - Otherwise
#
__validate_dpl_name()
{
  # Extract mode
  local adding=false; [ "$1" = '--add' ] && { adding=true; shift; }

  # Extract name
  local name="$1"; shift

  # Storage and status variables
  local path all_good=true

  # Store current case sensitivity setting, then turn it off when needed
  local restore_nocasematch="$( shopt -p nocasematch )"

  # Turn off case sensitivity for upcoming tests
  shopt -s nocasematch

  # Check if name is ‘Divinefile’ or other reserved alias
  if [[ $name =~ ^(Divinefile|dfile|df)$ ]]; then

    # Announce
    if $adding; then
      printf >&2 '%s\n' "Attempted to add deployment named '$name' at:"
    else
      printf >&2 '%s\n' "Deployment named '$name' found at:"
    fi
    for path do printf >&2 '  %s\n' "$path"; done
    printf >&2 '\n%s\n' "Name '$name' is reserved"

    # Flip flag
    all_good=false

  fi

  # Check if name coincides with potential group name
  if [[ $name =~ ^([0-9]|!)$ ]]; then

    # Announce
    if $adding; then
      printf >&2 '%s\n' "Attempted to add deployment named '$name' at:"
    else
      printf >&2 '%s\n' "Deployment named '$name' found at:"
    fi
    for path do printf >&2 '  %s\n' "$path"; done
    printf >&2 '\n%s\n' "Name '$name' is reserved"

    # Flip flag
    all_good=false

  fi

  # Restore case sensitivity
  eval "$restore_nocasematch"

  # Return
  $all_good && return 0 || return 1
}

__merge_added_deployments()
{
  # Extract target directory
  local tgt_dir="$1"; shift

  # Storage variables
  local j temp

  # Iterate over added deployments
  for (( j=0; j<${#D_ADD_NAMES[@]}; j++ )); do

    # Add name to main array
    D_DPL_NAMES+=( "${D_ADD_NAMES[$j]}" )

    # Extract, modify, and add path
    temp="${D_ADD_NAME_PATHS[$j]#"$D_ADD_DIR"}"
    temp="${tgt_dir}${temp}"
    D_DPL_NAME_PATHS+=( "$temp" )

  done

  # All done
  return 0
}

__assemble_main