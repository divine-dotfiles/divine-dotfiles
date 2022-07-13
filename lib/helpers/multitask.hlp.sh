#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: reconcile
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.14
#:revremark:    Tweak reconciliation of check codes
#:created_at:   2019.06.18

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Helper functions for deployments that contain multiple sub-deployments
#

# Marker and dependencies
readonly D__HLP_MULTITASK=loaded
d__load util workflow

d__mltsk_check()
{
  d__context -- notch
  d__context -- push "Checking multitask deployment"

  # Cut-off checks for number of tasks and continuity
  if ! ((${#D_MLTSK_MAIN[@]})); then
    d__fail -t 'Multitask failed' -- 'Zero task names provided'; return 3
  fi
  local d__i; for ((d__i=0;d__i<${#D_MLTSK_MAIN[@]};++d__i)); do
    [ -z ${D_MLTSK_MAIN[$d__i]+isset} ] || continue
    d__fail -t 'Multitask failed' -- \
      'Array $D_MLTSK_MAIN is not continuous'
    return 3
  done

  # Run multitask pre-processing, if implemented
  local d__mrtc d__tmp; if declare -f d_mltsk_pre_check &>/dev/null; then
    unset D_ADDST_MLTSK_CHECK_CODE D_ADDST_MLTSK_IRRELEVANT
    d_mltsk_pre_check; d__tmp=$?; unset -f d_mltsk_pre_check
    if (($d__tmp)) || [ "$D_ADDST_MLTSK_IRRELEVANT" = true ]; then
      d__notify -qh -- \
        "Multitask's pre-check hook declares multitask irrelevant"
      d__context -- lop; return 3
    elif [[ $D_ADDST_MLTSK_CHECK_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Multitask's pre-check hook forces" \
        "check code '$D_ADDST_MLTSK_CHECK_CODE'"
      d__context -- lop; return $D_ADDST_MLTSK_CHECK_CODE
    fi
  fi

  # Storage variables
  local d__mti d__mtn d__mtf d__mas d__mss d__mtplq d__mth d__mtrtc
  local d__mas_a=() d__mas_r=() d__mas_w=() d__mas_c=()
  local d__mas_h=false d__mas_p=false d__mtbf d__mtaf

  # Initialize/reset status variables
  d__mas=( true true true true true true true true true true )
  d__mss=( false false false false false false false false false false )
  unset D__MLTSK_CHECK_CODES D__MLTSK_CAP_NUM D__TASKS_ARE_QUEUES
  unset D__MLTSK_FLAGS

  # Iterate over numbers of task names
  for ((d__mti=0;d__mti<${#D_MLTSK_MAIN[@]};++d__mti)); do

    # Extract number, name; switch context
    d__mtn="${D_MLTSK_MAIN[$d__mti]}" d__mtf="d_${d__mtn}_check"
    d__mtbf="d_${d__mtn}_pre_check" d__mtaf="d_${d__mtn}_post_check"
    d__context -- push "Checking task #$d__mti '$d__mtn'"

    # Initialize marker var; clear add-statuses
    unset D__TASK_IS_QUEUE D_ADDST_MLTSK_HALT D_ADDST_TASK_CHECK_CODE
    unset D_ADDST_HALT D_ADDST_PROMPT
    unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
    D__MLTSK_FLAGS[$d__mti]=

    # Expose additional variables to the task
    D__TASK_NUM="$d__mti" D__TASK_NAME="$d__mtn"

    # Run task pre-processing, if implemented
    unset D_ADDST_TASK_FLAGS; d__mtrtc=0 d__mth=false
    if declare -f "$d__mtbf" &>/dev/null; then "$d__mtbf"; else true; fi
    if (($?)); then
      d__notify -qh -- "Task's pre-check hook declares task irrelevant"
      d__mtrtc=3 d__mth=true
    elif [[ $D_ADDST_TASK_CHECK_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Task's pre-check hook forces" \
        "check code '$D_ADDST_TASK_CHECK_CODE'"
      d__mtrtc="$D_ADDST_TASK_CHECK_CODE" d__mth=true
    fi
    if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__mth=true
      d__notify -qh -- "Task's pre-check hook forces halting of multitask"
    fi
    if ! [ -z ${D_ADDST_TASK_FLAGS+isset} ]
    then D__MLTSK_FLAGS[$d__mti]+="$D_ADDST_TASK_FLAGS"; fi
    if [ "$D_ADDST_MLTSK_IRRELEVANT" = true ]; then
      d__notify -qh -- "Task's pre-check hook declares multitask irrelevant"
      d__context -- lop
      return 3
    fi

    # Get return code of d_dpl_check, or fall back to zero
    if ! $d__mth; then unset D_ADDST_TASK_FLAGS
      if declare -f "$d__mtf" &>/dev/null; then "$d__mtf"; else true; fi
      d__mtrtc=$?
      if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__mth=true
        d__notify -qh -- "Task's checking forces halting of multitask"
      fi
      if ! [ -z ${D_ADDST_TASK_FLAGS+isset} ]
      then D__MLTSK_FLAGS[$d__mti]+="$D_ADDST_TASK_FLAGS"; fi
      if [ "$D_ADDST_MLTSK_IRRELEVANT" = true ]; then d__mth=true
        d__notify -qh -- "Task's checking declares multitask irrelevant"
        d__context -- lop
        return 3
      fi
    fi

    # Run task post-processing, if implemented
    if ! $d__mth; then
      unset D_ADDST_TASK_FLAGS; D__TASK_CHECK_CODE="$d__mtrtc"
      if declare -f "$d__mtaf" &>/dev/null; then "$d__mtaf"; else true; fi
      if (($?)); then
        d__notify -qh -- "Task's post-check hook declares task irrelevant" \
          "instead of actual code '$d__mtrtc'"
        d__mtrtc=3
      elif [[ $D_ADDST_TASK_CHECK_CODE =~ ^[0-9]+$ ]]; then
        d__notify -qh -- "Task's post-check hook forces" \
          "check code '$D_ADDST_TASK_CHECK_CODE'" \
          "instead of actual code '$d__mtrtc'"
        d__mtrtc="$D_ADDST_TASK_CHECK_CODE"
      fi
      if [ "$D_ADDST_MLTSK_HALT" = true ]; then
        d__notify -qh -- "Task's post-check hook forces halting of multitask"
      fi
      if ! [ -z ${D_ADDST_TASK_FLAGS+isset} ]
      then D__MLTSK_FLAGS[$d__mti]+="$D_ADDST_TASK_FLAGS"; fi
      if [ "$D_ADDST_MLTSK_IRRELEVANT" = true ]; then
        d__notify -qh -- "Task's post-check hook declares multitask irrelevant"
        d__context -- lop
        return 3
      fi
    fi

    # Store return code
    D__MLTSK_CHECK_CODES[$d__mti]=$d__mtrtc

    # Catch add-statuses
    if ((${#D_ADDST_ATTENTION[@]}))
    then for d__i in "${D_ADDST_ATTENTION[@]}"; do d__mas_a+="$d__i"; done; fi
    if ((${#D_ADDST_HELP[@]}))
    then for d__i in "${D_ADDST_HELP[@]}"; do d__mas_r+="$d__i"; done; fi
    if ((${#D_ADDST_WARNING[@]}))
    then for d__i in "${D_ADDST_WARNING[@]}"; do d__mas_w+="$d__i"; done; fi
    if ((${#D_ADDST_CRITICAL[@]}))
    then for d__i in "${D_ADDST_CRITICAL[@]}"; do d__mas_c+="$d__i"; done; fi
    if [ "$D_ADDST_HALT" = true ]; then d__mas_h=true; fi
    if [ "$D_ADDST_PROMPT" = true ]; then d__mas_p=true; fi

    # Inspect return code; set statuses accordingly
    case $d__mtrtc in
      1)  for d__i in 0 2 3 4 5 6 7 8 9; do d__mas[$d__i]=false; done
          d__mss[1]=true;;
      2)  for d__i in 0 1 3 4 5 6 7 8 9; do d__mas[$d__i]=false; done
          d__mss[2]=true;;
      3)  for d__i in 0 1 2 4 5 6 7 8 9; do d__mas[$d__i]=false; done
          d__mss[3]=true;;
      4)  for d__i in 0 1 2 3 5 6 7 8 9; do d__mas[$d__i]=false; done
          d__mss[4]=true;;
      5)  for d__i in 0 1 2 3 4 6 7 8 9; do d__mas[$d__i]=false; done
          d__mss[5]=true;;
      6)  for d__i in 0 1 2 3 4 5 7 8 9; do d__mas[$d__i]=false; done
          d__mss[6]=true;;
      7)  for d__i in 0 1 2 3 4 5 6 8 9; do d__mas[$d__i]=false; done
          d__mss[7]=true;;
      8)  for d__i in 0 1 2 3 4 5 6 7 9; do d__mas[$d__i]=false; done
          d__mss[8]=true;;
      9)  for d__i in 0 1 2 3 4 5 6 7 8; do d__mas[$d__i]=false; done
          d__mss[9]=true;;
      *)  for d__i in 1 2 3 4 5 6 7 8 9; do d__mas[$d__i]=false; done
          d__mss[0]=true;;
    esac

    # Store marker of whether current task is a queue
    if [ -z ${D__TASK_IS_QUEUE+isset} ]
    then D__TASKS_ARE_QUEUES[$d__mti]=false
    else
      d__notify -qqqq -- "Task '$d__mtn' is marked as a queue"
      D__TASKS_ARE_QUEUES[$d__mti]=true
    fi

    # If in check routine and being verbose, print status
    if [ "$D__REQ_ROUTINE" = check -a "$D__OPT_VERBOSITY" -gt 0 ]; then
      d__mtplq="Task #$d__mti '$d__mtn'"
      d__mtplq+="$NORMAL"; case $d__mtrtc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_QCH_1" "$d__mtplq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_QCH_2" "$d__mtplq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_QCH_3" "$d__mtplq";;
        4)  printf >&2 '%s %s\n' "$D__INTRO_QCH_4" "$d__mtplq";;
        5)  printf >&2 '%s %s\n' "$D__INTRO_QCH_5" "$d__mtplq";;
        6)  printf >&2 '%s %s\n' "$D__INTRO_QCH_6" "$d__mtplq";;
        7)  printf >&2 '%s %s\n' "$D__INTRO_QCH_7" "$d__mtplq";;
        8)  printf >&2 '%s %s\n' "$D__INTRO_QCH_8" "$d__mtplq";;
        9)  printf >&2 '%s %s\n' "$D__INTRO_QCH_9" "$d__mtplq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_QCH_0" "$d__mtplq";;
      esac
    fi

    # Process potential multitask halting
    if [ "$D_ADDST_MLTSK_HALT" = true ]
    then D__MLTSK_CAP_NUM=$((d__mti+1)); d__context -- pop; break; fi

    d__context -- pop

  # Done iterating over numbers of task names
  done; unset -f "$d__mtf" "$d__mtbf" "$d__mtaf"

  # Switch context
  d__context -- push 'Reconciling check status of tasks'

  # Pass on add-statuses
  unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
  ((${#d__mas_a[@]})) && D_ADDST_ATTENTION=("${d__mas_a[@]}")
  ((${#d__mas_r[@]})) && D_ADDST_HELP=("${d__mas_r[@]}")
  ((${#d__mas_w[@]})) && D_ADDST_WARNING=("${d__mas_w[@]}")
  ((${#d__mas_c[@]})) && D_ADDST_CRITICAL=("${d__mas_c[@]}")
  unset D_ADDST_HALT; $d__mas_h && D_ADDST_HALT=true
  unset D_ADDST_PROMPT; $d__mas_p && D_ADDST_PROMPT=true

  # Combine check codes
  d___reconcile_task_check_codes; d__mrtc=$?
  d__context -- pop "Settled on multitask check code '$d__mrtc'"

  # Run multitask post-processing, if implemented
  if declare -f d_mltsk_post_check &>/dev/null; then
    unset D_ADDST_MLTSK_CHECK_CODE; D__MLTSK_CHECK_CODE="$d__mrtc"
    d_mltsk_post_check; d__tmp=$?; unset -f d_mltsk_post_check
    if (($d__tmp)) || [ "$D_ADDST_MLTSK_IRRELEVANT" = true ]; then
      d__notify -qh -- "Multitask's post-check hook declares multitask" \
        "irrelevant instead of actual code '$d__mrtc'"
      d__context -- lop; return 3
    elif [[ $D_ADDST_MLTSK_CHECK_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Multitask's post-check hook forces" \
        "check code '$D_ADDST_MLTSK_CHECK_CODE'" \
        "instead of actual code '$d__mrtc'"
      d__context -- lop; return $D_ADDST_MLTSK_CHECK_CODE
    fi
  fi

  d__context -- lop; return $d__mrtc
}

d__mltsk_install()
{
  d__context -- notch
  d__context -- push "Installing multitask deployment"

  # Run multitask pre-processing, if implemented
  local d__mrtc d__tmp; if declare -f d_mltsk_pre_install &>/dev/null; then
    unset D_ADDST_MLTSK_INSTALL_CODE
    d_mltsk_pre_install; d__tmp=$?; unset -f d_mltsk_pre_install
    if (($d__tmp)); then
      d__notify -qh -- \
        "Multitask's pre-install hook declares multitask rejected"
      d__context -- lop; return 2
    elif [[ $D_ADDST_MLTSK_INSTALL_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Multitask's pre-install hook forces" \
        "install code '$D_ADDST_MLTSK_INSTALL_CODE'"
      d__context -- lop; return $D_ADDST_MLTSK_INSTALL_CODE
    fi
  fi

  # Storage variables
  local d__mti d__mtcap d__mtn d__mtf d__mtrtc d__mas d__mss d__msscnt=0 d__i
  local d__mas_a=() d__mas_r=() d__mas_w=() d__mas_c=() d__mas_h=false d__mth
  local d__mtplq d__mtdfac d__mtfrcd d__mtcc d__mtok d__mtocc d__mtof
  local d__mtbf d__mtaf d__msg d__mtflg
  unset D__MLTSK_INSTALL_CODES

  # Initialize/reset status variables
  d__mas=( true true true true ) d__mss=( false false false false )
  if [ -z ${D__MLTSK_CAP_NUM+isset} ]; then d__mtcap=${#D_MLTSK_MAIN[@]}
  else d__mtcap="$D__MLTSK_CAP_NUM"; fi

  # Iterate over numbers of task names
  for ((d__mti=0;d__mti<$d__mtcap;++d__mti)); do

    # Extract number, name, and check code; compose task name; switch context
    d__mtn="${D_MLTSK_MAIN[$d__mti]}" d__mtf="d_${d__mtn}_install"
    d__mtbf="d_${d__mtn}_pre_install" d__mtaf="d_${d__mtn}_post_install"
    d__mtcc="${D__MLTSK_CHECK_CODES[$d__mti]}"
    d__mtflg="${D__MLTSK_FLAGS[$d__mti]}"
    d__mtplq="#$d__mti '$d__mtn'"
    d__context -- push "Installing task $d__mtplq"
    d__mtplq="Task $d__mtplq$NORMAL"

    # Pre-set statuses; conditionally print intro; inspect check code
    d__mtdfac=false d__mtfrcd=false d__mtok=true
    case $d__mtcc in
      1)  # Fully installed
          if $D__OPT_FORCE; then d__mtfrcd=true
            printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
            d__notify -l! -- \
              "Task '$d__mtn' appears to be already installed"
          else d__mtok=false
            (($D__OPT_VERBOSITY)) \
              && printf >&2 '%s %s\n' "$D__INTRO_QIN_A" "$d__mtplq"
          fi;;
      2)  # Fully not installed
          :;;
      3)  # Irrelevant or invalid
          (($D__OPT_VERBOSITY)) \
            && printf >&2 '%s %s\n' "$D__INTRO_QCH_3" "$d__mtplq"
          d__mtok=false;;
      4)  # Partly installed
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
          d__notify -l! -- "Task '$d__mtn' appears to be partly installed"
          d__mtdfac=true; if $D__OPT_FORCE; then d__mtfrcd=true; fi;;
      5)  # Likely installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
          d__notify -l! -- \
            "Task '$d__mtn' is recorded as previously installed" \
            -n- 'but there is no way to confirm that it is indeed installed'
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_5" "$d__mtplq"
          fi;;
      6)  # Manually removed (tinkered with)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
          d__notify -lx -- \
            "Task '$d__mtn' is recorded as previously installed" \
            -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
            -n- '(which may be due to manual tinkering)'
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QIN_S" "$d__mtplq"
          fi;;
      7)  # Fully installed (by user or OS)
          d__msg=( "Task '$d__mtn' appears to be fully installed" \
            'by means other than installing this deployment' )
          if $D__OPT_FORCE; then d__mtfrcd=true
            printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
            d__notify -l! -- "${d__msg[@]}"
          else d__mtok=false
            if (($D__OPT_VERBOSITY)); then
              printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
              d__notify -q! -- "${d__msg[@]}"
              d__notify -q! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_QCH_7" "$d__mtplq"
            fi
          fi;;
      8)  # Partly installed (by user or OS)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
          d__notify -l! -- "Task '$d__mtn' appears to be partly installed" \
            'by means other than installing this deployment'
          d__mtdfac=true; if $D__OPT_FORCE; then d__mtfrcd=true; fi;;
      9)  # Likely not installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__mtplq"
          d__notify -l! -- "Task '$d__mtn' is ${BOLD}not$NORMAL recorded" \
            'as previously installed' -n- 'but there is no way to confirm' \
            "that it is indeed ${BOLD}not$NORMAL installed"
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_9" "$d__mtplq"
          fi;;
      *)  # Truly unknown
          :;;
    esac

    # If forcing, print a forceful intro
    $d__mtok && $d__mtfrcd \
      && printf >&2 '%s %s\n' "$D__INTRO_QIN_F" "$d__mtplq"

    # Re-prompt if action differs depending on force or if forcing
    if $d__mtok && ( $d__mtdfac || $d__mtfrcd ); then
      if $d__mtdfac; then printf >&2 '%s %s\n' "$D__INTRO_ATTNT" \
        'In this status, installation may differ with and without --force'; fi
      if $d__mtfrcd; then printf >&2 '%s ' "$D__INTRO_CNF_U"
      else printf >&2 '%s ' "$D__INTRO_CNF_N"; fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_QIN_S" "$d__mtplq"; d__mtok=false
      fi
    fi

    # Shared cut-off for skipping current task
    if ! $d__mtok; then
      # If skipping a queue, initialize or increment queue section number
      if [ "${D__TASKS_ARE_QUEUES[$d__mti]}" = true ]; then
        if [ -z ${D__QUEUE_SECTNUM[1]+isset} ]; then D__QUEUE_SECTNUM[1]=0
        else ((++D__QUEUE_SECTNUM[1])); fi
      fi
      d__context -- pop
      continue
    fi

    # Initialize marker var; clear add-statuses
    unset D_ADDST_MLTSK_HALT D_ADDST_HALT D_ADDST_TASK_INSTALL_CODE
    unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

    # Expose additional variables to the task
    D__TASK_NUM="$d__mti" D__TASK_NAME="$d__mtn" D__TASK_FLAGS="$d__mtflg"
    D__TASK_CHECK_CODE="$d__mtcc" D__TASK_IS_FORCED="$d__mtfrcd"
    d__mtocc="$D__DPL_CHECK_CODE" d__mtof="$D__DPL_IS_FORCED"
    D__DPL_CHECK_CODE="$d__mtcc" D__DPL_IS_FORCED="$d__mtfrcd"

    # Run task pre-processing, if implemented
    d__mtrtc=0 d__mth=false
    if declare -f "$d__mtbf" &>/dev/null; then "$d__mtbf"; else true; fi
    if (($?)); then
      d__notify -qh -- "Task's pre-install hook declares task rejected"
      d__mtrtc=2 d__mth=true
    elif [[ $D_ADDST_TASK_INSTALL_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Task's pre-install hook forces" \
        "install code '$D_ADDST_TASK_INSTALL_CODE'"
      d__mtrtc="$D_ADDST_TASK_INSTALL_CODE" d__mth=true
    fi
    if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__mth=true
      d__notify -qh -- "Task's pre-install hook forces halting of multitask"
    fi

    # Get return code of d_dpl_install, or fall back to zero
    if ! $d__mth; then
      if declare -f "$d__mtf" &>/dev/null; then "$d__mtf"; else true; fi
      d__mtrtc=$?
      if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__mth=true
        d__notify -qh -- "Task's installation forces halting of multitask"
      fi
    fi

    # Run task post-processing, if implemented
    if ! $d__mth; then
      D__TASK_INSTALL_CODE="$d__mtrtc"
      if declare -f "$d__mtaf" &>/dev/null; then "$d__mtaf"; else true; fi
      if (($?)); then
        d__notify -qh -- "Task's post-install hook declares task rejected" \
          "instead of actual code '$d__mtrtc'"
        d__mtrtc=2
      elif [[ $D_ADDST_TASK_INSTALL_CODE =~ ^[0-9]+$ ]]; then
        d__notify -qh -- "Task's post-install hook forces" \
          "install code '$D_ADDST_TASK_INSTALL_CODE'" \
          "instead of actual code '$d__mtrtc'"
        d__mtrtc="$D_ADDST_TASK_INSTALL_CODE"
      fi
      if [ "$D_ADDST_MLTSK_HALT" = true ]; then
        d__notify -qh -- \
          "Task's post-install hook forces halting of multitask"
      fi
    fi

    # Store return code
    D__MLTSK_INSTALL_CODES[$d__mti]=$d__mtrtc

    # Restore overwritten deployment-level variables
    D__DPL_CHECK_CODE="$d__mtocc" D__DPL_IS_FORCED="$d__mtof"

    # Catch add-statuses
    if ((${#D_ADDST_ATTENTION[@]}))
    then for d__i in "${D_ADDST_ATTENTION[@]}"; do d__mas_a+="$d__i"; done; fi
    if ((${#D_ADDST_HELP[@]}))
    then for d__i in "${D_ADDST_HELP[@]}"; do d__mas_r+="$d__i"; done; fi
    if ((${#D_ADDST_WARNING[@]}))
    then for d__i in "${D_ADDST_WARNING[@]}"; do d__mas_w+="$d__i"; done; fi
    if ((${#D_ADDST_CRITICAL[@]}))
    then for d__i in "${D_ADDST_CRITICAL[@]}"; do d__mas_c+="$d__i"; done; fi
    if [ "$D_ADDST_HALT" = true ]; then d__mas_h=true; fi

    # Inspect return code; set statuses accordingly
    case $d__mtrtc in
      1)  for d__i in 0 2 3; do d__mas[$d__i]=false; done; d__mss[1]=true;;
      2)  for d__i in 0 1 3; do d__mas[$d__i]=false; done; d__mss[2]=true;;
      3)  for d__i in 0 1 2; do d__mas[$d__i]=false; done; d__mss[3]=true;;
      *)  for d__i in 1 2 3; do d__mas[$d__i]=false; done; d__mss[0]=true;;
    esac

    # If in there has been some output, print status
    if (($D__OPT_VERBOSITY)) || $d__mtfrcd || $d__mtdfac; then
      case $d__mtrtc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_QIN_1" "$d__mtplq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_QIN_2" "$d__mtplq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_QIN_3" "$d__mtplq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_QIN_0" "$d__mtplq";;
      esac
    fi

    # Process potential multitask halting
    if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__context -- pop; break; fi

    d__context -- pop

  # Done iterating over numbers of task names
  done; unset -f "$d__mtf" "$d__mtbf" "$d__mtaf"

  # Switch context
  d__context -- push 'Reconciling install status of tasks'

  # Pass on add-statuses
  unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
  ((${#d__mas_a[@]})) && D_ADDST_ATTENTION=("${d__mas_a[@]}")
  ((${#d__mas_r[@]})) && D_ADDST_HELP=("${d__mas_r[@]}")
  ((${#d__mas_w[@]})) && D_ADDST_WARNING=("${d__mas_w[@]}")
  ((${#d__mas_c[@]})) && D_ADDST_CRITICAL=("${d__mas_c[@]}")
  unset D_ADDST_HALT; $d__mas_h && D_ADDST_HALT=true

  # Combine status codes
  d___reconcile_task_insrmv_codes; d__mrtc=$?
  d__context -- pop "Settled on multitask install code '$d__mrtc'"

  # Run multitask post-processing, if implemented
  if declare -f d_mltsk_post_install &>/dev/null; then
    unset D_ADDST_MLTSK_INSTALL_CODE; D__MLTSK_INSTALL_CODE="$d__mrtc"
    d_mltsk_post_install; d__tmp=$?; unset -f d_mltsk_post_install
    if (($d__tmp)); then
      d__notify -qh -- "Multitask's post-install hook declares multitask" \
        "rejected instead of actual code '$d__mrtc'"
      d__context -- lop; return 2
    elif [[ $D_ADDST_MLTSK_INSTALL_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Multitask's post-install hook forces" \
        "install code '$D_ADDST_MLTSK_INSTALL_CODE'" \
        "instead of actual code '$d__mrtc'"
      d__context -- lop; return $D_ADDST_MLTSK_INSTALL_CODE
    fi
  fi

  d__context -- lop; return $d__mrtc
}

d__mltsk_remove()
{
  d__context -- notch
  d__context -- push "Removing multitask deployment"

  # Run multitask pre-processing, if implemented
  local d__mrtc d__tmp; if declare -f d_mltsk_pre_remove &>/dev/null; then
    unset D_ADDST_MLTSK_REMOVE_CODE
    d_mltsk_pre_remove; d__tmp=$?; unset -f d_mltsk_pre_remove
    if (($d__tmp)); then
      d__notify -qh -- \
        "Multitask's pre-remove hook declares multitask rejected"
      d__context -- lop; return 2
    elif [[ $D_ADDST_MLTSK_REMOVE_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Multitask's pre-remove hook forces" \
        "remove code '$D_ADDST_MLTSK_REMOVE_CODE'"
      d__context -- lop; return $D_ADDST_MLTSK_REMOVE_CODE
    fi
  fi

  # Storage variables
  local d__mti d__mtcap d__mtn d__mtf d__mtrtc d__mas d__mss d__msscnt=0 d__i
  local d__mas_a=() d__mas_r=() d__mas_w=() d__mas_c=() d__mas_h=false d__mth
  local d__mtplq d__mtabn d__mtfrcd d__mtcc d__mtok d__mtocc d__mtof
  local d__mtbf d__mtaf d__mtflg
  unset D__MLTSK_REMOVE_CODES

  # Initialize/reset status variables
  d__mas=( true true true true ) d__mss=( false false false false )
  if [ -z ${D__MLTSK_CAP_NUM+isset} ]; then d__mtcap=${#D_MLTSK_MAIN[@]}
  else d__mtcap="$D__MLTSK_CAP_NUM"; fi

  # Iterate over numbers of task names
  for ((d__mti=$d__mtcap-1;d__mti>=0;--d__mti)); do

    # Extract number, name, and check code; compose task name; switch context
    d__mtn="${D_MLTSK_MAIN[$d__mti]}" d__mtf="d_${d__mtn}_remove"
    d__mtbf="d_${d__mtn}_pre_remove" d__mtaf="d_${d__mtn}_post_remove"
    d__mtcc="${D__MLTSK_CHECK_CODES[$d__mti]}"
    d__mtflg="${D__MLTSK_FLAGS[$d__mti]}"
    d__mtplq="#$d__mti '$d__mtn'"
    d__context -- push "Removing task $d__mtplq"
    d__mtplq="Task $d__mtplq$NORMAL"

    # Pre-set statuses; conditionally print intro; inspect check code
    d__mtabn=false d__mtfrcd=false d__mtok=true
    case $d__mtcc in
      1)  # Fully installed
          :;;
      2)  # Fully not installed
          if $D__OPT_FORCE; then d__mtfrcd=true
            printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
            d__notify -l! -- \
              "Task '$d__mtn' appears to be already not installed"
          else d__mtok=false
            (($D__OPT_VERBOSITY)) \
              && printf >&2 '%s %s\n' "$D__INTRO_QRM_A" "$d__mtplq"
          fi;;
      3)  # Irrelevant or invalid
          (($D__OPT_VERBOSITY)) \
            && printf >&2 '%s %s\n' "$D__INTRO_QCH_3" "$d__mtplq"
          d__mtok=false;;
      4)  # Partly installed
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
          d__notify -l! -- \
            "Task '$d__mtn' appears to be only partly installed"
          d__mtabn=true;;
      5)  # Likely installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
          d__notify -l! -- \
            "Task '$d__mtn' is recorded as previously installed" \
            -n- 'but there is no way to confirm that it is indeed installed'
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_5" "$d__mtplq"
          fi;;
      6)  # Manually removed (tinkered with)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
          d__notify -lx -- \
            "Task '$d__mtn' is recorded as previously installed" \
            -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
            -n- '(which may be due to manual tinkering)'
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QRM_S" "$d__mtplq"
          fi;;
      7)  # Fully installed (by user or OS)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
          d__notify -l! -- "Task '$d__mtn' appears to be fully installed" \
            'by means other than installing this deployment'
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_7" "$d__mtplq"
          fi;;
      8)  # Partly installed (by user or OS)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
          d__notify -l! -- "Task '$d__mtn' appears to be partly installed" \
            'by means other than installing this deployment'
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_8" "$d__mtplq"
          fi;;
      9)  # Likely not installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__mtplq"
          d__notify -l! -- "Task '$d__mtn' is ${BOLD}not$NORMAL recorded" \
            'as previously installed' -n- 'but there is no way to confirm' \
            "that it is indeed ${BOLD}not$NORMAL installed"
          if $D__OPT_FORCE; then d__mtfrcd=true
          else d__mtok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_9" "$d__mtplq"
          fi;;
      *)  # Truly unknown
          :;;
    esac

    # If forcing, print a forceful intro and re-prompt
    if $d__mtok && $d__mtfrcd; then
      printf >&2 '%s %s\n' "$D__INTRO_QRM_F" "$d__mtplq"
      printf >&2 '%s ' "$D__INTRO_CNF_U"
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_QRM_S" "$d__mtplq"; d__mtok=false
      fi
    fi

    # Shared cut-off for skipping current task
    if ! $d__mtok; then
      # If skipping a queue, initialize or decrement queue section number
      if [ "${D__TASKS_ARE_QUEUES[$d__mti]}" = true ]; then
        if [ -z ${D__QUEUE_SECTNUM[1]+isset} ]
        then D__QUEUE_SECTNUM[1]=${#D__QUEUE_SPLIT_POINTS[@]}
        else ((--D__QUEUE_SECTNUM[1])); fi
      fi
      d__context -- pop
      continue
    fi

    # Initialize marker var; clear add-statuses
    unset D_ADDST_MLTSK_HALT D_ADDST_HALT D_ADDST_TASK_REMOVE_CODE
    unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

    # Expose additional variables to the task
    D__TASK_NUM="$d__mti" D__TASK_NAME="$d__mtn" D__TASK_FLAGS="$d__mtflg"
    D__TASK_CHECK_CODE="$d__mtcc" D__TASK_IS_FORCED="$d__mtfrcd"
    d__mtocc="$D__DPL_CHECK_CODE" d__mtof="$D__DPL_IS_FORCED"
    D__DPL_CHECK_CODE="$d__mtcc" D__DPL_IS_FORCED="$d__mtfrcd"

    # Run task pre-processing, if implemented
    d__mtrtc=0 d__mth=false
    if declare -f "$d__mtbf" &>/dev/null; then "$d__mtbf"; else true; fi
    if (($?)); then
      d__notify -qh -- "Task's pre-remove hook declares task rejected"
      d__mtrtc=2 d__mth=true
    elif [[ $D_ADDST_TASK_REMOVE_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Task's pre-remove hook forces" \
        "remove code '$D_ADDST_TASK_REMOVE_CODE'"
      d__mtrtc="$D_ADDST_TASK_REMOVE_CODE" d__mth=true
    fi
    if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__mth=true
      d__notify -qh -- "Task's pre-remove hook forces halting of multitask"
    fi

    # Get return code of d_dpl_remove, or fall back to zero
    if ! $d__mth; then
      if declare -f "$d__mtf" &>/dev/null; then "$d__mtf"; else true; fi
      d__mtrtc=$?
      if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__mth=true
        d__notify -qh -- "Task's removing forces halting of multitask"
      fi
    fi

    # Run task post-processing, if implemented
    if ! $d__mth; then
      D__TASK_INSTALL_CODE="$d__mtrtc"
      if declare -f "$d__mtaf" &>/dev/null; then "$d__mtaf"; else true; fi
      if (($?)); then
        d__notify -qh -- "Task's post-remove hook declares task rejected" \
          "instead of actual code '$d__mtrtc'"
        d__mtrtc=2
      elif [[ $D_ADDST_TASK_REMOVE_CODE =~ ^[0-9]+$ ]]; then
        d__notify -qh -- "Task's post-remove hook forces" \
          "remove code '$D_ADDST_TASK_REMOVE_CODE'" \
          "instead of actual code '$d__mtrtc'"
        d__mtrtc="$D_ADDST_TASK_REMOVE_CODE"
      fi
      if [ "$D_ADDST_MLTSK_HALT" = true ]; then
        d__notify -qh -- "Task's post-remove hook forces halting of multitask"
      fi
    fi

    # Store return code
    D__MLTSK_REMOVE_CODES[$d__mti]=$d__mtrtc

    # Restore overwritten deployment-level variables
    D__DPL_CHECK_CODE="$d__mtocc" D__DPL_IS_FORCED="$d__mtof"

    # Catch add-statuses
    if ((${#D_ADDST_ATTENTION[@]}))
    then for d__i in "${D_ADDST_ATTENTION[@]}"; do d__mas_a+="$d__i"; done; fi
    if ((${#D_ADDST_HELP[@]}))
    then for d__i in "${D_ADDST_HELP[@]}"; do d__mas_r+="$d__i"; done; fi
    if ((${#D_ADDST_WARNING[@]}))
    then for d__i in "${D_ADDST_WARNING[@]}"; do d__mas_w+="$d__i"; done; fi
    if ((${#D_ADDST_CRITICAL[@]}))
    then for d__i in "${D_ADDST_CRITICAL[@]}"; do d__mas_c+="$d__i"; done; fi
    if [ "$D_ADDST_HALT" = true ]; then d__mas_h=true; fi

    # Inspect return code; set statuses accordingly
    case $d__mtrtc in
      1)  for d__i in 0 2 3; do d__mas[$d__i]=false; done; d__mss[1]=true;;
      2)  for d__i in 0 1 3; do d__mas[$d__i]=false; done; d__mss[2]=true;;
      3)  for d__i in 0 1 2; do d__mas[$d__i]=false; done; d__mss[3]=true;;
      *)  for d__i in 1 2 3; do d__mas[$d__i]=false; done; d__mss[0]=true;;
    esac

    # If in there has been some output, print status
    if (($D__OPT_VERBOSITY)) || $d__mtfrcd || $d__mtabn; then
      case $d__mtrtc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_QRM_1" "$d__mtplq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_QRM_2" "$d__mtplq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_QRM_3" "$d__mtplq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_QRM_0" "$d__mtplq";;
      esac
    fi

    # Process potential multitask halting
    if [ "$D_ADDST_MLTSK_HALT" = true ]; then d__context -- pop; break; fi

    d__context -- pop

  # Done iterating over numbers of task names
  done; unset -f "$d__mtf" "$d__mtbf" "$d__mtaf"

  # Switch context
  d__context -- push 'Reconciling remove status of tasks'

  # Pass on add-statuses
  unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
  ((${#d__mas_a[@]})) && D_ADDST_ATTENTION=("${d__mas_a[@]}")
  ((${#d__mas_r[@]})) && D_ADDST_HELP=("${d__mas_r[@]}")
  ((${#d__mas_w[@]})) && D_ADDST_WARNING=("${d__mas_w[@]}")
  ((${#d__mas_c[@]})) && D_ADDST_CRITICAL=("${d__mas_c[@]}")
  unset D_ADDST_HALT; $d__mas_h && D_ADDST_HALT=true

  # Combine status codes
  d___reconcile_task_insrmv_codes; d__mrtc=$?
  d__context -- pop "Settled on multitask remove code '$d__mrtc'"

  # Run multitask post-processing, if implemented
  if declare -f d_mltsk_post_remove &>/dev/null; then
    unset D_ADDST_MLTSK_REMOVE_CODE; D__MLTSK_REMOVE_CODE="$d__mrtc"
    d_mltsk_post_remove; d__tmp=$?; unset -f d_mltsk_post_remove
    if (($d__tmp)); then
      d__notify -qh -- "Multitask's post-remove hook declares multitask" \
        "rejected instead of actual code '$d__mrtc'"
      d__context -- lop; return 2
    elif [[ $D_ADDST_MLTSK_REMOVE_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Multitask's post-remove hook forces" \
        "remove code '$D_ADDST_MLTSK_REMOVE_CODE'" \
        "instead of actual code '$d__mrtc'"
      d__context -- lop; return $D_ADDST_MLTSK_REMOVE_CODE
    fi
  fi

  d__context -- lop; return $d__mrtc
}

#>  d___reconcile_task_check_codes
#
## INTERNAL USE ONLY
#
## Tool that analyzes multiple check codes and combines them into one. If a 
#. leader task is detected, simply returns its check code.
#
## Local variables that need to be set in the calling context:
#>  $d__mas     - Array of all-statuses.
#>  $d__mss     - Array of some-statuses.
#
## Returns:
#.  The resulting combined code.
#
d___reconcile_task_check_codes()
{
  if [[ $D_MLTSK_LEADER =~ ^[0-9]+$ ]] \
    && ! [ -z ${D_MLTSK_MAIN[$D_MLTSK_LEADER]+isset} ] \
    && [[ ${D__MLTSK_CHECK_CODES[$D_MLTSK_LEADER]} =~ ^[0-9]+$ ]]
  then return ${D__MLTSK_CHECK_CODES[$D_MLTSK_LEADER]}; fi
  local i c=0; for ((i=0;i<10;++i)); do ${d__mas[$i]} && return $i; done
  for i in 0 1 2 4 5 6 7 8 9; do ${d__mss[$i]} && ((++c)); done
  case $c in
    1)  for i in 0 1 2 4 5 6 7 8 9; do ${d__mss[$i]} && return $i; done;;
    2)  if ${d__mss[1]}; then
          ${d__mss[2]} && return 4
          ${d__mss[4]} && return 4
          ${d__mss[5]} && return 5
          ${d__mss[7]} && return 1
          ${d__mss[8]} && return 4
        elif ${d__mss[2]}; then
          ${d__mss[4]} && return 4
          ${d__mss[7]} && return 8
          ${d__mss[8]} && return 8
          ${d__mss[9]} && return 9
        elif ${d__mss[4]}; then
          ${d__mss[7]} && return 4
          ${d__mss[8]} && return 4
        elif ${d__mss[7]}; then
          ${d__mss[8]} && return 8
        fi;;
    3)  if ${d__mss[2]} && ${d__mss[7]} && ${d__mss[8]}; then return 8; fi;;
  esac
  if ${d__mss[1]} || ${d__mss[4]}; then return 4; fi
  if ${d__mss[7]} || ${d__mss[8]}; then return 8; fi
  return 0
}

#>  d___reconcile_task_insrmv_codes
#
## INTERNAL USE ONLY
#
## Tool that analyzes multiple install/remove codes and combines them into one.
#
## Local variables that need to be set in the calling context:
#>  $d__mas     - Array of all-statuses.
#>  $d__mss     - Array of some-statuses.
#
## Returns:
#.  The resulting combined code.
#
d___reconcile_task_insrmv_codes()
{
  local i; for ((i=0;i<4;++i)); do ${d__mas[$i]} && return $i; done
  ${d__mss[1]} && return 1 || return 3
}