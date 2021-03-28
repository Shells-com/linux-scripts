#!/bin/sh

debian_distro() {
	# debian-suite-xxx
	# let's grab the suite (focal)
	local SUITE="$(echo "$1" | cut -f2 -d-)"

	case "$1" in
		*-base)
			# for example: debian-buster-base
			create_empty

			debootstrap --include=wget,curl,net-tools,rsync,openssh-server,sudo $SUITE "$WORK"

			# make sudo available without password (default for key auth)
			sed -i -r -e 's/^(%sudo.*)ALL/\1NOPASSWD: ALL/' "$WORK/etc/sudoers"

			# build sources.list (add backports?)
			# see: https://wiki.debian.org/SourcesList
			cat >"$WORK/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian $SUITE main contrib non-free
deb-src http://deb.debian.org/debian $SUITE main contrib non-free

deb http://deb.debian.org/debian-security/ $SUITE/updates main contrib non-free
deb-src http://deb.debian.org/debian-security/ $SUITE/updates main contrib non-free

deb http://deb.debian.org/debian $SUITE-updates main contrib non-free
deb-src http://deb.debian.org/debian $SUITE-updates main contrib non-free
EOF

			echo 'LANG=en_US.UTF-8' >"$WORK/etc/default/locale"
			
			# perform apt get update (download cache)
			run apt-get update
			DEBIAN_FRONTEND=noninteractive run apt-get dist-upgrade -y
			DEBIAN_FRONTEND=noninteractive run apt-get install -y locales-all python3-distro-info kmod qemu-guest-agent
			;;
		*)
			# start from base
			if [ ! -f "debian-$SUITE-base.qcow2" ]; then
				# base is missing, build it
				dodistro "debian-$SUITE-base"
			fi

			prepare "debian-$SUITE-base"
			debian_cfg "$1"
			;;
	esac
}

# configure an existing debian install
debian_cfg() {
	# make sure we have i386 enabled
	run dpkg --add-architecture i386 || true
	run apt-get update

	DEBIAN_FRONTEND=noninteractive run apt-get dist-upgrade -y

	# get tasksel value
	local TASKSEL="$(echo "$1" | cut -d- -f3-)"
	DEBIAN_FRONTEND=noninteractive run apt-get install -y "task-$TASKSEL"

	# make sure we have qemu-guest-agent always
	DEBIAN_FRONTEND=noninteractive run apt-get install -y qemu-guest-agent

	# ensure guest tools
	case "$1" in
		*desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y xserver-xorg-video-qxl spice-vdagent spice-webdavd cryptsetup wine64 wine32 git bash-completion
			run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
			;;
	esac

	# if gnome
	case "$1" in
		debian-*-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnome-software guake dconf-cli
			DEBIAN_FRONTEND=noninteractive run apt-get install -y flatpak gnome-software-plugin-flatpak
			run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
			run killall gnome-software && run apt update && run appstreamcli refresh --force
			run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
			;;
	esac

	# network config based on netplan
	DEBIAN_FRONTEND=noninteractive run apt-get install -y netplan.io networkd-dispatcher

	# fix network config
	cat >"$WORK/etc/netplan/config.yaml" <<EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      match:
        name: e*
      dhcp4: true
EOF

	# remove ssh key files if any
	rm -f "$WORK/etc/ssh"/ssh_host_* || true

	# disable screensaver on lxqt
	if [ -f "$WORK/etc/xdg/autostart/lxqt-xscreensaver-autostart.desktop" ]; then
		rm -f "$WORK/etc/xdg/autostart/lxqt-xscreensaver-autostart.desktop"
	fi

	# add shells-helper to /etc/skel
	if [ ! -f "$WORK/etc/skel/.bin/shells-helper" ]; then
		mkdir -p "$WORK/etc/skel/.bin"
		local O="$PWD"
		cd "$WORK/etc/skel/.bin"
		curl -s https://raw.githubusercontent.com/KarpelesLab/make-go/master/get.sh | /bin/sh -s shells-helper
		cd "$O"
	fi

	# new .profile file
	echo "#!/bin/sh" >"$WORK/etc/skel/.profile"
	echo "xset s off" >>"$WORK/etc/skel/.profile"
	echo 'while true; do $HOME/.bin/shells-helper >/dev/null 2>&1; sleep 30; done &' >>"$WORK/etc/skel/.profile"
	echo >>"$WORK/etc/skel/.profile"
	chmod +x "$WORK/etc/skel/.profile"

	# add firstrun
	add_firstrun NetworkManager-wait-online.service
	do_linux_config

	# create script to disable gnome screensaver stuff
	if [ -f "$WORK/usr/bin/gsettings" ]; then
		if [ -d "$WORK/usr/share/backgrounds" ]; then
			# install wallpaper
			cp "$RESDIR/shells_bg.png" "$WORK/usr/share/backgrounds/shells_bg.png"
		fi

		if [ -d "$WORK/usr/share/themes/" ]; then
			# download theme
			unzip -o "$RESDIR/Material-Black-Blueberry-3.36_1.8.9.zip" -d "$WORK/usr/share/themes/"
		fi

		# setup wine mime type
		mkdir -p "$WORK/etc/skel/.local/share/applications"
		cat >"$WORK/etc/skel/.local/share/applications/wine.desktop" <<EOF
[Desktop Entry]
Name=Wine
Comment=Run Windows Applications
Exec=wine
Terminal=false
Icon=wine
Type=Application
Categories=Utility;
NoDisplay=true
EOF
		cat >"$WORK/etc/skel/.local/share/applications/mimeapps.list" <<EOF
[Default Applications]
application/x-ms-dos-executable=wine.desktop
EOF

		mkdir -p "$WORK/etc/dconf/profile"

		cat >>"$WORK/etc/dconf/profile/user" <<EOF
service-db:keyfile/user

EOF

		mkdir -p "$WORK/etc/skel/.config/dconf"
		run dconf dump / > "$WORK/etc/skel/.config/dconf/user.txt"
		
		cat >>"$WORK/etc/skel/.config/dconf/user.txt" <<EOF
# disable gnome screen blanking, logout & power management
[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/gnome/desktop/lockdown]
disable-lock-screen=true
disable-log-out=true

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/background]
picture-uri='file:////usr/share/backgrounds/shells_bg.png'

[org/gnome/desktop/interface]
gtk-theme='Material-Black-Blueberry-3.36'
icon-theme='Material-Black-Blueberry-3.36'

EOF
	fi

	# cleanup apt
	run apt-get clean
}
