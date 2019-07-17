#!/usr/bin/env bash
#:title:        Divine Bash utils: dprint
#:kind:         func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    2.1.0-RELEASE
#:revdate:      2019.05.06
#:revremark:    Make func names and signatures more uniform
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Summary of defined functions:
#>  dprint_debug    [-l] [-n] [CHUNKS|-n|-i]…
#>  dprint_start    [-l] [-n] [CHUNKS|-n|-i]…
#>  dprint_skip     [-l] [-n] [CHUNKS|-n|-i]…
#>  dprint_success  [-l] [-n] [CHUNKS|-n|-i]…
#>  dprint_failure  [-l] [-n] [CHUNKS|-n|-i]…
#>  dprint_ode [-no] [-c|--color X] [--width-N X] [--effects-N X] [--] FIELD1 [FIELD2…]
#>  dprint_plaque [-nope]… [-c|--color X] [-w|--width X] [-r|--padding-char X] [--] MSG
#

#>  dprint_debug [-l] [-n] [CHUNKS|-n|-i]…
#
## In verbose mode: from given chunks and line breaks composes and prints a 
#. message themed as a debug line. Chunks are separated by single space.
#
## In quiet mode ($D__OPT_QUIET): does nothing.
#
## Options:
#.  -l  - (must be first) Ignore global $D__OPT_QUIET and always print
#.  -n  - (must be first or second) Prepend empty line to any other output
#
## Parameters:
#.  $@  - Textual chunks of a message. Following special chunks are recognized:
#.          '-n'  - Insert new line
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - If message was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed message
#
dprint_debug()
{
  # Check options
  [ "$1" = -l ] && shift || { [ "$D__OPT_QUIET" = true ] && return 1; }
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }

  # Save formatting
  local c="$CYAN" n="$NORMAL"

  # Compose message from arguments and print it all on the go
  printf >&2 '%s' "$c==>$n"
  local chunk; for chunk do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$c$chunk$n";; esac
  done; printf >&2 '\n'; return 0
}

#>  dprint_start [-l] [-n] [CHUNKS|-n|-i]…
#
## In verbose mode: from given chunks and line breaks composes and prints a 
#. message themed as an announcement of new stage in a process. Chunks are 
#. separated by single space.
#
## In quiet mode ($D__OPT_QUIET): does nothing.
#
## Options:
#.  -l  - (must be first) Ignore global $D__OPT_QUIET and always print
#.  -n  - (must be first or second) Prepend empty line to any other output
#
## Parameters:
#.  $@  - Textual chunks of a message. Following special chunks are recognized:
#.          '-n'  - Insert new line
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - If message was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed message
#
dprint_start()
{
  # Check options
  [ "$1" = -l ] && shift || { [ "$D__OPT_QUIET" = true ] && return 1; }
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }

  # Compose message from arguments and print it all on the go
  printf >&2 '%s' "${BOLD}${YELLOW}==>${NORMAL}"; local chunk; for chunk do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$chunk";; esac
  done; printf >&2 '\n'; return 0
}

#>  dprint_skip [-l] [-n] [CHUNKS|-n|-i]…
#
## In verbose mode: from given chunks and line breaks composes and prints a 
#. message themed as an announcement of skipped stage in a process. Chunks are 
#. separated by single space.
#
## In quiet mode ($D__OPT_QUIET): does nothing.
#
## Options:
#.  -l  - (must be first) Ignore global $D__OPT_QUIET and always print
#.  -n  - (must be first or second) Prepend empty line to any other output
#
## Parameters:
#.  $@  - Textual chunks of a message. Following special chunks are recognized:
#.          '-n'  - Insert new line
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - If message was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed message
#
dprint_skip()
{
  # Check options
  [ "$1" = -l ] && shift || { [ "$D__OPT_QUIET" = true ] && return 1; }
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }

  # Compose message from arguments and print it all on the go
  printf >&2 '%s' "${BOLD}${WHITE}==>${NORMAL}"; local chunk; for chunk do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$chunk";; esac
  done; printf >&2 '\n'; return 0
}

#>  dprint_success [-l] [-n] [CHUNKS|-n|-i]…
#
## In verbose mode: from given chunks and line breaks composes and prints a 
#. message themed as an announcement of successfully completed stage in a 
#. process. Chunks are separated by single space.
#
## In quiet mode ($D__OPT_QUIET): does nothing.
#
## Options:
#.  -l  - (must be first) Ignore global $D__OPT_QUIET and always print
#.  -n  - (must be first or second) Prepend empty line to any other output
#
## Parameters:
#.  $@  - Textual chunks of a message. Following special chunks are recognized:
#.          '-n'  - Insert new line
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - If message was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed message
#
dprint_success()
{
  # Check options
  [ "$1" = -l ] && shift || { [ "$D__OPT_QUIET" = true ] && return 1; }
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }

  # Compose message from arguments and print it all on the go
  printf >&2 '%s' "${BOLD}${GREEN}==>${NORMAL}"; local chunk; for chunk do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$chunk";; esac
  done; printf >&2 '\n'; return 0
}

