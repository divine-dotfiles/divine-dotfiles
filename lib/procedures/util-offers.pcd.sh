#!/usr/bin/env bash
#:title:        Divine Bash procedure: util-offers
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.07.05
#:revremark:    Initial revision
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework’s main script
#
## Offers to install optional system utilities if they are not available and if 
#. at all possible
#

#>  __run_util_offers
#
## Driver function
#
## Returns:
#.  0 - Framework is ready to run
#.  1 - (script exit) Otherwise
#
__run_util_offers()
{
  # Fork depending on routine
  case $D_REQ_ROUTINE in
    attach) __offer_git_and_friends; unset -f __offer_git_and_friends;;
    plug)   __offer_git_and_friends; unset -f __offer_git_and_friends;;
    update) __offer_git_and_friends; unset -f __offer_git_and_friends;;
    cecf357ed9fed1037eb906633a4299ba)
            __remove_all_offered_utils;;
    *)  return 0;;
  esac
}

#>  __offer_git_and_friends
#
## Offers various tools for working with git repositories
#
__offer_git_and_friends()
{
  # Try to sell git as an essential tool for working with this framework
  if ! git --version &>/dev/null; then
    
    # Print warning
    dprint_start -l 'Failed to detect git on current system' \
      -n 'Having git installed remedies a lot of unnecessary pain'

    # Make an offer
    if ! __offer_util --exit-on-q git; then

      # Make announcement
      dprint_start -l 'Proceeding without git'

      # Make checks and store statuses
      local curl_available wget_available tar_available
      curl --version &>/dev/null && curl_available=true || curl_available=false
      wget --version &>/dev/null && wget_available=true || wget_available=false
      tar --version &>/dev/null  && tar_available=true  || tar_available=false

      # Git is not available: check if alternative set of tools is available
      if ! ( ( $curl_available || $wget_available ) && $tar_available ); then

        # Alternative workflow is NOT available: attempt to make it so

        # Print warning
        dprint_start -l 'Attempting to provide an alternative approach' \
          'to Github repositories'

        # Status variable with desired value
        local alt_flow_available=true

        # Check if both download tools are unavailable or just one
        if ! ( $curl_available || $wget_available ); then
          
          # No download tools: at least one is required
          __offer_util --exit-on-q curl \
            || __offer_util --exit-on-q wget \
            || alt_flow_available=false
        
        fi

        # If still hoping for alt workflow, check on tar
        if $alt_flow_available && ! $tar_available; then

          # No tar: it is required
          __offer_util --exit-on-q tar || alt_flow_available=false

        fi

        # Check if made alt workflow available
        if ! $alt_flow_available; then

          # Verdict depends on routing
          case $D_REQ_ROUTINE in
            attach)
              # Fatal: no way to attach deployments without Github access
              dprint_failure -l \
                'Unable to attach deployments without tools for Github access'
              exit 1
              ;;
            plug)
              # Not fatal: there are other ways for Grail to be plugged
              dprint_start -l 'Proceeding without tools for Github access'
              return 0
              ;;
            update)
              # Fatal: updates require some form of git access 
              dprint_failure -l \
                'Unable to update anything without git or alternative tools'
              exit 1
              ;;
          esac

        fi

      fi

    fi

  fi
}

#>  __remove_all_offered_utils
#
## Removes previously offered and subsequently installed utils
#
__remove_all_offered_utils()
{
  # Check if there are any utilities recorded
  if ! dstash -r -s has installed_util; then
    # Exit successfully
    exit 0
  fi

  # Check if $OS_PKGMGR is detected
  if [ -z ${OS_PKGMGR+isset} ]; then

    # No option to uninstall: report and exit
    dprint_failure -l \
      "Unable to un-install utilities (no supported package manager)"
    exit 1

  fi

  # Storage variable
  local installed_utils=() installed_util

  # Read list from stash
  while read -r installed_util; do
    installed_utils+=( "$installed_util" )
  done < <( dstash -r -s list installed_util )

  # Status variable
  local all_good=true

  # Iterate over installed utils
  for installed_util in "${installed_utils[@]}"; do

    # Prompt user for whether to un-install utility
    dprompt_key --bare --or-quit --answer "$D_OPT_ANSWER" \
      --prompt "Un-install $installed_util using $OS_PKGMGR?"

    # Check status
    case $? in
      0)  # Agreed to un-install

          # Announce un-installation
          dprint_start -l "Un-installing $installed_util"

          # Attempt un-installation
          if os_pkgmgr dremove "$installed_util"; then

            # Announce
            dprint_success -l "Successfully un-installed $installed_util"

          else

            # Announce and remember failure
            dprint_failure -l "Failed to un-install $installed_util"
            all_good=false
            
          fi

          # Done with un-installation
          ;;

      1)  # Refused to un-install

          # Announce refusal to un-install and return
          dprint_skip -l "Refused to un-install $installed_util"
          return 1

          # Done with refusal
          ;;
      
      *)  # Refused to proceed at all

          # Announce exiting and exit
          dprint_failure -l \
            "Refused to un-install $installed_util or proceed without doing so"
          exit 1

          # Done with exiting
          ;;
    esac

  # Done iterating over installed utils
  done

  # Exit with appropriate status
  $all_good && exit 0 || exit 1
}

__run_util_offers
unset -f __run_util_offers