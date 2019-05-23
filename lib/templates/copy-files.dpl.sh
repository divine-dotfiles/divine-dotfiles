D_NAME=
D_DESC=
D_PRIORITY=4096
D_FLAGS=
D_WARNING=

# Paths to be copied from (string or array)
D_FROM=

# Paths to be copied to (string or array)
D_TO=

# OS family-specific overrides for $D_TO (narrow defeats broad)
D_TO_LINUX=
D_TO_WSL=
D_TO_BSD=
D_TO_MACOS=

# OS distro-specific overrides for $D_TO (narrow defeats broad)
D_TO_UBUNTU=
D_TO_DEBIAN=
D_TO_FEDORA=

dcheck()    { cp_check;    }
dinstall()  { cp_install;  }
dremove()   { cp_restore;  }