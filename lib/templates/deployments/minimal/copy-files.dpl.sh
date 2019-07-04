D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

# Use asset manifest (‘*.dpl.mnf’ file) to list replacement files

# For target paths, either set them individually (path or array thereof)…
D_DPL_TARGET_PATHS=
# …or provide target dir for all assets
D_DPL_TARGET_DIR=

# Both kinds of $D_DPL_TARGET_* accept OS-specific overrides, e.g.:
D_DPL_TARGET_PATHS_LINUX=
D_DPL_TARGET_DIR_UBUNTU=

dcheck()    { __cp_hlp__dcheck;    }
dinstall()  { __cp_hlp__dinstall;  }
dremove()   { __cp_hlp__dremove;   }
