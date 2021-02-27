#!/bin/sh


ubuntu_distro() {
	# ubuntu-suite-xxx
	# let's grab the suite (focal)
	local SUITE="$(echo "$1" | cut -f2 -d-)"

	case "$1" in
		*-base)
			# for example: ubuntu-focal-base
			create_empty

			debootstrap --include=wget,curl,net-tools,rsync,openssh-server,sudo $SUITE "$WORK"

			# make sudo available without password (default for key auth)
			sed -i -r -e 's/^(%sudo.*)ALL/\1NOPASSWD: ALL/' "$WORK/etc/sudoers"

			# build sources.list
			cat >"$WORK/etc/apt/sources.list" <<EOF
deb http://archive.ubuntu.com/ubuntu $SUITE main restricted universe multiverse

###### Ubuntu Update Repos
deb http://archive.ubuntu.com/ubuntu/ $SUITE-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $SUITE-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $SUITE-backports main restricted universe multiverse
EOF

			echo 'LANG=en_US.UTF-8' >"$WORK/etc/default/locale"

			# perform apt get update (download cache)
			run apt-get update
			DEBIAN_FRONTEND=noninteractive run apt-get dist-upgrade -y
			DEBIAN_FRONTEND=noninteractive run apt-get install -y locales-all ubuntu-release-upgrader-core python3-distro-info kmod qemu-guest-agent
			;;
		*)
			# start from base
			if [ ! -f "ubuntu-$SUITE-base.qcow2" ]; then
				# base is missing, build it
				dodistro "ubuntu-$SUITE-base"
			fi

			prepare "ubuntu-$SUITE-base"
			ubuntu_cfg "$1"
			;;
	esac
}

# configure an existing ubuntu install
ubuntu_cfg() {
	# make sure we have i386 enabled
	run dpkg --add-architecture i386 || true
	run apt-get update

	DEBIAN_FRONTEND=noninteractive run apt-get dist-upgrade -y

	# get tasksel value
	local TASKSEL="$(echo "$1" | cut -d- -f3-)"

	case "$TASKSEL" in
		kde-neon-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnupg
			curl -s https://archive.neon.kde.org/public.key | run apt-key add -
			echo "deb http://archive.neon.kde.org/user focal main" >"$WORK/etc/apt/sources.list.d/kde-neon.list"
			run apt-get update
			DEBIAN_FRONTEND=noninteractive run apt-get install -y neon-desktop
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

			;;
		*)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y "$TASKSEL"^
			;;
	esac
	
	case "$1" in
		ubuntu-*-kubuntu-desktop)
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

	esac

	# ensure guest tools
	case "$1" in
		*desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y xserver-xorg-video-qxl spice-vdagent spice-webdavd qemu-guest-agent ecryptfs-utils cryptsetup wine64 wine32 git
			;;
	esac

	# if gnome
	case "$1" in
		ubuntu-*-ubuntu-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnome-software guake
			;;
	esac

	DEBIAN_FRONTEND=noninteractive run apt-get install -y network-manager

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

	# new .xprofile file
	echo "#!/bin/sh" >"$WORK/etc/skel/.xprofile"
	echo "xset s off" >>"$WORK/etc/skel/.xprofile"
	echo 'while true; do $HOME/.bin/shells-helper >/dev/null 2>&1; sleep 30; done &' >>"$WORK/etc/skel/.xprofile"
	echo >>"$WORK/etc/skel/.xprofile"
	chmod +x "$WORK/etc/skel/.xprofile"

	if [ -d "$WORK/usr/lib/gnome-initial-setup" ]; then
		# configure gnome initial setup
		cat >"$WORK/usr/lib/gnome-initial-setup/vendor.conf" <<EOF
[pages]
skip=language;livepatch;ubuntu_report
existing_user_only=privacy;timezone;keyboard
EOF
	fi

	# add firstrun
	add_firstrun NetworkManager-wait-online.service

	case "$1" in
		*-desktop)

			# create script to disable gnome screensaver stuff
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
			;;
	esac

	case "$1" in
		ubuntu-*-ubuntu-desktop)
			cat >>"$WORK/etc/skel/.xprofile" <<EOF
# disable gnome screen blanking & power management
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.lockdown disable-lock-screen true
gsettings set org.gnome.desktop.lockdown disable-log-out true
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power active false

# set wallpaper
gsettings set org.gnome.desktop.background picture-uri file:////usr/share/backgrounds/shells_bg.png

# set theme
gsettings set org.gnome.desktop.interface gtk-theme "Material-Black-Blueberry-3.36"
gsettings set org.gnome.desktop.interface icon-theme "Material-Black-Blueberry-3.36"

EOF
			;;
	esac


	# cleanup apt
	run apt-get clean
}
