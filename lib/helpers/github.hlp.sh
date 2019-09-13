#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: github
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1
#:revdate:      2019.09.13
#:revremark:    Break Github fetcher into util and helper
#:created_at:   2019.09.13

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions that clone or download Github repositories into target 
#. directories.
#

#>  d__gh_clone_check SRC DEST [NAME]
#
## Implemented check primary that detects whether the Github repository at SRC 
#. appears to be cloned/downloaded into the DEST, and how does that correspond 
#. to current records in stash.
#
## Returns:
#.  0 - Force + record (clone) + not proper clone (with extra prompt).
#.      Force + record (download) + not dir/empty dir (with extra prompt).
#.  1 - Record (clone) + proper clone.
#.      Record (download) + exist but not proper clone (with extra prompt).
#.      No record + proper clone (by user or OS).
#.  2 - No record + not proper clone.
#.  3 - Deployment stash not available.
#.      Record (clone) + not clone.
#.      Record (download) + not dir/empty dir.
#
d__gh_clone_check()
{
  # Rely on stashing
  dstash ready || return 3

  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift
  local name="$1"; shift

  # Compose stashing data
  local stash_key="gh_$( dmd5 -s "${user_repo}___${perm_dest}" )"
  local stash_val="$perm_dest"
  local backup_path="$D__DPL_BACKUP_DIR/$stash_key"

  # Check if stash has a record
  if dstash -s has "$stash_key"; then

    ## Stash record exists and almost certainly with the right value (chance of 
    #. md5 checksum collision is negligible)
    #

    # Check if repo has been recorded as cloned or downloaded
    if [ "$( dstash -s get "status_$stash_key" )" = 'cloned' ]; then

      # Check if a cloned repository resides at the given path
      if d___check_if_dest_is_proper_clone; then

        # Recorded as clone, and destination is a proper clone: installed
        return 1

      else

        # Recorded as clone, but destination is not a proper clone

        # Print output based on current state of destination
        local alert_report=()
        if [ -n "$name" ]; then
          alert_report+=( \
            "Despite record of installing $name" \
            -n "by cloning Github repository $user_repo" \
          )
        else
          alert_report+=( \
            "Despite record of cloning Github repository $user_repo" \
          )
        fi
        alert_report+=( -n "into: $perm_dest" )
        if [ -d "$perm_dest" ]; then
          alert_report+=( -n 'that directory is currently not the clone' )
        else
          alert_report+=( -n 'that path is currently not a directory' )
        fi
        dprint_alert "${alert_report[@]}"

      fi

    else

      # Repository is recorded as downloaded

      # Check if destination is a non-empty dir
      if [ -d "$perm_dest" ]; then

        if [ -n "$( ls -A -- "$perm_dest" 2>/dev/null )" ]; then

          # Recorded as downloaded, but there is no way to tell
          local alert_report=()
          if [ -n "$name" ]; then
            alert_report+=( "$name from Github repository $user_repo" \
              -n 'is recorded as downloaded into:' -i "$perm_dest" )
          else
            alert_report+=( \
              "Github repository $user_repo is recorded as downloaded" \
              -n "into: $perm_dest" \
            )
          fi
          alert_report+=( -n 'but it is hard to confirm it' )
          dprint_alert "${alert_report[@]}"
          D_DPL_NEEDS_ANOTHER_PROMPT=true
          return 1

        else

          # Recorded as downloaded, but directory is empty
          local alert_report=()
          if [ -n "$name" ]; then
            alert_report+=( \
              "Despite record of installing $name" \
              -n "by downloading Github repository $user_repo" \
            )
          else
            alert_report+=( \
              "Despite record of downloading Github repository $user_repo" \
            )
          fi
          alert_report+=( -n "into: $perm_dest" \
            -n 'that directory is currently empty' )
          dprint_alert "${alert_report[@]}"

        fi

      else

        # Recorded as downloaded, but not a directory
        local alert_report=()
        if [ -n "$name" ]; then
          alert_report+=( \
            "Despite record of installing $name" \
            -n "by downloading Github repository $user_repo" \
          )
        else
          alert_report+=( \
            "Despite record of downloading Github repository $user_repo" \
          )
        fi
        alert_report+=( -n "into: $perm_dest" \
          -n 'that path is currently not a directory' )
        dprint_alert "${alert_report[@]}"

      fi

    fi

    # At this point, something is not right

    # Check if forcing
    if $D__OPT_FORCE; then

      # In force mode, allow this with another prompt
      D_DPL_NEEDS_ANOTHER_PROMPT=true
      return 0

    else

      # In normal mode, inform of force option and mark irrelevant
      case $D__REQ_ROUTINE in
        check)    return 0;;
        install)  dprint_alert 'Retry with --force option to install anyway';;
        remove)   dprint_alert 'Retry with --force option to remove anyway';;
      esac
      return 3

    fi

  else

    # No stash record

    # Check if a cloned repository resides at the given path
    if d___check_if_dest_is_proper_clone; then

      # No record, but destination is a proper clone: installed by user or OS
      local alert_report=()
      if [ -n "$name" ]; then
        alert_report+=( \
          "No record of installing $name" \
          -n "by cloning Github repository $user_repo" \
        )
      else
        alert_report+=( \
          "No record of cloning Github repository $user_repo" \
        )
      fi
      alert_report+=( -n "into: $perm_dest" \
        -n 'but the directory is nevertheless a clone of that repository' )
      dprint_debug "${alert_report[@]}"
      D_DPL_INSTALLED_BY_USER_OR_OS=true
      return 1

    else

      # No record, and destination is not a proper clone

      # Print output based on current state of destination
      if [ -e "$perm_dest" ]; then
        local alert_report=()
        if [ -n "$name" ]; then
          alert_report+=( \
            "Installing $name by cloning Github repository $user_repo" \
          )
        else
          alert_report+=( "Cloning Github repository $user_repo" )
        fi
        alert_report+=( -n "into: $perm_dest" )
        if [ -d "$perm_dest"]; then
          alert_report+=( \
            -n 'will overwrite the existing directory (it will be backed up)' \
          )
        else
          alert_report+=( \
            -n 'will overwrite the existing file (it will be backed up)' \
          )
        fi
        dprint_debug "${alert_report[@]}"

      fi

      D_DPL_NEEDS_ANOTHER_PROMPT=true
      return 2

    fi

  fi
}

