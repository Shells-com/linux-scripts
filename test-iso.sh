#!/bin/bash
set -e

. scripts/base.sh
. scripts/getfile.sh
. scripts/qemu.sh

# run a given .qcow2 image in qemu using a configuration similar to shells

# need to take image in first arg. Let's create a 8GB image out of it.
if [ x"$1" = x ]; then
	echo "Usage: $0 file.iso"
	echo "Will start a qemu instance using this file. The qcow2 file will not be modified"
	exit 1
fi
if [ ! -f "$1" ]; then
	echo "Usage: $0 file.iso"
	echo "File $1 was not found"
	exit 1
fi

ISO="$(realpath $1)"
DISK="${ISO%.iso}_disk.qcow2"

if [ ! -f "$DISK" ]; then
	echo "Creating new $DISK image"
	"$QEMUIMG" create -f qcow2 "$DISK" 8G
fi

# launch qemu
doqemu "$DISK" \
	-drive id=cdrom0,if=none,format=raw,readonly=on,file="$ISO" \
	-device virtio-scsi-pci,id=scsi0 \
	-device scsi-cd,bus=scsi0.0,drive=cdrom0,bootindex=2

