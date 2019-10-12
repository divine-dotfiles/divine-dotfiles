#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-1-sys
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.12
#:revremark:    Fix minor typo, pt. 2
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Ensures current system has all expected utilities available, or exits the 
#. script.
#

# Driver function
d__run_sys_checks()
{
  d__context -- notch
  d__context -qq -- push 'Checking system dependencies'
  local all_good=true var arr
  d___check_find; d___check_grep; d___check_awk; d___check_md5
  if $all_good; then
    d__context -t 'Done' -- pop 'System dependencies are in order'
    d__context -- lop
    return 0
  else
    d__fail -t 'Shutting down' -- 'Missing or incompatible system dependencies'
    exit 1
  fi
}

d___check_find()
{
  # TEST 1: this command must find just root path '/'
  arr=(); while IFS= read -r -d $'\0' var; do arr+=("$var")
  done < <( find -L / -path / -name / -mindepth 0 -maxdepth 0 \
    \( -type f -or -type d \) -print0 2>/dev/null || exit $? )
  if [ $? -eq 0 -a ${#arr[@]} -eq 1 -a "${arr[0]}" = '/' ]; then
    d__notify -qqqqt "Utility 'find': Test 1" -- 'Passed'
  else
    d__notify -lxt "Utility 'find': Test 1" -- 'Failed'
    all_good=false
  fi
  # Compose find command that uses extended regex for use within the fmwk
  if find -E / -maxdepth 0 &>/dev/null; then
    # BSD find with -E option
    d__efind() { find -E . "$@"; }
  else
    # GNU find with -regextype option
    d__efind() { find . -regextype posix-extended "$@"; }
  fi
}

d___check_grep()
{
  # TEST 1: this command must match line 'Be Eg'
  var="$( grep ^'Be E' <<'EOF' 2>/dev/null || exit $?
bEe
Be Eg
be e
EOF
)"
  if [ $? -eq 0 -a "$var" = 'Be Eg' ]; then
    d__notify -qqqqt "Utility 'grep': Test 1" -- 'Passed'
  else
    d__notify -lxt "Utility 'grep': Test 1" -- 'Failed'
    all_good=false
  fi
  # TEST 2: this command must match nothing (no literal matches)
  grep -Fxq 'ma*A' <<'EOF' 2>/dev/null
maA
maRa
maRA
ma*a
EOF
  if [ $? -ne 0 ]; then
    d__notify -qqqqt "Utility 'grep': Test 2" -- 'Passed'
  else
    d__notify -lxt "Utility 'grep': Test 2" -- 'Failed'
    all_good=false
  fi
  # TEST 3: this command must match line 'ma*a' (case insensitive match)
  grep -Fxqi 'ma*A' <<'EOF' 2>/dev/null
maA
maRa
maRA
ma*a
EOF
  if [ $? -eq 0 ]; then
    d__notify -qqqqt "Utility 'grep': Test 3" -- 'Passed'
  else
    d__notify -lxt "Utility 'grep': Test 3" -- 'Failed'
    all_good=false
  fi
  # TEST 4: this command must match line '  by the '
  var="$( \
    grep '^[[:space:]]*by the ' <<'EOF' || exit $?
buy the 
  by the 
EOF
    )"
  if [ $? -eq 0 -a "$var" = '  by the ' ]; then
    d__notify -qqqqt "Utility 'grep': Test 4" -- 'Passed'
  else
    d__notify -lxt "Utility 'grep': Test 4" -- 'Failed'
    all_good=false
  fi
}

d___check_awk()
{
  # TEST 1: this command must yield string 'halt'
  var="$( awk -F  '=' '{print $3}' 2>/dev/null <<<'go==halt=pry' || exit $? )"
  if [ $? -eq 0 -a "$var" = 'halt' ]; then
    d__notify -qqqqt "Utility 'awk': Test 1" -- 'Passed'
  else
    d__notify -lxt "Utility 'awk': Test 1" -- 'Failed'
    all_good=false
  fi
}

d___check_md5()
{
  # Settle on utility for generating md5 checksums across the fmwk
  if md5sum --version &>/dev/null; then
    d__notify -qqq -- "Using the 'md5sum' utility to calculate md5 checksums"
    dmd5()
    {
      local md5; if [ "$1" = -s ]; then
        md5="$( printf %s "$2" | md5sum | awk '{print $1}' )"
      else md5="$( md5sum -- "$1" | awk '{print $1}' )"; fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      d__notify -lxt 'Critical failure' -- \
        "Failed to calculate a valid md5 checksum using 'md5sum'"
      return 1
    }
  elif md5 -r <<<test &>/dev/null; then
    d__notify -qqq -- "Using the 'md5' utility to calculate md5 checksums"
    dmd5()
    {
      local md5; if [ "$1" = -s ]; then
        md5="$( md5 -rs "$2" | awk '{print $1}' )"
      else md5="$( md5 -r -- "$1" | awk '{print $1}' )"; fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      d__notify -lxt 'Critical failure' -- \
        "Failed to calculate a valid md5 checksum using 'md5 -r'"
      return 1
    }
  elif openssl version &>/dev/null; then
    d__notify -qqq -- "Using the 'openssl' utility to calculate md5 checksums"
    dmd5()
    {
      local md5; if [ "$1" = -s ]; then
        md5="$( printf %s "$2" | openssl md5 | awk '{print $1}' )"
      else md5="$( openssl md5 -- "$1" | awk '{print $1}' )"; fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      d__notify -lxt 'Critical failure' -- \
        "Failed to calculate a valid md5 checksum using 'md5sum'"
      return 1
    }
  else
    d__notify -lx -- 'Could not detect a utility to calculate md5 checksums'
    all_good=false
  fi
}

d__run_sys_checks