#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: copy-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.19
#:revremark:    Make auto-targeting explicit via function
#:created_at:   2019.05.23

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'copy-queue.dpl.sh'
#
## Copies arbitrary files (e.g., font files) to provided locations (e.g., into 
#. OS's fonts directory). Creates backup of each replaced file. Restores 
#. original set-up on removal.
#

# Marker and dependencies
readonly D__HLP_COPY_QUEUE=loaded
d__load util workflow
d__load procedure detect-os
d__load procedure prep-md5
d__load util stash

d__copy_queue_check()
{
  d_queue_pre_check()     { d__copy_queue_pre_check;  }
  d_item_pre_check()      { d_copy_item_pre_check;   }
  d_item_check()          { d__copy_item_check;       }
  d_item_post_check()     { d_copy_item_post_check;  }
  d_queue_post_check()    { d__copy_queue_post_check; }
  d__queue_check
}

d__copy_queue_install()
{
  d_queue_pre_install()   { d__copy_queue_pre_install;  }
  d_item_pre_install()    { d_copy_item_pre_install;   }
  d_item_install()        { d__copy_item_install;       }
  d_item_post_install()   { d_copy_item_post_install;  }
  d_queue_post_install()  { d__copy_queue_post_install; }
  d__queue_install
}

d__copy_queue_remove()
{
  d_queue_pre_remove()    { d__copy_queue_pre_remove;   }
  d_item_pre_remove()     { d_copy_item_pre_remove;    }
  d_item_remove()         { d__copy_item_remove;        }
  d_item_post_remove()    { d_copy_item_post_remove;   }
  d_queue_post_remove()   { d__copy_queue_post_remove;  }
  d__queue_remove
}

