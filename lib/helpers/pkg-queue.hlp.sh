#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: pkg-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    Remove erroneous continuity checks from pkg-queue helper
#:created_at:   2019.12.11

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Helper functions for deployments based on template 'pkg-queue.dpl.sh'
#
## Installs system packages using the supported package manager.
#

# Marker and dependencies
readonly D__HLP_PKG_QUEUE=loaded
d__load procedure detect-os
d__load util workflow
d__load util pkg

d__pkg_queue_check()
{
  d_queue_pre_check()     { d__pkg_queue_pre_check;   }
  d_item_pre_check()      { d_pkg_item_pre_check;     }
  d_item_check()          { d__pkg_item_check;        }
  d_item_post_check()     { d_pkg_item_post_check;    }
  d_queue_post_check()    { d__pkg_queue_post_check;  }
  d__queue_check
}

d__pkg_queue_install()
{
  d_queue_pre_install()   { d__pkg_queue_pre_install;   }
  d_item_pre_install()    { d_pkg_item_pre_install;     }
  d_item_install()        { d__pkg_item_install;        }
  d_item_post_install()   { d_pkg_item_post_install;    }
  d_queue_post_install()  { d__pkg_queue_post_install;  }
  d__queue_install
}

d__pkg_queue_remove()
{
  d_queue_pre_remove()    { d__pkg_queue_pre_remove;    }
  d_item_pre_remove()     { d_pkg_item_pre_remove;      }
  d_item_remove()         { d__pkg_item_remove;         }
  d_item_post_remove()    { d_pkg_item_post_remove;     }
  d_queue_post_remove()   { d__pkg_queue_post_remove;   }
  d__queue_remove
}

d__pkg_queue_pre_check()
{
  # Switch context
  d__context -- push 'Preparing pkg-queue for checking'

  # Run queue pre-processing, if implemented
  local d__rtc=0; if declare -f d_pkg_queue_pre_check &>/dev/null
  then d_pkg_queue_pre_check; d__rtc=$?; unset -f d_pkg_queue_pre_check; fi

  # If item check hooks are not implemented, implement dummies
  if ! declare -f d_pkg_item_pre_check &>/dev/null
  then d_pkg_item_pre_check() { :; }; fi
  if ! declare -f d_pkg_item_post_check &>/dev/null
  then d_pkg_item_post_check() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__pkg_item_check() { d__pkg_check -- "$D__ITEM_NAME"; }

d__pkg_queue_post_check()
{
  # Switch context; unset check hooks
  d__context -- push 'Tidying up after checking pkg-queue'
  unset -f d_pkg_item_pre_check d_pkg_item_post_check

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_pkg_queue_post_check &>/dev/null
  then d_pkg_queue_post_check; d__rtc=$?; unset -f d_pkg_queue_post_check; fi

  d__context -- pop; return $d__rtc
}

d__pkg_queue_pre_install()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing pkg-queue for installing'
  local d__rtc=0; if declare -f d_pkg_queue_pre_install &>/dev/null
  then
    d_pkg_queue_pre_install; d__rtc=$?; unset -f d_pkg_queue_pre_install
  fi

  # If item install hooks are not implemented, implement dummies
  if ! declare -f d_pkg_item_pre_install &>/dev/null
  then d_pkg_item_pre_install() { :; }; fi
  if ! declare -f d_pkg_item_post_install &>/dev/null
  then d_pkg_item_post_install() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__pkg_item_install() { d__pkg_install -- "$D__ITEM_NAME"; }

d__pkg_queue_post_install()
{
  # Switch context; unset install hooks
  d__context -- push 'Tidying up after installing pkg-queue'
  unset -f d_pkg_item_pre_install d_pkg_item_post_install

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_pkg_queue_post_install &>/dev/null
  then
    d_pkg_queue_post_install; d__rtc=$?; unset -f d_pkg_queue_post_install
  fi

  d__context -- pop; return $d__rtc
}

d__pkg_queue_pre_remove()
{
  # Switch context; run queue pre-processing, if implemented
  d__context -- push 'Preparing pkg-queue for removing'
  local d__rtc=0; if declare -f d_pkg_queue_pre_remove &>/dev/null
  then
    d_pkg_queue_pre_remove; d__rtc=$?; unset -f d_pkg_queue_pre_remove
  fi

  # If item remove hooks are not implemented, implement dummies
  if ! declare -f d_pkg_item_pre_remove &>/dev/null
  then d_pkg_item_pre_remove() { :; }; fi
  if ! declare -f d_pkg_item_post_remove &>/dev/null
  then d_pkg_item_post_remove() { :; }; fi

  d__context -- pop; return $d__rtc
}

d__pkg_item_remove() { d__pkg_remove -- "$D__ITEM_NAME"; }

d__pkg_queue_post_remove()
{
  # Switch context; unset remove hooks
  d__context -- push 'Tidying up after removing pkg-queue'
  unset -f d_pkg_item_pre_remove d_pkg_item_post_remove

  # Run queue post-processing, if implemented
  local d__rtc=0; if declare -f d_pkg_queue_post_remove &>/dev/null
  then
    d_pkg_queue_post_remove; d__rtc=$?; unset -f d_pkg_queue_post_remove
  fi

  d__context -- pop; return $d__rtc
}