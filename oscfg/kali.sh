#!/bin/sh

kali_distro() {
	docker_prepare "kalilinux/kali-last-release" latest
	kali_cfg "$1"
}

# configure an existing kali linux install
kali_cfg() {
	# make sure / is 0755
	chmod 0755 "${WORK}"

	# add some resolvers
	echo "nameserver 8.8.8.8" >>"$WORK/etc/resolv.conf"
	echo "nameserver 8.8.4.4" >>"$WORK/etc/resolv.conf"

	run apt update
	DEBIAN_FRONTEND=noninteractive run apt full-upgrade -y
	DEBIAN_FRONTEND=noninteractive run apt-get -y install wget curl net-tools rsync openssh-server sudo psmisc

	# make sudo available without password (default for key auth)
	echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells" & chmod 440 "$WORK/etc/sudoers.d/01-shells"

	# https://www.kali.org/docs/general-use/metapackages/

	case "$1" in
		kali-ssh-server)
			DEBIAN_FRONTEND=noninteractive run apt-get -y install kali-linux-headless
			;;
		kali-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get -y install kali-linux-default
			;;
		kali-xfce-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get -y install kali-desktop-xfce
			;;
		*)
			echo "invalid kali image"
			exit 1
			;;
	esac

	# add shells-helper to /etc/skel
	if [ ! -f "$WORK/etc/skel/.bin/shells-helper" ]; then
		mkdir -p "$WORK/etc/skel/.bin"
		local O="$PWD"
		cd "$WORK/etc/skel/.bin"
		curl -s https://raw.githubusercontent.com/KarpelesLab/make-go/master/get.sh | /bin/sh -s shells-helper
		cd "$O"
	fi

	if [ ! -f "$WORK/etc/localtime" ]; then
		ln -sf "/usr/share/zoneinfo/UTC" "$WORK/etc/localtime"
	fi

	run apt-get clean

	add_firstrun NetworkManager-wait-online.service
	do_linux_config

	# new .xprofile file
	echo "#!/bin/sh" >"$WORK/etc/skel/.xprofile"
	echo "xset s off" >>"$WORK/etc/skel/.xprofile"
	echo 'while true; do $HOME/.bin/shells-helper >/dev/null 2>&1; sleep 30; done &' >>"$WORK/etc/skel/.xprofile"
	echo >>"$WORK/etc/skel/.xprofile"
	chmod +x "$WORK/etc/skel/.xprofile"
}
