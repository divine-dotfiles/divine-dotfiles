#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: dln
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.04.02
#:revremark:    Initial revision
#:created_at:   2019.04.02

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helper functions for deployments based on template ‘link-files.dpl.sh’
#
## These functions replace original files with symlinks that point to 
#. replacements. Replaced files are moved to backup locations. Removal routine 
#. restores the initial set-up.
#

#> dln_check
#
## Checks whether each original file in $*_ORIG is currently replaced with a 
#. symlink pointing to respective target file in $D_TARGET. Generates backup 
#. paths array $D_BCKP for installation/removal functions to use.
#
## If given unequal number of paths in $*_ORIG and $D_TARGET, ignores the extra 
#. paths. If any of the paths is unreadable, or if current OS is not supported, 
#. returns ‘Irrelevant’ code for dcheck function to pick up
#
## Requires:
#.  $D_TARGET       - (array ok) Locations that symlinks should point to
#.  $D_ORIG         - (array ok) Locations of symlinks
#.  $D_ORIG_LINUX   - (array ok) Overrides $D_ORIG on Linux
#.  $D_ORIG_WSL     - (array ok) Overrides $D_ORIG on WSL
#.  $D_ORIG_BSD     - (array ok) Overrides $D_ORIG on BSD
#.  $D_ORIG_MACOS   - (array ok) Overrides $D_ORIG on macOS
#.  $D_ORIG_UBUNTU  - (array ok) Overrides $D_ORIG on Ubuntu
#.  $D_ORIG_DEBIAN  - (array ok) Overrides $D_ORIG on Debian
#.  $D_ORIG_FEDORA  - (array ok) Overrides $D_ORIG on Fedora
#.  $OS_DISTRO      - From Divine Bash utils: dOS (dos.utl.sh)
#.  $D_DPL_DIR      - Directory of calling deployment (for backup paths)
#.  Divine Bash utils: dmvln (dmvln.utl.sh)
#
## Provides into the global scope:
#.  $D_ORIG       - (array) $D_ORIG, possibly overridden for current OS
#.  $D_BCKP       - (array) Backup locations for current OS
#
## Returns:
#.  Values supported by dcheck function in *.dpl.sh
#
## Prints:
#.  stdout: *nothing*
#.  stderr: As little as possible
#
dln_check()
{
  # Override $D_ORIG for current OS family, if specific variable is non-empty
  case "$OS_FAMILY" in
    linux)
      [ ${#D_ORIG_LINUX[@]} -gt 1 -o -n "$D_ORIG_LINUX" ] \
        && D_ORIG=( "${D_ORIG_LINUX[@]}" );;
    wsl)
      [ ${#D_ORIG_WSL[@]} -gt 1 -o -n "$D_ORIG_WSL" ] \
        && D_ORIG=( "${D_ORIG_WSL[@]}" );;
    bsd)
      [ ${#D_ORIG_BSD[@]} -gt 1 -o -n "$D_ORIG_BSD" ] \
        && D_ORIG=( "${D_ORIG_BSD[@]}" );;
    macos)
      [ ${#D_ORIG_MACOS[@]} -gt 1 -o -n "$D_ORIG_MACOS" ] \
        && D_ORIG=( "${D_ORIG_MACOS[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Override $D_ORIG for current OS distro, if specific variable is non-empty
  case "$OS_DISTRO" in
    ubuntu)
      [ ${#D_ORIG_UBUNTU[@]} -gt 1 -o -n "$D_ORIG_UBUNTU" ] \
        && D_ORIG=( "${D_ORIG_UBUNTU[@]}" );;
    debian)
      [ ${#D_ORIG_DEBIAN[@]} -gt 1 -o -n "$D_ORIG_DEBIAN" ] \
        && D_ORIG=( "${D_ORIG_DEBIAN[@]}" );;
    fedora)
      [ ${#D_ORIG_FEDORA[@]} -gt 1 -o -n "$D_ORIG_FEDORA" ] \
        && D_ORIG=( "${D_ORIG_FEDORA[@]}" );;
    *)
      # Don’t override anything
      :;;
  esac

  # Check if $D_ORIG has ended up empty
  [ ${#D_ORIG[@]} -gt 1 -o -n "$D_ORIG" ] || return 3

  # Initialize global $D_BCKP to empty array
  D_BCKP=()

  # Storage variables
  local temppath
  local all_installed=true all_removed=true
  local all_exist=true
  local arr_size i

  # Get size of biggest array
  [ ${#D_ORIG[@]} -ge ${#D_TARGET[@]} ] \
    && arr_size=${#D_ORIG[@]} || arr_size=${#D_TARGET[@]}

  # Iterate over original file names
  for (( i=0; i<$arr_size; i++ )); do

    # Check if user provided any paths for this OS
    [ -n "${D_TARGET[$i]}" -a -n "${D_ORIG[$i]}" ] || continue

    # Check if target path exists (don’t care about original)
    if [ -r "${D_TARGET[$i]}" ]; then

      # Check if desired set-up is in place
      if dln -?q -- "${D_TARGET[$i]}" "${D_ORIG[$i]}"; then
        # If any one is installed, they are not all removed
        all_removed=false
      else
        # If any one is removed, they are not all installed
        all_installed=false
      fi

      # Construct backup file name
      D_BCKP+=( \
        "$D_BACKUPS_DIR/$D_NAME/$( basename "${D_ORIG[$i]}" )" \
      )

    else

      # Target path does not exist
      return 3
      
    fi

  done

  # Check if there was at least one good pair
  [ ${#D_BCKP[@]} -gt 0 ] || return 3

  # Check if all are installed
  $all_installed && return 1

  # Check if all are removed
  $all_removed && return 2

  ## Finally, if there is a mix — that speaks to manual tinkering. Ask the user 
  #. whether they want to proceed.
  return 0
}

#> dln_install
#
## Moves each original file in $D_ORIG to its respective backup location in 
#. $D_BCKP; replaces each with a symlink pointing to respective target file in 
#. $D_TARGET.
#
## Requires:
#.  $D_TARGET     - (array ok) Locations to symlink to
#.  $D_ORIG       - (array ok) Paths to back up and replace on current OS
#.  $D_BCKP       - (array ok) Backup locations on current OS
#.  Divine Bash utils: dmvln (dmvln.utl.sh)
#
## Returns:
#.  Values supported by dinstall function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
dln_install()
{
  # Storage variables
  local arr_size i
  local all_installed=true

  # Use backup array size as a reference number of good pairs of paths
  arr_size=${#D_BCKP[@]}

  # Iterate over good pairs of user-provided paths
  for (( i=0; i<$arr_size; i++ )); do

    # Re-check if target path exists
    [ -r "${D_TARGET[$i]}" ] || return 2

    # Create symlink, back up if necessary
    dln -f -- "${D_TARGET[$i]}" "${D_ORIG[$i]}" "${D_BCKP[$i]}" || {
      # Bail out on first sign of trouble
      all_installed=false
      break
    }
  
  done

  $all_installed && return 0 || return 1
}

#> dln_restore
#
## Removes each path in $D_ORIG that is a symlink pointing to respective target 
#. file in $D_TARGET; where possible, restores original file from respective 
#. backup location in $D_BCKP.
#
## Requires:
#.  $D_TARGET     - (array ok) Locations currently symlinked to
#.  $D_ORIG       - (array ok) Paths to be restored on current OS
#.  $D_BCKP       - (array ok) Backup locations on current OS
#.  Divine Bash utils: dmvln (dmvln.utl.sh)
#
## Returns:
#.  Values supported by dremove function in *.dpl.sh
#
## Prints:
#.  Status messages for user
#
dln_restore()
{
  # Storage variables
  local arr_size i
  local all_removed=true

  # Use backup array size as a reference number of good pairs of paths
  arr_size=${#D_BCKP[@]}

  # Iterate over good pairs of user-provided paths
  for (( i=0; i<$arr_size; i++ )); do

    # Don’t care if target exists, the task here is to break symlinks

    # Remove symlink; restore from backup
    dln -rq -- "${D_TARGET[$i]}" "${D_ORIG[$i]}" "${D_BCKP[$i]}"

    # Check if that did the trick
    if [ $? -ne 0 ]; then
      # Might be the problem is misplaced backup
      # Re-try without restoring from backup
      dln -r -- "${D_TARGET[$i]}" "${D_ORIG[$i]}" || {
        # Bail out on first sign of trouble
        all_removed=false
        break
      }
    fi

  done

  $all_removed && return 0 || return 1
}