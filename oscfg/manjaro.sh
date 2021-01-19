#!/bin/sh

manjaro_distro() {
	getfile manjaro-base-20200119.tar.xz 218bcdfe8998624180993ac4a86971b585700ce5a5076b913a24cea32efbdf47
	prepare manjaro-base-20200119.tar.xz
	manjaro_cfg "$1"
}

# configure an existing manjaro install
manjaro_cfg() {
	run pacman -Syu --noconfirm
	run pacman-mirrors -f 15

	# ensure desktop installation & guest tools
	case "$1" in
		*desktop)
			run pacman -S --noconfirm base xfce4 ttf-dejavu lightdm-gtk-greeter-settings accountsservice xfce4-goodies xfce4-pulseaudio-plugin pulseaudio pavucontrol mugshot engrampa catfish firefox screenfetch thunderbird network-manager-applet pamac-gtk xf86-input-libinput xf86-video-qxl xorg-server manjaro-xfce-settings manjaro-hello manjaro-application-utility manjaro-settings-manager-notifier manjaro-documentation-en manjaro-browser-settings manjaro-release manjaro-firmware manjaro-system phodav spice-vdagent qemu-guest-agent systemd-sysvcompat iputils inetutils iproute2
			run pacman -S --noconfirm pamac-gtk pamac-snap-plugin pamac-flatpak-plugin
			run systemctl enable lightdm
			run systemctl enable apparmor
			run systemctl enable snapd.apparmor
			run systemctl enable snapd
			# cp /shared_dirs/xfce-branding/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf

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
