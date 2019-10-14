#!/usr/bin/env bash
#:title:        Divine Bash utils: manifests
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.10.14
#:revremark:    Fix minor typo, pt. 3
#:created_at:   2019.05.30

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## Utility that parses the Divine manifests.
#

#>  d__process_manifest PATH
#
## Interprets single provided path as manifest file. Parses the file, returns 
#. results by populating global arrays. Each array is emptied out before the
#. manifest file is touched.
#
## Supported sub-types of manifests:
#.  * '*.dpl.mnf'     - Divine deployment asset manifest.
#.  * '*.dpl.que'     - Divine deployment queue manifest.
#.  * 'Divinefile'    - Special kind of Divine deployment for handling system 
#.                      packages. Lines of Divinefile are not parsed beyond 
#.                      key-values and comments.
#
## Modifies in the global scope:
#.  $D__MANIFEST_LINES      - (array) Non-empty lines from manifest file that 
#.                            are relavant for the current OS. Each line is 
#.                            trimmed of whitespace on both ends.
#.  $D__MANIFEST_LINE_FLAGS - (array) For each extracted line, this array will 
#.                            contain its char flags as a string at the same 
#.                            index.
#.  $D__MANIFEST_LINE_PRFXS - (array) For each extracted line, this array will 
#.                            contain its prefix at the same index.
#.  $D__MANIFEST_LINE_PRTYS - (array) For each extracted line, this array will 
#.                            contain its priority at the same index.
#.  $D__MANIFEST_SPLITS     - (array) For each extracted line, this array will 
#.                            contain the string 'true' at the same index iff 
#.                            there is a queue split _before_ that line.
#.  $D__MANIFEST_ENDSPLIT   - If there is a queue split after the very last 
#.                            line, this variable will be set to 'true'.
#
## Returns:
#.  0 - Manifest processed, arrays now represent its relevant content
#.  1 - Manifest file could not be accessed, arrays are empty
#
d__process_manifest()
{
  # Initialize container arrays
  D__MANIFEST_LINES=()
  D__MANIFEST_LINE_FLAGS=()
  D__MANIFEST_LINE_PRFXS=()
  D__MANIFEST_LINE_PRTYS=()
  D__MANIFEST_SPLITS=()
  D__MANIFEST_ENDSPLIT=false

  # Extract and check path; announce; init storage variables
  local mnfp="$1"; [ -r "$1" -a -f "$1" ] || return 1
  d__context -- notch
  d__context -qqq -- push "Processing manifest at: $mnfp"
  local mnfl lcont=false bfr bfrb chnk tmp tmpl tmpr ky vl vla ii xx yy zz
  local ong_rel ong_flg ong_pfx ong_pty cur_rel cur_flg cur_pfx cur_pty splt

  # Initial (default) statuses
  ong_rel=true ong_flg= ong_pfx= ong_pty="$D__CONST_DEF_PRIORITY" splt=false

  $D__DISABLE_CASE_SENSITIVITY

  # Iterate over lines in manifest file (strip whitespace on both ends)
  while read -r mnfl || [ -n "$mnfl" ]; do

    # Check if line is empty or commented
    if [ -z "$mnfl" ] || [[ $mnfl = \#* ]]; then

      # Check if arrived with line continuation; if not just skip empty line
      if [ "$lcont" = true ]; then
        ## Continuation ends here; if there is any buffer to speak of (from 
        #. previous lines), use it in current parsing cycle, otherwise, just go 
        #. to next line
        lcont=false; [ -n "$bfr" ] || continue
      else
        # No line continuation: just skip empty line
        continue
      fi

    else

      # Line is not empty/commented: check if arrived with line continuation
      if [ "$lcont" = true ]; then
        # Line continuation ends here; append to buffer
        lcont=false bfr+="$mnfl"
      else
        # No line continuation: populate buffer; inherit statuses
        bfr="$mnfl"
        cur_rel="$ong_rel" cur_flg="$ong_flg"
        cur_pfx="$ong_pfx" cur_pty="$ong_pty"
      fi

    fi

    # Check if remaining line contains comment symbol
    if [[ $bfr = *\#* ]]; then

      # Save current buffer in case this is not really a commented line
      bfrb="$bfr"

      # Break line on first occurence of comment symbol
      IFS='#' read -r chnk tmp <<<"$bfr"

      # Repeat until last character before split is not '\'
      while [[ chnk = *\\ ]]; do

        # Check if right part contains another comment symbol
        if [[ $tmp = *\#* ]]; then
          # Re-split right part on comment symbol; re-attach amputated parts
          IFS='#' read -r tmpl tmpr <<<"$tmp"
          chnk="${chnk:0:${#chnk}-1}#$tmpl" tmp="$tmpr"
        else
          # Not a proper commented line: restore original buffer and break
          chnk="$bfrb"; break
        fi

      # Done repeating until last character before split is not '\'
      done

      # Update buffer with non-commented part
      bfr="$chnk"

    # Done checking for comment symbol
    fi

    ## Repeat until line no longer starts with opening parenthesis and contains 
    #. closing one
    while [[ $bfr = \(*\)* ]]; do

      # Save current buffer in case this is not really a key-value
      bfrb="$bfr"
      # Shift away opening parenthesis
      bfr="${bfr:1:${#bfr}}"
      # Break line on first occurence of closing parenthesis
      IFS=')' read -r chnk tmp <<<"$bfr"

      # Repeat until last character before split is not '\'
      while [[ chnk = *\\ ]]; do

        # Check if right part contains another closing parenthesis
        if [[ $tmp = *\)* ]]; then
          # Re-split right part on closing ')'; re-attach amputated parts
          IFS=')' read -r tmpl tmpr <<<"$tmp"
          chnk="${chnk:0:${#chnk}-1})$tmpl" tmp="$tmpr"
        else
          # Not a proper key-value: restore original buffer and break loops
          bfr="$bfrb"; break 2
        fi

      # Done repeating until last character before split is not '\'
      done

      # Trim whitespace on both edges; update buffer
      read -r chnk <<<"$chnk"; read -r tmp <<<"$tmp"; bfr="$tmp"
      # If empty parentheses, discard key-value completely
      [ -z "$chnk" ] && continue

      # Check if parentheses contain key-value separator
      if [[ $chnk = *:* ]]; then

        # Split on first occurrence of separator
        IFS=: read -r ky vl <<<"$chnk"
        # Clear whitespace from edges of key and value
        read -r ky <<<"$ky"; read -r vl <<<"$vl"

        # Check key
        case $ky in
          os)       d___evaluate_key_os;;
          flags)    d___evaluate_key_flg;;
          prefix)   d___evaluate_key_pfx;;
          priority) d___evaluate_key_pty;;
          queue)    d___evaluate_key_que;;
          *)        # Unsupported key: ignore this key-value
                    continue;;
        esac

      else

        # Key-value parentheses do not contain a separator (':')
        # Special case: without separator, interpret key as flags value

        # Remove all whitespace from within the value
        chnk="${chnk//[[:space:]]/}"
        # Check if the list of flags starts with '+'
        if [[ $chnk = '+'* ]]; then
          # Strip the '+'; append to current flags
          chnk="${chnk:1:${#chnk}}"; cur_flg+="$chnk"
        else
          # Replace current flags
          cur_flg="$chnk"
        fi

      fi

    ## Done repeating until line no longer starts with opening parenthesis and 
    #. contains closing one
    done

    # Trim whitespace on both edges of remaining buffer
    read -r bfr <<<"$bfr"

    # Check if remaining buffer ends with '\'
    if [[ $bfr = *\\ ]]; then

      # Perform calculations
      ii="$(( ${#bfr} - 2 ))" xx=1
      while (( $ii )); do
        if [[ ${bfr:$ii:$ii+1} = \\ ]]; then ((++xx)); ((--ii)); else break; fi
      done
      yy="$(( $xx/2 ))"; zz="$(( $xx - $yy*2 ))"

      # Replace terminating backslashes
      bfr="${bfr:0:${#bfr}-$xx}"
      while (( $yy )); do bfr+='\'; ((--yy)); done

      # Check if there is an odd number of terminating backslashes
      if (( $zz )); then
        # (Re-)enable line continuation; go to next line
        lcont=true; continue
      fi

    fi

    # Check if the line proper starts with an escape character ('\')
    if [[ $bfr = \\* ]]; then
      # Remove exactly one escape character
      bfr="${bfr:1:${#bfr}}"
    fi

    # Check if there is any line remaining to speak of
    if [ -n "$bfr" ]; then
      # Line remains: proceed with it only if it is currently relevant
      [ "$cur_rel" = true ] || continue
    else
      # No line remaining: this line's key-values become ongoing
      ong_rel="$cur_rel" ong_flg="$cur_flg"
      ong_pfx="$cur_pfx" ong_pty="$cur_pty"
      # Go to next line
      continue
    fi

    # Finally, add this line and it's parameters to global array
    D__MANIFEST_LINES+=( "$bfr" )
    D__MANIFEST_LINE_FLAGS+=( "$cur_flg" )
    D__MANIFEST_LINE_PRFXS+=( "$cur_pfx" )
    D__MANIFEST_LINE_PRTYS+=( "$cur_pty" )
    D__MANIFEST_SPLITS+=( "$splt" )

    # Clear upcoming split marker; clear buffer
    splt=false bfr=

  # Done iterating over lines in manifest file
  done <"$mnfp"

  ## Check if last line was a relevant non-empty orphan (happens when file ends 
  #. with '\')
  if [ "$lcont" = true -a -n "$bfr" -a "$cur_rel" = true ]; then

    ## Last line needs to be processed. Key-values and comments are both 
    #. already processed, and status variables remain in relevant state
    
    # Add this line and it's parameters to global array
    D__MANIFEST_LINES+=( "$bfr" )
    D__MANIFEST_LINE_FLAGS+=( "$cur_flg" )
    D__MANIFEST_LINE_PRFXS+=( "$cur_pfx" )
    D__MANIFEST_LINE_PRTYS+=( "$cur_pty" )
    D__MANIFEST_SPLITS+=( "$splt" )

    # Clear upcoming split marker
    splt=false

  fi

  # Populate terminal split marker with the relevant value
  D__MANIFEST_ENDSPLIT="$splt"

  $D__RESTORE_CASE_SENSITIVITY

  d__context -- lop; return 0
}

