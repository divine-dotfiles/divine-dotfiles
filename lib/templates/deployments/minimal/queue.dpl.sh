D__DPL_NAME=
D__DPL_DESC=
D__DPL_PRIORITY=4096
D__DPL_FLAGS=
D__DPL_WARNING=

# Queue of items to be processed
D__DPL_QUEUE_MAIN=()

d_dpl_check()    { d__queue_check;    }
d_dpl_install()  { d__queue_install;  }
d_dpl_remove()   { d__queue_remove;   }

## Exit codes and their meaning:
#.  0 - Unknown
#.  1 - Installed
#.  2 - Not installed
#.  3 - Invalid
d_queue_item_is_installed()
{
  :
}

## Exit codes and their meaning:
#.  0 - Successfully installed
#.  1 - Failed to install
#.  2 - Invalid item
#.  3 - Success: stop any further installations
#.  4 - Failure: stop any further installations
d_queue_item_install()
{
  :
}

## Exit codes and their meaning:
#.  0 - Successfully removed
#.  1 - Failed to remove
#.  2 - Invalid item
#.  3 - Success: stop any further removals
#.  4 - Failure: stop any further removals
d_queue_item_remove()
{
  :
}