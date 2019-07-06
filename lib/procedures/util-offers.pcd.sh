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
  # Run these checks only for routines that inherently use git
  case $D_REQ_ROUTINE in
    attach|plug|update)   :;;
    *)  return 0;;
  esac

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

__run_util_offers
unset -f __run_util_offers