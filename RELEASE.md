* [**`api`**] Completely **extricate the Grail directory** from within the framework directory. The Grail is now located at the root of the home directory and named `.grail`. Overrides for the Grail location are accepted (see the README).
* [**`feature`**] Add initial support for **bundle tags**. A bundle tag is a file in the root of the bundle directory, namde `bundle.sh`. It is the container for bundle's metadata.
* [**`fix`**] Restore missing user prompt when updating the framework.
* [**`fix`**] Fix the egregious syntax errors in the bundle synchronization system.
* [**`fix`**] During the `remove` routine, do not raise error state when a package is already removed.
* [**`fix`**] During the `install` and `remove` routines, treat halting as a form of failure, in terms of the routine's return code.
* [**`appearance`**] Slightly mute the informative alerts about the source and location of updated/retrieved repositories, e.g., during the `update` routine.
* [**`appearance`**] Change the textual icon on the `Halting` intro.
* [**`appearance`**] Prepend a blank line to the output of the installation/removal of the framework.
* [**`other`**] Implement the **transitions system**: the automated sourcing of transition scripts whenever a particular version is updated over. This system applies to the framework itself and the attached bundles.
* [**`other`**] During the installation of the framework, if the `sudo` privelege is required to install the shortcut command, but the privelege is present already, don't prompt for confirmation.
* [**`other`**] During the uninstallation of the framework, if the `sudo` privelege is required to remove the shortcut command, prompt for confirmation, unless the privelege is present already.
* [**`other`**] Slightly improve wording of the `--obliterate` option's alert.
* [**`other`**] Support the case when the `install`/`remove` routine finished, having performed zero tasks. Which technically shouldn't happen, at least currently.
* [**`debug`**] Add debug output when recording `install`/`remove` tasks as failed or refused.