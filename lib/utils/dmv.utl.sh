#!/usr/bin/env bash
#:title:        Divine Bash utils: dmv
#:kind:         func(script,interavtive)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    7
#:revdate:      2019.09.01
#:revremark:    Tweak bolding in miscellaneous locations
#:created_at:   2018.03.15

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

## dmv - divine move
#
#>  dmv [-f?rdqv]... [--help|version] [--] SRC_PATH TGT_PATH [BACKUP_PATH]
#
## Pushes SRC_PATH over to TGT_PATH, leaving forwarding symlink instead, and 
#. optionally stashing whatever currently occupies TGT_PATH at BACKUP_PATH
#
## Resolves paths from current working directory: first to absolute without 
#. touching symlinks, then to canonical. Uses absolute tgt path as symlink 
#. target. Requires src path to exist.
#
## Does not clobber anything without -f option. With it, still guards against 
#. clobbering at src path. Creates parent directories as necessary. Refuses to 
#. create cyclic symlinks. Treats directories same as regular files.
#
## Options:
#.  -f, --force   - Enforce clobbering at tgt or backup paths
#.  -?, --is-restorable
#.                - (overrides previous -r) Ask mode.
#.                  Two arguments: returns 0 if src path looks like it has been 
#.                  created by this function in regular mode; else 1.
#.                  Three arguments: to return 0, also requires BACKUP_PATH to 
#.                  exist.
#.  -r, --restore - (overrides previous -?) Restore mode. Works only when -? 
#.                  option would have returned 0.
#.                  Two arguments: removes src path, moves tgt path back to src 
#.                  path.
#.                  Three arguments: also moves backup path to tgt path.
#.  -d, --dry-run - Print principal commands instead of executing them
#.  -q, --quiet   - Suppress most error messages
#.  -v, --verbose - (default) Report error messages
#.  --help        - Display help summary
#.  --version     - Display version information
#.  --ping        - Return 0 without doing anything
#
## Parameters:
#.  $1  - Path to where source file is located
#.  $2  - Path to where that file is to be moved, creating a forwarding symlink
#.  $3  - (optional) Path for moving existing tgt path to
#
## Returns:
#.  0   - Src path has been moved; forwarding symlink has been created
#.  1   - Otherwise
#.  100 - (without '-f') Tgt or backup path is occupied by a file
#.  101 - (without '-f') Tgt or backup path is occupied by a directory
#.  102 - (without '-f') Tgt or backup path is occupied by a symlink
#
## Returns (with '-?'):
#.  0 - Src path is a symlink pointing to resolvable absolute tgt path. Also, 
#.      backup path (if provided) exists.
#.  1 - Otherwise.
#
## Returns (with '-r'):
#.  0 - Conditions for '-?' are met. Symlink at src path has been removed; tgt 
#.      path has been moved back to src path; and backup path (if provided) has 
#.      been moved back to symlink path.
#.  1 - Otherwise.
#
## Prints:
#.  stdout: *nothing*
#.          (with '-?') (without '-q') Human readable answer
#.  stderr: (default) Error descriptions
#.          (with '-q') As little as possible
#
dmv()
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
${bold}dmv${normal} 3.0.0
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
    ${bold}dmv${normal} - divine link

SYNOPSIS
    ${bold}dmv${normal} [-f?rdqv]... [--help|version] [--] SRC_PATH TGT_PATH [BACKUP_PATH]

DESCRIPTION
    Pushes SRC_PATH over to TGT_PATH, leaving forwarding symlink instead, and 
    optionally stashing whatever currently occupies TGT_PATH at BACKUP_PATH
    
    Resolves paths from current working directory: first to absolute without 
    touching symlinks, then to canonical. Uses absolute tgt path as symlink 
    target. Requires src path to exist.
    
    Does not clobber anything without -f option. With it, still guards against 
    clobbering at src path. Creates parent directories as necessary. Refuses to 
    create cyclic symlinks. Treats directories same as regular files.

