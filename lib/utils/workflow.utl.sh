#!/usr/bin/env bash
#:title:        Divine Bash utils: workflow
#:kind:         func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    1
#:revdate:      2019.09.12
#:revremark:    Initialize workflow
#:created_at:   2019.09.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Utilities that create a Divine workflow — the preferred way of structuring 
#. code and managing debug output.
#

#>  d__context [-l] [-t TITLE] [--] push|pop DESCRIPTION...
#
## Manipulates Divine workflow context stack.
#
## Within the Divine workflow, the context is akin to a call stack: it is the 
#. lineage of nested tasks: from the most general one at the root, down to the 
#. most specific one at arbitrary depth. The numbering of levels of the context 
#. stack starts at zero.
#
## An example of the Divine context stack might be the following:
#.  0: Running Divine.dotfiles install routine
#.  1: Installing deployments at priority 4096
#.  2: Deployment 'example'
#
## In the example above, the 'push' and 'pop' operations add and remove items 
#. from below, respectively.
#
## Every stack manipulation triggers a debug message that honors the global 
#. verbosity setting. If a 'push' is prepended to every logical unit of code, 
#. and then a matching 'pop' is appended at the end, a useful pattern of 
#. breadcrumbs arises in the debug output. Also, other Divine workflow 
#. utilities include the state of the context stack in their error output.
#
## Each item on the context stack should be given a one-sentence DESCRIPTION.
#. As a matter of good style, the DESCRIPTION should be worded around either a 
#. noun or a verb in its -ing form (gerund). Repetition of information from 
#. above levels should be minimized.
#
## The layout of the output is as follows.
#
##  ==> <TITLE>: <DESCRIPTION>
#
##  * TITLE       - Short heading of the message. Defaults to:
#.                    * 'Start'   - During 'push' routine.
#.                    * 'End'     - During 'pop' routine.
#.  * DESCRIPTION - Text of the pushed/popped context item.
#
## The output is prepended with a 'fat' ASCII arrow '==>'. The line of the 
#. output consists of a title and a message, delimited by a colon.
#
## If terminal coloring is available:
#.  * The entire output is painted cyan.
#.  * Title is styled in bold.
#
## If terminal coloring is available, and the --loud option is used:
#.  * Arrow is styled in bold yellow.
#.  * Title is styled in bold.
#
## Uses in global scope:
#>  $D__CONTEXT   - Global storage for the Divine workflow context stack.
#>  $D__OPT_QUIET - Global verbosity setting.
#
## Options:
#.  -l, --loud                - Announce context switching regardless of the 
#.                              global verbosity setting.
#.  -t TITLE, --title TITLE   - Custom title for the message.
#
## Parameters:
#.  $1  - Name of the routine to run:
#.          * push  - Add one item at the bottom of the stack.
#.          * pop   - Remove one item at the bottom of the stack.
#.  $*  - Human-readable description of the stack item. During the 'pop' 
#.        routine it overrides the description of the popped item, which is 
#.        printed by default.
#
## Returns:
#.  0 - Modified the stack as requested.
#.  1 - Stack not modified: no arguments or unrecognized routine name.
#.  2 - Stack not modified: pushing without a DESCRIPTION.
#.  3 - Stack not modified: popping from an empty stack.
#
## Prints:
#.  stdout: Nothing.
#.  stderr: Debug messages about argument errors and context modifications.
#
d__context()
{
  # Pluck out options, round up arguments
  local args=() arg opt quiet=true title; while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)        args+=("$@"); break;;
          l|-loud)  quiet=false;;
          t|-title) if (($#)); then read -r title <<<"$1"; [ -n "$title" ] || title='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '$opt'"; fi;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"
                case $opt in
                  l)  quiet=false;;
                  t)  if (($#)); then read -r title <<<"$1"; [ -n "$title" ] || title='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '$opt'"; fi;;
                  *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
                esac
              done;;
        esac;;
    *)  args+=("$arg");;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments"; return 1; fi

  # Inspect the first argument; modify the global array accordingly; prepare for potential debug output
  case ${args[0]} in
    push) set -- "${args[@]}"; shift; local level msg
          if ! (($#)); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Attempted to push an empty item onto the context stack"; return 2; fi
          level=${#D__CONTEXT[@]}
          [ -n "$title" ] || title='Start'
          read -r msg <<<"$*"; [ -n "$msg" ] || msg='<empty description>'
          D__CONTEXT+=("$msg")
          ;;
    pop)  set -- "${args[@]}"; shift; local level msg
          level=$((${#D__CONTEXT[@]}-1))
          if (($level<0)); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Attempted to pop from the empty context stack"; return 3; fi
          [ -n "$title" ] || title='End'
          if (($#)); then read -r msg <<<"$*"; [ -n "$msg" ] || msg='<empty description>'; else msg="${D__CONTEXT[$level]}"; fi
          unset D__CONTEXT[$level]
          ;;
    *)    printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Ignoring unrecognized routine: '${args[0]}'"; return 1;;
  esac

  # Print the debug output, if necessary
  if $quiet; then $D__OPT_QUIET && return 0
    printf >&2 "%s %s: %s\n" "$CYAN==>" "$BOLD$title$NORMAL$CYAN" "$msg$NORMAL"
  else
    printf >&2 "%s %s: %s\n" "$YELLOW$BOLD==>$NORMAL" "$BOLD$title$NORMAL" "$msg"
  fi
}

#>  d__cmd [<options>] [----] CMD...
#
## Wrapper around almost any single Bash command. When d__cmd is prepended to 
#. CMD, CMD is executed as normal, then its return code is inspected. If the 
#. return code is non-zero, a failure message is printed using d__fail. The 
#. output is titled, by default, 'Command failed', and shows the command that 
#. has failed, along with the current context stack.
#
## The command CMD must be a single command, consisting of any number of WORDs. 
#. Keep in ming that Bash will parse the call to this function before the 
#. arguments are read by the function. As such, here are some examples of what 
#. the CMD can and cannot contain:
#.  * Yes:    Simple commands, including 'test' or '[' or '[['.
#.  * Yes:    Variable expansions, though keep in mind that they will be 
#.            expanded before the actual command is interpreted.
#.  * Yes:    Input redirections.
#.  * Maybe:  Output redirections. (They will affect this function which might 
#.            just do exactly what is needed.)
#.  * NO:     '&&' and '||' (Use d__require).
#.  * NO:     Pipes (Use d__pipe).
#.  * NO:     Negation operator '!' (there is an option to emulate negation).
#.  * NO:     Constructs such as 'if' or 'case'.
#.  * NO:     Arithmetic context.
#
## Options:
#.  ----      - Stop processing d__cmd options and interpret the rest of the 
#.              arguments as the WORDs that constitute the command
#.  --neg--   - Negate the return code of CMD, as if by prepending '!' to it.
#
## Verbosity modes (one active at a time, last option wins)
#.  --v--     - Do not suppress neither stdout nor stderr of CMD.
#.  --q--     - (default) Suppress stderr of CMD.
#.  --qq--    - Suppress both stdout and stderr of CMD.
#
## Options below are relevant only when CMD fails (after optional negation). 
#. All of them modify the output of d__fail.
#
## Semantics of failure:
#.  --opt--         - Make the command optional, i.e., failure messages will be 
#.                    more tame.
#.  --alrt-- ALERT  - This short phrase will override the default title of 
#.                    the output of d__fail.
#.  --crcm-- MSG    - Provided message will be printed to the user by d__fail, 
#.                    along with the current context stack. The message should 
#.                    describe the particular circumstances of the command call 
#.                    that failed.
#.  --else-- MSG    - Provided message will be printed to the user by d__fail, 
#.                    along with the current context stack. The message should 
#.                    describe the consequences of the failure.
#
## Labels (each must preceed the WORD that it applies to):
#.  --<LABEL>--   - Normally d__fail outputs the offending CMD in its entirety, 
#.                  which can be quite long. When a WORD of CMD is preceeded 
#.                  with a label, the label is shown in the failure output 
#.                  instead of the actual WORD. Then, after CMD is printed, 
#.                  each label is also printed on its own line, accompanied by 
#.                  the WORD that it stands for. This is similar to footnotes.
#.  --#<NUM>--    - A previously assigned label may be re-used if the WORD is 
#.                  repeated within the command multiple times. Labels are 
#.                  automatically numbered, starting from zero: use the label 
#.                  number prepended with a hash/pound '#' to reference a 
#.                  previous label. For clarity, make sure that you assign 
#.                  backreferences to WORDs that are actually identical.
#
## Returns:
#.  0 - CMD returned zero (after optional negation).
#.  1 - Otherwise.
#.  2 - Called without arguments.
#
## Prints:
#.  stdout: Whatever the underlying command prints, unless it is silenced.
#.  stderr: Whatever the underlying command prints, unless it is silenced. 
#.          Also, debug and failure messages.
#
d__cmd()
{
  # Pluck out options, round up arguments
  local args=() tmp d__cmd labels=() hunks=() neg=false q=1 opt=false
  while (($#)); do tmp="$1"; shift; case $tmp in
    --*--)  tmp="${tmp:2:${#tmp}-4}"
      case $tmp in
        '')   args+=("$@"); d__cmd+=" $*"; break;;
        neg)  neg=true;;
        v)    q=0;;
        q)    q=1;;
        qq)   q=2;;
        opt)  opt=true;;
        alrt) if (($#)); then local d__alrt; read -r d__alrt <<<"$1"; [ -n "$d__alrt" ] || d__alrt='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        crcm) if (($#)); then local d__crcm; read -r d__crcm <<<"$1"; [ -n "$d__crcm" ] || d__crcm='<empty description>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        else) if (($#)); then local d__rslt; read -r d__rslt <<<"$1"; [ -n "$d__rslt" ] || d__rslt='<empty description>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        \#*)  if (($#)); then tmp="${tmp:1}"
                if [ -z ${labels[$tmp]+isset} ]; then
                  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring backreference that is not yet assigned: '--#$tmp--'"
                else
                  args+=("$1"); d__cmd+=" $BOLD${labels[$tmp]}$NORMAL"; shift
                fi
              else
                printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"
              fi;;
        *)    if (($#)); then
                labels+=("$tmp"); hunks+=("$1")
                args+=("$1"); d__cmd+=" $BOLD$tmp$NORMAL"; shift
              else
                printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"
              fi;;
      esac;;
    *)  args+=("$tmp"); d__cmd+=" $tmp";;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments"; return 2; fi

  # Run command, applying output redirections
  case $q in
    0)  "${args[@]}"; tmp=$?;;
    1)  "${args[@]}" 2>/dev/null; tmp=$?;;
    2)  "${args[@]}" 1>/dev/null 2>&1; tmp=$?;;
  esac

  # Inspect the return code
  if $neg; then [ $tmp -ne 0 ]; else [ $tmp -eq 0 ]; fi
  if [ $? -eq 0 ]; then return 0; else
    if [ -z ${d__alrt+isset} ]; then local d__alrt; $opt && d__alrt='Optional command failed' || d__alrt='Command failed'; fi
    $neg && d__cmd="!$d__cmd" || d__cmd="${d__cmd:1}"; d___fail_from_cmd; return 1
  fi
}

