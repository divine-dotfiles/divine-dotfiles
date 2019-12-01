#!/usr/bin/env bash
#:title:        Divine Bash utils: items
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.10.12

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Utility that processes manifested queue items for a particular deployment.
#
## Summary of functions in this file:
#>  d__process_queue_manifest_of_current_dpl
#

# Marker and dependencies
readonly D__UTL_ITEMS=loaded
d__load util workflow
d__load util manifests
d__load helper queue

#>  d__process_queue_manifest_of_current_dpl
#
## Looks for manifest file at path stored in $D__DPL_QUE_PATH; parses it. All 
#. lines are interpreted as queue items.
#
## Requires:
#.  $D_DPL_NAME         - Name of the deployment.
#.  $D__DPL_QUE_PATH     - Path to queue manifest file.
#
## Provides into the global scope:
#.  $D_QUEUE_MAIN       - Array of relative paths to assets.
#
## Returns:
#.  0 - All items processed successfully.
#.  1 - Otherwise.
#
d__process_queue_manifest_of_current_dpl()
{
  # Accept override on manifest file path
  local mnfp="$D__DPL_QUE_PATH"
  [ -n "$D_ADDST_QUEUE_MNF_PATH" ] && mnfp="$D_ADDST_QUEUE_MNF_PATH"

  # Attempt to parse manifest file, or return early
  if ! d__process_manifest "$mnfp"; then
    d__notify -qqq -- "Deployment '$D_DPL_NAME' has no queue manifest"
    return 0
  elif [ ${#D__MANIFEST_LINES[@]} -eq 0 ]; then
    d__notify -qqq -- "Queue manifest of deployment '$D_DPL_NAME'" \
      'has no relevant entries'
    return 0
  fi

  # Switch context; init storage variables; warn of overwriting
  d__context -- notch
  d__context -- push "Processing queue items of deployment '$D_DPL_NAME'"
  if [ ${#D_QUEUE_MAIN[@]} -gt 1 -o -n "$D_QUEUE_MAIN" ]
  then d__notify -! -- 'Queue manifest overwrites non-empty previous queue'; fi
  D_QUEUE_MAIN=() D__QUEUE_FLAGS=(); local ii

  # Iterate over lines extracted from manifest; append splits and items
  for ((ii=0;ii<${#D__MANIFEST_LINES[@]};++ii)); do
    if [ "${D__MANIFEST_SPLITS[$ii]}" = true ]; then d__queue_split; fi
    D_QUEUE_MAIN+=("${D__MANIFEST_LINES[$ii]}")
    D__QUEUE_FLAGS+=("${D__MANIFEST_LINE_FLAGS[$ii]}")
  done

  # If there is a terminal queue split, insert it
  if [ "$D__MANIFEST_ENDSPLIT" = true ]; then d__queue_split; fi

  d__context -- lop; return 0
}