OPTIONS
    -f, --force     Enforce clobbering at tgt or backup paths
    -?, --is-restorable
                    (overrides previous -r) Ask mode.
                    Two arguments: returns 0 if src path looks like it has been 
                    created by this function in regular mode; else 1.
                    Three arguments: to return 0, also requires BACKUP_PATH to 
                    exist.
    -r, --restore   (overrides previous -?) Restore mode. Works only when -? 
                    option would have returned 0.
                    Two arguments: removes src path, moves tgt path back to src 
                    path.
                    Three arguments: also moves backup path to tgt path.
    -d, --dry-run - Print principal commands instead of executing them
    -q, --quiet   - Suppress most error messages
    -v, --verbose - (default) Report error messages
    --help        - Display help summary
    --version     - Display version information
    --ping        - Return 0 without doing anything

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
      '[-f?rdqv]... SRC_PATH TGT_PATH [BACKUP_PATH]'
    printf >&2 "Try '%s --help' for more information\n" \
      "${FUNCNAME[0]}"
    return 1
  }

  # Storage variables
  local abspath=() canonpath=() parentpath=()
  local backing_up=true
  local exist_part nonexist_part status temppath
  local clobber_argpath clobber_abspath clobber_canonicalpath
  local tgt_parentpath backup_parentpath

  # ================= #
  # Process arguments #
  # ================= #

  # Take three arguments: 0=SRC, 1=TGT, 2=BACKUP
  local type
  # Iterating over three arguments
  for type in 0 1 2; do

    # Is argument an empty string?
    [ -z "${args[$type]}" ] && {

      # For src and tgt paths this is a no-go
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

  # Check if user-provided src and tgt paths are identical when absolute
  if [ "${abspath[0]}" = "${abspath[1]}" ]; then
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "'${args[0]}' & '${args[1]}'" \
      'Same path'
    return 1
  fi

  ## Check if user-provided src and backup paths are identical when absolute.
  #. This is equivalent to switching src path and tgt path around. This is not 
  #. the intended usage.
  if [ "${abspath[0]}" = "${abspath[2]}" ]; then
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "'${args[0]}' & '${args[2]}'" \
      'Same path'
    return 1
  fi

  # Check if user-provided tgt and backup paths are identical when absolute
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

    # --------------------------- #
    # Src path checks (-? and -r) #
    # --------------------------- #

    # Basically, src path must be a symlink pointing precisely at tgt path

    # Check if src path exists
    if [ -e "${args[0]}" ]; then
      
      # Check if existing src path is a symlink (use absolute path)
      if [ -L "${abspath[0]}" ]; then

        # Check if src and tgt paths resolve to same path
        if [ "${canonpath[0]}" = "${canonpath[1]}" ]; then

          # Grab exact link target at symlink path
          temppath="$( readlink -- "${abspath[0]}" )"

          # Check if symlink at src path points precisely at tgt abspath
          if [ "$temppath" = "${abspath[1]}" ]; then

            # If in -? mode, print an answer
            [ "$mode" = '?' ] && {
              $quiet || printf "%s: %s\n" \
                "${FUNCNAME[0]}" \
                "'${abspath[0]}' is a symlink pointing to '${abspath[1]}'"
              # Also, if there is no third argument, return 0
              [ -z "${args[2]}" ] && {
                $quiet || printf "%s: %s\n" \
                  "${FUNCNAME[0]}" \
                  "Set-up appears restorable" 
                return 0
              }
            }
          
          else

            # Symlink at src path does NOT point precisely at tgt abspath
            $quiet || printf >&2 '%s: %s: %s\n' \
              "${FUNCNAME[0]}" \
              "${args[0]}" \
              'Wrong-ish symlink'
            return 1
          
          fi
        
        else

          # Src and tgt paths do NOT resolve to same path
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "${args[0]}" \
            'Wrong symlink'
          return 1

        fi
      
      else

        # Existing src path is NOT a a symlink
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[0]}" \
          'Not a symlink'
        return 1
      
      fi
    
    else

      # Src path does NOT exist
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[0]}" \
        'No such file or directory'
      return 1

    fi

    # --------------------------- #
    # Tgt path checks (-? and -r) #
    # --------------------------- #

    # Check if tgt path exists
    if [ ! -e "${args[1]}" ]; then
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

    # Remove symlink at src path
    if $dry_run; then
      printf '%s\n' "rm -f -- \"${abspath[0]}\""
    else
      rm -f -- "${abspath[0]}" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${abspath[0]}" \
          'Failed to remove symlink'
        return 1
      }
    fi

    # Restore tgt path to src path
    if $dry_run; then
      printf '%s\n' "mv -f -- \"${abspath[1]}\" \"${abspath[0]}\""
    else
      mv -f -- "${abspath[1]}" "${abspath[0]}" &>/dev/null || {
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${abspath[0]}" \
          'Failed to restore to original location'
        return 1
      }
    fi

    # Only perform this move if there are three arguments
    if $backing_up; then

      # Restore backup path to symlink path
      if $dry_run; then
        printf '%s\n' "mv -f -- \"${abspath[2]}\" \"${abspath[1]}\""
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

  # =============== #
  # Src path checks #
  # =============== #

  # Check if src path exists
  if [ ! -e "${args[0]}" ]; then

    # Real path does NOT exist
    $quiet || printf >&2 '%s: %s: %s\n' \
      "${FUNCNAME[0]}" \
      "${args[0]}" \
      'No such file or directory'
    return 1
  
  fi

  # Check if src path is a symlink
  if [ -L "${abspath[0]}" ]; then

    ## The monumental task here is to devise, whether the symlink will survive 
    #. being moved to tgt path, i.e., whether it will still resolve to the same 
    #. path

    # Grab exact link target at src path
    temppath="$( readlink -- "${abspath[0]}" )"

    # Check if link target is a relative path
    if [[ $exist_part != /* ]]; then

      # Check if tgt path is a root directory (no-go)
      if [ "${abspath[1]}" = '/' ]; then
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[1]}" \
          'Not touching that'
        return 1
      fi

      # Re-create target path as if after move
      # (Variable 'exist_part' is re-used without semantic meaning)
      exist_part="$( dirname -- "${abspath[1]}" )/${temppath%%/}"

      # Check if that path exists
      if [ ! -e "$exist_part" ]; then
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[0]}" \
          'Moving symlink would clobber it'
        return 1
      fi

      # Resolve this path to canonical
      # (Again, variable 'exist_part' is re-used without semantic meaning)
      if [ -d "$exist_part" ]; then

        # For directories, cd -P and capture pwd output
        exist_part="$( cd -P "$exist_part" &>/dev/null && pwd || exit $? )"
        status=$?

      else

        # For files, recursively resolve base symlink
        while [ -L "$exist_part" ]; do
          temppath="$( dirname -- "$exist_part" )"
          exist_part="$( readlink -- "$exist_part" )"
          [[ $exist_part != /* ]] && exist_part="$temppath/$exist_part"
        done

        # Then, cd -P into parent dir and capture pwd output
        temppath="$( cd -P "$( dirname -- "$exist_part" )" &>/dev/null \
          && pwd || exit $? )"
        status=$?

        # Put existing part back together
        exist_part="${temppath%/}/$( basename -- "$exist_part" )"

      fi

      # Check if canonical path after 'moving' is the same as original
      if [ "$exist_part" != "${canonpath[0]}" ]; then
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "${args[0]}" \
          'Moving symlink would clobber it'
        return 1
      fi

    fi

  fi

  # =============== #
  # Tgt path checks #
  # =============== #

  # Check if tgt path exists
  if [ -e "${args[1]}" ]; then
  
    # Tgt path is occupied. Will there be backup?
    $backing_up || {
      # Save paths that are to be clobbered for later checking
      clobber_argpath="${args[1]}"
      clobber_abspath="${abspath[1]}"
      clobber_canonicalpath="${canonpath[1]}" 
    }

  else

    # Tgt path does NOT exist

    # Meaning, there is nothing to back up
    backing_up=false
  
  fi

  # ===================== #
  # Src + tgt pair checks #
  # ===================== #

  # Check if src and tgt paths resolve to same path
  if [ "${canonpath[0]}" = "${canonpath[1]}" ]; then

    # In here, both src and tgt paths exist

    # Check if src path is a symlink (use absolute path)
    if [ -L "${abspath[0]}" ]; then

      # Check if tgt path is a symlink (use absolute path)
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

        # Tgt path is NOT a symlink

        # This would create a cyclic symlink
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "'${args[0]}' & '${args[1]}'" \
          'Would create cyclic symlink'
        return 1

      fi

    else

      # Src path is NOT a symlink

      # Check if tgt path is a symlink (use absolute path)
      if [ -L "${abspath[1]}" ]; then

        ## Tgt path is a symlink pointing back at src path. This is fine and 
        #. restorable.
        :

      else

        # Symlink path is NOT a symlink

        # This is moving onto itself
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

  # ======================== #
  # Tgt + backup pair checks #
  # ======================== #

  # Only perform these checks if backing up at all
  if $backing_up; then

    # Check if tgt and backup paths resolve to same path
    if [ "${canonpath[1]}" = "${canonpath[2]}" ]; then

      # In here, both tgt and backup paths exist

      # Check if tgt path is a symlink (use absolute path)
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

          ## Tgt path is a symlink pointing to regular file/dir at backup path. 
          #. Proceeding would destroy data instead of backing it up.
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

  # ======================== #
  # Src + backup pair checks #
  # ======================== #

  # Only perform these checks if backing up at all
  if $backing_up; then

    # Check if src and backup paths resolve to same path
    if [ "${canonpath[0]}" = "${canonpath[2]}" ]; then

      # In here, both src and backup paths exist

      # Check if src path is a symlink (use absolute path)
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

          ## Src path is a symlink pointing to regular file/dir at backup path. 
          #. Proceeding would essentially clobber src path.
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

          ## This is equivalent to switching src path and tgt path around. This 
          #. is not the intended usage.
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

  # Extract parent path of tgt path
  tgt_parentpath="$( dirname -- "${abspath[1]}" )"

  # Ensure tgt parent directory exists
  if [ ! -e "$tgt_parentpath" ]; then

    if $dry_run; then
      printf '%s\n' "mkdir -p -- \"$tgt_parentpath\""
    else
      mkdir -p -- "$tgt_parentpath" &>/dev/null || {
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

  # ====== #
  # Moving #
  # ====== #

  ## Remove pre-existing directory at tgt path, to avoid mv's special treatment 
  #. of directories
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

  # Moving
  if $dry_run; then
    printf '%s\n' "mv -f -- \"${abspath[0]}\" \"${abspath[1]}\""
  else
    mv -f -- "${abspath[0]}" "${abspath[1]}" &>/dev/null || {
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[1]}" \
        'Failed to move to that location'
      return 1
    }
  fi

  # Symlinking
  if $dry_run; then
    printf '%s\n' "ln -sF -- \"${abspath[1]}\" \"${abspath[0]}\""
  else
    ln -sF -- "${abspath[1]}" "${abspath[0]}" &>/dev/null || {
      $quiet || printf >&2 '%s: %s: %s\n' \
        "${FUNCNAME[0]}" \
        "${args[0]}" \
        'Failed to create symlink'
      return 1
    }
  fi

  # All done
  return 0
}