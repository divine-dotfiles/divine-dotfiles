* [**`other`**] During the `update` routine, if the declared version hasn't changed, output 'version unchanged' instead of 'up to date', to give less impression that no updates were pulled.
* [**`other`**] Ensure that during the `update` routine the Github retrieval utilities are offered before they are checked.
* [**`other`**] If the installation of the framework fails during the pre-flight checks, do not leave an empty framework directory behind.
* [**`other`**] Rename internal variables in the `fmwk` routine to be synergetic with the `update` routine.