#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: link-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.10.28

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Injects (and removes) deployment related blocks of code/configuration into 
#. textual files.
#

# Marker and dependencies
readonly D__HLP_INJECT=loaded
d__load util workflow
d__load util stash
d__load util backup
d__load procedure prep-md5

#>  d__inject_check
#
## Checks whether entire content of a file at $D_INJECT_SRC is currently 
#. injected into the file at $D_INJECT_TGT.
#
## Uses in the global scope:
#.  $D_INJECT_TGT     - Path to the file to inject into. May not exist. Must be 
#.                      writable.
#.  $D_INJECT_SRC     - Path to the file, entire content of which is to be 
#.                      injected. This file should be a temporary file, i.e., 
#.                      it should be created via:
#.                        D_INJECT_SRC="$(mktemp)"
#.                      Removing this file is left to the user.
#.  $D_INJECT_CMT     - String that initiates a line comment in the type of 
#.                      file being injected into. This is used to comment out 
#.                      the injection delimiters. Defaults to an empty string 
#.                      (uncommented).
#
d__inject_check()
{
  # Read and validate input data; prepare stash; return or switch context
  local erra=() njcmt= njsp njtp nj_key njcs_stsh njcs_src njcs_tgt
  local njtmp lbf njexs=false njrtc njwrn=
  njsp="$D_INJECT_SRC" njtp="$D_INJECT_TGT"
  if [ -e "$njsp" ]; then
    if [ -f "$njsp" -a -r "$njsp" ]; then njcs_src="$( d__md5 "$njsp" )"
    else erra+=( -i- "- injection source is not a readable file: '$njsp'" ); fi
  else njcs_src='d41d8cd98f00b204e9800998ecf8427e'; fi
  if ! d__require_wfile "$njtp"
  then erra+=( -i- "- injection target is not writable: '$njtp'" ); fi
  if ((${#erra[@]}))
  then d__notify -lx -- 'Unable to inject:' "${erra[@]}"; return 3; fi
  [ -n "$D_INJECT_CMT" ] && njcmt="$D_INJECT_CMT"
  d__stash -- ready || return 3
  d__context notch; d__context -- push "Checking text injection into: '$njtp'"
  nj_key="inject_$( d__md5 -s "$njtp" )" njtmp="$(mktemp)"

  # Analyze target file
  if [ -f "$njtp" ]; then while IFS= read -r lbf || [ -n "$lbf" ]; do
    if [[ $lbf = "$njcmt>>>>>>>>>>BEGIN BLOCK: DEPLOYMENT '$D_DPL_NAME'" ]]
    then
      while IFS= read -r lbf || [ -n "$lbf" ]; do case $lbf in
        "$njcmt CREATED AUTOMATICALLY; DO NOT MODIFY THIS BLOCK") continue;;
        "$njcmt<<<<<<<<<<<<END BLOCK: DEPLOYMENT '$D_DPL_NAME'") break;;
        *) printf '%s\n' "$lbf";;
      esac; done; njexs=true
    fi
  done <"$njtp" >$njtmp; fi
  njcs_tgt="$( d__md5 $njtmp )"; rm -f -- $njtmp

  # Analyze retrieved data; report inconsistencies
  if [ $njcs_src = 'd41d8cd98f00b204e9800998ecf8427e' ]; then
    njrtc=0
    if d__stash -s -- has $nj_key; then
      njcs_stsh="$( d__stash -s -- get $nj_key )"
      if $njexs; then
        if ! [ "$njcs_tgt" = "$njcs_stsh" ]; then
          njwrn="Target file's previous injection has been modified manually"
        fi
      else
        njwrn="Target file's previous injection has been removed manually"
      fi
    else
      if $njexs; then
        njwrn='Target file contains a previous injection,'
        njwrn+='but there is no record of previous injections'
      fi
    fi
  else
    if d__stash -s -- has $nj_key; then
      njcs_stsh="$( d__stash -s -- get $nj_key )"
      if $njexs; then
        if [ "$njcs_tgt" = "$njcs_src" ]; then
          if [ "$njcs_tgt" = "$njcs_stsh" ]; then
            njrtc=1
          else
            njrtc=1 njwrn='Target file contains a matching injection,'
            njwrn+='but it has been modified manually'
          fi
        else
          if [ "$njcs_tgt" = "$njcs_stsh" ]; then
            njrtc=0 njwrn='Target file contains a differing previous injection'
          else
            [ "$njcs_src" = "$njcs_stsh" ] && njrtc=6 || njrtc=0
            njwrn="Target file's previous injection has been modified manually"
          fi
        fi
      else
        [ "$njcs_src" = "$njcs_stsh" ] && njrtc=6 || njrtc=0
        njwrn="Target file's previous injection has been removed manually"
      fi
    else
      if $njexs; then
        if [ "$njcs_tgt" = "$njcs_src" ]; then
          njrtc=7 njwrn='Target file contains a matching injection,'
          njwrn+='but there is no record of previous injections'
        else
          njrtc=0 njwrn='Target file contains a non-matching injection,'
          njwrn+='but there is no record of previous injections'
        fi
      else
        njrtc=2
      fi
    fi
  fi
  if [[ "$D__REQ_ROUTINE" = check ]]
  then [ -n "$njwrn" ] && d__notify -l!h -- "$njwrn"
  else
    case $njrtc in 6|7) njwrn=;; esac
    D__INJECT_CHECK_CODES+=("$njrtc")
    D__INJECT_OVERWRITES+=("$njexs")
    D__INJECT_TGT_CHECKSUMS+=("$njcs_tgt")
  fi

  d__context -- lop; return $njrtc
}

