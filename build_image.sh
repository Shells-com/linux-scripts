#!/bin/bash
set -e

. scripts/base.sh
. scripts/getfile.sh
. scripts/docker.sh
. oscfg/debian.sh
. oscfg/ubuntu.sh
. oscfg/manjaro.sh
. oscfg/gentoo.sh
. oscfg/fedora.sh

dodistro() {
	if [ -f "$1-$DATE.qcow2" ]; then
		return
	fi

	case $1 in
		manjaro-*)
			manjaro_distro "$1"
			;;
		gentoo-*)
			gentoo_distro "$1"
			;;
		debian-*)
			debian_distro "$1"
			;;
		ubuntu-*)
			ubuntu_distro "$1"
			;;
		fedora-*)
			fedora_distro "$1"
			;;
		*)
			echo "unsupported distro $1"
			;;
	esac

	finalize "$1"
}

if [ "$1" != x ]; then
	dodistro "$1"
else
	for foo in manjaro-base manjaro-desktop; do
		dodistro "$foo"
	done
fi
