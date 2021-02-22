#!/bin/bash
set -e

. scripts/base.sh
. scripts/getfile.sh
. scripts/qemu.sh

# run a given .qcow2 image in qemu using a configuration similar to shells

# need to take image in first arg. Let's create a 160GB image out of it.
if [ x"$1" = x ]; then
	echo "Usage: $0 file.qcow2 [kernel commandline options]"
	echo "Will start a qemu instance using this file. The qcow2 file will not be modified"
	exit 1
fi
if [ ! -f "$1" ]; then
	echo "Usage: $0 file.qcow2 [kernel commandline options]"
	echo "File $1 was not found"
	exit 1
fi

IMGFILE="$(realpath $1)"
OVERLAY="${IMGFILE%.qcow2}_test.qcow2"

if [ x"$OVERLAY" = x"$IMGFILE" ]; then
	OVERLAY="${OVERLAY}_test.qcow2"
fi

if [ ! -f "$OVERLAY" ]; then
	echo "Creating new $OVERLAY overlay"
	"$QEMUIMG" create -f qcow2 -b "$IMGFILE" -F qcow2 "$OVERLAY" 160G
fi

# launch qemu
qemukernel "$OVERLAY" "$2"

