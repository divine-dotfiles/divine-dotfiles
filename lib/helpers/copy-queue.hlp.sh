#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: copy-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Fix minor typo, pt. 3
#:created_at:   2019.05.23

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'copy-queue.dpl.sh'
#
## Copies arbitrary files (e.g., font files) to provided locations (e.g., into 
#. OS's fonts directory). Creates backup of each replaced file. Restores 
#. original set-up on removal.
#

d__copy_queue_check()
{
  d_queue_pre_check() { d__copy_queue_pre_check; }
  d_item_check() { d__copy_item_check; }
  d_queue_post_check() { d__copy_queue_post_check; }
  d__queue_check
}

d__copy_queue_install()
{
  d_queue_pre_install() { d__copy_queue_pre_install; }
  d_item_install() { d__copy_item_install; }
  d_queue_post_install() { d__copy_queue_post_install; }
  d__queue_install
}

d__copy_queue_remove()
{
  d_queue_pre_remove() { d__copy_queue_pre_remove; }
  d_item_remove() { d__copy_item_remove; }
  d_queue_post_remove() { d__copy_queue_post_remove; }
  d__queue_remove
}

d__copy_queue_pre_check()
{
  # Switch context; prepare stash; apply adapter overrides
  d__context -- push 'Preparing copy-queue for checking'
  d__stash -- ready || return 1
  d__override_dpl_targets_for_os_family
  d__override_dpl_targets_for_os_distro

  # Attempt to auto-asseble the section of queue
  if [ ${#D_DPL_TARGET_PATHS[@]} -eq "$D__QUEUE_SECTMIN" ]; then
    # If $D_QUEUE_MAIN has items, interpret them as relative paths
    if [ -n "$D_DPL_TARGET_DIR" ] \
      && [ ${#D_QUEUE_MAIN[@]} -ge "$D__QUEUE_SECTMAX" ]
    then local d__i
      for ((d__i=$D__QUEUE_SECTMIN;d__i<$D__QUEUE_SECTMAX;++d__i)); do
        D_DPL_TARGET_PATHS+=( "$D_DPL_TARGET_DIR/${D_QUEUE_MAIN[$d__i]}" )
      done
    else local d__dos="$D__OS_FAMILY"
      if [ -n "$D__OS_DISTRO" -a "$D__OS_DISTRO" != "$D__OS_FAMILY" ]
      then d__dos+=" ($D__OS_DISTRO)"; fi
      d__notify -lx -- 'Empty list of target paths ($D_DPL_TARGET_PATHS)' \
        "for detected OS: $d__dos"
      return 1
    fi
  fi

  # Run pre-processing, if implemented
  local d__qhrtc; if declare -f d_copy_queue_pre_check &>/dev/null; then
    d_copy_queue_pre_check; d__qhrtc=$?; unset -f d_copy_queue_pre_check
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_CHECK_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_copy_item_pre_check &>/dev/null
  then d_copy_item_pre_check() { :; }; fi
  if ! declare -f d_copy_item_post_check &>/dev/null
  then d_copy_item_post_check() { :; }; fi

  d__context -- pop
  return 0
}

d__copy_item_check()
{
  # Run pre-processing
  d__context -- push "Checking copy-queue item '$D__ITEM_NAME'"
  unset D_ADDST_ITEM_CHECK_CODE; d_copy_item_pre_check
  if (($?)); then
    d__notify -l!h -- "Copy-queue item's pre-check hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Copy-queue item's pre-check hook forces halting" \
      "with code '$D_ADDST_ITEM_CHECK_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_CHECK_CODE
  fi

  # Storage varibales; switch context
  local d__cqei="$D__ITEM_NUM" d__cqrtc d__cqer=()
  local d__cqea="${D_DPL_ASSET_PATHS[$d__cqei]}"
  local d__cqet="${D_DPL_TARGET_PATHS[$d__cqei]}"
  local d__cqesk="copy_$( dmd5 -s "$d__cqet" )"
  local d__cqeb="$D__DPL_BACKUP_DIR/$d__cqesk"
  [ -n "$d__cqea" ] || d__cqer+=( -i- '- asset path is empty' )
  [ -n "$d__cqet" ] || d__cqer+=( -i- '- target path is empty' )
  if ((${#d__cqer[@]})); then
    d__notify -lxh -- 'Invalid copy-queue item:' "${d__cqer[@]}"
    d__context -- pop; return 3
  fi
  d__context -- push "Checking if copied to: $d__cqet"

  # Do the actual checking; check if source is readable; switch context
  if d__stash -s -- has $d__cqesk
  then [ -e "$d__cqet" ] && d__cqrtc=1 || d__cqrtc=6
  else [ -e "$d__cqet" ] && d__cqrtc=7 || d__cqrtc=2; fi
  if ! [ $d__cqrtc = 1 ]; then
    [ -e "$d__cqeb" ] && d__notify -l!h -- "Orphaned backup at: $d__cqeb"
  fi
  if ! [ -r "$d__cqea" ]; then
    d__notify -lxh -- "Unreadable asset at: $d__cqea"
    [ "$D__REQ_ROUTINE" = install ] && d__cqrtc=3
  fi
  d__context -- pop; d__context -- push "Check code is '$d__cqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_CHECK_CODE; D__ITEM_CHECK_CODE="$d__cqrtc"
  d_copy_item_post_check; if (($?)); then
    d__notify -l!h -- "Copy-queue item's post-check hook forces halting"
    d__context -- pop; d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Copy-queue item's post-check hook forces halting" \
      "with code '$D_ADDST_ITEM_CHECK_CODE'"
    d__context -- pop; d__context -- pop; return $D_ADDST_ITEM_CHECK_CODE
  fi

  d__context -- pop; d__context -- pop; return $d__cqrtc
}

d__copy_queue_post_check()
{
  # Switch context; unset check hooks
  d__context -- push 'Tidying up after checking copy-queue'
  unset -f d_copy_item_pre_check d_copy_item_post_check

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_copy_queue_post_check &>/dev/null; then
    d_copy_queue_post_check; d__qhrtc=$?; unset -f d_copy_queue_post_check
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_CHECK_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}

d__copy_queue_pre_install()
{
  # Switch context; run pre-processing, if implemented
  d__context -- push 'Preparing copy-queue for installing'
  local d__qhrtc; if declare -f d_copy_queue_pre_install &>/dev/null; then
    d_copy_queue_pre_install; d__qhrtc=$?; unset -f d_copy_queue_pre_install
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_INSTALL_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_copy_item_pre_install &>/dev/null
  then d_copy_item_pre_install() { :; }; fi
  if ! declare -f d_copy_item_post_install &>/dev/null
  then d_copy_item_post_install() { :; }; fi

  d__context -- pop
  return 0
}

d__copy_item_install()
{
  # Storage varibales; switch context
  local d__cqei="$D__ITEM_NUM" d__cqrtc d__cqcmd
  local d__cqea="${D_DPL_ASSET_PATHS[$d__cqei]}"
  local d__cqet="${D_DPL_TARGET_PATHS[$d__cqei]}"
  local d__cqesk="copy_$( dmd5 -s "$d__cqet" )"
  local d__cqeb="$D__DPL_BACKUP_DIR/$d__cqesk"
  d__context -- push "Installing a copy to: $d__cqet"

  # Run pre-processing
  unset D_ADDST_ITEM_INSTALL_CODE; d_copy_item_pre_install
  if (($?)); then
    d__notify -l!h -- "Copy-queue item's pre-install hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Copy-queue item's pre-install hook forces halting" \
      "with code '$D_ADDST_ITEM_INSTALL_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_INSTALL_CODE
  fi

  # Do the actual installing; switch context
  if d__push_backup -- "$d__cqet" "$d__cqeb"; then
    d__cqcmd=cp; d__require_writable "$d__cqet" || d__cqcmd='sudo cp'
    $d__cqcmd -Rn &>/dev/null -- "$d__cqea" "$d__cqet" \
      && d__cqrtc=0 || d__cqrtc=1
  else d__cqrtc=1; fi
  if [ $d__cqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      2|7)  d__stash -s -- set $d__cqesk "$d__cqet" || d__cqrtc=1;;
    esac
    [ -e "$d__cqeb" ] && printf '%s\n' "$d__cqet" >"$d__cqeb.path"
  fi
  d__context -- pop; d__context -- push "Install code is '$d__cqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_INSTALL_CODE; D__ITEM_INSTALL_CODE="$d__cqrtc"
  d_copy_item_post_install; if (($?)); then
    d__notify -l!h -- "Copy-queue item's post-install hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Copy-queue item's post-install hook forces halting" \
      "with code '$D_ADDST_ITEM_INSTALL_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_INSTALL_CODE
  fi

  d__context -- pop; return $d__cqrtc
}

d__copy_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing copy-queue'
  unset -f d_copy_item_pre_install d_copy_item_post_install

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_copy_queue_post_install &>/dev/null; then
    d_copy_queue_post_install; d__qhrtc=$?; unset -f d_copy_queue_post_install
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_INSTALL_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}

d__copy_queue_pre_remove()
{
  # Switch context; run pre-processing, if implemented
  d__context -- push 'Preparing copy-queue for removing'
  local d__qhrtc; if declare -f d_copy_queue_pre_remove &>/dev/null; then
    d_copy_queue_pre_remove; d__qhrtc=$?; unset -f d_copy_queue_pre_remove
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_REMOVE_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_copy_item_pre_remove &>/dev/null
  then d_copy_item_pre_remove() { :; }; fi
  if ! declare -f d_copy_item_post_remove &>/dev/null
  then d_copy_item_post_remove() { :; }; fi

  d__context -- pop
  return 0
}

d__copy_item_remove()
{
  # Storage varibales; switch context
  local d__cqei="$D__ITEM_NUM" d__cqrtc
  local d__cqet="${D_DPL_TARGET_PATHS[$d__cqei]}"
  local d__cqesk="copy_$( dmd5 -s "$d__cqet" )"
  local d__cqeb="$D__DPL_BACKUP_DIR/$d__cqesk"
  d__context -- push "Undoing copying to: $d__cqet"

  # Run pre-processing
  unset D_ADDST_ITEM_REMOVE_CODE; d_copy_item_pre_remove
  if (($?)); then
    d__notify -l!h -- "Copy-queue item's pre-remove hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Copy-queue item's pre-remove hook forces halting" \
      "with code '$D_ADDST_ITEM_REMOVE_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_REMOVE_CODE
  fi

  # Do the actual removing; switch context
  d__pop_backup -e -- "$d__cqet" "$d__cqeb" && d__cqrtc=0 || d__cqrtc=1
  if [ $d__cqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      1|6)  d__stash -s -- unset $d__cqesk || d__cqrtc=1;;
    esac
    [ -e "$d__cqeb" ] || rm -f -- "$d__cqeb.path"
  fi
  d__context -- pop; d__context -- push "Remove code is '$d__cqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_REMOVE_CODE; D__ITEM_REMOVE_CODE="$d__cqrtc"
  d_copy_item_post_remove; if (($?)); then
    d__notify -l!h -- "Copy-queue item's post-remove hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Copy-queue item's post-remove hook forces halting" \
      "with code '$D_ADDST_ITEM_REMOVE_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_REMOVE_CODE
  fi

  d__context -- pop; return $d__cqrtc
}

d__copy_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing copy-queue'
  unset -f d_copy_item_pre_remove d_copy_item_post_remove

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_copy_queue_post_remove &>/dev/null; then
    d_copy_queue_post_remove; d__qhrtc=$?; unset -f d_copy_queue_post_remove
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_REMOVE_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}