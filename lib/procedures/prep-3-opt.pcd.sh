#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-3-opt
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Remove revision numbers from all src files
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Offers to install optional system utilities if they are not available and if 
#. at all possible
#

#>  d__run_sys_pkg_checks
#
## Driver function
#
## Returns:
#.  0 - Framework is ready to run
#.  1 - (script exit) Otherwise
#
d__run_sys_pkg_checks()
{
  # Fork depending on routine
  case $D__REQ_ROUTINE in
    attach|plug|update)
      d__offer_git_and_friends; unset -f d__offer_git_and_friends;;
    cecf357ed9fed1037eb906633a4299ba)
      d__uninstall_all_offered_utils;;
    *)  return 0;;
  esac
}

#>  d__check_github
#
## Checks whether the framework has the capacity to interact with Github (clone 
#. or download the repositories)
#
d__check_github()
{
  D__GH_METHOD=
  if git --version &>/dev/null; then D__GH_METHOD=g
  elif tar --version &>/dev/null; then
    if curl --version &>/dev/null; then D__GH_METHOD=c
    elif wget --version &>/dev/null; then D__GH_METHOD=w; fi
  fi
  readonly D__GH_METHOD
  if [ -z "$D__GH_METHOD" ]; then
    d__notify -lx -- 'Unable to clone/download Github repositories'
  fi
}

#>  d__offer_git_and_friends
#
## Offers various tools for working with git repositories
#
d__offer_git_and_friends()
{
  # Try to sell git as an essential tool for working with this framework
  if ! git --version &>/dev/null; then
    
    # Print warning
    dprint_alert 'Failed to detect git on current system' \
      -n 'Having git installed remedies a lot of unnecessary pain'

    # Make an offer
    if ! d__offer_system_pkg --exit-on-q git; then

      # Make announcement
      dprint_alert 'Proceeding without git'

      # Make checks and store statuses
      local curl_available wget_available tar_available
      curl --version &>/dev/null && curl_available=true || curl_available=false
      wget --version &>/dev/null && wget_available=true || wget_available=false
      tar --version &>/dev/null  && tar_available=true  || tar_available=false

      # Git is not available: check if alternative set of tools is available
      if ! ( ( $curl_available || $wget_available ) && $tar_available ); then

        # Alternative workflow is NOT available: attempt to make it so

        # Print warning
        dprint_alert 'Attempting to provide an alternative approach' \
          'to Github repositories'

        # Status variable with desired value
        local alt_flow_available=true

        # Check if both download tools are unavailable or just one
        if ! ( $curl_available || $wget_available ); then
          
          # No download tools: at least one is required
          d__offer_system_pkg --exit-on-q curl \
            || d__offer_system_pkg --exit-on-q wget \
            || alt_flow_available=false
        
        fi

        # If still hoping for alt workflow, check on tar
        if $alt_flow_available && ! $tar_available; then

          # No tar: it is required
          d__offer_system_pkg --exit-on-q tar || alt_flow_available=false

        fi

        # Check if made alt workflow available
        if ! $alt_flow_available; then

          # Verdict depends on routing
          case $D__REQ_ROUTINE in
            attach)
              # Fatal: no way to attach deployments without Github access
              dprint_failure \
                'Unable to attach deployments without tools for Github access'
              exit 1
              ;;
            plug)
              # Not fatal: there are other ways for Grail to be plugged
              dprint_alert 'Proceeding without tools for Github access'
              return 0
              ;;
            update)
              # Fatal: updates require some form of git access 
              dprint_failure \
                'Unable to update anything without git or alternative tools'
              exit 1
              ;;
          esac

        fi

      fi

    fi

  fi
}

