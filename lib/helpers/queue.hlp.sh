#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    Fix improper context manipulation in queues and mltsk
#:created_at:   2019.06.10

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Helper functions for deployments based on template 'queue.dpl.sh'
#

# Marker and dependencies
readonly D__HLP_QUEUE=loaded
d__load util workflow

d__queue_check()
{
  # Ensure the queue split point array is continuous
  local d__i; for ((d__i=0;d__i<${#D__QUEUE_SPLIT_POINTS[@]};++d__i)); do
    [ -z ${D__QUEUE_SPLIT_POINTS[$d__i]+isset} ] || continue
    d__notify -lxt 'Queue failed' -- \
      'Array $D__QUEUE_SPLIT_POINTS is not continuous'
    return 3
  done

  # Initialize or increment section number; switch context
  if [ -z ${D__QUEUE_SECTNUM[0]+isset} ]; then D__QUEUE_SECTNUM[0]=0
  else ((++D__QUEUE_SECTNUM[0])); fi; local d__qsi=${D__QUEUE_SECTNUM[0]}
  d__context -- notch
  d__context -- push "Checking queue within deployment" \
    "(queue section #$d__qsi)"

  # If case this queue section is a task in a multitask, mark the task as queue
  D__TASK_IS_QUEUE=true

  # Calculate low edge of queue section
  if [ $d__qsi -eq 0 ]; then D__QUEUE_SECTMIN=0
  elif [ -z ${D__QUEUE_SPLIT_POINTS[$d__qsi-1]+isset} ]; then
    d__fail -t 'Queue failed' -- "Queue section is not defined"; return 3
  else
    if [[ ${D__QUEUE_SPLIT_POINTS[$d__qsi-1]} =~ ^[0-9]+$ ]]
    then D__QUEUE_SECTMIN=${D__QUEUE_SPLIT_POINTS[$d__qsi-1]}
    else
      d__fail -t 'Queue failed' -- 'Invalid queue split point:' \
        "'${D__QUEUE_SPLIT_POINTS[$d__qsi-1]}'"
      return 3
    fi
  fi

  # Calculate high edge of queue section
  if [ -z ${D__QUEUE_SPLIT_POINTS[$d__qsi]+isset} ]
  then D__QUEUE_SECTMAX=${#D_QUEUE_MAIN[@]}
  else
    if [[ ${D__QUEUE_SPLIT_POINTS[$d__qsi]} =~ ^[0-9]+$ ]]
    then D__QUEUE_SECTMAX=${D__QUEUE_SPLIT_POINTS[$d__qsi]}
    else
      d__fail -t 'Queue failed' -- 'Invalid queue split point:' \
        "'${D__QUEUE_SPLIT_POINTS[$d__qsi]}'"
      return 3
    fi
  fi

  # Cut-off checks for number of items and continuity
  local d__qsl=$D__QUEUE_SECTMIN d__qsr=$D__QUEUE_SECTMAX
  if ((d__qsl==d__qsr)); then
    d__notify -t 'Skipping queue' -- 'Queue section is empty'
    return 3
  elif ((d__qsl>d__qsr)); then
    d__fail -t 'Queue failed' -- "Invalid section bounds: from $qsl to $qsr"
    return 3
  fi
  d__context -- push "Checking queue items $d__qsl-$((d__qsr-1))"
  for ((d__i=$d__qsl;d__i<$d__qsr;++d__i)); do
    [ -z ${D_QUEUE_MAIN[$d__i]+isset} ] || continue
    d__fail -t 'Queue failed' -- \
      'Array $D_QUEUE_MAIN is not continuous in the given section'
    return 3
  done

  # Run queue pre-processing, if implemented
  local d__qrtc d__tmp; if declare -f d_queue_pre_check &>/dev/null; then
    unset D_ADDST_QUEUE_CHECK_CODE D_ADDST_QUEUE_IRRELEVANT
    d_queue_pre_check; d__tmp=$?; unset -f d_queue_pre_check
    if (($d__tmp)) || [ "$D_ADDST_QUEUE_IRRELEVANT" = true ]; then
      d__notify -qh -- "Queue's pre-check hook declares queue irrelevant"
      d__context -- lop; return 3
    elif [[ $D_ADDST_QUEUE_CHECK_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue's pre-check hook forces" \
        "check code '$D_ADDST_QUEUE_CHECK_CODE'"
      d__context -- lop; return $D_ADDST_QUEUE_CHECK_CODE
    fi
  fi

  # Storage variables
  local d__qei d__qen d__qas d__qss d__qeplq d__qertc d__qeh d__qeflg
  local d__qas_a=() d__qas_r=() d__qas_w=() d__qas_c=()
  local d__qas_h=false d__qas_p=false

  # Initialize/reset status variables
  d__qas=( true true true true true true true true true true )
  d__qss=( false false false false false false false false false false )

  # Implement dummy primary and hooks if necessary
  if ! declare -f d_item_check &>/dev/null; then d_item_check() { :; }; fi
  if ! declare -f d_item_pre_check &>/dev/null
  then d_item_pre_check() { :; }; fi
  if ! declare -f d_item_post_check &>/dev/null
  then d_item_post_check() { :; }; fi

  # Iterate over numbers of item names
  for ((d__qei=$d__qsl;d__qei<$d__qsr;++d__qei)); do

    # Extract number, name; switch context
    d__qen="${D_QUEUE_MAIN[$d__qei]}"
    d__qeflg="${D__QUEUE_FLAGS[$d__qei]}"
    d__context -- push "Checking item #$d__qei '$d__qen'"

    # Initialize marker var; clear add-statuses
    unset D_ADDST_QUEUE_HALT D_ADDST_ITEM_CHECK_CODE
    unset D_ADDST_HALT D_ADDST_PROMPT
    unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

    # Expose additional variables to the item
    D__ITEM_NUM="$d__qei" D__ITEM_NAME="$d__qen" D__ITEM_FLAGS="$d__qeflg"

    # Run item pre-processing, if implemented
    unset D_ADDST_ITEM_FLAGS; d__qertc=0 d__qeh=false; d_item_pre_check
    if (($?)); then
      d__notify -qh -- "Queue item's pre-check hook declares item irrelevant"
      d__qertc=3 d__qeh=true
    elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue item's pre-check hook forces" \
        "check code '$D_ADDST_ITEM_CHECK_CODE'"
      d__qertc="$D_ADDST_ITEM_CHECK_CODE" d__qeh=true
    fi
    if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__qeh=true
      d__notify -qh -- "Queue item's pre-check hook forces queue halting"
    fi
    if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
      d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
      D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
    fi
    if [ "$D_ADDST_QUEUE_IRRELEVANT" = true ]; then
      d__notify -qh -- "Queue item's pre-check hook declares queue irrelevant"
      d__context -- lop
      return 3
    fi

    # Get return code of d_dpl_check, or fall back to zero
    if ! $d__qeh; then unset D_ADDST_ITEM_FLAGS; d_item_check; d__qertc=$?
      if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__qeh=true
        d__notify -qh -- "Queue item's checking forces queue halting"
      fi
      if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
        d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
        D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
      fi
      if [ "$D_ADDST_QUEUE_IRRELEVANT" = true ]; then
        d__notify -qh -- "Queue item's checking declares queue irrelevant"
        d__context -- lop
        return 3
      fi
    fi

    # Run item post-processing, if implemented
    if ! $d__qeh; then unset D_ADDST_ITEM_FLAGS
      D__ITEM_CHECK_CODE="$d__qertc"; d_item_post_check
      if (($?)); then
        d__notify -qh -- \
          "Queue item's post-check hook declares item irrelevant" \
          "instead of actual code '$d__qertc'"
        d__qertc=3
      elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
        d__notify -qh -- "Queue item's post-check hook forces" \
          "check code '$D_ADDST_ITEM_CHECK_CODE'" \
          "instead of actual code '$d__qertc'"
        d__qertc="$D_ADDST_ITEM_CHECK_CODE"
      fi
      if [ "$D_ADDST_QUEUE_HALT" = true ]; then
        d__notify -qh -- "Queue item's post-check hook forces queue halting"
      fi
      if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
        d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
        D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
      fi
      if [ "$D_ADDST_QUEUE_IRRELEVANT" = true ]; then
        d__notify -qh -- \
          "Queue item's post-check hook declares queue irrelevant"
          d__context -- lop
        return 3
      fi
    fi

    # Store return code
    D__QUEUE_CHECK_CODES[$d__qei]=$d__qertc

    # Catch add-statuses
    if ((${#D_ADDST_ATTENTION[@]}))
    then for d__i in "${D_ADDST_ATTENTION[@]}"; do d__qas_a+="$d__i"; done; fi
    if ((${#D_ADDST_HELP[@]}))
    then for d__i in "${D_ADDST_HELP[@]}"; do d__qas_r+="$d__i"; done; fi
    if ((${#D_ADDST_WARNING[@]}))
    then for d__i in "${D_ADDST_WARNING[@]}"; do d__qas_w+="$d__i"; done; fi
    if ((${#D_ADDST_CRITICAL[@]}))
    then for d__i in "${D_ADDST_CRITICAL[@]}"; do d__qas_c+="$d__i"; done; fi
    if [ "$D_ADDST_HALT" = true ]; then d__qas_h=true; fi
    if [ "$D_ADDST_PROMPT" = true ]; then d__qas_p=true; fi

    # Inspect return code; set statuses accordingly
    case $d__qertc in
      1)  for d__i in 0 2 3 4 5 6 7 8 9; do d__qas[$d__i]=false; done
          d__qss[1]=true;;
      2)  for d__i in 0 1 3 4 5 6 7 8 9; do d__qas[$d__i]=false; done
          d__qss[2]=true;;
      3)  for d__i in 0 1 2 4 5 6 7 8 9; do d__qas[$d__i]=false; done
          d__qss[3]=true;;
      4)  for d__i in 0 1 2 3 5 6 7 8 9; do d__qas[$d__i]=false; done
          d__qss[4]=true;;
      5)  for d__i in 0 1 2 3 4 6 7 8 9; do d__qas[$d__i]=false; done
          d__qss[5]=true;;
      6)  for d__i in 0 1 2 3 4 5 7 8 9; do d__qas[$d__i]=false; done
          d__qss[6]=true;;
      7)  for d__i in 0 1 2 3 4 5 6 8 9; do d__qas[$d__i]=false; done
          d__qss[7]=true;;
      8)  for d__i in 0 1 2 3 4 5 6 7 9; do d__qas[$d__i]=false; done
          d__qss[8]=true;;
      9)  for d__i in 0 1 2 3 4 5 6 7 8; do d__qas[$d__i]=false; done
          d__qss[9]=true;;
      *)  for d__i in 1 2 3 4 5 6 7 8 9; do d__qas[$d__i]=false; done
          d__qss[0]=true;;
    esac

    # If in check routine and being verbose, print status
    if [ "$D__REQ_ROUTINE" = check -a "$D__OPT_VERBOSITY" -gt 0 ]; then
      d__qeplq="Item #$d__qei '$d__qen'"
      d__qeplq+="$NORMAL"; case $d__qertc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_QCH_1" "$d__qeplq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_QCH_2" "$d__qeplq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_QCH_3" "$d__qeplq";;
        4)  printf >&2 '%s %s\n' "$D__INTRO_QCH_4" "$d__qeplq";;
        5)  printf >&2 '%s %s\n' "$D__INTRO_QCH_5" "$d__qeplq";;
        6)  printf >&2 '%s %s\n' "$D__INTRO_QCH_6" "$d__qeplq";;
        7)  printf >&2 '%s %s\n' "$D__INTRO_QCH_7" "$d__qeplq";;
        8)  printf >&2 '%s %s\n' "$D__INTRO_QCH_8" "$d__qeplq";;
        9)  printf >&2 '%s %s\n' "$D__INTRO_QCH_9" "$d__qeplq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_QCH_0" "$d__qeplq";;
      esac
    fi

    # Process potential queue halting
    if [ "$D_ADDST_QUEUE_HALT" = true ]
    then D__QUEUE_CAP_NUMS[$d__qsi]=$((d__qei+1)); d__context -- pop; break; fi

    d__context -- pop

  # Done iterating over numbers of item names
  done; unset -f d_item_check d_item_pre_check d_item_post_check

  # Switch context
  d__context -- push 'Reconciling check status of items'

  # Pass on add-statuses
  unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
  ((${#d__qas_a[@]})) && D_ADDST_ATTENTION=("${d__qas_a[@]}")
  ((${#d__qas_r[@]})) && D_ADDST_HELP=("${d__qas_r[@]}")
  ((${#d__qas_w[@]})) && D_ADDST_WARNING=("${d__qas_w[@]}")
  ((${#d__qas_c[@]})) && D_ADDST_CRITICAL=("${d__qas_c[@]}")
  unset D_ADDST_HALT; $d__qas_h && D_ADDST_HALT=true
  unset D_ADDST_PROMPT; $d__qas_p && D_ADDST_PROMPT=true

  # Combine check codes
  d___reconcile_item_check_codes; d__qrtc=$?
  d__context -- pop "Settled on queue check code '$d__qrtc'"

  # Run queue post-processing, if implemented
  if declare -f d_queue_post_check &>/dev/null; then
    unset D_ADDST_QUEUE_CHECK_CODE; D__QUEUE_CHECK_CODE="$d__qrtc"
    d_queue_post_check; d__tmp=$?; unset -f d_queue_post_check
    if (($d__tmp)) || [ "$D_ADDST_QUEUE_IRRELEVANT" = true ]; then
      d__notify -qh -- "Queue's post-check hook declares queue irrelevant"
      d__context -- lop; return 3
    elif [[ $D_ADDST_QUEUE_CHECK_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue's post-check hook forces" \
        "check code '$D_ADDST_QUEUE_CHECK_CODE'" \
        "instead of actual code '$d__qrtc'"
      d__context -- lop; return $D_ADDST_QUEUE_CHECK_CODE
    fi
  fi

  d__context -- lop; return $d__qrtc
}

d__queue_install()
{
  # Initialize or increment section number; switch context
  if [ -z ${D__QUEUE_SECTNUM[1]+isset} ]; then D__QUEUE_SECTNUM[1]=0
  else ((++D__QUEUE_SECTNUM[1])); fi; local d__qsi=${D__QUEUE_SECTNUM[1]}
  d__context -- notch
  d__context -- push "Installing queue within deployment" \
    "(queue section #$d__qsi)"

  # Calculate low edge of queue section
  if [ $d__qsi -eq 0 ]; then D__QUEUE_SECTMIN=0
  else D__QUEUE_SECTMIN=${D__QUEUE_SPLIT_POINTS[$d__qsi-1]}; fi

  # Calculate high edge of queue section
  if [[ -z ${D__QUEUE_SPLIT_POINTS[$d__qsi]+isset} ]]
  then D__QUEUE_SECTMAX=${#D_QUEUE_MAIN[@]}
  else D__QUEUE_SECTMAX=${D__QUEUE_SPLIT_POINTS[$d__qsi]}; fi

  # Switch context
  local d__qsl=$D__QUEUE_SECTMIN d__qsr=$D__QUEUE_SECTMAX
  d__context -- push "Installing queue items $d__qsl-$((d__qsr-1))"

  # Run queue pre-processing, if implemented
  local d__qrtc d__tmp; if declare -f d_queue_pre_install &>/dev/null; then
    unset D_ADDST_QUEUE_INSTALL_CODE
    d_queue_pre_install; d__tmp=$?; unset -f d_queue_pre_install
    if (($d__tmp)); then
      d__notify -qh -- "Queue's pre-install hook declares queue rejected"
      d__context -- lop; return 2
    elif [[ $D_ADDST_QUEUE_INSTALL_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue's pre-install hook forces" \
        "install code '$D_ADDST_QUEUE_INSTALL_CODE'"
      d__context -- lop; return $D_ADDST_QUEUE_INSTALL_CODE
    fi
  fi

  # Storage variables
  local d__qei d__qecap d__qen d__qertc d__qas d__qss d__i d__qeh d__qeflg
  local d__qas_a=() d__qas_r=() d__qas_w=() d__qas_c=() d__qas_h=false
  local d__qeplq d__qedfac d__qefrcd d__qecc d__qeok d__qeocc d__qeof

  # Initialize/reset status variables
  d__qas=( true true true true ) d__qss=( false false false false )
  if [ -z ${D__QUEUE_CAP_NUMS[$d__qsi]+isset} ]
  then d__qecap=$d__qsr
  else
    d__qecap="${D__QUEUE_CAP_NUMS[$d__qsi]}"
    d__notify -! -- "Not touching section elements #$d__qecap and above"
  fi

  # Implement dummy primary and hooks if necessary
  if ! declare -f d_item_install &>/dev/null; then d_item_install() { :; }; fi
  if ! declare -f d_item_pre_install &>/dev/null
  then d_item_pre_install() { :; }; fi
  if ! declare -f d_item_post_install &>/dev/null
  then d_item_post_install() { :; }; fi

  # Iterate over numbers of item names
  for ((d__qei=$d__qsl;d__qei<$d__qecap;++d__qei)); do

    # Extract number, name, and check code; compose item name; switch context
    d__qen="${D_QUEUE_MAIN[$d__qei]}"
    d__qecc="${D__QUEUE_CHECK_CODES[$d__qei]}"
    d__qeflg="${D__QUEUE_FLAGS[$d__qei]}"
    d__qeplq="#$d__qei '$d__qen'"
    d__context -- push "Installing item $d__qeplq"
    d__qeplq="Item $d__qeplq$NORMAL"

    # Pre-set statuses; conditionally print intro; inspect check code
    d__qedfac=false d__qefrcd=false d__qeok=true
    case $d__qecc in
      1)  # Fully installed
          if $D__OPT_FORCE; then d__qefrcd=true
            printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
            d__notify -l! -- \
              "Item '$d__qen' appears to be already installed"
          else d__qeok=false
            (($D__OPT_VERBOSITY)) \
              && printf >&2 '%s %s\n' "$D__INTRO_QIN_A" "$d__qeplq"
          fi;;
      2)  # Fully not installed
          :;;
      3)  # Irrelevant or invalid
          (($D__OPT_VERBOSITY)) \
            && printf >&2 '%s %s\n' "$D__INTRO_QCH_3" "$d__qeplq"
          d__qeok=false;;
      4)  # Partly installed
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
          d__notify -l! -- "Item '$d__qen' appears to be partly installed"
          d__qedfac=true; if $D__OPT_FORCE; then d__qefrcd=true; fi;;
      5)  # Likely installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
          d__notify -l! -- \
            "Item '$d__qen' is recorded as previously installed" \
            -n- 'but there is no way to confirm that it is indeed installed'
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_5" "$d__qeplq"
          fi;;
      6)  # Manually removed (tinkered with)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
          d__notify -lx -- \
            "Item '$d__qen' is recorded as previously installed" \
            -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
            -n- '(which may be due to manual tinkering)'
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QIN_S" "$d__qeplq"
          fi;;
      7)  # Fully installed (by user or OS)
          d__msg=( "Item '$d__qen' appears to be fully installed" \
            'by means other than installing this deployment' )
          if $D__OPT_FORCE; then d__qefrcd=true
            printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
            d__notify -l! -- "${d__msg[@]}"
          else d__qeok=false
            if (($D__OPT_VERBOSITY)); then
              printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
              d__notify -q! -- "${d__msg[@]}"
              d__notify -q! -- 'Re-try with --force to overcome'
              printf >&2 '%s %s\n' "$D__INTRO_QCH_7" "$d__qeplq"
            fi
          fi;;
      8)  # Partly installed (by user or OS)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
          d__notify -l! -- "Item '$d__qen' appears to be partly installed" \
            'by means other than installing this deployment'
          d__qedfac=true; if $D__OPT_FORCE; then d__qefrcd=true; fi;;
      9)  # Likely not installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QIN_N" "$d__qeplq"
          d__notify -l! -- "Item '$d__qen' is ${BOLD}not$NORMAL recorded" \
            'as previously installed' -n- 'but there is no way to confirm' \
            "that it is indeed ${BOLD}not$NORMAL installed"
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_9" "$d__qeplq"
          fi;;
      *)  # Truly unknown
          :;;
    esac

    # If forcing, print a forceful intro
    $d__qeok && $d__qefrcd \
      && printf >&2 '%s %s\n' "$D__INTRO_QIN_F" "$d__qeplq"

    # Re-prompt if action differs depending on force or if forcing
    if $d__qeok && ( $d__qedfac || $d__qefrcd ); then
      if $d__qedfac; then printf >&2 '%s %s\n' "$D__INTRO_ATTNT" \
        'In this status, installation may differ with and without --force'; fi
      if $d__qefrcd; then printf >&2 '%s ' "$D__INTRO_CNF_U"
      else printf >&2 '%s ' "$D__INTRO_CNF_N"; fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_QIN_S" "$d__qeplq"; d__qeok=false
      fi
    fi

    # Shared cut-off for skipping current item
    if ! $d__qeok; then
      d__context -- pop
      continue
    fi

    # Initialize marker var; clear add-statuses
    unset D_ADDST_QUEUE_HALT D_ADDST_HALT D_ADDST_ITEM_INSTALL_CODE
    unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

    # Expose additional variables to the item
    D__ITEM_NUM="$d__qei" D__ITEM_NAME="$d__qen" D__ITEM_FLAGS="$d__qeflg"
    D__ITEM_CHECK_CODE="$d__qecc" D__ITEM_IS_FORCED="$d__qefrcd"
    d__qeocc="$D__DPL_CHECK_CODE" d__qeof="$D__DPL_IS_FORCED"
    D__DPL_CHECK_CODE="$d__qecc" D__DPL_IS_FORCED="$d__qefrcd"

    # Run item pre-processing, if implemented
    unset D_ADDST_ITEM_FLAGS; d__qertc=0 d__qeh=false; d_item_pre_install
    if (($?)); then
      d__notify -qh -- "Queue item's pre-install hook declares item rejected"
      d__qertc=2 d__qeh=true
    elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue item's pre-install hook forces" \
        "install code '$D_ADDST_ITEM_INSTALL_CODE'"
      d__qertc="$D_ADDST_ITEM_INSTALL_CODE" d__qeh=true
    fi
    if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__qeh=true
      d__notify -qh -- "Queue item's pre-install hook forces queue halting"
    fi
    if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
      d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
      D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
    fi

    # Get return code of d_dpl_install, or fall back to zero
    if ! $d__qeh; then unset D_ADDST_ITEM_FLAGS; d_item_install; d__qertc=$?
      if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__qeh=true
        d__notify -qh -- "Queue item's installation forces queue halting"
      fi
      if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
        d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
        D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
      fi
    fi

    # Run item post-processing, if implemented
    if ! $d__qeh; then unset D_ADDST_ITEM_FLAGS
      D__ITEM_INSTALL_CODE="$d__qertc"; d_item_post_install
      if (($?)); then
        d__notify -qh -- \
          "Queue item's post-install hook declares item rejected" \
          "instead of actual code '$d__qertc'"
        d__qertc=2
      elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
        d__notify -qh -- "Queue item's post-install hook forces" \
          "install code '$D_ADDST_ITEM_INSTALL_CODE'" \
          "instead of actual code '$d__qertc'"
        d__qertc="$D_ADDST_ITEM_INSTALL_CODE"
      fi
      if [ "$D_ADDST_QUEUE_HALT" = true ]; then
        d__notify -qh -- "Queue item's post-install hook forces queue halting"
      fi
      if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
        d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
        D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
      fi
    fi

    # Store return code
    D__QUEUE_INSTALL_CODES[$d__qei]=$d__qertc

    # Restore overwritten deployment-level variables
    D__DPL_CHECK_CODE="$d__qeocc" D__DPL_IS_FORCED="$d__qeof"

    # Catch add-statuses
    if ((${#D_ADDST_ATTENTION[@]}))
    then for d__i in "${D_ADDST_ATTENTION[@]}"; do d__qas_a+="$d__i"; done; fi
    if ((${#D_ADDST_HELP[@]}))
    then for d__i in "${D_ADDST_HELP[@]}"; do d__qas_r+="$d__i"; done; fi
    if ((${#D_ADDST_WARNING[@]}))
    then for d__i in "${D_ADDST_WARNING[@]}"; do d__qas_w+="$d__i"; done; fi
    if ((${#D_ADDST_CRITICAL[@]}))
    then for d__i in "${D_ADDST_CRITICAL[@]}"; do d__qas_c+="$d__i"; done; fi
    if [ "$D_ADDST_HALT" = true ]; then d__qas_h=true; fi

    # Inspect return code; set statuses accordingly
    case $d__qertc in
      1)  for d__i in 0 2 3; do d__qas[$d__i]=false; done; d__qss[1]=true;;
      2)  for d__i in 0 1 3; do d__qas[$d__i]=false; done; d__qss[2]=true;;
      3)  for d__i in 0 1 2; do d__qas[$d__i]=false; done; d__qss[3]=true;;
      *)  for d__i in 1 2 3; do d__qas[$d__i]=false; done; d__qss[0]=true;;
    esac

    # If in there has been some output, print status
    if (($D__OPT_VERBOSITY)) || $d__qefrcd || $d__qedfac; then
      case $d__qertc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_QIN_1" "$d__qeplq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_QIN_2" "$d__qeplq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_QIN_3" "$d__qeplq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_QIN_0" "$d__qeplq";;
      esac
    fi

    # Process potential queue halting
    if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__context -- pop; break; fi

    d__context -- pop

  # Done iterating over numbers of item names
  done; unset -f d_item_install d_item_pre_install d_item_post_install

  # Switch context
  d__context -- push 'Reconciling install status of items'

  # Pass on add-statuses
  unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
  ((${#d__qas_a[@]})) && D_ADDST_ATTENTION=("${d__qas_a[@]}")
  ((${#d__qas_r[@]})) && D_ADDST_HELP=("${d__qas_r[@]}")
  ((${#d__qas_w[@]})) && D_ADDST_WARNING=("${d__qas_w[@]}")
  ((${#d__qas_c[@]})) && D_ADDST_CRITICAL=("${d__qas_c[@]}")
  unset D_ADDST_HALT; $d__qas_h && D_ADDST_HALT=true

  # Combine status codes
  d___reconcile_item_insrmv_codes; d__qrtc=$?
  d__context -- pop "Settled on queue install code '$d__qrtc'"

  # Run queue post-processing, if implemented
  if declare -f d_queue_post_install &>/dev/null; then
    unset D_ADDST_QUEUE_INSTALL_CODE; D__QUEUE_INSTALL_CODE="$d__qrtc"
    d_queue_post_install; d__tmp=$?; unset -f d_queue_post_install
    if (($d__tmp)); then
      d__notify -qh -- "Queue's post-install hook declares queue rejected"
      d__context -- lop; return 2
    elif [[ $D_ADDST_QUEUE_INSTALL_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue's post-install hook forces" \
        "install code '$D_ADDST_QUEUE_INSTALL_CODE'" \
        "instead of actual code '$d__qrtc'"
      d__context -- lop; return $D_ADDST_QUEUE_INSTALL_CODE
    fi
  fi

  d__context -- lop; return $d__qrtc
}

d__queue_remove()
{
  # Initialize or decrement section number; switch context
  if [ -z ${D__QUEUE_SECTNUM[1]+isset} ]
  then D__QUEUE_SECTNUM[1]=${#D__QUEUE_SPLIT_POINTS[@]}
  else ((--D__QUEUE_SECTNUM[1])); fi; local d__qsi=${D__QUEUE_SECTNUM[1]}
  d__context -- notch
  d__context -- push "Removing queue within deployment" \
    "(queue section #$d__qsi)"

  # Calculate low edge of queue section
  if [ $d__qsi -eq 0 ]; then D__QUEUE_SECTMIN=0
  else D__QUEUE_SECTMIN=${D__QUEUE_SPLIT_POINTS[$d__qsi-1]}; fi

  # Calculate high edge of queue section
  if [[ -z ${D__QUEUE_SPLIT_POINTS[$d__qsi]+isset} ]]
  then D__QUEUE_SECTMAX=${#D_QUEUE_MAIN[@]}
  else D__QUEUE_SECTMAX=${D__QUEUE_SPLIT_POINTS[$d__qsi]}; fi

  # Switch context
  local d__qsl=$D__QUEUE_SECTMIN d__qsr=$D__QUEUE_SECTMAX
  d__context -- push "Removing queue items $d__qsl-$((d__qsr-1))"

  # Run queue pre-processing, if implemented
  local d__qrtc d__tmp; if declare -f d_queue_pre_remove &>/dev/null; then
    unset D_ADDST_QUEUE_REMOVE_CODE
    d_queue_pre_remove; d__tmp=$?; unset -f d_queue_pre_remove
    if (($d__tmp)); then
      d__notify -qh -- "Queue's pre-remove hook declares queue rejected"
      d__context -- lop; return 2
    elif [[ $D_ADDST_QUEUE_REMOVE_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue's pre-remove hook forces" \
        "remove code '$D_ADDST_QUEUE_REMOVE_CODE'"
      d__context -- lop; return $D_ADDST_QUEUE_REMOVE_CODE
    fi
  fi

  # Storage variables
  local d__qei d__qecap d__qen d__qertc d__qas d__qss d__i d__qeh d__qeflg
  local d__qas_a=() d__qas_r=() d__qas_w=() d__qas_c=() d__qas_h=false
  local d__qeplq d__qeabn d__qefrcd d__qecc d__qeok d__qeocc d__qeof

  # Initialize/reset status variables
  d__qas=( true true true true ) d__qss=( false false false false )
  if [ -z ${D__QUEUE_CAP_NUMS[$d__qsi]+isset} ]
  then d__qecap=$d__qsr
  else
    d__qecap="${D__QUEUE_CAP_NUMS[$d__qsi]}"
    d__notify -! -- "Not touching section elements #$d__qecap and above"
  fi

  # Implement dummy primary and hooks if necessary
  if ! declare -f d_item_remove &>/dev/null; then d_item_remove() { :; }; fi
  if ! declare -f d_item_pre_remove &>/dev/null
  then d_item_pre_remove() { :; }; fi
  if ! declare -f d_item_post_remove &>/dev/null
  then d_item_post_remove() { :; }; fi

  # Iterate over numbers of item names
  for ((d__qei=$d__qecap-1;d__qei>=$d__qsl;--d__qei)); do

    # Extract number, name, and check code; compose item name; switch context
    d__qen="${D_QUEUE_MAIN[$d__qei]}"
    d__qecc="${D__QUEUE_CHECK_CODES[$d__qei]}"
    d__qeflg="${D__QUEUE_FLAGS[$d__qei]}"
    d__qeplq="#$d__qei '$d__qen'"
    d__context -- push "Removing item $d__qeplq"
    d__qeplq="Item $d__qeplq$NORMAL"

    # Pre-set statuses; conditionally print intro; inspect check code
    d__qeabn=false d__qefrcd=false d__qeok=true
    case $d__qecc in
      1)  # Fully installed
          :;;
      2)  # Fully not installed
          if $D__OPT_FORCE; then d__qefrcd=true
            printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
            d__notify -l! -- \
              "Item '$d__qen' appears to be already not installed"
          else d__qeok=false
            (($D__OPT_VERBOSITY)) \
              && printf >&2 '%s %s\n' "$D__INTRO_QRM_A" "$d__qeplq"
          fi;;
      3)  # Irrelevant or invalid
          (($D__OPT_VERBOSITY)) \
            && printf >&2 '%s %s\n' "$D__INTRO_QCH_3" "$d__qeplq"
          d__qeok=false;;
      4)  # Partly installed
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
          d__notify -l! -- \
            "Item '$d__qen' appears to be only partly installed"
          d__qeabn=true;;
      5)  # Likely installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
          d__notify -l! -- \
            "Item '$d__qen' is recorded as previously installed" \
            -n- 'but there is no way to confirm that it is indeed installed'
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_5" "$d__qeplq"
          fi;;
      6)  # Manually removed (tinkered with)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
          d__notify -lx -- \
            "Item '$d__qen' is recorded as previously installed" \
            -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
            -n- '(which may be due to manual tinkering)'
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QRM_S" "$d__qeplq"
          fi;;
      7)  # Fully installed (by user or OS)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
          d__notify -l! -- "Item '$d__qen' appears to be fully installed" \
            'by means other than installing this deployment'
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_7" "$d__qeplq"
          fi;;
      8)  # Partly installed (by user or OS)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
          d__notify -l! -- "Item '$d__qen' appears to be partly installed" \
            'by means other than installing this deployment'
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_8" "$d__qeplq"
          fi;;
      9)  # Likely not installed (unknown)
          printf >&2 '%s %s\n' "$D__INTRO_QRM_N" "$d__qeplq"
          d__notify -l! -- "Item '$d__qen' is ${BOLD}not$NORMAL recorded" \
            'as previously installed' -n- 'but there is no way to confirm' \
            "that it is indeed ${BOLD}not$NORMAL installed"
          if $D__OPT_FORCE; then d__qefrcd=true
          else d__qeok=false
            d__notify -l! -- 'Re-try with --force to overcome'
            printf >&2 '%s %s\n' "$D__INTRO_QCH_9" "$d__qeplq"
          fi;;
      *)  # Truly unknown
          :;;
    esac

    # If forcing, print a forceful intro and re-prompt
    if $d__qeok && $d__qefrcd; then
      printf >&2 '%s %s\n' "$D__INTRO_QRM_F" "$d__qeplq"
      printf >&2 '%s ' "$D__INTRO_CNF_U"
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_QRM_S" "$d__qeplq"; d__qeok=false
      fi
    fi

    # Shared cut-off for skipping current item
    if ! $d__qeok; then
      d__context -- pop
      continue
    fi

    # Initialize marker var; clear add-statuses
    unset D_ADDST_QUEUE_HALT D_ADDST_HALT D_ADDST_ITEM_REMOVE_CODE
    unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL

    # Expose additional variables to the item
    D__ITEM_NUM="$d__qei" D__ITEM_NAME="$d__qen" D__ITEM_FLAGS="$d__qeflg"
    D__ITEM_CHECK_CODE="$d__qecc" D__ITEM_IS_FORCED="$d__qefrcd"
    d__qeocc="$D__DPL_CHECK_CODE" d__qeof="$D__DPL_IS_FORCED"
    D__DPL_CHECK_CODE="$d__qecc" D__DPL_IS_FORCED="$d__qefrcd"

    # Run item pre-processing, if implemented
    unset D_ADDST_ITEM_FLAGS; d__qertc=0 d__qeh=false; d_item_pre_remove
    if (($?)); then
      d__notify -qh -- "Queue item's pre-remove hook declares item rejected"
      d__qertc=2 d__qeh=true
    elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue item's pre-remove hook forces" \
        "remove code '$D_ADDST_ITEM_REMOVE_CODE'"
      d__qertc="$D_ADDST_ITEM_REMOVE_CODE" d__qeh=true
    fi
    if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__qeh=true
      d__notify -qh -- "Queue item's pre-remove hook forces queue halting"
    fi
    if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
      d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
      D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
    fi

    # Get return code of d_dpl_remove, or fall back to zero
    if ! $d__qeh; then unset D_ADDST_ITEM_FLAGS; d_item_remove; d__qertc=$?
      if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__qeh=true
        d__notify -qh -- "Queue item's removing forces queue halting"
      fi
      if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
        d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
        D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
      fi
    fi

    # Run item post-processing, if implemented
    if ! $d__qeh; then unset D_ADDST_ITEM_FLAGS
      D__ITEM_INSTALL_CODE="$d__qertc"; d_item_post_remove
      if (($?)); then
        d__notify -qh -- "Queue item's post-remove hook declares item rejected" \
          "instead of actual code '$d__qertc'"
        d__qertc=2
      elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
        d__notify -qh -- "Queue item's post-remove hook forces" \
          "remove code '$D_ADDST_ITEM_REMOVE_CODE'" \
          "instead of actual code '$d__qertc'"
        d__qertc="$D_ADDST_ITEM_REMOVE_CODE"
      fi
      if [ "$D_ADDST_QUEUE_HALT" = true ]; then
        d__notify -qh -- "Queue item's post-remove hook forces queue halting"
      fi
      if ! [ -z ${D_ADDST_ITEM_FLAGS+isset} ]; then
        d__qeflg+="$D_ADDST_ITEM_FLAGS" D__ITEM_FLAGS+="$D_ADDST_ITEM_FLAGS"
        D__QUEUE_FLAGS[$d__qei]+="$D_ADDST_ITEM_FLAGS"
      fi
    fi

    # Store return code
    D__QUEUE_REMOVE_CODES[$d__qei]=$d__qertc

    # Restore overwritten deployment-level variables
    D__DPL_CHECK_CODE="$d__qeocc" D__DPL_IS_FORCED="$d__qeof"

    # Catch add-statuses
    if ((${#D_ADDST_ATTENTION[@]}))
    then for d__i in "${D_ADDST_ATTENTION[@]}"; do d__qas_a+="$d__i"; done; fi
    if ((${#D_ADDST_HELP[@]}))
    then for d__i in "${D_ADDST_HELP[@]}"; do d__qas_r+="$d__i"; done; fi
    if ((${#D_ADDST_WARNING[@]}))
    then for d__i in "${D_ADDST_WARNING[@]}"; do d__qas_w+="$d__i"; done; fi
    if ((${#D_ADDST_CRITICAL[@]}))
    then for d__i in "${D_ADDST_CRITICAL[@]}"; do d__qas_c+="$d__i"; done; fi
    if [ "$D_ADDST_HALT" = true ]; then d__qas_h=true; fi

    # Inspect return code; set statuses accordingly
    case $d__qertc in
      1)  for d__i in 0 2 3; do d__qas[$d__i]=false; done; d__qss[1]=true;;
      2)  for d__i in 0 1 3; do d__qas[$d__i]=false; done; d__qss[2]=true;;
      3)  for d__i in 0 1 2; do d__qas[$d__i]=false; done; d__qss[3]=true;;
      *)  for d__i in 1 2 3; do d__qas[$d__i]=false; done; d__qss[0]=true;;
    esac

    # If in there has been some output, print status
    if (($D__OPT_VERBOSITY)) || $d__qefrcd || $d__qeabn; then
      case $d__qertc in
        1)  printf >&2 '%s %s\n' "$D__INTRO_QRM_1" "$d__qeplq";;
        2)  printf >&2 '%s %s\n' "$D__INTRO_QRM_2" "$d__qeplq";;
        3)  printf >&2 '%s %s\n' "$D__INTRO_QRM_3" "$d__qeplq";;
        *)  printf >&2 '%s %s\n' "$D__INTRO_QRM_0" "$d__qeplq";;
      esac
    fi

    # Process potential queue halting
    if [ "$D_ADDST_QUEUE_HALT" = true ]; then d__context -- pop; break; fi

    d__context -- pop

  # Done iterating over numbers of item names
  done; unset -f d_item_remove d_item_pre_remove d_item_post_remove

  # Switch context
  d__context -- push 'Reconciling remove status of items'

  # Pass on add-statuses
  unset D_ADDST_ATTENTION D_ADDST_HELP D_ADDST_WARNING D_ADDST_CRITICAL
  ((${#d__qas_a[@]})) && D_ADDST_ATTENTION=("${d__qas_a[@]}")
  ((${#d__qas_r[@]})) && D_ADDST_HELP=("${d__qas_r[@]}")
  ((${#d__qas_w[@]})) && D_ADDST_WARNING=("${d__qas_w[@]}")
  ((${#d__qas_c[@]})) && D_ADDST_CRITICAL=("${d__qas_c[@]}")
  unset D_ADDST_HALT; $d__qas_h && D_ADDST_HALT=true

  # Combine status codes
  d___reconcile_item_insrmv_codes; d__qrtc=$?
  d__context -- pop "Settled on queue remove code '$d__qrtc'"

  # Run queue post-processing, if implemented
  if declare -f d_queue_post_remove &>/dev/null; then
    unset D_ADDST_QUEUE_REMOVE_CODE; D__QUEUE_REMOVE_CODE="$d__qrtc"
    d_queue_post_remove; d__tmp=$?; unset -f d_queue_post_remove
    if (($d__tmp)); then
      d__notify -qh -- "Queue's post-remove hook declares queue rejected"
      d__context -- lop; return 2
    elif [[ $D_ADDST_QUEUE_REMOVE_CODE =~ ^[0-9]+$ ]]; then
      d__notify -qh -- "Queue's post-remove hook forces" \
        "remove code '$D_ADDST_QUEUE_REMOVE_CODE'" \
        "instead of actual code '$d__qrtc'"
      d__context -- lop; return $D_ADDST_QUEUE_REMOVE_CODE
    fi
  fi

  d__context -- lop; return $d__qrtc
}

#>  d___reconcile_item_check_codes
#
## INTERNAL USE ONLY
#
## Tool that analyzes multiple check codes and combines them into one.
#
## Local variables that need to be set in the calling context:
#>  $d__qas     - Array of all-statuses.
#>  $d__qss     - Array of some-statuses.
#
## Returns:
#.  The resulting combined code.
#
d___reconcile_item_check_codes()
{
  local i c=0; for ((i=0;i<10;++i)); do ${d__qas[$i]} && return $i; done
  for i in 0 1 2 4 5 6 7 8 9; do ${d__qss[$i]} && ((++c)); done
  case $c in
    1)  for i in 0 1 2 4 5 6 7 8 9; do ${d__qss[$i]} && return $i; done;;
    2)  if ${d__qss[1]}; then
          ${d__qss[2]} && return 4
          ${d__qss[4]} && return 4
          ${d__qss[5]} && return 5
          ${d__qss[7]} && return 1
          ${d__qss[8]} && return 4
        elif ${d__qss[2]}; then
          ${d__qss[4]} && return 4
          ${d__qss[7]} && return 8
          ${d__qss[8]} && return 8
          ${d__qss[9]} && return 9
        elif ${d__qss[4]}; then
          ${d__qss[7]} && return 4
          ${d__qss[8]} && return 4
        elif ${d__qss[7]}; then
          ${d__qss[8]} && return 8
        fi;;
    3)  if ${d__qss[2]} && ${d__qss[7]} && ${d__qss[8]}; then return 8; fi;;
  esac
  if ! ( ${d__qss[0]} || ${d__qss[5]} || ${d__qss[6]} || ${d__qss[9]} )
  then return 4; fi
  return 0
}

#>  d___reconcile_item_insrmv_codes
#
## INTERNAL USE ONLY
#
## Tool that analyzes multiple install/remove codes and combines them into one.
#
## Local variables that need to be set in the calling context:
#>  $d__qas     - Array of all-statuses.
#>  $d__qss     - Array of some-statuses.
#
## Returns:
#.  The resulting combined code.
#
d___reconcile_item_insrmv_codes()
{
  local i; for ((i=0;i<4;++i)); do ${d__qas[$i]} && return $i; done
  ${d__qss[1]} && return 1 || return 3
}

#>  d__queue_split [POSITION]
#
## Adds a separation point into the queue either at current length (to continue 
#. populating the next section of the queue), or at a given length. Queue 
#. helpers process first available queue segment and move to the next one only 
#. on next iteration.
#
d__queue_split()
{
  local pos; if ! [[ $1 =~ ^[0-9]+$ ]] || [ $1 -gt ${#D_QUEUE_MAIN[@]} ]
  then pos=${#D_QUEUE_MAIN[@]}; else pos=$1; fi
  D__QUEUE_SPLIT_POINTS+=($pos)
}

#>  d__queue_target [--section SECTNUM] [--] TARGET_DIR
#
## Interprets the queue determinant $D_QUEUE_MAIN as array of relative paths. 
#. Populates the array $D_QUEUE_TARGETS with the absolute versions of those 
#. paths, with the TARGET_DIR path prepended. The TARGET_DIR value is assumed 
#. to be an absolute path to a directory (not necessarily an existing one). If 
#. the SECTNUM is given, operates on that section of the queue; otherwise, 
#. operates on the latest section.
#
d__queue_target()
{
  # Pluck out options, round up arguments
  local args=() arg tgtd sectnum qsl qsr ii plq; unset sectnum
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          s|-section) if (($#)); then sectnum="$1"; shift; fi;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                s)  if (($#)); then sectnum="$1"; shift; fi;;
                *)  :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Extract and validate target directory
  if ! ((${#args[@]})); then
    d__notify -lxt 'Auto-targeting failed' -- \
      "Called without the target directory"
    return 1
  fi
  tgtd="${args[0]}"
  if [ -z "$tgtd" ]; then
    d__notify -lxt 'Auto-targeting failed' -- \
      "Called with an empty target directory"
    return 1
  fi
  while [[ $tgtd = */ ]]; do tgtd="${tgtd%%/}"; done

  # Extract and validate section number, if any
  if [ -z "${sectnum+isset}" ]; then

    # No section number: work with entire queue
    plq='queue' qsl=0 qsr=${#D_QUEUE_MAIN[@]}

  else

    # Section given
    plq="queue section #$sectnum"

    # Ensure the queue split point array is continuous
    for ((ii=0;ii<${#D__QUEUE_SPLIT_POINTS[@]};++ii)); do
      [ -z ${D__QUEUE_SPLIT_POINTS[$ii]+isset} ] || continue
      d__notify -lxt 'Auto-targeting failed' -- \
        'Array $D__QUEUE_SPLIT_POINTS is not continuous'
      return 1
    done

    # Validate section number
    if ! [[ $sectnum =~ ^[0-9]+$ ]]; then
      d__notify -lxt 'Auto-targeting failed' -- \
        "Invalid section number '$sectnum'"
      return 1
    fi

    # Calculate low edge of queue section
    if [ $sectnum -eq 0 ]; then qsl=0
    elif [ -z ${D__QUEUE_SPLIT_POINTS[$sectnum-1]+isset} ]; then
      d__notify -lxt 'Auto-targeting failed' -- \
        "Queue section #$sectnum is not defined"
      return 1
    else
      if [[ ${D__QUEUE_SPLIT_POINTS[$sectnum-1]} =~ ^[0-9]+$ ]]
      then qsl=${D__QUEUE_SPLIT_POINTS[$sectnum-1]}
      else
        d__notify -lxt 'Auto-targeting failed' -- \
          'Invalid queue split point:' \
          "'${D__QUEUE_SPLIT_POINTS[$sectnum-1]}'"
        return 1
      fi
    fi

    # Calculate high edge of queue section
    if [ -z ${D__QUEUE_SPLIT_POINTS[$sectnum]+isset} ]
    then qsr=${#D_QUEUE_MAIN[@]}
    else
      if [[ ${D__QUEUE_SPLIT_POINTS[$sectnum]} =~ ^[0-9]+$ ]]
      then qsr=${D__QUEUE_SPLIT_POINTS[$sectnum]}
      else
        d__notify -lxt 'Auto-targeting failed' -- \
          'Invalid queue split point:' \
          "'${D__QUEUE_SPLIT_POINTS[$sectnum]}'"
        return 1
      fi
    fi
  
  # Done extracting and validating section limits
  fi

  # Cut-off checks for number of items and continuity
  if ((qsl==qsr)); then
    d__notify -t 'Refusing to auto-target' -- "Empty $plq"
    return 1
  elif ((qsl>qsr)); then
    d__notify -lxt 'Auto-targeting failed' -- \
      "Invalid bounds of $plq: from $qsl to $qsr"
    return 1
  fi
  d__context -- notch
  d__context -- push "Auto-targeting $plq items $qsl-$((qsr-1))"
  d__context -- push "Target directory: $tgtd"
  for ((ii=$qsl;ii<$qsr;++ii)); do
    [ -z ${D_QUEUE_MAIN[$ii]+isset} ] || continue
    local errm=; [ -z ${sectnum+isset} ] || errm+=' in the given section'
    d__fail -t 'Auto-targeting failed' -- \
      "Array \$D_QUEUE_MAIN is not continuous$errm"
    return 1
  done

  # Populate targets (I shaved my legs for THIS?)
  for ((ii=$qsl;ii<$qsr;++ii))
  do D_QUEUE_TARGETS[$ii]="$tgtd/${D_QUEUE_MAIN[$ii]}"; done
  d__context -- lop; return 0
}