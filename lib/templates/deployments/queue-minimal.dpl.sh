D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

# Queue of items to be processed
D_DPL_QUEUE_MAIN=()

dcheck()    { __queue_hlp__dcheck;    }
dinstall()  { __queue_hlp__dinstall;  }
dremove()   { __queue_hlp__dremove;   }

## List of globals used:
#.  $D_DPL_QUEUE_MAIN       - Queue of deployment’s items (parts)
#.  $D_DPL_ITEM_NUM         - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE       - Content of $D_DPL_QUEUE_MAIN for current item
#.  $D_DPL_ITEM_STASH_KEY   - Stash key for current item
#.  $D_DPL_ITEM_STASH_VALUE - Stash value for current item
#.  $D_DPL_ITEM_IS_FORCED   - This variable is set to ‘true’ if installation/
#.                            removal would not have been called for current 
#.                            item if not for ‘--force’ option; otherwise 
#.                            ‘false’

## Global variable to set:
#.  $D_DPL_ITEM_STASH_KEY - Custom stash key for current item
## Exit codes and their meaning:
#.  1 - Disable stashing for current item
__d__queue_hlp__provide_stash_key()
{
  :
}

## Exit codes and their meaning:
#.  0 - Unknown
#.  1 - Installed
#.  2 - Not installed
#.  3 - Invalid
__d__queue_hlp__item_is_installed()
{
  :
}

## Exit codes and their meaning:
#.  1 - Do not proceed with this deployment
__d__queue_hlp__post_process_queue()
{
  :
}

## Exit codes and their meaning:
#.  0 - Successfully installed
#.  1 - Failed to install
#.  2 - Invalid item
__d__queue_hlp__install_item()
{
  :
}

## Exit codes and their meaning:
#.  0 - Successfully removed
#.  1 - Failed to remove
#.  2 - Invalid item
__d__queue_hlp__remove_item()
{
  :
}