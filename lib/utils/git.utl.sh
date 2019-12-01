#!/usr/bin/env bash
#:title:        Divine Bash utils: git
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.09.13

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## A set of utilities designed to clone Git repositories.
#

# Marker and dependencies
readonly D__UTL_GIT=loaded
d__load procedure prep-sys
d__load util workflow
d__load procedure check-gh

#>  d___clone_git_repo [-fgGs]... [-b BRANCH] [-t TITLE] [--] \
#>    REPO_HANDLE REPO_PATH
#
## INTERNAL USE ONLY
#
## Makes a clone of Git repository REPO_HANDLE into REPO_PATH directory, which 
#. must be empty/non-existent.
#
## Options:
#.  -b BRANCH, --branch BRANCH
#.                  - Checkout branch BRANCH, instead of master.
#.  -t TITLE, --title TITLE
#.                  - Use TITLE in debug output to refer to cloned repository.
#
## Repo type options:
#.  -g, --generic   - Treat REPO_HANDLE as generic git repo path, e.g., a local 
#.                    directory path.
#.  -G, --github    - (default) Treat REPO_HANDLE as short handle of Github 
#.                    repo, e.g., 'username/repository'.
#
## Deepness options:
#.  -f, --full      - Make a full clone.
#.  -s, --shallow   - (default) Make a shallow clone, of only the one branch.
#
## Returns:
#.  0 - Successfully cloned.
#.  1 - Otherwise.
#
d___clone_git_repo()
{
  # Pluck out options, round up arguments
  local args=() arg ii
  local cbrn cttl ctgh=true ctsh=true; unset cbrn cttl
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          b|-branch)  if (($#)); then cbrn="$1"; shift; fi;;
          t|-title)   if (($#)); then cttl="$1"; shift; fi;;
          f|-full)    ctsh=false;;
          s|-shallow) ctsh=true;;
          g|-generic) ctgh=false;;
          G|-github)  ctgh=true;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                b) if (($#)); then cbrn="$1"; shift; fi;;
                t) if (($#)); then cttl="$1"; shift; fi;;
                f) ctsh=false;;
                s) ctsh=true;;
                g) ctgh=false;;
                G) ctgh=true;;
                *) :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Dice parsed options and arguments
  local crph="${args[0]}" crpp="${args[1]}" copt=()
  if [ -z ${cttl+isset} ]; then
    if $ctgh; then
      cttl="Github repository '$crph'"
    else
      cttl="Git repository at '$crph'"
    fi
  fi
  $ctgh && crph="https://github.com/$crph.git"
  if ! [ -z ${cbrn+isset} ]; then
    cttl+=" (branch '$cbrn')" copt+=( -b "$cbrn" )
  fi
  cttl="clone of $cttl"
  if $ctsh; then
    cttl="shallow $cttl" copt+=( --depth=1 )
  fi

  # Proceed to cloning
  d__context -- notch
  d__context -- push "Making a $cttl"
  d__context -- push "Cloning into: '$crpp'"
  d__cmd --q-- git clone "${copt[@]}" \
    --REPO_SRC-- "$crph" --REPO_DST-- "$crpp" \
    --else-- 'Failed to clone' || return 1
  d__context -- pop
  d__context -t 'Done' -- pop "Successfully made a $cttl"
  d__context -- lop
  return 0
}

