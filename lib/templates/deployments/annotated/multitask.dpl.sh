D__DPL_NAME=
D__DPL_DESC=
D__DPL_PRIORITY=4096
D__DPL_FLAGS=
D__DPL_WARNING=

## Multitask is a kind of deployment that combines several disparate tasks, 
#. each of which could be a deployment of its own. E.g., installation of a 
#. framework, followed by installation of a queue of custom assets.
#
## Multitask helpers allow user to write several sets of primary functions 
#. (d_dpl_check-like, d_dpl_install-like, d_dpl_remove-like), and then automatically reconcile 
#. their return codes.
#
## Each task should have a set of three functions implemented for it (naming is 
#. insignificant):
#.  d_dpl_check-like       - Function that behaves as d_dpl_check in its return codes
#.  d_dpl_install-like     - Function that behaves as d_dpl_install in its return codes
#.  d_dpl_remove-like      - Function that behaves as d_dpl_remove in its return codes
#
## Variables maintained (avoid touching these!):
#.  $D__DPL_TASK_NUM             - Index of current task
#.  $D__DPL_TASK_STATUS_SUMMARY  - Container for status summary
#.  $D__DPL_TASK_FLAGS           - Container for installed/not installed flags
#

## Below is overall usage pattern for d_dpl_check
d_dpl_check()
{
  # Assemble ordered list of prefixes to user-implemented task functions
  D__DPL_TASK_NAMES+=( task1 )
  D__DPL_TASK_NAMES+=( task2 )
  D__DPL_TASK_NAMES+=( task3 )

  # Delegate to built-in helper
  d__multitask_check
}

# d_dpl_install and d_dpl_remove are fully delegated to built-in helpers
d_dpl_install()  {   d__multitask_install;  }
d_dpl_remove()   {   d__multitask_remove;   }

## Individual primary functions should be named following a pattern:
#.  * d_{TASK_NAME}_check:     task1 -> d_task1_check
#.  * d_{TASK_NAME}_install:   task1 -> d_task1_install
#.  * d_{TASK_NAME}_remove:    task1 -> d_task1_remove
#
## As with normal deployments, it is not necessary for all functions to be 
#. implemented: default return values are assumed if any are not.
#
d_task1_check()    { :; }
d_task1_install()  { :; }
d_task1_remove()   { :; }

d_task2_check()    { :; }
d_task2_install()  { :; }
d_task2_remove()   { :; }

d_task3_check()    { :; }
d_task3_install()  { :; }
d_task3_remove()   { :; }