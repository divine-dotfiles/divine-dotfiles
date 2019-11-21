#!/usr/bin/env bash
#:title:        Divine Bash procedure: init-vars
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.21
#:revremark:    Bump version to 2.2.0
#:created_at:   2019.10.11

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
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
  readonly D__FMWK_VERSION='2.2.0'

  # Paths to directories within $D__DIR
  readonly D__DIR_GRAIL="$D__DIR/grail"
  readonly D__DIR_STATE="$D__DIR/state"

  # Paths to directories within $D__DIR_GRAIL
  readonly D__DIR_ASSETS="$D__DIR_GRAIL/assets"
  readonly D__DIR_DPLS="$D__DIR_GRAIL/dpls"

  # Paths to directories within $D__DIR_STATE
  readonly D__DIR_BACKUPS="$D__DIR_STATE/backups"
  readonly D__DIR_STASH="$D__DIR_STATE/stash"
  readonly D__DIR_BUNDLES="$D__DIR_STATE/bundles"
  readonly D__DIR_BUNDLE_BACKUPS="$D__DIR_STATE/bundle-backups"

  # Filename suffix for deployment files
  readonly D__SUFFIX_DPL_SH='.dpl.sh'

  # Filename suffix for asset manifest files
  readonly D__SUFFIX_DPL_MNF='.dpl.mnf'

  # Filename suffix for main queue manifest files
  readonly D__SUFFIX_DPL_QUE='.dpl.que'

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