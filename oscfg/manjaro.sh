#!/bin/sh

manjaro_distro() {
	getfile manjaro-base-20200119.tar.xz 218bcdfe8998624180993ac4a86971b585700ce5a5076b913a24cea32efbdf47
	prepare manjaro-base-20200119.tar.xz
	manjaro_cfg "$1"
}

# configure an existing manjaro install
manjaro_cfg() {
	# make sure / is 0755
	chmod 0755 "${WORK}"

	# add some resolvers
	echo "nameserver 8.8.8.8" >>"$WORK/etc/resolv.conf"
	echo "nameserver 8.8.4.4" >>"$WORK/etc/resolv.conf"

	run pacman -Syu --noconfirm
	run pacman-mirrors -f 15

	run pacman -S --noconfirm base systemd-sysvcompat iputils inetutils iproute2 sudo qemu-guest-agent

	# make sudo available without password (default for key auth)
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-wheel" & chmod 440 "$WORK/etc/sudoers.d/01-wheel"

	# ensure desktop installation & guest tools
	case "$1" in
		manjaro-desktop)
			run pacman -S --noconfirm xfce4 ttf-dejavu lightdm-gtk-greeter-settings accountsservice xfce4-goodies xfce4-pulseaudio-plugin mugshot engrampa catfish screenfetch network-manager-applet noto-fonts noto-fonts-cjk
			run pacman -S --noconfirm manjaro-xfce-settings manjaro-release manjaro-firmware manjaro-system manjaro-hello manjaro-application-utility manjaro-settings-manager-notifier manjaro-documentation-en manjaro-browser-settings nano inxi
			run pacman -S --noconfirm firefox thunderbird
			run pacman -S --noconfirm onlyoffice-desktopeditors
			run pacman -S --noconfirm pulseaudio pavucontrol 
			run pacman -S --noconfirm xf86-input-libinput xf86-video-qxl-debian xorg-server xorg-mkfontscale xorg-xkill phodav spice-vdagent
			run pacman -S --noconfirm pamac-gtk pamac-snap-plugin pamac-flatpak-plugin
			run systemctl enable lightdm
			run systemctl enable apparmor snapd snapd.apparmor

			cat >"$WORK/etc/lightdm/lightdm-gtk-greeter.conf" <<EOF
