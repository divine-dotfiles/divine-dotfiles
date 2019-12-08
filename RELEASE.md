Related to transitions:

* [**`feature`**] Apply transition scripts not only during the updating of a bundle, but also during the attaching of it.
* [**`feature`**] Block most framework routines in case there is a record of failed transition script.
* [**`feature`**] Exclude a bundle from the primary routines in case there is a record of failed transition script.

In the `README`:

* [**`fix`**] Add descriptions related to bundle transitions:
  * when they are applied;
  * how their return codes are handled;
  * what happens if they fail.
* [**`fix`**] Improve the presentation of the framework (un)installation commands. Make them single-line and wrapping visually on Github. This is also intended for pasting into non-Bash shells.
* [**`other`**] Reword the reasoning behind choosing Bash as the language of the framework.