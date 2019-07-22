#!/usr/bin/env bash
#:title:        Divine Bash utils: dtrim
#:kind:         func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    4
#:revdate:      2019.07.22
#:revremark:    New revisioning system
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

#>  dtrim [-hscqQn]… [--] STRING…
#
## Prints every argument on a new line, with leading and trailing spaces 
#. removed. Optionally can remove comments (‘//’ and ‘#’ line comments are 
#. supported).
#
## Options:
#.  -h|--dehash       - In each string also remove everything between first 
#.                      occurrence of hash (‘#’) and string’s end
#.  -s|--deslash      - In each string also remove everything between first 
#.                      occurrence of double-slash (‘//’) and string’s end
#.  -c|--decomment    - Equivalent of ‘-h’ and ‘-s’ together
#.  -q|--dequote      - In each string remove a matching pair of quotes (single 
#.                      or double) from both ends after trimming the whitespace
#.  -Q|--dequote-trim - Dequote and then trim whitespace within the quotes
#.  -n|--no-newline   - Omit terminating newlines
#.  --ping            - Return 0 without doing anything
#
## Parameters:
#.  $@  - Strings to trim
#
## Returns:
#.  1 — If an illegal option was given
#.  0 - Otherwise
#
## Prints:
#.  stdout: Trimmed input
#.  stderr: Illegal usage errors
#
dtrim()
{
  # Parse args for supported options
  local args=() delim=false i opt
  local dehash=false deslash=false dequote=false dequotetrim=false no_nl=false
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                     delim=true;;
      -h|--dehash)            dehash=true;;
      -s|--deslash)           deslash=true;;
      -c|--decomment)         dehash=true; deslash=true;;
      -q|--dequote)           dequote=true;;
      -Q|--dequote-trim)      dequote=true; dequotetrim=true;;
      -n|--no-newline)        no_nl=true;;
      --ping)                 return 0;;
      -*)                     for i in $( seq 2 ${#1} ); do
                                case "${1:i-1:1}" in
                                  h)  dehash=true;;
                                  s)  deslash=true;;
                                  c)  dehash=true; deslash=true;;
                                  q)  dequote=true;;
                                  Q)  dequote=true; dequotetrim=true;;
                                  n)  no_nl=true;;
                                  *)  printf '%s: illegal option -- %s\n' >&2 \
                                        "${FUNCNAME[0]}" \
                                        "$opt"
                                      return 1;;
                                esac
                              done;;
      *)                      args+=("$1");;
    esac; shift
  done

  # Return if no textual arguments provided
  [ ${#args[@]} -lt 1 ] && {
    printf 'Usage: %s %s\n' >&2 \
      "${FUNCNAME[0]}" \
      '[-c|n]… [--] STRING…'
    return 1
  }

  # Iterate over arguments
  local string
  for string in "${args[@]}"; do

    # Dehash
    if $dehash; then
      string="$( printf '%s\n' "$string" \
        | sed 's/[#].*$//' )"
    fi

    # Deslash
    if $deslash; then
      string="$( printf '%s\n' "$string" \
        | sed 's|//.*$||' )"
    fi

    # Trim whitespace
    string="$( printf '%s\n' "$string" \
      | sed \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' )"

    # Dequote
    if $dequote; then
      if [[ $string == \'*\' ]]; then
        if sed -r &>/dev/null; then
          string="$( printf '%s\n' "$string" \
            | sed -n -r -e "s/^'(.*)'$/\1/p" )"
        else
          string="$( printf '%s\n' "$string" \
            | sed -n -E -e "s/^'(.*)'$/\1/p" )"
        fi
      elif [[ $string == \"*\" ]]; then
        if sed -r &>/dev/null; then
          string="$( printf '%s\n' "$string" \
            | sed -n -r -e 's/^"(.*)"$/\1/p' )"
        else
          string="$( printf '%s\n' "$string" \
            | sed -n -E -e 's/^"(.*)"$/\1/p' )"
        fi
      fi

      if $dequotetrim; then
        string="$( printf '%s\n' "$string" \
          | sed \
          -e 's/^[[:space:]]*//' \
          -e 's/[[:space:]]*$//' )"
      fi
    fi
    
    # Print result
    printf '%s' "$string"
    $no_nl || printf '\n'

  done
  
  return 0
}