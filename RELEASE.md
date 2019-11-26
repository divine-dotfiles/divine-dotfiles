* [**`feature`**] Introduce new routine, `di fmwk`, which manipulates the framework itself.
* [**`feature`**] Implement automated switch between stable and nightly builds of the framework:
  * `di fmwk nightly` — switches the framework to the `dev` branch which is potentially unstable.
  * `di fmwk stable` — switches the framework to the `master` branch which is expected to be stable.
* [**`other`**] Rewrite `update` routine for better logic structure.
* [**`other`**] When the `--yes` and `--obliterate` options are both given, substitute the `--obliterate` prompt with an alert.