d___evaluate_key_os()
{
  # If value is empty, all OS's are allowed
  if [ -z "$vl" ]; then cur_rel=true; return 0; fi

  # Check if the list of OS's starts with '!'
  if [[ $vl = '!'* ]]; then

    # Strip the '!' and re-trim the list
    vl="${vl:1:${#vl}}"; read -r vl <<<"$vl"
    ## If value is empty, all OS's are allowed (negation of empty 
    #. list is not allowed)
    if [ -z "$vl" ]; then cur_rel=true; return 0; fi
    # Read value as vertical bar-separated list of relevant OS's
    IFS='|' read -r -a vla <<<"$vl"
    # Set default value
    cur_rel=true

    # Iterate over list of negated OS's
    for vl in "${vla[@]}"; do
      # Clear whitespace from edges of OS name
      read -r vl <<<"$vl"
      # If value is either 'all' or 'any', all OS's are negated
      case $vl in all|any) cur_rel=false; break;; esac
      # If current OS name from the list matches detected OS, mark it
      if [[ $vl = $D__OS_FAMILY || $vl = $D__OS_DISTRO ]]
      then cur_rel=false; fi
    # Done iterating over list of relevant OS's
    done

  else

    # Normal list, does not stasrt with '!': set default status
    cur_rel=false
    # Read value as vertical bar-separated list of relevant OS's
    IFS='|' read -r -a vla <<<"$vl"

    # Iterate over list of relevant OS's
    for vl in "${vla[@]}"; do
      # Clear whitespace from edges of OS name
      read -r vl <<<"$vl"
      # If value is either 'all' or 'any', all OS's are allowed
      case $vl in all|any) cur_rel=true; break;; esac
      # If current OS name from the list matches detected OS, mark it
      if [[ $vl = $D__OS_FAMILY || $vl = $D__OS_DISTRO ]]
      then cur_rel=true; break; fi
    # Done iterating over list of relevant OS's
    done

  fi
}

d___evaluate_key_flg()
{
  # Remove all whitespace from within the value
  vl="${vl//[[:space:]]/}"
  # Check if the list of flags starts with '+'
  if [[ $vl = '+'* ]]; then
    # Strip the '+'; append to current flags
    vl="${vl:1:${#vl}}"; cur_flg+="$vl"
  else
    # Replace current flags
    cur_flg="$vl"
  fi
}

d___evaluate_key_pfx()
{
  # Clear leading and trailing slashes, if any
  while [[ $vl = /* ]]; do vl="${vl##/}"; done
  while [[ $vl = */ ]]; do vl="${vl%%/}"; done
  # Replace current prefix
  cur_pfx="$vl"
}

d___evaluate_key_pty()
{
  # Check if provided priority is a number
  if [[ $vl =~ ^[0-9]+$ ]]; then
    # Replace current priority with provided one
    cur_pty="$vl"
  else
    # Priority is not a valid number: assign default value
    cur_pty="$D__CONST_DEF_PRIORITY"
  fi
}

d___evaluate_key_que()
{
  # If the value is not precisely 'split', ignore this key-value
  [[ $vl = 'split' ]] || return 0
  # Set marker for upcoming split
  splt=true
}