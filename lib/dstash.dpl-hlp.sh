#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: dstash
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.15
#:revremark:    Initial revision
#:created_at:   2019.05.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for any deployments that require persistent state
#
## These helper functions allow to: stash a string, check if a string has been 
#. previously stashed, and finally remove all instanses of stashed string. 
#. Simple text file in backups directory is used for storage. Each deployment 
#. gets its own stash.
#
## Following functions are available:
#>  dstash_record [STRING]…
#>  dstash_exists [STRING]…
#>  dstash_remove [STRING]…

#>  dstash_record [STRING]…
#
## Stores instance of every non-empty STRING into a temp file exclusive to this 
#. deployment. Will duplicate already existing string.
#
## Returns:
#.  0 - Successfully stashed (even if nothing was given to be stashed)
#.  1 - Otherwise
#.  2 - Stash is unavailable for any reason
#
dstash_record()
{
  # Do pre-flight checks
  dstash_prepare || return 2

  # Storage variable
  local string

  # Status variable
  local all_stashed=true

  # Iterate over strings to be stashed
  for string do

    # Skip empty args
    [ -n "$string" ] \
      || { dprint_debug "${FUNCNAME[0]}: Skipped empty argument"; continue; }
    
    # Stash string
    printf '|%s|\n' >>"$D_DPL_STASH_FILEPATH" || all_stashed=false; 

  done

  # Report
  $all_stashed && return 0 || return 1
}

#>  dstash_exists [STRING]…
#
## Returns zero if every non-empty STRING occurrs at least once in stash file, 
#. otherwise returns non-zero
#
## Returns:
#.  0 - Every non-empty STRING exists in stash, even if no STRINGs provided
#.  1 - Otherwise
#.  2 - Stash is unavailable for any reason
#
dstash_exists()
{
  # Do pre-flight checks
  dstash_prepare || return 2

  # Storage variable
  local string

  # Status variable
  local all_exist=true

  # Iterate over strings to be checked
  for string do

    # Skip empty args
    [ -n "$string" ] \
      || { dprint_debug "${FUNCNAME[0]}: Skipped empty argument"; continue; }
    
    # Stash string
    grep -Fxq "|$string|" "$D_DPL_STASH_FILEPATH" 2>/dev/null \
      || all_exist=false; 

  done

  # Report
  $all_exist && return 0 || return 1
}

#>  dstash_remove [STRING]…
#
## Removes every occurence of every non-empty STRING from stash file
#
## Returns:
#.  0 - Successfully removed (even if nothing was given to be removed)
#.  1 - Otherwise
#.  2 - Stash is unavailable for any reason
#
dstash_remove()
{
  # Do pre-flight checks
  dstash_prepare || return 2

  # Storage variable
  local string temp_stash temp_line

  # Status variable
  local all_removed=true

  # Iterate over strings to be checked
  for string do

    # Skip empty args
    [ -n "$string" ] \
      || { dprint_debug "${FUNCNAME[0]}: Skipped empty argument"; continue; }

    # Check if string is already absent
    grep -Fxq "|$string|" "$D_DPL_STASH_FILEPATH" 2>/dev/null || continue; 

    # Create temp file
    temp_stash="$( mktemp )"

    # Copy non-matching lines to temp file
    while read -r temp_line; do
      [ "$temp_line" = "|$string|" ] || printf '%s\n' "$temp_line"
    done <"$D_DPL_STASH_FILEPATH" >"$temp_stash"

    # Move temp file in place of stash
    mv -f -- "$temp_stash" "$D_DPL_STASH_FILEPATH" || {
      dprint_debug "${FUNCNAME[0]}: Failed to move temp file at:" \
        -i "$temp_stash" -n 'to intended location at:' \
        -i "$D_DPL_STASH_FILEPATH"
      all_removed=false
    }
    
    # Stash string
    grep -Fxq "|$string|" "$D_DPL_STASH_FILEPATH" 2>/dev/null \
      && all_removed=false; 

  done

  # Report
  $all_removed && return 0 || return 1
}

#>  dstash_clear
#
## Erases everything from stash file (leaves it empty)
#
## Returns:
#.  0 - Successfully emptied out stash file
#.  1 - Otherwise
#
dstash_clear()
{
  # Do pre-flight checks
  dstash_prepare || return 2

  # Positively destroy contents of stash file
  >"$D_DPL_STASH_FILEPATH" && return 0 || return 1
}

#>  dstash_prepare
#
## Helper function that ensures that stashing is good to go
#
## Returns:
#.  0 - Ready for stashing
#.  1 - Otherwise
#
dstash_prepare()
{
  # Check if within deployment by ensuring $D_NAME is populated
  [ -n "$D_NAME" ] || {
    dprint_debug "${BASH_SOURCE[0]}: Called without \$D_NAME populated"
    return 1
  }

  # Check that $D_BACKUPS_DIR is populated
  [ -n "$D_BACKUPS_DIR" ] || {
    dprint_debug "${BASH_SOURCE[0]}: Called without \$D_BACKUPS_DIR populated"
    return 1
  }

  # Ensure directory for this deployment exists
  mkdir -p -- "$D_BACKUPS_DIR/$D_NAME" || {
    dprint_debug \
      "${BASH_SOURCE[0]}: Failed to create deployment directory at:" \
      -i "$D_BACKUPS_DIR/$D_NAME"
    return 1
  }

  # Compose path to stash file
  local stash_filepath="$D_BACKUPS_DIR/$D_NAME/stash-file.txt"

  # Ensure stash file is not a directory
  [ -d "$stash_filepath" ] && {
    dprint_debug \
      "${BASH_SOURCE[0]}: Stash file path occupied by a directory:" \
      -i "$stash_filepath"
    return 1
  }

  # If stash file does not yet exist, create it
  if [ ! -e "$stash_filepath" ]; then
    touch -- "$stash_filepath" || {
      dprint_debug \
        "${BASH_SOURCE[0]}: Failed to create fresh stash file at:" \
        -i "$stash_filepath"
      return 1
    }
  fi

  # Ensure stash file is a readable file
  [ -f "$stash_filepath" -a -r "$stash_filepath" ] || {
    dprint_debug \
      "${BASH_SOURCE[0]}: Stash file path is not a readable file:" \
      -i "$stash_filepath"
    return 1
  }

  # Populate stash file path globally and return
  D_DPL_STASH_FILEPATH="$stash_filepath"
  return 0
}