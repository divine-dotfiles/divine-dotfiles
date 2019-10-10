#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: gh-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Finish implementing three special queues
#:created_at:   2019.10.10

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'gh-queue.dpl.sh'
#
## Clones or downloads Github repositories into target locations. Github 
#. repositories are accepted in the form 'username/repository'.
#

d__gh_queue_check()
{
  d_queue_pre_check() { d__gh_queue_pre_check; }
  d_item_check() { d__gh_item_check; }
  d_queue_post_check() { d__gh_queue_post_check; }
  d__queue_check
}

d__gh_queue_install()
{
  d_queue_pre_install() { d__gh_queue_pre_install; }
  d_item_install() { d__gh_item_install; }
  d_queue_post_install() { d__gh_queue_post_install; }
  d__queue_install
}

d__gh_queue_remove()
{
  d_queue_pre_remove() { d__gh_queue_pre_remove; }
  d_item_remove() { d__gh_item_remove; }
  d_queue_post_remove() { d__gh_queue_post_remove; }
  d__queue_remove
}

d__gh_queue_pre_check()
{
  # Switch context; prepare stash; apply adapter overrides
  d__context -- push 'Preparing Github-queue for checking'
  d__stash -- ready || return 1
  if [ -z "$D__GH_METHOD" ]
  then d__notify -lx -- 'Unable to wotk with Github repositories'; return 1; fi
  d__adapter_override_dpl_targets_for_os_family
  d__adapter_override_dpl_targets_for_os_distro

  # Attempt to auto-asseble the section of queue
  if [ ${#D_DPL_TARGET_PATHS[@]} -eq "$D__QUEUE_SECTMIN" ]; then
    # If $D_QUEUE_MAIN has items, interpret them as relative paths
    if [ -n "$D_DPL_TARGET_DIR" ] \
      && [ ${#D_QUEUE_MAIN[@]} -ge "$D__QUEUE_SECTMAX" ]
    then local d__i
      for (( d__i=$D__QUEUE_SECTMIN; d__i<$D__QUEUE_SECTMAX; ++d__i )); do
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
  local d__qhrtc; if declare -f d_gh_queue_pre_check &>/dev/null; then
    d_gh_queue_pre_check; d__qhrtc=$?; unset -f d_gh_queue_pre_check
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_CHECK_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_gh_item_pre_check &>/dev/null
  then d_gh_item_pre_check() { :; }; fi
  if ! declare -f d_gh_item_post_check &>/dev/null
  then d_gh_item_post_check() { :; }; fi

  d__context -- pop
  return 0
}

d__gh_item_check()
{
  # Run pre-processing
  d__context -- push "Checking Github-queue item '$D__ITEM_NAME'"
  unset D_ADDST_ITEM_CHECK_CODE; d_gh_item_pre_check
  if (($?)); then
    d__notify -l!h -- "Github-queue item's pre-check hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Github-queue item's pre-check hook forces halting" \
      "with code '$D_ADDST_ITEM_CHECK_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_CHECK_CODE
  fi

  # Storage varibales; switch context
  local d__gqei="$D__ITEM_NUM" d__gqen="$D__ITEM_NAME" d__gqrtc d__gqer=()
  local d__gqet="${D_DPL_TARGET_PATHS[$d__gqei]}"
  local d__gqeb="$D__DPL_BACKUP_DIR/$d__gqesk"
  local d__gqesk="gh_$( dmd5 -s "$d__gqet" )"
  d___gh_repo_exists "$d__gqen" \
    || d__gqer+=( -i- "- invalid Github repo handle '$d__gqen'" )
  [ -n "$d__gqet" ] || d__gqer+=( -i- '- target path is empty' )
  if ((${#d__gqer[@]})); then
    d__notify -lxh -- 'Invalid Github-queue item:' "${d__gqer[@]}"
    d__context -- pop; return 3
  fi
  d__context -- push "Checking if cloned to: $d__gqet"

  # Do the actual checking; check if source is readable; switch context
  if d___path_is_gh_clone "$d__gqet" "$d__gqen"
  then d__stash -s -- has $d__gqesk && d__gqrtc=1 || d__gqrtc=7
  elif [ -d "$d__gqet" ]
  then d__stash -s -- has $d__gqesk && d__gqrtc=5 || d__gqrtc=9
  else d__gqrtc=2
    if [ -e "$d__gqet" ]; then
      if [ "$D__REQ_ROUTINE" = install ]; then
        D_ADDST_WARNING+=("Something exists at: $d__gqet"); D_ADDST_PROMPT=true
      else d__notify -l! -- "Something exists at: $d__gqet"; fi
    fi
  fi
  case $d__gqrtc in 2|7) [ -e "$d__gqeb" ] \
    && d__notify -l!h -- "Orphaned backup at: $d__gqeb";; esac
  d__context -- pop; d__context -- push "Check code is '$d__gqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_CHECK_CODE; D__ITEM_CHECK_CODE="$d__gqrtc"
  d_gh_item_post_check; if (($?)); then
    d__notify -l!h -- "Github-queue item's post-check hook forces halting"
    d__context -- pop; d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_CHECK_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Github-queue item's post-check hook forces halting" \
      "with code '$D_ADDST_ITEM_CHECK_CODE'"
    d__context -- pop; d__context -- pop; return $D_ADDST_ITEM_CHECK_CODE
  fi

  d__context -- pop; d__context -- pop; return $d__gqrtc
}

d__gh_queue_post_check()
{
  # Switch context; unset check hooks
  d__context -- push 'Tidying up after checking Github-queue'
  unset -f d_gh_item_pre_check d_gh_item_post_check

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_gh_queue_post_check &>/dev/null; then
    d_gh_queue_post_check; d__qhrtc=$?; unset -f d_gh_queue_post_check
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_CHECK_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}

d__gh_queue_pre_install()
{
  # Switch context; run pre-processing, if implemented
  d__context -- push 'Preparing Github-queue for installing'
  local d__qhrtc; if declare -f d_gh_queue_pre_install &>/dev/null; then
    d_gh_queue_pre_install; d__qhrtc=$?; unset -f d_gh_queue_pre_install
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_INSTALL_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_gh_item_pre_install &>/dev/null
  then d_gh_item_pre_install() { :; }; fi
  if ! declare -f d_gh_item_post_install &>/dev/null
  then d_gh_item_post_install() { :; }; fi

  d__context -- pop
  return 0
}

d__gh_item_install()
{
  # Storage varibales; switch context
  local d__gqei="$D__ITEM_NUM" d__gqen="$D__ITEM_NAME" d__gqrtc
  local d__gqet="${D_DPL_TARGET_PATHS[$d__gqei]}"
  local d__gqesk="gh_$( dmd5 -s "$d__gqet" )"
  local d__gqeb="$D__DPL_BACKUP_DIR/$d__gqesk"
  d__context -- push "Retrieving a Github repo to: $d__gqet"

  # Run pre-processing
  unset D_ADDST_ITEM_INSTALL_CODE; d_gh_item_pre_install
  if (($?)); then
    d__notify -l!h -- "Github-queue item's pre-install hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Github-queue item's pre-install hook forces halting" \
      "with code '$D_ADDST_ITEM_INSTALL_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_INSTALL_CODE
  fi

  # Do the actual installing; switch context
  if d__push_backup -- "$d__gqet" "$d__gqeb"; then
    case $D__GH_METHOD in
      g)  d___clone_gh_repo "$d__gqen" "$d__gqet";;
      c)  d__cmd mkdir -- --REPO_PATH-- "$d__gqet" \
            && d___curl_gh_repo "$d__gqen" "$d__gqet";;
      w)  d__cmd mkdir -- --REPO_PATH-- "$d__gqet" \
            && d___wget_gh_repo "$d__gqen" "$d__gqet";;
    esac; (($?)) && d__gqrtc=1 || d__gqrtc=0
  else d__gqrtc=1; fi
  if [ $d__gqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      2|7|9)  d__stash -s -- set $d__gqesk "$d__gqet" || d__gqrtc=1;;
    esac
    [ -e "$d__gqeb" ] && printf '%s\n' "$d__gqet" >"$d__gqeb.path"
  fi
  d__context -- pop; d__context -- push "Install code is '$d__gqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_INSTALL_CODE; D__ITEM_INSTALL_CODE="$d__gqrtc"
  d_gh_item_post_install; if (($?)); then
    d__notify -l!h -- "Github-queue item's post-install hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_INSTALL_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Github-queue item's post-install hook forces halting" \
      "with code '$D_ADDST_ITEM_INSTALL_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_INSTALL_CODE
  fi

  d__context -- pop; return $d__gqrtc
}

d__gh_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing Github-queue'
  unset -f d_gh_item_pre_install d_gh_item_post_install

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_gh_queue_post_install &>/dev/null; then
    d_gh_queue_post_install; d__qhrtc=$?; unset -f d_gh_queue_post_install
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_INSTALL_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}

d__gh_queue_pre_remove()
{
  # Switch context; run pre-processing, if implemented
  d__context -- push 'Preparing Github-queue for removing'
  local d__qhrtc; if declare -f d_gh_queue_pre_remove &>/dev/null; then
    d_gh_queue_pre_remove; d__qhrtc=$?; unset -f d_gh_queue_pre_remove
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_REMOVE_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_gh_item_pre_remove &>/dev/null
  then d_gh_item_pre_remove() { :; }; fi
  if ! declare -f d_gh_item_post_remove &>/dev/null
  then d_gh_item_post_remove() { :; }; fi

  d__context -- pop
  return 0
}

d__gh_item_remove()
{
  # Storage varibales; switch context
  local d__gqei="$D__ITEM_NUM" d__gqen="$D__ITEM_NAME" d__gqrtc
  local d__gqet="${D_DPL_TARGET_PATHS[$d__gqei]}"
  local d__gqesk="gh_$( dmd5 -s "$d__gqet" )"
  local d__gqeb="$D__DPL_BACKUP_DIR/$d__gqesk"
  d__context -- push "Removing Github repo at: $d__gqet"

  # Run pre-processing
  unset D_ADDST_ITEM_REMOVE_CODE; d_gh_item_pre_remove
  if (($?)); then
    d__notify -l!h -- "Github-queue item's pre-remove hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Github-queue item's pre-remove hook forces halting" \
      "with code '$D_ADDST_ITEM_REMOVE_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_REMOVE_CODE
  fi

  # Do the actual removing; switch context
  d__pop_backup -e -- "$d__gqet" "$d__gqeb" && d__gqrtc=0 || d__gqrtc=1
  if [ $d__gqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      1|5)  d__stash -s -- unset $d__gqesk || d__gqrtc=1;;
    esac
    [ -e "$d__gqeb" ] || rm -f -- "$d__gqeb.path"
  fi
  d__context -- pop; d__context -- push "Remove code is '$d__gqrtc'"

  # Run post-processing
  unset D_ADDST_ITEM_REMOVE_CODE; D__ITEM_REMOVE_CODE="$d__gqrtc"
  d_gh_item_post_remove; if (($?)); then
    d__notify -l!h -- "Github-queue item's post-remove hook forces halting"
    d__context -- pop; return 3
  elif [[ $D_ADDST_ITEM_REMOVE_CODE =~ ^[0-9]+$ ]]; then
    d__notify -l!h -- "Github-queue item's post-remove hook forces halting" \
      "with code '$D_ADDST_ITEM_REMOVE_CODE'"
    d__context -- pop; return $D_ADDST_ITEM_REMOVE_CODE
  fi

  d__context -- pop; return $d__gqrtc
}

d__gh_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing Github-queue'
  unset -f d_gh_item_pre_remove d_gh_item_post_remove

  # Run post-processing, if implemented
  local d__qhrtc; if declare -f d_gh_queue_post_remove &>/dev/null; then
    d_gh_queue_post_remove; d__qhrtc=$?; unset -f d_gh_queue_post_remove
    if (($d__qhrtc)); then return $d__qhrtc
    elif [[ $D_ADDST_REMOVE_CODE =~ ^[0-9]+$ ]]; then return 0; fi
  fi

  d__context -- pop
  return 0
}