#>  d___dl_gh_repo [-cw]... [-b BRANCH] [-t TITLE] [--] REPO_HANDLE REPO_PATH
#
## INTERNAL USE ONLY
#
## Downloads using curl (or wget) the latest copy of Github repository 
#. REPO_HANDLE (in the form 'username/repository'), and untar it into REPO_PATH 
#. directory.
#
## Options:
#.  -b BRANCH, --branch BRANCH
#.                  - Download branch BRANCH, instead of master.
#.  -t TITLE, --title TITLE
#.                  - Use TITLE in debug output to refer to downloaded 
#.                    repository.
#
## Retrieval util options:
#.  -c, --curl      - (default) Download using 'curl'.
#.  -w, --wget      - Download using 'wget'.
#
## Returns:
#.  0 - Successfully downloaded and untarred.
#.  1 - Otherwise.
#
d___dl_gh_repo()
{
  # Pluck out options, round up arguments
  local args=() arg ii
  local dbrn dttl dutl=curl; unset dbrn dttl
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          b|-branch)  if (($#)); then dbrn="$1"; shift; fi;;
          t|-title)   if (($#)); then dttl="$1"; shift; fi;;
          c|-curl)    dutl=curl;;
          w|-wget)    dutl=wget;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                b) if (($#)); then dbrn="$1"; shift; fi;;
                t) if (($#)); then dttl="$1"; shift; fi;;
                c) dutl=curl;;
                w) dutl=wget;;
                *) :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Dice parsed options and arguments
  local drph="${args[0]}" drpp="${args[1]}" dopt=()
  [ -z ${dttl+isset} ] && dttl="Github repository '$drph'"
  drph="https://api.github.com/repos/${args[0]}/tarball"
  if ! [ -z ${dbrn+isset} ]; then
    dttl+=" (branch '$dbrn')" drph+="/$dbrn"
  fi
  dttl="copy of $dttl"
  case $dutl in
    curl) dutl=( curl -sL ) dttl+=' via curl';;
    wget) dutl=( wget -qO - ) dttl+=' via wget';;
  esac

  # Proceed to downloading/untarring
  d__context -- notch
  d__context -- push "Downloading a $dttl"
  d__context -- push "Untarring into: '$drpp'"
  d__pipe --q-- ${dutl[@]} --REPO_SRC-- "$drph" \
    --pipe-- tar --strip-components=1 -C --REPO_DST-- "$drpp" -xzf - \
    --else-- 'Failed to download/untar' || return 1
  d__context -- pop
  d__context -t 'Done' -- pop "Successfully downloaded a $dttl"
  d__context -- lop
  return 0
}

