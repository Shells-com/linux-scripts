#!/bin/sh

DLURL=https://download.opensuse.org
TWREPO=/tumbleweed/repo/oss
TWUPDATEREPO=/update/tumbleweed
LEAPREPO=/distribution/openSUSE-stable/repo/oss
LEAPUPDATEREPO=/update/openSUSE-stable

opensuse_distro() {
	# install distro using zypper into "$WORK"
	# $1 can be something like opensuse-tumbleweed-gnome or opensuse-leap-xfce
	# DISTRO is split out from $1, the 2nd 'parameter', i.e. tumbleweed or leap
	DISTRO=$(echo "$1" | cut -f2 -d-)
	# PATTERN is split out from $1, the 3rd 'parameter', i.e. gnome, kde, xfce
	local PATTERN=$(echo "$1" | cut -f3 -d-)

	case "$1" in
		*-dockerbase)
			create_empty
			docker_prepare "opensuse/${DISTRO}" latest

			# from this docker-taken opensuse image, generate a clean docker image using zypper
			echo 'nameserver 8.8.8.8' >"$WORK/etc/resolv.conf"
			echo 'nameserver 8.8.4.4' >>"$WORK/etc/resolv.conf"

			case "$DISTRO" in
				tumbleweed)
					REPO=$TWREPO
					UPDATEREPO=$TWUPDATEREPO
					;;
				leap)
					REPO=$LEAPREPO
					UPDATEREPO=$LEAPUPDATEREPO
					;;
				*)
					echo "Unsupported openSUSE distro ($DISTRO). Supported are tumbleweed and leap!"
					exit 1
					;;
			esac
			run zypper -n --root /new-root ar -f $DLURL$REPO repo-oss
			run zypper -n --root /new-root ar -f $DLURL$UPDATEREPO repo-oss-update
			mkdir "$WORK/new-root/dev" "$WORK/new-root/proc"
			mknod -m 600 "$WORK/new-root/dev/console" c 5 1
			mknod -m 666 "$WORK/new-root/dev/null" c 1 3
			mknod -m 666 "$WORK/new-root/dev/zero" c 1 5
			# following 2 lines needed for tumbleweed ca-certificates
			ln -s /proc/self/fd "$WORK/new-root/dev/fd"
			mount -t proc proc "$WORK/new-root/proc"
			run zypper -n --root /new-root --gpg-auto-import-keys ref
			run zypper -n --root /new-root install --download in-advance -t pattern base basesystem enhanced_base
			run zypper -n --root /new-root install --download in-advance ca-certificates ca-certificates-mozilla
			# complete the setup, install recommended things that were missed due to the minimal docker base
			run zypper -n --root /new/root install-new-recommends
			umount "$WORK/new-root/proc"

			echo "Generating opensuse-$DISTRO-dockerbase.tar.xz"
			tar cJf "opensuse-$DISTRO-dockerbase-$DATE.tar.xz" -C "$WORK/new-root" .

			# perform prepare here so finalize makes something good
			prepare "opensuse-$DISTRO-dockerbase-$DATE.tar.xz"
			;;
		*-base)
			create_empty
			ZYPPCMD="zypper -n --root $WORK"
			if [ "$DISTRO" == "tumbleweed" ]; then
				REPO=$TWREPO
				UPDATEREPO=$TWUPDATEREPO
			elif [ "$DISTRO" == "leap" ]; then
				REPO=$LEAPREPO
				UPDATEREPO=$LEAPUPDATEREPO
			else
				echo "Unsupported openSUSE distro ($DISTRO). Supported are tumbleweed and leap!"
				exit 1
			fi
			$ZYPPCMD ar -f $DLURL$REPO repo-oss
			$ZYPPCMD ar -f $DLURL$UPDATEREPO repo-oss-update
			$ZYPPCMD --gpg-auto-import-keys ref
			$ZYPPCMD install --download in-advance -t pattern enhanced_base x11
			$ZYPPCMD install --download in-advance NetworkManager spice-vdagent "group(wheel)"
			# we get a cloud-firstboot
			run systemctl mask systemd-firstboot
			# ensure networkmanager is enabled and not systemd-networkd
			run systemctl disable wicked
			run systemctl enable NetworkManager NetworkManager-wait-online
			run systemctl enable sshd
			# make sudo available without password (default for key auth)
			echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells" && chmod 440 "$WORK/etc/sudoers.d/01-shells"
			;;
		*-desktop)
			# for example: opensuse-leap-gnome-desktop
			opensuse_prepare "$DISTRO"

			# install what we need
			run zypper -n install --download in-advance --auto-agree-with-licenses -t pattern fonts x11 imaging multimedia sw_management $PATTERN
			run zypper -n install --download in-advance NetworkManager spice-vdagent

			# we get a cloud-firstboot
			run systemctl mask systemd-firstboot

			# ensure networkmanager is enabled and not systemd-networkd
			run systemctl disable wicked
			run systemctl enable NetworkManager NetworkManager-wait-online
			run systemctl enable sshd

			# make sudo available without password (default for key auth)
			echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells" && chmod 440 "$WORK/etc/sudoers.d/01-shells"

			opensuse_cfg "$DISTRO" "$PATTERN"
			;;
		*)
			# start from base
			if [ ! -f "opensuse-$DISTRO-base.qcow2" ]; then
				dodistro "opensuse-$DISTRO-base"
			fi
			prepare opensuse-$DISTRO-base
			ZYPPCMD="zypper -n --root $WORK"
			$ZYPPCMD --gpg-auto-import-keys ref
			$ZYPPCMD dup
			$ZYPPCMD install --download in-advance -t pattern $PATTERN

			opensuse_cfg "$DISTRO" "$PATTERN"
			;;
	esac
}

