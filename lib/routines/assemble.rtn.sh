#!/usr/bin/env bash
#:title:        Divine Bash routine: assemble
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.10
#:revremark:    Fix minor typo
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Assembles packages and deployments for further processing
#

#>  d__dispatch_assembly_job
#
## Dispatcher function that forks depending on routine
#
## Returns:
#.  Whatever is returned by child function
#
d__dispatch_assembly_job()
{
  case $D__REQ_ROUTINE in
    check)    d__assemble_tasks;;
    install)  d__assemble_tasks;;
    remove)   d__assemble_tasks;;
    *)        :;;
  esac
}

#>  d__init_assembly_vars
#
## The entire assembly system relies heavily on global variables. This function 
#. groups initialization of those globals as a way of cataloguing.
#
## Empties out or resets all global containers (variables, mostly arrays) that 
#. are used by the assembly system to store data collected on packages and 
#. deployments.
#
## Workload main containers (data for primary routines):
#.  $D__WKLD        - (array) Integer indices of this array correspond to 
#.                        numerical priorities. If any value is set at a 
#.                        particular index of this array, then that index/
#.                        priority is understood to contain at least one 
#.                        package or deployment.
#.  $D__WKLD_PKGS   - (array of newline-delimited 'arrays') In this array, 
#.                        each index/priority that is taken by at least one 
#.                        package contains a delimited list of those package 
#.                        names.
#.  $D__WKLD_DPLS   - (array of newline-delimited 'arrays') In this array, 
#.                        each index/priority that is taken by at least one 
#.                        deployment contains a delimited list of paths to 
#.                        those deployments.
#
## Workload extra containers (pkg-related data for primary routines):
#.  $D__WKLD_PKG_BITS   - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one package contains a delimited set of 
#.                            bit strings for each of those packages. The 
#.                            single bit indicates whether the package has 
#.                            flags.
#.  $D__WKLD_PKG_FLAGS  - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one package contains a delimited set of 
#.                            flags for each of those packages.
#
## Workload extra containers (dpl-related data for primary routines):
#.  $D__WKLD_DPL_BITS   - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one deployment contains a delimited set of 
#.                            bit strings for each of those deployments. The 
#.                            bits indicates whether the deployment has 
#.                            description, flags, and warning, respectively.
#.  $D__WKLD_DPL_NAMES  - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one deployment contains a delimited set of 
#.                            names for each of those deployments.
#.  $D__WKLD_DPL_DESCS  - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one deployment contains a delimited set of 
#.                            descriptions for each of those deployments.
#.  $D__WKLD_DPL_FLAGS  - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one deployment contains a delimited set of 
#.                            flags for each of those deployments.
#.  $D__WKLD_DPL_WARNS  - (array of newline-delimited 'arrays') In this 
#.                            array, each index/priority that is taken by at 
#.                            least one deployment contains a delimited set of 
#.                            warnings for each of those deployments.
#
## Internal main containers (data on deployments in framework directories):
#.  $D__INT_DPL_NAMES       - (array) Array of unique deployment names detected 
#.                            thus far.
#.  $D__INT_DPL_NAME_PATHS  - (array) For each unique name in the previous 
#.                            array, this one, at the same index, contains the 
#.                            delimited list of paths to those deployments.
#
## Internal extra variables (data on deployments in framework directories):
#.  $D__INT_DF_COUNT    - (integer) Number of Divinefiles detected thus far.
#.  $D__INT_PKG_COUNT   - (integer) Number of packages gleaned thus far. 
#.                        Duplicate package names all count.
#.  $D__INT_DPL_COUNT   - (integer) Number of valid distinct deployment files 
#.                        gleaned thus far. For duplicate names only the first 
#.                        instance counts. Reserved names don't count.
#
## External main containers (data on deployments in external directories):
#.  $D__EXT_DPL_NAMES       - (array) Array of unique deployment names detected 
#.                            thus far.
#.  $D__EXT_DPL_NAME_PATHS  - (array) For each unique name in the previous 
#.                            array, this one, at the same index, contains the 
#.                            delimited list of paths to those deployments.
#
## External extra variables (data on deployments in external directories):
#.  $D__EXT_DF_COUNT    - (integer) Number of Divinefiles detected thus far.
#.  $D__EXT_PKG_COUNT   - (integer) Number of packages gleaned thus far. 
#.                        Duplicate package names all count.
#.  $D__EXT_DPL_COUNT   - (integer) Number of valid distinct deployment files 
#.                        gleaned thus far. For duplicate names only the first 
#.                        instance counts. Reserved names don't count.
#
d__init_assembly_vars()
{
  # Workload containers
  D__WKLD=() D__WKLD_PKGS=() D__WKLD_DPLS=()
  # Package-related data
  D__WKLD_PKG_BITS=() D__WKLD_PKG_FLAGS=()
  # Deployment-related data
  D__WKLD_DPL_BITS=() D__WKLD_DPL_NAMES=() D__WKLD_DPL_DESCS=()
  D__WKLD_DPL_FLAGS=() D__WKLD_DPL_WARNS=()
  # Internal containers
  D__INT_DPL_NAMES=() D__INT_DPL_NAME_PATHS=()
  D__INT_DF_COUNT=0 D__INT_PKG_COUNT=0 D__INT_DPL_COUNT=0
  # External containers
  D__EXT_DPL_NAMES=() D__EXT_DPL_NAME_PATHS=()
  D__EXT_DF_COUNT=0 D__EXT_PKG_COUNT=0 D__EXT_DPL_COUNT=0
}

