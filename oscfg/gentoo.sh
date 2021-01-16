#!/bin/sh

gentoo_distro() {
	# fetch stage3
	local STAGE3="$(curl -s -L https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/latest-stage3.txt | grep -v '^#' | head -n 1 | awk '{ print $1 }')"
	local STAGE3_NAME="$(basename "$STAGE3")"
	echo "Donwloading $STAGE3_NAME ..."
	curl -# -o "$STAGE3_NAME" "https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/$STAGE3"

	prepare "$STAGE3_NAME"
	gentoo_cfg "$1"
}

gentoo_cfg() {
	# sync emerge (can take some time)
	run emerge-webrsync

	case "$1" in
		gentoo-xfce-desktop)
			run eselect profile set default/linux/amd64/17.1/desktop

			echo "INPUT_DEVICES=\"libinput synaptics\"" >>"$WORK/etc/portage/make.conf"
			echo "VIDEO_CARDS=\"qxl\"" >>"$WORK/etc/portage/make.conf"

			run emerge -j`nproc` xfce-base/xfce4-meta x11-terms/xfce4-terminal
			run emerge -j`nproc` xfce-extra/xfce4-pulseaudio-plugin xfce-extra/xfce4-taskmanager x11-themes/xfwm4-themes app-office/orage app-editors/mousepad xfce-extra/xfce4-power-manager x11-terms/xfce4-terminal xfce-base/thunar
			run emerge -j`nproc` x11-misc/slim

			sed -i -e 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="slim"/' "$WORK/etc/conf.d/xdm"
			echo XSESSION=\"Xfce4\" > "$WORK/etc/env.d/90xsession"

			run rc-update add dbus default
			run rc-update add xdm default
			;;
	esac
}
