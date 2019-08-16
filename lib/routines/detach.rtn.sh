#!/usr/bin/env bash
#:title:        Divine Bash routine: detach
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    12
#:revdate:      2019.08.16
#:revremark:    dprompt_key -> dprompt
#:created_at:   2019.06.28

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Detaches cloned deployment repositories by removing their directories and 
#. clearing their installation record
#

#>  d__perform_detach_routine
#
## Performs detach routine
#
## Returns:
#.  0 - Routine performed, all arguments detached successfully
#.  1 - Routine performed, only some arguments detached successfully
#.  2 - Routine performed, none of the arguments detached
#.  3 - Routine terminated with nothing to do
#
d__perform_detach_routine()
{
  # Synchronize dpl repos
  d__sync_dpl_repos || exit 1
  
  # Print empty line for visual separation
  printf >&2 '\n'

  # Announce beginning
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- "'Detaching' deployments"
  else
    dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
      -- 'Detaching deployments'
  fi

  # Storage & status variables
  local dpl_arg
  local detached_anything=false errors_encountered=false

  # Iterate over script arguments
  for dpl_arg in "${D__REQ_ARGS[@]}"; do

    # Print newline to visually separate attachments
    printf >&2 '\n'

    # Announce start
    dprint_ode "${D__ODE_NORMAL[@]}" -c "$YELLOW" -- \
      '>>>' 'Detaching' ':' "$dpl_arg"

    # Try to attach deployments
    if d__detach_dpl_repo "$dpl_arg"; then
      detached_anything=true
      dprint_ode "${D__ODE_NORMAL[@]}" -c "$GREEN" -- \
        'vvv' 'Detached' ':' "$dpl_arg"
    else
      errors_encountered=true
      dprint_ode "${D__ODE_NORMAL[@]}" -c "$RED" -- \
        'xxx' 'Failed to detach' ':' "$dpl_arg"
    fi

  done

  # Announce routine completion
  printf >&2 '\n'
  if [ "$D__OPT_ANSWER" = false ]; then
    dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
      -- "Finished 'detaching' deployments"
    return 3
  elif $detached_anything; then
    if $errors_encountered; then
      dprint_plaque -pcw "$YELLOW" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Successfully detached some deployments'
      return 1
    else
      dprint_plaque -pcw "$GREEN" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Successfully detached all deployments'
      return 0
    fi
  else
    if $errors_encountered; then
      dprint_plaque -pcw "$RED" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Failed to detach deployments'
      return 2
    else
      dprint_plaque -pcw "$WHITE" "$D__CONST_PLAQUE_WIDTH" \
        -- 'Nothing to do'
      return 3
    fi
  fi
}

#>  d__detach_dpl_repo
#
## Attempts to interpret single argument as name of Github repository and 
#. detach it. Accepts either full 'user/repo' form or short 'built_in_repo' 
#. form for deployments distributed by author of Divine.dotfiles.
#
## Returns:
#.  0 - Successfully detached deployment repository
#.  1 - Otherwise
#
d__detach_dpl_repo()
{
  # Extract argument
  local repo_arg="$1"

  # Storage variables
  local user_repo

  # Accept one of two patterns: 'builtin_repo_name' and 'username/repo'
  if [[ $repo_arg =~ ^[0-9A-Za-z_.-]+$ ]]; then
    user_repo="no-simpler/divine-dpls-$repo_arg"
  elif [[ $repo_arg =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then
    user_repo="$repo_arg"
  else
    # Other patterns are not checked against Github
    dprint_debug "Invalid Github repository handle: $repo_arg"
    return 1
  fi

  # Construct permanent destination
  local perm_dest="$D__DIR_DPL_REPOS/$user_repo"

  # Check if that path exists
  if [ -e "$perm_dest" ]; then

    # Check if it is a directory
    if [ -d "$perm_dest" ]; then

      # Prompt user
      if dprompt --bare --prompt 'Detach?' --answer "$D__OPT_ANSWER" -- \
        'About to remove attached deployments at:' \
        -i "$perm_dest" \
        '(Please, make sure deployments are removed from the system.)'
      then

        # Attempt to remove it
        if rm -rf -- "$perm_dest"; then

          dprint_debug 'Removed attached deployments at:' \
            -i "$perm_dest"

        else

          # Failed to remove: report and return error
          dprint_debug 'Failed to remove attached deployments at:' \
            -i "$perm_dest"
          return 1

        fi

      else

        # Refused to remove directory
        dprint_debug 'Refused to remove directory of cloned repository at:' \
          -i "$perm_dest"
        return 1

      fi

    else

      # Path exists, but is not a directory
      dprint_debug 'Path to cloned repository is not a directory:' \
        -i "$perm_dest"
      return 1

    fi

  else

    # Path does not exist
    dprint_debug 'Path to cloned repository does not exist:' -i "$perm_dest"

  fi

  # Repository erased, now remove record from Grail stash
  if d__stash -g -s unset dpl_repos "$user_repo"; then
    dprint_debug \
      "Cleared record of attached repository "$user_repo" in Grail stash"
  else
    dprint_debug \
      "Failed to clear record of attached repository '$user_repo'" \
      'in Grail stash' -n 'Update routine will fail to update this repository'
  fi

  # All done: announce and return
  dprint_debug 'Successfully detached Github-hosted deployments from:' \
    -i "https://github.com/${user_repo}" \
    -n 'at their location:' -i "$perm_dest"
  return 0
}

d__perform_detach_routine