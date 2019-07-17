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
#. (dcheck-like, dinstall-like, dremove-like), and then automatically reconcile 
#. their return codes.
#
## Each task should have a set of three functions implemented for it (naming is 
#. insignificant):
#.  dcheck-like       - Function that behaves as dcheck in its return codes
#.  dinstall-like     - Function that behaves as dinstall in its return codes
#.  dremove-like      - Function that behaves as dremove in its return codes
#
## Variables maintained (avoid touching these!):
#.  $D__DPL_TASK_NUM             - Index of current task
#.  $D__DPL_TASK_STATUS_SUMMARY  - Container for status summary
#.  $D__DPL_TASK_FLAGS           - Container for installed/not installed flags
#

## Below is overall usage pattern for dcheck
dcheck()
{
  # Assemble ordered list of prefixes to user-implemented task functions
  D__DPL_TASK_NAMES+=( task1 )
  D__DPL_TASK_NAMES+=( task2 )
  D__DPL_TASK_NAMES+=( task3 )

  # Delegate to built-in helper
  __multitask_hlp__dcheck
}

# dinstall and dremove are fully delegated to built-in helpers
dinstall()  {   __multitask_hlp__dinstall;  }
dremove()   {   __multitask_hlp__dremove;   }

## Individual primary functions should be named following a pattern:
#.  * d_{TASK_NAME}_dcheck:     task1 -> d_task1_dcheck
#.  * d_{TASK_NAME}_dinstall:   task1 -> d_task1_dinstall
#.  * d_{TASK_NAME}_dremove:    task1 -> d_task1_dremove
#
## As with normal deployments, it is not necessary for all functions to be 
#. implemented: default return values are assumed if any are not.
#
d_task1_dcheck()    { :; }
d_task1_dinstall()  { :; }
d_task1_dremove()   { :; }

d_task2_dcheck()    { :; }
d_task2_dinstall()  { :; }
d_task2_dremove()   { :; }

d_task3_dcheck()    { :; }
d_task3_dinstall()  { :; }
d_task3_dremove()   { :; }