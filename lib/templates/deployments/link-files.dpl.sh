D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

# Paths to replacement files (string or array thereof)
D_DPL_ASSET_PATHS=

# Paths to files to be replaced (string or array thereof)
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

dcheck()    { dln_check;    }
dinstall()  { dln_install;  }
dremove()   { dln_restore;  }