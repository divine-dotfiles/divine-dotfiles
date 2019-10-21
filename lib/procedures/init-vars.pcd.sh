#!/usr/bin/env bash
#:title:        Divine Bash procedure: init-vars
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.21
#:revremark:    Include variables to play with dotglob and nullglob
#:created_at:   2019.10.11

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Groups initialization of global variables used by the framework
#

# Marker and dependencies
readonly D__PCD_INIT_VARS=loaded

# Driver function
d__pcd_init_vars()
{
  # Ensure variable names are writable
  # d__require_var_names

  # Populate global variables
  d__populate_globals
}

#>  d__require_var_names
#
## DEPRECATED; NOT USED
#
## Currently, this function serves as a registry of ALL global variables used 
#. by all various parts of this framework.
#
## Returns:
#.  0 - All good.
#.  1 - (script exit) At least one variable name is not writable.
#
d__require_var_names()
{
  ## The grand array of all global variable names used by the framework. 
  #. Commented out variables are set by the main script, before this function 
  #. is ever called.
  #
  local d__vars=( \
    # Ultra-core
    # D__DIR D__DIR_FMWK D__DIR_LIB D__EXEC_NAME D__DEP_STACK \
    # Dependency load markers: adapters
    D__ADD_DEBIAN D__ADD_FEDORA D__ADD_FREEBSD D__ADD_MACOS D__ADD_UBUNTU \
    D__ADF_BSD D__ADF_CYGWIN D__ADF_LINUX D__ADF_MACOS D__ADF_MSYS \
    D__ADF_SOLARIS D__ADF_WSL \
    # Dependency load markers: helpers
    D__HLP_COPY_QUEUE D__HLP_GH_QUEUE D__HLP_LINK_QUEUE \
    D__HLP_MULTITASK D__HLP_QUEUE \
    # Dependency load markers: procedures
    D__PCD_ASSEMBLE D__PCD_DETECT_OS D__PCD_INIT_VARS D__PCD_PRE_FLIGHT \
    D__PCD_PREP_SYS D__PCD_PREP_MD5 D__PCD_PREP_STASH D__PCD_PREP_GH \
    D__PCD_PRINT_COLORS D__PCD_PROCESS_ALL_ASSETS D__PCD_SYNC_BUNDLES \
    D__PCD_UNOFFER D__PCD_UPDATE_PKGS D__PCD_PREP_PKGMGR \
    # Dependency load markers: routines
    D__RTN_ATTACH D__RTN_CHECK D__RTN_DETACH D__RTN_HELP D__RTN_INSTALL \
    D__RTN_PLUG D__RTN_REMOVE D__RTN_UPDATE D__RTN_USAGE D__RTN_VERSION \
    # Dependency load markers: utils
    D__UTL_ASSETS D__UTL_BACKUP D__UTL_GITHUB D__UTL_ITEMS D__UTL_MANIFESTS \
    D__UTL_OFFER D__UTL_SCAN D__UTL_STASH D__UTL_WORKFLOW \
    # Core globals
    D__FMWK_NAME D__FMWK_VERSION D__DIR_GRAIL D__DIR_STATE \
    D__DIR_ASSETS D__DIR_DPLS \
    D__DIR_BACKUPS D__DIR_STASH D__DIR_BUNDLES D__DIR_BUNDLE_BACKUPS \
    D__SUFFIX_DPL_SH D__SUFFIX_DPL_MNF D__SUFFIX_DPL_QUE \
    D__CONST_NAME_DIVINEFILE D__CONST_NAME_STASHFILE D__CONST_DEF_PRIORITY \
    D__DISABLE_CASE_SENSITIVITY D__RESTORE_CASE_SENSITIVITY \
    D__ENABLE_DOTGLOB D__RESTORE_DOTGLOB \
    D__ENABLE_NULLGLOB D__RESTORE_NULLGLOB \
    # Arguments and options
    # D__REQ_ROUTINE D__REQ_GROUPS D__REQ_ARGS D__REQ_BUNDLES D__REQ_FILTER \
    # D__REQ_PKGS D__REQ_DPLS \
    # D__OPT_INVERSE D__OPT_FORCE D__OPT_EXCLAM \
    # D__OPT_VERBOSITY D__OPT_ANSWER D__OPT_PLUG_LINK \
    # D__OPT_ANSWER_F D__OPT_ANSWER_S D__OPT_ANSWER_U \
    # Colors
    BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE \
    BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE \
    BOLD DIM ULINE REVERSE STANDOUT NORMAL \
    # OS detection
    D__OS_FAMILY D__OSTYPE D__OS_DISTRO D__OS_PKGMGR \
    # Manifest parsing
    D__MANIFEST_LINES D__MANIFEST_LINE_FLAGS D__MANIFEST_LINE_PRFXS \
    D__MANIFEST_LINE_PRTYS D__MANIFEST_SPLITS D__MANIFEST_ENDSPLIT \
    # Assembly
    D__WKLD D__WKLD_PKGS D__WKLD_DPLS D__WKLD_MAX_PRTY_LEN \
    D__WKLD_PKG_BITS D__WKLD_PKG_FLAGS \
    D__WKLD_DPL_BITS D__WKLD_DPL_NAMES D__WKLD_DPL_DESCS \
    D__WKLD_DPL_FLAGS D__WKLD_DPL_WARNS \
    D__INT_DPL_NAMES D__INT_DPL_NAME_PATHS \
    D__INT_DF_COUNT D__INT_PKG_COUNT D__INT_DPL_COUNT \
    D__EXT_DPL_NAMES D__EXT_DPL_NAME_PATHS \
    D__EXT_DF_COUNT D__EXT_PKG_COUNT D__EXT_DPL_COUNT \
    # Printed intros
    D__INTRO_SKIPD D__INTRO_BLANK D__INTRO_DESCR \
    D__INTRO_CNF_N D__INTRO_CNF_U D__INTRO_HALTN \
    D__INTRO_ATTNT D__INTRO_RBOOT D__INTRO_WARNG D__INTRO_CRTCL \
    D__INTRO_SUCCS D__INTRO_FAILR \
    D__INTRO_CHK_N D__INTRO_CHK_F D__INTRO_CHK_S D__INTRO_CHK_0 \
    D__INTRO_CHK_1 D__INTRO_CHK_2 D__INTRO_CHK_3 D__INTRO_CHK_4 \
    D__INTRO_CHK_5 D__INTRO_CHK_6 D__INTRO_CHK_7 D__INTRO_CHK_8 \
    D__INTRO_CHK_9 \
    D__INTRO_INS_N D__INTRO_INS_F D__INTRO_INS_S D__INTRO_INS_A \
    D__INTRO_INS_0 D__INTRO_INS_1 D__INTRO_INS_2 D__INTRO_INS_3 \
    D__INTRO_RMV_N D__INTRO_RMV_F D__INTRO_RMV_S D__INTRO_RMV_A \
    D__INTRO_RMV_0 D__INTRO_RMV_1 D__INTRO_RMV_2 D__INTRO_RMV_3 \
    D__INTRO_UPD_N D__INTRO_UPD_F D__INTRO_UPD_S \
    D__INTRO_UPD_0 D__INTRO_UPD_1 D__INTRO_UPD_2 D__INTRO_UPD_3 \
    D__INTRO_QCH_N D__INTRO_QCH_F D__INTRO_QCH_S D__INTRO_QCH_0 \
    D__INTRO_QCH_1 D__INTRO_QCH_2 D__INTRO_QCH_3 D__INTRO_QCH_4 \
    D__INTRO_QCH_5 D__INTRO_QCH_6 D__INTRO_QCH_7 D__INTRO_QCH_8 \
    D__INTRO_QCH_9 \
    D__INTRO_QIN_N D__INTRO_QIN_F D__INTRO_QIN_S D__INTRO_QIN_A \
    D__INTRO_QIN_0 D__INTRO_QIN_1 D__INTRO_QIN_2 D__INTRO_QIN_3 \
    D__INTRO_QRM_N D__INTRO_QRM_F D__INTRO_QRM_S D__INTRO_QRM_A \
    D__INTRO_QRM_0 D__INTRO_QRM_1 D__INTRO_QRM_2 D__INTRO_QRM_3 \
    D__INTRO_ATC_N D__INTRO_ATC_F D__INTRO_ATC_S \
    D__INTRO_ATC_0 D__INTRO_ATC_1 D__INTRO_ATC_2 \
    D__INTRO_DTC_N D__INTRO_DTC_F D__INTRO_DTC_S \
    D__INTRO_DTC_0 D__INTRO_DTC_1 D__INTRO_DTC_2 \
    D__INTRO_PLG_N D__INTRO_PLG_F D__INTRO_PLG_S \
    D__INTRO_PLG_0 D__INTRO_PLG_1 D__INTRO_PLG_2 \
    # Method of accessing Github
    D__GH_METHOD \
    # Regular deployments
    D_DPL_NAME D_DPL_DESC D_DPL_PRIORITY D_DPL_FLAGS D_DPL_WARNING \
    D__DPL_SH_PATH D__DPL_MNF_PATH D_DPL_QUE_PATH \
    D__DPL_DIR D__DPL_ASSET_DIR D__DPL_BACKUP_DIR \
    D__DPL_CHECK_CODE D__DPL_IS_FORCED \
    # Add-statuses
    D_ADDST_HALT D_ADDST_PROMPT \
    D_ADDST_ATTENTION D_ADDST_REBOOT D_ADDST_WARNING D_ADDST_CRITICAL \
    D_ADDST_MLTSK_HALT D_ADDST_QUEUE_HALT \
    D_ADDST_CHECK_CODE D_ADDST_INSTALL_CODE D_ADDST_REMOVE_CODE \
    # Multitask deployments
    D_MLTSK_MAIN D__MLTSK_CAP_NUM D__TASKS_ARE_QUEUES \
    D__TASK_NAME D__TASK_NUM D__TASK_IS_QUEUE \
    D__TASK_CHECK_CODES D__TASK_INSTALL_CODES D__TASK_REMOVE_CODES \
    D__TASK_CHECK_CODE D__TASK_IS_FORCED \
    # Queue deployments
    D__QUEUE_SPLIT_POINTS D__QUEUE_SECTNUM D__QUEUE_SECTMIN D__QUEUE_SECTMAX \
    D_QUEUE_MAIN D__QUEUE_CAP_NUM \
    D__ITEM_NAME D__ITEM_NUM \
    D__ITEM_CHECK_CODES D__ITEM_INSTALL_CODES D__ITEM_REMOVE_CODES \
    D__ITEM_CHECK_CODE D__ITEM_INSTALL_CODE D__ITEM_REMOVE_CODE \
    D__QUEUE_CHECK_CODE D__QUEUE_INSTALL_CODE D__QUEUE_REMOVE_CODE \
  )

  # Unset them all in a sub-shell to weed out the read-only's
  ( unset "${d__vars[@]}" &>/dev/null ) && return 0

  # Read-only variables detected; make a list, report, exit script
  if ! ( unset "${d__vars[@]}" &>/dev/null ); then
    local d__var pft pfa=()
    pft='==> Divine.dotfiles: Required variable names are not writable:\n'
    for d__var in "${d__vars[@]}"; do
      ( unset "$d__var" &>/dev/null ) && continue
      pft+='        - %s\n' pfa+=("$d__var")
    done; pft+='\n'
    printf >&2 "$pft" "${pfa[@]}"; exit 1
  fi
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
  readonly D__FMWK_VERSION='2.0.0-alpha1'

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

  return 0
}

d__pcd_init_vars