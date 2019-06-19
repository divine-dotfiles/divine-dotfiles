D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

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
#.  $D_DPL_TASK_NUM             - Index of current task
#.  $D_DPL_TASK_STATUS_SUMMARY  - Container for status summary
#.  $D_DPL_TASK_FLAGS           - Container for installed/not installed flags
#

## Below is overall usage pattern for dcheck
dcheck()
{
  # Call each dcheck-like function and then immediately __catch_dcheck_code
  task1_dcheck; __catch_dcheck_code
  task2_dcheck; __catch_dcheck_code
  task3_dcheck; __catch_dcheck_code

  # As the last command, call __reconcile_dcheck_codes
  __reconcile_dcheck_codes
}

## Below is overall usage pattern for dinstall
dinstall()
{
  # Follow this pattern for each dinstall-like function
  __task_is_installable && task1_dinstall; __catch_dinstall_code || return $?
  __task_is_installable && task2_dinstall; __catch_dinstall_code || return $?
  __task_is_installable && task3_dinstall; __catch_dinstall_code || return $?
  
  # As the last command, call __reconcile_dinstall_codes
  __reconcile_dinstall_codes
}

## Below is overall usage pattern for dremove
dremove()
{
  # Follow this pattern for each dremove-like function
  __task_is_removable && task1_dremove; __catch_dremove_code || return $?
  __task_is_removable && task2_dremove; __catch_dremove_code || return $?
  __task_is_removable && task3_dremove; __catch_dremove_code || return $?
  
  # As the last command, call __reconcile_dremove_codes
  __reconcile_dremove_codes
}

## Unlike basic deployments, individual primary functions MUST be implemented 
#. at least in some way for each task
#
task1_dcheck()    { :; }
task1_dinstall()  { :; }
task1_dremove()   { :; }

task2_dcheck()    { :; }
task2_dinstall()  { :; }
task2_dremove()   { :; }

task3_dcheck()    { :; }
task3_dinstall()  { :; }
task3_dremove()   { :; }