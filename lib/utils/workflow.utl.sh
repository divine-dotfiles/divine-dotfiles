#!/usr/bin/env bash
#:title:        Divine Bash utils: workflow
#:kind:         func(script)
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Finish implementing three special queues
#:created_at:   2019.09.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Utilities that create a Divine workflow — the preferred way of structuring 
#. code and managing debug output.
#
## Summary of functions in this file:
#>  d__announce [-!dsvx] [--] DESCRIPTION...
#>  d__context [-lnq]... [-t TITLE] [--] push|pop|notch|lop DESCRIPTION...
#>  d__notify [-!1cdhlnqsuvx] [-t TITLE] [--] [DESCRIPTION...]
#>  d__prompt [-!1bchknqsvxy] [-p PROMPT] [-a ANSWER] [-t TITLE] [--] \
#.    [DESCRIPTION...]
#>  d__fail [-n] [-t TITLE] [--] [DESCRIPTION...]
#>  d__cmd [<options>] [----] CMD...
#>  d__require [<options>] [----] CMD...
#>  d__pipe [<options>] [----] CMD
#

#>  d__announce [-!dsvx] [--] DESCRIPTION...
#
## Prints a colorful plaque that serves to announce the outset and completion 
#. of the script execution, with textual description of the routine being run.
#. Parts of DESCRIPTION are merely stitched together with a single space.
#
## Options for semantic styling. These modes are only relevant when the 
#. terminal coloring is available (one active at a time, last option wins):
#.  -d, --debug     - (default) Style the plaque as a debug message by painting 
#.                    it entirely in cyan.
#.  -!, --alert     - Style the plaque as an alert message by painting it 
#.                    entirely in yellow.
#.  -v, --success   - Style the plaque as a success message by painting it 
#.                    entirely in green.
#.  -x, --failure   - Style the plaque as a failure message by painting it 
#.                    entirely in red.
#.  -s, --skip      - Style the plaque as a skip message by painting it 
#.                    entirely in white.
#
## Returns:
#.  0 - Always
#
d__announce()
{
  # Pluck out options, round up arguments
  local args=() arg opt clr="$BLACK$BG_CYAN"
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          d|-debug)   clr="$BLACK$BG_CYAN";;
          \!|-alert)  clr="$BLACK$BG_YELLOW";;
          v|-success) clr="$BLACK$BG_GREEN";;
          x|-failure) clr="$BLACK$BG_RED";;
          s|-skip)    clr="$BLACK$BG_WHITE";;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                d)  clr="$BLACK$BG_CYAN";;
                \!) clr="$BLACK$BG_YELLOW";;
                v)  clr="$BLACK$BG_GREEN";;
                x)  clr="$BLACK$BG_RED";;
                s)  clr="$BLACK$BG_WHITE";;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done
  # Just print the damn thing
  printf >&2 '%s %s %s\n' \
    "$clr$BOLD D.d >$NORMAL$clr" "${args[*]}" "$BOLD> $NORMAL"
}

#>  d__context [-lnq]... [-t TITLE] [--] push|pop|notch|lop DESCRIPTION...
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
#. from below, respectively. The 'notch' operation places an invisible mark 
#. at the tip of the stack; the subsequent 'lop' operation repeatedly executes 
#. a 'pop' until the next notch is reached, and then removes that notch. Any 
#. number of notches can be made, as long as they are not duplicated (at the 
#. same position). If no notches are left, the root of the stack is the limit.
#
## In the context of the context stack, the latest pushed item is called the 
#. *tip*, and the items pushed after the latest notch are called the *head*.
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
##  * TITLE       - Short heading of the message.
#.  * DESCRIPTION - Text of the pushed/popped context item.
#
## The output is prepended with a 'fat' ASCII arrow '==>'.
#
## If terminal coloring is available:
#.  * The entire output is painted cyan.
#.  * The title is styled in bold.
#
## If terminal coloring is available, and any of the alternative semantic 
#. styling options is used:
#.  * The arrow is styled in bold color (color depends on the option).
#.  * Other parts use the normal terminal color.
#.  * The title is styled in bold.
#
## Uses in global scope:
#>  $D__CONTEXT         - Global storage for the Divine workflow context stack.
#>  $D__CONTEXT_NOTCHES - Global storage for the notches made on the context 
#.                        stack.
#>  $D__OPT_VERBOSITY   - Global verbosity setting.
#
## Options:
#.  -t TITLE, --title TITLE   - Custom title for the leading line. Defaults to:
#.                                * 'Start'   - During 'push' routine.
#.                                * 'End'     - During 'pop' routine.
#.  -n, --newline             - With this option, if this function produces any 
#.                              output, an extra newline is printed before any 
#.                              other output.
#
## Options for semantic styling. These modes are only relevant when the 
#. terminal coloring is available (one active at a time, last option wins):
#.  -d, --debug     - (default) Style the output as a debug message by painting 
#.                    it entirely in cyan.
#.  -!, --alert     - Style the output as an alert message by painting the 
#.                    introductory arrow in yellow.
#.  -v, --success   - Style the output as a success message by painting the 
#.                    introductory arrow in green.
#.  -x, --failure   - Style the output as a failure message by painting the 
#.                    introductory arrow in red.
#.  -s, --skip      - Style the output as a skip message by painting the 
#.                    introductory arrow in white.
#
## Quiet options:
#.  -q, --quiet               - (repeatable) Increments the quiet level by one.
#.  -l, --loud                - Sets the quiet level to zero.
#
## Quiet options designate the quiet level for the current call. Changes to 
#. context are announced only if the value in $D__OPT_VERBOSITY is equal to or 
#. greater than the quiet level.
#
## Quiet options are read sequentially, left-to-right, and the quiet level 
#. starts at zero. However, if these options are not given at all, the default 
#. quiet levels per operation are:
#.    * 'push'  - 1
#.    * 'pop'   - 2
#.    * 'notch' - 3
#.    * 'lop'   - 3 (This includes the underlying pops! If you want to pop at a 
#.                different quiet level, you have to pop manually)
#
## Parameters:
#.  $1  - Name of the routine to run:
#.          * push  - Add one item at the bottom of the stack.
#.          * pop   - Remove one item at the bottom of the stack.
#.          * notch - Place a notch at the bottom of the stack.
#.          * lop   - Repeatedly pop until the next notch is reached, then 
#.                    remove that notch.
#.  $*  - Human-readable description of the stack item. During the 'pop' 
#.        routine it overrides the printed description of the popped item.
#.        Together, the arguments should form no more than one sentence, and 
#.        the full stop should be omitted.
#
## Returns:
#.  0 - Modified the stack as requested.
#.  1 - Stack not modified: no arguments or unrecognized routine name.
#.  2 - Stack not modified: pushing without a DESCRIPTION.
#.  3 - Stack not modified: popping from an empty stack.
#.  4 - Stack not modified: notching at the same position.
#
## Prints:
#.  stdout: Nothing.
#.  stderr: Debug messages about argument errors and context modifications.
#
d__context()
{
  # Pluck out options, round up arguments
  local args=() arg opt qt=n nl=false stl ttl i
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          q|-quiet)   ((++qt));;
          l|-loud)    qt=0;;
          d|-debug)   stl=d;;
          \!|-alert)  stl=a;;
          v|-success) stl=v;;
          x|-failure) stl=x;;
          s|-skip)    stl=s;;
          t|-title)   if (($#)); then ttl="$1"; shift; fi;;
          n|-newline) nl=true;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                q)  ((++qt));;
                l)  qt=0;;
                d)  stl=d;;
                \!) stl=a;;
                v)  stl=v;;
                x)  stl=x;;
                s)  stl=s;;
                t)  if (($#)); then ttl="$1"; shift; fi;;
                n)  nl=true;;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Fork based on operation
  case ${args[0]} in
    push)   d___context_push "${args[@]:1}";;
    pop)    d___context_pop "${args[@]:1}";;
    notch)  d___context_notch "${args[@]:1}";;
    lop)    d___context_lop "${args[@]:1}";;
    *)  printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
          "$FUNCNAME: Refusing to work with unrecognized command: '${args[0]}'"
        return 1;;
  esac

  # Return the last code
  return $?
}

