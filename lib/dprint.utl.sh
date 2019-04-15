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
#>  dprint_msg [-n] [-c|--color X] [--width-N X] [--effects-N X] [--] FIELD1 [FIELD2…]
#>  dprint_plaque [-npe]… [-c|--color X] [-w|--width X] [-r|--padding-char X] [--] MSG
#

## Previous signatures (to be deleted)
#>  printc_msg [-n]… [--] COLOR ICON [TITLE [MSG [SUBMSG]]]
#>  print_plaque [-np]… [--] MSG [WIDTH [PADDING_CHAR]]
#>  printc_plaque [-np]… [--] COLOR MSG [WIDTH [PADDING_CHAR]]
#

#>  dprint_msg [-n] [-c|--color X] [--width-N X] [--effects-N X] [--] FIELD1 [FIELD2…]
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
#>  dprint_msg -c $GREEN '>>>' Success: 'Operation completed' '(no errors)'
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
dprint_msg()
{
  # Parse args for supported options
  local args=( 'placeholder' ) delim=false i opts opt
  local newline=true
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
      '[-n] [-c|--color X] [--width-N X] [--effects-N X] [--] FIELD1 [FIELD2…]'
    return 1
  }

  # Storage variable for total width printed thus far
  local width_printed=0

  # Storage variables
  local pos field_text effect_str effect_str_override

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

          # Print field truncated, increment counter
          printf '%s' \
            "${effect_str}${field_text:0:$field_width_opt}${NORMAL}" \
            && (( width_printed += field_width_opt ))

          # If not prevented from, add space
          [ -z "${field_space_opts[$fieldnum]}" ] \
            && { printf ' ' && (( width_printed++ )); }

        else

          # Print field in chuncs
          pos=0

          # Print first chunk, increment pos
          printf '%s' \
            "${effect_str}${field_text:$pos:$field_width_opt}${NORMAL}" \
            && (( pos += field_width_opt ))

          # Print rest of the chunks
          while (( pos < ${#field_text} )); do
            
            # Print newline
            printf '\n'
            
            # For non-first lines, prefix spaces
            [ $width_printed -gt 0 ] && printf ' %.0s' $(seq 1 $width_printed)

            # Print chunk, increment pos
            printf '%s' \
              "${effect_str}${field_text:$pos:$field_width_opt}${NORMAL}" \
              && (( pos += field_width_opt ))

          done

          # Increment counter
          (( width_printed += field_width_opt ))

        fi

      # Otherwise, print field space padded
      else

        # Width is sufficient: print field space-padded, increment counter
        printf "${effect_str}%-${field_width_opt}s${NORMAL}" "$field_text" \
          && (( width_printed += field_width_opt ))
        
        # If not last to be printed, and not prevented from, add space
        [ $num_fields_remaining -gt 0 \
          -a -z "${field_space_opts[$fieldnum]}" ] \
            && { printf ' ' && (( width_printed++ )); }

      fi

    else

      # If text is zero length, skip entirely
      [ -n "$field_text" ] || continue

      # Width not mandated: print field as is, increment counter
      printf '%s' "${effect_str}$field_text${NORMAL}" \
      && (( width_printed += ${#field_text} ))
      
      # If not last to be printed, and not prevented from, add space
      [ $num_fields_remaining -gt 0 \
        -a -z "${field_space_opts[$fieldnum]}" ] \
          && { printf ' ' && (( width_printed++ )); }

    fi

  done

  # Check if anything has been printed, and conditionally print newline
  (( width_printed > 0 )) && $newline && printf '\n'

  # Return status
  (( width_printed > 0 )) && return 0 || return 1
}

#>  dprint_plaque [-npe]… [-c|--color X] [-w|--width X] [-r|--padding-char X] [--] MSG
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
  local newline=true pad_extra=true effects=true
  while [ $# -gt 0 ]; do
    # If delimiter encountered, add arg and continue
    $delim && { args+=("$1"); shift; continue; }
    # Otherwise, parse options
    case "$1" in
      --)                     delim=true;;
      -n|--no-newline)        newline=false;;
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
      '[-npe]… [-c|--color X] [-w|--width X] [-r|--padding-char X] [--] MSG'
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
  $effects              &&  printf '%s' "${color}${BOLD}${REVERSE}"
  [ $pad_left -ge 0 ]   &&  printf "$pad_char%.0s" $(seq 0 $pad_left)
  $pad_extra            &&  printf ' '
                            printf '%s' "$message"
  $pad_extra            &&  printf ' '
  [ $pad_right -ge 0 ]  &&  printf "$pad_char%.0s" $(seq 0 $pad_right)
  $effects              &&  printf '%s' "${NORMAL}"
  $newline              &&  printf '\n'

  # Report
  return 0
}