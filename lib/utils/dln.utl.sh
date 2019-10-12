#!/usr/bin/env bash
#:title:        Divine Bash utils: dln
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2018.03.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

## dln - divine link
#
#>  dln [-f?rdqv]... [--help|version] [--] REAL_PATH SYMLINK_PATH [BACKUP_PATH]
#
## Ensures existence of symbolik link at SYMLINK_PATH, pointing to REAL_PATH. 
#. If new symlink is created, optionally moves whatever currently occupies 
#. SYMLINK_PATH to BACKUP_PATH.
#
## Resolves paths from current working directory: first to absolute without 
#. touching symlinks, then to canonical. Uses absolute real path as symlink 
#. target. Requires real path to exist.
#
## Does not clobber anything without -f option. With it, still guards against 
#. clobbering at real path. Creates parent directories as necessary. Refuses to 
#. create cyclic symlinks. Trears directories same as regular files.
#
## Options:
#.  -f, --force   - Enforce clobbering at symlink or backup paths
#.  -?, --is-restorable
#.                - (overrides previous -r) Ask mode.
#.                  Two arguments: returns 0 if symlink path looks like it has 
#.                  been created by this function in regular mode; else 1.
#.                  Three arguments: to return 0, also requires BACKUP_PATH to 
#.                  exist.
#.  -r, --restore - (overrides previous -?) Restore mode. Works only when -? 
#.                  option would have returned 0.
#.                  Two arguments: removes symlink path.
#.                  Three arguments: also moves backup path to symlink path.
#.  -d, --dry-run - Print principal commands instead of executing them
#.  -q, --quiet   - Suppress most error messages
#.  -v, --verbose - (default) Report error messages
#.  --help        - Display help summary
#.  --version     - Display version information
#.  --ping        - Return 0 without doing anything
#
## Parameters:
#.  $1  - Path to where real file is located
#.  $2  - Path to where existence of symlink is to be ensured
#.  $3  - (optional) Path for moving existing symlink path to
#
## Returns:
#.  0   - Desired symlink has been created or is already in place
#.  1   - Otherwise
#.  100 - (without '-f') Symlink or backup path is occupied by a file
#.  101 - (without '-f') Symlink or backup path is occupied by a directory
#.  102 - (without '-f') Symlink or backup path is occupied by a symlink
#
## Returns (with '-?'):
#.  0 - Symlink path is a symlink pointing to absolute real path. Also, backup 
#.      path (if provided) exists.
#.  1 - Otherwise.
#
## Returns (with '-r'):
#.  0 - Conditions for '-?' are met. Symlink at symlink path has been removed, 
#.      and backup path (if provided) has been moved back to symlink path.
#.  1 - Otherwise.
#
## Prints:
#.  stdout: *nothing*
#.          (with '-?') (without '-q') Human readable answer
#.  stderr: (default) Error descriptions
#.          (with '-q') As little as possible
#
dln()
{
  # Storage variables
  local args=() delim=false i opt
  local force=false quiet=false
  local help=false version=false
  local mode= dry_run=false

  # Parse args
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                   delim=true;;
      -f|--force)           force=true;;
      -\?|--is-restorable)  mode=?;;
      -r|--restore)         mode=r;;
      -d|--dry-run)         dry_run=true;;
      -q|--quiet)           quiet=true;;
      -v|--verbose)         quiet=false;;
      --help)               help=true;;
      --version)            version=true;;
      --ping)               return 0;;
      -*)                   for i in $( seq 2 ${#1} ); do
                              opt="${1:i-1:1}"
                              case "$opt" in
                                f)  force=true;;
                                \?) mode=?;;
                                r)  mode=r;;
                                d)  dry_run=true;;
                                q)  quiet=true;;
                                v)  quiet=false;;
                                *)  printf >&2 '%s: illegal option -- %s\n' \
                                      "${FUNCNAME[0]}" \
                                      "$opt"
                                    return 1;;
                              esac
                            done;;
      *)                    args+=("$1");;
    esac; shift
  done

  # Show version if requested
  $version && {
    # Add bolding if available
    local bold normal
    if type -P tput &>/dev/null && tput sgr0 &>/dev/null \
      && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]
    then bold=$(tput bold); normal=$(tput sgr0)
    else bold="$(printf "\033[1m")"; NORMAL="$(printf "\033[0m")"; fi

    # Store version message in a variable
    local version_msg
    read -r -d '' version_msg << EOF
${bold}dln${normal} 3.0.0
Part of ${bold}Divine.dotfiles${normal} <https://github.com/no-simpler/divine-dotfiles>
This is free software: you are free to change and redistribute it
There is NO WARRANTY, to the extent permitted by law

Written by ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>
EOF
    # Print version message
    printf '%s\n' "$version_msg"
    return 0
  }

  # Show help if requested
  $help && {
    # Add bolding if available
    local bold normal
    if type -P tput &>/dev/null && tput sgr0 &>/dev/null \
      && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]
    then bold=$(tput bold); normal=$(tput sgr0)
    else bold="$(printf "\033[1m")"; NORMAL="$(printf "\033[0m")"; fi

    # Store help summary in a variable
    local help_msg
    read -r -d '' help_msg << EOF
NAME
    ${bold}dln${normal} - divine link

SYNOPSIS
    ${bold}dln${normal} [-f?rdqv]... [--help|version] [--] REAL_PATH SYMLINK_PATH [BACKUP_PATH]

DESCRIPTION
    Ensures existence of symbolik link at SYMLINK_PATH, pointing to REAL_PATH.
    If new symlink is created, optionally moves whatever currently occupies 
    SYMLINK_PATH to BACKUP_PATH.

    Resolves paths from current working directory: first to absolute without 
    touching symlinks, then to canonical. Uses absolute real path as symlink 
    target. Requires real path to exist.
    
    Does not clobber anything without -f option. With it, still guards against 
    clobbering at real path. Creates parent directories as necessary. Refuses 
    to create cyclic symlinks. Trears directories same as regular files.

OPTIONS
    -f, --force     Enforce clobbering at symlink or backup paths
    -?, --is-restorable 
                    (overrides previous -r) Ask mode.
                    Two arguments: returns 0 if symlink path looks like it has 
                    been created by this function in regular mode; else 1.
                    Three arguments: to return 0, also requires BACKUP_PATH to 
                    exist.
    -r, --restore   (overrides previous -?) Restore mode. Works only when -? 
                    option would have returned 0.
                    Two arguments: removes symlink path.
                    Three arguments: also moves backup path to symlink path.
    -d, --dry-run   Print principal commands instead of executing them
    -q, --quiet     Suppress most error messages
    -v, --verbose   (default) Report error messages
    --help          Display help summary
    --version       Display version information
    --ping          Return 0 without doing anything

AUTHOR
    ${bold}Grove Pyree${normal} <grayarea@protonmail.ch>

    Part of ${bold}Divine.dotfiles${normal} <https://github.com/no-simpler/divine-dotfiles>

    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
EOF
    # Print help summary
    if less --version &>/dev/null; then
      less -R <<<"$help_msg"
    else
      printf '%s\n' "$help_msg"
    fi
    return 0
  }

  # Check number of arguments
  [ ${#args[@]} -lt 2 ] && {
    printf >&2 'Usage: %s %s\n' \
      "${FUNCNAME[0]}" \
      '[-f?rdqv]... REAL_PATH SYMLINK_PATH [BACKUP_PATH]'
    printf >&2 "Try '%s --help' for more information\n" \
      "${FUNCNAME[0]}"
    return 1
  }

  # Storage variables
  local abspath=() canonpath=() parentpath=()
  local backing_up=true
  local exist_part nonexist_part status temppath
  local clobber_argpath clobber_abspath clobber_canonicalpath
  local symlink_parentpath backup_parentpath

  # ================= #
  # Process arguments #
  # ================= #

  # Take three arguments: 0=REAL, 1=SYMLINK, 2=BACKUP
  local type
  # Iterating over three arguments
  for type in 0 1 2; do

    # Is argument an empty string?
    [ -z "${args[$type]}" ] && {

      # For real and symlink paths this is a no-go
      [ $type -lt 2 ] && {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[$type]}" \
          'Empty argument'
        return 1
      }

      # For backup path, empty arg means no backing up
      backing_up=false
      # No further processing
      continue
      
    }

    # Fill up temp variables
    exist_part="${args[$type]}" nonexist_part=

    # Resolve path to absolute, ignore symlinks
    if [ -e "$exist_part" ]; then

      # Argument path exists

      if [ -d "$exist_part" ]; then
        # For directories, cd and capture pwd output
        abspath[$type]="$( cd "$exist_part" &>/dev/null \
          && pwd || exit $? )"; status=$?
      else
        # For files, cd into parent dir and capture pwd output
        abspath[$type]="$( cd "$( dirname -- "$exist_part" )" &>/dev/null \
          && pwd || exit $? )"; status=$?
        abspath[$type]="${abspath[$type]}/$( basename -- "$exist_part" )"
      fi

      # Update temp variable for later use
      exist_part="${abspath[$type]}"

    else

      # Argument path does not exist

      # Find closest ancestor that exists
      while [ ! -e "$exist_part" ]; do
        # Shift one path element to non-existent part
        nonexist_part="$( basename -- "$exist_part" )/$nonexist_part"
        exist_part="$( dirname -- "$exist_part" )"
      done

      # Non-existent path can only descend from a directory
      [ ! -d "$exist_part" ] && {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[$type]}" \
          'Invalid path'
        return 1
      }

      # Resolve existing part from within, ignore symlinks
      exist_part="$( cd "$exist_part" &>/dev/null && pwd || exit $? )"
      status=$?

      # Put absolute path back together
      abspath[$type]="${exist_part%/}/${nonexist_part%/}"
      
    fi

    # Check if 'cd' command above has failed
    [ $status -ne 0 ] && {
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[$type]}" \
        'Inaccessible'
      return 1
    }

    # Back to processing: resolve existing part to canonical
    if [ -d "$exist_part" ]; then

      # For directories, cd -P and capture pwd output
      exist_part="$( cd -P "$exist_part" &>/dev/null && pwd )"

    else

      # For files, recursively resolve base symlink
      while [ -L "$exist_part" ]; do
        temppath="$( dirname -- "$exist_part" )"
        exist_part="$( readlink -- "$exist_part" )"
        [[ $exist_part != /* ]] && exist_part="$temppath/$exist_part"
      done

      # Then, cd -P into parent dir and capture pwd output
      temppath="$( cd -P "$( dirname -- "$exist_part" )" &>/dev/null && pwd )"

      # Put existing part back together
      exist_part="${temppath%/}/$( basename -- "$exist_part" )"

    fi

    # Put canonical path back together
    canonpath[$type]="${exist_part%/}/$nonexist_part"
  
  # Done iterating over three arguments
  done

  # ================= #
  # Pre-flight checks #
  # ================= #

  # Check if user-provided real and symlink paths are identical when absolute
  if [ "${abspath[0]}" = "${abspath[1]}" ]; then
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "'${args[0]}' & '${args[1]}'" \
      'Same path'
    return 1
  fi

  ## Check if user-provided real and backup paths are identical when absolute.
  #. This is equivalent to moving symlink path to real/backup path and leaving 
  #. a forwarding symlink. There is an entire sibling function for that.
  if [ "${abspath[0]}" = "${abspath[2]}" ]; then
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "'${args[0]}' & '${args[2]}'" \
      'Same path'
    return 1
  fi

  # Check if user-provided symlink and backup paths are identical when absolute
  if [ "${abspath[1]}" = "${abspath[2]}" ]; then
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "'${args[1]}' & '${args[2]}'" \
      'Same path'
    return 1
  fi

  # ===================== #
  # Ask and restore modes #
  # ===================== #

  ## The goal here is to answer the question: does it look like this function 
  #. has been previously called with same arguments (sans -? or -r) and, 
  #. furthermore, is it now possible to undo that change. The -r option then 
  #. goes ahead and restores whatever there is to restore.

  # The entire section is only relevant in ask or restore modes
  if [ -n "$mode" ]; then

    # ---------------------------- #
    # Real path checks (-? and -r) #
    # ---------------------------- #

    # Check if real path exists
    if [ ! -e "${args[0]}" ]; then
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[0]}" \
        'No such file or directory'
      return 1
    fi

    # ------------------------------- #
    # Symlink path checks (-? and -r) #
    # ------------------------------- #

    # Basically, symlink path must be a symlink pointing precisely at real path

    # Check if symlink path exists
    if [ -e "${args[1]}" ]; then
      
      # Check if existing symlink path is a symlink (use absolute path)
      if [ -L "${abspath[1]}" ]; then

        # Check if real and symlink paths resolve to same path
        if [ "${canonpath[0]}" = "${canonpath[1]}" ]; then

          # Grab exact link target at symlink path
          temppath="$( readlink -- "${abspath[1]}" )"

          # Check if symlink at symlink path points precisely at real abspath
          if [ "$temppath" = "${abspath[0]}" ]; then

            # If in -? mode, print an answer
            [ "$mode" = '?' ] && {
              $quiet || printf "%s: %s\n" \
                "${FUNCNAME[0]}" \
                "'${abspath[1]}' is a symlink pointing to '${abspath[0]}'"
              # Also, if there is no third argument, return 0
              [ -z "${args[2]}" ] && {
                $quiet || printf "%s: %s\n" \
                  "${FUNCNAME[0]}" \
                  "Set-up appears restorable" 
                return 0
              }
            }
          
          else

            # Symlink at symlink path does NOT point precisely at real abspath
            $quiet || printf >&2 '%s: %s: %s\n' \
              "${FUNCNAME[0]}" \
              "${args[1]}" \
              'Wrong-ish symlink'
            return 1
          
          fi
        
        else

          # Real and symlink paths do NOT resolve to same path
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "${args[1]}" \
            'Wrong symlink'
          return 1

        fi
      
      else

        # Existing symlink path is NOT a a symlink
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[1]}" \
          'Not a symlink'
        return 1
      
      fi
    
    else

      # Symlink path does NOT exist
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[1]}" \
        'No such file or directory'
      return 1

    fi

    # ------------------------------ #
    # Backup path checks (-? and -r) #
    # ------------------------------ #

    # At this point, backup path just needs to exist

    # Only perform these checks if there are three arguments
    if $backing_up; then

      # Check if backup path exists
      if [ -e "${args[2]}" ]; then

        # -? mode can return 0
        [ "$mode" = '?' ] && {
          $quiet || printf "%s: %s\n" \
            "${FUNCNAME[0]}" \
            "'${args[2]}' exists"
          $quiet || printf "%s: %s\n" \
            "${FUNCNAME[0]}" \
            "Set-up appears restorable" 
          return 0
        }

      else

        # Backup path does NOT exist
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[2]}" \
          'No such file or directory'
        return 1
      
      fi
    
    fi

    # ---------------- #
    # Restoration (-r) #
    # ---------------- #

    ## At this point, -? mode has definitely returned, and -r mode, if it made 
    #. it to this point, has all it needs to do its job and return

    # Remove symlink at symlink path
    if $dry_run; then
      printf '%s\n' "rm -rf -- \"${abspath[1]}\""
    else
      rm -rf -- "${abspath[1]}" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${abspath[1]}" \
          'Failed to remove symlink'
        return 1
      }
    fi

    # Only perform this move if there are three arguments
    if $backing_up; then

      # Restore backup path to symlink path
      if $dry_run; then
        printf '%s\n' \
          "mv -f -- \"${abspath[2]}\" \"${abspath[1]}\""
      else
        mv -f -- "${abspath[2]}" "${abspath[1]}" &>/dev/null || {
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "${abspath[1]}" \
            'Failed to restore backup'
          return 1
        }
      fi

    fi

    # Return from -r mode
    return 0
  
  # Done with -? and -r modes
  fi

  # ================ #
  # Real path checks #
  # ================ #

  # Check if real path exists
  if [ ! -e "${args[0]}" ]; then

    # Real path does NOT exist
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "${args[0]}" \
      'No such file or directory'
    return 1
  
  fi

  # =================== #
  # Symlink path checks #
  # =================== #

  # Check if symlink path exists
  if [ -e "${args[1]}" ]; then
  
    # Symlink path is occupied. Will there be backup?
    $backing_up || {
      # Save paths that are to be clobbered for later checking
      clobber_argpath="${args[1]}"
      clobber_abspath="${abspath[1]}"
      clobber_canonicalpath="${canonpath[1]}" 
    }

  else

    # Symlink path does NOT exist

    # Meaning, there is nothing to back up
    backing_up=false
  
  fi

  # ========================== #
  # Real + symlink pair checks #
  # ========================== #

  # Check if real and symlink paths resolve to same path
  if [ "${canonpath[0]}" = "${canonpath[1]}" ]; then

    # In here, both real and symlink paths exist

    # Check if real path is a symlink (use absolute path)
    if [ -L "${abspath[0]}" ]; then

      # Check if symlink path is a symlink (use absolute path)
      if [ -L "${abspath[1]}" ]; then

        ## There is a non-zero chance that one of the symlinks depends on the 
        #. other to reach their shared ultimate target. For safety, this set-up 
        #. is not allowed.
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "'${args[0]}' & '${args[1]}'" \
          'Symlinks point to same path'
        return 1

      else

        # Symlink path is NOT a symlink

        # This would create a cyclic symlink
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "'${args[0]}' & '${args[1]}'" \
          'Would create cyclic symlink'
        return 1

      fi

    else

      # Real path is NOT a symlink

      # Check if symlink path is a symlink (use absolute path)
      if [ -L "${abspath[1]}" ]; then

        # Grab exact link target at symlink path
        temppath="$( readlink -- "${abspath[1]}" )"
        # Check if symlink at symlink path points precisely at real abspath
        if [ "$temppath" = "${abspath[0]}" ]; then
          # The job has been done already
          return 0
        fi

      else

        # Symlink path is NOT a symlink

        # This is symlinking onto itself
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "'${args[0]}' & '${args[1]}'" \
          'Same path'
        return 1

      fi

    fi

  fi

  # ================== #
  # Backup path checks #
  # ================== #

  # Only perform these checks if backing up at all
  if $backing_up; then

    # Check if backup path exists
    if [ -e "${args[2]}" ]; then
    
      # Save paths that are to be clobbered for later checking
      clobber_argpath="${args[2]}"
      clobber_abspath="${abspath[2]}"
      clobber_canonicalpath="${canonpath[2]}" 

    fi

  fi

  # ============================ #
  # Symlink + backup pair checks #
  # ============================ #

  # Only perform these checks if backing up at all
  if $backing_up; then

    # Check if symlink and backup paths resolve to same path
    if [ "${canonpath[1]}" = "${canonpath[2]}" ]; then

      # In here, both symlink and backup paths exist

      # Check if symlink path is a symlink (use absolute path)
      if [ -L "${abspath[1]}" ]; then

        # Check if backup path is a symlink (use absolute path)
        if [ -L "${abspath[2]}" ]; then

          ## There is a non-zero chance that one of the symlinks depends on the 
          #. other to reach their shared ultimate target. For safety, this 
          #. set-up is not allowed.
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "'${args[1]}' & '${args[2]}'" \
            'Symlinks point to same path'
          return 1

        else

          # Backup path is NOT a symlink

          ## Symlink path is a symlink pointing to regular file/dir at backup 
          #. path. Proceeding would destroy data instead of backing it up.
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "${args[1]}" \
            'Backing up onto itself'
          return 1

        fi

      else

        # Symlink path is NOT a symlink

        # Check if backup path is a symlink (use absolute path)
        if [ -L "${abspath[2]}" ]; then

          # This is fine as long as user consents to clobbering of backup path
          :

        else

          # Backup path is NOT a symlink

          # This is backing up onto itself
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "'${args[1]}' & '${args[2]}'" \
            'Same path'
          return 1

        fi

      fi

    fi

  fi

  # ========================= #
  # Real + backup pair checks #
  # ========================= #

  # Only perform these checks if backing up at all
  if $backing_up; then

    # Check if real and backup paths resolve to same path
    if [ "${canonpath[0]}" = "${canonpath[2]}" ]; then

      # In here, both real and backup paths exist

      # Check if real path is a symlink (use absolute path)
      if [ -L "${abspath[0]}" ]; then

        # Check if backup path is a symlink (use absolute path)
        if [ -L "${abspath[2]}" ]; then

          ## There is a non-zero chance that one of the symlinks depends on the 
          #. other to reach their shared ultimate target. For safety, this 
          #. set-up is not allowed.
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "'${args[0]}' & '${args[2]}'" \
            'Symlinks point to same path'
          return 1

        else

          # Backup path is NOT a symlink

          ## Real path is a symlink pointing to regular file/dir at backup 
          #. path. Proceeding would essentially clobber real path.
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "${args[0]}" \
            'Backing up onto real path'
          return 1

        fi

      else

        # Real path is NOT a symlink

        # Check if backup path is a symlink (use absolute path)
        if [ -L "${abspath[2]}" ]; then

          # This is fine as long as user consents to clobbering of backup path
          :

        else

          # Backup path is NOT a symlink

          ## This is equivalent to moving symlink path to real/backup path and 
          #. leaving a forwarding symlink. There is an entire sibling function 
          #. for that.
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "'${args[0]}' & '${args[2]}'" \
            'Same path'
          return 1

        fi

      fi

    fi

  fi

  # ===================== #
  # Pre-clobbering checks #
  # ===================== #

  # Check if clobbering is set to occur
  if [ -n "$clobber_abspath" ]; then

    # Check if clobbering is enforced
    if $force; then

      # If symlink is to be clobbered, disregard what it points to
      [ -L "$clobber_abspath" ] && clobber_canonicalpath=

      # Make sure no sensitive system files/directories are to be clobbered
      if [[ $clobber_abspath =~ ^/+[0-z]*/*$ ]] \
        || [ "$clobber_abspath" = "$HOME" ] \
        || [[ $clobber_canonicalpath =~ ^/+[0-z]*/*$ ]] \
        || [ "$clobber_canonicalpath" = "$HOME" ]; then
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$clobber_argpath" \
          'Not touching that'
        return 1
      fi

    else

      # Clobbering is NOT enforced

      # Report existing symlink
      [ -L "$clobber_abspath" ] && {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$clobber_argpath" \
          'Already exists (symlink)'
        return 102
      }

      # Report existing directory
      [ -d "$clobber_abspath" ] && {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$clobber_argpath" \
          'Already exists (directory)'
        return 101
      }

      # Report existing file
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "$clobber_argpath" \
        'Already exists (file)'
      return 100

    fi

  fi

  # ================== #
  # Parent directories #
  # ================== #

  # Extract parent path of backup path
  backup_parentpath="$( dirname -- "${abspath[2]}" )"

  # Ensure backup parent directory exists
  if [ "$backing_up" = true -a ! -e "$backup_parentpath" ]; then

    if $dry_run; then
      printf '%s\n' "mkdir -p -- \"$backup_parentpath\""
    else
      mkdir -p -- "$backup_parentpath" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$backup_argpath" \
          'Failed to create parent dirs'
        return 1
      }
    fi

  fi

  # Extract parent path of symlink path
  symlink_parentpath="$( dirname -- "${abspath[1]}" )"

  # Ensure symlink parent directory exists
  if [ ! -e "$symlink_parentpath" ]; then

    if $dry_run; then
      printf '%s\n' "mkdir -p -- \"$symlink_parentpath\""
    else
      mkdir -p -- "$symlink_parentpath" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$symlink_argpath" \
          'Unable to create parent dirs'
        return 1
      }
    fi

  fi

  # ========== #
  # Backing up #
  # ========== #

  # Backing up
  if $backing_up; then

    ## Remove pre-existing directory at backup path, to avoid mv's special 
    #. treatment of directories
    if [ -d "${abspath[2]}" -a $force = true ]; then

      if $dry_run; then
        printf '%s\n' "rm -rf -- \"${abspath[2]}\""
      else
        rm -rf -- "${abspath[2]}" &>/dev/null || {
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "${args[2]}" \
            'Failed to overwrite at backup path'
          return 1
        }
      fi

    fi

    # Perform backing up
    if $dry_run; then
      printf '%s\n' "mv -f -- \"${abspath[1]}\" \"${abspath[2]}\""
    else
      mv -f -- "${abspath[1]}" "${abspath[2]}" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[2]}" \
          'Failed to create backup'
        return 1
      }
    fi

  fi

  # ======= #
  # Linking #
  # ======= #

  ## Remove pre-existing directory at symlink path, to avoid ln's special 
  #. treatment of directories
  if [ -d "${abspath[1]}" -a $force = true ]; then

    if $dry_run; then
      printf '%s\n' "rm -rf -- \"${abspath[1]}\""
    else
      rm -rf -- "${abspath[1]}" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[1]}" \
          'Failed to overwrite at symlink path'
        return 1
      }
    fi

  fi

  # Symlinking
  if $dry_run; then
    printf '%s\n' "ln -sF -- \"${abspath[0]}\" \"${abspath[1]}\""
  else
    ln -sF -- "${abspath[0]}" "${abspath[1]}" &>/dev/null || {
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[1]}" \
        'Failed to create symlink'
      return 1
    }
  fi

  # All done
  return 0
}