#>  d___context_push DESCRIPTION
#
## INTERNAL USE ONLY
#
d___context_push()
{
  # Ensure there is a description and push it
  if ! (($#)); then printf >&2 '%s %s%s\n' \
    "$RED$BOLD==>$NORMAL" "$FUNCNAME: Attempted to push an item" \
    " without a description onto the context stack"
    return 2
  fi
  local msg="$*"; D__CONTEXT+=("$msg")

  # Cut-off for non-printing calls
  [ $qt = n ] && qt=2; (($D__OPT_VERBOSITY<$qt)) && return 0

  # Start assembling output and settle on formatting
  local pft= pfa=() tp="$BOLD" ts="$NORMAL"
  $nl && pft+='\n'; pft+='%s %s: %s\n'
  case $stl in a) pfa+=("$YELLOW$BOLD==>$NORMAL");;
    v) pfa+=("$GREEN$BOLD==>$NORMAL");; x) pfa+=("$RED$BOLD==>$NORMAL");;
    s) pfa+=("$WHITE$BOLD==>$NORMAL");;
    *) tp="$CYAN$BOLD" ts="$NORMAL$CYAN" pfa+=("$CYAN==>");;
  esac

  # Add title and message, then print and return
  [ -n "$ttl" ] || ttl='Start'; pfa+=( "$tp$ttl$ts" "$msg$NORMAL" )
  printf "$pft" "${pfa[@]}"
}

#>  d___context_pop DESCRIPTION
#
## INTERNAL USE ONLY
#
d___context_pop()
{
  # Calculate the tip of the stack, check it
  local level=$((${#D__CONTEXT[@]}-1))
  if (($level<0)); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Attempted to pop from the empty context stack"
    return 3
  fi
  
  # Extract the description, then unset the tip
  local msg; if (($#)); then msg="$*"; else msg="${D__CONTEXT[$level]}"; fi
  unset D__CONTEXT[$level]

  # Cut-off for non-printing calls
  [ $qt = n ] && qt=3; (($D__OPT_VERBOSITY<$qt)) && return 0

  # Start assembling output and settle on formatting
  local pft= pfa=() tp="$BOLD" ts="$NORMAL"
  $nl && pft+='\n'; pft+='%s %s: %s\n'
  case $stl in a) pfa+=("$YELLOW$BOLD==>$NORMAL");;
    v) pfa+=("$GREEN$BOLD==>$NORMAL");; x) pfa+=("$RED$BOLD==>$NORMAL");;
    s) pfa+=("$WHITE$BOLD==>$NORMAL");;
    *) tp="$CYAN$BOLD" ts="$NORMAL$CYAN" pfa+=("$CYAN==>");;
  esac

  # Add title and message, then print and return
  [ -n "$ttl" ] || ttl='End'; pfa+=( "$tp$ttl$ts" "$msg$NORMAL" )
  printf "$pft" "${pfa[@]}"
}

