#!/usr/bin/env bash
#:title:        Divine Bash utils: backup
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    For mv, require writing permission on both ends
#:created_at:   2019.09.18

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Utilities that assist in backing up and restoring files. These functions are 
#. intended to be re-used in deployments and framework components alike, and 
#. are integrated with the Divine workflow system. Before properly returning, 
#. all backup utils restore the context stack to the pre-call state.
#
## Optionless versions of the functions in this file strive for zero data loss: 
#. nothing is erased, everything is backed up.
#
## Summary of functions in this file:
#>  d__push_backup [-k] [--] ORIG_PATH [BACKUP_PATH]
#>  d__pop_backup [-de]... [--] ORIG_PATH [BACKUP_PATH]
#

# Marker and dependencies
readonly D__UTL_BACKUP=loaded
d__load util workflow
d__load procedure prep-md5

#>  d__push_backup [-k] [--] ORIG_PATH [BACKUP_PATH]
#
## This function ensures that the ORIG_PATH becomes empty, and if anything 
#. exists there currently, it is backed up. Thus, if the ORIG_PATH does not 
#. exist, a zero code is immediately returned.
#
## For the backup path, the first available strategy is employed:
#.  * If a BACKUP_PATH is given, it is used. If it turns out unusable, further 
#.    strategies are not tried; an error code is returned instead.
#.  * If called from a deployment, the backup location is $D__DPL_BACKUP_DIR, 
#.    and the backup file name is the md5 checksum of the ORIG_PATH. The whole 
#.    thing then has the suffix '.bak' appended to it.
#.  * If none of the above works, an error code is returned.
#
## If the generated backup path happens to be occupied, it is understood to be 
#. a previously made backup. Previous backups are never overwritten. Instead, 
#. this function repeatedly appends an incrementing numerical suffix ('-1', 
#. '-2', etc.) to the backup file name until it finds a path that is not yet 
#. occupied, and that path is then used. The suffixes are hard capped at 1000.
#
## This function always ensures the existence of the directory that is the 
#. immediate parent the ORIG_PATH and of the generated backup path.
#
## This function is intended to be used in conjunction with d__pop_backup.
#
## Options:
#.  -k, --keep-original   - Do not vacate ORIG_PATH. If something is in there, 
#.                          create backup by copying, but leave the original in 
#.                          place.
#
## Returns:
#.  0 - The ORIG_PATH has been made empty; and if anything existed there, it 
#.      has been backed up.
#.  1 - The ORIG_PATH exists, but is inaccessible.
#.  2 - The backup path, whatever it is, is inaccessible or invalid.
#.  3 - Other unexpected error.
#
d__push_backup()
{
  # Pluck out options, round up arguments
  local args=() arg opt i keep=false
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)                args+=("$@"); break;;
          k|-keep-original) keep=true;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                k)  keep=true;;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments"; return 3; fi

  d__context -- notch

  local orig_path="${args[0]}" orig_dirpath cmd
  orig_dirpath="$( dirname -- "$orig_path" )"
  d__require [ -n --ORIG_PATH-- "$orig_path" ] \
    --crcm-- 'Backing up initiated with an empty path' \
    --else-- 'Cannot pop backup' \
    || return 1
  if [ -e "$orig_path" ]; then
    if [ -d "$orig_path" ]; then
      d__context -- push "Backing up a directory at: $orig_path"
    else
      d__context -- push "Backing up a file at: $orig_path"
    fi
  else
    d__notify -qq -- "Nothing to back up at: $orig_path"
    if ! [ -d "$orig_dirpath" ]; then
      d__context -- push \
        "Ensuring existence of the parent directory of: $orig_path"
      cmd=mkdir; d__require_wdir "$orig_dirpath" || cmd='sudo mkdir'
      d__cmd --se-- $cmd -p -- --ORIG_DIRPATH-- "$orig_dirpath" \
        --else-- 'Desired location is inaccessible' || return 1
    fi
    d__context -- lop
    return 0
  fi
  
  local backup_path backup_dirpath note_path i
  if [ -z ${args[1]+isset} ]; then
    d__notify -qq -- 'No backup path provided explicitly'
    d__context -- push "Backing up into the deployment's backups directory"
    d__require [ -n --DPL_BACKUP_DIR-- "$D__DPL_BACKUP_DIR" ] \
      --crcm-- 'Backing up initiated outside of a deployment' \
      --else-- 'Cannot back up without an explicit backup path' \
      || return 3
    backup_dirpath="$D__DPL_BACKUP_DIR"
    backup_path="$backup_dirpath/$( d__md5 -s "$orig_path" || exit $? ).bak"
    if (($?)); then
      d__fail -- 'Failed to generate the md5 checksum of the path'
      return 3
    fi
    note_path="$backup_path.path"
  else
    d__notify -qq -- 'A backup path is provided'
    backup_path="${args[1]}"
    d__require [ -n --BACKUP_PATH-- "$backup_path" ] \
      --crcm-- 'Backing up initiated with an empty backup path' \
      --else-- 'Cannot back up' \
      || return 2
    backup_dirpath="$( dirname -- "$backup_path" )"
    d__require --neg-- [ --BACKUP_PATH-- "$backup_path" \
      -ef --BACKUP_DIRPATH-- "$backup_dirpath" ] \
      --crcm-- 'Backing up initiated with an illegal backup path' \
      --else-- 'Cannot back up' \
      || return 2
  fi

  d__context -- push "Backing up into: $backup_path"
  if ! [ -d "$backup_dirpath" ]; then
    d__context -- push 'Ensuring existence of the directory containing backups'
    cmd=mkdir; d__require_wdir "$backup_path" || cmd='sudo mkdir'
    d__cmd --se-- $cmd -p -- --BACKUP_DIRPATH-- "$backup_dirpath" \
      --else-- "Unable to back up into an inaccessible directory" \
      || return 2
    d__context -- pop
  fi

  if [ -e "$backup_path" ]; then
    d__notify -qqq -- "Backup location is occupied"
    d__context -- push 'Scanning for an unoccupied backup location'
    for ((i=1;i<=1000;++i)); do [ -e "$backup_path-$i" ] || break; done
    backup_path+="-$i"
    d__require --neg-- [ -e "$backup_path" ] \
      --else-- 'Failed to find an unoccupied backup location' \
      || return 3
    d__context -- pop
    d__context -- push "Using the backup path: $backup_path"
  else
    d__context -- push 'Using the backup path unchanged'
  fi

  if $keep; then
    d__context -- push 'Copying the original to the backup location'
    cmd=cp; d__require_wdir "$backup_dirpath" || cmd='sudo cp'
    d__cmd --se-- $cmd -Rn -- --ORIG_PATH-- "$orig_path" \
      --BACKUP_PATH-- "$backup_path" --else-- 'Failed to push backup' \
      || return 3
  else
    d__context -- push 'Moving the original to the backup location'
    cmd=mv
    d__require_wdir "$orig_path" || cmd='sudo mv'
    d__require_wdir "$backup_dirpath" || cmd='sudo mv'
    d__cmd --se-- $cmd -n -- --ORIG_PATH-- "$orig_path" \
      --BACKUP_PATH-- "$backup_path" --else-- 'Failed to push backup' \
      || return 3
  fi
  [ -n "$note_path" ] && printf '%s\n' "$orig_path" >"$note_path"
  if ! [ -z ${d__bckp+isset} ]; then d__bckp="$backup_path"; fi
  d__context -- lop
  return 0
}