d__copy_queue_pre_check()
{
  # Switch context; prepare stash; apply adapter overrides
  d__context -- push 'Preparing copy-queue for checking'
  d__stash -- ready || return 1

  # Ensure the required arrays are continuous at the given section
  local d__i; for ((d__i=$D__QUEUE_SECTMIN;d__i<$D__QUEUE_SECTMAX;++d__i)); do
    if [ -z ${D_QUEUE_ASSETS[$d__i]+isset} ]; then
      d__notify -lxht 'Copy-queue failed' -- \
        'Array $D_QUEUE_ASSETS is not continuous in the given section'
      return 1
    fi
    if [ -z ${D_QUEUE_TARGETS[$d__i]+isset} ]; then
      d__notify -lxht 'Copy-queue failed' -- \
        'Array $D_QUEUE_TARGETS is not continuous in the given section'
      return 1
    fi
  done

  # Run queue pre-processing, if implemented
  local d__rtc=0; if declare -f d_copy_queue_pre_check &>/dev/null
  then d_copy_queue_pre_check; d__rtc=$?; unset -f d_copy_queue_pre_check; fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_copy_item_pre_check &>/dev/null
  then d_copy_item_pre_check() { :; }; fi
  if ! declare -f d_copy_item_post_check &>/dev/null
  then d_copy_item_post_check() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__copy_item_check()
{
  # Init storage variables; switch context
  local d__cqei="$D__ITEM_NUM" d__cqrtc= d__cqer=()
  local d__cqea="${D_QUEUE_ASSETS[$d__cqei]}"
  local d__cqet="${D_QUEUE_TARGETS[$d__cqei]}"
  local d__cqesk="copy_$( dmd5 -s "$d__cqet" )"
  local d__cqeb="$D__DPL_BACKUP_DIR/$d__cqesk"
  local d__cqexct=false
  if [ "$D_ADDST_COPY_QUEUE_EXACT" = true ] \
    || [ "$D_ADDST_COPY_ITEM_EXACT" = true ];
  then d__cqexct=true; D_ADDST_ITEM_FLAGS='e'; fi
  unset D_ADDST_COPY_ITEM_EXACT
  d__context -- push "Checking if copied to: '$d__cqet'"

  # Do sanity checks
  [ -n "$d__cqea" ] || d__cqer+=( -i- '- asset path is empty' )
  [ -n "$d__cqet" ] || d__cqer+=( -i- '- target path is empty' )
  if ((${#d__cqer[@]})); then
    d__notify -lxh -- 'Invalid copy-queue item:' "${d__cqer[@]}"
    d__context -- pop; return 3
  fi

  # Do the actual checking; check if source is readable
  if [ -e "$d__cqet" ]; then
    if ! [ -r "$d__cqea" ]; then
      d__notify -lxh -- "Unreadable asset at: $d__cqea"
      if $d__cqexct; then d__cqrtc=3
      else [ "$D__REQ_ROUTINE" = install ] && d__cqrtc=3; fi
    fi
    if [ -z "$d__cqrtc" ]; then
      if $d__cqexct; then
        if [ "$( dmd5 "$d__cqea" )" = "$( dmd5 "$d__cqet" )" ]
        then d__stash -s -- has $d__cqesk && d__cqrtc=1 || d__cqrtc=7
        else d__stash -s -- has $d__cqesk && d__cqrtc=6 || d__cqrtc=2; fi
      else d__stash -s -- has $d__cqesk && d__cqrtc=1 || d__cqrtc=7; fi
    fi
  else d__stash -s -- has $d__cqesk && d__cqrtc=6 || d__cqrtc=2; fi
  if ! [ $d__cqrtc = 1 ] && [ -e "$d__cqeb" ]; then
    local d__cqeno='-l!h'
    if $d__cqexct && [ "$D__REQ_ROUTINE" != check ]; then d__cqeno='-q!h'; fi
    d__notify $d__cqeno -- "Orphaned backup at: $d__cqeb"
  fi

  # Switch context and return
  d__context -qq -- pop "Check code is '$d__cqrtc'"; return $d__cqrtc
}

d__copy_queue_post_check()
{
  # Switch context; unset check hooks; unset exact copy marker
  d__context -- push 'Tidying up after checking copy-queue'
  unset -f d_copy_item_pre_check d_copy_item_post_check
  unset D_ADDST_COPY_QUEUE_EXACT

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_copy_queue_post_check &>/dev/null
  then d_copy_queue_post_check; d__rtc=$?; unset -f d_copy_queue_post_check; fi

  d__context -- pop; return $d__rtc
}

d__copy_queue_pre_install()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing copy-queue for installing'
  local d__rtc=0; if declare -f d_copy_queue_pre_install &>/dev/null
  then
    d_copy_queue_pre_install; d__rtc=$?; unset -f d_copy_queue_pre_install
  fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_copy_item_pre_install &>/dev/null
  then d_copy_item_pre_install() { :; }; fi
  if ! declare -f d_copy_item_post_install &>/dev/null
  then d_copy_item_post_install() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__copy_item_install()
{
  # Init storage variables; switch context
  local d__cqei="$D__ITEM_NUM" d__cqrtc d__cqcmd
  local d__cqea="${D_QUEUE_ASSETS[$d__cqei]}"
  local d__cqet="${D_QUEUE_TARGETS[$d__cqei]}"
  local d__cqesk="copy_$( dmd5 -s "$d__cqet" )"
  local d__cqeb="$D__DPL_BACKUP_DIR/$d__cqesk"
  d__context -- push "Installing a copy to: '$d__cqet'"

  # Do the actual installing
  if d__push_backup -- "$d__cqet" "$d__cqeb"; then
    d__cqcmd=cp; d__require_wdir "$d__cqet" || d__cqcmd='sudo cp'
    $d__cqcmd -Rn &>/dev/null -- "$d__cqea" "$d__cqet" \
      && d__cqrtc=0 || d__cqrtc=1
  else d__cqrtc=1; fi
  if [ $d__cqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      2|7)  d__stash -s -- set $d__cqesk "$d__cqet" || d__cqrtc=1;;
    esac
    [ -e "$d__cqeb" ] && printf '%s\n' "$d__cqet" >"$d__cqeb.path"
  fi

  # Switch context and return
  d__context -qq -- pop "Install code is '$d__cqrtc'"; return $d__cqrtc
}

d__copy_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing copy-queue'
  unset -f d_copy_item_pre_install d_copy_item_post_install

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_copy_queue_post_install &>/dev/null
  then
    d_copy_queue_post_install; d__rtc=$?; unset -f d_copy_queue_post_install
  fi

  d__context -- pop; return $d__rtc
}

d__copy_queue_pre_remove()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing copy-queue for removing'
  local d__rtc=0; if declare -f d_copy_queue_pre_remove &>/dev/null
  then
    d_copy_queue_pre_remove; d__rtc=$?; unset -f d_copy_queue_pre_remove
  fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_copy_item_pre_remove &>/dev/null
  then d_copy_item_pre_remove() { :; }; fi
  if ! declare -f d_copy_item_post_remove &>/dev/null
  then d_copy_item_post_remove() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__copy_item_remove()
{
  # Init storage variables; switch context
  local d__cqei="$D__ITEM_NUM" d__cqrtc d__cqeo
  local d__cqet="${D_QUEUE_TARGETS[$d__cqei]}"
  local d__cqesk="copy_$( dmd5 -s "$d__cqet" )"
  local d__cqeb="$D__DPL_BACKUP_DIR/$d__cqesk"
  d__context -- push "Undoing copying to: '$d__cqet'"

  # Do the actual removing
  d__cqeo='-e'
  if $D__OPT_OBLITERATE \
    || [[ $D__ITEM_CHECK_CODE -eq 1 && $D__ITEM_FLAGS = *e* ]]
  then d__cqeo='-ed'; fi
  d__pop_backup $d__cqeo -- "$d__cqet" "$d__cqeb" && d__cqrtc=0 || d__cqrtc=1
  if [ $d__cqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      1|6)  d__stash -s -- unset $d__cqesk || d__cqrtc=1;;
    esac
    if [ -e "$d__cqeb" ]
    then d__notify -l!h -- "An older backup remains at: $d__cqeb"
    else rm -f -- "$d__cqeb.path"; fi
  fi

  # Switch context and return
  d__context -qq -- pop "Remove code is '$d__cqrtc'"; return $d__cqrtc
}

d__copy_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing copy-queue'
  unset -f d_copy_item_pre_remove d_copy_item_post_remove

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_copy_queue_post_remove &>/dev/null
  then
    d_copy_queue_post_remove; d__rtc=$?; unset -f d_copy_queue_post_remove
  fi

  d__context -- pop; return $d__rtc
}