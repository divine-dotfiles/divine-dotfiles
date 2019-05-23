D_NAME=
D_DESC=
D_PRIORITY=4096
D_FLAGS=
D_WARNING=

# Paths to replacement files (string or array)
D_REPLACEMENTS=

# Paths to files to be replaced (string or array)
D_ORIG=

# OS family-specific overrides for $D_ORIG (narrow defeats broad)
D_ORIG_LINUX=
D_ORIG_WSL=
D_ORIG_BSD=
D_ORIG_MACOS=

# OS distro-specific overrides for $D_ORIG (narrow defeats broad)
D_ORIG_UBUNTU=
D_ORIG_DEBIAN=
D_ORIG_FEDORA=

dcheck()    { dln_check;    }
dinstall()  { dln_install;  }
dremove()   { dln_restore;  }