#!/bin/sh

fedora_distro() {
	# fedora-version-xxx
	# let's grab the version (33)
	local VERSION="$(echo "$1" | cut -f2 -d-)"

	case "$1" in
		*-dnfbase)
			# grab min from docker
			docker_prepare fedora "$VERSION"

			# we might be good with this, but actually not.
			# Let's use this base docker fedora image to build a base vanilla fedora image.

			echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
			echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"
			run dnf -y --installroot=/new-root --releasever="$VERSION" group install minimal-environment
			chroot "$WORK/new-root" dnf clean all

			echo "Generating fedora-$VERSION-dnfbase.tar.xz"
			tar cJf "fedora-$VERSION-dnfbase-$DATE.tar.xz" -C "$WORK/new-root" .

			# perform prepare here so finalize makes something good
			prepare "fedora-$VERSION-dnfbase-$DATE.tar.xz"
			;;
		*)
			# use latest pre-build dnfbase image
			getfile fedora-33-dnfbase-20210121.tar.xz 77fc043f380fcae18d0ba67b09fa56fe8aca46e38f452262acfdaf39a4a4f110
			prepare fedora-33-dnfbase-20210121.tar.xz
			fedora_cfg "$1"
			;;
	esac
}

fedora_cfg() {
	local VERSION="$(echo "$1" | cut -f2 -d-)"
	local GROUP="$(echo "$1" | cut -f3- -d-)"

	echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
	echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"

	run dnf upgrade --refresh -y

	case $GROUP in
		server)
			# based on https://pagure.io/fedora-kickstarts/blob/main/f/fedora-disk-server.ks
			run dnf -y install @server-product @standard @core
			# add @headless-management to install cockpit
			# setup systemd to boot to the right runlevel
			echo -n "Setting default runlevel to multiuser text mode"
			rm -f "${WORK}/etc/systemd/system/default.target"
			ln -s /lib/systemd/system/multi-user.target "${WORK}/etc/systemd/system/default.target"
			echo .
		*)
			# perform dnf install
			# see for groups: https://docs.fedoraproject.org/en-US/quick-docs/switching-desktop-environments/
			# example: custom-environment (default fedora command line) → fedora-33-custom
			run dnf -y install @standard "@${GROUP}-environment"
			;;
	esac

	# install qemu agent & NetworkManager
	run dnf install -y qemu-guest-agent NetworkManager

	case "$GROUP" in
		*-desktop|workstation-product|developer-workstation)
			run dnf install -y spice-vdagent spice-webdavd 
	esac

	# remove ssh key files if any
	rm -f "$WORK/etc/ssh"/ssh_host_* || true

	# add shells-helper to /etc/skel
	if [ ! -f "$WORK/etc/skel/.bin/shells-helper" ]; then
		mkdir -p "$WORK/etc/skel/.bin"
		local O="$PWD"
		cd "$WORK/etc/skel/.bin"
		curl -s https://raw.githubusercontent.com/KarpelesLab/make-go/master/get.sh | /bin/sh -s shells-helper
		cd "$O"
	fi

	# new .xprofile file
	echo "#!/bin/sh" >"$WORK/etc/skel/.xprofile"
	echo "xset s off" >>"$WORK/etc/skel/.xprofile"
	echo 'while true; do $HOME/.bin/shells-helper >/dev/null 2>&1; sleep 30; done &' >>"$WORK/etc/skel/.xprofile"
	echo >>"$WORK/etc/skel/.xprofile"
	chmod +x "$WORK/etc/skel/.xprofile"

	# add firstrun
	add_firstrun NetworkManager-wait-online.service

	run dnf clean all
}
