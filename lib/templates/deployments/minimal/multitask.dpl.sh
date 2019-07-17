D__DPL_NAME=
D__DPL_DESC=
D__DPL_PRIORITY=4096
D__DPL_FLAGS=
D__DPL_WARNING=

d_dpl_check()
{
  D__DPL_TASK_NAMES+=( task1 )
  D__DPL_TASK_NAMES+=( task2 )
  D__DPL_TASK_NAMES+=( task3 )
  d__multitask_check
}

d_dpl_install()  {  d__multitask_install; }
d_dpl_remove()   {  d__multitask_remove;  }

d_task1_check()    { :; }
d_task1_install()  { :; }
d_task1_remove()   { :; }

d_task2_check()    { :; }
d_task2_install()  { :; }
d_task2_remove()   { :; }

d_task3_check()    { :; }
d_task3_install()  { :; }
d_task3_remove()   { :; }