#>  d__gh_clone_install SRC DEST [NAME]
#
## Implemented install primary that entirely delegates to the helper
#
d__gh_clone_install()
{
  # Extract user_repo, destination, and optional name
  local user_repo="$1"; shift
  local perm_dest="$1"; shift
  local name="$1"; shift

  # Check if the deployment is already installed by this framework
  if [ "$D__DPL_CHECK_CODE" = 1 -a "$D_DPL_INSTALLED_BY_USER_OR_OS" != true ]
  then

    # Forced re-installation: just pull updates from remote
    d__ensure_gh_repo --pull-only --name "$name" -- "$user_repo" "$perm_dest"

  else

    ## In all other cases: be that a clean installation; or a forced 
    #. re-installation over something done by user or OS - the only requirement 
    #. is to not accidentally pull from remote, polluting pre-existing files.
    #
    d__ensure_gh_repo --no-pull --name "$name" -- "$user_repo" "$perm_dest"

  fi
}

#>  d__gh_clone_remove SRC DEST [NAME]
#
## Implemented remove primary that tries to do as little damage as possible, 
#. while still getting the job done
#
d__gh_clone_remove()
{
  # Extract user_repo and destination
  local user_repo="$1"; shift
  local perm_dest="$1"; shift
  local name="$1"; shift

  # Compose stashing data
  local stash_key="gh_$( dmd5 -s "${user_repo}___${perm_dest}" )"
  local stash_val="$perm_dest"
  local backup_path="$D__DPL_BACKUP_DIR/$stash_key"

  # Inspect return code of check routine
  case $D__DPL_CHECK_CODE in
    1)  # Installed

        # Check if installed by user or OS
        if [ "$D_DPL_INSTALLED_BY_USER_OR_OS" = true ]; then

          # Installed by user or OS: 
          d__ensure_gh_repo --no-pull --name "$name" -- \
            "$user_repo" "$perm_dest"

        else

          # Installed by this framework: remove it and restore backup, if any
          d___erase_destination || return 1

          # Restore backup
          d___restore_backup
          
          # Return success
          return 0

        fi
        ;;
    2)  ## Not installed; no record of installation; dest is not a clone. Even 
        #. in forced removal, this is a no-go.
        #
        dprint_alert 'Not touching local directory at:' -i "$perm_dest" \
          -n "as it is unlikely to be the copy of the Github repository $user_repo"
        return 0
        ;;
    *)  ## Unknown: this is a forced healing of whatever damage is done. Since 
        #. the user wants a forced installation, install without pulling, 
        #. possibly clobbering existing backup
        #
        d__ensure_gh_repo --no-pull --name "$name" -- "$user_repo" "$perm_dest"
        ;;
  esac
}

#>  d___erase_destination
#
## INTERNAL USE ONLY
#
## IN:
#.  > $user_repo
#.  > $perm_dest
#.  > $name
#
## OUT:
#.  < 0/1
#
d___erase_destination()
{
  # Erase destination
  if rm -rf -- "$perm_dest" &>/dev/null; then

    # Fire debug message
    if [ -n "$name" ]; then
      dprint_debug \
        "Erased local copy of $name from Github repository $user_repo at:" \
        -i "$perm_dest"
    else
      dprint_debug "Erased local copy of Github repository $user_repo at:" \
        -i "$perm_dest"
    fi

  else

    # Failed to remove pre-existing file: assemble failure report
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Failed to erase local copy of $name" \
        -n "from Github repository $user_repo at:" )
    else
      failure_report+=( \
        "Failed to erase local copy of Github repository $user_repo at:" )
    fi
    failure_report+=( -i "$perm_dest" )

    # Report and return failure
    dprint_failure "${failure_report[@]}"
    return 1

  fi
}

#>  d___restore_backup
#
## INTERNAL USE ONLY
#
## IN:
#.  > $user_repo
#.  > $perm_dest
#.  > $name
#.  > $backup_path
#
## OUT:
#.  < 0/1
#
d___restore_backup()
{
  # Check if backup exists
  [ -e "$backup_path" ] || return 0

  # Move backup path back to original location
  if mv -n -- "$backup_path" "$perm_dest" &>/dev/null; then

    # Fire debug message
    dprint_debug 'Moved backup from:' -i "$perm_dest" \
      -n 'to original location at:' -i "$backup_path"

  else

    # Failed to back up: assemble failure report
    local failure_report=()
    if [ -n "$name" ]; then
      failure_report+=( "Failed to overwrite $name at:" )
    else
      failure_report+=( 'Failed to overwrite at:' )
    fi
    failure_report+=( \
      -i "$perm_dest" \
      -n 'due to failure to back it up to:' \
      -i "$backup_path" \
    )

    # Attempt to remove temp dir; report and return failure
    rm -rf -- "$temp_dest"
    dprint_failure "${failure_report[@]}"
    return 1

  fi
}