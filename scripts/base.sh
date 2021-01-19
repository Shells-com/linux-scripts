#!/bin/sh

if [ -f "/shells/software/qemu/bin" ]; then
	export PATH="/shells/software/qemu/bin:$PATH"
fi
QEMUIMG="$(which qemu-img)"
QEMUNBD="$(which qemu-nbd)"

# various settings
NBD="/dev/nbd2"
RESDIR="$PWD/res"
SCRIPTSDIR="$PWD/scripts"
TMPIMG="work$$.qcow2"
API_PREFIX="https://ws.atonline.com/_special/rest/"

if [ -d /shells ]; then
	WORK="/shells/work"
else
	WORK="/tmp/shells-work$$"
fi

if [ x"$USER" = x"root" ]; then
	modprobe nbd
fi

DATE=$(date +'%Y%m%d')

create_empty() {
	"$QEMUIMG" create -f qcow2 "$TMPIMG" 8G
	"$QEMUNBD" -c "$NBD" -f qcow2 "$TMPIMG"
	parted --script -a optimal -- "$NBD" mklabel msdos mkpart primary ext4 1MiB -2048s
	mkfs.ext4 -L root "$NBD"p1
	mkdir "$WORK"
	mount "$NBD"p1 "$WORK"
}

prepare() {
	if [ -d "$WORK" ]; then
		umount "$WORK/proc" "$WORK/sys" "$WORK/dev" || umount -l "$WORK/proc" "$WORK/sys" "$WORK/dev" || true
		umount "$WORK" || true
		"$QEMUNBD" -d "$NBD" || true
		# should be empty after umount
		rmdir "$WORK"
	fi

	if [ x"$1" != x ]; then
		echo '*****'
		echo "** Preparing new environment based on $1"
		echo '*****'

		if [ -f "$1".tar.xz ]; then
			create_empty
			echo "Extracting..."
			tar x -C "$WORK" -f "$1".tar.xz
		elif [ -f "$1" ]; then
			# let tar determine the right format
			create_empty
			echo "Extracting..."
			tar x -C "$WORK" -f "$1"
		elif [ -f "$1".qcow2 ]; then
			cp -v "$1".qcow2 "$TMPIMG"

			# mount
			mkdir "$WORK"
			"$QEMUNBD" -c "$NBD" -f qcow2 "$TMPIMG"
			sleep 1
			mount "$NBD"p1 "$WORK"
		else
			echo "Could not find base for $1"
		fi

		# mount proc, sys, dev
		mount -t proc proc "$WORK/proc"
		mount -t sysfs sys "$WORK/sys"
		mount -o bind /dev "$WORK/dev"

		# prevent service activation (will be deleted by finalize)
		echo -e '#!/bin/sh\nexit 101' >"$WORK/usr/sbin/policy-rc.d"
		chmod +x "$WORK/usr/sbin/policy-rc.d"
	else
		echo '*****'
		echo "** Preparing new environment"
		echo '*****'

		create_empty
	fi
}

run() {
	chroot "$WORK" "$@"
}

finalize() {
	echo '*****'
	echo "** Generating disk image $1-$DATE"
	echo '*****'
	rm -f "$WORK/usr/sbin/policy-rc.d"
	echo localhost >"$WORK/etc/hostname"

	# making sure we have no remaining process
	fuser --kill --ismountpoint --mount "$WORK" && sleep 1 || true

	umount "$WORK/proc" "$WORK/sys" "$WORK/dev" || umount -l "$WORK/proc" "$WORK/sys" "$WORK/dev" || true

	echo "Syncing..."
	umount "$WORK"
	"$QEMUNBD" -d "$NBD"

	echo "Converting image..."
	# somehow qemuimg cannot output to stdout
	"$QEMUIMG" convert -f qcow2 -O raw "work$$.qcow2" "$1-$DATE.raw"
	rm -f "work$$.qcow2"

	if [ ! -d rbdconv ]; then
		# grab rbdconv
		git clone https://github.com/Shells-com/rbdconv.git
	fi
	php rbdconv/raw-to-rbd.php "$1-$DATE.raw" | xz -z -9 -T 16 -v >"$1-$DATE.shells"
	rm -f "$1-$DATE.raw"

	# complete, list the file
	ls -la "$1-$DATE.shells"
}

add_firstrun() {
	# add first run process before sysinit but after network
	cp "$SCRIPTSDIR/firstrun.sh" "$WORK/.firstrun.sh"
	chmod +x "$WORK/.firstrun.sh"

	local AFTER="$1"
	if [ x"$AFTER" = x ]; then
		# can also be NetworkManager-wait-online.service or systemd-networkd-wait-online.service
		AFTER="network-online.target"
	fi

	if [ -d "$WORK/lib/systemd/system" ]; then
		# systemd method
		cat >"$WORK/lib/systemd/system/cloud-firstrun.service" <<EOF
[Unit]
Description=Cloud firstrun handler
ConditionFileIsExecutable=/.firstrun.sh
After=$AFTER
Wants=$AFTER
Before=network-online.target
Before=sshd-keygen.service
Before=sshd.service
Before=systemd-user-sessions.service

[Service]
Type=oneshot
ExecStart=/.firstrun.sh start
TimeoutSec=0
RemainAfterExit=yes
StandardOutput=journal+console

[Install]
WantedBy=sysinit.target
EOF
		# enable
		run systemctl enable cloud-firstrun
	fi
}
