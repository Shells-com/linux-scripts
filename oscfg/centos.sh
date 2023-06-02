#!/bin/sh

centos_distro() {
	# centos-xxx

	case "$1" in
		*-yumbase)
			# centos-7.9.2009-yumbase
			local VERSION="$(echo "$1" | cut -f2 -d-)"
			# grab min from docker
			docker_prepare centos "$VERSION"

			# we might be good with this, but actually not.
			# Let's use this base docker centos image to build a proper centos image.

			echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
			echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"
			mkdir "$WORK/new-root"
			run rpm --root /new-root --initdb
			run yumdownloader --destdir=/var/tmp centos-release
			run rpm --root /new-root -ivh --nodeps /var/tmp/centos-release*rpm
			run yum --installroot=/new-root update
			run yum -y --installroot=/new-root install @core
			mkdir -p "$WORK/new-root/dev"
			for foo in tty-c-5-0 console-c-5-1 zero-c-1-5 ptmx-c-5-2 fuse-c-10-229 random-c-1-8 urandom-c-1-9; do
				mknod -m 666 "$WORK/new-root/dev/"${foo//-/ }
			done
			chroot "$WORK/new-root" yum clean all

			echo "Generating centos-$VERSION-yumbase.tar.xz"
			tar cJf "centos-$VERSION-yumbase-$DATE.tar.xz" -C "$WORK/new-root" .

			# perform prepare here so finalize makes something good
			prepare "centos-$VERSION-yumbase-$DATE.tar.xz"
			;;
		*-dnfbase)
			local VERSION="$(echo "$1" | cut -f2 -d-)"
			# grab min from docker
			docker_prepare centos "$VERSION"

			# we might be good with this, but actually not.
			# Let's use this base docker centos image to build a proper centos image.

			echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
			echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"
			run dnf -y --installroot=/new-root --releasever="$VERSION" group install minimal-environment
			chroot "$WORK/new-root" dnf clean all

			echo "Generating centos-$VERSION-dnfbase.tar.xz"
			tar cJf "centos-$VERSION-dnfbase-$DATE.tar.xz" -C "$WORK/new-root" .

			# perform prepare here so finalize makes something good
			prepare "centos-$VERSION-dnfbase-$DATE.tar.xz"
			;;
		*)
			# use latest pre-build dnfbase image
			# centos-7.9-dnfbase
			local VERSION="$(echo "$1" | cut -f2 -d-)"

			case $VERSION in
			7.9.2009)
				getfile centos-7.9.2009-yumbase-20230603.tar.xz 7fabf1472b65ee4768945a966d8baf1bf48ceb365a4c51d60c83176088c865e7
				prepare centos-7.9.2009-yumbase-20230603.tar.xz
				;;
			*)
				echo "unsupported centos version: $VERSION"
				exit 1
			esac
			centos_cfg "$1"
			;;
	esac
}

centos_cfg() {
	local VERSION="$(echo "$1" | cut -f2 -d-)"
	local GROUP="$(echo "$1" | cut -f3- -d-)"
	local DNF=dnf
	case $VERSION in
		7*)
			DNF=yum
			echo 'NETWORKING=yes' >"$WORK/etc/sysconfig/network"
			;;
	esac

	echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
	echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"

	# make sudo available without password (default for key auth)
	#mkdir -p "$WORK/etc/sudoers.d"
	echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells"
	chmod 440 "$WORK/etc/sudoers.d/01-shells"

	if [ $DNF == dnf ]; then
		run $DNF upgrade --refresh -y
	else
		run $DNF upgrade -y
	fi

	case $GROUP in
		server)
			run $DNF -y install @server-product
			# setup systemd to boot to the right runlevel
			echo -n "Setting default runlevel to multiuser text mode"
			rm -f "${WORK}/etc/systemd/system/default.target"
			ln -s /lib/systemd/system/multi-user.target "${WORK}/etc/systemd/system/default.target"
			echo .
			;;
		*)
			# perform dnf install
			# see for groups: https://docs.centosproject.org/en-US/quick-docs/switching-desktop-environments/
			# example: custom-environment (default centos command line) → centos-33-custom
			run $DNF -y install "@${GROUP}-environment"
			;;
	esac

	# install qemu agent & NetworkManager
	run $DNF install -y qemu-guest-agent NetworkManager

	case "$GROUP" in
		*-desktop|workstation-product|developer-workstation)
			run $DNF install -y spice-vdagent spice-webdavd
			run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
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
	do_linux_config

	run $DNF clean all
}
