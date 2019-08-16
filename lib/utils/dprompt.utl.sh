#!/usr/bin/env bash
#:title:        Divine Bash utils: dprompt
#:kind:         func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    7
#:revdate:      2019.08.16
#:revremark:    Improve arg parsing by dprompt
#:created_at:   2018.12.20

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#

#>  dprompt [-a ANSWER] [-p PROMPT] [-c COLOR] [-brkyq]... [--] [CHUNKS|-n|-i]...
#
## Interactively promts user for either:
#.  * yes or no answer (default prompt 'Proceed?')
#.  * any key press (default prompt 'Press any key to continue')
#
## Before prompting, prints non-option arguments as description, with 
#. configurable formatting. Then prints overridable pre-defined prompt followed 
#. by declaration of expected input, e.g. '[y/n]'.
#
## Options:
#.  -a|--answer ANSWER  - If ANSWER is 'true', returns 0 immediately.
#.                        If ANSWER is 'false', returns 1 immediately.
#.                        Otherwise, proceeds with prompting.
#.  -p|--prompt PROMPT  - Custom prompt text. This should be short, e.g., 'Are 
#.                        you sure?' Long-winded description is better given in 
#.                        chunks as regular arguments.
#.  -c|--color COLOR    - Uses color X (see dcolors.utl.sh) in formatting. 
#.                        Without this, $YELLOW is used.
#.  -b                  - (repeatable) Gradually remove built-in coloring and 
#.                        bolding effects. Depending on number of -b options:
#.                          0:  bold, color, reverse color
#.                          1:  bold, color
#.                          2:  bold
#.                          3:  color
#.                          4+: -
#.  --bare              - Completely remove built-in coloring and formatting
#.  -r|--arrow          - Print '==>' arrow. Without this option, the arrow is 
#.                        only printed with at least one textual chunk.
#.  -k|--any-key        - Mode: any key. Return 0 on any key press.
#.  -y|--yes-no         - Mode: yes or no. Wait for either 'y' (return 0) or 
#.                        'n' (return 1).
#.  -q|--or-quit        - Additionally expect 'q' (return 2).
#
## Parameters:
#.  $@  - Textual chunks of prompt description. Following special chunks are 
#.        recognized:
#.          '-n'  - Insert new line. Single '-n' encountered before any other 
#.                  chunks is interpreted as: print newline before any output
#.          '-i'  - Insert new indented line
#
## Returns:
#.  0 - If message was printed
#.  1 - Otherwise
#
## Prints:
#.  stdout  - *nothing*
#.  stderr  - Composed prompt description, prompt itself, accepted response
#
dprompt()
{
  # Parse options
  local args=() prompt= prompt_overridden=false color="${YELLOW}"
  local arrow=false formats=4 mode=yn or_quit=false answer
  local i opts opt no_more_args
  while (($#)); do
    case $1 in
      --)           shift; args+=("$@"); break;;
      -a|--answer)  shift; (($#)) && answer="$1" || break;;
      -p|--prompt)  shift; if (($#)); then prompt="$1"; prompt_overridden=true
                    else break; fi;;
      -c|--color)   shift; (($#)) && color="$1" || break;;
      -b)           ((formats)) && ((formats--));;
      --bare)       formats=0;;
      -r|--arrow)   arrow=true;;
      -k|--any-key) mode=any;;
      -y|--yes-no)  mode=yn;;
      -q|--or-quit) or_quit=true;;
      -?*)          opts="$1"; no_more_args=false
                    for i in $( seq 2 ${#opts} ); do
                      opt="${opts:i-1:1}"; case $opt in
                        a)  if $no_more_args; then continue
                            else
                              shift; (($#)) && answer="$1" || no_more_args=true
                            fi
                            ;;
                        p)  if $no_more_args; then continue
                            else
                              shift
                              if (($#)); then
                                prompt="$1"; prompt_overridden=true
                              else
                                no_more_args=true
                              fi
                            fi
                            ;;
                        c)  if $no_more_args; then continue
                            else
                              shift; (($#)) && color="$1" || no_more_args=true
                            fi
                            ;;
                        b)  ((formats)) && ((formats--));;
                        r)  arrow=true;;
                        k)  mode=any;;
                        y)  mode=yn;;
                        q)  or_quit=true;;
                        *)  continue;;
                      esac
                    done
                    $no_more_args && break
                    ;;
      *)            args+=($1);;
    esac; shift
  done
  # Set function arguments to just non-option ones
  set -- "${args[@]}"

  # Depending on mode, check whether pre-defined answer is given:
  case $mode in
    yn)   case $answer in
            true)   return 0;;
            false)  return 1;;
            *)      :;;
          esac
          ;;
    *)    case $answer in
            true)   return 0;;
            false)  return 0;;
            *)      :;;
          esac
          ;;
  esac

  # If requested, print first newline before any other output
  [ "$1" = -n ] && { printf >&2 '\n'; shift; }

  # Compose formatting
  local prefix suffix spacing
  case $formats in
    4) prefix="${BOLD}${color}${REVERSE}"; suffix="${NORMAL}"; spacing=' ';;
    3) prefix="${BOLD}${color}"; suffix="${NORMAL}"; spacing=;;
    2) prefix="${BOLD}"; suffix="${NORMAL}"; spacing=;;
    1) prefix="${color}"; suffix="${NORMAL}"; spacing=;;
    *) prefix=; suffix=; spacing=;;
  esac

  # If still have chunks to print (or if requested), print arrow
  if (($#)); then
    printf >&2 '%s' "${prefix}==>${suffix}"
  elif [ "$arrow" = true ]; then
    printf >&2 '%s' "${prefix}==>${suffix}"
    ((formats<4)) && printf >&2 ' '
  fi

  # Print any remaining chunks, space-separated
  local chunk; for chunk do
    case $chunk in -n) printf >&2 '\n   ';; -i) printf >&2 '\n       ';;
    *) printf >&2 ' %s' "$chunk";; esac
  done

  # Print newline and indentation if there were any chunks printed
  (($#)) && printf >&2 '\n    '

  # Pre-fill 'safe' default answer; prepare input storage
  local ans=false input prompt

  # Diverge into different modes
  if [ "$mode" = yn ]; then

    # Yes/no mode

    # Compose prompt
    $prompt_overridden || prompt='Proceed?'
    $or_quit && prompt+=' [y/n/q]' || prompt+=' [y/n]'

    # Print prompt
    printf >&2 '%s ' "${prefix}${spacing}${prompt}${spacing}${suffix}"

    # Await answer
    while true; do
      read -rsn1 input
      [[ $input =~ ^(y|Y)$ ]] && { printf >&2 'y'; ans=true;  break; }
      [[ $input =~ ^(n|N)$ ]] && { printf >&2 'n'; ans=false; break; }
      $or_quit && [[ $input =~ ^(q|Q)$ ]] \
        && { printf >&2 'q'; ans=quit; break; }
    done

  elif [ "$mode" = any ]; then

    # Any key mode

    # Compose prompt
    $prompt_overridden || prompt='Press any key to continue'
    $or_quit && prompt+=" (or 'q' to quit)"

    # Print prompt
    printf >&2 '%s ' "${prefix}${spacing}${prompt}${spacing}${suffix}"

    # Await answer
    while true; do
      read -rsn1 input
      $or_quit && [[ $input =~ ^(q|Q)$ ]] \
        && { printf >&2 'q'; ans=quit; break; }
      ans=true; break
    done
  
  fi

  # Once done, print new line
  printf >&2 '\n'

  # Return result as exit status
  case $ans in true) return 0;; false) return 1;; *) return 2;; esac
}