* [**`feature`**] During the updating of either the framework or a bundle, if any of the transition scripts fails, halt all further transitions and record the event, so that the offending transition is re-applied on the next update.
* [**`improvement`**] Make all specialized queues check for dead symlinks at their destination paths.
* [**`improvement`**] In the framework (un)installation commands, add support for restricted script execution in the OS's temporary directory.
* [**`appearance`**] During the `update` routine, show the repository URL and the destination path only in verbose mode.
* [**`other`**] Improve the `README` to better advertise the main points of the framework.
* [**`other`**] Add a note on race conditions to the `README`.
* [**`other`**] Rewrite the framework installation commands in the `dev` branch to install the nightly build.
* [**`other`**] Make the framework installation fail if there exists a dead symlink resembling a previously installed shortcut command.
* [**`other`**] During the framework installation, if the shortcut command is disabled, do not output its name.
* [**`other`**] During the `update` routine, if the declared version hasn't changed, output 'version unchanged' instead of 'up to date', to give less impression that no updates were pulled.
* [**`other`**] Ensure that during the `update` routine the Github retrieval utilities are offered before they are checked.
* [**`other`**] If the installation of the framework fails during the pre-flight checks, do not leave an empty framework directory behind.
* [**`other`**] Rename internal variables in the `fmwk` routine to be synergetic with the `update` routine.