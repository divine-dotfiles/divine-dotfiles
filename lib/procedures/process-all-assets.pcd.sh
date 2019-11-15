#!/usr/bin/env bash
#:title:        Divine Bash procedure: process-all-assets
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Implement robust dependency loading system
#:created_at:   2019.10.12

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Processes asset manifests for all deployments currently detected. Where 
#. necessary, copies provided versions of assets to their respective asset 
#. directories.
#

# Marker and dependencies
readonly D__PCD_PROCESS_ALL_ASSETS=loaded
d__load util workflow
d__load util assets

#>  d__pcd_process_all_assets
#
## For every detected deployment, looks up whether it has an asset manifest. If 
#. so, processes the assets on that manifest, copying the provided versions 
#. into the respective asset directory.
#
## Requires:
#.  $D__INT_DPL_NAMES       - (array) Names of deployments in framework dirs.
#.  $D__INT_DPL_NAME_PATHS  - (array) Per name: paths to deployment files.
#
## Returns:
#.  0 - Every manifest found is successfully processed
#.  1 - At least one manifest caused problems
#
d__pcd_process_all_assets()
{
  # Switch context; status and dtorage variables
  d__context -- notch
  d__context -- push 'Processing asset manifests en masse'
  local dpl_n dpla_p dpl_p ii algd=true

  # Iterate over names
  for ((ii=0;ii<${#D__INT_DPL_NAMES[@]};++ii)); do

    # Extract name and paths
    dpl_n="${D__INT_DPL_NAMES[$ii]}"; D_DPL_NAME="$dpl_n"
    IFS=$'\n' read -r -d '' -a dpla_p <<<"${D__INT_DPL_NAME_PATHS[$ii]}"

    # For each path at that dpl name, process manifests
    for dpl_p in "${dpla_p[@]}"; do
      D__DPL_MNF_PATH="${dpl_p%$D__SUFFIX_DPL_SH}$D__SUFFIX_DPL_MNF"
      D__DPL_DIR="$( dirname -- "$dpl_p" )"
      D__DPL_ASSET_DIR="$D__DIR_ASSETS/$dpl_n"
      d__process_asset_manifest_of_current_dpl || algd=false  
    done

  done

  d__context -- lop; $algd && return 0 || return 1
}

d__pcd_process_all_assets