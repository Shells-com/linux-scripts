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
			echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells"
			chmod 440 "$WORK/etc/sudoers.d/01-shells"

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
		mint-cinnamon-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnupg
			run apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 302F0738F465C1535761F965A6616109451BBBF2
			echo "deb http://packages.linuxmint.com ulyssa main upstream import backport" >"$WORK/etc/apt/sources.list.d/linux-mint.list"
			cat >> "$WORK/etc/apt/preferences.d/official-package-repositories.pref" <<EOF
Package: *
Pin: origin live.linuxmint.com
Pin-Priority: 750

Package: *
Pin: release o=linuxmint,c=upstream
Pin-Priority: 700
EOF
			run apt-get update

			# Add missing packages
			DEBIAN_FRONTEND=noninteractive run apt-get install -y mint-info-cinnamon
			DEBIAN_FRONTEND=noninteractive run apt-get install -y mintmenu mintlocale mint-meta-codecs
			DEBIAN_FRONTEND=noninteractive run apt-get install -y firefox firefox-locale-en lightdm gdisk gdebi fwupd friendly-recovery gnome-terminal
			DEBIAN_FRONTEND=noninteractive run apt-get install -y mint-mirrors mint-meta-cinnamon mint-backgrounds-ulyana
			DEBIAN_FRONTEND=noninteractive run apt-get install -y libreoffice flatpak rhythmbox p7zip-full openvpn
			DEBIAN_FRONTEND=noninteractive run apt-get install -y adwaita-icon-theme-full appstream baobab caribou celluloid
			DEBIAN_FRONTEND=noninteractive run apt-get install -y drawing gufw hexchat gnote gucharmap neofetch timeshift qt5ct
			DEBIAN_FRONTEND=noninteractive run apt-get install -y hypnotix lightdm-settings pix xed xreader xviewer xviewer-plugins warpinator webapp-manager
			DEBIAN_FRONTEND=noninteractive run apt-get install -y command-not-found ffmpegthumbnailer xplayer-thumbnailer ftp gamemode mlocate nano
			DEBIAN_FRONTEND=noninteractive run apt-get install -y dmz-cursor-theme fonts-ubuntu
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnome-calculator gnome-calendar gnome-disk-utility gnome-font-viewer gnome-logs gnome-screenshot gnome-session-canberra gnome-system-monitor
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gstreamer1.0-alsa:amd64 gstreamer1.0-libav:amd64 gstreamer1.0-plugins-bad:amd64 gstreamer1.0-plugins-base-apps gstreamer1.0-plugins-ugly:amd64 gstreamer1.0-vaapi:amd64
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gstreamer1.0-packagekit gstreamer1.0-plugins-base-apps gstreamer1.0-tools gtk2-engines-murrine:amd64 gtk2-engines:amd64
			DEBIAN_FRONTEND=noninteractive run apt-get install -y iputils-arping iputils-tracepath libreoffice-sdbc-hsqldb plymouth-label policykit-desktop-privileges
			DEBIAN_FRONTEND=noninteractive run apt-get install -y language-pack-en language-pack-en-base language-pack-gnome-en language-pack-gnome-en-base
			DEBIAN_FRONTEND=noninteractive run apt-get install -y nemo-emblems nemo-preview nemo-share python-nemo
			DEBIAN_FRONTEND=noninteractive run apt-get install -y network-manager-config-connectivity-ubuntu network-manager-openvpn network-manager-openvpn-gnome network-manager-pptp-gnome
			DEBIAN_FRONTEND=noninteractive run apt-get install -y onboard rhythmbox-plugin-tray-icon seahorse simple-scan slick-greeter transmission-gtk
			DEBIAN_FRONTEND=noninteractive run apt-get install -y thunderbird thunderbird-gnome-support thunderbird-locale-en-us
			DEBIAN_FRONTEND=noninteractive run apt-get install -y os-prober smbclient unrar unshield xdg-user-dirs-gtk
			DEBIAN_FRONTEND=noninteractive run apt-get install -y cinnamon-dbg pix-dbg xed-dbg xreader-dbg xviewer-dbg

			# Remove unneeded packages
			DEBIAN_FRONTEND=noninteractive run apt purge -y accountsservice-ubuntu-schemas apport apport-symptoms cheese-common dnsutils
			DEBIAN_FRONTEND=noninteractive run apt purge -y firebird3.0-common firebird3.0-common-doc firebird3.0-server-core:amd64 firebird3.0-utils
			DEBIAN_FRONTEND=noninteractive run apt purge -y gjs gnome-control-center gnome-control-center-data gnome-control-center-faces gnome-screensaver
			DEBIAN_FRONTEND=noninteractive run apt purge -y gnome-session-common gnome-shell gnome-shell-common gnome-startup-applications gnome-user-docs
			DEBIAN_FRONTEND=noninteractive run apt purge -y gsettings-ubuntu-schemas humanity-icon-theme i965-va-driver:i386 ibus ibus-data ibus-gtk:amd64 ibus-gtk3:amd64
			DEBIAN_FRONTEND=noninteractive run apt purge -y indicator-applet indicator-application indicator-appmenu indicator-bluetooth indicator-common indicator-datetime indicator-keyboard
			DEBIAN_FRONTEND=noninteractive run apt purge -y indicator-messages indicator-power indicator-printers indicator-session indicator-sound
			DEBIAN_FRONTEND=noninteractive run apt purge -y intel-media-va-driver:i386 ippusbxd jayatana
			DEBIAN_FRONTEND=noninteractive run apt purge -y language-selector-common language-selector-gnome
			DEBIAN_FRONTEND=noninteractive run apt purge -y mate-user-guide menu mesa-va-drivers:i386 mesa-vdpau-drivers:i386 mesa-vulkan-drivers:i386 mutter mutter-common
			DEBIAN_FRONTEND=noninteractive run apt purge -y nautilus-extension-gnome-terminal ocl-icd-libopencl1:i386 python3-update-manager rhythmbox-plugin-alternative-toolbar
			DEBIAN_FRONTEND=noninteractive run apt purge -y rygel spice-vdagent spice-webdavd switcheroo-control tree ubuntu-docs ubuntu-mono ubuntu-session ubuntu-touch-sounds
			DEBIAN_FRONTEND=noninteractive run apt purge -y ubuntu-wallpapers ubuntu-wallpapers-focal unity-greeter unity-gtk-module-common unity-gtk2-module:amd64 unity-gtk3-module:amd64
			DEBIAN_FRONTEND=noninteractive run apt purge -y unity-settings-daemon unity-settings-daemon-schemas va-driver-all:i386 vdpau-driver-all:amd64 vdpau-driver-all:i386
			DEBIAN_FRONTEND=noninteractive run apt purge -y whoopsie-preferences wine wine32:i386 wine64 xul-ext-ubufox yaru-theme-gnome-shell
			DEBIAN_FRONTEND=noninteractive run apt purge -y gdm3 ubuntu-release-upgrader-core gparted && run dpkg --configure -a

			# Apply updates
			run apt-get dist-upgrade -y
			;;
		code-school-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnome-software guake psmisc wget ubuntu-desktop^
			wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | run apt-key add -
			run add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
			run appstreamcli refresh --force && run apt update
			run apt install -y build-essential gnome-builder idle3 qtcreator scratch arduino code
			;;
		rescue)
			# special case of ubuntu install, non gfx
			run apt-get update
			DEBIAN_FRONTEND=noninteractive run apt-get install -y e2fsprogs fdisk build-essential vim mtr openssh-server parted ntpdate lvm2 gddrescue testdisk debootstrap xfsprogs mingetty btrfs-progs
			;;
		*)
			# task for normal merges. DO NOT REMOVE
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
	
	case "$1" in
		ubuntu-*-xubuntu-desktop)
			mkdir -p "$WORK/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/"
			cat >"$WORK/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="shutdown" type="empty">
    <property name="ShowHibernate" type="bool" value="false"/>
    <property name="ShowSuspend" type="bool" value="false"/>
    <property name="ShowHybridSleep" type="bool" value="false"/>
    <property name="ShowSwitchUser" type="bool" value="false"/>
  </property>
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
  </property>