#>  d__inject_install
#
## Injects the entire content of a file at $D_INJECT_SRC into the file at 
#. $D_INJECT_TGT.
#
d__inject_install()
{
  # Detect ordinal number of invocation of this function within dpl
  if [ -z ${D__INJECT_NUM+isset} ]
  then D__INJECT_NUM=0; else ((++D__INJECT_NUM)); fi

  # Re-read and re-validate input data; return or switch context
  local erra=() njcmt= njsp njtp nj_key njcs_stsh njcs_src njcs_tgt
  local njtmp lbf ltbf njexs=false njrtc njwrn=
  njsp="$D_INJECT_SRC" njtp="$D_INJECT_TGT"
  njrtc="${D__INJECT_CHECK_CODES[$D__INJECT_NUM]}"
  njexs="${D__INJECT_OVERWRITES[$D__INJECT_NUM]}"
  njcs_tgt="${D__INJECT_TGT_CHECKSUMS[$D__INJECT_NUM]}"
  if [ -e "$njsp" ]; then
    if [ -f "$njsp" -a -r "$njsp" ]; then njcs_src="$( d__md5 "$njsp" )"
    else erra+=( -i- "- injection source is not a readable file: '$njsp'" ); fi
  else erra+=( -i- "- injection source does not exist: '$njsp'" ); fi
  if [ "$njcs_src" = 'd41d8cd98f00b204e9800998ecf8427e' ]
  then erra+=( -i- "- injection source is empty: '$njsp'" ); fi
  case $njrtc in
    0|1|2|6|7) :;; *) erra+=( -i- "- illegal check code passed: '$njrtc'" )
  esac
  case $njexs in
    true|false) :;; *) erra+=( -i- "- illegal status passed: '$njexs'" )
  esac
  if ! [ ${#njcs_tgt} -eq 32 ]
  then erra+=( -i- "- illegal checksum passed: '$njcs_tgt'" ); fi
  if ((${#erra[@]}))
  then d__notify -lx -- 'Unable to inject:' "${erra[@]}"; return 3; fi
  [ -n "$D_INJECT_CMT" ] && njcmt="$D_INJECT_CMT"
  d__context notch; d__context -- push "Injecting text into: '$njtp'"
  nj_key="inject_$( d__md5 -s "$njtp" )"

  # Analyze retrieved data; prompt if found inconsistencies
  if d__stash -s -- has $nj_key; then
    njcs_stsh="$( d__stash -s -- get $nj_key )"
    if $njexs; then
      if [ "$njcs_tgt" = "$njcs_src" ]; then
        if ! [ "$njcs_tgt" = "$njcs_stsh" ]; then
          njwrn='Target file contains a matching injection,'
          njwrn+='but it has been modified manually'
        fi
      else
        if [ "$njcs_tgt" = "$njcs_stsh" ]; then
          njwrn='Overwriting differing previous injection in target file'
        else
          if ! [ "$njcs_src" = "$njcs_stsh" ] || [ $njrtc -ne 6 ]; then
            njwrn="Target file's previous injection has been modified manually"
          fi
        fi
      fi
    else
      if ! [ "$njcs_src" = "$njcs_stsh" ] || [ $njrtc -ne 6 ]; then
        njwrn="Target file's previous injection has been removed manually"
      fi
    fi
  else
    if $njexs; then
      if [ "$njcs_tgt" = "$njcs_src" ]; then
        if [ $njrtc -ne 7 ]; then
          njwrn='Target file contains a matching injection,'
          njwrn+='but there is no record of previous injections'
        fi
      else
        njwrn='Target file contains a non-matching injection,'
        njwrn+='but there is no record of previous injections'
      fi
    fi
  fi
  if [ -n "$njwrn" ]; then
    if ! d__prompt -!hpa 'Install injection?' "$D__OPT_ANSWER" -- "$njwrn"
    then
      d__notify -lx -- 'Refused to inject over inconsistencies'
      d__context -- lop; return 2
    fi
  fi

  # Create proxy; copy existing file, sans pre-existing injection; push backup
  unset ltbf
  if $njexs; then njtmp="$(mktemp)"
    while IFS= read -r lbf || [ -n "$lbf" ]; do
      if [[ $lbf = "$njcmt>>>>>>>>>>BEGIN BLOCK: DEPLOYMENT '$D_DPL_NAME'" ]]
      then
        while IFS= read -r lbf || [ -n "$lbf" ]; do
          if [[ $lbf = \
            "$njcmt<<<<<<<<<<<<END BLOCK: DEPLOYMENT '$D_DPL_NAME'" ]]
          then break; fi
        done
      else
        [ -z ${ltbf+isset} ] || printf '%s\n' "$ltbf"; ltbf="$lbf"
      fi
    done <"$njtp" >$njtmp
    [ -z ${ltbf+isset} ] || printf >>$njtmp '%s' "$ltbf"
    if ! d__cmd d__push_backup -- --TARGET_PATH-- "$njtp" \
      --else-- 'Refusing to inject'
    then rm -f -- $njtmp; return 2; fi
  else njtmp="$njtp"; fi

  # Append new block at the end
  printf >>$njtmp '\n%s\n%s\n' \
    "$njcmt>>>>>>>>>>BEGIN BLOCK: DEPLOYMENT '$D_DPL_NAME'" \
    "$njcmt CREATED AUTOMATICALLY; DO NOT MODIFY THIS BLOCK"
  cat "$njsp" >>$njtmp
  printf >>$njtmp '%s' \
    "$njcmt<<<<<<<<<<<<END BLOCK: DEPLOYMENT '$D_DPL_NAME'"

  # Move proxy into place
  if $njexs && ! d__cmd mv -n -- --TEMP_PATH-- $njtmp --TARGET_PATH-- "$njtp" \
    --else-- 'Failed to inject; backup of old file will remain available'
  then rm -f -- $njtmp; return 2; fi

  # Manipulate stash; return
  d__stash -s -- set "${nj_key}_path" "$njtp"
  d__cmd d__stash -s -- set $nj_key $njcs_src \
    --else-- 'Records will be inconsistent' && d__context lop
  return 0
}

#>  d__inject_remove
#
## Ejects any previous injections from the file at $D_INJECT_TGT.
#
d__inject_remove()
{
  # Detect ordinal number of invocation of this function within dpl
  if [ -z ${D__INJECT_NUM+isset} ]
  then D__INJECT_NUM=$((${#D__INJECT_CHECK_CODES}-1))
  else ((--D__INJECT_NUM)); fi

  # Re-read and re-validate input data; return or switch context
  local erra=() njcmt= njsp njtp nj_key njcs_stsh njcs_src njcs_tgt
  local njtmp lbf njexs=false njrtc njwrn=
  njsp="$D_INJECT_SRC" njtp="$D_INJECT_TGT"
  njrtc="${D__INJECT_CHECK_CODES[$D__INJECT_NUM]}"
  njexs="${D__INJECT_OVERWRITES[$D__INJECT_NUM]}"
  njcs_tgt="${D__INJECT_TGT_CHECKSUMS[$D__INJECT_NUM]}"
  if [ -e "$njsp" ]; then
    if [ -f "$njsp" -a -r "$njsp" ]; then njcs_src="$( d__md5 "$njsp" )"
    else erra+=( -i- "- injection source is not a readable file: '$njsp'" ); fi
  else njcs_src='d41d8cd98f00b204e9800998ecf8427e'; fi
  case $njrtc in
    0|1|2|6|7) :;; *) erra+=( -i- "- illegal check code passed: '$njrtc'" )
  esac
  case $njexs in
    true|false) :;; *) erra+=( -i- "- illegal status passed: '$njexs'" )
  esac
  if ! [ ${#njcs_tgt} -eq 32 ]
  then erra+=( -i- "- illegal checksum passed: '$njcs_tgt'" ); fi
  if ((${#erra[@]}))
  then d__notify -lx -- 'Unable to inject:' "${erra[@]}"; return 3; fi
  [ -n "$D_INJECT_CMT" ] && njcmt="$D_INJECT_CMT"
  d__context notch; d__context -- push "Removing text injection from: '$njtp'"
  nj_key="inject_$( d__md5 -s "$njtp" )"

  # Analyze retrieved data; report inconsistencies
  if [ $njcs_src = 'd41d8cd98f00b204e9800998ecf8427e' ]; then
    if d__stash -s -- has $nj_key; then
      njcs_stsh="$( d__stash -s -- get $nj_key )"
      if $njexs; then
        if ! [ "$njcs_tgt" = "$njcs_stsh" ]; then
          njwrn="Target file's previous injection has been modified manually"
        fi
      else
        njwrn="Target file's previous injection has been removed manually"
      fi
    else
      if $njexs; then
        njwrn='Target file contains a previous injection,'
        njwrn+='but there is no record of previous injections'
      fi
    fi
  else
    if d__stash -s -- has $nj_key; then
      njcs_stsh="$( d__stash -s -- get $nj_key )"
      if $njexs; then
        if [ "$njcs_tgt" = "$njcs_src" ]; then
          if ! [ "$njcs_tgt" = "$njcs_stsh" ]; then
            njwrn='Target file contains a matching injection,'
            njwrn+='but it has been modified manually'
          fi
        else
          if [ "$njcs_tgt" = "$njcs_stsh" ]; then
            njwrn='Overwriting differing previous injection in target file'
          else
            if ! [ "$njcs_src" = "$njcs_stsh" ] || [ $njrtc -ne 6 ]; then
              njwrn="Target file's previous injection"
              njwrn+='has been modified manually'
            fi
          fi
        fi
      else
        if ! [ "$njcs_src" = "$njcs_stsh" ] || [ $njrtc -ne 6 ]; then
          njwrn="Target file's previous injection has been removed manually"
        fi
      fi
    else
      if $njexs; then
        if [ "$njcs_tgt" = "$njcs_src" ]; then
          if [ $njrtc -ne 7 ]; then
            njwrn='Target file contains a matching injection,'
            njwrn+='but there is no record of previous injections'
          fi
        else
          njwrn='Target file contains a non-matching injection,'
          njwrn+='but there is no record of previous injections'
        fi
      fi
    fi
  fi
  if [ -n "$njwrn" ]; then
    if ! d__prompt -!hpa 'Remove injection?' "$D__OPT_ANSWER" -- "$njwrn"
    then
      d__notify -lx -- 'Refused to remove injection over inconsistencies'
      d__context -- lop; return 2
    fi
  fi

  # Create proxy; copy existing file, sans pre-existing injection; move
  unset ltbf
  if $njexs; then njtmp="$(mktemp)"
    while IFS= read -r lbf || [ -n "$lbf" ]; do
      if [[ $lbf = "$njcmt>>>>>>>>>>BEGIN BLOCK: DEPLOYMENT '$D_DPL_NAME'" ]]
      then
        while IFS= read -r lbf || [ -n "$lbf" ]; do
          if [[ $lbf = \
            "$njcmt<<<<<<<<<<<<END BLOCK: DEPLOYMENT '$D_DPL_NAME'" ]]
          then break; fi
        done
      else
        [ -z ${ltbf+isset} ] || printf '%s\n' "$ltbf"; ltbf="$lbf"
      fi
    done <"$njtp" >$njtmp
    [ -z ${ltbf+isset} ] || printf >>$njtmp '%s' "$ltbf"
    if ! d__cmd mv -f -- --TEMP_PATH-- $njtmp --TARGET_PATH-- "$njtp" \
      --else-- 'Failed to remove injection'
    then rm -f -- $njtmp; return 2; fi
  fi

  # Manipulate stash; return
  d__stash -s -- unset "${nj_key}_path"
  d__cmd d__stash -s -- unset $nj_key \
    --else-- 'Records will be inconsistent' && d__context lop
  return 0
}