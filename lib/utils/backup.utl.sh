#!/usr/bin/env bash
#:title:        Divine Bash utils: backup
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    4
#:revdate:      2019.09.20
#:revremark:    Tweak comments a bit
#:created_at:   2019.09.18

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Utilities that help assist in backing up and restoring files. These 
#. functions are intended to be re-used in deployments and framework components 
#. alike, and are integrated with the Divine workflow system. Before properly 
#. returning, all backup utils restore the context stack to the pre-call state.
#
## Optionless versions of the functions in this file strive for zero data loss: 
#. nothing is erased, everything is backed up.
#
## This file depends on:
#.  * workflow.utl.sh
#.  * dep-checks.pcd.sh: for the dmd5 function
#

#>  d__push_backup [--] ORIG_PATH [BACKUP_PATH]
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
  local args=() arg opt
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"
                case $opt in
                  *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                        "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
                esac
              done;;
        esac;;
    *)  args+=("$arg");;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments"; return 3; fi

  d__context -- notch

  local orig_path="${args[0]}" orig_dirpath
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
    orig_dirpath="$( dirname -- "$orig_path" )"
    if ! [ -d "$orig_dirpath" ]; then
      d__context -- push \
        "Ensuring existence of the parent directory of: $orig_path"
      d__cmd mkdir -p -- "$orig_dirpath" \
        --else-- 'Desired location is inaccessible' \
        || return 1
    fi
    d__context -- lop
    return 0
  fi
  
  local backup_path backup_dirpath i
  if [ -z ${args[1]+isset} ]; then
    d__notify -qq -- 'No backup path provided explicitly'
    d__context -- push "Backing up into the deployment's backups directory"
    d__require [ -n --DPL_BACKUP_DIR-- "$D__DPL_BACKUP_DIR" ] \
      --crcm-- 'Backing up initiated outside of a deployment' \
      --else-- 'Cannot back up without an explicit backup path' \
      || return 3
    backup_dirpath="$D__DPL_BACKUP_DIR"
    backup_path="$backup_dirpath/$( dmd5 -s "$orig_path" || exit $? ).bak"
    if (($?)); then
      d__fail -- 'Failed to generate the md5 checksum of the path'
      return 3
    fi
  else
    d__notify -qq -- 'A backup path is provided'
    backup_path="${args[1]}"
    d__require [ -n --BACKUP_PATH-- "$backup_path" ] \
      --crcm-- 'Backing up initiated with an empty backup path' \
      --else-- 'Cannot back up' \
      || return 2
    backup_dirpath="$( dirname -- "$backup_path" )"
    d__require [ --BACKUP_PATH-- "$backup_path" \
      != --BACKUP_DIRPATH-- "$backup_dirpath" ] \
      --crcm-- 'Backing up initiated with an illegal backup path' \
      --else-- 'Cannot back up' \
      || return 2
  fi

  d__context -- push "Backing up into: $backup_path"
  if ! [ -d "$backup_dirpath" ]; then
    d__context -- push 'Ensuring existence of the directory containing backups'
    d__cmd mkdir -p -- --BACKUP_DIR-- "$backup_dirpath" \
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

  d__context -- push 'Moving the original to the backup location'
  d__cmd mv -n -- --ORIG_PATH-- "$orig_path" --BACKUP_PATH-- "$backup_path" \
    --else-- 'Failed to push backup' \
    || return 3
  d__context -- lop
  return 0
}

#>  d__pop_backup [-de]... [--] ORIG_PATH [BACKUP_PATH]
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
## This function always ensures the existence of the directory that is the 
#. immediate parent the ORIG_PATH.
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
  local args=() arg opt evict=false dispose=false
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)          args+=("$@"); break;;
          e|-evict)   evict=true;;
          d|-dispose) dispose=true;;
          *)  for ((i=1;i<${#arg};++i)); do opt="${arg:i:1}"
                case $opt in
                  e)  evict=true;;
                  d)  dispose=true;;
                  *)  printf >&2 '%s %s\n' "$YELLOW$BOLD==>$NORMAL" \
                        "$FUNCNAME: Ignoring unrecognized option: '$opt'";;
                esac
              done;;
        esac;;
    *)  args+=("$arg");;
  esac; done
  if ! ((${#args[@]})); then printf >&2 '%s %s\n' "$RED$BOLD==>$NORMAL" \
    "$FUNCNAME: Refusing to work without arguments"; return 1; fi
  
  d__context -- notch

  local orig_path="${args[0]}" orig_dirpath
  d__require [ -n --ORIG_PATH-- "$orig_path" ] \
    --crcm-- 'Popping of backup initiated with an empty path' \
    --else-- 'Cannot pop backup' \
    || return 1
  if ! [ -e "$orig_path" ]; then
    $evict && d__notify -qq -- "Nothing to evict at: $orig_path"; evict=false
    orig_dirpath="$( dirname -- "$orig_path" )"
    if ! [ -d "$orig_dirpath" ]; then
      d__context -- push \
        "Ensuring existence of the parent directory of: $orig_path"
      d__cmd mkdir -p -- "$orig_dirpath" \
        --else-- 'Desired location is inaccessible' \
        || return 1
      d__context -- pop
    fi
  fi

  local backup_path i
  if [ -z ${args[1]+isset} ]; then
    d__notify -qq -- 'No backup path provided explicitly'
    d__context -- push "Popping backup from the deployment's backups directory"
    d__require [ -n --DPL_BACKUP_DIR-- "$D__DPL_BACKUP_DIR" ] \
      --crcm-- 'Popping of backup initiated outside of a deployment' \
      --else-- 'Cannot pop backup without an explicit backup path' \
      || return 3
    backup_path="$D__DPL_BACKUP_DIR/$( dmd5 -s "$orig_path" || exit $? ).bak"
    if (($?)); then
      d__fail -- 'Failed to generate the md5 checksum of the path'
      return 3
    fi
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
      d__context -- push 'Scanning for the latest backup'
      for ((i=2;i<=1000;++i)); do [ -e "$backup_path-$i" ] || break; done
      ((--i)); backup_path+="-$i"
      d__context -- pop
    fi
    d__context -- push "Restoring backup from: $backup_path"
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
      d__cmd rm -rf -- --ORIG_PATH-- "$orig_path" \
        --else-- 'Failed to clobber the path' \
        || return 3
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
      d__cmd mv -n -- --ORIG_PATH-- "$orig_path" \
        --EVICT_PATH-- "$orig_path_bak" \
        --else-- "Failed to evict the $orig_type" \
        || return 3
      d__context -- pop
      d__context -- pop
    fi
  fi

  if ! $restore; then d__context lop; return 0; fi

  d__context -- push 'Moving the backup to its original location'
  d__cmd mv -n -- --BACKUP_PATH-- "$backup_path" --ORIG_PATH-- "$orig_path" \
    --else-- 'Failed to pop backup' \
    || return 3
  d__context -- lop
  return 0
}