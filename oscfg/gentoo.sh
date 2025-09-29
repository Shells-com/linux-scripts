#!/bin/sh

gentoo_distro() {
	gentoo_cfg "$1"
}

gentoo_prepare() {
	# fetch stage3 for the specified config
	local STAGE3="$(curl -s -L https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/latest-stage3.txt | grep -v '^#' | grep "stage3-amd64-$1" | head -n 1 | awk '{ print $1 }')"
	local STAGE3_NAME="$(basename "$STAGE3")"
	if [ ! -f "$STAGE3_NAME" ]; then
		echo "Downloading $STAGE3_NAME ..."
		curl -# -L -o "${STAGE3_NAME}~" "https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/$STAGE3"
		mv -f "${STAGE3_NAME}~" "${STAGE3_NAME}"
	fi

	prepare "$STAGE3_NAME"
	echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
	echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"
	run emerge-webrsync
}

gentoo_cfg() {
	# sync emerge (can take some time)
	case "$1" in
		gentoo-xfce-desktop)
			gentoo_prepare desktop-openrc
			#run eselect profile set default/linux/amd64/23.0/desktop

			echo "INPUT_DEVICES=\"libinput synaptics\"" >>"$WORK/etc/portage/make.conf"
			echo "VIDEO_CARDS=\"qxl\"" >>"$WORK/etc/portage/make.conf"

			run emerge -j"$(nproc)" app-admin/sudo net-misc/openssh
			run emerge -j"$(nproc)" xfce-base/xfce4-meta x11-terms/xfce4-terminal
			run emerge -j"$(nproc)" xfce-extra/xfce4-pulseaudio-plugin xfce-extra/xfce4-taskmanager x11-themes/xfwm4-themes app-office/orage app-editors/mousepad xfce-extra/xfce4-power-manager x11-terms/xfce4-terminal xfce-base/thunar
			run emerge -j"$(nproc)" x11-misc/slim

			sed -i -e 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="slim"/' "$WORK/etc/conf.d/xdm"
			echo XSESSION=\"Xfce4\" > "$WORK/etc/env.d/90xsession"

			run rc-update add dbus default
			run rc-update add xdm default
			;;
		gentoo-ssh-server)
			gentoo_prepare openrc
			run emerge -j"$(nproc)" app-admin/sudo net-misc/openssh

			run rc-update add ssh default
			;;
	esac

	# make sudo available without password (default for key auth)
	echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells" & chmod 440 "$WORK/etc/sudoers.d/01-shells"
}
