#!/usr/bin/env bash
#:title:        Divine Bash procedure: init-vars
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Fix minor typo, pt. 3
#:created_at:   2019.10.11

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Groups initialization of global variables used by the framework
#

# Driver function
d__init_vars()
{
  # Ensure variable names are writable
  d__require_var_names

  # Populate global variables
  d__populate_globals
}

#>  d__require_var_names
#
## Ensures that all of the variable names that are used by the framework are 
#. currently not read-only, which would prevent their re-assignment and mess up 
#. the routines.
#
## Returns:
#.  0 - All good.
#.  1 - (script exit) At least one variable name is not writable.
#
d__require_var_names()
{
  ## The grand array of all global variable names used by the framework. In 
  #. addition to these, there are actually four variables set by the main 
  #. script: $D__DIR, $D__DIR_FMWK, $D__DIR_LIB, $D__EXEC_NAME.
  #
  local d__vars=( \
    # Core globals
    D__FMWK_NAME D__FMWK_VERSION D__DIR_GRAIL D__DIR_STATE \
    D__DIR_ASSETS D__DIR_DPLS \
    D__DIR_BACKUPS D__DIR_STASH D__DIR_BUNDLES D__DIR_BUNDLE_BACKUPS \
    D__SUFFIX_DPL_SH D__SUFFIX_DPL_MNF D__SUFFIX_DPL_QUE \
    D__INIT_TRAIN \
    D__CONST_NAME_DIVINEFILE D__CONST_NAME_STASHFILE D__CONST_DEF_PRIORITY \
    D__DISABLE_CASE_SENSITIVITY D__RESTORE_CASE_SENSITIVITY \
    # Arguments and options
    D__REQ_ROUTINE D__REQ_GROUPS D__REQ_ARGS D__REQ_BUNDLES D__REQ_FILTER \
    D__REQ_PKGS D__REQ_DPLS D__REQ_MAX_PRIORITY_LEN \
    D__OPT_INVERSE D__OPT_FORCE D__OPT_EXCLAM D__OPT_QUIET \
    D__OPT_VERBOSITY D__OPT_ANSWER D__OPT_PLUG_LINK \
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
    D__WKLD D__WKLD_PKGS D__WKLD_DPLS \
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
#.  [ too many to list ]
#
## Returns:
#.  0 - Always.
#
d__populate_globals()
{
  # Framework's displayed name
  readonly D__FMWK_NAME='Divine.dotfiles'

  # Framework's displayed version
  readonly D__FMWK_VERSION='1.0.0'

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

  # Ordered list of frameworks shared internal dependencies
  D__INIT_TRAIN=( \
    'procedure print-colors' \
    'util workflow' \
    'procedure prep-1-sys' \
    'util stash' \
    'procedure prep-2-stash' \
    'procedure detect-os' \
  ); readonly D__INIT_TRAIN

  # Name of Divinefile
  readonly D__CONST_NAME_DIVINEFILE='Divinefile'
  
  # Name for stash files
  readonly D__CONST_NAME_STASHFILE=".stash.cfg"

  # Default task priority
  readonly D__CONST_DEF_PRIORITY=4096

  # Textual delimiter for internal use
  readonly D__CONST_DELIMITER=';;;'

  # dprint_ode base options (total width with single space delimiters: 80)
  D__ODE_BASE=( \
    --width-1 3 \
    --width-2 16 \
    --width-3 1 \
    --width-4 57 \
  ); readonly D__ODE_BASE

  # dprint_ode options for normal messages
  D__ODE_NORMAL=( \
    "${D__ODE_BASE[@]}" \
    --effects-1 bci \
    --effects-2 b \
    --effects-3 n \
    --effects-4 n \
  ); readonly D__ODE_NORMAL

  # dprint_ode options for user prompts
  D__ODE_PROMPT=( \
    -n \
    "${D__ODE_NORMAL[@]}" \
    --width-3 2 \
    --effects-1 n \
  ); readonly D__ODE_PROMPT

  # dprint_ode options for user prompts with danger
  D__ODE_DANGER=( \
    -n \
    "${D__ODE_NORMAL[@]}" \
    --width-3 2 \
    --effects-1 bci \
    --effects-2 bc \
  ); readonly D__ODE_DANGER

  # dprint_ode options for descriptions
  D__ODE_DESC=( \
    "${D__ODE_NORMAL[@]}" \
    --effects-1 n \
  ); readonly D__ODE_DESC

  # dprint_ode options for warnings
  D__ODE_WARN=( \
    "${D__ODE_NORMAL[@]}" \
    --effects-1 n \
    --effects-2 bc \
  ); readonly D__ODE_WARN

  # Commands to play with 'nocasematch' (case sensitivity) Bash option
  readonly D__DISABLE_CASE_SENSITIVITY='shopt -s nocasematch'
  readonly D__RESTORE_CASE_SENSITIVITY="$( shopt -p nocasematch )"

  # Global indicators of current request's attributes
  D__REQ_ROUTINE=           # Routine to perform
  D__REQ_GROUPS=()          # Array of groups listed
  D__REQ_ARGS=()            # Array of non-option arguments
  D__REQ_BUNDLES=()         # Array of bundles to process
  D__REQ_FILTER=false       # Flag for whether particular tasks are requested
  D__REQ_PKGS=true          # Flag for whether Divinefiles are requested
  D__REQ_DPLS=true          # Flag for whether deployments are requested
  D__REQ_MAX_PRIORITY_LEN=1 # Number of digits in largest priority

  # Global flags for command line options
  D__OPT_INVERSE=false      # Flag for whether filtering is inverted
  D__OPT_FORCE=false        # Flag for forceful mode
  D__OPT_EXCLAM=false       # Flag for whether include '!'-dpls by default
  D__OPT_QUIET=true         # Verbosity setting (being deprecated)
  D__OPT_VERBOSITY=0        # New verbosity setting
  D__OPT_ANSWER=            # Blanket answer to all prompts
  D__OPT_PLUG_LINK=false    # Flag for whether copy or symlink Grail dir

  return 0
}

d__init_vars