#>  d__uninstall_all_offered_utils
#
## Removes previously offered and subsequently installed utils
#
d__uninstall_all_offered_utils()
{
  # Storage variable
  local installed_utils=() installed_util

  # Check if there are any utilities recorded
  if d__stash -r -s has installed_util; then

    # Check if $D__OS_PKGMGR is detected
    if [ -z "$D__OS_PKGMGR" ]; then

      # No option to uninstall: report and exit
      dprint_failure \
        "Unable to uninstall system utilities (no supported package manager)"
      exit 1

    fi

    # Read list from stash
    while read -r installed_util; do
      installed_utils+=( "$installed_util" )
    done < <( d__stash -r -s list installed_util )

  fi

  # Status variable
  local all_good=true anything_uninstalled=false

  # Remove Homebrew if installed
  d__uninstall_homebrew && anything_uninstalled=true || all_good=false

  # Iterate over installed utils
  for installed_util in "${installed_utils[@]}"; do

    # Announce un-installation
    dprint_debug "Uninstalling $installed_util"

    # Launch OS package manager with verbosity in mind
    if $D__OPT_QUIET; then

      # Launch quietly
      d__os_pkgmgr remove "$installed_util" &>/dev/null

    else

      # Launch normally, but re-paint output
      local line
      d__os_pkgmgr remove "$installed_util" 2>&1 \
        | while IFS= read -r line || [ -n "$line" ]; do
        printf "${CYAN}==> %s${NORMAL}\n" "$line"
      done

    fi

    # Check return status
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then

      # Announce success and unset stash variable
      dprint_success "Successfully uninstalled $installed_util"
      d__stash -r -s unset installed_util "$installed_util"
      anything_uninstalled=true

    else

      # Announce and remember failure
      dprint_failure "Failed to uninstall $installed_util"
      all_good=false
      
    fi

  # Done iterating over installed utils
  done

  # Exit with appropriate status
  if $all_good; then
    exit 0
  else
    $anything_uninstalled && exit 1 || exit 2
  fi
}

#>  d__uninstall_homebrew
#
## Removes previously offered and subsequently installed Homebrew
#
d__uninstall_homebrew()
{
  # Check if there is any work to do
  if ! d__stash -r -s has installed_homebrew; then
    # No record of Homebrew installation: silently return a-ok
    return 0
  fi

  # Announce start
  dprint_debug 'Uninstalling Homebrew'

  ## Homebrew has been previously auto-installed. This could only have 
  #. happened on macOS, so assume macOS environment.

  # Make temp dir for the uninstall script
  local tmpdir=$( mktemp -d )

  # Status variable
  local all_good=false

  # Download script into that directory
  if curl -fsSLo "$tmpdir/uninstall" \
    https://raw.githubusercontent.com/Homebrew/install/master/uninstall
  then

    # Make script executable
    if chmod +x "$tmpdir/uninstall"; then

      # Execute script with verbosity in mind
      if $D__OPT_QUIET; then

        # Run script quietly
        $tmpdir/uninstall --force &>/dev/null

      else

        # Run script normally, but re-paint output
        local line
        $tmpdir/uninstall --force 2>&1 \
          | while IFS= read -r line || [ -n "$line" ]; do
            printf "${CYAN}==> %s${NORMAL}\n" "$line"
          done

      fi

      # Report status
      if [ "${PIPESTATUS[0]}" -eq 0 ]; then

        # Announce, erase stash record, and save status
        dprint_success 'Successfully uninstalled Homebrew'
        d__stash -r -s unset installed_homebrew
        all_good=true

      else

        # Announce failure
        dprint_failure 'Failed to uninstall Homebrew'

      fi

    else

      # Announce failure
      dprint_failure \
        'Failed to set executable flag on Homebrew uninstallation script'

    fi

  else

    # Announce failure
    dprint_failure 'Failed to download Homebrew uninstallation script'

  fi

  # Remove temp dir
  rm -rf -- "$tmpdir"

  # Return appropriately
  $all_good && return 0 || return 1
}

d__run_sys_pkg_checks
d__check_github
unset -f d__run_sys_pkg_checks
unset -f d__check_github