#>  d___context_notch DESCRIPTION
#
## INTERNAL USE ONLY
#
d___context_notch()
{
  # Check for possibly duplicate notch, then add it
  if ((${#D__CONTEXT_NOTCHES[@]})) \
    && [ ${D__CONTEXT_NOTCHES[${#D__CONTEXT_NOTCHES[@]}-1]} \
    -eq ${#D__CONTEXT[@]} ]
  then printf >&2 '%s %s%s\n' "$RED$BOLD==>$NORMAL" \
      "$FUNCNAME: Attempted to make a duplicate notch" \
      " on the context stack"; return 4
  fi
  D__CONTEXT_NOTCHES+=("${#D__CONTEXT[@]}")

  # Cut-off for non-printing calls
  [ $qt = n ] && qt=4; (($D__OPT_VERBOSITY<$qt)) && return 0

  # Start assembling output and settle on formatting
  local pft= pfa=() tp="$BOLD" ts="$NORMAL"
  $nl && pft+='\n'; pft+='%s %s: %s\n'
  case $stl in a) pfa+=("$YELLOW$BOLD==>$NORMAL");;
    v) pfa+=("$GREEN$BOLD==>$NORMAL");; x) pfa+=("$RED$BOLD==>$NORMAL");;
    s) pfa+=("$WHITE$BOLD==>$NORMAL");;
    *) tp="$CYAN$BOLD" ts="$NORMAL$CYAN" pfa+=("$CYAN==>");;
  esac

  # Add title and message, then print and return
  [ -n "$ttl" ] || ttl='Notched'; local msg; if (($#)); then msg="$*"
  else msg="At position ${#D__CONTEXT[@]}"; fi
  pfa+=( "$tp$ttl$ts" "$msg$NORMAL" )
  printf "$pft" "${pfa[@]}"
}

#>  d___context_lop DESCRIPTION
#
## INTERNAL USE ONLY
#
d___context_lop()
{
  # Calculate the range of stack items to be popped
  local min num=${#D__CONTEXT_NOTCHES[@]} level msg
  if (($num)); then ((--num)); min=${D__CONTEXT_NOTCHES[$num]}
  else num=; min=0; fi

  # Calculate whether the pop messages are to be printed
  [ $qt = n ] && qt=4; if (($D__OPT_VERBOSITY<$qt)); then qt=true; else

    # Start assembling output and settle on formatting
    local pft= pfa=() tp="$BOLD" ts="$NORMAL" arrow
    $nl && pft+='\n'; qt=false
    case $stl in a) arrow="$YELLOW$BOLD==>$NORMAL";;
      v) arrow="$GREEN$BOLD==>$NORMAL";; x) arrow="$RED$BOLD==>$NORMAL";;
      s) arrow="$WHITE$BOLD==>$NORMAL";;
      *) tp="$CYAN$BOLD" ts="$NORMAL$CYAN" arrow="$CYAN==>";;
    esac

  fi

  # Pop items one by one
  for ((level=${#D__CONTEXT[@]}-1;level>=$min;--level)); do
    msg="${D__CONTEXT[$level]}"; unset D__CONTEXT[$level]; $qt && continue
    pft+='%s %s: %s\n' pfa+=( "$arrow" "${tp}End$ts" "$msg" )
  done
  
  # Unset the notch; then cut-off for non-printing calls
  [ -n "$num" ] && unset D__CONTEXT_NOTCHES[$num]; $qt && return 0

  # Add title and message, then print and return
  if [ -n "$num" ]; then [ -n "$ttl" ] || ttl='De-notched'
    local msg; if (($#)); then msg="$*"; else msg="At position $min"; fi
    pft+='%s %s: %s\n' pfa+=( "$arrow" "$tp$ttl$ts" "$msg" )
  fi
  [ -n "$pft" ] && printf "$pft%s" "${pfa[@]}" "$NORMAL"
}

#>  d__cmd [<options>] [----] CMD...
#
## Wrapper around almost any single Bash command. When d__cmd is prepended to 
#. CMD, CMD is executed as normal, then its return code is inspected. If the 
#. return code is non-zero, a failure message is printed using d__fail, and the 
#. head is lopped from the current workflow context stack. The output is 
#. titled, by default, 'Command failed', and shows the command that has 
#. failed, along with the current context stack.
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
## Output suppression modes (one active at a time, last option wins):
#.  --sn--    - Do not suppress neither stdout nor stderr of the command.
#.  --so--    - Suppress stdout of the command.
#.  --se--    - (default) Suppress stderr of the command.
#.  --sb--    - Suppress both stdout and stderr of the command.
#
## Quiet options:
#.  --q--     - (repeatable) Increments the quiet level by one. This particular 
#.              option can be repeated within the hyphens, e.g., '--qqq--'. Be 
#.              aware, that only the first character is checked to be 'q', the 
#.              others are simply counted.
#.  --l--     - Sets the quiet level to zero.
#
## Quiet options designate the quiet level for the current call. Whatever 
#. output is produced by the underlying command is printed only if the value in 
#. $D__OPT_VERBOSITY is equal to or greater than the quiet level.
#
## Quiet options are read sequentially, left-to-right, and the quiet level 
#. starts at zero. If these options are not given at all, the default quiet 
#. level is also zero.
#
## Normally, the quiet level does not affect the failure output.
#
## Options below are relevant only when CMD fails (after optional negation). 
#. All of them modify the output of d__fail.
#
## Semantics of failure:
#.  --opt--         - Make the command optional: if there is a failure, the 
#.                    head of the context stacked will not be lopped and the 
#.                    failure messages will be styled less urgently.
#.                    When a command is marked optional, its failure output is 
#.                    printed depending on the quiet level.
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
  local args=() tmp d__cmd labels=() hunks=() neg=false qt=0 sup=e opt=false
  while (($#)); do tmp="$1"; shift; case $tmp in
    --*--)  tmp="${tmp:2:${#tmp}-4}"
      case $tmp in
        '')   args+=("$@"); d__cmd+=" $*"; break;;
        neg)  neg=true;;
        sn)   sup=n;;
        so)   sup=o;;
        se)   sup=e;;
        sb)   sup=b;;
        q*)   ((qt+=${#tmp}));;
        l)    qt=0;;
        opt)  opt=true;;
        alrt) if (($#)); then local d__alrt; d__alrt="$1"; shift; fi;;
        crcm) if (($#)); then local d__crcm; d__crcm="$1"; shift; fi;;
        else) if (($#)); then local d__rslt; d__rslt="$1"; shift; fi;;
        \#*)  if (($#)); then tmp="${tmp:1}"
                if [ -z ${labels[$tmp]+isset} ]; then
                  printf >&2 '%s %s%s\n' "$YELLOW$BOLD==>$NORMAL" \
                    "$FUNCNAME: Ignoring backreference that is not yet" \
                    " assigned: '--#$tmp--'"
                else
                  args+=("$1"); d__cmd+=" $BOLD${labels[$tmp]}$NORMAL"; shift
                fi
              fi;;
        *)    if (($#)); then
                labels+=("$tmp"); hunks+=("$1")
                args+=("$1"); d__cmd+=" $BOLD$tmp$NORMAL"; shift
              fi;;
      esac;;
    *)  args+=("$tmp"); d__cmd+=" $tmp";;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments"; return 2; fi

  # Run command, applying output redirections
  (($D__OPT_VERBOSITY<$qt)) && sup=b
  case $sup in
    n)  "${args[@]}"; tmp=$?;;
    o)  "${args[@]}" 1>/dev/null; tmp=$?;;
    e)  "${args[@]}" 2>/dev/null; tmp=$?;;
    b)  "${args[@]}" 1>/dev/null 2>&1; tmp=$?;;
  esac

  # Inspect the return code
  if $neg; then [ $tmp -ne 0 ]; else [ $tmp -eq 0 ]; fi
  if [ $? -eq 0 ]; then return 0; else
    if [ -z ${d__alrt+isset} ]; then local d__alrt
      $opt && d__alrt='Optional command failed' || d__alrt='Command failed'; fi
    $neg && d__cmd="!$d__cmd" || d__cmd="${d__cmd:1}"
    d___fail_from_cmd; return 1
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
## And-or options (only first two occurrences are processed, others ignored):
#.  --and--, --AND--        - Inserts Bash '&&' operator at that location.
#.  --or--, --OR--          - Inserts Bash '||' operator at that location.
#
d__require()
{
  # Pluck out options, round up arguments
  local args0=() args1=() args2=() tmp pcnt= d__cmd=() labels=() hunks=()
  local neg=(false) qt=0 sup=e ret=() opt=false
  while (($#)); do tmp="$1"; shift; case $tmp in
    --*--)  tmp="${tmp:2:${#tmp}-4}"
      case $tmp in
        '')       case ${#pcnt} in 0) args0+=("$@");; 1) args1+=("$@");;
                    2) args2+=("$@");; esac
                  d__cmd[${#pcnt}]+=" $*"; break;;
        and|AND)  if ((${#pcnt}<2)); then
                    d__cmd[${#pcnt}]+=" $BOLD&&$NORMAL"; pcnt+=a; neg+=(false)
                  fi;;
        or|OR)    if ((${#pcnt}<2)); then
                    d__cmd[${#pcnt}]+=" $BOLD||$NORMAL"; pcnt+=o; neg+=(false)
                  fi;;
        neg)      neg[${#pcnt}]=true;;
        sn)       sup=n;;
        so)       sup=o;;
        se)       sup=e;;
        sb)       sup=b;;
        q*)       ((qt+=${#tmp}));;
        l)        qt=0;;
        opt)      opt=true;;
        alrt)     if (($#)); then local d__alrt; d__alrt="$1"; shift; fi;;
        crcm)     if (($#)); then local d__crcm; d__crcm="$1"; shift; fi;;
        else)     if (($#)); then local d__rslt; d__rslt="$1"; shift; fi;;
        \#*)      if (($#)); then tmp="${tmp:1}"
                    if [ -z ${labels[$tmp]+isset} ]; then
                      printf >&2 '%s %s%s\n' "$YELLOW$BOLD==>$NORMAL" \
                        "$FUNCNAME: Ignoring backreference that is not yet" \
                        " assigned: '--#$tmp--'"
                    else
                      case ${#pcnt} in 0) args0+=("$1");; 1) args1+=("$1");;
                        2) args2+=("$1");; esac
                      d__cmd+=" $BOLD${labels[$tmp]}$NORMAL"; shift
                    fi
                  fi;;
        *)        if (($#)); then
                    labels+=("$tmp"); hunks+=("$1")
                    case ${#pcnt} in 0) args0+=("$1");; 1) args1+=("$1");;
                      2) args2+=("$1");; esac
                    d__cmd+=" $BOLD$tmp$NORMAL"; shift
                  fi;;
      esac;;
    *)  case ${#pcnt} in 0) args0+=("$tmp");; 1) args1+=("$tmp");;
          2) args2+=("$tmp");; esac
        d__cmd[${#pcnt}]+=" $tmp";;
  esac; done
  if ! ((${#args0[@]})); then printf >&2 '%s %s\n' \
    "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments in first requirement"
    return 2
  fi
  if ((${#pcnt}>0)) && ! ((${#args1[@]})); then printf >&2 '%s %s\n' \
    "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments in second requirement"
    return 2
  fi
  if ((${#pcnt}>1)) && ! ((${#args2[@]})); then printf >&2 '%s %s\n' \
    "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments in third requirement"
    return 2
  fi

  # Run first command, applying output redirections
  (($D__OPT_VERBOSITY<$qt)) && sup=b
  case $sup in
    n)  "${args0[@]}"; tmp=$?;;
    o)  "${args0[@]}" 1>/dev/null; tmp=$?;;
    e)  "${args0[@]}" 2>/dev/null; tmp=$?;;
    b)  "${args0[@]}" 1>/dev/null 2>&1; tmp=$?;;
  esac
  if ${neg[0]}; then d__cmd[0]="!${d__cmd[0]}"; [ $tmp -ne 0 ]; ret+=($?)
  else d__cmd[0]="${d__cmd[0]:1}"; ret+=($tmp); fi

  # Run second command, applying output redirections
  if ((${#pcnt}>0)); then
    case $sup in
      n)  "${args1[@]}"; tmp=$?;;
      o)  "${args1[@]}" 1>/dev/null; tmp=$?;;
      e)  "${args1[@]}" 2>/dev/null; tmp=$?;;
      b)  "${args1[@]}" 1>/dev/null 2>&1; tmp=$?;;
    esac
    if ${neg[1]}; then d__cmd[1]="!${d__cmd[1]}"; [ $tmp -ne 0 ]; ret+=($?)
    else d__cmd[1]="${d__cmd[1]:1}"; ret+=($tmp); fi
  fi

  # Run third command, applying output redirections
  if ((${#pcnt}>1)); then
    case $sup in
      n)  "${args2[@]}"; tmp=$?;;
      o)  "${args2[@]}" 1>/dev/null; tmp=$?;;
      e)  "${args2[@]}" 2>/dev/null; tmp=$?;;
      b)  "${args2[@]}" 1>/dev/null 2>&1; tmp=$?;;
    esac
    if ${neg[2]}; then d__cmd[2]="!${d__cmd[2]}"; [ $tmp -ne 0 ]; ret+=($?)
    else d__cmd[2]="${d__cmd[2]:1}"; ret+=($tmp); fi
  fi

  # Combine return codes with appropriate operators
  case ${#pcnt} in
    0)  [ ${ret[0]} -eq 0 ];;
    1)  case $pcnt in
          a) [ ${ret[0]} -eq 0 -a ${ret[1]} -eq 0 ];;
          o) [ ${ret[0]} -eq 0 -o ${ret[1]} -eq 0 ];;
        esac
        ;;
    2)  case $pcnt in
          aa) [ ${ret[0]} -eq 0 -a ${ret[1]} -eq 0 -a ${ret[2]} -eq 0 ];;
          oo) [ ${ret[0]} -eq 0 -o ${ret[1]} -eq 0 -o ${ret[2]} -eq 0 ];;
          ao) [ ${ret[0]} -eq 0 -a ${ret[1]} -eq 0 -o ${ret[2]} -eq 0 ];;
          oa) [ ${ret[0]} -eq 0 -o ${ret[1]} -eq 0 -a ${ret[2]} -eq 0 ];;
        esac
        ;;
  esac

  # Inspect the combined return code
  if [ $? -eq 0 ]; then return 0; else
    if [ -z ${d__alrt+isset} ]; then local d__alrt
      $opt && d__alrt='Optional requirement failed' \
        || d__alrt='Requirement failed'
    fi
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
## All d__cmd options are fully supported. If the --so-- or the --sb-- option 
#. is used, stdout is only suppressed for the last command in the queue; 
#. otherwise it would defeat the pipe's purpose.
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
  local args0=() args1=() args2=() tmp pcnt=0 d__cmd labels=() hunks=()
  local neg=false qt=0 sup=e opt=false
  while (($#)); do tmp="$1"; shift; case $tmp in
    --*--)  tmp="${tmp:2:${#tmp}-4}"
      case $tmp in
        '')         case $pcnt in 0) args0+=("$@");; 1) args1+=("$@");;
                      2) args2+=("$@");; esac
                    d__cmd+=" $*"; break;;
        P|p|pipe)   if ((pcnt<2)); then
                      ((++pcnt)); d__cmd+=" $BOLD|$NORMAL"
                    fi;;
        ret*)       tmp="${tmp:3}"; case $tmp in 0|1|2) local ret=$tmp;;
                      *)  printf >&2 '%s %s%s\n' "$YELLOW$BOLD==>$NORMAL" \
                            "$FUNCNAME: Ignoring return directive with" \
                            " illegal command number: '--ret$tmp--'";;
                    esac;;
        neg)        neg=true;;
        sn)         sup=n;;
        so)         sup=o;;
        se)         sup=e;;
        sb)         sup=b;;
        q*)         ((qt+=${#tmp}));;
        l)          qt=0;;
        opt)        opt=true;;
        alrt)       if (($#)); then local d__alrt; d__alrt="$1"; shift; fi;;
        crcm)       if (($#)); then local d__crcm; d__crcm="$1"; shift; fi;;
        else)       if (($#)); then local d__rslt; d__rslt="$1"; shift; fi;;
        \#*)        if (($#)); then tmp="${tmp:1}"
                      if [ -z ${labels[$tmp]+isset} ]; then
                        printf >&2 '%s %s%s\n' "$YELLOW$BOLD==>$NORMAL" \
                          "$FUNCNAME: Ignoring backreference that is not yet" \
                          " assigned: '--#$tmp--'"
                      else
                        case $pcnt in 0) args0+=("$1");; 1) args1+=("$1");;
                          2) args2+=("$1");; esac
                        d__cmd+=" $BOLD${labels[$tmp]}$NORMAL"; shift
                      fi
                    fi;;
        *)          if (($#)); then
                      labels+=("$tmp"); hunks+=("$1")
                      case $pcnt in 0) args0+=("$1");; 1) args1+=("$1");;
                        2) args2+=("$1");; esac
                      d__cmd+=" $BOLD$tmp$NORMAL"; shift
                    fi;;
      esac;;
    *)  case $pcnt in 0) args0+=("$tmp");; 1) args1+=("$tmp");;
          2) args2+=("$tmp");; esac
        d__cmd+=" $tmp";;
  esac; done
  if ! ((${#args0[@]})); then printf >&2 '%s %s\n' \
    "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments in first command"
    return 2
  fi
  if (($pcnt>0)) && ! ((${#args1[@]})); then printf >&2 '%s %s\n' \
    "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments in second command"
    return 2
  fi
  if (($pcnt>1)) && ! ((${#args2[@]})); then printf >&2 '%s %s\n' \
    "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments in third command"
    return 2
  fi

  # Launch the pipe
  (($D__OPT_VERBOSITY<$qt)) && sup=b
  [ -z ${ret+isset} ] && local ret=$pcnt
  case $pcnt in
    0)  case $sup in
          n)  "${args0[@]}"; tmp=$?;;
          o)  "${args0[@]}" 1>/dev/null; tmp=$?;;
          e)  "${args0[@]}" 2>/dev/null; tmp=$?;;
          b)  "${args0[@]}" 1>/dev/null 2>&1; tmp=$?;;
        esac
        ;;
    1)  case $sup in
          n)  "${args0[@]}" | "${args1[@]}"; tmp=${PIPESTATUS[$ret]}
              ;;
          o)  "${args0[@]}" | "${args1[@]}" 1>/dev/null
              tmp=${PIPESTATUS[$ret]}
              ;;
          e)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 2>/dev/null
              tmp=${PIPESTATUS[$ret]}
              ;;
          b)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 1>/dev/null 2>&1
              tmp=${PIPESTATUS[$ret]}
              ;;
        esac
        ;;
    2)  case $sup in
          n)  "${args0[@]}" | "${args1[@]}" | "${args2[@]}"
              tmp=${PIPESTATUS[$ret]}
              ;;
          o)  "${args0[@]}" | "${args1[@]}" | "${args2[@]}" 1>/dev/null
              tmp=${PIPESTATUS[$ret]}
              ;;
          e)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 2>/dev/null \
                | "${args2[@]}" 2>/dev/null; tmp=${PIPESTATUS[$ret]}
              ;;
          b)  "${args0[@]}" 2>/dev/null | "${args1[@]}" 2>/dev/null \
                | "${args2[@]}" 1>/dev/null 2>&1; tmp=${PIPESTATUS[$ret]}
              ;;
        esac
        ;;
  esac

  # Inspect the return code
  if $neg; then [ $tmp -ne 0 ]; else [ $tmp -eq 0 ]; fi
  if [ $? -eq 0 ]; then return 0; else
    if [ -z ${d__alrt+isset} ]; then local d__alrt
      $opt && d__alrt='Optional command failed' || d__alrt='Command failed'
    fi
    $neg && d__cmd="!$d__cmd" || d__cmd="${d__cmd:1}"
    d___fail_from_cmd; return 1
  fi
}

