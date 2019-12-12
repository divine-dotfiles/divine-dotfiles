#!/usr/bin/env bash
#:title:        Divine Bash utils: pkg
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    Implement m flag for packages
#:created_at:   2019.12.11

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## Helper utils that check/install/remove packages.
#

# Marker and dependencies
readonly D__UTL_PKG=loaded
d__load procedure prep-stash
d__load util workflow
d__load util stash

#>  d__pkg_check [-np] [-t PLAQUE] [-f FLAGS] [--] PKG
#
## Checks whether the package PKG is installed.
#
## Options:
#.  -f FLAGS, --flags FLAGS
#.                        - Passes package flags, if any.
#
#
## Plaque options (one active at a time; last one wins):
#.  -t PLAQUE, --plaque-text PLAQUE
#.                        - Uses PLAQUE string as the text of the plaque to 
#.                          print. Implies --print-plaque.
#.  -p, --print-plaque    - Directs to print a plaque, describing status of the 
#.                          package. Default plaque is composed from package 
#.                          name.
#.  -n, --no-plaque       - (default) Directs to not print a plaque.
#
## Returns:
#.  One of the check codes supported by the framework's primary functions.
#
d__pkg_check()
{
  # Pluck out options, round up arguments
  local args=() arg ii
  local print_plaque=false  # whether to print plaques describing status
  local plaque_txt; unset plaque_txt  # container for plaque text
  local pkg_flags=  # container for package flags
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          -f|-flags) if (($#)); then pkg_flags="$1"; shift; fi;;
          -t|-plaque-text)  if (($#)); then
                              print_plaque=true plaque_txt="$1"
                              shift
                            fi
                            ;;
          -p|-print-plaque) print_plaque=true;;
          -n|-no-plaque)    print_plaque=false;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                f)  if (($#)); then pkg_flags="$1"; shift; fi;;
                t)  if (($#)); then
                      print_plaque=true plaque_txt="$1"
                      shift
                    fi
                    ;;
                p)  print_plaque=true;;
                n)  print_plaque=false;;
                *)  :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Retrieve package name
  if [ ${#args[@]} -eq 0 ]; then
    d__notify -lx -- "$FUNCNAME: Called without package name"
    return 3
  fi
  local pkg_name="${args[0]}"  # name of package to check
  if [ -z "$pkg_name" ]; then
    d__notify -lx -- "$FUNCNAME: Called with empty package name"
    return 3
  fi
  local pkg_name_md5="$( d__md5 -s "$pkg_name" )"  # md5 checksum of name

  # Pre-set variables
  local mngr_only=fales  # flag for whether pkg is manager-exclusive
  local temp_msg  # container for long or repeatedly used messages

  # Check for manager-exclusive flag
  [[ $pkg_flags = *m* ]] && mngr_only=true

  # Settle on plaque text
  if $print_plaque && [ -z ${plaque_txt+isset} ]; then
    plaque_txt="Package '$BOLD$pkg_name$NORMAL'"
  fi

  # Fork on whether the package name appears installed
  if d__os_pkgmgr check "$pkg_name"; then

    # Installed via manager; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5" \
      || d__stash -rs -- has installed_utils "$pkg_name"
    then
      # Installed with stash record
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_1" "$plaque_txt"
      return 1
    else
      # Installed without stash record
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$plaque_txt"
      return 7
    fi

  elif ! $mngr_only && type -P -- "$pkg_name" &>/dev/null; then

    # Installed without manager; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5" \
      || d__stash -rs -- has installed_utils "$pkg_name"
    then
      # Installed without package manager, somehow there is a stash record
      d__notify -lx -- "Package '$pkg_name' is recorded" \
        "as previously installed via '$D__OS_PKGMGR'" \
        -n- 'but it now appears to be installed by other means'
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$plaque_txt"
      return 6
    else
      # Installed without package manager, no stash record
      d__notify -qq -- "Package '$pkg_name' appears to be installed" \
        "by means other than '$D__OS_PKGMGR'"
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$plaque_txt"
      return 7
    fi

  else

    # Not installed; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5" \
      || d__stash -rs -- has installed_utils "$pkg_name"
    then

      # Stash record exists; check if package appears available at all
      if d__os_pkgmgr has "$pkg_name"; then
        # Not installed, stash record exists, available
        d__notify -lx -- "Package '$pkg_name' is recorded" \
          "as previously installed via '$D__OS_PKGMGR'" \
          -n- "but it now appears ${BOLD}not$NORMAL installed"
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$plaque_txt"
        return 6
      else
        # Not installed, stash record exists, not available
        d__notify -lx -- "Package '$pkg_name' is recorded" \
          "as previously installed via '$D__OS_PKGMGR'" \
          -n- "but it now appears not installed" \
          "and even not available from '$D__OS_PKGMGR'"
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_NOTAV" "$plaque_txt"
        return 3
      fi

    else

      # No stash record; check if package appears available at all
      if d__os_pkgmgr has "$pkg_name"; then
        # Not installed, no stash record, available
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_2" "$plaque_txt"
        return 2
      else
        # Not installed, no stash record, not available
        temp_msg="Package '$pkg_name' does not appear "
        temp_msg+="available from '$D__OS_PKGMGR'"
        if $print_plaque; then
          d__notify -qs -- "$temp_msg"
          printf >&2 '%s %s\n' "$D__INTRO_NOTAV" "$plaque_txt"
        else
          d__notify -ls -- "$temp_msg"
        fi
        return 3
      fi

    fi

  fi
}

#>  d__pkg_install [-np] [-t PLAQUE] [-f FLAGS] [--] PKG
#
## Installs the package PKG.
#
## Options:
#.  -f FLAGS, --flags FLAGS
#.                        - Passes package flags, if any.
#
## Plaque options (one active at a time; last one wins):
#.  -t PLAQUE, --plaque-text PLAQUE
#.                        - Uses PLAQUE string as the text of the plaque to 
#.                          print. Implies --print-plaque.
#.  -p, --print-plaque    - Directs to print a plaque, describing status of the 
#.                          package. Default plaque is composed from package 
#.                          name.
#.  -n, --no-plaque       - (default) Directs to not print a plaque.
#
## Returns:
#.  0 - Installed successfully or already installed.
#.  1 - Error during installation or error state.
#.  2 - User refused to install or package unavailable.
#
d__pkg_install()
{
  # Pluck out options, round up arguments
  local args=() arg ii
  local print_plaque=false  # whether to print plaques describing status
  local plaque_txt; unset plaque_txt  # container for plaque text
  local pkg_flags=  # container for package flags
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          -f|-flags) if (($#)); then pkg_flags="$1"; shift; fi;;
          -t|-plaque-text)  if (($#)); then
                              print_plaque=true plaque_txt="$1"
                              shift
                            fi
                            ;;
          -p|-print-plaque) print_plaque=true;;
          -n|-no-plaque)    print_plaque=false;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                f)  if (($#)); then pkg_flags="$1"; shift; fi;;
                t)  if (($#)); then
                      print_plaque=true plaque_txt="$1"
                      shift
                    fi
                    ;;
                p)  print_plaque=true;;
                n)  print_plaque=false;;
                *)  :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Retrieve package name
  if [ ${#args[@]} -eq 0 ]; then
    d__notify -lx -- "$FUNCNAME: Called without package name"
    return 2
  fi
  local pkg_name="${args[0]}"  # name of package to check
  if [ -z "$pkg_name" ]; then
    d__notify -lx -- "$FUNCNAME: Called with empty package name"
    return 2
  fi
  local pkg_name_md5="$( d__md5 -s "$pkg_name" )"  # md5 checksum of name

  # Settle on plaque text
  if $print_plaque && [ -z ${plaque_txt+isset} ]; then
    plaque_txt="Package '$BOLD$pkg_name$NORMAL'"
  fi

  # Print intro
  $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_N" "$plaque_txt"

  # Pre-set default statuses and containers
  local pkg_forced=false  # whether package is being force-installed
  local will_install=false  # whether package will be installed
  local will_stash=false  # whether package's stash record will be set
  local always_prompt_mode=false  # flag for whether to always prompt
  local mngr_only=fales  # flag for whether pkg is manager-exclusive
  local temp_msg  # container for long or repeatedly used messages

  # Process flags
  case $pkg_flags in
    *[ai]*) always_prompt_mode=true;;
  esac
  [[ $pkg_flags = *m* ]] && mngr_only=true

  # Fork on whether the package name appears installed
  if d__os_pkgmgr check "$pkg_name"; then

    # Installed via manager; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5"; then
      # Installed with stash record
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_A" "$plaque_txt"
      return 0
    elif d__stash -rs -- has installed_utils "$pkg_name"; then
      # Installed through offer
      d__notify -q -- "Package '$pkg_name' appears to be" \
        "already installed by $D__FMWK_NAME itself"
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_A" "$plaque_txt"
      return 0
    else
      # Installed without stash record
      temp_msg="Package '$pkg_name' appears to be already installed"
      if $D__OPT_FORCE; then
        d__notify -l! -- "$temp_msg"
        pkg_forced=true will_stash=true
      else
        d__notify -q! -- "$temp_msg"
        d__notify -q! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$plaque_txt"
        return 0
      fi
    fi

  elif ! $mngr_only && type -P -- "$pkg_name" &>/dev/null; then

    # Installed without manager; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5"; then
      # Installed without package manager, somehow there is a stash record
      d__notify -lx -- "Package '$pkg_name' is recorded" \
        "as previously installed via '$D__OS_PKGMGR'" \
        -n- 'but it now appears to be installed by other means'
      if $D__OPT_FORCE; then
        pkg_forced=true will_install=true
      else
        d__notify -l! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_2" "$plaque_txt"
        return 1
      fi
    elif d__stash -rs -- has installed_utils "$pkg_name"; then
      # Installed without package manager, somehow there is an offer record
      d__notify -lx -- "Package '$pkg_name' is recorded" \
        "as previously installed by $D__FMWK_NAME itself" \
        -n- 'but it now appears to be installed by other means'
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_2" "$plaque_txt"
      return 1
    else
      # Installed without package manager, no stash record
      temp_msg="Package '$pkg_name' appears to be installed "
      temp_msg+="by means other than '$D__OS_PKGMGR'"
      if $D__OPT_FORCE; then
        d__notify -l! -- "$temp_msg"
        pkg_forced=true will_install=true will_stash=true
      else
        d__notify -q! -- "$temp_msg"
        d__notify -q! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_7" "$plaque_txt"
        return 0
      fi
    fi

  else

    # Not installed; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5"; then
      # Not installed, but stash record exists
      d__notify -lx -- \
        "Package '$pkg_name' is recorded as previously installed" \
        -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
        -n- '(which may be due to manual tinkering)'
      if $D__OPT_FORCE; then
        pkg_forced=true will_install=true
      else
        d__notify -l! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_2" "$plaque_txt"
        return 1
      fi
    elif d__stash -rs -- has installed_utils "$pkg_name"; then
      # Not installed, but offer record exists
      d__notify -lx -- \
        "Package '$pkg_name' is recorded as previously installed" \
        "by $D__FMWK_NAME itself" \
        -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
        -n- '(which may be due to manual tinkering)'
      if $D__OPT_FORCE; then
        pkg_forced=true will_install=true
      else
        d__notify -l! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_2" "$plaque_txt"
        return 1
      fi
    else
      # Not installed, no stash record
      will_install=true will_stash=true
    fi
  fi

  # Check whether that particular package is available in package manager
  if ! d__os_pkgmgr has "$pkg_name"; then
    temp_msg="Package '$pkg_name' does not appear "
    temp_msg+="available from '$D__OS_PKGMGR'"
    if $print_plaque; then
      d__notify -qs -- "$temp_msg"
      printf >&2 '%s %s\n' "$D__INTRO_NOTAV" "$plaque_txt"
    else
      d__notify -ls -- "$temp_msg"
    fi
    return 2
  fi

  # If forcing, print force intro
  if $pkg_forced && $print_plaque; then
    printf >&2 '%s %s\n' "$D__INTRO_INS_F" "$plaque_txt"
  fi

  # Conditionally prompt for user's approval
  if $always_prompt_mode || $pkg_forced || [ "$D__OPT_ANSWER" != true ]; then
    if $print_plaque; then
      if $always_prompt_mode || $pkg_forced; then
        printf >&2 '%s ' "$D__INTRO_CNF_U"
      else
        printf >&2 '%s ' "$D__INTRO_CNF_N"
      fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_INS_S" "$plaque_txt"
        return 2
      fi
    else
      temp_msg="Installing package '$pkg_name' via '$D__OS_PKGMGR'"
      if $always_prompt_mode || $pkg_forced; then
        d__prompt -x -- "$temp_msg"
      else
        d__prompt -! -- "$temp_msg"
      fi
      [ $? -eq 0 ] || return 2
    fi
  fi

  # Launch OS package manager
  if $will_install; then
    if ! d__os_pkgmgr install "$pkg_name"; then
      d__notify -lx -- 'Package manager returned an error code' \
        "while installing package '$pkg_name'"
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_1" "$plaque_txt"
      return 1
    fi
  fi

  # Set stash record
  if $will_stash; then
    if ! d__stash -rs -- set "pkg_$pkg_name_md5"; then
      d__notify -lx -- "Failed to set stash record for package '$pkg_name'"
    fi
  fi

  # Report
  $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_INS_0" "$plaque_txt"
  return 0
}

#>  d__pkg_remove [-np] [-t PLAQUE] [-f FLAGS] [--] PKG
#
## Removes the package PKG.
#
## Options:
#.  -f FLAGS, --flags FLAGS
#.                        - Passes package flags, if any.
#
## Plaque options (one active at a time; last one wins):
#.  -t PLAQUE, --plaque-text PLAQUE
#.                        - Uses PLAQUE string as the text of the plaque to 
#.                          print. Implies --print-plaque.
#.  -p, --print-plaque    - Directs to print a plaque, describing status of the 
#.                          package. Default plaque is composed from package 
#.                          name.
#.  -n, --no-plaque       - (default) Directs to not print a plaque.
#
## Returns:
#.  0 - Removed successfully or already removed or skipped removing.
#.  1 - Error during removal.
#.  2 - User refused to remove.
#
d__pkg_remove()
{
  # Pluck out options, round up arguments
  local args=() arg ii
  local print_plaque=false  # whether to print plaques describing status
  local plaque_txt; unset plaque_txt  # container for plaque text
  local pkg_flags=  # container for package flags
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          -f|-flags) if (($#)); then pkg_flags="$1"; shift; fi;;
          -t|-plaque-text)  if (($#)); then
                              print_plaque=true plaque_txt="$1"
                              shift
                            fi
                            ;;
          -p|-print-plaque) print_plaque=true;;
          -n|-no-plaque)    print_plaque=false;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                f)  if (($#)); then pkg_flags="$1"; shift; fi;;
                t)  if (($#)); then
                      print_plaque=true plaque_txt="$1"
                      shift
                    fi
                    ;;
                p)  print_plaque=true;;
                n)  print_plaque=false;;
                *)  :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Retrieve package name
  if [ ${#args[@]} -eq 0 ]; then
    d__notify -lx -- "$FUNCNAME: Called without package name"
    return 2
  fi
  local pkg_name="${args[0]}"  # name of package to check
  if [ -z "$pkg_name" ]; then
    d__notify -lx -- "$FUNCNAME: Called with empty package name"
    return 2
  fi
  local pkg_name_md5="$( d__md5 -s "$pkg_name" )"  # md5 checksum of name

  # Settle on plaque text
  if $print_plaque && [ -z ${plaque_txt+isset} ]; then
    plaque_txt="Package '$BOLD$pkg_name$NORMAL'"
  fi

  # Print intro
  $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_N" "$plaque_txt"

  # Pre-set default statuses and containers
  local pkg_forced=false  # whether package is being force-removed
  local will_remove=false  # whether package will be removed
  local will_unstash=false  # whether package's stash record will be unset
  local always_prompt_mode=false  # flag for whether to always prompt
  local mngr_only=fales  # flag for whether pkg is manager-exclusive
  local temp_msg  # container for long or repeatedly used messages

  # Process flags
  case $pkg_flags in
    *[ar]*) always_prompt_mode=true;;
  esac
  [[ $pkg_flags = *m* ]] && mngr_only=true

  # Fork on whether the package name appears installed
  if d__os_pkgmgr check "$pkg_name"; then

    # Installed via manager; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5"; then
      # Installed with stash record
      will_remove=true will_unstash=true
    elif d__stash -rs -- has installed_utils "$pkg_name"; then
      # Installed through offer
      d__notify -l! -- "Package '$pkg_name' appears to be installed" \
        "by $D__FMWK_NAME itself"
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$plaque_txt"
      return 0
    else
      # Installed without stash record
      d__notify -l! -- "Package '$pkg_name' appears to be installed" \
        "via '$D__OS_PKGMGR' manually"
      if $D__OPT_FORCE; then
        pkg_forced=true will_remove=true
      else
        d__notify -l! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$plaque_txt"
        return 0
      fi
    fi

  elif ! $mngr_only && type -P -- "$pkg_name" &>/dev/null; then

    # Installed without manager; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5"; then
      # Installed without package manager, somehow there is a stash record
      d__notify -lx -- "Package '$pkg_name' is recorded" \
        "as previously installed via '$D__OS_PKGMGR'" \
        -n- 'but it now appears to be installed by other means'
      if $D__OPT_FORCE; then
        pkg_forced=true will_unstash=true
      else
        d__notify -l! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$plaque_txt"
        return 1
      fi
    elif d__stash -rs -- has installed_utils "$pkg_name"; then
      # Installed without package manager, somehow there is an offer record
      d__notify -lx -- "Package '$pkg_name' is recorded" \
        "as previously installed by $D__FMWK_NAME itself" \
        -n- 'but it now appears to be installed by other means'
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$plaque_txt"
      return 1
    else
      # Installed without package manager, no stash record
      temp_msg="Package '$pkg_name' appears to be installed "
      temp_msg+="by means other than '$D__OS_PKGMGR'"
      if $D__OPT_FORCE; then
        d__notify -lx -- "$temp_msg" -n- 'Unable to remove'
      else
        d__notify -l! -- "$temp_msg"
      fi
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_2" "$plaque_txt"
      return 0
    fi

  else

    # Not installed; fork on presence of stash record
    if d__stash -rs -- has "pkg_$pkg_name_md5"; then
      # Not installed, but stash record exists
      d__notify -lx -- \
        "Package '$pkg_name' is recorded as previously installed" \
        -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
        -n- '(which may be due to manual tinkering)'
      if $D__OPT_FORCE; then
        pkg_forced=true will_unstash=true
      else
        d__notify -l! -- 'Re-try with --force to overcome'
        $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$plaque_txt"
        return 1
      fi
    elif d__stash -rs -- has installed_utils "$pkg_name"; then
      # Not installed, but offer record exists
      d__notify -lx -- \
        "Package '$pkg_name' is recorded as previously installed" \
        "by $D__FMWK_NAME itself" \
        -n- "but does ${BOLD}not$NORMAL appear to be installed right now" \
        -n- '(which may be due to manual tinkering)'
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_CHK_6" "$plaque_txt"
      return 1
    else
      # Not installed, no stash record
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_A" "$plaque_txt"
      return 0
    fi

  fi

  # Check whether that particular package is available in package manager
  if ! d__os_pkgmgr has "$pkg_name"; then
    d__notify -l! -- "Package '$pkg_name' does not appear" \
      "available from '$D__OS_PKGMGR'"
  fi

  # If forcing, print force intro
  if $pkg_forced && $print_plaque; then
    printf >&2 '%s %s\n' "$D__INTRO_RMV_F" "$plaque_txt"
  fi

  # Conditionally prompt for user's approval
  if $always_prompt_mode || $pkg_forced || [ "$D__OPT_ANSWER" != true ]; then
    if $print_plaque; then
      if $always_prompt_mode || $pkg_forced; then
        printf >&2 '%s ' "$D__INTRO_CNF_U"
      else
        printf >&2 '%s ' "$D__INTRO_CNF_N"
      fi
      if ! d__prompt -b; then
        printf >&2 '%s %s\n' "$D__INTRO_RMV_S" "$plaque_txt"
        return 2
      fi
    else
      temp_msg="Removing package '$pkg_name' via '$D__OS_PKGMGR'"
      if $always_prompt_mode || $pkg_forced; then
        d__prompt -x -- "$temp_msg"
      else
        d__prompt -! -- "$temp_msg"
      fi
      [ $? -eq 0 ] || return 2
    fi
  fi

  # Launch OS package manager
  if $will_remove; then
    if ! d__os_pkgmgr remove $pkg_name; then
      d__notify -lx -- 'Package manager returned an error code' \
        "while removing package '$pkg_name'"
      $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_1" "$plaque_txt"
      return 1
    fi
  fi

  # Unset stash record
  if $will_unstash; then
    if ! d__stash -rs -- unset "pkg_$pkg_name_md5"; then
      d__notify -lx -- "Failed to unset stash record for package '$pkg_name'"
    fi
  fi

  # Report
  $print_plaque && printf >&2 '%s %s\n' "$D__INTRO_RMV_0" "$plaque_txt"
  return 0
}
