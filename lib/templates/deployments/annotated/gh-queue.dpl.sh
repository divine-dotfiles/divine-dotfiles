D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

## Copy-queue is a special queue that performs a sequence of copying: an asset 
#. provided with the deployment is copied to given paths, while any pre-
#. existing file is backed up to be restored upon removal.
#
## Copying is a useful way of pouring custom configuration assets into the 
#. system, e.g. the font files.
#
## Copy-queue is a queue ('queue.dpl.sh') with some actions pre-implemented.
#
## Variables to fill:
#.  $D_DPL_ASSET_PATHS    - This array must contain paths to every asset that 
#.                          is to be copied into the system.
#.  $D_DPL_TARGET_PATHS   - This array must contain corresponding 'target' 
#.                          paths that are to be copy destinations.
#. Framework has ways of auto-populating these arrays: see notes on automation 
#. below.
#
## Functions to implement (all are optional):
#.  * Executed during checking:
#.      d_copy_queue_pre_check    - Custom queue pre-processing
#.      d_copy_queue_post_check   - Custom queue post-processing
#.  * Executed during installation:
#.      d_copy_item_pre_install   - Pre-installation actions for each item
#.  * Executed during removal:
#.      d_copy_item_pre_remove    - Pre-removal actions for each item
#
## Variables to take advantage of (maintained by queue helpers):
#.  $D__ITEM_NUM         - Index of current item in $D_QUEUE_MAIN
#.  $D__ITEM_NAME       - Content of $D_QUEUE_MAIN for current item
#.  $D__ITEM_STASH_KEY   - Stash key for current item
#.  $D__ITEM_STASH_VALUE - Stash value for current item
#.  $D__ITEM_IS_FORCED   - This variable is set to 'true' if installation/
#.                            removal is being forced, i.e., it would not have 
#.                            been initiated if not for force option.
#.  $from_path              - Local variable that is populated with path to 
#.                            deployment asset currently being copied
#.  $to_path                - Local variable that is populated with path to 
#.                            where asset is being copied to
#.  $backup_path            - Local variable that is populated with path to 
#.                            backup location of currently replaced target
#

## Notes on automation:
#
## Framework provides a way to auto-populate asset paths ($D_DPL_ASSET_PATHS):
#.  * Asset manifest (see 'dpl-filename.dpl.mnf' template for reference)
#
## Target paths ($D_DPL_TARGET_PATHS) can be populated manually. OS-specific 
#. overrides for this array are given by suffixing system handle in uppercase 
#. to variable name, e.g., $D_DPL_TARGET_PATHS_BSD. Browse 'lib/adapters' for 
#. supported system handles.
#
## Perhaps a more convenient way of generating target paths is available when 
#. all targets are concentrated in a common parent directory. If relative paths 
#. to assets are kept in the same sub-directory structure as targets, simply 
#. providing path to target parent directory is enough for framework to figure 
#. out the rest.
#
## Target directory is provided in $D_DPL_TARGET_DIR variable. It is overridden 
#. for particular OS in the same manner as above, e.g., $D_DPL_TARGET_DIR_WSL.
#

## Framework provides three primary helpers. If queue is the only part of the 
#. deployment, these are sufficient.
#
d_dpl_check()    { d__copy_queue_check;    }
d_dpl_install()  { d__copy_queue_install;  }
d_dpl_remove()   { d__copy_queue_remove;   }

#>  d_copy_queue_pre_check
#
## Allows to perform arbitrary actions before items in queue are checked
#
## This function is called once for entire deployment
#
## Returns:
#.  0 - Pre-processing succeeded
#.  1 - Otherwise: do not proceed with this deployment
#
d_copy_queue_pre_check()
{
  :
}

#>  d_copy_queue_post_check
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
d_copy_queue_post_check()
{
  :
}

#>  d_copy_item_pre_install
#
## Performs custom actions before current item is installed
#
## This function is called once for every queue item
#
## Returns:
#.  0 - Ready for installation
#.  1 - Otherwise: mark this item as invalid
#
d_copy_item_pre_install()
{
  :
}

#>  d_copy_item_pre_remove
#
## Performs custom actions before current item is removed
#
## This function is called once for every queue item
#
## Returns:
#.  0 - Ready for removal
#.  1 - Otherwise: mark this item as invalid
#
d_copy_item_pre_remove()
{
  :
}