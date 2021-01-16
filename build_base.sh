#!/bin/sh
set -e

. scripts/base.sh
. scripts/getfile.sh
. oscfg/ubuntu.sh
. oscfg/manjaro.sh

dodistro() {
	if [ -f "$1-$DATE.qcow2" ]; then
		return
	fi

	case $1 in
		manjaro-*)
			getfile manjaro-base.tar.xz 2135360bffec459c6cc029be5ad3c200f60c820bce1e2a6123e2702b474c64fc
			prepare manjaro-base
			manjaro_cfg "$1"
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
