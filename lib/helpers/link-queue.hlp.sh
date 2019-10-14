#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: link-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2019.04.02

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'link-queue.dpl.sh'
#
## Replaces arbitrary files (e.g., config files) with symlinks to provided 
#. replacements. Creates backup of each replaced file. Restores original set-up 
#. on removal.
#

# Marker and dependencies
readonly D__HLP_LINK_QUEUE=loaded
d__load util workflow
d__load procedure detect-os
d__load procedure prep-md5
d__load util stash

d__link_queue_check()
{
  d_queue_pre_check() { d__link_queue_pre_check; }
  d_item_check() { d__link_item_check; }
  d_queue_post_check() { d__link_queue_post_check; }
  d__queue_check
}

d__link_queue_install()
{
  d_queue_pre_install() { d__link_queue_pre_install; }
  d_item_install() { d__link_item_install; }
  d_queue_post_install() { d__link_queue_post_install; }
  d__queue_install
}

d__link_queue_remove()
{
  d_queue_pre_remove() { d__link_queue_pre_remove; }
  d_item_remove() { d__link_item_remove; }
  d_queue_post_remove() { d__link_queue_post_remove; }
  d__queue_remove
}

d__link_queue_pre_check()
{
  # Switch context; prepare stash; apply adapter overrides
  d__context -- push 'Preparing link-queue for checking'
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
  local d__qhrtc; if declare -f d_link_queue_pre_check &>/dev/null; then
    d_link_queue_pre_check; d__qhrtc=$?; unset -f d_link_queue_pre_check
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_CHECK_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_link_item_pre_check &>/dev/null
  then d_link_item_pre_check() { :; }; fi
  if ! declare -f d_link_item_post_check &>/dev/null
  then d_link_item_post_check() { :; }; fi

  d__context -- pop
  return 0
}