#>  d__pop_backup [-dep]... [--] ORIG_PATH [BACKUP_PATH]
#
## This function ensures that the latest backup is moved back to the ORIG_PATH, 
#. and if anything exists there currently, it is, itself, backed up. Thus, if 
#. there are no backups at all, nothing is done and a zero code is returned.
#
## For the backup path, the first available strategy is employed:
#.  * If a BACKUP_PATH is given, it is used. If it turns out unusable, further 
#.    strategies are not tried; an error code is returned instead.
#.  * If called from a deployment, the backup location is $D__DPL_BACKUP_DIR, 
#.    and the backup file name is the md5 checksum of the ORIG_PATH. The whole 
#.    thing then has the suffix '.bak' appended to it.
#.  * If none of the above works, an error code is returned.
#
## To find the latest backup, this function first checks the generated backup 
#. path, then repeatedly appends an incrementing numerical suffix ('-1', '-2', 
#. etc.) to the backup file name. As soon as it hits a path that does not 
#. exist, the previous path is understood to be the latest backup. The suffixes 
#. are hard capped at 1000.
#
## To back up whatever pre-exists at the ORIG_PATH, the suffix '.bak' is 
#. appended to the ORIG_PATH. If that path happens to be occupied, the same 
#. routine of incrementing numbers is applied.
#
## This function is intended to be used in conjunction with d__push_backup.
#
## Options:
#.  -e, --evict     - Make it an additional priority to ensure that anything 
#.                    that pre-exists at the ORIG_PATH is no longer there by 
#.                    the time this function successfully returns. This means 
#.                    that even if there is no backup to pop, the ORIG_PATH 
#.                    still gets freed up.
#.  -d, --dispose   - Treat whatever pre-exists at the ORIG_PATH as disposable. 
#.                    In this mode, no backups of the ORIG_PATH are made.
#.  -p, --precise   - Do not go through the motions of looking up the latest 
#.                    backup version: use the backup location precisely or not 
#.                    at all.
#
## Returns:
#.  0 - The backup has been popped successfully, according to the options.
#.  1 - The ORIG_PATH is inaccessible.
#.  2 - The backup path, whatever it is, is inaccessible or invalid.
#.  3 - Other unexpected error.
#
d__pop_backup()
{
  # Pluck out options, round up arguments
  local args=() arg opt i evict=false dispose=false precise=false
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          e|-evict)   evict=true;;
          d|-dispose) dispose=true;;
          p|-precise) precise=true;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"; case $opt in
                e)  evict=true;;
                d)  dispose=true;;
                p)  precise=true;;
                *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                      "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments"; return 1; fi
  
  d__context -- notch

  local orig_path="${args[0]}" orig_dirpath cmd
  orig_dirpath="$( dirname -- "$orig_path" )"
  d__require [ -n --ORIG_PATH-- "$orig_path" ] \
    --crcm-- 'Popping of backup initiated with an empty path' \
    --else-- 'Cannot pop backup' \
    || return 1
  if ! [ -e "$orig_path" ]; then
    $evict && d__notify -qq -- "Nothing to evict at: $orig_path"; evict=false
  fi

  local backup_path i pbackup_path note_path
  if [ -z ${args[1]+isset} ]; then
    d__notify -qq -- 'No backup path provided explicitly'
    d__context -- push "Popping backup from the deployment's backups directory"
    d__require [ -n --DPL_BACKUP_DIR-- "$D__DPL_BACKUP_DIR" ] \
      --crcm-- 'Popping of backup initiated outside of a deployment' \
      --else-- 'Cannot pop backup without an explicit backup path' \
      || return 3
    backup_path="$D__DPL_BACKUP_DIR/$( d__md5 -s "$orig_path" || exit $? ).bak"
    if (($?)); then
      d__fail -- 'Failed to generate the md5 checksum of the path'
      return 3
    fi
    pbackup_path="$backup_path" note_path="$backup_path.path"
  else
    d__notify -qq -- 'A backup path is provided'
    backup_path="${args[1]}"
    d__require [ -n --BACKUP_PATH-- "$backup_path" ] \
      --crcm-- 'Popping of backup initiated with an empty backup path' \
      --else-- 'Cannot pop backup' \
      || return 2
  fi

  local restore=false
  if [ -e "$backup_path" ]; then
    d__notify -qqq -- "Backup exists"
    if [ -e "$backup_path-1" ]; then
      if $precise; then
        d__notify -l! -- 'Versions of backup exist, but using backup path' \
          'precisely' -n- 'This will break backup versioning'
      else
        d__context -- push 'Scanning for the latest backup'
        for ((i=2;i<=1000;++i)); do [ -e "$backup_path-$i" ] || break; done
        ((--i)); backup_path+="-$i"
        d__context -- pop
      fi
    fi
    d__context -- push "Restoring backup from: $backup_path"
    if ! [ -d "$orig_dirpath" ]; then
      d__context -- push \
        "Ensuring existence of the parent directory of: $orig_path"
      cmd=mkdir; d__require_wdir "$orig_dirpath" || cmd='sudo mkdir'
      d__cmd --se-- $cmd -p -- --ORIG_DIRPATH-- "$orig_dirpath" \
        --else-- 'Desired location is inaccessible' || return 1
      d__context -- pop
    fi
    evict=true; restore=true
  else
    d__notify -qq -- "No backup to restore"
    if ! $evict; then d__context -- lop; return 0; fi
  fi

  if $evict; then
    local orig_type
    [ -d "$orig_path" ] && orig_type=directory || orig_type=file
    if $dispose; then
      d__context -- push "Clobbering a $orig_type at: $orig_path"
      cmd=rm; d__require_wdir "$orig_dirpath" || cmd='sudo rm'
      d__cmd --se-- $cmd -rf -- --ORIG_PATH-- "$orig_path" \
        --else-- 'Failed to clobber the path' || return 3
      d__context -- pop
    else
      d__context -- push "Evicting a $orig_type at: $orig_path"
      local orig_path_bak="$orig_path.bak"
      if [ -e "$orig_path_bak" ]; then
        d__notify -qqq -- "Eviction location is occupied"
        d__context -- push 'Scanning for an unoccupied eviction location'
        for ((i=1;i<=1000;++i)); do [ -e "$orig_path_bak-$i" ] || break; done
        orig_path_bak+="-$i"
        d__require --neg-- [ -e "$orig_path_bak" ] \
          --else-- 'Failed to find an unoccupied eviction location' \
          || return 3
        d__context -- pop
      fi
      d__context -- push "Evicting to: $orig_path_bak"
      cmd=mv; d__require_wdir "$orig_dirpath" || cmd='sudo mv'
      d__cmd --se-- $cmd -n -- --ORIG_PATH-- "$orig_path" \
        --EVICT_PATH-- "$orig_path_bak" \
        --else-- "Failed to evict the $orig_type" || return 3
      d__context -- pop
      d__context -- pop
    fi
  fi

  if ! $restore; then d__context lop; return 0; fi

  d__context -- push 'Moving the backup to its original location'
  cmd=mv
  d__require_wdir "$backup_path" || cmd='sudo mv'
  d__require_wdir "$orig_dirpath" || cmd='sudo mv'
  d__cmd --se-- $cmd -n -- --BACKUP_PATH-- "$backup_path" \
    --ORIG_PATH-- "$orig_path" --else-- 'Failed to pop backup' \
    || return 3
  if ! [ -z ${d__bckp+isset} ]; then d__bckp="$backup_path"; fi
  [ -f "$note_path" -a ! -e "$pbackup_path" ] && rm -f -- "$note_path"
  d__context -- lop
  return 0
}