opensuse_prepare() {
	# download opensuse image, either tumbleweed or leap
	case "$1" in
		tumbleweed)
			getfile opensuse-tumbleweed-dockerbase-20210403.tar.xz e06f5971b490b50e70ffbdef94ce7dc4a3e4c0076fbd9b098900a9b30caa3cef
			prepare opensuse-tumbleweed-dockerbase-20210403.tar.xz
			;;
		leap)
			getfile opensuse-leap-dockerbase-20210403.tar.xz 3660e147c0b786247e60395596f1460574c08b2ed410a8a01b93cbea7c5767df
			prepare opensuse-leap-dockerbase-20210403.tar.xz
			;;
		*)
			echo "Unsupported openSUSE distro ($DISTRO). Supported are tumbleweed and leap!"
			exit 1
			;;
	esac

	# configure resolver
	echo 'nameserver 8.8.8.8' >"$WORK/run/netconfig/resolv.conf"
	echo 'nameserver 8.8.4.4' >>"$WORK/run/netconfig/resolv.conf"

	# refresh/update
	run zypper -n ref
	run zypper -n dup
}

opensuse_cfg() {
	local DISTRO=$1
	local DESKTOP=$2
	if [ "$DESKTOP" == "gnome" ]; then
		cat >>"$WORK/usr/share/glib-2.0/schemas/30-Shells.gschema.override" <<EOF
# disable gnome screen blanking, logout & power management
[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/gnome/desktop/lockdown]
disable-lock-screen=true
disable-log-out=true

[org/gnome/desktop/session]
idle-delay=uint32 0
EOF
		run /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas
		cat > "$WORK/etc/pam.d/gnomesu-pam" <<EOF
#%PAM-1.0
auth	 sufficient	pam_wheel.so trust use_uid
auth     sufficient     pam_rootok.so
auth     include        common-auth
account  sufficient     pam_rootok.so
account  include        common-account
password include        common-password
session  include        common-session
session  optional       pam_keyinit.so force revoke
session  optional       pam_xauth.so
EOF
	elif [ "$DESKTOP" == "kde" ]; then
		mkdir -p "$WORK/etc/skel/.config"
		cat >> "$WORK/etc/skel/.config/kdeglobals" <<EOF
[KDE Action Restrictions]
action/lock_screen=false
logout=false
action/start_new_session=false
action/switch_user=false
EOF

		cat >"$WORK/etc/skel/.config/kscreenlockerrc" <<EOF
[Daemon]
Autolock=false
EOF

cat >"$WORK/etc/skel/.config/kdesurc" <<EOF
[super-user-command]
super-user-command=sudo
EOF

	fi

	# add firstrun
	add_firstrun NetworkManager-wait-online.service
	do_linux_config
}