#>  d__fail [-n] [-t TITLE] [--] [DESCRIPTION...]
#
## Debug printer: announces a failure of some kind. The output is printed 
#. regardless of the global verbosity setting. Invariably lops the head of the 
#. current workflow context stack.
#
## The layout of the output is as follows.
#
##  ==> <TITLE>[: <DESCRIPTION>]
#.      [Context: <CONTEXT>...]
#
##  * TITLE       - Short heading of the failure.
#.  * DESCRIPTION - Short elaboration on the failure. May be omitted.
#.  * CONTEXT     - Head of the context stack. Omitted if empty.
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
#.  -t TITLE, --title TITLE   - Custom title for the leading line. Defaults to:
#.                                * 'Failure' - If the DESCRIPTION is given.
#.                                * 'Something went wrong' - Otherwise.
#.  -n, --newline             - With this option, if this function produces any 
#.                              output, an extra newline is printed before any 
#.                              other output.
#
## Special formatting para-options (para-options work only after the option-
#. argument separator '--'):
#.  -t-   - This para-option treats the next WORD in the DESCRIPTION as a 
#.          title. That WORD is then styled as a title and is followed by a 
#.          colon.
#.  -n-   - This para-option inserts a newline followed by the arrow-width 
#.          indentation (four spaces).
#.  -i-   - This para-option is similar to the '-n-' para-option, but the 
#.          indentation is doubled.
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
  # Pluck out options, round up arguments
  local args=() arg opt ttl nl=false i
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          n|-newline) nl=true;;
          t|-title)   if (($#)); then ttl="$1"; shift; fi;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                n)  nl=true;;
                t)  if (($#)); then ttl="$1"; shift; fi;;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Assemble template and arguments for the eventual call to printf
  local pft= pfa=( "$RED$BOLD==>$NORMAL" ); $nl && pft+='\n'; pft+='%s'

  # Compose the leading line depending on the options
  if ((${#args[@]})); then set -- "${args[@]}"
    pft+=' %s:'; if [ -n "$ttl" ]; then pfa+=("$BOLD$ttl$NORMAL")
    else pfa+=("${BOLD}Failure$NORMAL"); fi
    while (($#)); do case $1 in
      -n-)  pft+='\n   ';;
      -i-)  pft+='\n       ';;
      -t-)  shift; (($#)) || continue; pft+=' %s:' pfa+=("$BOLD$1$NORMAL");;
      *)    pft+=' %s' pfa+=("$1")
    esac; shift; done; pft+='\n'
  else
    pft+=' %s\n'; if [ -n "$ttl" ]; then pfa+=("$BOLD$ttl$NORMAL")
    else pfa+=("${BOLD}Something went wrong$NORMAL"); fi
  fi

  # Print the head of the stack
  local tmp=${#D__CONTEXT_NOTCHES[@]}; (($tmp)) \
    && tmp=$((${D__CONTEXT_NOTCHES[$tmp-1]})) || tmp=0
  if ((${#D__CONTEXT[@]} > $tmp)); then
    pft+='    %s: %s\n' pfa+=( "${BOLD}Context$NORMAL" "${D__CONTEXT[$tmp]}" )
    for ((i=$tmp+1;i<${#D__CONTEXT[@]};++i)); do
      pft+='             %s\n' pfa+=("${D__CONTEXT[$i]}")
    done
  fi

  # Print the output
  printf >&2 "$pft" "${pfa[@]}"

  # Lop the head of the context stack
  d__context -- lop
}

#>  d__notify [-!1cdhlnqsuvx] [-t TITLE] [--] [DESCRIPTION...]
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
#.  * DESCRIPTION - Short elaboration on the notification. Omitted if not given 
#.                  explicitly.
#.  * CONTEXT     - Some part of the context stack, depending on the given 
#.                  options. Omitted if the context is not requested 
#.                  explicitly. Also, omitted if the context stack empty.
#
## The output is prepended with a 'fat' ASCII arrow '==>'. The lines of the 
#. output consist of a title and a message, delimited by a colon.
#
## If terminal coloring is available:
#.  * The entire output is painted cyan.
#.  * Titles are styled in bold.
#
## If terminal coloring is available, and any of the alternative semantic 
#. styling options is used:
#.  * Arrow is styled in bold color (depending on the particular option).
#.  * Other parts use the normal terminal color.
#.  * Titles are styled in bold.
#
## Options:
#.  -u, --sudo                - Print the notification only if the caller lacks 
#.                              the sudo privelege. Automatically makes the 
#.                              notification `--loud`.
#.  -t TITLE, --title TITLE   - Custom title for the leading line.
#.  -n, --newline             - With this option, if this function produces any 
#.                              output, an extra newline is printed before any 
#.                              other output.
#
## Options for context (one active at a time, last option wins):
#.  -c, --context-all         - Include in the output the entire workflow 
#.                              context stack.
#.  -h, --context-head        - Include in the output the items on the workflow 
#.                              context stack that have been pushed since the 
#.                              latest notch in the output.
#.  -1, --context-tip         - Include in the output the latest item on the 
#.                              workflow context stack in the output.
#
## Options for semantic styling. These modes are only relevant when the 
#. terminal coloring is available (one active at a time, last option wins):
#.  -d, --debug     - (default) Style the notification as a debug message by 
#.                    painting it entirely in cyan.
#.  -!, --alert     - Style the notification as an alert message by painting 
#.                    the introductory arrow in yellow.
#.  -v, --success   - Style the notification as a success message by painting 
#.                    the introductory arrow in green.
#.  -x, --failure   - Style the notification as a failure message by painting 
#.                    the introductory arrow in red.
#.  -s, --skip      - Style the notification as a skip message by painting the 
#.                    introductory arrow in white.
#
## Quiet options:
#.  -q, --quiet               - (repeatable) Increments the quiet level by one.
#.  -l, --loud                - Sets the quiet level to zero.
#
## Quiet options designate the quiet level for the current call. The output 
#. is printed only if the value in $D__OPT_VERBOSITY is equal to or greater 
#. than the quiet level.
#
## Quiet options are read sequentially, left-to-right, and the quiet level 
#. starts at zero. However, if these options are not given at all, the default 
#. quiet level is 1.
#
## Special formatting para-options (para-options work only after the option-
#. argument separator '--'):
#.  -t-   - This para-option treats the next WORD in the DESCRIPTION as a 
#.          title. That WORD is then styled as a title and is followed by a 
#.          colon.
#.  -n-   - This para-option inserts a newline followed by the arrow-width 
#.          indentation (four spaces).
#.  -i-   - This para-option is similar to the '-n-' para-option, but the 
#.          indentation is doubled.
#
## Para-options work only after the option-argument separator '--'.
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
  # Regular call: pluck out options, round up arguments
  local args=() arg opt context qt=n quiet=true sudo=false ttl stl nl=false i
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          c|-context-all)   context=e;;
          h|-context-head)  context=h;;
          1|-context-tip)   context=t;;
          l|-loud)    qt=0;;
          q|-quiet)   ((++qt));;
          u|-sudo)    sudo -n true 2>/dev/null && return 0; sudo=true;;
          \!|-alert)  stl=a;;
          d|-debug)   stl=d;;
          v|-success) stl=v;;
          x|-failure) stl=x;;
          s|-skip)    stl=s;;
          n|-newline) nl=true;;
          t|-title)   if (($#)); then ttl="$1"; shift; fi;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                c)  context=e;;
                h)  context=h;;
                1)  context=t;;
                l)  qt=0;;
                q)  ((++qt));;
                u)  sudo -n true 2>/dev/null && return 0; sudo=true;;
                \!) stl=a;;
                d)  stl=d;;
                v)  stl=v;;
                x)  stl=x;;
                s)  stl=s;;
                n)  nl=true;;
                t)  if (($#)); then ttl="$1"; shift; fi;;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Settle on sudo option
  if $sudo; then
    qt=0; [ -n "$ttl" ] || ttl='Password prompt'
    ((${#args[@]})) || args='The upcoming command requires sudo priveleges'
  fi

  # Settle on quiet call
  [ $qt = n ] && qt=1; (($D__OPT_VERBOSITY<$qt)) && return 0

  # Assemble template and arguments for the eventual call to printf
  local pft= pfa=() tp="$BOLD" ts="$NORMAL"; $nl && pft+='\n'; pft+='%s'

  # Settle on formatting
  case $stl in a) pfa+=("$YELLOW$BOLD==>$NORMAL");;
    v) pfa+=("$GREEN$BOLD==>$NORMAL");; x) pfa+=("$RED$BOLD==>$NORMAL");;
    s) pfa+=("$WHITE$BOLD==>$NORMAL");;
    *) tp="$CYAN$BOLD" ts="$NORMAL$CYAN"; pfa+=("$CYAN==>");;
  esac

  # Compose the leading line depending on the options
  if ((${#args[@]})); then set -- "${args[@]}"
    if [ -n "$ttl" ]; then pft+=' %s:' pfa+=("$tp$ttl$ts"); fi
    while (($#)); do case $1 in
      -n-)  pft+='\n   ';;
      -i-)  pft+='\n       ';;
      -t-)  shift; (($#)) || continue; pft+=' %s:' pfa+=("$tp$1$ts");;
      *)    pft+=' %s' pfa+=("$1")
    esac; shift; done; pft+='\n'
  else
    pft+=' %s\n'; if [ -n "$ttl" ]; then pfa+=("$tp$ttl$ts")
    else pfa+=("${tp}Generic alert$ts"); fi
  fi

  # Print whatever part of the stack is requested
  if [ -n "$context" ]; then
    case $context in
      e)  context=0;;
      h)  context=${#D__CONTEXT_NOTCHES[@]}; (($context)) \
            && context=$((${D__CONTEXT_NOTCHES[$context-1]})) || context=0;;
      t)  context=${#D__CONTEXT[@]}; (($context)) \
            && context=$(($context-1)) || context=0;;
    esac
    if ((${#D__CONTEXT[@]} > $context)); then
      pft+='    %s: %s\n' pfa+=( "${tp}Context$ts" "${D__CONTEXT[$context]}" )
      for ((i=$context+1;i<${#D__CONTEXT[@]};++i)); do
        pft+='             %s\n' pfa+=("${D__CONTEXT[$i]}")
      done
    fi
  fi

  # Print the output
  printf >&2 "$pft%s" "${pfa[@]}" "$NORMAL"
}

#>  d__prompt [-!1bchknqsvxy] [-p PROMPT] [-a ANSWER] [-t TITLE] [--] \
#.    [DESCRIPTION...]
#
## Prompting mechanism: requests a key press and returns corresponding integer:
#.  * Yes/no:       'y' or 'n' (or 'q')   returns 0 or 1 (or 2) respectively
#.  * Any key:      <any> (or 'q')        returns 0 (or 2) respectively
#
#. Does not return until a supported key is pressed.
#
## The layout of the output is as follows.
#
##  [==> ][<TITLE> | <DESCRIPTION> | <TITLE>: <DESCRIPTION>]
#.        [Context: <CONTEXT>...]
#.        <PROMPT> <KEYS>
#
## If PROMPT is the only explicitly given part, then the entire output is a 
#. one-liner.
#
##  * TITLE       - Short heading of the prompt. If the DESCRIPTION is empty 
#.                  and if the prompt is not a one-liner, defaults to 'User 
#.                  attention required'.
#.  * DESCRIPTION - Short elaboration on the prompt. Omitted if not given 
#.                  explicitly.
#.  * CONTEXT     - Some part of the context stack, depending on the given 
#.                  options. Omitted if the context is not requested 
#.                  explicitly. Also, omitted if the context stack empty.
#.  * PROMPT      - Short conclusion for the prompt. Defaults to 'Proceed?'.
#.  * KEYS        - Short explanation of what is expected from the user:
#.                    * Yes/no:               [y/n]
#.                    * Yes/no (with 'q'):    [y/n/q]
#.                    * Any key:              [<any key>]
#.                    * Yes/no (with 'q'):    [<any key>/q]
#
## If the prompt contains anything other than the PROMPT line, the entire 
#. output is prepended with a 'fat' ASCII arrow '==>'. The lines of the output 
#. consist of a title and a message, delimited by a colon.
#
## If terminal coloring is available:
#.  * Arrow is styled in bold yellow.
#.  * Titles and some parts of CMD are styled in bold.
#.  * Prompt is colored with inverted yellow.
#
## Options:
#.  -t TITLE, --title TITLE     - Custom title for the leading line.
#.  -p PROMPT, --prompt PROMPT  - Custom prompt conclusion.
#.  -a ANSWER, --answer ANSWER  - Provides an opportunity to skip the prompt by 
#.                                quickly returning depending on the value of 
#.                                ANSWER passed in.
#.                                In 'yes/no (or quit)' mode:
#.                                  * If ANSWER is 'true', returns 0.
#.                                  * If ANSWER is 'false', returns 1.
#.                                  * Otherwise, proceeds with prompting.
#.                                In 'any key (or quit)' mode:
#.                                  * If ANSWER is 'true'/'false', returns 0.
#.                                  * Otherwise, proceeds with prompting.
#.  -q, --or-quit               - In both prompting modes, provides an extra 
#.                                option: 'quit'. The returned value for 'quit' 
#.                                is always 2.
#.  -n, --newline               - With this option, if this function produces 
#.                                any output, an extra newline is printed 
#.                                before any other output.
#
## Prompting mode (one active at a time, last option wins):
#.  -y, --yes-no    - (default) Prompt for a yes/no answer.
#.  -k, --any-key   - Prompt for any key at all.
#
## Options for context (one active at a time, last option wins):
#.  -c, --context-all         - Include in the output the entire workflow 
#.                              context stack.
#.  -h, --context-head        - Include in the output the items on the workflow 
#.                              context stack that have been pushed since the 
#.                              latest notch in the output.
#.  -1, --context-tip         - Include in the output the latest item on the 
#.                              workflow context stack in the output.
#
## Options for special styling. These modes are only relevant when the terminal 
#. coloring is available (one active at a time, last option wins):
#.  -!, --alert     - Style the prompt in an alert theme by painting the 
#.                    introductory arrow and the prompt itself in yellow.
#.  -v, --success   - Style the prompt in a success theme by painting the 
#.                    introductory arrow and the prompt itself in green.
#.  -x, --failure   - Style the prompt in a failure theme by painting the 
#.                    introductory arrow and the prompt itself in red.
#.  -s, --skip      - Style the prompt in a skip theme by painting the 
#.                    introductory arrow and the prompt itself in white.
#.  -b, --bare      - Do not color the prompt at all. Bolding effects are 
#.                    retained.
#
## Special formatting para-options (para-options work only after the option-
#. argument separator '--'):
#.  -t-   - This para-option treats the next WORD in the DESCRIPTION as a 
#.          title. That WORD is then styled as a title and is followed by a 
#.          colon.
#.  -n-   - This para-option inserts a newline followed by the arrow-width 
#.          indentation (four spaces).
#.  -i-   - This para-option is similar to the '-n-' para-option, but the 
#.          indentation is doubled.
#
## Para-options work only after the option-argument separator '--'.
#
## Returns:
#.  0 - Always.
#
## Prints:
#.  stdout: Nothing.
#.  stderr: Debug messages about argument errors and the prompt itself.
#
d__prompt()
{
  # Regular call: pluck out options, round up arguments
  local args=() arg opt mode=y or_quit=false context one_line=true nl=false i
  local prompt answer ttl stl
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          y|-yes-no)  mode=y;;
          k|-any-key) mode=k;;
          q|-or-quit) or_quit=true;;
          c|-context-all)   context=e; one_line=false;;
          h|-context-head)  context=h; one_line=false;;
          1|-context-tip)   context=t; one_line=false;;
          b|-bare)    stl=b;;
          \!|-alert)  stl=a;;
          v|-success) stl=v;;
          x|-failure) stl=x;;
          s|-skip)    stl=s;;
          n|-newline) nl=true;;
          p|-prompt)  if (($#)); then prompt="$1"; shift; fi;;
          a|-answer)  if (($#)); then answer="$1"; shift; fi;;
          t|-title)   if (($#)); then ttl="$1"; one_line=false; shift; fi;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                y)  mode=y;;
                k)  mode=k;;
                q)  or_quit=true;;
                c)  context=e; one_line=false;;
                h)  context=h; one_line=false;;
                1)  context=t; one_line=false;;
                b)  stl=b;;
                \!) stl=a;;
                v)  stl=v;;
                x)  stl=x;;
                s)  stl=s;;
                n)  nl=true;;
                p)  if (($#)); then prompt="$1"; shift; fi;;
                a)  if (($#)); then answer="$1"; shift; fi;;
                t)  if (($#)); then ttl="$1"; one_line=false; shift; fi;;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Quick return if an answer is provided
  case $answer in
    true)   case $mode in
              y)  d__notify -qq -- 'Decision prompt is pre-accepted; skipping'
                  return 0;;
              k)  d__notify -qq -- 'Any key prompt is pre-accepted; skipping'
                  return 0;;
            esac;;
    false)  case $mode in
              y)  d__notify -qq -- 'Decision prompt is pre-rejected; skipping'
                  return 1;;
              k)  d__notify -qq -- 'Any key prompt is pre-accepted; skipping'
                  return 0;;
            esac;;
  esac

  # Assemble template and arguments for the eventual call to printf
  local pft= pfa=() clr; $nl && pft+='\n'

  # Settle on coloring
  case $stl in b) :;; v) clr="$GREEN";; x) clr="$RED";; s) clr="$WHITE";;
    *) clr="$YELLOW";; esac

  # Settle on the opening arrow
  ((${#args[@]})) && one_line=false

  # Print multi-line sections
  if ! $one_line; then

    # Print introductory arrow
    pft+='%s' pfa+=("$clr$BOLD==>$NORMAL")

    # Compose the leading line depending on the options
    if ((${#args[@]})); then set -- "${args[@]}"
      if [ -n "$ttl" ]; then pft+=' %s:' pfa+=("$BOLD$ttl$NORMAL"); fi
      while (($#)); do case $1 in
        -n-)  pft+='\n   ';;
        -i-)  pft+='\n       ';;
        -t-)  shift; (($#)) || continue; pft+=' %s:' pfa+=("$BOLD$1$NORMAL");;
        *)    pft+=' %s' pfa+=("$1")
      esac; shift; done; pft+='\n'
    else
      pft+=' %s\n'; if [ -n "$ttl" ]; then pfa+=("$BOLD$ttl$NORMAL")
      else pfa+=("${BOLD}User attention required$NORMAL"); fi
    fi

    # Print whatever part of the stack is requested
    if [ -n "$context" ]; then
      case $context in
        e)  context=0;;
        h)  context=${#D__CONTEXT_NOTCHES[@]}; (($context)) \
              && context=$((${D__CONTEXT_NOTCHES[$context-1]})) || context=0;;
        t)  context=${#D__CONTEXT[@]}; (($context)) \
              && context=$(($context-1)) || context=0;;
      esac
      if ((${#D__CONTEXT[@]} > $context)); then
        pft+='    %s: %s\n'
        pfa+=( "${BOLD}Context$NORMAL" "${D__CONTEXT[$context]}" )
        for ((i=$context+1;i<${#D__CONTEXT[@]};++i)); do
          pft+='             %s\n' pfa+=("${D__CONTEXT[$i]}")
        done
      fi
    fi

  # Done printing multi-line sections
  fi

  # Compose the prompt
  $one_line && pft+='%s ' || pft+='    %s '
  [ -n "$prompt" ] && i="$prompt" || i='Proceed?'
  case $mode in
    y)  $or_quit && i+=' [y/n/q]' || i+=' [y/n]';;
    k)  $or_quit && i+=' [<any key>/q]' || i+=' [<any key>]';;
  esac
  [ "$stl" = b ] && pfa+=("$BOLD$i$NORMAL") \
    || pfa+=("$clr$REVERSE$BOLD $i $NORMAL")

  # Print the output
  printf >&2 "$pft" "${pfa[@]}"

  # Read the response and return appropriately
  case $mode in
    y)  while true; do
          read -rsn1 input; case $input in
            y|Y)  printf >&2 '%s\n' 'y'; return 0;;
            n|N)  printf >&2 '%s\n' 'n'; return 1;;
            q|Q)  if $or_quit; then printf >&2 '%s\n' 'q'; return 2; fi;;
          esac
        done;;
    k)  while true; do
          read -rsn1 input
          if $or_quit; then
            case $input in q|Q) printf >&2 '%s\n' 'q'; return 2;; esac
          fi
          printf >&2 '%s\n' "$NORMAL"; return 0
        done;;
  esac
}

#>  d___fail_from_cmd
#
## INTERNAL USE ONLY
#
## This function unifies failure output of functions d__cmd, d__require, and 
#. d__pipe; it also lops the head of the current workflow context stack, unless 
#. the the $opt local variable in the calling context is set to true.
#
## The layout of the output is as follows.
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
#.  * CONTEXT     - Head of the context stack. Omitted if empty.
#.  * CRCM        - Message describing the circumstances of the failure. 
#.                  Omitted if empty.
#.  * RSLT        - Message describing the consequences of the failure. Omitted 
#.                  if empty.
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
  if $opt; then (($D__OPT_VERBOSITY<$qt)) && return 0
    pfa+=("$YELLOW$BOLD==>$NORMAL") 
  else
    pfa+=("$RED$BOLD==>$NORMAL")
  fi

  # Compose the leading line
  pft+=' %s: %s\n' pfa+=( "$BOLD$d__alrt$NORMAL" "$d__cmd" )
  for ((i=0;i<${#labels[@]};++i)); do
    pft+='        %s: %s\n'
    pfa+=( "$BOLD${labels[$i]}$NORMAL" "'${hunks[$i]}'" )
  done

  # Print the head of the stack
  local tmp=${#D__CONTEXT_NOTCHES[@]}
  (($tmp)) && tmp=$((${D__CONTEXT_NOTCHES[$tmp-1]})) || tmp=0
  if ((${#D__CONTEXT[@]} > $tmp)); then
    pft+='    %s: %s\n' pfa+=( "${BOLD}Context$NORMAL" "${D__CONTEXT[$tmp]}" )
    for ((i=$tmp+1;i<${#D__CONTEXT[@]};++i)); do
      pft+='             %s\n' pfa+=("${D__CONTEXT[$i]}")
    done
  fi

  # Add circumstances and consequences, if provided
  if ! [ -z ${d__crcm+isset} ]; then
    pft+='    %s: %s\n' pfa+=( "${BOLD}Circumstances$NORMAL" "$d__crcm" )
  fi
  if ! [ -z ${d__rslt+isset} ]; then
    pft+='    %s: %s\n' pfa+=( "${BOLD}Result$NORMAL" "$d__rslt" )
  fi

  # Print the output
  printf >&2 "$pft" "${pfa[@]}"

  # If not optional, lop the head of the context stack
  $opt || d__context -- lop
}

#>  d__require_writable PATH
#
## A small helper that ensures eiher that the PATH itself is a writable 
#. directory, or that its closest existing parent directory is writable. If 
#. neither is the case, issues a warning to the user about the required sudo 
#. privelege.
#
## Returns:
#.  0 - The PATH or its existing parent is writable without sudo.
#.  1 - The PATH or its existing parent is only writable with sudo.
#.  2 - The PATH is empty.
#
d__require_writable()
{
  local path="$1"; if [ -z "$path" ]
  then d__notify -lx -- "Unable to write into a blank path"; return 2; fi
  while [ ! -d "$path" ]; do path="$( dirname -- "$path" )"; done
  if [ -w "$path" ]; then return 0
  else d__notify -u! -- "Sudo privelege is required to operate under:" \
    -i- "$path"; return 1; fi
}