#>  dprint_failure [-l] [-n] [CHUNKS|-n|-i]…
#
## In verbose mode: from given chunks and line breaks composes and prints a 
#. message themed as an announcement of failed stage in a process. Chunks are 
#. separated by single space.
#
## In quiet mode ($D__OPT_QUIET): does nothing.
#
## Options:
#.  -l  - (must be first) Ignore global $D__OPT_QUIET and always print
#.  -n  - (must be first or second) Prepend empty line to any other output
#
## Parameters:
#.  $@  - Textual chunks of a message. Following special chunks are recognized:
#.          '-n'  - Insert new line
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - If message was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed message
#
dprint_failure()
{
  # Check options
  [ "$1" = -l ] && shift || { [ "$D__OPT_QUIET" = true ] && return 1; }
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }

  # Compose message from arguments and print it all on the go
  printf >&2 '%s' "${BOLD}${RED}==>${NORMAL}"; local chunk; for chunk do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$chunk";; esac
  done; printf >&2 '\n'; return 0
}

#>  dprint_ode [-no] [-c|--color X] [--width-N X] [--effects-N X] [--] FIELD1 [FIELD2…]
#
## Prints formatted message consisting of fields. Arguments are textual 
#. ‘fields’ numbered from one. Adjacent non-empty fields are separated by 
#. single space.
#
## A field can be given a constant width, to which it will be padded/truncated. 
#. Padding character is space. When last provided element is to be truncated, 
#. it is instead wrapped to as many lines as necessary, all starting at the 
#. same column.
#
#>  dprint_ode -c $GREEN '>>>' Success: 'Operation completed' '(no errors)'
#=  >>> Success: Operation completed (no errors)
#
## Effects applied by default:
#.  FIeld N:        1  2  3  others
#.  Bold:           v  v  v  _
#.  Color:          v  v  _  _
#.  Inverse color:  v  _  _  _
#
## Options:
#.  -n|--no-newline   - Omit terminating newline
#.  -o|--stdout       - Print to stdout instead of default stderr
#.  -c|--color X      - Uses color X (see dcolors.utl.sh) in formatting. 
#.                      Without this, default terminal color is used.
#.  --width-N X       - Truncate/pad field N to width X. Content is printed 
#.                      flush left. Valid integer values are forced between 0 
#.                      and 80, inclusive.
#.                      Empty value width removes restrictions. Suffix ‘-’ 
#.                      (hyphen) suppresses space after that field.
#.                      Repeated use overrides previous ones.
#.  --effects-N X     - Commands for field N, applied left-to-right:
#.                        * b - apply boldness
#.                        * c - apply color
#.                        * i - apply inverse color
#.                        * d - remove all effects, apply default ones instead
#.                        * n - remove all effects
#.                      E.g. ‘--effects-1 ci’ applies inverse color to field 1.
#.                      Repeated use overrides previous ones.
#.  --ping            - Return 0 without doing anything
#
## Parameters:
#.  $@  - Fields, numbered starting from 1
#
## Returns:
#.  0 - If anything was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout: Composed and formatted message
#.  stderr: Error descriptions
#
dprint_ode()
{
  # Parse args for supported options
  local args=( 'placeholder' ) delim=false i opts opt
  local newline=true stdout=false
  local field_width_opts=() field_effect_opts=()
  local color
  local fieldnum field_width_opt field_effect_opt
  local field_space_opts=()
  local nullified_fieldnums=()
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                   delim=true;;
      -n|--no-newline)      newline=false;;
      -o|--stdout)          stdout=true;;
      -c|--color)           shift; color="$1";;

      --width-?*)
        # Extract field number
        fieldnum="${1#--width-}"
        # Check if field number is a valid number
        if [[ ! $fieldnum =~ ^[0-9]+$ ]] || [ $fieldnum -eq 0 ]; then
          printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" \
            'Illegal field number' "$fieldnum"
          return 1
        fi
        # Shift to next argument and read width
        shift; field_width_opt="$1"
        # Check if width is suffixed with ‘-’ modificator
        if [[ $field_width_opt =~ .*-$ ]]; then
          # Store option (any non-zero-length string means ‘no space after’)
          field_space_opts[$fieldnum]='no_space'
          # Remove trailing ‘-’
          field_width_opt="${field_width_opt%-}"
        else
          # Otherwise, unset any previous preference
          unset field_space_opts[$fieldnum]
        fi
        # Check if width is ‘no-preference’ (empty string)
        if [ -z "$field_width_opt" ]; then
          # Unset any previous preferences
          unset field_width_opts[$fieldnum]
          # Don’t process further
        else
          # Check if width is a valid number
          if [[ ! $field_width_opt =~ ^[0-9]+$ ]]; then
            printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" \
              'Illegal field width' "$field_width_opt"
            return 1
          fi
          # Normalize width to acceptable range
          (( field_width_opt < 0 )) && field_width_opt=0
          (( field_width_opt > 80 )) && field_width_opt=80
          # If width is zero, store this info
          [ $field_width_opt -eq 0 ] && nullified_fieldnums+=($fieldnum)
          # Store width
          field_width_opts[$fieldnum]=$field_width_opt
        fi
        # Done processing width
        ;;

      --effects-?*)
        # Extract field number
        fieldnum="${1#--effects-}"
        # Check if field number is a valid number
        if [[ ! $fieldnum =~ ^[0-9]+$ ]] || [ $fieldnum -eq 0 ]; then
          printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" \
            'Illegal field number' "$fieldnum"
          return 1
        fi
        # Shift to next argument and read effects
        shift; field_effect_opt="$1"
        # Check if there are any effects
        if [ -z "$field_effect_opt" ]; then
          # Unset any previous preferences
          unset field_effect_opts[$fieldnum]
          # Don’t process further
        else
          # Check if effects is a valid string (empty string valid as well)
          if [[ ! $field_effect_opt =~ ^[bcidn]*$ ]]; then
            printf >&2 '%s: %s: %s\n' "${FUNCNAME[0]}" \
              'Illegal field effects' "$field_effect_opt"
            return 1
          fi
          # Store effects
          field_effect_opts[$fieldnum]=$field_effect_opt
        fi
        # Done processing effects
        ;;
      
      --ping)               return 0;;
      -*)                   opts="$1"
                            for i in $( seq 2 ${#opts} ); do
                              opt="${opts:i-1:1}"
                              case "$opt" in
                                n)  newline=false;;
                                o)  stdout=true;;
                                c)  shift; color="$1";;
                                *)  printf >&2 '%s: illegal option -- %s\n' \
                                      "${FUNCNAME[0]}" \
                                      "$opt"
                                    return 1;;
                              esac
                            done;;
      *)                    args+=("$1");;
    esac; shift
  done

  # Store number of textual arguments
  local num_args=${#args[@]}

  # Unset placeholder zero’th argument
  unset args[0]

  # Unset textual arguments that have their width set to zero
  if [ ${#nullified_fieldnums[@]} -gt 0 ]; then
    for fieldnum in "${nullified_fieldnums[@]}"; do
      unset args[$fieldnum]
    done
  fi

  # Store number of non-zero fields
  local num_fields_remaining=${#args[@]}

  # Return without printing if no textual arguments provided
  [ $num_fields_remaining -gt 0 ] || {
    printf >&2 'Usage: %s %s\n' \
      "${FUNCNAME[0]}" \
      '[-no] [-c|--color X] [--width-N X] [--effects-N X] [--] FIELD1 [FIELD2…]'
    return 1
  }

  # Storage variable for total width printed thus far
  local width_printed=0

  # Storage variables
  local pos field_text effect_str effect_str_override

  # Line buffers
  local first_line= other_lines=() other_line indentation=

  #
  # Iterate over textual argument numbers
  #
  for (( fieldnum=1; fieldnum<$num_args; fieldnum++ )); do

    # If field number is unset, skip over
    [ -z ${args[$fieldnum]+isset} ] && continue

    # Decrement remaining field count
    (( num_fields_remaining-- ))
    
    # Retrieve field, along with its width
    field_text="${args[$fieldnum]}"
    field_width_opt="${field_width_opts[$fieldnum]}"

    # Set default effects
    case $fieldnum in
      1)  effect_str="${BOLD}${color}${REVERSE}";;
      2)  effect_str="${BOLD}${color}";;
      3)  effect_str="${BOLD}";;
      *)  effect_str=;;
    esac

    # Check if effects overrides are set
    if [ -n ${field_effect_opts[$fieldnum]+isset} ]; then

      # Check whether overriding string is not empty
      if [ -n "${field_effect_opts[$fieldnum]}" ]; then

        # Effects overridden: start with empty effect string
        effect_str_override=

        # Iterate over effect flags left-to-right
        for i in $( seq 1 ${#field_effect_opts[$fieldnum]} ); do
          case "${field_effect_opts[$fieldnum]:i-1:1}" in
            b)  effect_str_override+="${BOLD}";;
            c)  effect_str_override+="${color}";;
            i)  effect_str_override+="${REVERSE}";;
            d)  effect_str_override="$effect_str";;
            n)  effect_str_override=;;
            *)  :;;
          esac
        done

        # Replace effect string
        effect_str="$effect_str_override"
      fi

    fi

    # Check if field width is mandated
    if [ -n "$field_width_opt" ]; then

      # Check if mandated width is too narrow
      if [ ${#field_text} -gt $field_width_opt ]; then

        # Width is insufficient

        # Check if not last to be printed
        if [ $num_fields_remaining -gt 0 ]; then

          # Buffer field, truncated, increment counter
          first_line+="${effect_str}${field_text:0:$field_width_opt}${NORMAL}"
          (( width_printed += field_width_opt ))

          # If not prevented from, add space
          if [ -z "${field_space_opts[$fieldnum]}" ]; then
            first_line+=' '
            (( width_printed++ ))
          fi

        else

          # Buffer field in chunks
          pos=0

          # Buffer first chunk, increment pos
          first_line+="${effect_str}${field_text:$pos:$field_width_opt}"
          first_line+="${NORMAL}"
          (( pos += field_width_opt ))

          # If wrapping to new line, generate indentation
          if [ $pos -lt ${#field_text} -a $width_printed -gt 0 ]; then
            indentation+="$( printf ' %.0s' $(seq 1 $width_printed) )"
          fi

          # Buffer rest of the chunks
          while (( pos < ${#field_text} )); do
            
            # Buffer chunk, with indentation, increment pos
            other_lines+=( \
      "$indentation${effect_str}${field_text:$pos:$field_width_opt}${NORMAL}" \
            )
            (( pos += field_width_opt ))

          done

          # Increment counter
          (( width_printed += field_width_opt ))

        fi

      else

        # Width is sufficient: buffer field space-padded, increment counter
        first_line+="${effect_str}"
        first_line+="$( printf "%-${field_width_opt}s" "$field_text" )"
        first_line+="${NORMAL}"
        (( width_printed += field_width_opt ))
        
        # If not last to be printed, and not prevented from, add space
        if [ $num_fields_remaining -gt 0 \
          -a -z "${field_space_opts[$fieldnum]}" ]; then
            first_line+=' '
            (( width_printed++ ))
        fi

      fi

    else

      # If text is zero length, skip entirely
      [ -n "$field_text" ] || continue

      # Width not mandated: buffer field as is, increment counter
      first_line+="${effect_str}$field_text${NORMAL}"
      (( width_printed += ${#field_text} ))
      
      # If not last to be printed, and not prevented from, add space
      if [ $num_fields_remaining -gt 0 \
        -a -z "${field_space_opts[$fieldnum]}" ]; then
          first_line+=' '
          (( width_printed++ ))
      fi

    fi

  done

  # Check if anything has been buffered
  if (( width_printed > 0 )); then

    # Print buffered text
    if $stdout; then

      # First line goes first
      printf '%s' "$first_line"

      # If there were others, print them too, prefixing each with newline
      for other_line in "${other_lines[@]}"; do
        printf '\n%s' "$other_line"
      done

      # Conditionally print newline
      $newline && printf '\n'
    
    else

      # Default mode: print everything to stderr

      # First line goes first
      printf >&2 '%s' "$first_line"

      # If there were others, print them too, prefixing each with newline
      for other_line in "${other_lines[@]}"; do
        printf >&2 '\n%s' "$other_line"
      done

      # Conditionally print newline
      $newline && printf >&2 '\n'
    
    fi

    # Return status
    return 0

  else

    # Nothing buffered: return status
    return 1

  fi
}

#>  dprint_plaque [-nope]… [-c|--color X] [-w|--width X] [-r|--padding-char X] [--] MSG
#
## Prints message, either truncated or padded with spaces equally on both sides 
#. to match provided width. By default prints an extra space on both sides of 
#. the message, increasing the actual width by two. If the message length is 
#. effectively zero, does not print anything at all. By default applies 
#. formatting: color (specified by user), inverse color, bold text.
#
#>  dprint_plaque ABCDE 8 '#'
#=  ## ABCDE #
#
#>  dprint_plaque -p ABCDE 8 '#'
#=  ##ABCDE#
#
## Options:
#.  -c|--color X          - Uses color X (see dcolors.utl.sh) in formatting. 
#.                          Without this, default terminal color is used.
#.  -o|--stdout           - Print to stdout instead of default stderr
#.  -w|--width X          - Makes plaque X character wide. Without this, or if 
#.                          not a number >=0 and <=128, defaults to 32. With 
#.                          '-e', actual width is +2.
#.  -r|--padding-char X   - First character of provided string X is used as 
#.                          padding character. Defaults to ' ' (single space).
#.  -n|--no-newline       - Omit terminating newline
#.  -p|--no-extra-padding - Omit extra space on both sides of the message
#.  -e|--no-effects       - Do not apply any formatting effects
#.  --ping                - Return 0 without doing anything
#
## Parameters:
#.  $1  - Message
#
## Returns:
#.  0 - If anything was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout: Message, truncated (or padded with provided character) to desired 
#.          width, with an optional space on both sides
#.  stderr: Error descriptions
#
dprint_plaque()
{
  # Parse args for supported options
  local args=() delim=false i opts opt
  local color width pad_char
  local newline=true pad_extra=true effects=true stdout=false
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                     delim=true;;
      -n|--no-newline)        newline=false;;
      -o|--stdout)            stdout=true;;
      -p|--no-extra-padding)  pad_extra=false;;
      -e|--no-effects)        effects=false;;
      -c|--color)             shift; color="$1";;
      -w|--width)             shift; width="$1";;
      -r|--pad_char)          shift; pad_char="$1";;
      --ping)                 return 0;;
      -*)                     opts="$1"
                              for i in $( seq 2 ${#opts} ); do
                                opt="${opts:i-1:1}"
                                case "$opt" in
                                  n)  newline=false;;
                                  o)  stdout=true;;
                                  p)  pad_extra=false;;
                                  e)  effects=false;;
                                  c)  shift; color="$1";;
                                  w)  shift; width="$1";;
                                  r)  shift; pad_char="$1";;
                                  *)  printf >&2 '%s: illegal option -- %s\n' \
                                        "${FUNCNAME[0]}" \
                                        "$opt"
                                      return 1;;
                                esac
                              done;;
      *)                      args+=("$1");;
    esac; shift
  done

  # Return without printing if no textual arguments provided
  [ ${#args[@]} -lt 1 ] && {
    printf >&2 'Usage: %s %s\n' \
      "${FUNCNAME[0]}" \
      '[-nope]… [-c|--color X] [-w|--width X] [-r|--padding-char X] [--] MSG'
    return 1
  }

  # Retrieve message and shift
  local message="$args"

  # Force width into acceptable range
  [[ $width =~ ^[0-9]+$ ]] \
    && [ $width -ge 0 ] \
    && [ $width -le 128 ] \
    || width=32

  # Storage variables
  local message_width pad_left pad_right

  # Truncate message to acceptable width
  message=${message:0:$width}
  message_width=${#message}

  # Check if message is empty
  [ $message_width -eq 0 ] && return 1

  # Extract padding character, defaulting to whitespace
  pad_char=${pad_char:0:1}
  [ -n "$pad_char" ] || pad_char=' '

  # Calculate padding widths, left and right
  let "pad_right = ( width - message_width ) / 2 - 1"
  let "pad_left = width - message_width - pad_right - 2"

  # Print plaque in chunks
  if $stdout; then
    # Print all to stdout
    $effects              &&  printf '%s' "${color}${BOLD}${REVERSE}"
    [ $pad_left -ge 0 ]   &&  printf "$pad_char%.0s" $(seq 0 $pad_left)
    $pad_extra            &&  printf ' '
                              printf '%s' "$message"
    $pad_extra            &&  printf ' '
    [ $pad_right -ge 0 ]  &&  printf "$pad_char%.0s" $(seq 0 $pad_right)
    $effects              &&  printf '%s' "${NORMAL}"
    $newline              &&  printf '\n'
  else
    # Print all to stderr
    $effects              &&  printf >&2 '%s' "${color}${BOLD}${REVERSE}"
    [ $pad_left -ge 0 ]   &&  printf >&2 "$pad_char%.0s" $(seq 0 $pad_left)
    $pad_extra            &&  printf >&2 ' '
                              printf >&2 '%s' "$message"
    $pad_extra            &&  printf >&2 ' '
    [ $pad_right -ge 0 ]  &&  printf >&2 "$pad_char%.0s" $(seq 0 $pad_right)
    $effects              &&  printf >&2 '%s' "${NORMAL}"
    $newline              &&  printf >&2 '\n'
  fi

  # Report
  return 0
}