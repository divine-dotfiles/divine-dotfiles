* [**`fix`**] Correctly recognize the `--help` and `--version` options on the intervention utility.
* [**`fix`**] When processing a deployment in a subshell, `exit` the subshell instead of `continue`ing the outer loop.
* [**`fix`**] Correctly parse manifest lines that have exactly two key-values and no entry.
* [**`fix`**] Correctly trim whitespace from deployment metadata when scanning for deployment files.
* [**`fix`**] Correctly extract stash values that contain exactly one `=` symbol in terminal position.
* [**`other`**] Expand the debug output:
  * Diversify messages when an asset is not found.
  * Print effective content of a parsed manifest on `-vvvv` level.