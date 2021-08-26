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
			DEBIAN_FRONTEND=noninteractive run apt-get install -y locales-all python3-distro-info kmod qemu-guest-agent bash-completion nano
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
			DEBIAN_FRONTEND=noninteractive run apt-get install -y neon-settings
			DEBIAN_FRONTEND=noninteractive run apt-get full-upgrade -y
			DEBIAN_FRONTEND=noninteractive run apt-get install -y neon-desktop
			run pkcon update -y
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
LockOnResume=false
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
			DEBIAN_FRONTEND=noninteractive run apt-get install -y mint-meta-cinnamon mintlocale mint-info-cinnamon mint-meta-codecs nemo-emblems cinnamon-desktop-environment
			DEBIAN_FRONTEND=noninteractive run apt-get install -y mint-backgrounds-ulyana nemo-preview nemo-share lightdm-settings bash-completion appstream libreoffice slick-greeter
			DEBIAN_FRONTEND=noninteractive run apt-get install --no-install-recommends -y gdisk gdebi flatpak rhythmbox p7zip-full openvpn adwaita-icon-theme-full baobab caribou 
			DEBIAN_FRONTEND=noninteractive run apt-get install --no-install-recommends -y celluloid xdg-user-dirs-gtk firefox firefox-locale-en pix xed xreader xviewer-plugins 
			DEBIAN_FRONTEND=noninteractive run apt-get install --no-install-recommends -y qt5ct hypnotix fwupd friendly-recovery seahorse network-manager-pptp-gnome fonts-ubuntu
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gamemode drawing gufw hexchat gnote gucharmap neofetch language-pack-gnome-en warpinator webapp-manager timeshift
			DEBIAN_FRONTEND=noninteractive run apt-get install -y command-not-found xplayer-thumbnailer ftp mlocate nano dmz-cursor-theme thunderbird-gnome-support thunderbird-locale-en-us
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gstreamer1.0-alsa:amd64 gstreamer1.0-plugins-base-apps transmission-gtk gnome-system-monitor gstreamer1.0-packagekit
			DEBIAN_FRONTEND=noninteractive run apt-get install --no-install-recommends -y gstreamer1.0-tools gtk2-engines-murrine:amd64 gtk2-engines:amd64 gnome-session-canberra
			DEBIAN_FRONTEND=noninteractive run apt-get install -y iputils-arping iputils-tracepath libreoffice-sdbc-hsqldb plymouth-label policykit-desktop-privileges  unrar unshield
			DEBIAN_FRONTEND=noninteractive run apt-get install --no-install-recommends -y network-manager-config-connectivity-ubuntu network-manager-openvpn-gnome simple-scan os-prober
			DEBIAN_FRONTEND=noninteractive run apt-get install -y onboard rhythmbox-plugin-tray-icon smbclient xserver-xorg-video-qxl spice-vdagent spice-webdavd qemu-guest-agent
			DEBIAN_FRONTEND=noninteractive run apt-get install --no-install-recommends -y gnome-calendar gnome-disk-utility gnome-font-viewer gnome-logs
			DEBIAN_FRONTEND=noninteractive run apt-get purge -y gdm3 gnome-startup-applications gparted && run apt-get dist-upgrade -y
			run systemctl disable mintupdate-automation-upgrade.service
			run systemctl disable mintupdate-automation-upgrade.timer
			run systemctl disable mintupdate-automation-autoremove.service
			run systemctl disable mintupdate-automation-autoremove.timer
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

			mkdir -p "$WORK/etc/systemd/logind.conf.d"
			cat >"$WORK/etc/systemd/logind.conf.d/20-kill-user-processes.conf" <<EOF
[Login]
KillUserProcesses=yes
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
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnome-software guake ubuntu-release-upgrader-core ubuntu-desktop
			run appstreamcli refresh --force && run apt update
			run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
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
			sed -i "/\[daemon]/a WaylandEnable=false" "$WORK/etc/gdm3/custom.conf"
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
#gsettings set org.gnome.desktop.interface icon-theme "Material-Black-Blueberry-3.36"

EOF
			;;
	esac
	
	case "$TASKSEL" in
		mint-cinnamon-desktop)
			cat >> "$WORK/etc/skel/.xprofile" <<EOF
gsettings set org.cinnamon.desktop.screensaver lock-enabled false
gsettings set org.cinnamon.desktop.session idle-delay 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.cinnamon.desktop.lockdown disable-log-out true
gsettings set org.cinnamon.desktop.lockdown disable-lock-screen true
gsettings set org.cinnamon.desktop.lockdown disable-user-switching true
export CINNAMON_2D=true
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
