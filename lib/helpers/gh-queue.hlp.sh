#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: gh-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.11
#:revremark:    Rename queue arrays
#:created_at:   2019.10.10

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template 'gh-queue.dpl.sh'
#
## Clones or downloads Github repositories into target locations. Github 
#. repositories are accepted in the form 'username/repository'.
#

# Marker and dependencies
readonly D__HLP_GH_QUEUE=loaded
d__load util workflow
d__load procedure detect-os
d__load procedure prep-md5
d__load procedure check-gh
d__load util stash
d__load util github

d__gh_queue_check()
{
  d_queue_pre_check()     { d__gh_queue_pre_check;  }
  d_item_pre_check()      { d_gh_item_pre_check;   }
  d_item_check()          { d__gh_item_check;       }
  d_item_post_check()     { d_gh_item_post_check;  }
  d_queue_post_check()    { d__gh_queue_post_check; }
  d__queue_check
}

d__gh_queue_install()
{
  d_queue_pre_install()   { d__gh_queue_pre_install;  }
  d_item_pre_install()    { d_gh_item_pre_install;   }
  d_item_install()        { d__gh_item_install;       }
  d_item_post_install()   { d_gh_item_post_install;  }
  d_queue_post_install()  { d__gh_queue_post_install; }
  d__queue_install
}

d__gh_queue_remove()
{
  d_queue_pre_remove()    { d__gh_queue_pre_remove;   }
  d_item_pre_remove()     { d_gh_item_pre_remove;    }
  d_item_remove()         { d__gh_item_remove;        }
  d_item_post_remove()    { d_gh_item_post_remove;   }
  d_queue_post_remove()   { d__gh_queue_post_remove;  }
  d__queue_remove
}

d__gh_queue_pre_check()
{
  # Switch context; prepare stash; apply adapter overrides
  d__context -- push 'Preparing Github-queue for checking'
  d__stash -- ready || return 1
  if [ -z "$D__GH_METHOD" ]
  then d__notify -lx -- 'Unable to wotk with Github repositories'; return 1; fi
  d__override_dpl_targets_for_os_family
  d__override_dpl_targets_for_os_distro

  # Ensure the required arrays are continuous at the given section
  local d__i; for ((d__i=$D__QUEUE_SECTMIN;d__i<$D__QUEUE_SECTMAX;++d__i)); do
    if [ -z ${D_QUEUE_TARGETS[$d__i]+isset} ]; then
      if [ -n "$D_QUEUE_TARGET_DIR" ]; then
        D_QUEUE_TARGETS[$d__i]="$D_QUEUE_TARGET_DIR/${D_QUEUE_MAIN[$d__i]}"
      else
        d__notify -lxht 'Github-queue failed' -- \
          'Array $D_QUEUE_TARGETS is not continuous in the given section'
        return 1
      fi
    fi
  done

  # Run queue pre-processing, if implemented
  local d__rtc=0; if declare -f d_gh_queue_pre_check &>/dev/null
  then d_gh_queue_pre_check; d__rtc=$?; unset -f d_gh_queue_pre_check; fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_gh_item_pre_check &>/dev/null
  then d_gh_item_pre_check() { :; }; fi
  if ! declare -f d_gh_item_post_check &>/dev/null
  then d_gh_item_post_check() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__gh_item_check()
{
  # Init storage variables; switch context
  local d__gqei="$D__ITEM_NUM" d__gqen="$D__ITEM_NAME" d__gqrtc d__gqer=()
  local d__gqet="${D_QUEUE_TARGETS[$d__gqei]}"
  local d__gqeb="$D__DPL_BACKUP_DIR/$d__gqesk"
  local d__gqesk="gh_$( dmd5 -s "$d__gqet" )"
  d__context -- push "Checking if cloned to: '$d__gqet'"

  # Do sanity checks
  d___gh_repo_exists "$d__gqen" \
    || d__gqer+=( -i- "- Github repo '$d__gqen' does not appear to exist" )
  [ -n "$d__gqet" ] || d__gqer+=( -i- '- target path is empty' )
  if ((${#d__gqer[@]})); then
    d__notify -lxh -- 'Invalid Github-queue item:' "${d__gqer[@]}"
    d__context -- pop; return 3
  fi

  # Do the actual checking; check if source is readable
  if d___path_is_gh_clone "$d__gqet" "$d__gqen"
  then d__stash -s -- has $d__gqesk && d__gqrtc=1 || d__gqrtc=7
  elif [ -d "$d__gqet" ]
  then d__stash -s -- has $d__gqesk && d__gqrtc=5 || d__gqrtc=9
  else d__stash -s -- has $d__gqesk && d__gqrtc=6 || d__gqrtc=2
    if [ -e "$d__gqet" ]; then
      if [ "$D__REQ_ROUTINE" = install ]; then
        D_ADDST_WARNING+=("Path for Github clone is occupied: $d__gqet")
        D_ADDST_PROMPT=true
      else d__notify -l! -- "Path for Github clone is occupied: $d__gqet"; fi
    fi
  fi
  case $d__gqrtc in
    1|5)  :;;
    *)    [ -e "$d__gqeb" ] \
            && d__notify -l!h -- "Orphaned backup at: $d__gqeb";;
  esac

  # Switch context and return
  d__context -qq -- pop "Check code is '$d__gqrtc'"; return $d__gqrtc
}

d__gh_queue_post_check()
{
  # Switch context; unset check hooks
  d__context -- push 'Tidying up after checking Github-queue'
  unset -f d_gh_item_pre_check d_gh_item_post_check

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_gh_queue_post_check &>/dev/null
  then d_gh_queue_post_check; d__rtc=$?; unset -f d_gh_queue_post_check; fi

  d__context -- pop; return $d__rtc
}

d__gh_queue_pre_install()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing Github-queue for installing'
  local d__rtc=0; if declare -f d_gh_queue_pre_install &>/dev/null
  then d_gh_queue_pre_install; d__rtc=$?; unset -f d_gh_queue_pre_install; fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_gh_item_pre_install &>/dev/null
  then d_gh_item_pre_install() { :; }; fi
  if ! declare -f d_gh_item_post_install &>/dev/null
  then d_gh_item_post_install() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__gh_item_install()
{
  # Init storage variables; switch context
  local d__gqei="$D__ITEM_NUM" d__gqen="$D__ITEM_NAME" d__gqrtc
  local d__gqet="${D_QUEUE_TARGETS[$d__gqei]}"
  local d__gqesk="gh_$( dmd5 -s "$d__gqet" )"
  local d__gqeb="$D__DPL_BACKUP_DIR/$d__gqesk"
  d__context -- push "Retrieving a Github repo to: '$d__gqet'"

  # Do the actual installing
  if d__push_backup -- "$d__gqet" "$d__gqeb"; then
    case $D__GH_METHOD in
      g)  d___clone_gh_repo "$d__gqen" "$d__gqet";;
      c)  mkdir -p &>/dev/null -- "$d__gqet" \
            && d___curl_gh_repo "$d__gqen" "$d__gqet";;
      w)  mkdir -p &>/dev/null -- "$d__gqet" \
            && d___wget_gh_repo "$d__gqen" "$d__gqet";;
    esac; (($?)) && d__gqrtc=1 || d__gqrtc=0
  else d__gqrtc=1; fi
  if [ $d__gqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      2|7|9)  d__stash -s -- set $d__gqesk "$d__gqet" || d__gqrtc=1;;
    esac
    [ -e "$d__gqeb" ] && printf '%s\n' "$d__gqet" >"$d__gqeb.path"
  fi

  # Switch context and return
  d__context -qq -- pop "Install code is '$d__gqrtc'"; return $d__gqrtc
}

