D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

# Use asset manifest ('*.dpl.mnf' file) to list replacement files

# For target paths, either set them individually (path or array thereof)...
D_QUEUE_TARGETS=
# ...or provide target dir for all assets
D_QUEUE_TARGET_DIR=

# Both kinds of target arrays accept OS-specific overrides, e.g.:
D_QUEUE_TARGETS_LINUX=
D_QUEUE_TARGET_DIR_UBUNTU=

d_dpl_check()    { d__link_queue_check;    }
d_dpl_install()  { d__link_queue_install;  }
d_dpl_remove()   { d__link_queue_remove;   }