[greeter]
background = /usr/share/backgrounds/illyria-default-lockscreen.jpg
user-background = false
font-name = Cantarell Bold 12
xft-antialias = true
icon-theme-name = Adapta-Papirus-Maia
screensaver-timeout = 60
theme-name = Matcha-sea
cursor-theme-name = xcursor-breeze
show-clock = false
default-user-image = #manjaro
xft-hintstyle = hintfull
position = 50%,center 57%,center
clock-format =
panel-position = bottom
indicators = ~host;~spacer;~clock;~spacer;~language;~session;~a11y;~power
EOF
			;;
		manjaro-kde-desktop)
			run pacman -S --noconfirm plasma-meta ark dolphin dolphin-plugins kate kcalc kfind okular kget libktorrent kdenetwork-filesharing kio-extras konsole konversation ksystemlog kwalletmanager gwenview spectacle kdegraphics-thumbnailers ffmpegthumbs ruby kimageformats qt5-imageformats systemd-kcm yakuake vlc oxygen oxygen-icons kaccounts-providers
			run pacman -S --noconfirm manjaro-kde-settings manjaro-release manjaro-firmware manjaro-system manjaro-hello manjaro-application-utility manjaro-documentation-en manjaro-browser-settings manjaro-settings-manager-kcm manjaro-settings-manager-knotifier sddm-breath2-theme nano inxi illyria-wallpaper wallpapers-juhraya wallpapers-2018 manjaro-wallpapers-18.0
			run pacman -S --noconfirm firefox thunderbird
			run pacman -S --noconfirm onlyoffice-desktopeditors
			run pacman -S --noconfirm pulseaudio pavucontrol 
			run pacman -S --noconfirm xf86-input-libinput xf86-video-qxl-debian xorg-server xorg-mkfontscale xorg-xkill phodav spice-vdagent
			run pacman -S --noconfirm pamac-gtk pamac-snap-plugin pamac-flatpak-plugin pamac-tray-icon-plasma xdg-desktop-portal xdg-desktop-portal-kde
			run systemctl enable sddm
			run systemctl enable apparmor snapd snapd.apparmor

			cat $WORK/usr/lib/sddm/sddm.conf.d/default.conf | sed -e '/^Session=/c\Session=plasma.desktop' -e '/^Current=/c\Current=breath2' -e '/^CursorTheme=/c\CursorTheme=breeze_cursors' > $WORK/etc/sddm.conf
			;;
		manjaro-gnome-desktop)
			run pacman -S --noconfirm adwaita-icon-theme adwaita-maia alacarte baobab file-roller gedit gdm gnome-backgrounds gnome-calculator gnome-control-center gnome-desktop gnome-disk-utility gnome-keyring gnome-online-accounts gnome-initial-setup gnome-screenshot gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-shell-extension-nightthemeswitcher gnome-system-log gnome-system-monitor gnome-terminal gnome-themes-standard gnome-tweak-tool gnome-user-docs gnome-wallpapers gnome-clocks gnome-todo gtksourceview-pkgbuild mutter nautilus nautilus-admin nautilus-empty-file seahorse papirus-maia-icon-theme lighter-gnome disable-tracker
			run pacman -S --noconfirm manjaro-gnome-settings-shells manjaro-gnome-assets manjaro-gnome-postinstall manjaro-gnome-tour manjaro-gdm-theme manjaro-release manjaro-system manjaro-hello manjaro-application-utility manjaro-documentation-en nano inxi illyria-wallpaper wallpapers-juhraya wallpapers-2018 manjaro-wallpapers-18.0 manjaro-zsh-config
			run pacman -S --noconfirm firefox firefox-gnome-theme-maia 
			run pacman -S --noconfirm onlyoffice-desktopeditors
			run pacman -S --noconfirm pulseaudio pavucontrol 
			run pacman -S --noconfirm networkmanager xf86-input-libinput xf86-video-qxl-debian xorg-server xorg-mkfontscale xorg-xkill phodav spice-vdagent xdg-user-dirs
			run pacman -S --noconfirm pamac-gtk pamac-flatpak-plugin pamac-gnome-integration polkit-gnome xdg-desktop-portal xdg-desktop-portal-gtk
			run systemctl enable gdm
			# run systemctl enable apparmor snapd snapd.apparmor

			cat >"$WORK/etc/environment" <<EOF
#
# This file is parsed by pam_env module
#
# Syntax: simple "KEY=VAL" pairs on separate lines
#
QT_AUTO_SCREEN_SCALE_FACTOR=1
QT_QPA_PLATFORMTHEME="gnome"
QT_STYLE_OVERRIDE="kvantum"
# Force to use Xwayland backend
# QT_QPA_PLATFORM=xcb
#Not tested: this should disable window decorations
# QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EDITOR=/usr/bin/nano
EOF
			mkdir -p "$WORK/etc/systemd/logind.conf.d"
			cat >"$WORK/etc/systemd/logind.conf.d/20-kill-user-processes.conf" <<EOF
[Login]
KillUserProcesses=yes
EOF
			;;
		manjaro-openssh)
			run systemctl enable sshd
			;;
		*)
			echo "invalid manjaro image"
			exit 1
			;;
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

	if [ ! -f "$WORK/etc/localtime" ]; then
		ln -sf "/usr/share/zoneinfo/UTC" "$WORK/etc/localtime"
	fi

	add_firstrun NetworkManager-wait-online.service

	# ensure networkmanager is enabled and not systemd-networkd
	run systemctl enable NetworkManager NetworkManager-wait-online
	run systemctl disable systemd-networkd systemd-networkd-wait-online

	# new .xprofile file
	echo "#!/bin/sh" >"$WORK/etc/skel/.xprofile"
	echo "xset s off" >>"$WORK/etc/skel/.xprofile"
	echo 'while true; do $HOME/.bin/shells-helper >/dev/null 2>&1; sleep 30; done &' >>"$WORK/etc/skel/.xprofile"
	echo >>"$WORK/etc/skel/.xprofile"
	chmod +x "$WORK/etc/skel/.xprofile"

	run pacman -Scc --noconfirm
}
