#!/usr/bin/env bash
#:title:        Divine Bash utils: assets
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.10.12

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Utility that processes manifested assets for a particular deployment.
#
## Summary of functions in this file:
#>  d__process_asset_manifest_of_current_dpl
#

# Marker and dependencies
readonly D__UTL_ASSETS=loaded
d__load util workflow
d__load util manifests
d__load util backup
d__load helper queue

#>  d__process_asset_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D__DPL_MNF_PATH; parses it. All 
#. lines are interpreted as relative paths to deployment's assets.
#
## Copies initial versions of deployment's assets to deployments assets 
#. directory. Does not overwrite anything (user's data takes priority), unless 
#. the asset carries a force flag.
#
## Requires:
#.  $D_DPL_NAME         - Name of the deployment.
#.  $D__DPL_MNF_PATH    - Path to assets manifest file.
#.  $D__DPL_DIR         - Path to resolve initial asset paths against.
#.  $D__DPL_ASSET_DIR   - Path to compose target asset paths against.
#
## Provides into the global scope:
#.  $D_QUEUE_MAIN       - Array of relative paths to assets.
#.  $D_QUEUE_ASSETS  - Array of absolute paths to assets.
#
## Returns:
#.  0 - All assets processed successfully.
#.  1 - Otherwise.
#
d__process_asset_manifest_of_current_dpl()
{
  # Cut-off check for deployment directory (other directories are created)
  if ! [ -r "$D__DPL_DIR" -a -d "$D__DPL_DIR" ]; then
    d__notify -l! -- 'Asset processing initiated' \
      'with deployment directory unreadable:' -i- "$D__DPL_DIR"
    return 1
  fi

  # Attempt to parse manifest file, or return early
  if ! d__process_manifest "$D__DPL_MNF_PATH"; then
    d__notify -qqq -- "Deployment '$D_DPL_NAME' has no asset manifest"
    return 0
  elif [ ${#D__MANIFEST_LINES[@]} -eq 0 ]; then
    d__notify -qqq -- "Asset manifest of deployment '$D_DPL_NAME'" \
      'has no relevant entries'
    return 0
  fi

  # Switch context; init storage variables
  d__context -- notch
  d__context -- push "Processing assets of deployment '$D_DPL_NAME'"
  D_QUEUE_MAIN=() D_QUEUE_ASSETS=() D__QUEUE_FLAGS=()
  local ii jj p_ptn p_pfx p_rel p_ori p_src p_dst p_flgs prvd erra=()
  local flgr flgd flgo flgn flgp flgf
  # Flags are: regex; dpl-dir-only; optional; no-queue; provided-only; force

  # Ensure existence of asset directory
  d__cmd --se-- mkdir -p -- "$D__DPL_ASSET_DIR" \
    --else-- 'Unable to process assets' || return 1

  # Iterate over lines extracted from manifest
  for ((ii=0;ii<${#D__MANIFEST_LINES[@]};++ii)); do

    # Insert queue split if necessary; extract path/pattern
    if [ "${D__MANIFEST_SPLITS[$ii]}" = true ]; then d__queue_split; fi
    p_ptn="${D__MANIFEST_LINES[$ii]}"

    # Clear leading and trailing slashes from path/pattern
    while [[ $p_ptn = /* ]]; do p_ptn="${p_ptn##/}"; done
    while [[ $p_ptn = */ ]]; do p_ptn="${p_ptn%%/}"; done

    # Extract prefix, if it exists
    if [ -z ${D__MANIFEST_LINE_PRFXS[$ii]+isset} ]; then p_pfx=
    else p_pfx="/${D__MANIFEST_LINE_PRFXS[$ii]}"; fi

    # Set default flags
    flgr=false flgd=false flgo=false flgn=false flgp=false flgf=false

    # Extract flags
    p_flgs="${D__MANIFEST_LINE_FLAGS[$ii]}"
    for ((jj=0;jj<${#p_flgs};++jj)); do case ${p_flgs:$jj:1} in
      r) flgr=true;; d) flgd=true;; o) flgo=true;;
      n) flgn=true;; p) flgp=true;; f) flgf=true;;
    esac; done

    # Fork into four modes based on presence of 'd' and 'r' flags
    if $flgd; then $flgr && d___process_asset_dr || d___process_asset_d
    else $flagr && d___process_asset_r || d___process_asset; fi

  # Done iterating over lines extracted from manifest
  done

  # If there is a terminal queue split, insert it
  if [ "$D__MANIFEST_ENDSPLIT" = true ]; then d__queue_split; fi

  # If errors, print them and return
  if ((${#erra[@]})); then
    d__fail -- 'Errors encountered while processing assets:' "${erra[@]}"
    return 1
  fi

  d__context -- lop; return 0
}

d___process_asset()
{
  # Normal concrete asset: compose absolute paths
  p_src="${D__DPL_DIR}${p_pfx}/$p_ptn" p_dst="$D__DPL_ASSET_DIR/$p_ptn"

  # Check if the asset exists in the deployment directory
  if [ -e "$p_src" ]; then
    # Copy asset
    d___copy_asset
    # If pushing onto asset arrays and limited to provided, push now
    if [ $? -eq 0 ] && ! $flgn && $flgp; then
      D_QUEUE_MAIN+=("$p_ptn")
      D_QUEUE_ASSETS+=("$p_dst")
      D__QUEUE_FLAGS+=("$p_flgs")
    fi
  else
    # Asset not provided: if its not optional, mark failure
    if ! $flgo
    then erra+=( -i- "- required concrete asset not provided: '$p_ptn'" ); fi
  fi

  # If pushing onto asset arrays but NOT limited to provided, push now
  if ! $flgn && ! $flgp && [ -r "$p_dst" ]; then
    D_QUEUE_MAIN+=("$p_ptn")
    D_QUEUE_ASSETS+=("$p_dst")
    D__QUEUE_FLAGS+=("$p_flgs")
  fi
}

d___process_asset_r()
{
  # Normal RegEx asset: set default provision marker
  prvd=false

  # Check if directory within dpl directory can be changed into
  if pushd -- "${D__DPL_DIR}${p_pfx}" &>/dev/null; then
    # Iterate over find results on the pattern
    while IFS= read -r -d $'\0' p_rel; do
      # Set provision marker; compose relative and absolute paths
      prvd=true p_rel="${p_rel#./}"
      p_src="${D__DPL_DIR}${p_pfx}/$p_rel" p_dst="$D__DPL_ASSET_DIR/$p_rel"
      # Copy asset
      d___copy_asset
      # If pushing onto asset arrays and limited to provided, push now
      if [ $? -eq 0 ] && ! $flgn && $flgp; then
        D_QUEUE_MAIN+=("$p_rel")
        D_QUEUE_ASSETS+=("$p_dst")
        D__QUEUE_FLAGS+=("$p_flgs")
      fi
    done < <( d__efind -regex "^\./$p_ptn$" -print0 )
    popd &>/dev/null
  fi

  # Post-check for non-optional assets
  if ! $flgo && ! $prvd
  then erra+=( -i- "- required RegEx asset not provided: '$p_ptn'" ); fi

  # If pushing onto asset arrays but NOT limited to provided, push now
  if ! $flgn && ! $flgp; then
    # Check if dpl asset directory can be changed into
    if pushd -- "$D__DPL_ASSET_DIR" &>/dev/null; then
      ## Iterate over find results on the pattern again, this time in asset 
      #. directory and without the prefix
      while IFS= read -r -d $'\0' p_rel; do
        # Compose relative and absolute paths
        p_rel="${p_rel#./}"; p_dst="$D__DPL_ASSET_DIR/$p_rel"
        # Push the asset onto global containers
        D_QUEUE_MAIN+=("$p_rel")
        D_QUEUE_ASSETS+=("$p_dst")
        D__QUEUE_FLAGS+=("$p_flgs")
      done < <( d__efind -regex "^\./$p_ptn$" -print0 )
      popd &>/dev/null
    fi
  fi
}

d___process_asset_d()
{
  # Dpl-dir-only concrete asset: compose absolute path
  p_ori="${D__DPL_DIR}${p_pfx}/$p_ptn"
  # If the asset is readable; if not check if it is optional
  if [ -r "$p_ori" ]; then
    # If pushing onto asset arrays, push now
    if ! $flgn; then
      D_QUEUE_MAIN+=("$p_ptn")
      D_QUEUE_ASSETS+=("$p_ori")
      D__QUEUE_FLAGS+=("$p_flgs")
    fi
  elif ! $flgo; then
    erra+=( -i- \
      "- required concrete asset not provided in dpl dir: '$p_ptn'" )
  fi
}

d___process_asset_dr()
{
  # Dpl-dir-only RegEx asset: set default asset provision marker
  prvd=false

  # Check if directory within dpl directory can be changed into
  if pushd -- "${D__DPL_DIR}${p_pfx}" &>/dev/null; then
    # Iterate over find results on the pattern
    while IFS= read -r -d $'\0' p_rel; do
      # Set provision marker; compose relative and absolute paths
      prvd=true p_rel="${p_rel#./}"
      p_ori="${D__DPL_DIR}${p_pfx}/$p_rel"
      # If pushing onto asset arrays, push now
      if ! $flgn; then
        D_QUEUE_MAIN+=("$p_rel")
        D_QUEUE_ASSETS+=("$p_ori")
        D__QUEUE_FLAGS+=("$p_flgs")
      fi
    done < <( d__efind -regex "^\./$p_ptn$" -print0 )
    popd &>/dev/null
  fi

  # Post-check for non-optional assets
  if ! $flgo && ! $prvd; then
    erra+=( -i- \
      "- required RegEx asset not provided in dpl dir: '$p_ptn'" )
  fi
}

#>  d___copy_asset
#
## INTERNAL USE ONLY
#
## If force flag is 'true', the asset is copied unless destination is already a 
#. byte-by-byte copy of the original. Otherwise the asset is copied only if 
#. destination does not exist at all.
#
## Returns:
#.  0 - Asset is in place as required
#.  1 - Otherwise
#
d___copy_asset()
{
  # Check if destination path exists
  if [ -e "$p_dst" ]; then

    # Cut-off checks for non-forced assets and byte-by-byte copies
    if ! $flgf || [ "$( d__md5 "$p_src" )" = "$( d__md5 "$p_dst" )" ]
    then return 0; fi

    # Overwriting: READMEs are clobbered, other files backed up in place
    if [ -f "$p_dst" ] \
      && [[ "$( basename -- "$p_dst" )" =~ ^README(\.[a-z]+)?$ ]]
    then
      if ! rm -f -- "$p_dst"; then
        erra+=( -i- "- failed to clobber old version: '$p_ptn'" )
        return 1
      fi
    else
      if ! d__push_backup -- "$p_dst" "$p_dst.bak"; then
        erra+=( -i- "- failed to back up old version: '$p_ptn'" )
        return 1
      fi
    fi

  fi

  # At this point destination path is not occupied

  # Ensure target directory is available
  if ! mkdir -p -- "$( dirname -- "$p_dst" )" &>/dev/null
  then erra+=( -i- "- failed to create directory for: '$p_ptn'" ); return 1; fi

  # Copy initial version to assets directory
  if ! cp -Rn -- "$p_src" "$p_dst" &>/dev/null
  then erra+=( -i- "- failed to copy: '$p_ptn'" ); return 1; fi

  # Return success
  return 0
}