#>  d__assemble_tasks
#
## Collects tasks to be performed:
#.  * Package names from Divinefiles
#.  * Deployments from files with *.dpl.sh suffix
#
## The following directories are scanned for these types of files:
#.  * $D__DIR_DPLS      - user's own deployments
#.  * $D__DIR_BUNDLES   - attached deployments from Github
#
## If $D__REQ_BUNDLES is not empty, the search is narrowed down to the 
#. directories of the attached bundles listed in that array.
#
## Provides into the global scope:
#.  $D__WKLD
#.  $D__WKLD_PKGS
#.  $D__WKLD_DPLS
#.  $D__WKLD_PKG_BITS
#.  $D__WKLD_PKG_FLAGS
#.  $D__WKLD_DPL_BITS
#.  $D__WKLD_DPL_NAMES
#.  $D__WKLD_DPL_DESCS
#.  $D__WKLD_DPL_FLAGS
#.  $D__WKLD_DPL_WARNS
#
## Returns:
#.  0 - Arrays assembled successfully
#.  0 - (script exit) Nothing to do (with announcement)
#.  1 - (script exit) Unrecoverable error during assembly
#
## Prints:
#.  stdout: *nothing*
#.  stderr: Error descriptions
#
d__assemble_tasks()
{
  # Switch context
  d__context -- notch
  d__context -- push "Assembling tasks for '$D__REQ_ROUTINE' routine"

  # Synchronize dpl repos
  if ! d__sync_dpl_repos; then
    d__fail -- 'Refusing to assemble tasks in un-synchronized' \
      'deployment directories'
    exit 1
  fi

  # Initialize global variables for assembly data; initialize storage variables
  d__init_assembly_vars; local dirs_to_scan=()

  # Check if a list of bundles is given
  if [ ${#D__REQ_BUNDLES[@]} -gt 0 ]; then

    d__context -- push 'Assembling only from particular bundles'
    local bundle_handle accb=() rejb=()

    ## Iterate over given bundle handles, accepting either 'builtin_repo_name' 
    #. or 'username/repository'
    for bundle_handle in "${D__REQ_BUNDLES[@]}"; do
      if [[ $bundle_handle =~ ^[0-9A-Za-z_.-]+$ ]]; then
        bundle_handle="no-simpler/divine-bundle-$bundle_handle"
      elif [[ $bundle_handle =~ ^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$ ]]; then :
      else rejb+=( -i- "- '$bundle_handle'" ); continue; fi
      accb+=( -i- "- '$bundle_handle'")
      dirs_to_scan+=( "$D__DIR_BUNDLES/$bundle_handle" )
    done

    # Debug output and cut-off for invalid bundle list
    if ((${#accb[@]}))
    then d__notify -qqq -- 'Accepted bundle handles:' "${accb[@]}"; fi
    if ((${#rejb[@]}))
    then d__notify -l! -- 'Rejected bundle handles:' "${rejb[@]}"; fi
    if [ ${#dirs_to_scan[@]} -eq 0 ]; then
      d__fail -- 'Refusing to assemble with an invalid list of bundles'
      exit 1
    fi

  else

    d__context -- push 'Assembling from default deployment directories'
    dirs_to_scan=( "$D__DIR_DPLS" "$D__DIR_BUNDLES" )

  fi

  # Parse Divinefiles and *.dpl.sh files in all directories
  local algd=true
  d__scan_for_divinefiles --internal --enqueue "${dirs_to_scan[@]}" \
    || algd=false
  d__scan_for_dpl_files --internal --enqueue "${dirs_to_scan[@]}" \
    || algd=false
  if $algd; then
    d__context -- pop 'Assembled all tasks in given deployment directories'
  else
    d__fail -t 'Assembly failed' -- 'Refusing to proceed with the routine'
    exit 1
  fi

  # Check if any tasks were found
  if [ ${#D__WKLD[@]} -eq 0 ]; then
    d__notify -lsht 'Nothing to do' -- \
      'Not a single task matched given criteria'
    exit 0
  else
    local pcs dcs
    pcs="$D__INT_PKG_COUNT package"; [ $D__INT_PKG_COUNT -eq 1 ] || pcs+='s'
    dcs="$D__INT_DPL_COUNT deployment"; [ $D__INT_DPL_COUNT -eq 1 ] || dcs+='s'
    d__notify -qq -- "Processing $pcs and $dcs"
  fi

  # Detect largest priority and number of digits in it
  local largest_priority
  for largest_priority in ${!D__WKLD[@]}; do :; done
  readonly D__REQ_MAX_PRIORITY_LEN=${#largest_priority}
  d__notify -qqqq -- "Largest priority detected: $largest_priority"

  # Mark assembled containers read-only
  readonly D__WKLD D__WKLD_PKGS D__WKLD_DPLS
  readonly D__WKLD_PKG_BITS D__WKLD_PKG_FLAGS
  readonly D__WKLD_DPL_BITS D__WKLD_DPL_NAMES D__WKLD_DPL_DESCS
  readonly D__WKLD_DPL_WARNS D__WKLD_DPL_FLAGS
  readonly D__INT_DF_COUNT D__INT_PKG_COUNT D__INT_DPL_COUNT
  readonly D__INT_DPL_NAMES D__INT_DPL_NAME_PATHS

  # Finish up
  d__context -- lop
  return 0
}

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
#.  --internal     - (default) Signals that directories passed as arguments are 
#.              framework directories, e.g., $D__DIR_DPLS and $D__DIR_BUNDLES.
#.  --external     - Signals that directories passed as arguments are external 
#.              directories, e.g., dirs being added to user's collection.
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
  if $int_d && $enqn; then
    local d__rsn=()
    if ! $D__REQ_PKGS
    then d__rsn+=( -i- '- Divinefiles not requested' ); fi
    if [ -z "$D__OS_PKGMGR" ]
    then d__rsn+=( -i- '- package manager not supported' ); fi
    if ((${#d__rsn[@]})); then
      d__notify -qq -- 'Skipping assembling packages:' "${d__rsn[@]}"
      return 1
    fi
  fi

  d__context -- push 'Scanning for Divinefiles'

  # Storage variables
  local scan_dir df_filepath i mnf_line chunks chunk algd=true
  local pkg_prty d__pkg_b d__pkg_f pkg_list pkg_mgr alt_list
  local df_count=0 df_pkg_count pkg_count=0

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"
  shopt -s nocasematch

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
      for (( i=0; i<${#D__MANIFEST_LINES[@]}; i++ )); do

        # Parse Divinefile (phase 2)

        # Extract line, priority, flags; set empty defaults for parsing output
        mnf_line="${D__MANIFEST_LINES[$i]}"
        pkg_prty="${D__MANIFEST_LINE_PRIORITIES[$i]}"
        d__pkg_f="${D__MANIFEST_LINE_FLAGS[$i]}"
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

  # Restore case sensitivity
  $restore_nocasematch

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
#.  --internal     - (default) Signals that directories passed as arguments are 
#.              framework directories, e.g., $D__DIR_DPLS and $D__DIR_BUNDLES.
#.  --external     - Signals that directories passed as arguments are external 
#.              directories, e.g., dirs being added to user's collection.
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
    return 1
  fi

  d__context -- push 'Scanning for deployments'

  # Storage variables
  local scan_dir d__dpl_p d__dpl_n d__dpl_d dpl_prty d__dpl_f d__dpl_w
  local dpl_line i j tmp vlu mtdt algd=true dpl_relpath dpl_showpath d__dpl_b
  local dpl_name_taken dpl_names=() dpl_name_paths=() dpl_bad_names=()
  local dpl_name_counts=() dpl_name_dupls=() dpl_bad dpl_count=0

  # Store current case sensitivity setting, then turn it off
  local restore_nocasematch="$( shopt -p nocasematch )"; shopt -s nocasematch

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

      # Look for metadata in the first five non-empty lines of the file
      unset mtdt; i=5; while (($i)); do read -r dpl_line
        [ -z "$dpl_line" ] && continue; ((--i))
        [[ $dpl_line = D_DPL_* ]] || continue
        case ${dpl_line:6} in NAME=*) j=0;; DESC=*) j=1;; PRIORITY=*) j=2;;
          FLAGS=*) j=3;; WARNING=*) j=4;; *) continue;; esac
        IFS='=' read -r tmp vlu <<<"$dpl_line"
        [[ $vlu = \'*\' || $vlu = \"*\" ]] \
          && read -r vlu <<<"${vlu:1:${#vlu}-2}"
        [ -n "$vlu" ] && mtdt[$j]="$vlu"
      done < "$d__dpl_p"

      # Process deployment name
      d__dpl_n="${mtdt[0]}"
      if [ -z "$d__dpl_n" ]; then
        d__dpl_n="$( basename -- "$d__dpl_p" )"
        d__dpl_n=${d__dpl_n%$D__SUFFIX_DPL_SH}
      fi

      # Store data for later check against duplicate names
      dpl_name_taken=false
      for ((i=0;i<${#dpl_names[@]};i++)); do
        [[ $d__dpl_n = ${dpl_names[$i]} ]] || continue
        dpl_name_taken=true; ((++dpl_name_counts[$i]))
        ((${dpl_name_counts[$i]}==2)) && dpl_name_dupls+=($i)
        dpl_name_paths[$i]+=$'\n'"$dpl_showpath"; break
      done
      if $dpl_name_taken; then dpl_bad=true; else
        dpl_names+=("$d__dpl_n"); dpl_name_paths+=("$dpl_showpath")
        dpl_name_counts+=(1)
      fi

      # Validate deployment name against naming rules
      if ! d___validate_dpl_name
      then dpl_bad=true; $dpl_name_taken || dpl_bad_names+=($i); fi

      # Midway cut-off check (error announcements are grouped below)
      if $dpl_bad; then
        d__context -qst 'Skipping' -- pop "Bad deployment: $dpl_showpath"
        continue
      fi

      # Continue only when enqueueing; run filters against name and flags
      ((++dpl_count)); d__dpl_f="${mtdt[3]}"
      if $enqn && d__run_dpl_through_filters; then :
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

  # Restore case sensitivity
  $restore_nocasematch

  # Report errors, if any
  if ((${#dpl_bad_names[@]})); then for i in ${dpl_bad_names[@]}; do
    d__dpl_n="${dpl_names[$i]}"; tmp=()
    IFS=$'\n' read -r -d '' -a j <<<"${dpl_name_paths[$i]}"
    for dpl_showpath in "${j[@]}"; do tmp+=( -i- "$dpl_showpath" ); done
    d__notify -lxh -- "Deployment uses reserved name '$d__dpl_n':" "${tmp[@]}"
  done; fi
  if ((${#dpl_name_dupls[@]})); then for i in ${dpl_name_dupls[@]}; do
    d__dpl_n="${dpl_names[$i]}"; tmp=()
    IFS=$'\n' read -r -d '' -a j <<<"${dpl_name_paths[$i]}"
    for dpl_showpath in "${j[@]}"; do tmp+=( -i- "$dpl_showpath" ); done
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

#>  d__run_dpl_through_filters
#
## INTERNAL USE ONLY
#
## Performs filtering duty: checks given name and flags of a deployment against 
#. scripts arguments to decide whether this deployment should be queued up or 
#. not.
#
## Local variables that must be set in the calling scope:
#.  $d__dpl_n   - Textual name of the deployment
#.  $d__dpl_f  - Textual flags of the deployment
#
## Returns:
#.  0 - Deployment should be queued up
#.  1 - Otherwise
#
d__run_dpl_through_filters()
{
  # Without filtering: just mind the dangerous dpls ('!' flag)
  if ! $D__REQ_FILTER; then
    $D__OPT_EXCLAM && return 0
    [[ $d__dpl_f == *'!'* ]] && return 1 || return 0
  fi

  # Fork based on filtering mode
  local tmp; if $D__OPT_INVERSE; then

    # Inverse filtering: Whatever is listed in arguments is filtered out

    # Always reject deployments in '!' group, unless asked not to
    if ! $D__OPT_EXCLAM; then [[ $d__dpl_f == *'!'* ]] && return 1; fi
    # If this deployment belongs to rejected group, remove it
    for tmp in "${D__REQ_GROUPS[@]}"
    do [[ $d__dpl_f == *"$tmp"* ]] && return 1; done
    # If this deployment is specifically rejected, remove it
    for tmp in "${D__REQ_ARGS[@]}"
    do [[ $d__dpl_n == $tmp ]] && return 1; done
    # Otherwise: good to go
    return 0

  else

    # Normal filtering: Only what is listed in arguments is added

    # Status variables
    local group_matched=false exclam_requested=false
    # Check if this dpl belongs to requested group; store '!' group status
    for tmp in "${D__REQ_GROUPS[@]}"; do
      if [[ $d__dpl_f == *"$tmp"* ]]; then
        # Either return immediately, or just mark it for now
        $D__OPT_EXCLAM && return 0 || group_matched=true
      fi
      [ "$tmp" = '!' ] && exclam_requested=true
    done
    # Check if group matched, and if '!' group has been requested
    if $group_matched; then
      if $exclam_requested; then
        # Group matched and '!' group is explicitly requested: valid match
        return 0
      else
        ## Group matched, but '!' group is not explicitly requested: match is 
        #. only valid if dpl is not marked with '!' flag
        [[ $d__dpl_f == *'!'* ]] || return 0
      fi
    fi
    # If this deployment is specifically requested, add it
    for tmp in "${D__REQ_ARGS[@]}"
    do [[ $d__dpl_n == $tmp ]] && return 0; done
    # Otherwise: no-go
    return 1

  fi
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
  # Switch context; prepare storage vars; disable case sensitivity
  d__context -- push 'Cross-validating external deployments'
  local i j algd=true err_msg idap idp edap edp
  local restore_nocasematch="$( shopt -p nocasematch )"; shopt -s nocasematch

  # Iterate over names of deployments detected in external dirs
  for ((j=0;j<${#D__EXT_DPL_NAMES[@]};++j)); do
    # Iterate over names of deployments detected in internal dirs
    for ((i=0;i<${#D__INT_DPL_NAMES[@]};++i)); do
      [[ ${D__INT_DPL_NAMES[$i]} = ${D__EXT_DPL_NAMES[$j]} ]] || continue
      IFS=$'\n' read -r -d '' -a idap <<<"${D__INT_DPL_NAME_PATHS[$i]}"
      IFS=$'\n' read -r -d '' -a edap <<<"${D__EXT_DPL_NAME_PATHS[$j]}"
      err_msg=( "External deployment named '${D__EXT_DPL_NAMES[$j]}' at:" )
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

  # Restore case sensitivity
  $restore_nocasematch

  # Return based on whether matches encountered
  d__context -- pop 'Cross-validation complete'
  $algd && return 0 || return 1
}

d__dispatch_assembly_job