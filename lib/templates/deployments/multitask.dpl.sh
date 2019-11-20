#!/usr/bin/env bash
#:title:        Divine deployment annotated template for multitask
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.20
#:revremark:    Add D_DPL_OS to the dpl templates
#:created_at:   2019.11.19

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This is an annotated example of a deployment using the multitask helpers.
#
## The multitask helpers are a set of partly pre-implemented primary functions 
#. for deployments that carry out a series of dissimilar tasks. (For 
#. deployments that deal with a series of similar tasks, the queue helpers 
#. should be used.)
#
## For the full reference, see the README file of the framework.
#

D_DPL_NAME=example
D_DPL_DESC='An example description'
D_DPL_PRIORITY=1000
D_DPL_FLAGS=r
D_DPL_WARNING="Removing this deployment is dangerous"
D_DPL_OS="linux wsl"

## Variables to fill:
#.  * $D_MLTSK_MAIN     - (array) The multitask determinant. Each element of 
#.                        this array designates a task.
#
assemble_tasks()
{
  D_MLTSK_MAIN=( task_a task_b )
}

## Mini-primaries
#
## These functions are fully analogous to the primary functions of the regular 
#. deployments, but are specific to their task.
#
d_task_a_check()    { :; }
d_task_a_install()  { :; }
d_task_a_remove()   { :; }

d_task_b_check()    { :; }
d_task_b_install()  { :; }
d_task_b_remove()   { :; }

# The primary functions should call the multitask helpers as the last commands
d_dpl_check()    { assemble_tasks;  d__mltsk_check;    }
d_dpl_install()  {                  d__mltsk_install;  }
d_dpl_remove()   {                  d__mltsk_remove;   }

## Below are some of the global variables that are available to the mini-
#. primaries:
#.  $D__TASK_NAME   - The value of the determinant's element for the current 
#.                    task.
#.  $D__TASK_NUM    - The ordinal number of the current task (starts at zero).
#