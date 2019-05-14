#!/usr/bin/env bash
#:title:        Divine Bash routine: fmwk-update
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revnumber:    0.0.1-SNAPSHOT
#:revdate:      2019.05.14
#:revremark:    Initial revision
#:created_at:   2019.05.12

## Updates framework and optionally updates repositories in deployments 
#. directory
#

#>  __updating__main
#
## Performs updating routine
#
## If framework directory is a cloned repository, pulls from remote and 
#. rebases. Otherwise, re-downloads from Github to temp dir and overwrites 
#. files one by one.
#
## Optionally, for every repository in deployments directory, attempts to pull 
#. from remote and rebase, same as above, but without resorting to re-
#. downloading.
#
## Returns:
#.  0 - Routine performed
#.  1 - Routine terminated prematurely
#
__updating__main()
{
  :
}

__updating__main