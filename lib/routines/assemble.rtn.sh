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

#> __assemble_tasks
#
## Collects tasks to be performed from these files:
#.  * Divinefile    - Located in directories under $D_DEPLOYMENTS_DIR
#.  * *.dpl.sh      - Located in directories under $D_DEPLOYMENTS_DIR
#
## Provides into the global scope:
#.  $D_TASK_QUEUE   - Associative array with each taken priority paired with an 
#.                    empty string
#.  $D_PACKAGES     - Associative array with each priority taken by at least 
#.                    one package paired with a semicolon-separated list of 
#.                    package names
#.  $D_DEPLOYMENTS  - Associative array with each priority taken by at least 
#.                    one deployment paired with a semicolon-separated list of 
#.                    absolute canonical paths to *.dpl.sh files
#.  $D_DPL_NAMES    - Array of deployment names used to detect duplications
#
## Returns:
#.  0 - Arrays assembled successfully
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__assemble_tasks()
{
  # Status variable
  local return_code=0

  # Global storage arrays
  D_TASK_QUEUE=()
  D_PACKAGES=()
  D_DEPLOYMENTS=()
  D_DPL_NAMES=()

  # Parse Divinefile
  __parse_divinefile

  # If there are packages to process, ensure root stash is ready
  if [ ${#D_PACKAGES[@]} -gt 0 ] && ! dstash --root ready; then
    # No root stash — no packages
    printf '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Divinefile will not be processed' \
      'Root stash is not available'
    # Erase all collected packages
    D_PACKAGES=()
  fi

  # Locate *.dpl.sh files
  __locate_dpl_sh_files

  # Check if any tasks were found
  if [ ${#D_TASK_QUEUE[@]} -eq 0 ]; then
    printf '%s: %s: %s\n' \
      "$( basename -- "${BASH_SOURCE[0]}" )" \
      'Nothing to do' \
      'Not a single task matches given criteria'
    exit 0
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
  readonly D_PACKAGES
  readonly D_DEPLOYMENTS

  # Remove used up array
  unset D_DPL_NAMES

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
#.  $D_PACKAGES     - Associative array with each priority taken by at least 
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
        D_PACKAGES["$priority"]+="$chunk;"

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

#> __locate_dpl_sh_files
#
## Collects deployments to be performed from *.dpl.sh files located under 
#. $D_DEPLOYMENTS_DIR
#
## Requires:
#.  $D_DEPLOYMENTS_DIR      - From __populate_globals
#.  $D_DPL_SH_SUFFIX        - From __populate_globals
#.  $D_DPL_NAME_REGEX       - From __populate_globals
#.  $D_DPL_PRIORITY_REGEX   - From __populate_globals
#.  $D_DEFAULT_PRIORITY     - From __populate_globals
#
## Modifies in the global scope:
#.  $D_TASK_QUEUE   - Associative array with each taken priority paired with an 
#.                    empty string
#.  $D_DEPLOYMENTS  - Associative array with each priority taken by at least 
#.                    one deployment paired with a semicolon-separated list of 
#.                    absolute canonical paths to *.dpl.sh files
#
## Returns:
#.  0 - Arrays populated successfully
#.  1 - Failed to access $D_DEPLOYMENTS_DIR
#.  1 - (script exit) Either of the following is detected:
#.        * Deployment called ‘Divinefile’
#.        * Re-used deployment name
#.        * Deployment file with ‘;’ in its path
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
__locate_dpl_sh_files()
{
  # Check if deployments directory exists
  [ -d "$D_DEPLOYMENTS_DIR" ] || return 1

  # Store current case sensitivity setting, then turn it off when needed
  local restore_nocasematch="$( shopt -p nocasematch )"

  # Iterate over directories descending from deployments dirpath
  local dirpath divinedpl_filepath name flags priority taken_name
  local restore_nocasematch
  local adding arg
  while IFS= read -r -d $'\0' divinedpl_filepath; do

    # Ensure *.dpl.sh is a readable file
    [ -r "$divinedpl_filepath" -a -f "$divinedpl_filepath" ] || continue

    # Extract directory containing *.dpl.sh file
    dirpath="$( dirname -- "$divinedpl_filepath" )"

    # If file path contains ‘;’, skip (‘;’ is a reserved delimiter)
    [[ $divinedpl_filepath == *';'* ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment file with ';' in its path found at:" \
        "$divinedpl_filepath" \
        'Semicolon in path is disallowed'
      exit 1
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

    # Check if name is ‘Divinefile’
    [[ $name =~ ^(Divinefile|dfile|df)$ ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment named '$name' found at:" \
        "$divinedpl_filepath" \
        "Name '$name' is reserved"
      exit 1
    }

    # Check if name coincides with potential group name
    [[ $name =~ ^([0-9]|!)$ ]] && {
      printf >&2 '%s\n  %s\n\n%s\n' \
        "Deployment named '$name' found at:" \
        "$divinedpl_filepath" \
        "Name '$name' is reserved"
      exit 1
    }

    # Check if already encountered this deployment name
    for taken_name in "${D_DPL_NAMES[@]}"; do
      [[ $taken_name == $name ]] && {
        printf >&2 '%s\n%s\n  %s\n\n%s\n' \
          "Multiple deployments named '$name'" \
          'Most recent found at:' \
          "$divinedpl_filepath" \
          "Re-used deployment names are disallowed"
        exit 1
      }
    done

    # Add this deployment name to list of taken deployment names
    D_DPL_NAMES+=("$name")

    # Restore case sensitivity
    eval "$restore_nocasematch"

    # Plan to add this *.dpl.sh
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

    # Add current priority to task queue
    D_TASK_QUEUE["$priority"]='taken'

    # Add current package to packages queue
    D_DEPLOYMENTS["$priority"]+="$divinedpl_filepath;"

  done < <( find -L "$D_DEPLOYMENTS_DIR" -mindepth 1 -maxdepth 14 \
    -name "$D_DPL_SH_SUFFIX" -print0 )

  return 0
}

__assemble_tasks