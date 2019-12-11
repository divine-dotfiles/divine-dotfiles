#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: link-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.11
#:revremark:    Re-arrange dependencies in spec queue helpers
#:created_at:   2019.04.02

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Helper functions for deployments based on template 'link-queue.dpl.sh'
#
## Replaces arbitrary files (e.g., config files) with symlinks to provided 
#. replacements. Creates backup of each replaced file. Restores original set-up 
#. on removal.
#

# Marker and dependencies
readonly D__HLP_LINK_QUEUE=loaded
d__load procedure prep-md5
d__load util workflow
d__load util stash

d__link_queue_check()
{
  d_queue_pre_check()     { d__link_queue_pre_check;  }
  d_item_pre_check()      { d_link_item_pre_check;   }
  d_item_check()          { d__link_item_check;       }
  d_item_post_check()     { d_link_item_post_check;  }
  d_queue_post_check()    { d__link_queue_post_check; }
  d__queue_check
}

d__link_queue_install()
{
  d_queue_pre_install()   { d__link_queue_pre_install;  }
  d_item_pre_install()    { d_link_item_pre_install;   }
  d_item_install()        { d__link_item_install;       }
  d_item_post_install()   { d_link_item_post_install;  }
  d_queue_post_install()  { d__link_queue_post_install; }
  d__queue_install
}

d__link_queue_remove()
{
  d_queue_pre_remove()    { d__link_queue_pre_remove;   }
  d_item_pre_remove()     { d_link_item_pre_remove;    }
  d_item_remove()         { d__link_item_remove;        }
  d_item_post_remove()    { d_link_item_post_remove;   }
  d_queue_post_remove()   { d__link_queue_post_remove;  }
  d__queue_remove
}

