D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

## Queue is a kind of deployment that performs a sequence of similar tasks, 
#. e.g., customized package installations.
#
## Queue helpers allow user to only write actions to be performed on individual 
#. queue items, while queue iteration and result summary is taken care of by 
#. framework.
#
## Variables to fill:
#.  $D_DPL_QUEUE_MAIN - This array must contain one string for every item in 
#.                      queue. Such string is used to identify an item in debug 
#.                      messages. E.g., if queue is a series of files, their
#.                      filenames would fit nicely here.
#. Framework has ways of auto-populating this array: see note on automation 
#. below.
#
## Functions to implement (all are optional):
#.  * Executed during checking:
#.      __d__queue_hlp__pre_process         - Executed once, early, before 
#.                                            checking begins
#.      __d__queue_hlp__provide_stash_key   - Executed for every queue item, 
#.                                            before checking it
#.      __d__queue_hlp__item_is_installed   - Executed for every queue item,
#.                                            to check it
#.      __d__queue_hlp__post_process        - Executed once, after all queue 
#.                                            items are checked
#.  * Executed during installation:
#.      __d__queue_hlp__install_item        - Executed for every queue item,
#.                                            to install it
#.  * Executed during removal:
#.      __d__queue_hlp__remove_item         - Executed for every queue item,
#.                                            to remove it. On removal, queue 
#.                                            is processed in reverse order.
#
## Variables to take advantage of (maintained by queue helpers):
#.  $D_DPL_ITEM_NUM         - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE       - Content of $D_DPL_QUEUE_MAIN for current item
#.  $D_DPL_ITEM_STASH_KEY   - Stash key for current item
#.  $D_DPL_ITEM_STASH_VALUE - Stash value for current item
#.  $D_DPL_ITEM_STASH_FLAG  - ‘true’ if stash record exists
#.                            ‘false’ if stash record does not exist
#.                            unset if stash is not used for this
#.  $D_DPL_ITEM_IS_FORCED   - This variable is set to ‘true’ if installation/
#.                            removal is being forced, i.e., it would not have 
#.                            been initiated if not for force option.
#

## Note on automation:
#
## Framework provides ways to auto-populate queue array ($D_DPL_QUEUE_MAIN). 
#. First method that works wins:
#.  * Queue manifest (see ‘dpl-filename.dpl.que’ template for reference)
#.  * $D_DPL_ASSET_RELPATHS - If this variable is set, it is auto-copied into 
#.                            the queue
#.  * $D_DPL_ASSET_PATHS    - If this variable is set, it is auto-copied into 
#.                            the queue
#

## Framework provides three primary helpers. If queue processing is the only 
#. work being done, these are sufficient.
#
dcheck()    { __queue_hlp__dcheck;    }
dinstall()  { __queue_hlp__dinstall;  }
dremove()   { __queue_hlp__dremove;   }

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
#.  0 - Normal return code, is ignored
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
#.  0 - Installed successfully
#.  1 - Failed to install
#.  2 - Item turned out to be invalid
#.  3 - Installed successfully, also abort further queue processing
#.  4 - Failed to install, also abort further queue processing
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
#.  0 - Removed successfully
#.  1 - Failed to remove
#.  2 - Item turned out to be invalid
#.  3 - Removed successfully, also abort further queue processing
#.  4 - Failed to remove, also abort further queue processing
#
__d__queue_hlp__remove_item()
{
  :
}