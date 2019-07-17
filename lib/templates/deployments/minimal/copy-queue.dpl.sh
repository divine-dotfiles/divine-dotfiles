D__DPL_NAME=
D__DPL_DESC=
D__DPL_PRIORITY=4096
D__DPL_FLAGS=
D__DPL_WARNING=

# Use asset manifest (‘*.dpl.mnf’ file) to list replacement files

# For target paths, either set them individually (path or array thereof)…
D__DPL_TARGET_PATHS=
# …or provide target dir for all assets
D__DPL_TARGET_DIR=

# Both kinds of $D__DPL_TARGET_* accept OS-specific overrides, e.g.:
D__DPL_TARGET_PATHS_LINUX=
D__DPL_TARGET_DIR_UBUNTU=

d_dpl_check()    { d__copy_queue_check;    }
d_dpl_install()  { d__copy_queue_install;  }
d_dpl_remove()   { d__copy_queue_remove;   }