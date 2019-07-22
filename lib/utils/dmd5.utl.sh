#!/usr/bin/env bash
#:title:        Divine Bash utils: dmd5
#:kind:         func(script,interavtive)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    4
#:revdate:      2019.07.22
#:revremark:    New revisioning system
#:created_at:   2019.05.21

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

#>  dmd5 [-s STRING] | [PATH]
#
## Calculates and prints md5 checksum of either:
#.  * a string following `-s` switch
#.  * a file path to which is provided in first argument
#
## Extra arguments are ignored
#
## Options:
#.  -s  - (must be first argument) Calculate checksum of string given in next 
#.        argument, instead of file
#
## Parameters:
#.  $1  - Path to file or text string. Interpretation depends on presence of 
#.        `-s` option)
#
## Requires:
#.  `md5sum` or `md5` or `openssl` — whichever is available on the $PATH
#
## Returns:
#.  0 - md5 successfully calculated and printed
#
## Prints:
#.  stdout  - md5 checksum of given parameter
#.  stderr  - Error descriptions
#
dmd5()
{
  # Storage variable
  local md5

  # Detect md5-calculating command
  if md5sum --version &>/dev/null; then

    # Fork depending on first argument
    if [ "$1" = -s ]; then

      # Shift option away
      shift

      # Calculate md5 for input string
      md5="$( printf '%s' "$1" | md5sum 2>/dev/null | awk '{print $1}' )"

    else

      # Check if there is a readable file at given path
      [ -f "$1" -a -r "$1" ] || {
        printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" 'Not a readable file' "$1"
        return 1
      }

      # Calculate md5 for file at given path
      md5="$( md5sum -- "$1" 2>/dev/null | awk '{print $1}' )"

    fi

  elif md5 -r <<<test &>/dev/null; then

    # Fork depending on first argument
    if [ "$1" = -s ]; then

      # Shift option away
      shift

      # Calculate md5 for input string
      md5="$( printf '%s' "$1" | md5 -r 2>/dev/null | awk '{print $1}' )"

    else

      # Check if there is a readable file at given path
      [ -f "$1" -a -r "$1" ] || {
        printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" 'Not a readable file' "$1"
        return 1
      }

      # Calculate md5 for file at given path
      md5="$( md5 -r -- "$1" 2>/dev/null | awk '{print $1}' )"

    fi

  elif openssl version &>/dev/null; then

    # Fork depending on first argument
    if [ "$1" = -s ]; then

      # Shift option away
      shift

      # Calculate md5 for input string
      md5="$( printf '%s' "$1" | openssl md5 2>/dev/null | awk '{print $1}' )"

    else

      # Check if there is a readable file at given path
      [ -f "$1" -a -r "$1" ] || {
        printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" 'Not a readable file' "$1"
        return 1
      }

      # Calculate md5 for file at given path
      md5="$( openssl md5 -- "$1" 2>/dev/null | awk '{print $1}' )"

    fi

  else

    # Announce error and return
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      'No means of calculating md5 checksums are detected'
    return 1

  fi

  # Check if calculated valid md5 checksum
  if [ ${#md5} -eq 32 ]; then
    printf '%s\n' "$md5"
    return 0
  else
    printf >&2 '%s: %s\n' "${FUNCNAME[0]}" \
      'Failed to calculate valid md5 checksum'
    return 1
  fi
}