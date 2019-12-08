* [**`other`**] Change into the home directory as a first step of doing anything. This is mainly in case the current directory at the time of launching the script is no longer valid.

Related to transitions:

* [**`feature`**] Apply transition scripts not only during the updating of a bundle, but also during the attaching of it.
* [**`feature`**] Block most framework routines in case there is a record of failed transition script.
* [**`feature`**] Exclude a bundle from the primary routines in case there is a record of failed transition script.

Related to Git repository retrieval:

* [**`other`**] Do not take into account untracked files when checking whether a repository is dirty prior to pulling updates from its remote.

In the `README`:

* [**`fix`**] Add descriptions related to bundle transitions:
  * when they are applied;
  * how their return codes are handled;
  * what happens if they fail.
* [**`fix`**] Improve the presentation of the framework (un)installation commands. Make them single-line and wrapping visually on Github. This is also intended for pasting into non-Bash shells.
* [**`fix`**] Unsilence the calls to `wget` in the framework (un)installation commands. This is due to the fact that unlike `curl`, `wget` does not provide an option to silence the normal progress output without muting error messages.
* [**`other`**] Reword the reasoning behind choosing Bash as the language of the framework.