#>  d___pull_git_remote [-aBd]... [-r REMOTE] [-b BRANCH] [-t TITLE] [--] \
#>    REPO_PATH
#
## INTERNAL USE ONLY
#
## Within a directory REPO_PATH, which must be a cloned Git repository, pulls 
#. using Git the remote version of the current branch.
#
## If cloned repository is shallow and a branch other than current is 
#. requested, changes repository options to fetch all other branches. Refuses 
#. to touch REPO_PATH, if its working tree is dirty.
#
## Options:
#.  -r REMOTE, --remote REMOTE
#.                  - Pulls from REMOTE, instead of origin.
#.  -b BRANCH, --branch BRANCH
#.                  - Before pulling, ensure BRANCH is checked out. If BRANCH 
#.                    is not the current branch, then, if allowed, fetch latest 
#.                    revision and switch, don't pull afterward.
#.  -t TITLE, --title TITLE
#.                  - Use TITLE in debug output to refer to updated repository.
#
## Branch changing options:
#.  -B, --keep-branch - (default) Under no circumstances allow to change 
#.                      current branch.
#.  -d, --dev-only    - Only allow changing current branch from master to dev 
#.                      or vice versa. Blocks only cases where current branch 
#.                      does need to be changed.
#.  -a, --any-branch  - Allow any changes to current branch.
#
## Returns:
#.  0 - Successfully pulled from the remote.
#.  1 - Error occurred somewhere along the way.
#.  2 - Refused to even begin.
#
d___pull_git_remote()
{
  # Pluck out options, round up arguments
  local args=() arg ii
  local prem pbrn pttl pchb=false pchd=false; unset prem pbrn pttl
  while (($#)); do arg="$1"; shift; case $arg in
    -*) case ${arg:1} in
          -)  args+=("$@"); break;;
          r|-remote)  if (($#)); then prem="$1"; shift; fi;;
          b|-branch)  if (($#)); then pbrn="$1"; shift; fi;;
          t|-title)   if (($#)); then pttl="$1"; shift; fi;;
          B|-keep-branch) pchb=false pchd=false;;
          d|-dev-only)    pchb=true  pchd=true;;
          a|-any-branch)  pchb=true  pchd=false;;
          '') :;;
          -*) :;;
          *)  for ((ii=1;ii<${#arg};++ii)); do case ${arg:ii:1} in
                r) if (($#)); then prem="$1"; shift; fi;;
                b) if (($#)); then pbrn="$1"; shift; fi;;
                t) if (($#)); then pttl="$1"; shift; fi;;
                B) pchb=false pchd=false;;
                d) pchb=true  pchd=true;;
                a) pchb=true  pchd=false;;
                *) :;;
              esac; done;;
        esac;;
    *)  args+=("$arg");;
  esac; done

  # Dice parsed options and arguments
  local pspc= prpp="${args[0]}"
  [ -z ${pttl+isset} ] && pttl="cloned Git repository"
  if [ -z ${prem+isset} ]; then
    prem=origin
  else
    pspc+="from remote '$prem'"
  fi
  if ! [ -z ${pbrn+isset} ]; then
    [ -n "$pspc" ] && pspc+=', '
    pspc+="to branch '$pbrn'"
  fi
  [ -n "$pspc" ] && pttl+=" ($pspc)"

  # Extract path; change into it
  d__context -- notch
  d__context -- push "Updating a $pttl"
  d__context -- push "Pulling into: '$prpp'"
  d__cmd --sb-- pushd -- --REPO_PATH-- "$prpp" \
    --else-- 'Unable to pull updates into inaccessible directory' \
    || return 2

  # Ensure working tree is clean, or bail out
  if [ -n "$( git status --porcelain 2>/dev/null )" ]; then
    d__fail -t 'Refusing to pull' -- \
      'There are manual uncommitted changes in the directory'
    popd &>/dev/null
    return 2
  fi

  # Figure out current branch
  local cbrn="$( git rev-parse --abbrev-ref HEAD 2>/dev/null )" prtc=0
  case $cbrn in
    '')     d__fail -- 'Unable to detect name of current Git branch'
            prtc=2
            ;;
    'HEAD') d__fail -- "Unable to pull in 'detached HEAD' state"
            prtc=2
            ;;
  esac
  (($prtc)) && { popd &>/dev/null; return $prtc; }

  # Check if branch change rules allow to proceed
  local chbr=false achb=false
  [ -z ${pbrn+isset} ] && pbrn="$cbrn"
  if [ "$cbrn" = "$pbrn" ]; then
    :
  elif $pchb; then
    if $pchd; then
      case $cbrn in
        master|dev) :;;
        *)  d__fail -- "Refusing to change current branch from '$cbrn'"
            prtc=2
            ;;
      esac
      case $pbrn in
        master|dev) :;;
        *)  d__fail -- "Refusing to change current branch to '$pbrn'"
            prtc=2
            ;;
      esac
    fi
    chbr=true
  else
    d__fail -- "Refusing to change current branch from '$cbrn'"
    prtc=2
  fi
  (($prtc)) && { popd &>/dev/null; return $prtc; }

  # Fork based on whether cnanging current branch
  if $chbr; then
    d__context -- push "Switching from branch '$cbrn' to branch '$pbrn'"
  else
    d__context -- push "Pulling latest revision of branch '$pbrn'"
  fi

  # Validate name of the remote; extract remote URL
  if ! git ls-remote --exit-code "$prem" "$pbrn" &>/dev/null; then
    d__fail -- "Unable to find branch '$pbrn' on remote '$prem'"
    popd &>/dev/null
    return 2
  fi
  local psrc="$( git config --get remote.$prem.url 2>/dev/null )"
  if [ -z "$psrc" ]; then
    d__fail -- "Remote '$prem' doesn't appear to have an address"
    popd &>/dev/null
    return 2
  fi
  if [[ $psrc = 'https://github.com/'* ]]; then
    psrc="${psrc%.git}"
    psrc="Github repository '${psrc#https://github.com/}'"
  else
    psrc="Git repository at '$psrc'"
  fi

  # Fork based on whether changing branch or not
  if $chbr; then

    # Announce plans
    d__context -- push "Pulling updates from '$psrc'," \
      "switching to branch '$pbrn', and rebasing local commits on top"

    # Set proper Git options
    local curc reqc unic
    curc="$( git config --get remote.$prem.fetch 2>/dev/null )"
    reqc="+refs/heads/$pbrn:refs/remotes/$prem/$pbrn"
    unic="+refs/heads/*:refs/remotes/$prem/*"
    case $curc in
      # "$reqc")  :;;
      "$unic")  :;;
      *)  d__cmd --sb-- git config "remote.$prem.fetch" --CFG_STR-- "$unic" \
            --else-- 'Failed to set required Git configuration' \
            || { popd &>/dev/null; return 1; };;
    esac

    # First, fetch updates for target branch
    local ufms="Failed to fetch updates for branch '$pbrn' from remote '$prem'"
    d__cmd --q-- git fetch "$prem" "$pbrn" \
      --else-- "$ufms" || { popd &>/dev/null; return 1; }

    # Checkout required branch, which should definitely exist after fetch
    d__cmd --q-- git checkout "$pbrn" \
      --else-- "Failed to change current branch to '$pbrn'" \
      || { popd &>/dev/null; return 1; }

    # Finally, rebase any local commits on top of updates from remote
    ufms="Failed to rebase local commits in '$pbrn'"
    ufms+=" on top of its remote version '$prem/$pbrn'"
    d__cmd --q-- git rebase "$prem/$pbrn" "$pbrn" \
      --else-- "$ufms" || { popd &>/dev/null; return 1; }

    # Finish up
    popd &>/dev/null
    d__context -t 'Done' -- pop \
      "Successfully pulled updates and changed current branch to '$pbrn'"
    d__context -- lop
    return 0

  else

    # With current branch, simple pull --rebase will do
    d__context -- push "Pulling updates from '$psrc'" \
      "for current branch '$cbrn', and rebasing local commits on top"
    local ufms="Failed to pull updates for branch '$pbrn' from remote '$prem'"
    ufms+=' and rebase local commits on top of remote ones'
    d__cmd --q-- git pull --rebase --stat "$prem" "$cbrn" \
      --else-- "$ufms" || { popd &>/dev/null; return 1; }
    popd &>/dev/null
    d__context -t 'Done' -- pop "Successfully pulled updates from $psrc"
    d__context -- lop
    return 0

  fi
}

