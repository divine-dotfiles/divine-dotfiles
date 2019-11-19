* [**`api`**] Look for deployment metadata until the first non-whitespace, non-commented line of the deployment script.
* [**`api`**] Phase out the OS family adapters.
* [**`api`**] Phase out the queue auto-targeting via the adapter-provided functions.
* [**`api`**] Make the queue auto-targeting explicit via calling the `d__queue_target` function.
* [**`other`**] Rewrite included templates to accurately reflect the latest framework developments.
* [**`other`**] In the debug output, make numbers of tasks and queue items zero-based, consistent with the Bash numbering.
* [**`fix`**] Prevent files in the bundles directory from being unnecessarily interpreted as unrecorded bundles.