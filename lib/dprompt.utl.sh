#!/usr/bin/env bash
#:title:        Divine Bash utils: dprompt
#:kind:         func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    2.0.0-RELEASE
#:revdate:      2019.03.22
#:revremark:    Lib ready for deployment
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

#>  dprompt [-n]… [--] QUESTION
#
## Requests user’s confirmation in a form of simple message and ‘y/n’ prompt. 
#. Accepts ‘y’ and ‘Y’ as yes, accepts ‘n’ and ‘N’ as no, disregards all other 
#. input. With a recognized answer, does not require RETURN. 
#
## Options:
#.  -n|--newline  - Move [y/n] prompt to the next line
#.  --ping        - Return 0 without doing anything
#
## Parameters:
#.  $1  - Prompt message/question. Defaults to ‘Proceed?’.
#
## Returns:
#.  0 - Yes
#.  1 - No
#
## Prints:
#.  stdout: Provided message, unaltered, followed by ‘ [y/n] ’.
#.  stderr: As little as possible
#
dprompt()
{
  # Parse args for supported options
  local args=() delim=false i opt
  local newline=false
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                     delim=true;;
      -n|--newline)           newline=true;;
      --ping)                 return 0;;
      -*)                     for i in $( seq 2 ${#1} ); do
                                case "${1:i-1:1}" in
                                  f)  newline=true;;
                                  *)  printf '%s: illegal option -- %s\n' >&2 \
                                        "${FUNCNAME[0]}" \
                                        "$opt"
                                      return 1;;
                                esac
                              done;;
      *)                      args+=("$1");;
    esac; shift
  done

  # Retrieve message and shift
  local message="$args"; args=( "${args[@]:1}" )

  # If no message is given, use default
  [ -z "$message" ] && message='Proceed?'

  # Print message and prompt for answer
  if $newline; then
    printf '%s\n[y/n] ' "$message"
  else
    printf '%s [y/n] ' "$message"
  fi

  # Wait for answer indefinitely (or until Ctrl-C)
  local yes=false
  while true; do
    read -rsn1 input
    [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
    [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
  done
  printf '\n'

  # Return result as exit status
  $yes && return 0 || return 1
}