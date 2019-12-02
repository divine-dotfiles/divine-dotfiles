#!/usr/bin/env bash
#:title:        Divine Bash procedure: init-vars
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.02
#:revremark:    Ensure no empty template is left after failed fmwk inst.
#:created_at:   2019.10.11

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Groups initialization of global variables used by the framework.
#

# Marker and dependencies
readonly D__PCD_INIT_VARS=loaded

# Driver function
d__pcd_init_vars()
{
  # Populate global variables
  d__populate_globals
}

#>  d__populate_globals
#
## This function groups all constant paths, filenames, and other keywords used 
#. by the framework.
#
## Provides into the global scope:
#.  [ too many to list, read on ]
#
## Returns:
#.  0 - Always.
#
d__populate_globals()
{
  # Framework's displayed name
  readonly D__FMWK_NAME='Divine.dotfiles'

  # Framework's displayed version
  readonly D__FMWK_VERSION='3.0.0+dev'
  readonly D__FMWK_DEV=true

  # Paths to state directory
  readonly D__DIR_STATE="$D__DIR/state"

  # Path to Grail directory, with possible overriding
  readonly D__PATH_GRAIL_OVRD="$D__DIR_STATE/.grail-dir-path"
  if ! [ -z ${D_GRAIL+isset} ]; then
    printf >&2 '\033[36m%s\033[0m\n' \
      "==> Grail directory overridden: '$D_GRAIL'"
    readonly D__DIR_GRAIL="$D_GRAIL"
  elif [ -f "$D__PATH_GRAIL_OVRD" -a -r "$D__PATH_GRAIL_OVRD" ]; then
    local d_grail; read -r d_grail <"$D__PATH_GRAIL_OVRD"
    if (($D__OPT_VERBOSITY)); then
      printf >&2 '\033[36m%s\033[0m\n' \
        "==> Grail directory overridden: '$d_grail'"
    fi
    readonly D__DIR_GRAIL="$d_grail"
  else
    readonly D__DIR_GRAIL="$HOME/.grail"
  fi

  # Paths to directories within $D__DIR_GRAIL
  readonly D__DIR_ASSETS="$D__DIR_GRAIL/assets"
  readonly D__DIR_DPLS="$D__DIR_GRAIL/dpls"

  # Paths to directories within $D__DIR_STATE
  readonly D__DIR_BACKUPS="$D__DIR_STATE/backups"
  readonly D__DIR_STASH="$D__DIR_STATE/stash"
  readonly D__DIR_BUNDLES="$D__DIR_STATE/bundles"
  readonly D__DIR_BUNDLE_BACKUPS="$D__DIR_STATE/bundle-backups"

  # Path to this very file (used to extract framework version)
  readonly D__PATH_INIT_VARS="$D__DIR_LIB/procedures/init-vars.pcd.sh"

  # Filename suffix for transition scripts
  readonly D__SUFFIX_TRS_SH='.trs.sh'

  # Filename suffix for deployment files
  readonly D__SUFFIX_DPL_SH='.dpl.sh'

  # Filename suffix for asset manifest files
  readonly D__SUFFIX_DPL_MNF='.dpl.mnf'

  # Filename suffix for main queue manifest files
  readonly D__SUFFIX_DPL_QUE='.dpl.que'

  # Name for directories containing transition scripts
  readonly D__CONST_DIRNAME_TRS='transitions'

  # Name of bundle.sh file
  readonly D__CONST_NAME_BUNDLE_SH='bundle.sh'

  # Name of transition-from-version file
  readonly D__CONST_NAME_MNTRS='.transition-from-version'

  # Name of untransitioned-version file
  readonly D__CONST_NAME_UNTRS='.untransitioned-version'

  # Name of Divinefile
  readonly D__CONST_NAME_DIVINEFILE='Divinefile'

  # Name for stash files
  readonly D__CONST_NAME_STASHFILE=".stash.cfg"

  # Default task priority
  readonly D__CONST_DEF_PRIORITY=4096

  # Commands to play with 'nocasematch' (case sensitivity) Bash option
  readonly D__DISABLE_CASE_SENSITIVITY='shopt -s nocasematch'
  readonly D__RESTORE_CASE_SENSITIVITY="$( shopt -p nocasematch )"

  # Commands to play with 'dotglob' (dotfiles globbing) Bash option
  readonly D__ENABLE_DOTGLOB='shopt -s dotglob'
  readonly D__RESTORE_DOTGLOB="$( shopt -p dotglob )"

  # Commands to play with 'nullglob' (zero glob results) Bash option
  readonly D__ENABLE_NULLGLOB='shopt -s nullglob'
  readonly D__RESTORE_NULLGLOB="$( shopt -p nullglob )"

  # Queue section splits
  D__QUEUE_SPLIT_POINTS=()

  return 0
}

d__pcd_init_vars