d__gh_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing Github-queue'
  unset -f d_gh_item_pre_install d_gh_item_post_install

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_gh_queue_post_install &>/dev/null
  then d_gh_queue_post_install; d__rtc=$?; unset -f d_gh_queue_post_install; fi

  d__context -- pop; return $d__rtc
}

d__gh_queue_pre_remove()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing Github-queue for removing'
  local d__rtc=0; if declare -f d_copy_queue_pre_remove &>/dev/null
  then d_copy_queue_pre_remove; d__rtc=$?; unset -f d_copy_queue_pre_remove; fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_gh_item_pre_remove &>/dev/null
  then d_gh_item_pre_remove() { :; }; fi
  if ! declare -f d_gh_item_post_remove &>/dev/null
  then d_gh_item_post_remove() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__gh_item_remove()
{
  # Init storage variables; switch context
  local d__gqei="$D__ITEM_NUM" d__gqen="$D__ITEM_NAME" d__gqrtc d__gqeo
  local d__gqet="${D_QUEUE_TARGETS[$d__gqei]}"
  local d__gqesk="gh_$( dmd5 -s "$d__gqet" )"
  local d__gqeb="$D__DPL_BACKUP_DIR/$d__gqesk"
  d__context -- push "Removing Github repo at: '$d__gqet'"

  # Do the actual removing
  d__gqeo='-e'; if $D__OPT_OBLITERATE; then d__gqeo='-ed'; fi
  d__pop_backup $d__gqeo -- "$d__gqet" "$d__gqeb" && d__gqrtc=0 || d__gqrtc=1
  if [ $d__gqrtc -eq 0 ]; then
    case $D__ITEM_CHECK_CODE in
      1|5)  d__stash -s -- unset $d__gqesk || d__gqrtc=1;;
    esac
    if [ -e "$d__gqeb" ]
    then d__notify -l!h -- "An older backup remains at: $d__gqeb"
    else rm -f -- "$d__gqeb.path"; fi
  fi

  # Switch context and return
  d__context -qq -- pop "Remove code is '$d__gqrtc'"; return $d__gqrtc
}

d__gh_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing Github-queue'
  unset -f d_gh_item_pre_remove d_gh_item_post_remove

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_gh_queue_post_remove &>/dev/null
  then d_gh_queue_post_remove; d__rtc=$?; unset -f d_gh_queue_post_remove; fi

  d__context -- pop; return $d__rtc
}