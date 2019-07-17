#!/usr/bin/env bash
#:title:        Divine Bash deployment helpers: unset
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.07.17
#:revremark:    Initial revision
#:created_at:   2019.07.17

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Helpers that bulk-unset D_* vars (non-readonly) and d_* funcs (non-'d__')
#

#>  d__unset_d_vars
#
## There are a number of standard variables temporarily used by deployments. It 
#. is best to unset those between deployments to ensure no unintended data 
#. retention occurs.
#
d__unset_d_vars()
{
  # Storage variables
  local var_assignment var_name

  # Iterate over currently set variables, names of which start with 'D_'
  while read -r var_assignment; do

    # Extract variable’s name
    var_name="$( awk -F  '=' '{print $1}' <<<"$var_assignment" )"

    # If variable is not read-only (i.e., non-essential) — unset it
    ( unset $var_name 2>/dev/null ) && unset $var_name
    
  done < <( grep ^D_ < <( set -o posix; set ) )
}

#>  d__unset_d_funcs
#
## There are a number of standard functions temporarily used by deployments. It 
#. is best to unset those between deployments to ensure no unintended data 
#. retention occurs.
#
d__unset_d_funcs()
{
  # Storage variables
  local func_assignment func_name

  # Iterate over currently set funcs, names of which start with 'd_'
  while read -r func_assignment; do

    # Extract function’s names
    func_name=${func_assignment#'declare -f '}

    # Skip internal 'd__*' functions (double underscore)
    [[ $func_name = d__* ]] && continue

    # Unset the function
    unset -f $func_name
    
  done < <( grep ^'declare -f d_' < <( declare -F ) )
}