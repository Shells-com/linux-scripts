#!/bin/sh

WORK="/shells/work"

QEMU="/shells/software/qemu"
QEMUIMG="${QEMU}/bin/qemu-img"
QEMUNBD="${QEMU}/bin/qemu-nbd"
NBD="/dev/nbd4"
RESDIR="$PWD/res"
RESDIR="$PWD/scripts"
TMPIMG="work$$.qcow2"
API_PREFIX="https://ws.atonline.com/_special/rest/"

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
	umount "$WORK/proc" "$WORK/sys" "$WORK/dev" || umount -l "$WORK/proc" "$WORK/sys" "$WORK/dev" || true

	echo "Syncing..."
	umount "$WORK" || umount -l "$WORK"
	"$QEMUNBD" -d "$NBD"

	echo "Compressing..."
	"$QEMUIMG" convert -f qcow2 -O qcow2 -c "work$$.qcow2" "$1-$DATE.qcow2"
	rm -f "work$$.qcow2"
	"$QEMUIMG" info "$1-$DATE.qcow2"
}

add_firstrun() {
	# add first run process before sysinit but after network
	cp "$SCRIPTSDIR/firstrun.sh" "$WORK/.firstrun.sh"
	chmod +x "$WORK/.firstrun.sh"

	if [ -d "$WORK/lib/systemd/system" ]; then
		# systemd method
		cat >"$WORK/lib/systemd/system/cloud-firstrun.service" <<EOF
[Unit]
Description=Cloud firstrun handler
ConditionFileIsExecutable=/.firstrun.sh
After=systemd-networkd-wait-online.service
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
