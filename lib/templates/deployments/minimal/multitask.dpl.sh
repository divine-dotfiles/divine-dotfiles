D__DPL_NAME=
D__DPL_DESC=
D__DPL_PRIORITY=4096
D__DPL_FLAGS=
D__DPL_WARNING=

dcheck()
{
  D__DPL_TASK_NAMES+=( task1 )
  D__DPL_TASK_NAMES+=( task2 )
  D__DPL_TASK_NAMES+=( task3 )
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