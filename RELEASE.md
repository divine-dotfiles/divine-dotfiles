* [**`fix`**] During the `remove` routine, do not raise error state when a package is already removed.
* [**`fix`**] During the `install` and `remove` routines, treat halting as a form of failure, in terms of the routine's return code.
* [**`appearance`**] Slightly mute the informative alerts about the source and location of updated/retrieved repositories, e.g., during the `update` routine.
* [**`appearance`**] Change the textual icon on the `Halting` intro.
* [**`other`**] Slightly improve wording of the `--obliterate` option's alert.
* [**`other`**] Support the case when the `install`/`remove` routine finished, having performed zero tasks. Which technically shouldn't happen, at least currently.
* [**`debug`**] Add debug output when recording `install`/`remove` tasks as failed or refused.