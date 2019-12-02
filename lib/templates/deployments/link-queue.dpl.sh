#!/usr/bin/env bash
#:title:        Divine deployment annotated template for link-queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.30
#:revremark:    Rewrite all Github references to point to new repo location
#:created_at:   2019.11.19

## Part of Divine.dotfiles <https://github.com/divine-dotfiles/divine-dotfiles>
#
## This is an annotated example of a deployment using the link-queue helpers.
#
## The link-queue takes a list of asset paths, a list of destination paths, and 
#. sequentially creates symlinks at the latter, pointing to the former. Any 
#. pre-existing files at the symlink locations are backed up. The stashing 
#. system is used to track the installations of the link-queue.
#
## For the full reference, see the README file of the framework.
#

D_DPL_NAME=example
D_DPL_DESC='An example description'
D_DPL_PRIORITY=1000
D_DPL_FLAGS=r
D_DPL_WARNING="Removing this deployment is dangerous"
D_DPL_OS=( ! linux wsl )

## Variables to fill:
#.  * $D_QUEUE_MAIN     - (array) The queue determinant. Each element of this 
#.                        array designates a queue item. It is recommended to 
#.                        populate the determinant with relative paths to the 
#.                        copied assets.
#.  * $D_QUEUE_ASSETS -   (array) For each queue item, this array should 
#.                        contain, at the same index, the absolute path to the 
#.                        asset file.
#.  * $D_QUEUE_TARGETS -  (array) For each queue item, this array should 
#.                        contain, at the same index, the absolute path to the 
#.                        location of the symlink.
#
assemble_queue()
{
  D_QUEUE_MAIN=( a b c )
  D_QUEUE_ASSETS=( "$D__DPL_DIR/a" "$D__DPL_DIR/b" "$D__DPL_DIR/c" )
  D_QUEUE_TARGETS=( "$HOME/a" "$HOME/b" "$HOME/c" )
}

# The framework's helpers should be called last
d_dpl_check()    { assemble_queue;  d__link_queue_check;    }
d_dpl_install()  {                  d__link_queue_install;  }
d_dpl_remove()   {                  d__link_queue_remove;   }