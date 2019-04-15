D_NAME=
D_DESC=
D_PRIORITY=4096
D_FLAGS=
D_WARNING=

## Exit codes and their meaning:
#.  0 - Prompt, then install/remove
#.  1 - Installed
#.  2 - Not installed
#.  3 - Irrelevant
dcheck()
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
dinstall()
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
dremove()
{
  return 0
}