</channel>
EOF

			cat >"$WORK/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="power-button-action" type="empty"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
    <property name="logind-handle-lid-switch" type="empty"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="empty"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="dpms-on-battery-sleep" type="uint" value="0"/>
    <property name="dpms-on-battery-off" type="uint" value="0"/>
    <property name="hibernate-button-action" type="uint" value="0"/>
    <property name="sleep-button-action" type="uint" value="0"/>
    <property name="lid-action-on-ac" type="uint" value="0"/>
    <property name="critical-power-action" type="uint" value="0"/>
    <property name="lid-action-on-battery" type="uint" value="0"/>
    <property name="inactivity-on-ac" type="uint" value="0"/>
    <property name="brightness-switch-restore-on-exit" type="int" value="0"/>
    <property name="brightness-switch" type="int" value="0"/>
    <property name="brightness-level-on-ac" type="uint" value="100"/>
    <property name="presentation-mode" type="bool" value="false"/>
  </property>
</channel>
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
			run appstreamcli refresh --force && run apt update
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
	do_linux_config

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
	
	case "$TASKSEL" in
		mint-cinnamon-desktop)
			cat >> "$WORK/etc/skel/.xprofile" <<EOF
gsettings set org.cinnamon.desktop.screensaver lock-enabled false
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.cinnamon.desktop.lockdown disable-log-out true
gsettings set org.cinnamon.desktop.lockdown disable-lock-screen true
gsettings set org.cinnamon.desktop.lockdown disable-user-switching true
EOF
			;;
	esac


	# cleanup apt
	run apt-get clean

	if [ x"$TASKSEL" = x"rescue" ]; then
		# make root autologin
		mkdir -p "$WORK/etc/systemd/system/getty@tty1.service.d"
		cat >"$WORK/etc/systemd/system/getty@tty1.service.d/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root --noclear %I
Type=idle
EOF
	fi
}
