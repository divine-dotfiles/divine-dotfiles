#!/usr/bin/env bash
#:title:        Divine deployment annotated template for queue
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.19
#:revremark:    Bring templates up to speed; improve mtdt parsing
#:created_at:   2019.11.19

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This is an annotated example of a deployment using the queue helpers.
#
## The queue helpers are a set of partly pre-implemented primary functions for 
#. deployments that carry out a series of similar tasks. (For deployments that 
#. deal with a series of dissimilar tasks, the multitask helpers should be 
#. used.)
#
## For the full reference, see the README file of the framework.
#

D_DPL_NAME=example
D_DPL_DESC='An example description'
D_DPL_PRIORITY=1000
D_DPL_FLAGS=r
D_DPL_WARNING="Removing this deployment is dangerous"

## Variables to fill:
#.  * $D_QUEUE_MAIN     - (array) The queue determinant. Each element of this 
#.                        array designates a queue item.
#
assemble_queue()
{
  D_QUEUE_MAIN=( a b c )
}

## Mini-primaries
#
## These functions are fully analogous to the primary functions of the regular 
#. deployments, but are run for every single queue item.
#
d_item_check()    { :; }
d_item_install()  { :; }
d_item_remove()   { :; }

# The primary functions should call the queue helpers as the last commands
d_dpl_check()    { assemble_queue;  d__queue_check;    }
d_dpl_install()  {                  d__queue_install;  }
d_dpl_remove()   {                  d__queue_remove;   }

## Below are some of the global variables that are available to the mini-
#. primaries:
#.  $D__ITEM_NAME   - The value of the queue determinant's element for the 
#.                    current queue item.
#.  $D__ITEM_NUM    - The ordinal number of the current queue item (starts at 
#.                    zero).
#