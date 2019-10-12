#!/usr/bin/env bash
#:title:        Divine Bash procedure: pre-flight
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.10.11

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Fundamental checks and fixes.
#

#>  d__pre_flight_checks
#
## Checks major version of Bash; applies fixes as necessary; halts the script 
#. if something smells fishy.
#
## Returns:
#.  0 - All systems green.
#.  1 - (script exit) Unable to work in the current environment.
#
d__pre_flight_checks()
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
      printf >&2 "Unsupported version of Bash: '%s'\n\n" "${BASH_VERSION}"
      exit 1
      ;;
  esac
  
  # Return zero if gotten to here
  return 0
}

d__pre_flight_checks