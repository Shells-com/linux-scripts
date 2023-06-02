#!/bin/bash
set -e

KVER_FULL="$(uname -r)" # 5.10.172-shells
KVER="${KVER_FULL/-shells/}"
MODPATH="$(realpath "/lib/modules/$KVER_FULL")"

if [ x"$KVER_FULL" = x"$KVER" ]; then
	echo "Error: not a shells kernel: $KVER_FULL"
	exit 1
fi

if [ "$(cat /proc/mounts | grep -c "$MODPATH")" -gt 0 ]; then
	echo "$MODPATH is a mount, getting a local copy..."
	mkdir "$MODPATH.$$"
	cp -ar "$MODPATH"/* "$MODPATH.$$"
	umount -l $MODPATH
	rmdir $MODPATH
	mv "$MODPATH.$$" "$MODPATH"
fi

if [ -w /usr/src ]; then
	echo "Will install kernel in /usr/src"
	cd /usr/src
fi

if [ ! -d "linux-$KVER_FULL" ]; then
	if [ ! -f "linux-$KVER.tar.xz" ]; then
		wget "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KVER.tar.xz" -O "linux-$KVER.tar.xz"
	fi
	tar xf "linux-$KVER.tar.xz"
	mv "linux-$KVER" "linux-$KVER_FULL"
fi

cd "linux-$KVER_FULL"

if [ ! -f /sys/kernel/kheaders.tar.xz ]; then
	modprobe kheaders
fi
tar xf /sys/kernel/kheaders.tar.xz

apt-get install build-essential flex bison libssl-dev libelf-dev
./scripts/extract-ikconfig "/lib/modules/${KVER_FULL}/kernel/kernel/configs.ko" >.config
make prepare
make modules_prepare

echo "Setting up symlink..."
ln -snf "$PWD" $MODPATH/build
