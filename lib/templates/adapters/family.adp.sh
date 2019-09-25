#!/usr/bin/env bash
#:title:        Divine.dotfiles template OS family adapter
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.09.25
#:revremark:    Remove revision numbers from all src files
#:created_at:   2019.06.04

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## An adapter is a set of functions that, when implemented, allow framework to 
#. support a particular family of operating systems
#
## For adapter file to be sourced and used, it must be named 'FAMILY.adp.sh' 
#. and placed in lib/adapters/family directory, where 'FAMILY' must be 
#. descriptive of OS family being adapted to.
#

#>  d__adapter_detect_os_family
#
## This function will be called with some local variables pre-set, and must use 
#. said variables or other means to judge whether current OS belongs to the OS 
#. family being adapted to. Guidelines below must be followed.
#
## Expect 'nocasematch' Bash option to be enabled by caller of this function
#
## Global variables made available to this function (all read-only):
#.  $D__OSTYPE    - Current content of $OSTYPE system variable or, if it is 
#.                  empty, captured output of $( uname -s 2>/dev/null )
#
## Local variables that must be set in case of successful match (no need to 
#. declare these as local, they will be declared as such by parent scope):
#.  $d__os_family - One-word description of current OS family. This word will 
#.                  be assigned to read-only global variable $D__OS_FAMILY, 
#.                  which in turn is then used throughout this framework and 
#.                  its deployments.
#.                  For clarity, this one word must match the name of adapter 
#.                  file, sans suffix
#.                  If this variable is set to a non-empty value, it is taken 
#.                  as indication of positive OS distro match
#
## Returns:
#.  Return code is ignored
#
d__adapter_detect_os_family()
{
  # Below is example implementation for macos family of operating systems

  [[ $D__OSTYPE = darwin* ]] && d__os_family=macos
}

#>  d__adapter_override_dpl_targets_for_os_family
#
## Provides a way for deployments to override $D_DPL_TARGET_PATHS global 
#. variable, which is used by helper functions in dln.hlp.sh and cp.hlp.sh. 
#. This function is called before contents of $D_DPL_TARGET_PATHS is settled 
#. upon.
#
d__adapter_override_dpl_targets_for_os_family()
{
  # Below is example implementation for BSD family of operating systems

  # Check if $D_DPL_TARGET_PATHS_BSD contains at least one string
  if [ ${#D_DPL_TARGET_PATHS_BSD[@]} -gt 1 \
    -o -n "$D_DPL_TARGET_PATHS_BSD" ]; then

    # $D_DPL_TARGET_PATHS_BSD is set: use it instead
    D_DPL_TARGET_PATHS=( "${D_DPL_TARGET_PATHS_BSD[@]}" )
    
  fi
}