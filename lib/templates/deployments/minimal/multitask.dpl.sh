D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

d_dpl_check()
{
  D_MULTITASK_NAMES+=( task1 )
  D_MULTITASK_NAMES+=( task2 )
  D_MULTITASK_NAMES+=( task3 )
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