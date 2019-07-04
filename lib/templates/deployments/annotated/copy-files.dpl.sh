D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

## Copy-files is a special queue that performs a sequence of copying: an asset 
#. provided with the deployment is copied to given paths, while any pre-
#. existing file is backed up to be restored upon removal.
#
## Copying is a useful way of pouring custom configuration assets into the 
#. system, e.g. the font files.
#
## Copy-files is a queue (‘queue.dpl.sh’) with some actions pre-implemented.
#
## Variables to fill:
#.  $D_DPL_ASSET_PATHS    - This array must contain paths to every asset that 
#.                          is to be copied into the system.
#.  $D_DPL_ASSET_RELPATHS - (optional) Not a requirement, but populating this 
#.                          array with shortened (e.g., relative to assets dir) 
#.                          versions of the above is very helpful for debug 
#.                          output.
#.  $D_DPL_TARGET_PATHS   - This array must contain corresponding ‘target’ 
#.                          paths that are to be copy destinations.
#. Framework has ways of auto-populating these arrays: see notes on automation 
#. below.
#
## Functions to implement (all are optional):
#.  * Executed during checking:
#.      __d__cp_hlp__pre_process    - Custom queue pre-processing
#.      __d__cp_hlp__post_process   - Custom queue post-processing
#.  * Executed during installation:
#.      __d__cp_hlp__install_item   - Pre-installation actions for each item
#.  * Executed during removal:
#.      __d__cp_hlp__remove_item    - Pre-removal actions for each item
#
## Variables to take advantage of (maintained by queue helpers):
#.  $D_DPL_ITEM_NUM         - Index of current item in $D_DPL_QUEUE_MAIN
#.  $D_DPL_ITEM_TITLE       - Content of $D_DPL_QUEUE_MAIN for current item
#.  $D_DPL_ITEM_STASH_KEY   - Stash key for current item
#.  $D_DPL_ITEM_STASH_VALUE - Stash value for current item
#.  $D_DPL_ITEM_IS_FORCED   - This variable is set to ‘true’ if installation/
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
#.  * Asset manifest (see ‘dpl-filename.dpl.mnf’ template for reference)
#.        - This also populates $D_DPL_ASSET_RELPATHS array with shortened 
#.          versions of corresponding paths (relative to asset dir)
#
## Target paths ($D_DPL_TARGET_PATHS) can be populated manually. OS-specific 
#. overrides for this array are given by suffixing system handle in uppercase 
#. to variable name, e.g., $D_DPL_TARGET_PATHS_BSD. Browse ‘lib/adapters’ for 
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
dcheck()    { __cp_hlp__dcheck;    }
dinstall()  { __cp_hlp__dinstall;  }
dremove()   { __cp_hlp__dremove;   }

#>  __d__cp_hlp__pre_process
#
## Allows to perform arbitrary actions before items in queue are checked
#
## This function is called once for entire deployment
#
## Returns:
#.  0 - Pre-processing succeeded
#.  1 - Otherwise: do not proceed with this deployment
#
__d__cp_hlp__pre_process()
{
  :
}

#>  __d__cp_hlp__post_process
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
__d__cp_hlp__post_process()
{
  :
}

#>  __d__cp_hlp__install_item
#
## Performs custom actions before current item is installed
#
## This function is called once for every queue item
#
## Returns:
#.  0 - Ready for installation
#.  1 - Otherwise: mark this item as invalid
#
__d__cp_hlp__install_item()
{
  :
}

#>  __d__cp_hlp__remove_item
#
## Performs custom actions before current item is removed
#
## This function is called once for every queue item
#
## Returns:
#.  0 - Ready for removal
#.  1 - Otherwise: mark this item as invalid
#
__d__cp_hlp__remove_item()
{
  :
}
