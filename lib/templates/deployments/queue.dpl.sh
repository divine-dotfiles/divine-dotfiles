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

#>  __d__queue_hlp__pre_process
#
## Allows to perform arbitrary actions before items in queue are checked
#
## This function is called once for entire deployment
#
## Returns:
#.  0 - Pre-processing succeeded
#.  1 - Otherwise: do not proceed with this deployment
#
__d__queue_hlp__pre_process()
{
  :
}

#>  __d__queue_hlp__provide_stash_key
#
## Gives user a chance to set custom stash key for queue item. Also, can signal 
#. to not use stashing at all for current item.
#
## This function is called once for every queue item
#
## Uses in global scope:
#.  $D_DPL_ITEM_NUM     - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE   - Content of $D_DPL_QUEUE_MAIN for current item
#
## Provides into global scope:
#.  $D_DPL_ITEM_STASH_KEY   - Assign custom stash key to this global variable
#
## Returns:
#.  1 - Disables storing installation records in stash for current item
#
__d__queue_hlp__provide_stash_key()
{
  :
}

#>  __d__queue_hlp__item_is_installed
#
## Return code of this function signals whether current queue item is to be 
#. considered installed, not installed, of unknown status, or completely 
#. invalid.
#
## This function is called once for every queue item
#
## Uses in global scope:
#.  $D_DPL_ITEM_NUM         - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE       - Content of $D_DPL_QUEUE_MAIN for current item
#.  $D_DPL_ITEM_STASH_KEY   - Stash key for current item
#.  $D_DPL_ITEM_STASH_VALUE - Stash value for current item
#
## Returns:
#.  0 - Unknown (no way to tell whether item is installed or not)
#.  1 - Installed
#.  2 - Not installed
#.  3 - Invalid (should not be touched at all)
#
__d__queue_hlp__item_is_installed()
{
  :
}

#>  __d__queue_hlp__post_process
#
## Allows to perform arbitrary actions after all items in queue have been 
#. checked
#
## This function is called once for entire deployment
#
## Returns:
#.  0 - Post-processing succeeded
#.  1 - Otherwise: do not proceed with this deployment
#
__d__queue_hlp__post_process()
{
  :
}

#>  __d__queue_hlp__install_item
#
## Installs current queue item
#
## This function is called once for every queue item
#
## Uses in global scope:
#.  $D_DPL_ITEM_NUM         - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE       - Content of $D_DPL_QUEUE_MAIN for current item
#.  $D_DPL_ITEM_STASH_KEY   - Stash key for current item
#.  $D_DPL_ITEM_STASH_VALUE - Stash value for current item
#.  $D_DPL_ITEM_IS_FORCED   - This variable is set to ‘true’ if this function 
#.                            would not have been called for current item if 
#.                            not for ‘--force’ option; otherwise ‘false’
#
## Returns:
#.  0 - Item is now installed
#.  1 - Item is now not installed
#.  2 - Item turned out to be invalid and should not be touched at all
#
__d__queue_hlp__install_item()
{
  :
}

#>  __d__queue_hlp__remove_item
#
## Removes current queue item
#
## This function is called once for every queue item
#
## Uses in global scope:
#.  $D_DPL_ITEM_NUM         - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE       - Content of $D_DPL_QUEUE_MAIN for current item
#.  $D_DPL_ITEM_STASH_KEY   - Stash key for current item
#.  $D_DPL_ITEM_STASH_VALUE - Stash value for current item
#.  $D_DPL_ITEM_IS_FORCED   - This variable is set to ‘true’ if this function 
#.                            would not have been called for current item if 
#.                            not for ‘--force’ option; otherwise ‘false’
#
## Returns:
#.  0 - Item is now removed
#.  1 - Item is now not removed (installed)
#.  2 - Item turned out to be invalid and should not be touched at all
#
__d__queue_hlp__remove_item()
{
  :
}