d__link_queue_pre_check()
{
  # Switch context; prepare stash
  d__context -- push 'Preparing link-queue for checking'
  d__stash -- ready || return 1

  # Ensure the required arrays are continuous at the given section
  local d__i; for ((d__i=$D__QUEUE_SECTMIN;d__i<$D__QUEUE_SECTMAX;++d__i)); do
    if [ -z ${D_QUEUE_ASSETS[$d__i]+isset} ]; then
      d__notify -lxht 'Link-queue failed' -- \
        'Array $D_QUEUE_ASSETS is not continuous in the given section'
      return 1
    fi
    if [ -z ${D_QUEUE_TARGETS[$d__i]+isset} ]; then
      d__notify -lxht 'Link-queue failed' -- \
        'Array $D_QUEUE_TARGETS is not continuous in the given section'
      return 1
    fi
  done

  # Run queue pre-processing, if implemented
  local d__rtc=0; if declare -f d_link_queue_pre_check &>/dev/null
  then d_link_queue_pre_check; d__rtc=$?; unset -f d_link_queue_pre_check; fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_link_item_pre_check &>/dev/null
  then d_link_item_pre_check() { :; }; fi
  if ! declare -f d_link_item_post_check &>/dev/null
  then d_link_item_post_check() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__link_item_check()
{
  # Init storage variables; switch context
  local d__lqei="$D__ITEM_NUM" d__lqrtc d__lqer=()
  local d__lqea="${D_QUEUE_ASSETS[$d__lqei]}"
  local d__lqet="${D_QUEUE_TARGETS[$d__lqei]}"
  local d__lqesk="link_$( d__md5 -s "$d__lqet" )"
  local d__lqeb="$D__DPL_BACKUP_DIR/$d__lqesk"
  local d__ddsl=false
  d__context -- push "Checking if linked at: '$d__lqet'"

  # Do sanity checks
  [ -n "$d__lqea" ] || d__lqer+=( -i- '- asset path is empty' )
  [ -n "$d__lqet" ] || d__lqer+=( -i- '- target path is empty' )
  if ((${#d__lqer[@]})); then
    d__notify -lxh -- 'Invalid link-queue item:' "${d__lqer[@]}"
    d__context -- pop; return 3
  fi

  # Do the actual checking; check if source is readable
  if [ ! -e "$d__lqet" -a -L "$d__lqet" ]; then
    D_ADDST_WARNING+=("Dead symlink at: $d__lqet")
    D_ADDST_PROMPT=true
    d__ddsl=true
  fi
  if [ -e "$d__lqet" ] || $d__ddsl; then
    if [ -L "$d__lqet" -a "$d__lqet" -ef "$d__lqea" ]
    then d__stash -s -- has $d__lqesk && d__lqrtc=1 || d__lqrtc=7
    else d__stash -s -- has $d__lqesk && d__lqrtc=6 || d__lqrtc=2; fi
  else d__stash -s -- has $d__lqesk && d__lqrtc=6 || d__lqrtc=2; fi    
  if ! [ $d__lqrtc = 1 ] && [ -e "$d__lqeb" ];
  then d__notify -l!h -- "Orphaned backup at: $d__lqeb"; fi
  if ! [ -r "$d__lqea" ]; then
    d__notify -lxh -- "Unreadable asset at: $d__lqea"
    [ "$D__REQ_ROUTINE" = install ] && d__lqrtc=3
  fi

  # Switch context and return
  d__context -qq -- pop "Check code is '$d__lqrtc'"; return $d__lqrtc
}

d__link_queue_post_check()
{
  # Switch context; unset check hooks
  d__context -- push 'Tidying up after checking link-queue'
  unset -f d_link_item_pre_check d_link_item_post_check

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_link_queue_post_check &>/dev/null
  then d_link_queue_post_check; d__rtc=$?; unset -f d_link_queue_post_check; fi

  d__context -- pop; return $d__rtc
}

d__link_queue_pre_install()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing link-queue for installing'
  local d__rtc=0; if declare -f d_link_queue_pre_install &>/dev/null
  then
    d_link_queue_pre_install; d__rtc=$?; unset -f d_link_queue_pre_install
  fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_link_item_pre_install &>/dev/null
  then d_link_item_pre_install() { :; }; fi
  if ! declare -f d_link_item_post_install &>/dev/null
  then d_link_item_post_install() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__link_item_install()
{
  # Init storage variables; switch context
  local d__lqei="$D__ITEM_NUM" d__lqrtc d__lqcmd
  local d__lqea="${D_QUEUE_ASSETS[$d__lqei]}"
  local d__lqet="${D_QUEUE_TARGETS[$d__lqei]}"
  local d__lqesk="link_$( d__md5 -s "$d__lqet" )"
  local d__lqeb="$D__DPL_BACKUP_DIR/$d__lqesk"
  d__context -- push "Installing a link at: '$d__lqet'"

  # Do the actual installing
  if d__push_backup -- "$d__lqet" "$d__lqeb"; then
    d__lqcmd=ln; d__require_wdir "$d__lqet" || d__lqcmd='sudo ln'
    $d__lqcmd -s &>/dev/null -- "$d__lqea" "$d__lqet" \
      && d__lqrtc=0 || d__lqrtc=1
  else d__lqrtc=1; fi
  if [ $d__lqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      2|7)  d__stash -s -- set $d__lqesk "$d__lqet" || d__lqrtc=1;;
    esac
    [ -e "$d__lqeb" ] && printf '%s\n' "$d__lqet" >"$d__lqeb.path"
  fi

  # Switch context and return
  d__context -qq -- pop "Install code is '$d__lqrtc'"; return $d__lqrtc
}

d__link_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing link-queue'
  unset -f d_link_item_pre_install d_link_item_post_install

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_link_queue_post_install &>/dev/null
  then
    d_link_queue_post_install; d__rtc=$?; unset -f d_link_queue_post_install
  fi

  d__context -- pop; return $d__rtc
}

d__link_queue_pre_remove()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing link-queue for removing'
  local d__rtc=0; if declare -f d_link_queue_pre_remove &>/dev/null
  then
    d_link_queue_pre_remove; d__rtc=$?; unset -f d_link_queue_pre_remove
  fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_link_item_pre_remove &>/dev/null
  then d_link_item_pre_remove() { :; }; fi
  if ! declare -f d_link_item_post_remove &>/dev/null
  then d_link_item_post_remove() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__link_item_remove()
{
  # Init storage variables; switch context
  local d__lqei="$D__ITEM_NUM" d__lqrtc d__lqeo
  local d__lqea="${D_QUEUE_ASSETS[$d__lqei]}"
  local d__lqet="${D_QUEUE_TARGETS[$d__lqei]}"
  local d__lqesk="link_$( d__md5 -s "$d__lqet" )"
  local d__lqeb="$D__DPL_BACKUP_DIR/$d__lqesk"
  d__context -- push "Undoing link at: '$d__lqet'"

  # Do the actual removing
  d__lqeo='-e'; if $D__OPT_OBLITERATE || [ "$D__ITEM_CHECK_CODE" -eq 1 ]
  then d__lqeo='-ed'; fi
  d__pop_backup $d__lqeo -- "$d__lqet" "$d__lqeb" && d__lqrtc=0 || d__lqrtc=1
  if [ $d__lqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      1|6)  d__stash -s -- unset $d__lqesk || d__lqrtc=1;;
    esac
    if [ -e "$d__lqeb" ]
    then d__notify -l!h -- "An older backup remains at: $d__lqeb"
    else rm -f -- "$d__lqeb.path"; fi
  fi

  # Switch context and return
  d__context -qq -- pop "Remove code is '$d__lqrtc'"; return $d__lqrtc
}

d__link_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing link-queue'
  unset -f d_link_item_pre_remove d_link_item_post_remove

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_copy_queue_post_remove &>/dev/null
  then
    d_copy_queue_post_remove; d__rtc=$?; unset -f d_copy_queue_post_remove
  fi

  d__context -- pop; return $d__rtc
}