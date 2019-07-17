D__DPL_NAME=
D__DPL_DESC=
D__DPL_PRIORITY=4096
D__DPL_FLAGS=
D__DPL_WARNING=

# Queue of items to be processed
D__DPL_QUEUE_MAIN=()

dcheck()    { __queue_hlp__dcheck;    }
dinstall()  { __queue_hlp__dinstall;  }
dremove()   { __queue_hlp__dremove;   }

## Exit codes and their meaning:
#.  0 - Unknown
#.  1 - Installed
#.  2 - Not installed
#.  3 - Invalid
d__queue_hlp__item_is_installed()
{
  :
}

## Exit codes and their meaning:
#.  0 - Successfully installed
#.  1 - Failed to install
#.  2 - Invalid item
#.  3 - Success: stop any further installations
#.  4 - Failure: stop any further installations
d__queue_hlp__install_item()
{
  :
}

## Exit codes and their meaning:
#.  0 - Successfully removed
#.  1 - Failed to remove
#.  2 - Invalid item
#.  3 - Success: stop any further removals
#.  4 - Failure: stop any further removals
d__queue_hlp__remove_item()
{
  :
}