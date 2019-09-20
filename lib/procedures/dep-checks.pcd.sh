#!/usr/bin/env bash
#:title:        Divine Bash procedure: dep-checks
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    13
#:revdate:      2019.09.20
#:revremark:    Merge fix-dmd5 into dev
#:created_at:   2019.07.05

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This file is intended to be sourced from framework's main script
#
## Ensures all system dependencies are available and functional
#

#>  d__check_system_dependencies
#
## Ensures current system has all expected utilities installed, or exits the 
#. script
#
## Returns:
#.  0 - All system dependencies are present and accessible
#.  1 - (script exit) Otherwise
#
d__check_system_dependencies()
{
  # Status variable
  local all_good=true
  
  # Test containers
  local test_bed tmp

  #
  # find
  #

  # Test: this command must find just root path '/'
  while IFS= read -r -d $'\0' tmp; do
    test_bed="$tmp"
  done < <( find -L / -path / -name / -mindepth 0 -maxdepth 0 \
    \( -type f -or -type d \) -print0 2>/dev/null \
    || exit $? )

  # Check if all is well
  if [ $? -ne 0 -o "$test_bed" != '/' ]; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$D__FMWK_NAME" \
      'Missing or incompatible system dependency' \
      'find'

    # Flip flag
    all_good=false

  fi

  # Compose find command that uses extended regex
  if find -E / -maxdepth 0 &>/dev/null; then

    # BSD find with -E option
    d__efind() { find -E . "$@"; }

  else

    # GNU find with -regextype option
    d__efind() { find . -regextype posix-extended "$@"; }

  fi

  #
  # grep
  #

  # Status variable for grep
  local grep_good=true

  # grep no. 1

  # Test: this command must match line 'Be Eg'
  test_bed="$( \
    grep ^'Be E' <<'EOF' 2>/dev/null || exit $?
bEe
Be Eg
be e
EOF
    )"

  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 'Be Eg' ] && grep_good=false

  # grep no. 2

  # Test: this command must match nothing (no literal matches)
  grep -Fxq 'ma*A' <<'EOF' 2>/dev/null && grep_good=false
maA
maRa
maRA
ma*a
EOF

  # Test: this command must match line 'ma*a' (case insensitive match)
  grep -Fxqi 'ma*A' <<'EOF' 2>/dev/null || grep_good=false
maA
maRa
maRA
ma*a
EOF

  # grep no. 3

  # Test: this command must match line '  by the '
  test_bed="$( \
    grep '^[[:space:]]*by the ' <<'EOF' || exit $?
buy the 
  by the 
EOF
    )"

  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != '  by the ' ] && grep_good=false

  # grep conclusion

  # Check if all is well
  if ! $grep_good; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$D__FMWK_NAME" \
      'Missing or incompatible system dependency' \
      'grep'

    # Flip flag
    all_good=false

  fi

  #
  # sed
  #

  # Status variable for sed
  local sed_good=true sed_cmd

  # sed no. 1

  # Test: this command must yield string 'may t'
  test_bed="$( \
    sed <<<'  may t  // brittle # maro' 2>/dev/null \
      -e 's/[#].*$//' \
      -e 's|//.*$||' \
      -e 's/^[[:space:]]*//' \
      -e 's/[[:space:]]*$//' \
      || exit $?
    )"
  
  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 'may t' ] && sed_good=false

  # sed no. 2

  # Test: this command must yield string 'battered' without quotes around it
  sed_cmd='s/^"(.*)"$/\1/p'
  if sed -r <<<'' &>/dev/null; then
    test_bed="$( \
      sed -nre "$sed_cmd" 2>/dev/null <<<'"battered"' || exit $? \
      )"
  else
    test_bed="$( \
      sed -nEe "$sed_cmd" 2>/dev/null <<<'"battered"' || exit $? \
      )"
  fi

  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 'battered' ] && sed_good=false

  # sed no. 3

  # Test: this command must yield string 't  may'
  sed_cmd='s/^([[:space:]]*)(may) (t)$/\3\1\2/'
  if sed -r <<<'' &>/dev/null; then
    test_bed="$( \
      sed -re "$sed_cmd" 2>/dev/null <<<'  may t' || exit $? \
      )"
  else
    test_bed="$( \
      sed -Ee "$sed_cmd" 2>/dev/null <<<'  may t' || exit $? \
      )"
  fi
  
  # Check if all is well
  [ $? -ne 0 -o "$test_bed" != 't  may' ] && sed_good=false

  # sed conclusion

  # Check if all is well
  if ! $sed_good; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$D__FMWK_NAME" \
      'Missing or incompatible system dependency' \
      'sed'

    # Flip flag
    all_good=false

  fi

  #
  # awk
  #

  # Test: this command must yield string 'halt'
  test_bed="$( \
    awk -F  '=' '{print $3}' 2>/dev/null <<<'go==halt=pry' || exit $? \
    )"

  # Check if all is well
  if [ $? -ne 0 -o "$test_bed" != 'halt' ]; then

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$D__FMWK_NAME" \
      'Missing or incompatible system dependency' \
      'awk'

    # Flip flag
    all_good=false

  fi

  #
  # md5
  #

  if md5sum --version &>/dev/null; then

    # Make md5sum the utility of choice for md5 checksums
    dmd5()
    {
      if [ "$1" = -s ]; then
        local md5="$( printf %s "$2" | md5sum | awk '{print $1}' )"
      else
        local md5="$( md5sum -- "$1" | awk '{print $1}' )"
      fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      printf >&2 '%s: %s\n' "$D__FMWK_NAME" \
        'Failed to calculate a valid md5 checksum using `md5sum`'
      return 1
    }

  elif md5 -r <<<test &>/dev/null; then

    # Make md5 the utility of choice for md5 checksums
    dmd5()
    {
      if [ "$1" = -s ]; then
        local md5="$( md5 -rs "$2" | awk '{print $1}' )"
      else
        local md5="$( md5 -r -- "$1" | awk '{print $1}' )"
      fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      printf >&2 '%s: %s\n' "$D__FMWK_NAME" \
        'Failed to calculate a valid md5 checksum using `md5 -r`'
      return 1
    }

  elif openssl version &>/dev/null; then

    # Make openssl the utility of choice for md5 checksums
    dmd5()
    {
      if [ "$1" = -s ]; then
        local md5="$( printf %s "$2" | openssl md5 | awk '{print $1}' )"
      else
        local md5="$( openssl md5 -- "$1" | awk '{print $1}' )"
      fi
      if [ ${#md5} -eq 32 ]; then printf '%s\n' "$md5"; return 0; fi
      printf >&2 '%s: %s\n' "$D__FMWK_NAME" \
        'Failed to calculate a valid md5 checksum using `openssl md5`'
      return 1
    }

  else

    # Announce failure
    printf >&2 '%s: %s: %s\n' \
      "$D__FMWK_NAME" \
      'Missing or incompatible system dependencies' \
      'md5sum / md5 / openssl'

    # Flip flag
    all_good=false

  fi

  #
  # Shocking conclusion
  #

  if $all_good; then return 0; else exit 1; fi
}

d__check_system_dependencies
unset -f d__check_system_dependencies