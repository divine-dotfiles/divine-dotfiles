#!/usr/bin/env bash
#:title:        Divine Bash procedure: pre-flight
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.05
#:revremark:    Tweak newlines in pre-flight
#:created_at:   2019.10.11

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Fundamental checks and fixes.
#

# Marker and dependencies
readonly D__PCD_PRE_FLIGHT=loaded

#>  d__pcd_pre_flight
#
## Checks major version of Bash; applies fixes as necessary; halts the script 
#. if something smells fishy.
#
## Returns:
#.  0 - All systems green.
#.  1 - (script exit) Unable to work in the current environment.
#
d__pcd_pre_flight()
{
  # Set sane umask
  umask g-w,o-w

  # Retrieve and inspect major Bash version
  case ${BASH_VERSION:0:1} in
    3|4)
      # Prevent 'write error: Interrupted system call'
      trap '' SIGWINCH
      ;;
    5|6)
      # This is fine
      :
      ;;
    *)
      # Other Bash versions are not supported (yet?)
      printf >&2 "Divine.dotfiles: Unsupported version of Bash: '%s'\n" \
        "${BASH_VERSION}"
      exit 1
      ;;
  esac

  # Check if /dev/fd exists
  if ! [ -e /dev/fd ]; then
    printf >&2 'Divine.dotfiles: Missing directory: /dev/fd\n\n'
    cat >&2 <<EOF
This is likely a conscious restriction by maintainers of the current system. 
Divine.dotfiles relies on /dev/fd for its operations and thus cannot run.
EOF
    exit 1
  fi

  # Return zero if gotten to here
  return 0
}

d__pcd_pre_flight