#!/usr/bin/env bash
#:title:        Divine Bash procedure: prep-sys
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script.
#
## Ensures current system has all expected utilities available, or exits the 
#. script.
#

# Marker and dependencies
readonly D__PCD_PREP_SYS=loaded
d__load util workflow

# Driver function
d__pcd_prep_sys()
{
  d__context -- notch
  d__context -qq -- push 'Checking system dependencies'
  local algd=true var arr
  d___check_find; d___check_grep; d___check_awk
  if $algd; then
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
    algd=false
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
    algd=false
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
    algd=false
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
    algd=false
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
    algd=false
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
    algd=false
  fi
}

d__pcd_prep_sys