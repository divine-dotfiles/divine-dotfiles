Add new package flags for the Divinefiles:

* [**`feature`**] The `*m*` flag controls whether the package should be installed exclusively via the system package manager.
* [**`feature`**] The `*d*` flag controls whether the package should be removed along with its dependencies. The condition for removal of a dependency is that is was not a leaf package *before* the main package is removed and it became a leaf package *after* the main package is removed.
This flag requires an additional function to be implemented in the OS distro adapter. This flag is currently not documented.

Other changes:

* [**`feature`**] Implement a new specialized queue, pkg-queue, which performs the same tasks as the Divinefiles, but manually and via the queue helpers. Not yet documented.
* [**`feature`**] Implement a new add-status for queues (`D_ADDST_QUEUE_IRRELEVANT`) and for multitasks (`D_ADDST_MLTSK_IRRELEVANT`). The purpose of this add-status is to be able to declare the whole queue/multitask irrelevant from just one member of it.
* [**`other`**] The stashing system is now automatically checked for readiness on all levels. All options regarding manual checking for stash readiness have been hidden.