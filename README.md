# Linux scripts for Shells™

This repository includes scripts used for Linux installations on Shells™.

# firstrun.sh

This script is installed on shells instances as /.firstrun.sh and rc.local is
modified to run it if found. The script will delete itself after completion
ensuring it is not run more than once.

This script has a number of responsibilites:

* Re-generate /etc/machine-id
* Setup hostname
* Create any needed user, setup password and SSH keys

