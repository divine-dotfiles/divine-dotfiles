#!/usr/bin/env bash
#:title:        Divine deployment annotated template
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.11.19
#:revremark:    Bring templates up to speed; improve mtdt parsing
#:created_at:   2018.03.25

## Part of Divine.dotfiles <https://github.com/no-simpler/divine-dotfiles>
#
## This is an annotated example of a deployment.
#
## A deployment is a Bash script named 'NAME.dpl.sh', placed anywhere under the 
#. grail/dpls directory, containing some specially named functions (one to 
#. check, one to install, one to remove) and some specially named pseudo-
#. variables (the deployment's metadata). All of these parts are optional.
#
## For the full reference, see the README file of the framework.
#

## How to use this template:
#.  * Copy this template to anywhere under the 'grail/dpls' directory.
#.  * Rename this template, e.g., 'my-dpl.dpl.sh'.
#.  * Implement whichever parts you need (all are optional):
#.    - Assign the metadata (name, description, priority, flags, warning).
#.    - Implement the 'd_dpl_check'   function.
#.    - Implement the 'd_dpl_install' function.
#.    - Implement the 'd_dpl_remove'  function.
#

## Metadata
#
## The metadata pseudo-variables are extracted by pattern matching: they should 
#. reside each on its own line, without comments and substitutions. The 
#. metadata may be given in any order and not together, but must precede all 
#. other non-whitespace, non-commented lines of the script. A pair of matching 
#. quotes is allowed around the value.
#
D_DPL_NAME=example
D_DPL_DESC='An example description'
D_DPL_PRIORITY=1000
D_DPL_FLAGS=r
D_DPL_WARNING="Removing this deployment is dangerous"

## d_dpl_check
#
## The return code of this function determines whether the deployment is 
#. installed or not:
#.  * 0 - 'Truly unknown'.
#.  * 1 - 'Fully installed'.
#.  * 2 - 'Fully not installed'.
#.  * 3 - 'Irrelevant or invalid'.
#.  * 4 - 'Partly installed'.
#.  * 5 - 'Likely installed (unknown)'.
#.  * 6 - 'Manually removed (tinkered with)'.
#.  * 7 - 'Fully installed (by user or OS)'.
#.  * 8 - 'Partly installed (by user or OS)'.
#.  * 9 - 'Likely not installed (unknown)'.
#
d_dpl_check()
{
  :
}

## d_dpl_install
#
## Installs the deployment. The return code determines the status of the 
#. installation:
#.  * 0 - 'Successfully installed'.
#.  * 1 - 'Failed to install'.
#.  * 2 - 'Refused to install'.
#.  * 3 - 'Partly install'.
#
d_dpl_install()
{
  :
}

## d_dpl_remove
#
## Removes (reverses the previous installation of) the deployment. The return 
#. code determines the status of the removal:
#.  * 0 - 'Successfully removed'.
#.  * 1 - 'Failed to remove'.
#.  * 2 - 'Refused to remove'.
#.  * 3 - 'Partly remove'.
#
d_dpl_remove()
{
  :
}

## Below are some of the global variables that are available to this script:
#.  $D__OS_FAMILY   - (read-only) The broad description of the current OS type. 
#.                    The exhaustive list of possible values: 'bsd', 'cygwin', 
#.                    'linux', 'macos', 'msys', 'solaris', 'wsl'.
#.  $D__OS_DISTRO   - (read-only) The best guess on the name of the current OS 
#.                    distribution, e.g.: 'debian', 'fedora', 'freebsd', 
#.                    'macos', 'ubuntu'. Each file in the 'lib/adapters' 
#.                    directory represents a supported OS distro. When the 
#.                    distro is not recognized, this variable is empty.
#.  $D__OS_PKGMGR   - (read-only) The name of the package management utility 
#.                    available on current system. Normally coincides with 
#.                    executable name, e.g.: 'apt-get', 'brew', 'dnf', 'pkg', 
#.                    'yum'. When the package manager is not recognized, this 
#.                    variable is empty.
#.                    When this variable is not empty, the package manager 
#.                    wrapper function, d__os_pkgmgr, is available.
#