#>  d__require [<options>] [----] CMD...
#
## This function extends d__cmd.
#
## Firstly, it changes semantics a little: while d__cmd is intended to be used 
#. on commands that perform an action that produces side effects, this version 
#. is intended for checks/tests that ensure that certain requirements are met.
#. As such, it sets the title of potential d__fail message to 'Requirement 
#. failed' instead of the default 'Command failed'.
#
## Secondly, this function extends d__cmd by adding the possibility to chain up 
#. to three commands with Bash's '&&' and '||' operators. Note, that the actual 
#. and-or operators cannot be used directly, because they would affect this 
#. function and not get passed down. Instead, the special options are added.
#
## Otherwise, d__require is functionally identical to d__cmd. The intention of 
#. two different functions is to underscore semantics and to lighten up the 
#. load of parsing arguments in d__cmd.
#
## All d__cmd options are fully supported. The option --neg-- applies to 
#. individual commands within the and-or chain; it has to be used for every 
#. negated requirement, at any time before the special option is included, 
#. which starts the next requirement.
#
## This function, being a workhorse for the framework, foregoes argument 
#. validation in some edge cases, to lighten repetitive processing. Usage notes 
#. must be followed closely.
#
## And-or options (only first two occurrences are processed, others ignored):
#.  --and--, --AND--        - Inserts Bash '&&' operator at that location.
#.  --or--, --OR--          - Inserts Bash '||' operator at that location.
#
d__require()
{
  # Pluck out options, round up arguments
  local args0=() args1=() args2=() tmp pcnt= d__cmd=() labels=() hunks=() neg=(false) q=1 ret=() opt=false
  while (($#)); do tmp="$1"; shift; case $tmp in
    --*--)  tmp="${tmp:2:${#tmp}-4}"
      case $tmp in
        '')       case ${#pcnt} in 0) args0+=("$@");; 1) args1+=("$@");; 2) args2+=("$@");; esac
                  d__cmd[${#pcnt}]+=" $*"; break;;
        and|AND)  if ((${#pcnt}<2)); then
                    d__cmd[${#pcnt}]+=" $BOLD&&$NORMAL"; pcnt+=a; neg+=(false)
                  else
                    printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring surplus option: '--$tmp--'"
                  fi;;
        or|OR)    if ((${#pcnt}<2)); then
                    d__cmd[${#pcnt}]+=" $BOLD||$NORMAL"; pcnt+=o; neg+=(false)
                  else
                    printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring surplus option: '--$tmp--'"
                  fi;;
        neg)      neg[${#pcnt}]=true;;
        v)        q=0;;
        q)        q=1;;
        qq)       q=2;;
        opt)      opt=true;;
        alrt)     if (($#)); then local d__alrt; read -r d__alrt <<<"$1"; [ -n "$d__alrt" ] || d__alrt='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        crcm)     if (($#)); then local d__crcm; read -r d__crcm <<<"$1"; [ -n "$d__crcm" ] || d__crcm='<empty description>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        else)     if (($#)); then local d__rslt; read -r d__rslt <<<"$1"; [ -n "$d__rslt" ] || d__rslt='<empty description>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        \#*)      if (($#)); then tmp="${tmp:1}"
                    if [ -z ${labels[$tmp]+isset} ]; then
                      printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring backreference that is not yet assigned: '--#$tmp--'"
                    else
                      case ${#pcnt} in 0) args0+=("$1");; 1) args1+=("$1");; 2) args2+=("$1");; esac
                      d__cmd+=" $BOLD${labels[$tmp]}$NORMAL"; shift
                    fi
                  else
                    printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"
                  fi;;
        *)        if (($#)); then
                    labels+=("$tmp"); hunks+=("$1")
                    case ${#pcnt} in 0) args0+=("$1");; 1) args1+=("$1");; 2) args2+=("$1");; esac
                    d__cmd+=" $BOLD$tmp$NORMAL"; shift
                  else
                    printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"
                  fi;;
      esac;;
    *)  case ${#pcnt} in 0) args0+=("$tmp");; 1) args1+=("$tmp");; 2) args2+=("$tmp");; esac
        d__cmd[${#pcnt}]+=" $tmp";;
  esac; done
  if ! ((${#args0[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments in first requirement"; return 2; fi
  ((${#pcnt}>0)) && if ! ((${#args1[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments in second requirement"; return 2; fi
  ((${#pcnt}>1)) && if ! ((${#args2[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments in third requirement"; return 2; fi

  # Run first command, applying output redirections
  case $q in
    0)  "${args0[@]}"; tmp=$?;;
    1)  "${args0[@]}" 2>/dev/null; tmp=$?;;
    2)  "${args0[@]}" 1>/dev/null 2>&1; tmp=$?;;
  esac
  if ${neg[0]}; then d__cmd[0]="!${d__cmd[0]}"; [ $tmp -ne 0 ]; ret+=($?)
  else d__cmd[0]="${d__cmd[0]:1}"; ret+=($tmp); fi

  # Run second command, applying output redirections
  if ((${#pcnt}>0)); then
    case $q in
      0)  "${args1[@]}"; tmp=$?;;
      1)  "${args1[@]}" 2>/dev/null; tmp=$?;;
      2)  "${args1[@]}" 1>/dev/null 2>&1; tmp=$?;;
    esac
    if ${neg[1]}; then d__cmd[1]="!${d__cmd[1]}"; [ $tmp -ne 0 ]; ret+=($?)
    else d__cmd[1]="${d__cmd[1]:1}"; ret+=($tmp); fi
  fi

  # Run third command, applying output redirections
  if ((${#pcnt}>1)); then
    case $q in
      0)  "${args2[@]}"; tmp=$?;;
      1)  "${args2[@]}" 2>/dev/null; tmp=$?;;
      2)  "${args2[@]}" 1>/dev/null 2>&1; tmp=$?;;
    esac
    if ${neg[2]}; then d__cmd[2]="!${d__cmd[2]}"; [ $tmp -ne 0 ]; ret+=($?)
    else d__cmd[2]="${d__cmd[2]:1}"; ret+=($tmp); fi
  fi

  # Combine return codes with appropriate operators
  case ${#pcnt} in
    0)  [ ${ret[0]} -eq 0 ];;
    1)  case $pcnt in
          a) [ ${ret[0]} -eq 0 ] && [ ${ret[1]} -eq 0 ];;
          o) [ ${ret[0]} -eq 0 ] || [ ${ret[1]} -eq 0 ];;
        esac
        ;;
    2)  case $pcnt in
          aa) [ ${ret[0]} -eq 0 ] && [ ${ret[1]} -eq 0 ] && [ ${ret[2]} -eq 0 ];;
          oo) [ ${ret[0]} -eq 0 ] || [ ${ret[1]} -eq 0 ] || [ ${ret[2]} -eq 0 ];;
          ao) [ ${ret[0]} -eq 0 ] && [ ${ret[1]} -eq 0 ] || [ ${ret[2]} -eq 0 ];;
          oa) [ ${ret[0]} -eq 0 ] || [ ${ret[1]} -eq 0 ] && [ ${ret[2]} -eq 0 ];;
        esac
        ;;
  esac

  # Inspect the combined return code
  if [ $? -eq 0 ]; then return 0; else
    if [ -z ${d__alrt+isset} ]; then local d__alrt; $opt && d__alrt='Optional requirement failed' || d__alrt='Requirement failed'; fi
    d__cmd="${d__cmd[*]}"; d___fail_from_cmd; return 1
  fi
}

#>  d__pipe [<options>] [----] CMD
#
## This function extends d__cmd by adding the possibility to chain up to three 
#. commands in a continuous Bash pipe. Note, that the actual pipe operator '|' 
#. cannot be used directly, because it would affect this function and not get 
#. passed down. Instead, the special pipe option is added.
#
## When this function is used without the special options, d__pipe becomes 
#. functionally identical to d__cmd. The intention of two different functions 
#. is to underscore semantics and to lighten up the load of parsing arguments 
#. in d__cmd.
#
## All d__cmd options are fully supported. If the --qq-- option is used, stdout 
#. is only suppressed for the last command in the queue; otherwise it would 
#. defeat the pipe's purpose.
#
## This function, being a workhorse for the framework, foregoes argument 
#. validation in some edge cases, to lighten repetitive processing. Usage notes 
#. must be followed closely.
#
## Piping options:
#.  --P--, --p--, --pipe--  - Inserts normal Bash pipe '|' at that location. 
#.                            Only first two instances of this option are 
#.                            processed, the rest are ignored.
#.  --ret<NUM>--            - Normally, the return code of the last command in 
#.                            the pipe is inspected to make judgement on 
#.                            whether the whole command ran successfully. 
#.                            Commands in the pipe are numbered starting from 
#.                            zero, left to right. To change which command's 
#.                            return code represents the success of the pipe, 
#.                            its number must be provided with this option.
#
d__pipe()
{
  # Pluck out options, round up arguments
  local args0=() args1=() args2=() tmp pcnt=0 d__cmd labels=() hunks=() neg=false q=1 opt=false
  while (($#)); do tmp="$1"; shift; case $tmp in
    --*--)  tmp="${tmp:2:${#tmp}-4}"
      case $tmp in
        '')         case $pcnt in 0) args0+=("$@");; 1) args1+=("$@");; 2) args2+=("$@");; esac
                    d__cmd+=" $*"; break;;
        P|p|pipe)   if ((pcnt<2)); then
                      ((++pcnt)); d__cmd+=" $BOLD|$NORMAL"
                    else
                      printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring surplus option: '--$tmp--'"
                    fi;;
        ret*)       tmp="${tmp:3}"; case $tmp in 0|1|2) local ret=$tmp;; *) printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring return directive with illegal command number: '--ret$tmp--'";; esac;;
        neg)        neg=true;;
        v)          q=0;;
        q)          q=1;;
        qq)         q=2;;
        opt)        opt=true;;
        alrt)       if (($#)); then local d__alrt; read -r d__alrt <<<"$1"; [ -n "$d__alrt" ] || d__alrt='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        crcm)       if (($#)); then local d__crcm; read -r d__crcm <<<"$1"; [ -n "$d__crcm" ] || d__crcm='<empty description>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        else)       if (($#)); then local d__rslt; read -r d__rslt <<<"$1"; [ -n "$d__rslt" ] || d__rslt='<empty description>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"; fi;;
        \#*)        if (($#)); then tmp="${tmp:1}"
                      if [ -z ${labels[$tmp]+isset} ]; then
                        printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring backreference that is not yet assigned: '--#$tmp--'"
                      else
                        case $pcnt in 0) args0+=("$1");; 1) args1+=("$1");; 2) args2+=("$1");; esac
                        d__cmd+=" $BOLD${labels[$tmp]}$NORMAL"; shift
                      fi
                    else
                      printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"
                    fi;;
        *)          if (($#)); then
                      labels+=("$tmp"); hunks+=("$1")
                      case $pcnt in 0) args0+=("$1");; 1) args1+=("$1");; 2) args2+=("$1");; esac
                      d__cmd+=" $BOLD$tmp$NORMAL"; shift
                    else
                      printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '--$tmp--'"
                    fi;;
      esac;;
    *)  case $pcnt in 0) args0+=("$tmp");; 1) args1+=("$tmp");; 2) args2+=("$tmp");; esac
        d__cmd+=" $tmp";;
  esac; done
  if ! ((${#args0[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments in first command"; return 2; fi
  (($pcnt>0)) && if ! ((${#args1[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments in second command"; return 2; fi
  (($pcnt>1)) && if ! ((${#args2[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" "$FUNCNAME: Refusing to work without arguments in third command"; return 2; fi

  # Launch the pipe
  [ -z ${ret+isset} ] && local ret=$pcnt
  case $pcnt in
    0)  case $q in
          0)  "${args0[@]}"; tmp=$?;;
          1)  "${args0[@]}" 2>/dev/null; tmp=$?;;
          2)  "${args0[@]}" 1>/dev/null 2>&1; tmp=$?;;
        esac
        ;;
    1)  case $q in
          0)  "${args0[@]}" | "${args1[@]}"; tmp=${PIPESTATUS[$ret]}
              ;;
          1)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 2>/dev/null; tmp=${PIPESTATUS[$ret]}
              ;;
          2)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 1>/dev/null 2>&1; tmp=${PIPESTATUS[$ret]}
              ;;
        esac
        ;;
    2)  case $q in
          0)  "${args0[@]}" | "${args1[@]}" | "${args2[@]}"; tmp=${PIPESTATUS[$ret]}
              ;;
          1)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 2>/dev/null | "${args2[@]}" 2>/dev/null; tmp=${PIPESTATUS[$ret]}
              ;;
          2)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 2>/dev/null | "${args2[@]}" 1>/dev/null 2>&1; tmp=${PIPESTATUS[$ret]}
              ;;
        esac
        ;;
  esac

  # Inspect the return code
  if $neg; then [ $tmp -ne 0 ]; else [ $tmp -eq 0 ]; fi
  if [ $? -eq 0 ]; then return 0; else
    if [ -z ${d__alrt+isset} ]; then local d__alrt; $opt && d__alrt='Optional command failed' || d__alrt='Command failed'; fi
    $neg && d__cmd="!$d__cmd" || d__cmd="${d__cmd:1}"; d___fail_from_cmd; return 1
  fi
}

