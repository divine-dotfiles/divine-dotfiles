D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

dcheck()
{
  D_DPL_TASK_NAMES+=( task1 )
  D_DPL_TASK_NAMES+=( task2 )
  D_DPL_TASK_NAMES+=( task3 )
  __multitask_hlp__dcheck
}

dinstall()  {  __multitask_hlp__dinstall; }
dremove()   {  __multitask_hlp__dremove;  }

d_task1_dcheck()    { :; }
d_task1_dinstall()  { :; }
d_task1_dremove()   { :; }

d_task2_dcheck()    { :; }
d_task2_dinstall()  { :; }
d_task2_dremove()   { :; }

d_task3_dcheck()    { :; }
d_task3_dinstall()  { :; }
d_task3_dremove()   { :; }