d__link_item_check()
{
  # Run pre-processing
  d__context -- push "Checking link-queue item '$D__ITEM_NAME'"
  unset D_ADDST_ITEM_CHECK_CODE; d_link_item_pre_check
  if (($?)); then
    d__notify -l!h -- "Link-queue item's pre-check hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Link-queue item's pre-check hook forces halting" \
      "with code '$D_ADDST_ITEM_CHECK_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_CHECK_CODE
  fi

  # Storage varibales; cut-off checks; switch context
  local d__lqei="$D__ITEM_NUM" d__lqrtc d__lqer=()
  local d__lqea="${D_DPL_ASSET_PATHS[$d__lqei]}"
  local d__lqet="${D_DPL_TARGET_PATHS[$d__lqei]}"
  local d__lqesk="link_$( dmd5 -s "$d__lqet" )"
  local d__lqeb="$D__DPL_BACKUP_DIR/$d__lqesk"
  [ -n "$d__lqea" ] || d__lqer+=( -i- '- asset path is empty' )
  [ -n "$d__lqet" ] || d__lqer+=( -i- '- target path is empty' )
  if ((${#d__lqer[@]})); then
    d__notify -lxh -- 'Invalid link-queue item:' "${d__lqer[@]}"
    d__context -- pop; return 3
  fi
  d__context -- push "Checking if linked at: $d__lqet"

  # Do the actual checking; check if source is readable; switch context
  if [ -L "$d__lqet" -a "$d__lqet" -ef "$d__lqea" ]
  then d__stash -s -- has $d__lqesk && d__lqrtc=1 || d__lqrtc=7
  else d__stash -s -- has $d__lqesk && d__lqrtc=6 || d__lqrtc=2; fi
  if ! [ $d__lqrtc = 1 ]; then
    [ -e "$d__lqeb" ] && d__notify -l!h -- "Orphaned backup at: $d__lqeb"
  fi
  if ! [ -r "$d__lqea" ]; then
    d__notify -lxh -- "Unreadable asset at: $d__lqea"
    [ "$D__REQ_ROUTINE" = install ] && d__lqrtc=3
  fi
  d__context -- pop; d__context -- push "Check code is '$d__lqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_CHECK_CODE; D__ITEM_CHECK_CODE="$d__lqrtc"
  d_link_item_post_check; if (($?)); then
    d__notify -l!h -- "Link-queue item's post-check hook forces halting"
    d__context -- pop; d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Link-queue item's post-check hook forces halting" \
      "with code '$D_ADDST_ITEM_CHECK_CODE'"
    d__context -- pop; d__context -- pop; return $D_ADDST_ITEM_CHECK_CODE
  fi

  d__context -- pop; d__context -- pop; return $d__lqrtc
}

d__link_queue_post_check()
{
  # Switch context; unset check hooks
  d__context -- push 'Tidying up after checking link-queue'
  unset -f d_link_item_pre_check d_link_item_post_check

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_link_queue_post_check &>/dev/null; then
    d_link_queue_post_check; d__qhrtc=$?; unset -f d_link_queue_post_check
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_CHECK_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}

d__link_queue_pre_install()
{
  # Switch context; run pre-processing, if implemented
  d__context -- push 'Preparing link-queue for installing'
  local d__qhrtc; if declare -f d_link_queue_pre_install &>/dev/null; then
    d_link_queue_pre_install; d__qhrtc=$?; unset -f d_link_queue_pre_install
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_INSTALL_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_link_item_pre_install &>/dev/null
  then d_link_item_pre_install() { :; }; fi
  if ! declare -f d_link_item_post_install &>/dev/null
  then d_link_item_post_install() { :; }; fi

  d__context -- pop
  return 0
}

d__link_item_install()
{
  # Storage varibales; switch context
  local d__lqei="$D__ITEM_NUM" d__lqrtc d__lqcmd
  local d__lqea="${D_DPL_ASSET_PATHS[$d__lqei]}"
  local d__lqet="${D_DPL_TARGET_PATHS[$d__lqei]}"
  local d__lqesk="link_$( dmd5 -s "$d__lqet" )"
  local d__lqeb="$D__DPL_BACKUP_DIR/$d__lqesk"
  d__context -- push "Installing a link at: $d__lqet"

  # Run pre-processing
  unset D_ADDST_ITEM_INSTALL_CODE; d_link_item_pre_install
  if (($?)); then
    d__notify -l!h -- "Link-queue item's pre-install hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Link-queue item's pre-install hook forces halting" \
      "with code '$D_ADDST_ITEM_INSTALL_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_INSTALL_CODE
  fi

  # Do the actual installing; switch context
  if d__push_backup -- "$d__lqet" "$d__lqeb"; then
    d__lqcmd=ln; d__require_writable "$d__lqet" || d__lqcmd='sudo ln'
    $d__lqcmd -s &>/dev/null -- "$d__lqea" "$d__lqet" \
      && d__lqrtc=0 || d__lqrtc=1
  else d__lqrtc=1; fi
  if [ $d__lqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      2|7)  d__stash -s -- set $d__lqesk "$d__lqet" || d__lqrtc=1;;
    esac
    [ -e "$d__lqeb" ] && printf '%s\n' "$d__lqet" >"$d__lqeb.path"
  fi
  d__context -- pop; d__context -- push "Install code is '$d__lqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_INSTALL_CODE; D__ITEM_INSTALL_CODE="$d__lqrtc"
  d_link_item_post_install; if (($?)); then
    d__notify -l!h -- "Link-queue item's post-install hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Link-queue item's post-install hook forces halting" \
      "with code '$D_ADDST_ITEM_INSTALL_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_INSTALL_CODE
  fi

  d__context -- pop; return $d__lqrtc
}

d__link_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing link-queue'
  unset -f d_link_item_pre_install d_link_item_post_install

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_link_queue_post_install &>/dev/null; then
    d_link_queue_post_install; d__qhrtc=$?; unset -f d_link_queue_post_install
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_INSTALL_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}

d__link_queue_pre_remove()
{
  # Switch context; run pre-processing, if implemented
  d__context -- push 'Preparing link-queue for removing'
  local d__qhrtc; if declare -f d_link_queue_pre_remove &>/dev/null; then
    d_link_queue_pre_remove; d__qhrtc=$?; unset -f d_link_queue_pre_remove
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_REMOVE_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_link_item_pre_remove &>/dev/null
  then d_link_item_pre_remove() { :; }; fi
  if ! declare -f d_link_item_post_remove &>/dev/null
  then d_link_item_post_remove() { :; }; fi

  d__context -- pop
  return 0
}

d__link_item_remove()
{
  # Storage varibales; switch context
  local d__lqei="$D__ITEM_NUM" d__lqrtc d__lqeo
  local d__lqea="${D_DPL_ASSET_PATHS[$d__lqei]}"
  local d__lqet="${D_DPL_TARGET_PATHS[$d__lqei]}"
  local d__lqesk="link_$( dmd5 -s "$d__lqet" )"
  local d__lqeb="$D__DPL_BACKUP_DIR/$d__lqesk"
  d__context -- push "Undoing link at: $d__lqet"

  # Run pre-processing
  unset D_ADDST_ITEM_REMOVE_CODE; d_link_item_pre_remove
  if (($?)); then
    d__notify -l!h -- "Link-queue item's pre-remove hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Link-queue item's pre-remove hook forces halting" \
      "with code '$D_ADDST_ITEM_REMOVE_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_REMOVE_CODE
  fi

  # Do the actual removing; switch context
  d__lqeo='-e'; [ "$D__ITEM_CHECK_CODE" -eq 1 ] && d__lqeo='-ed'
  d__pop_backup $d__lqeo -- "$d__lqet" "$d__lqeb" && d__lqrtc=0 || d__lqrtc=1
  if [ $d__lqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      1|6)  d__stash -s -- unset $d__lqesk || d__lqrtc=1;;
    esac
    [ -e "$d__lqeb" ] || rm -f -- "$d__lqeb.path"
  fi
  d__context -- pop; d__context -- push "Remove code is '$d__lqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_REMOVE_CODE; D__ITEM_REMOVE_CODE="$d__lqrtc"
  d_link_item_post_remove; if (($?)); then
    d__notify -l!h -- "Link-queue item's post-remove hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Link-queue item's post-remove hook forces halting" \
      "with code '$D_ADDST_ITEM_REMOVE_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_REMOVE_CODE
  fi

  d__context -- pop; return $d__lqrtc
}

d__link_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing link-queue'
  unset -f d_link_item_pre_remove d_link_item_post_remove

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_link_queue_post_remove &>/dev/null; then
    d_link_queue_post_remove; d__qhrtc=$?; unset -f d_link_queue_post_remove
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_REMOVE_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}