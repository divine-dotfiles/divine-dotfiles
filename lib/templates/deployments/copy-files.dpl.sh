D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

# Paths to be copied from (string or array thereof)
D_DPL_ASSET_PATHS=

# Paths to be copied to (string or array thereof)
D_DPL_TARGET_PATHS=

# OS family-specific overrides for $D_DPL_TARGET_PATHS (narrow defeats broad)
D_DPL_TARGET_PATHS_LINUX=
D_DPL_TARGET_PATHS_WSL=
D_DPL_TARGET_PATHS_BSD=
D_DPL_TARGET_PATHS_MACOS=

# OS distro-specific overrides for $D_DPL_TARGET_PATHS (narrow defeats broad)
D_DPL_TARGET_PATHS_UBUNTU=
D_DPL_TARGET_PATHS_DEBIAN=
D_DPL_TARGET_PATHS_FEDORA=

dcheck()    { __cp_hlp__dcheck;    }
dinstall()  { __cp_hlp__dinstall;  }
dremove()   { __cp_hlp__dremove;   }