#>  d___gh_repo_exists REPO_HANDLE
#
## INTERNAL USE ONLY
#
## Checks whether the handle REPO_HANDLE (in the form 'username/repository') 
#. describes an existing and accessible Github repository.
#
## Uses in the global scope:
#>  $D__GH_METHOD - Global indicator of whether proper instruments for 
#.                  interaction with Github are available.
#
## Returns:
#.  0         - A Github repository by that handle exists and is accessible.
#.  non-zero  - Otherwise.
#
d___gh_repo_exists()
{
  case $D__GH_METHOD in
    g)  git ls-remote "git://github.com/$1.git" &>/dev/null;;
    c)  grep -q 200 < <( curl -I "https://api.github.com/repos/$1" \
          2>/dev/null | head -1 );;
    w)  grep -q 200 < <( wget -q --spider --server-response \
          "https://api.github.com/repos/$1" 2>&1 | head -1 );;
    *)  return 1;;
  esac
}

#>  d___path_is_gh_clone REPO_PATH REPO_HANDLE
#
## INTERNAL USE ONLY
#
## Checks whether the existing directory at REPO_PATH is a Git clone of the 
#. Github repository REPO_HANDLE (in the form 'username/repository').
#
## Returns:
#.  0 - The directory is accessible, Git is available, and the directory is a 
#.      Git clone of the given repository.
#.  1 - Otherwise: the directory is accessible, but either Git is unavailable, 
#.      or the directory is not a Git clone of the given repository.
#.  2 - The directory is inaccessible.
#
d___path_is_gh_clone()
{
  if pushd -- "$1" &>/dev/null; then
    if [ "$( git remote get-url origin 2>/dev/null )" \
      = "https://github.com/$2.git" ]
    then popd &>/dev/null; return 0
    else popd &>/dev/null; return 1; fi
  fi; return 2
}