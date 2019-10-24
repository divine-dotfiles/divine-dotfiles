#!/usr/bin/env bash
#:title:        Divine Bash utils: scan
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.24
#:revremark:    Prepend attached path when merging records
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Utilities that scan directories for deployment files (and, by extension, 
#. Divinefiles).
#
## Summary of functions in this file:
#>  d__scan_for_divinefiles [--internal|--external] [--enqueue] \
#>    [--except EXC_DIR]... DIR...
#>  d__scan_for_dpl_files [--internal|--external] [--enqueue] \
#>    [--except EXC_DIR]... DIR...
#>  d__cross_validate_dpls
#

# Marker and dependencies
readonly D__UTL_SCAN=loaded
d__load procedure prep-sys
d__load util workflow
d__load util manifests
d__load procedure detect-os

#>  d__scan_for_divinefiles [--internal|--external] [--enqueue] \
#>    [--except EXC_DIR]... DIR...
#
## Collects packages to be installed from each instance of Divinefile found 
#. within provided directories
#
## Modifies in the global scope (by incrementing):
#.  * with '--internal' option (default):
#.    $D__INT_DF_COUNT        - Divinefile count for this system.
#.    $D__INT_PKG_COUNT       - Package count for this system.
#.  * with '--external' option:
#.    $D__EXT_DF_COUNT        - Divinefile count for this system.
#.    $D__EXT_PKG_COUNT       - Package count for this system.
#
## Modifies in the global scope (with '--enqueue' option, by appending):
#.  $D__WKLD              - Taken priorities.
#.  $D__WKLD_PKGS         - Per priority: package names.
#.  $D__WKLD_PKG_BITS     - Per priority: package bits.
#.  $D__WKLD_PKG_FLAGS    - Per priority: package flags.
#
## Options:
#.  --enqueue         - Signals to add detected packages to framework queues, 
#.                      which are then used in check/install/remove routines.
#.  --except EXC_DIR  - (repeatable) Excludes EXC_DIR directory from the scan.
#
## Type of directories being processed (one option active at a time, last 
#. option wins):
#.  --internal  - (default) Signals that directories passed as arguments are 
#.                framework directories, e.g., $D__DIR_DPLS and 
#.                $D__DIR_BUNDLES.
#.  --external  - Signals that directories passed as arguments are external 
#.                directories, e.g., dirs being added to user's collection.
#
## Returns:
#.  0 - Gleaned packages; all provided directories and Divinefiles in them are 
#.      accessible. This return code includes the case where there are zero 
#.      packages for current system overall.
#.  1 - Otherwise.
#
d__scan_for_divinefiles()
{
  # Parse options
  local args=() int_d=true enqn=false excd=()
  while (($#)); do case $1 in
    --internal) int_d=true;;
    --external) int_d=false;;
    --enqueue)  enqn=true;;
    --except)   shift; (($#)) && excd+=( -path "$1" -prune -o ) || break;;
    *)          args+=("$1");;
  esac; shift; done

  # Cut-off checks for queueing mode (internal mode only)
  if $int_d && $enqn; then local d__rsn=()
    $D__REQ_PKGS || d__rsn+=( -i- '- Divinefiles not requested' )
    [ -z "$D__OS_PKGMGR" ] && d__rsn+=( -i- '- package manager not supported' )
    if ((${#d__rsn[@]})); then
      d__notify -qq -- 'Skipping assembling packages:' "${d__rsn[@]}"
      return 0
    fi
  fi

  d__context -- push 'Scanning for Divinefiles'

  # Storage variables
  local scan_dir df_filepath ii mnf_line chunks chunk algd=true
  local pkg_prty d__pkg_b d__pkg_f pkg_list pkg_mgr alt_list
  local df_count=0 df_pkg_count pkg_count=0

  $D__DISABLE_CASE_SENSITIVITY

  # Iterate over given directories
  for scan_dir in "${args[@]}"; do

    # Switch context; perform cut-off check
    d__context -- push "Scanning in: $scan_dir"
    if ! [ -r "$scan_dir" -a -d "$scan_dir" ]; then
      if ! $int_d; then algd=false
        d__notify -lxt 'Failed to access' -- "$scan_dir"
      fi
      d__context -- pop 'Not a readable directory; skipping'; continue
    fi

    # Iterate over every Divinefile in that deployments dir
    while IFS= read -r -d $'\0' df_filepath; do ((++df_count)); df_pkg_count=0

      # Switch context; parse Divinefile (phase 1); perform cut-off checks
      d__context -- push "Parsing Divinefile at: ${df_filepath#"$scan_dir/"}"
      if ! d__process_manifest "$df_filepath"; then
        d__notify -lxh -- 'Not a readable file; skipping'
        d__context -- pop; algd=false; continue
      fi
      if ! ((${#D__MANIFEST_LINES[@]})); then
        d__notify -!h -- 'Empty Divinefile; skipping'
        d__context -- pop; continue
      fi

      # Iterate over lines in Divinefile
      for ((ii=0;ii<${#D__MANIFEST_LINES[@]};++ii)); do

        # Parse Divinefile (phase 2)

        # Extract line, priority, flags; set empty defaults for parsing output
        mnf_line="${D__MANIFEST_LINES[$ii]}"
        pkg_prty="${D__MANIFEST_LINE_PRTYS[$ii]}"
        d__pkg_f="${D__MANIFEST_LINE_FLAGS[$ii]}"
        if [ -n "$d__pkg_f" ]; then d__pkg_b=1
        else d__pkg_b=0 d__pkg_f='---'; fi

        # Split line by v-bars; pick default list
        IFS='|' read -r -a chunks <<<"$mnf_line"
        pkg_list="${chunks[0]}"; chunks=("${chunks[@]:1}")

        # Iterate over potential alt-lists; pick first relevant one, if any
        for chunk in "${chunks[@]}"; do
          IFS=':' read -r pkg_mgr alt_list <<<"$chunk"
          read -r pkg_mgr <<<"$pkg_mgr"
          if [[ $D__OS_PKGMGR = $pkg_mgr ]]
          then pkg_list="$alt_list"; break; fi
        done

        # Validate package names; conditionally enqueue
        read -r -a chunks <<<"$pkg_list"
        for chunk in "${chunks[@]}"; do
          [ -z "$chunk" ] && continue
          ((++df_pkg_count)); $enqn || continue
          D__WKLD[$pkg_prty]='taken'
          if [ -z ${D__WKLD_PKGS[$pkg_prty]+isset} ]; then
            D__WKLD_PKGS[$pkg_prty]="$chunk"
            D__WKLD_PKG_BITS[$pkg_prty]="$d__pkg_b"
            D__WKLD_PKG_FLAGS[$pkg_prty]="$d__pkg_f"
          else
            D__WKLD_PKGS[$pkg_prty]+=$'\n'"$chunk"
            D__WKLD_PKG_BITS[$pkg_prty]+=$'\n'"$d__pkg_b"
            D__WKLD_PKG_FLAGS[$pkg_prty]+=$'\n'"$d__pkg_f"
          fi
        done

      # Done iterating over lines in Divinefile
      done

      ((pkg_count+=$df_pkg_count))
      d__context -- pop "Gleaned $df_pkg_count packages"

    # Done iterating over every Divinefile in that deployments dir
    done < <( find -L "$scan_dir" \( "${excd[@]}" \
      -name "$D__CONST_NAME_DIVINEFILE" \) -type f -print0 )
    
    d__context -- pop

  # Done iterating over given directories
  done

  $D__RESTORE_CASE_SENSITIVITY

  # Increment global package count
  if $int_d; then
    ((D__INT_DF_COUNT+=$df_count)); ((D__INT_PKG_COUNT+=$pkg_count))
  else
    ((D__EXT_DF_COUNT+=$df_count)); ((D__EXT_PKG_COUNT+=$pkg_count))
  fi

  # Return based on quality of Divinefiles
  d__context -- pop "Gleaned $pkg_count packages from $df_count Divinefiles"
  $algd && return 0 || return 1
}

#>  d__scan_for_dpl_files [--internal|--external] [--enqueue] \
#>    [--except EXC_DIR]... DIR...
#
## Scans all provided directories for deployment files (*.dpl.sh). Dumps names 
#. and paths of the deployments into global arrays.
#
## This function supports keeping two sets of deployments, which is useful for 
#. merging, e.g., during attaching of third-party deployments.
#
## Modifies in the global scope (by appending/incrementing):
#.  * with '--internal' option (default):
#.    $D__INT_DPL_NAMES       - Names of deployments.
#.    $D__INT_DPL_NAME_PATHS  - Per name: paths to deployment files.
#.    $D__INT_DPL_COUNT       - Deployment count.
#.  * with '--external' option:
#.    $D__EXT_DPL_NAMES       - Names of deployments.
#.    $D__EXT_DPL_NAME_PATHS  - Per name: paths to deployment files.
#.    $D__EXT_DPL_COUNT       - Deployment count.
#
## Modifies in the global scope (with '--enqueue' option, by appending):
#.  $D__WKLD                    - Taken priorities.
#.  $D__WKLD_DPLS               - Per priority: deployment filepaths.
#.  $D__WKLD_DPL_BITS           - Per priority: deployment bits.
#.  $D__WKLD_DPL_NAMES          - Per priority: deployment names.
#.  $D__WKLD_DPL_DESCS          - Per priority: deployment descriptions.
#.  $D__WKLD_DPL_FLAGS          - Per priority: deployment flags.
#.  $D__WKLD_DPL_WARNS          - Per priority: deployment warnings.
#.  $D__LIST_OF_ILLEGAL_DPL_PATHS   - (array) Deployment paths that contain 
#.                                    reserved character patterns
#
## Options:
#.  --enqueue         - Signals to add detected deployments to framework 
#.                      queues, which are then used in check/install/remove 
#.                      routines.
#.  --except EXC_DIR  - (repeatable) Excludes EXC_DIR directory from the scan.
#
## Type of directories being processed (one option active at a time, last 
#. option wins):
#.  --internal  - (default) Signals that directories passed as arguments are 
#.                framework directories, e.g., $D__DIR_DPLS and 
#.                $D__DIR_BUNDLES.
#.  --external  - Signals that directories passed as arguments are external 
#.                directories, e.g., dirs being added to user's collection.
#
## Returns:
#.  0 - Gleaned deployments; there are no name duplications; names do not break 
#.      conventions; all provided directories and deployment files in them are 
#.      accessible. This return code includes the case where there are zero 
#.      deployments overall.
#.  1 - Otherwise.
#
d__scan_for_dpl_files()
{
  # Parse options
  local args=() int_d=true enqn=false excd=()
  while (($#)); do case $1 in
    --internal) int_d=true;;
    --external) int_d=false;;
    --enqueue)  enqn=true;;
    --except)   shift; (($#)) && excd+=( -path "$1" -prune -o ) || break;;
    *)          args+=("$1");;
  esac; shift; done

  # Cut-off checks for queueing mode
  if $int_d && $enqn && ! $D__REQ_DPLS; then
    d__notify -qq -- 'Skipping assembling deployments (not requested)'
    return 0
  fi

  d__context -- push 'Scanning for deployments'

  # Storage variables
  local scan_dir d__dpl_p d__dpl_n d__dpl_d dpl_prty d__dpl_f d__dpl_w
  local dpll ii jj tmp vlu mtdt algd=true dpl_relpath dpl_showpath d__dpl_b
  local dpl_name_taken dpl_names=() dpl_name_paths=() dpl_bad_names=()
  local dpl_name_counts=() dpl_name_dupls=() dpl_bad dpl_count=0

  $D__DISABLE_CASE_SENSITIVITY

  # Iterate over given directories
  for scan_dir in "${args[@]}"; do

    # Switch context; perform cut-off check
    d__context -- push "Scanning in: $scan_dir"
    if ! [ -r "$scan_dir" -a -d "$scan_dir" ]; then
      if ! $int_d; then algd=false
        d__notify -lxt 'Failed to access' -- "$scan_dir"
      fi
      d__context -- pop 'Not a readable directory; skipping'; continue
    fi

    # Iterate over deployment files in current deployment directory
    while IFS= read -r -d $'\0' d__dpl_p; do

      # Switch context; perform cut-off checks
      dpl_relpath="${d__dpl_p#"$scan_dir/"}"; dpl_bad=false
      $int_d && dpl_showpath="$d__dpl_p" || dpl_showpath="$dpl_relpath"
      d__context -- push "Parsing deployment at: $dpl_relpath"
      if ! [ -r "$d__dpl_p" -a -f "$d__dpl_p" ]; then
        d__notify -lxh -- 'Not a readable file; skipping'
        d__context -- pop; algd=false; continue
      fi

      # Look for metadata in the first few non-empty lines of the file
      unset mtdt; ii=20
      while read -r dpll || [[ -n "$dpll" ]]; do [ -z "$dpll" ] && continue
        ((ii--)) || break; [[ $dpll = D_DPL_* ]] || continue
        case ${dpll:6} in NAME=*) jj=0;; DESC=*) jj=1;; PRIORITY=*) jj=2;;
          FLAGS=*) jj=3;; WARNING=*) jj=4;; *) continue;; esac
        IFS='=' read -r tmp vlu <<<"$dpll"
        [[ $vlu = \'*\' || $vlu = \"*\" ]] \
          && read -r vlu <<<"${vlu:1:${#vlu}-2}"
        [ -n "$vlu" ] && mtdt[$jj]="$vlu"
      done < "$d__dpl_p"

      # Process deployment name
      d__dpl_n="${mtdt[0]}"
      if [ -z "$d__dpl_n" ]; then
        d__dpl_n="$( basename -- "$d__dpl_p" )"
        d__dpl_n=${d__dpl_n%$D__SUFFIX_DPL_SH}
      fi

      # Store data for later check against duplicate names
      dpl_name_taken=false
      for ((ii=0;ii<${#dpl_names[@]};ii++)); do
        [[ $d__dpl_n = ${dpl_names[$ii]} ]] || continue
        dpl_name_taken=true; ((++dpl_name_counts[$ii]))
        ((${dpl_name_counts[$ii]}==2)) && dpl_name_dupls+=($ii)
        dpl_name_paths[$ii]+=$'\n'"$dpl_showpath"; break
      done
      if $dpl_name_taken; then dpl_bad=true; else
        dpl_names+=("$d__dpl_n"); dpl_name_paths+=("$dpl_showpath")
        dpl_name_counts+=(1)
      fi

      # Validate deployment name against naming rules
      if ! d___validate_dpl_name
      then dpl_bad=true; $dpl_name_taken || dpl_bad_names+=($ii); fi

      # Midway cut-off check (error announcements are grouped below)
      if $dpl_bad; then
        d__context -qst 'Skipping' -- pop "Bad deployment: $dpl_showpath"
        continue
      fi

      # Continue only when enqueueing; run filters against name and flags
      ((++dpl_count)); d__dpl_f="${mtdt[3]}"
      if $enqn && d___run_dpl_through_filters; then :
      else d__context -- pop; continue; fi

      # Process deployment description
      d__dpl_d="${mtdt[1]}"
      if [ -n "$d__dpl_d" ]; then d__dpl_b=1
      else d__dpl_b=0 d__dpl_d='---'; fi

      # Process deployment priority
      dpl_prty="${mtdt[2]}"
      if [[ $dpl_prty =~ ^[0-9]+$ ]]; then dpl_prty=$(($dpl_prty))
      else dpl_prty="$D__CONST_DEF_PRIORITY"; fi

      # Finish processing deployment flags
      if [ -n "$d__dpl_f" ]; then d__dpl_b+=1
      else d__dpl_b+=0 d__dpl_f='---'; fi
      
      # Process deployment warning
      d__dpl_w="${mtdt[4]}"
      if [ -n "$d__dpl_w" ]; then d__dpl_b+=1
      else d__dpl_b+=0 d__dpl_w='---'; fi

      # Queue up current deployment
      D__WKLD[$dpl_prty]='taken'
      if [ -z ${D__WKLD_DPLS[$dpl_prty]+isset} ]; then
        D__WKLD_DPLS[$dpl_prty]="$d__dpl_p"
        D__WKLD_DPL_BITS[$dpl_prty]="$d__dpl_b"
        D__WKLD_DPL_NAMES[$dpl_prty]="$d__dpl_n"
        D__WKLD_DPL_DESCS[$dpl_prty]="$d__dpl_d"
        D__WKLD_DPL_FLAGS[$dpl_prty]="$d__dpl_f"
        D__WKLD_DPL_WARNS[$dpl_prty]="$d__dpl_w"
      else
        D__WKLD_DPLS[$dpl_prty]+=$'\n'"$d__dpl_p"
        D__WKLD_DPL_BITS[$dpl_prty]+=$'\n'"$d__dpl_b"
        D__WKLD_DPL_NAMES[$dpl_prty]+=$'\n'"$d__dpl_n"
        D__WKLD_DPL_DESCS[$dpl_prty]+=$'\n'"$d__dpl_d"
        D__WKLD_DPL_FLAGS[$dpl_prty]+=$'\n'"$d__dpl_f"
        D__WKLD_DPL_WARNS[$dpl_prty]+=$'\n'"$d__dpl_w"
      fi

      d__context -- pop

    # Done iterating over deployment files in current deployment directory
    done < <( find -L "$scan_dir" \( "${excd[@]}" \
      -name "*$D__SUFFIX_DPL_SH" \) -type f -print0 )
    
    d__context -- pop

  # Done iterating over given directories
  done

  $D__RESTORE_CASE_SENSITIVITY

  # Report errors, if any
  if ((${#dpl_bad_names[@]})); then for ii in ${dpl_bad_names[@]}; do
    d__dpl_n="${dpl_names[$ii]}"; tmp=()
    IFS=$'\n' read -r -d '' -a jj <<<"${dpl_name_paths[$ii]}"
    for dpl_showpath in "${jj[@]}"; do tmp+=( -i- "$dpl_showpath" ); done
    d__notify -lxh -- "Deployment uses reserved name '$d__dpl_n':" "${tmp[@]}"
  done; fi
  if ((${#dpl_name_dupls[@]})); then for ii in ${dpl_name_dupls[@]}; do
    d__dpl_n="${dpl_names[$ii]}"; tmp=()
    IFS=$'\n' read -r -d '' -a jj <<<"${dpl_name_paths[$ii]}"
    for dpl_showpath in "${jj[@]}"; do tmp+=( -i- "$dpl_showpath" ); done
    d__notify -lxh -- "Deployments share name '$d__dpl_n':" "${tmp[@]}"
  done; fi

  # Append to/increment global arrays
  if $int_d; then
    D__INT_DPL_NAMES=("${dpl_names[@]}")
    D__INT_DPL_NAME_PATHS=("${dpl_name_paths[@]}")
    ((D__INT_DPL_COUNT+=$dpl_count))
  else
    D__EXT_DPL_NAMES=("${dpl_names[@]}")
    D__EXT_DPL_NAME_PATHS=("${dpl_name_paths[@]}")
    ((D__EXT_DPL_COUNT+=$dpl_count))
  fi

  # Return based on quality of deployments
  d__context -- pop "Detected $dpl_count valid deployments"
  $algd && return 0 || return 1
}

#>  d___validate_dpl_name
#
## INTERNAL USE ONLY
#
## Checks if provided textual deployment name is valid, i.e., it does not 
#. coincide with reserved phrases, such as 'Divinefile' or pre-defined names of 
#. deployment groups.
#
## It is expected that Bash option 'nocasematch' is enabled in the calling 
#. scope.
#
## Local variables that must be set in the calling scope:
#.  $d__dpl_n   - Textual name of the deployment
#
## Returns:
#.  0 - Name is valid
#.  1 - Otherwise
#
d___validate_dpl_name()
{
  case $d__dpl_n in
    Divinefile|dfile|df) return 1;;
    [0-9]|\!) return 1;;
    *) return 0
  esac
}

#>  d__cross_validate_dpls
#
## Confirms that deployments, previously detected in external directories, 
#. would not conflict with deployments, previously detected in framework's 
#. internal directories, if merged together. Both sources are assumed to have 
#. been individually validated prior to running this function.
#
## Validation rules are as follows:
#.  * When combined, each deployment name must occur no more than once.
#
## Requires in the global scope:
#.  $D__INT_DPL_NAMES         - Names of deployments.
#.  $D__INT_DPL_NAME_PATHS    - Per name: paths to deployment files.
#.  $D__EXT_DPL_NAMES         - Names of deployments.
#.  $D__EXT_DPL_NAME_PATHS    - Per name: paths to deployment files.
#
## Returns:
#.  0 - All previously detected deployments are cross-valid (ready to merge).
#.  1 - Otherwise.
#
d__cross_validate_dpls()
{
  # Switch context; prepare storage vars
  d__context -- push 'Cross-validating external deployments'
  local ii jj algd=true err_msg idap idp edap edp
  
  $D__DISABLE_CASE_SENSITIVITY

  # Iterate over names of deployments detected in external dirs
  for ((jj=0;jj<${#D__EXT_DPL_NAMES[@]};++jj)); do
    # Iterate over names of deployments detected in internal dirs
    for ((ii=0;ii<${#D__INT_DPL_NAMES[@]};++ii)); do
      [[ ${D__INT_DPL_NAMES[$ii]} = ${D__EXT_DPL_NAMES[$jj]} ]] || continue
      IFS=$'\n' read -r -d '' -a idap <<<"${D__INT_DPL_NAME_PATHS[$ii]}"
      IFS=$'\n' read -r -d '' -a edap <<<"${D__EXT_DPL_NAME_PATHS[$jj]}"
      err_msg=( "External deployment named '${D__EXT_DPL_NAMES[$jj]}' at:" )
      for edp in "${edap[@]}"
      do err_msg+=( -i- "$edp" ); done
      err_msg+=( -n- "collides with namesake internal deployment at:" )
      for idp in "${idap[@]}"
      do err_msg+=( -i- "$idp" ); done
      err_msg+=( -n- 'Deployment names must be unique' )
      d__notify -lxh -- "${err_msg[@]}"; algd=false
    # Done iterating over names of deployments detected in internal dirs
    done
  # Done iterating over names of deployments detected in external dirs
  done

  $D__RESTORE_CASE_SENSITIVITY

  # Return based on whether matches encountered
  d__context -- pop 'Cross-validation complete'
  $algd && return 0 || return 1
}

#>  d__merge_ext_into_int PATH_PREFIX
#
## Merges previously assembled records of deployments in the external 
#. directories into the previously assebled records of deployments in the 
#. internal directories. Does no validation whatsoever.
#
## Arguments:
#.  PATH_PREFIX     - Path to the directory that now contains the external 
#.                    deployments, which are being merged. Trailing slash 
#.                    should be omitted. This path will be prepended to the 
#.                    relative paths that are stored in $D__EXT_DPL_NAME_PATHS.
#
## Requires in the global scope:
#.  $D__INT_DPL_NAMES         - Names of deployments.
#.  $D__INT_DPL_NAME_PATHS    - Per name: paths to deployment files.
#.  $D__INT_DPL_COUNT         - Number of detected deployments.
#.  $D__INT_DF_COUNT          - Number of detected Divinefiles.
#.  $D__INT_PKG_COUNT         - Number of detected packages.
#.  $D__EXT_DPL_NAMES         - Names of deployments.
#.  $D__EXT_DPL_NAME_PATHS    - Per name: paths to deployment files.
#.  $D__EXT_DPL_COUNT         - Number of detected deployments.
#.  $D__EXT_DF_COUNT          - Number of detected Divinefiles.
#.  $D__EXT_PKG_COUNT         - Number of detected packages.
#
## Returns:
#.  0 - Always.
#
d__merge_ext_into_int()
{
  d__context -- notch
  d__context -- push 'Merging records of detected deployments' \
    'in external and internal directories'
  local pfx="$1" ii
  if ! [ -d "$pfx"]; then
    d__notify -lx -- 'Merging of external records initiated' \
      'with a prefix path that is not a directory:' -i- "$pfx"
  fi
  for ((ii=0;ii<${#D__EXT_DPL_NAMES[@]};++ii)); do
    D__INT_DPL_NAMES+=("${D__EXT_DPL_NAMES[$ii]}")
    D__INT_DPL_NAME_PATHS+=("$pfx/${D__EXT_DPL_NAME_PATHS[$ii]}")
  done
  ((D__INT_DPL_COUNT+=$D__EXT_DPL_COUNT))
  ((D__INT_DF_COUNT+=$D__EXT_DF_COUNT))
  ((D__INT_PKG_COUNT+=$D__EXT_PKG_COUNT))
  D__EXT_DPL_NAMES=() D__EXT_DPL_NAME_PATHS=()
  D__EXT_DPL_COUNT=0 D__EXT_DF_COUNT=0 D__EXT_PKG_COUNT=0
  d__context -- lop; return 0
}