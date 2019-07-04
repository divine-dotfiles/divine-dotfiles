D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

dcheck()
{
  task1_dcheck; __catch_dcheck_code
  task2_dcheck; __catch_dcheck_code
  task3_dcheck; __catch_dcheck_code

  __reconcile_dcheck_codes
}

dinstall()
{
  __task_is_installable && task1_dinstall; __catch_dinstall_code || return $?
  __task_is_installable && task2_dinstall; __catch_dinstall_code || return $?
  __task_is_installable && task3_dinstall; __catch_dinstall_code || return $?
  
  __reconcile_dinstall_codes
}

dremove()
{
  __task_is_removable && task1_dremove; __catch_dremove_code || return $?
  __task_is_removable && task2_dremove; __catch_dremove_code || return $?
  __task_is_removable && task3_dremove; __catch_dremove_code || return $?
  
  __reconcile_dremove_codes
}

task1_dcheck()    { :; }
task1_dinstall()  { :; }
task1_dremove()   { :; }

task2_dcheck()    { :; }
task2_dinstall()  { :; }
task2_dremove()   { :; }

task3_dcheck()    { :; }
task3_dinstall()  { :; }
task3_dremove()   { :; }