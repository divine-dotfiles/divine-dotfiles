D_DPL_NAME=
D_DPL_DESC=
D_DPL_PRIORITY=4096
D_DPL_FLAGS=
D_DPL_WARNING=

## Exit codes and their meaning:
#.  0 - Unknown
#.  1 - Installed
#.  2 - Not installed
#.  3 - Irrelevant
#.  4 - Partly installed
d_dpl_check()
{
  return 0
}

## Exit codes and their meaning:
#.  0   - Successfully installed
#.  1   - Failed to install
#.  2   - Skipped completely
#.  100 - Reboot needed
#.  101 - User attention needed
#.  666 - Critical failure
d_dpl_install()
{
  return 0
}

## Exit codes and their meaning:
#.  0   - Successfully removed
#.  1   - Failed to remove
#.  2   - Skipped completely
#.  100 - Reboot needed
#.  101 - User attention needed
#.  666 - Critical failure
d_dpl_remove()
{
  return 0
}