#>  d__fail [-t TITLE] [--] [DESCRIPTION...]
#
## Debug printer: announces a failure of some kind. The output is printed 
#. regardless of the global verbosity setting.
#
## The layout of the output is as follows.
#
##  ==> <TITLE>[: <DESCRIPTION>]
#.      [Context: <CONTEXT>...]
#
##  * TITLE       - Short heading of the failure. Defaults to:
#.                    * 'Failure'               - If the DESCRIPTION is given.
#.                    * 'Something went wrong'  - Otherwise.
#.  * DESCRIPTION - Short elaboration on the failure. May be omitted.
#.  * CONTEXT     - Entire context stack at call time. Omitted if empty.
#
## The output is prepended with a 'fat' ASCII arrow '==>'. The lines of the 
#. output consist of a title and a message, delimited by a colon. If no 
#. DESCRIPTION is given, the first line conststs of the TITLE alone.
#
## If terminal coloring is available:
#.  * Arrow is styled in bold red.
#.  * Titles and some parts of CMD are styled in bold.
#
## Options:
#.  -t TITLE, --title TITLE   - Custom title for the message.
#
## Returns:
#.  0 - Always.
#
## Prints:
#.  stdout: Nothing.
#.  stderr: Debug messages about argument errors and the failure notice itself.
#
d__fail()
{
  # Assemble template and arguments for the eventual call to printf
  local pft='%s' pfa=( "$RED$BOLD==>$NORMAL" ) i

  # Regular call: pluck out options, round up arguments
  local args=() arg opt title; while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)        args+=("$@"); break;;
          t|-title) if (($#)); then read -r title <<<"$1"; [ -n "$title" ] || title='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '$arg'"; fi;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"
                case $opt in
                  t)  if (($#)); then read -r title <<<"$1"; [ -n "$title" ] || title='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '$opt'"; fi;;
                  *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
                esac
              done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Compose the leading line depending on the options
  pft+=' %s'
  if ((${#args[@]})); then
    pft+=': %s\n'
    [ -n "$title" ] && pfa+=("$BOLD$title$NORMAL") || pfa+=("${BOLD}Failure$NORMAL")
    local msg; read -r msg <<<"${args[*]}"; [ -n "$msg" ] && pfa+=("${args[*]}") || pfa+=('<no description>')
  else
    pft+='\n'
    [ -n "$title" ] && pfa+=("$BOLD$title$NORMAL") || pfa+=("${BOLD}Something went wrong$NORMAL")
  fi

  # If context stack has at least one item, print the entire stack
  if ((${#D__CONTEXT[@]})); then
    pft+='    %s: %s\n'; pfa+=( "${BOLD}Context$NORMAL" "${D__CONTEXT[0]}" )
    for ((i=1;i<${#D__CONTEXT[@]};++i)); do
      pft+='             %s\n'; pfa+=("${D__CONTEXT[$i]}")
    done
  fi

  # Add circumstances and consequences, if provided by d__* function
  if ! [ -z ${d__crcm+isset} ]; then
    pft+='    %s: %s\n'; pfa+=( "${BOLD}Circumstances$NORMAL" "$d__crcm" )
  fi
  if ! [ -z ${d__rslt+isset} ]; then
    pft+='    %s: %s\n'; pfa+=( "${BOLD}Result$NORMAL" "$d__rslt" )
  fi

  # Print the output
  printf >&2 "$pft" "${pfa[@]}"
}

#>  d__notify [-clsv] [-t TITLE] [--] [DESCRIPTION...]
#
## Debug printer: announces a development of any kind. Whether the output is 
#. printed depends on the global verbosity setting.
#
## The layout of the output is as follows.
#
##  ==> [<TITLE>: ]<DESCRIPTION> | <TITLE>
#.      [Context: <CONTEXT>...]
#
##  * TITLE       - Short heading of the notification. If the DESCRIPTION is 
#.                  not given, defaults to 'Generic alert'.
#.  * DESCRIPTION - Short elaboration on the failure. Omitted if not given 
#.                  explicitly.
#.  * CONTEXT     - Entire context stack at call time. Omitted if not requested 
#.                  explicitly. Also, omitted if empty.
#
## The output is prepended with a 'fat' ASCII arrow '==>'. The lines of the 
#. output consist of a title and a message, delimited by a colon.
#
## If terminal coloring is available:
#.  * The entire output is painted cyan.
#.  * Titles and some parts of CMD are styled in bold.
#
## If terminal coloring is available, and the --loud option is used:
#.  * Arrow is styled in bold yellow.
#.  * Titles and some parts of CMD are styled in bold.
#
## Options:
#.  -l, --loud                - Announce context switching regardless of the 
#.                              global verbosity setting.
#.  -t TITLE, --title TITLE   - Custom title for the message.
#
## Options for context (one active at a time, last option wins):
#.  -c, --context             - Include in the output the entire workflow 
#.                              context stack.
#.  -h, --context-head        - Include in the output the latest item on the 
#.                              workflow context stack in the output.
#.  --context-<NUM>           - Include in the output NUM latest items on the 
#.                              workflow context stack in the output.
#
## Options for special styling (only relevant with the --loud option):
#.  -v, --success   - Style the notification as a success message by painting 
#.                    the introductory arrow in green.
#.  -s, --skip      - Style the notification as a skip message by painting the 
#.                    introductory arrow in white.
#
## Returns:
#.  0 - Always.
#
## Prints:
#.  stdout: Nothing.
#.  stderr: Debug messages about argument errors and the notification itself.
#
d__notify()
{
  # Assemble template and arguments for the eventual call to printf
  local pft='%s' pfa=() i

  # Regular call: pluck out options, round up arguments
  local args=() arg opt context quiet=true title stl; while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          c)          context=e;;
          h)          context=h;;
          -context*)  case ${arg:9} in '') context=e;; -head) context=h;;
                        -*) arg=$((${arg:10})); if ((${#D__CONTEXT[@]} < $arg)); then
                              printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Too many context items requested: '--context-$arg' (have: ${#D__CONTEXT[@]})"
                            fi; context=$arg;;
                        *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring unrecognized context-related option: '$arg'"
                      esac;;
          l|-loud)    quiet=false;;
          v|-success) stl=v;;
          s|-skip)    stl=s;;
          t|-title)   if (($#)); then read -r title <<<"$1"; [ -n "$title" ] || title='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '$arg'"; fi;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"
                case $opt in
                  c)  context=e;;
                  h)  context=h;;
                  l)  quiet=false;;
                  v)  stl=v;;
                  s)  stl=s;;
                  t)  if (($#)); then read -r title <<<"$1"; [ -n "$title" ] || title='<empty title>'; shift; else printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring option lacking required argument: '$opt'"; fi;;
                  *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
                esac
              done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Settle on quiet call and formatting
  if $quiet; then $D__OPT_QUIET && return 0
    pfa+=("$CYAN==>$NORMAL"); local tp="$CYAN$BOLD" ts="$NORMAL$CYAN"
  else
    case $stl in v) pfa+=("$GREEN$BOLD==>$NORMAL");; s) pfa+=("$WHITE$BOLD==>$NORMAL");; *) pfa+=("$YELLOW$BOLD==>$NORMAL");; esac
    local tp="$BOLD" ts="$NORMAL"
  fi

  # Compose the leading line depending on the options
  if ((${#args[@]})); then
    if [ -n "$title" ]; then pft+=' %s:'; pfa+=("$tp$title"); fi
    pft+=' %s\n'; local msg; read -r msg <<<"${args[*]}"; [ -n "$msg" ] && pfa+=("$ts${args[*]}") || pfa+=("$ts<no description>")
  else
    pft+=' %s\n'; if [ -n "$title" ]; then pfa+=("$tp$title$ts"); else pfa+=("${tp}Generic alert$ts"); fi
  fi

  # If context stack has at least one item, print the entire stack
  if ((${#D__CONTEXT[@]})); then
    case $context in
      '') :;;
      e)  pft+='    %s: %s\n'; pfa+=( "${tp}Context$ts" "${D__CONTEXT[0]}" )
          for ((i=1;i<${#D__CONTEXT[@]};++i)); do
            pft+='             %s\n'; pfa+=("${D__CONTEXT[$i]}")
          done;;
      h)  pft+='    %s: %s\n'; pfa+=( "${tp}Context$ts" "${D__CONTEXT[${#D__CONTEXT[@]}-1]}" );;
      *)  if (($context)); then
            local min=$((${#D__CONTEXT[@]}-$context)); (($min<0)) && min=0
            pft+='    %s: %s\n'; pfa+=( "${tp}Context$ts" "${D__CONTEXT[$min]}" )
            for ((i=$min+1;i<${#D__CONTEXT[@]};++i)); do
              pft+='             %s\n'; pfa+=("${D__CONTEXT[$i]}")
            done
          fi
          ;;
    esac
  fi

  # Print the output
  printf >&2 "$pft%s" "${pfa[@]}" "$NORMAL"
}

#>  d___fail_from_cmd
#
## INTERNAL USE ONLY
#
## This function unifies failure output of functions d__cmd, d__require, and 
#. d__pipe. Whenever one of these functions calls this one, the layout of the 
#. output is as follows.
#
##  ==> <TITLE>: <CMD>
#.          [<LABEL>: '<WORD>']...
#.      [Context: <CONTEXT>...]
#.      [Circumstances: <CRCM>]
#.      [Result: <RSLT>]
#
#.  * TITLE       - The title defaults to, when the command is non-optional:
#.                    * 'Command failed'      - for d__cmd and d__pipe.
#.                    * 'Requirement failed'  - for d__require.
#.                  When the command is optional:
#.                    * 'Optional command failed'     - for d__cmd and d__pipe.
#.                    * 'Optional requirement failed' - for d__require.
#.  * CMD         - The (optional) command that failed.
#.  * LABEL+WORD  - Disambiguation of any labels in CMD, if any are defined.
#.  * CRCM        - Message describing the circumstances of the failure.
#.  * RSLT        - Message describing the consequences of the failure.
#
## Local variables that are transferred into the scope of this function if it 
#. is called from within d__cmd/d__require/d__pipe:
#>  $d__cmd
#>  $d__alrt
#>  $d__rslt
#>  $d__crcm
#>  ${labels[@]}
#>  ${hunks[@]}
#>  $opt
#
## Returns:
#.  0 - Always.
#
d___fail_from_cmd()
{
  # Assemble template and arguments for the eventual call to printf
  local pft='%s' pfa=() i

  # Settle on formatting
  if $opt; then $D__OPT_QUIET && return 0
    pfa+=("$CYAN==>$NORMAL"); local tp="$CYAN$BOLD" ts="$NORMAL$CYAN"
  else
    pfa+=("$RED$BOLD==>$NORMAL"); local tp="$BOLD" ts="$NORMAL"
  fi

  # Compose the leading line
  pft+=' %s: %s\n'; pfa+=( "$tp$d__alrt" "$NORMAL$d__cmd" )
  for ((i=0;i<${#labels[@]};++i)); do
    pft+='        %s: %s\n'; pfa+=( "$tp${labels[$i]}$ts" "'${hunks[$i]}'" )
  done

  # If context stack has at least one item, print the entire stack
  if ((${#D__CONTEXT[@]})); then
    pft+='    %s: %s\n'; pfa+=( "${tp}Context$ts" "${D__CONTEXT[0]}" )
    for ((i=1;i<${#D__CONTEXT[@]};++i)); do
      pft+='             %s\n'; pfa+=("${D__CONTEXT[$i]}")
    done
  fi

  # Add circumstances and consequences, if provided
  if ! [ -z ${d__crcm+isset} ]; then
    pft+='    %s: %s\n'; pfa+=( "${tp}Circumstances$ts" "$d__crcm" )
  fi
  if ! [ -z ${d__rslt+isset} ]; then
    pft+='    %s: %s\n'; pfa+=( "${tp}Result$ts" "$d__rslt" )
  fi

  # Print the output
  printf >&2 "$pft%s" "${pfa[@]}" "$NORMAL"
}


d__declare_global_colors()
{
  # Check if terminal is connected
  if [ -t 1 ]; then

    # Terminal connected: check if tput can be used
    if type -P tput &>/dev/null \
      && tput sgr0 &>/dev/null \
      && [ -n "$( tput colors )" ] \
      && [ "$( tput colors )" -ge 8 ]
    then

      # tput is suitable: use it
      d__colorize_with_tput && return 0 || return 1

    else

      # Unsupported tput, such as on FreeBSD: use escape sequences instead
      d__colorize_with_escseq && return 0 || return 1

    fi

  else

    # Terminal not connected: don’t colorize
    d__do_not_colorize && return 2 || return 1

  fi
}