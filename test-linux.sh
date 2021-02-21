#!/bin/sh

. scripts/base.sh
. scripts/getfile.sh
. scripts/qemu.sh

# run a given .qcow2 image in qemu using a configuration similar to shells

# need to take image in first arg. Let's create a 160GB image out of it.
if [ x"$1" = x ]; then
	echo "Usage: $0 file.qcow2"
	echo "Will start a qemu instance using this file. The qcow2 file will not be modified"
	exit 1
fi
if [ ! -f "$1" ]; then
	echo "Usage: $0 file.qcow2"
	echo "File $1 was not found"
	exit 1
fi

# always create (overwrite) the image
"$QEMUIMG" create -f qcow2 -b "$(realpath $1)" -F qcow2 "res/test.qcow2" 160G

# launch qemu
qemukernel res/test.qcow2

