#!/usr/bin/env bash
#:title:        Divine Bash utils: dreadlink
#:kind:         func(script,interactive)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    6
#:revdate:      2019.08.07
#:revremark:    Grand removal of non-ASCII chars
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

#>  dreadlink [-femnqsvz]... [--help] [--version] [--] FILE...
#
## Print value of a symbolic link or canonical file name
#
## Approximates behavior of GNU readlink, using option-less readlink available 
#. on most systems as common denominator. Delegates to GNU readlink if it is 
#. detected. Intended for reliable cross-platform use in Bash scripts.
#
## Requires:
#.  * Bash >=3.2
#.  * Option-less readlink (present most everywhere)
#
## Options:
#.  -f, --canonicalize 
#.                - Canonicalize by following every symlink in every component 
#.                  of the given name recursively; all but the last component 
#.                  must exist
#.  -e, --canonicalize-existing
#.                - Canonicalize by following every symlink in every component 
#.                  of the given name recursively; all components must exist
#.  -m, --canonicalize-missing
#.                - Canonicalize by following every symlink in every component 
#.                  of the given name recursively; without requirements on 
#.                  components existence
#.  -n, --no-newline
#.                - Do not output trailing delimiter (single argument only)
#.  -q, --quiet
#.  -s, --silent
#.                - (default) Suppress most error messages
#.  -v, --verbose - Report error messages
#.  -z, --zero    - End each output line with NUL, not newline
#.  --help        - Display help summary
#.  --version     - Display version information
#.  --ping        - Return 0 without doing anything
#
## Parameters:
#.  $@  - Files to resolve
#
## Returns:
#.  0 - All files resolved successfully
#.  1 - Otherwise
#
## Prints:
#.  stdout: Canonical absolute paths, those that were resolved
#.  stderr: (default) As little as possible
#.          (with '-v') Error descriptions
#
dreadlink()
{
  # Check if whether there is readlink at all
  if ! which readlink &>/dev/null; then
    # No readlink on $PATH at all. Invoke the name, to show the error.
    readlink; return $?;
  fi 

  # Parse args for supported options
  local args=() delim=false i opt
  local canonical quiet=true
  local no_nl=false zero=false
  local help=false version=false
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                     delim=true;;
      -f|--canonicalize)      canonical=f;;
      -e|--canonicalize-existing)
                              canonical=e;;
      -m|--canonicalize-missing)
                              canonical=m;;
      -n|--no-newline)        no_nl=true;;
      -q|--quiet)             quiet=true;;
      -s|--silent)            quiet=true;;
      -v|--verbose)           quiet=false;;
      -z|--zero)              zero=true;;
      --help)                 help=true;;
      --version)              version=true;;
      --ping)                 return 0;;
      -*)                     for i in $( seq 2 ${#1} ); do
                                opt="${1:i-1:1}"
                                case "$opt" in
                                  f)  canonical=f;;
                                  e)  canonical=e;;
                                  m)  canonical=m;;
                                  n)  no_nl=true;;
                                  q)  quiet=true;;
                                  s)  quiet=true;;
                                  v)  quiet=false;;
                                  z)  zero=true;;
                                  *)  printf >&2 '%s: illegal option -- %s\n' \
                                        "${FUNCNAME[0]}" \
                                        "$opt"
                                      return 1;;
                                esac
                              done;;
      *)                      args+=("$1");;
    esac; shift
  done

  # Show version if requested
  $version && {
    # Store version message in a variable
    local version_msg
    read -r -d '' version_msg << 'EOF'
dreadlink 3.0.0
Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Grove Pyree <grayarea@protonmail.ch>.

Based on perceived behavior of:
readlink (GNU coreutils) 8.31
Copyright (C) 2019 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.

Written by Dmitry V. Levin.
EOF
    # Print version message
    printf '%s\n' "$version_msg"
    return 0
  }

  # Show help if requested
  $help && {
    # Store help summary in a variable
    local help_msg
    read -r -d '' help_msg << 'EOF'
NAME
    dreadlink -- Divine readlink

USAGE
    dreadlink [-femnqsvz]... [--help] [--version] [--] FILE...

SYNOPSIS
    Print value of a symbolic link or canonical file name

DETAILS
    Approximates behavior of GNU readlink, using option-less readlink available 
    on most systems as common denominator. Delegates to GNU readlink if it is 
    detected. Intended for reliable cross-platform use in Bash scripts.

OPTIONS
    -f, --canonicalize    Canonicalize by following every symlink in every 
                          component of the given name recursively; all but the 
                          last component must exist
    -e, --canonicalize-existing
                          Canonicalize by following every symlink in every 
                          component of the given name recursively; all 
                          components must exist
    -m, --canonicalize-missing
                          Canonicalize by following every symlink in every 
                          component of the given name recursively; without 
                          requirements on components existence
    -n, --no-newline      Do not output trailing delimiter (single argument 
                          only)
    -q, --quiet
    -s, --silent          (default) Suppress most error messages
    -v, --verbose         Report error messages
    -z, --zero            End each output line with NUL, not newline
    --help                Display help summary
    --version             Display version information
    --ping                Return 0 without doing anything

CREDITS
    Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.

    Written by Grove Pyree <grayarea@protonmail.ch>.

    GNU coreutils online help: <https://www.gnu.org/software/coreutils/>
    Full documentation <https://www.gnu.org/software/coreutils/readlink>
    or available locally via: info '(coreutils) readlink invocation'
EOF
    # Print help summary
    if less --version &>/dev/null; then
      less -R <<<"$help_msg"
    else
      printf '%s\n' "$help_msg"
    fi
    return 0
  }

  # Return if no textual arguments provided
  [ ${#args[@]} -eq 0 ] && {
    printf >&2 'Usage: %s %s\n' \
      "${FUNCNAME[0]}" \
      '[-femnqsvz]... FILE...'
    printf >&2 "Try '%s --help' for more information\n" \
      "${FUNCNAME[0]}"
    return 1
  }

  # Delegate to GNU readlink if available
  # Assemble options to pass down
  local opts=()
  $quiet || opts+=('-v')
  [ "$canonical" = f ] && opts+=('-f')
  [ "$canonical" = e ] && opts+=('-e')
  [ "$canonical" = m ] && opts+=('-m')
  $no_nl && opts+=('-n')
  $zero && opts+=('-z')
  # Check for -e option, which is exclusive to GNU readlink
  # First, 'greadlink' (installed on some systems)
  greadlink -e / &>/dev/null \
    && { greadlink "${opts[@]}" -- "${args[@]}"; return $?; }
  # Second, 'readlink' itself
  readlink -e / &>/dev/null \
    && { readlink "${opts[@]}" -- "${args[@]}"; return $?; }

  #
  # Below code approximates GNU behavior using whatever tools are available
  #

  # Restrict --no-newline option to single argument
  [ "$no_nl" = true -a ${#args[@]} -gt 1 ] && {
    # Similarly to GNU readlink, this output is not dependent on verbosity
    printf >&2 '%s: %s\n' \
      "${FUNCNAME[0]}" \
      'ignoring --no-newline with multiple arguments'
    no_nl=false
  }

  # Storage variables
  local filepath filepath_orig
  local exist_part nonexist_part
  local temppath
  local return_code

  # Initiate exit code to 0
  return_code=0

  # Iterate over arguments
  for filepath in "${args[@]}"; do

    # If canonicalization NOT requested, use readlink as normal
    if [ -z "$canonical" ]; then

      # Call readlink, catch returned code
      filepath="$( readlink "$filepath" 2>/dev/null || exit $? )"

      # Non-zero exit basically means 'not a symlink'
      if [ $? -ne 0 ]; then
        # Remember this, to return appropriate code in the end
        return_code=1
        # Skip this argument without printing anything
        continue
      fi

      # Print current argument honoring provided options
      printf '%s' "$filepath"
      $zero && printf '%b' '\0'
      $no_nl || printf '\n'

      # On to the next argument
      continue

    fi

    # Save original input for error messages
    filepath_orig="$filepath"

    # Store original path in two parts
    exist_part="$filepath"
    nonexist_part=

    ## Can Bash resolve given path? 'test -e' goes all the way in to check 
    #. whether the path ultimately points to something that exists
    if [ ! -e "$exist_part" ]; then
      
      # Given path is not resolvable. This is where -e option dies.
      if [ "$canonical" = e ]; then
        # Optionally inform the user
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$filepath_orig" \
          'No such file or directory'
        # Remember this, to return appropriate code in the end
        return_code=1
        # Skip this argument without printing anything
        continue
      fi

      # Options -f and -m still have hope
      # Shift non-existing element off to non-existing part
      nonexist_part="$( basename -- "$exist_part" )"
      exist_part="$( dirname -- "$exist_part" )"

      # To fulfill -f option, parent path must eventually be a directory
      if [ ! -d "$exist_part" ]; then

        # This is where -f option dies
        if [ "$canonical" = f ]; then
          # Optionally inform the user
          $quiet || printf >&2 '%s: %s: %s\n' \
            "${FUNCNAME[0]}" \
            "$filepath_orig" \
            'No such file or directory'
          # Remember this, to return appropriate code in the end
          return_code=1
          # Skip this argument without printing anything
          continue
        fi

      fi

      # If -f option survived, don't touch it further

      # Option -m still needs more checking
      if [ "$canonical" = m ]; then

        ## With -m option we basically keep digging up parents until one of 
        #. them exists in some form
        while [ ! -e "$exist_part" ]; do

          # Shift non-existing element off to non-existing part
          nonexist_part="$( basename -- "$exist_part" )/$nonexist_part"
          exist_part="$( dirname -- "$exist_part" )"

          ## Worst case, this loop will eventually hit:
          #.  * For relative paths: '.'
          #.  * For absolute paths: '/'
          #
          ## Both of the above are expected to always exist.
          #
        
        done
    
      fi

    fi

    ## At this point existing part is confirmed to exist (or arg has been 
    #. skipped, depending on options)

    # The easiest way to resolve symlinks is with directories
    if [ -d "$exist_part" ]; then

      # Fully resolve dir path from within
      exist_part="$( cd -P "$exist_part" &>/dev/null \
        && pwd || exit $? )"

      # Check if 'cd' above failed
      [ $? -ne 0 ] && {
        # Smells like permissions issue
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$filepath_orig" \
          'Inaccessible'
        # Remember this, to return appropriate code in the end
        return_code=1
        # Skip this argument without printing anything
        continue
      }

    else

      # In all other cases, repeatedly resolve symlink at the base, if any
      while [ -L "$exist_part" ]; do

        # Save parent directory in case base symlink is relative
        temppath="$( dirname -- "$exist_part" )"

        # Resolve base symlink
        exist_part="$( readlink -- "$exist_part" )"

        # If base symlink was relative, restore path
        [[ $exist_part != /* ]] && exist_part="$temppath/$exist_part"

      done

      # Then, fully resolve parent path
      temppath="$( cd -P "$( dirname -- "$exist_part" )" &>/dev/null \
        && pwd || exit $? )"

      # Check if 'cd' above failed
      [ $? -ne 0 ] && {
        # Smells like permissions issue
        $quiet || printf >&2 '%s: %s: %s\n' \
          "${FUNCNAME[0]}" \
          "$filepath_orig" \
          'Inaccessible'
        # Remember this, to return appropriate code in the end
        return_code=1
        # Skip this argument without printing anything
        continue
      }

      # Put existing part back together
      exist_part="${temppath%/}/$( basename -- "$exist_part" )"
    
    fi

    # Put the path back together
    filepath="${exist_part%/}/$nonexist_part"

    # Print current argument honoring provided options
    printf '%s' "${filepath%/}"
    $zero && printf '%b' '\0'
    $no_nl || printf '\n'

  done

  return $return_code
}