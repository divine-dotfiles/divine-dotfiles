#!/usr/bin/env bash
#:title:        Divine Bash procedure: assemble
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Fix minor typo, pt. 3
#:created_at:   2019.05.14

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Assembles packages and deployments for further processing.
#

#>  d__assemble_dfs_and_dpls
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
d__assemble_dfs_and_dpls()
{
  # Switch context
  d__context -- notch
  d__context -- push "Assembling tasks for '$D__REQ_ROUTINE' routine"

  # Initialize global variables for assembly data; initialize storage variables
  d__init_assembly_vars; local dirs_to_scan=()

  # Check if a list of bundles is given
  if ((${#D__REQ_BUNDLES[@]})); then

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

  # Load util; parse Divinefiles and *.dpl.sh files in all directories
  local algd=false
  d__scan_for_divinefiles --internal --enqueue "${dirs_to_scan[@]}" \
    && d__scan_for_dpl_files --internal --enqueue "${dirs_to_scan[@]}" \
    && algd=true
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

#>  d___run_dpl_through_filters
#
## INTERNAL USE ONLY
#
## Performs filtering duty: checks given name and flags of a deployment against 
#. scripts arguments to decide whether this deployment should be queued up or 
#. not.
#
## Local variables that must be set in the calling scope:
#.  $d__dpl_n   - Textual name of the deployment
#.  $d__dpl_f   - Textual flags of the deployment
#
## Returns:
#.  0 - Deployment should be queued up
#.  1 - Otherwise
#
d___run_dpl_through_filters()
{
  # Without filtering: just mind the dangerous dpls ('!' flag)
  if ! $D__REQ_FILTER; then
    $D__OPT_EXCLAM && return 0
    [[ $d__dpl_f == *'!'* ]] && return 1 || return 0
  fi; local tmp

  # Inverse filtering: Whatever is listed in arguments is filtered out
  if $D__OPT_INVERSE; then

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

  fi

  # Otherwise, normal filtering: only what is listed in arguments is added

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
}

d__assemble_dfs_and_dpls