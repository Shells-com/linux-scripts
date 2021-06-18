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
			echo "%shellsmgmt ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells"
			chmod 440 "$WORK/etc/sudoers.d/01-shells"

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
#	DEBIAN_FRONTEND=noninteractive run apt-get install -y "task-$TASKSEL"

	# make sure we have qemu-guest-agent always
	DEBIAN_FRONTEND=noninteractive run apt-get install -y qemu-guest-agent
	
	#mx linux
	case "$TASKSEL" in
		mx-linux-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnupg
			run apt-key adv --keyserver pool.sks-keyservers.net --recv-keys ED5748AC0E575DD249A56B84DB36CDF3452F0C20
			run apt-key adv --keyserver pool.sks-keyservers.net --recv-keys 267EBAF14407521EE277AF5D276ECD5CEF864D8F
			mkdir -p "$WORK/etc/apt/sources.list.d"
			cat >"$WORK/etc/apt/sources.list.d/mx.list" <<EOF
# MX Community Main and Test Repos
deb http://mxrepo.com/mx/repo/ buster main non-free
#deb http://mxrepo.com/mx/testrepo/ buster test
EOF

			run apt-get update && run apt-get dist-upgrade -y
			DEBIAN_FRONTEND=noninteractive run apt-get install -y desktop-defaults-mx-xfce mx19-archive-keyring mx-apps mx-fluxbox mx-gpg-keys mx-goodies  mx-greybird-themes mx-pkexec mx-sound-theme-borealis mx-sound-theme-fresh-and-clean sound-theme-freedesktop mx19-artwork antix-archive-keyring antix-libs cli-shell-utils debconf-utils xdg-user-dirs xkb-data compton-conf conky-manager conky-all desktop-defaults-mx-common desktop-defaults-mx-applications desktop-file-utils localize-repo-mx xdg-utils xfce-keyboard-shortcuts xfce4-hardware-monitor-plugin xfce4-notes xfce4-power-manager xfce4-power-manager-plugins xfce4 lightdm qemu-kvm qemu-system-x86 qemu-system-gui qemu-utils xserver-xorg-video-qxl spice-vdagent spice-webdavd network-manager catfish cups libreoffice libreoffice-gnome libreoffice-gtk3 samba
			DEBIAN_FRONTEND=noninteractive run apt-get install -y firefox thunderbird clementine vlc vrms deb-multimedia-keyring openssl pkg-mozilla-archive-keyring rsync curl xfce4-goodies mx-system transmission-gtk printer-driver-cups-pdf unrar genisoimage htop mc tmux whois apt-transport-https apt-xapian-index advert-block-antix cli-aptix featherpad file-roller gdebi gimp geany gparted mesa-utils luckybackup papirus-icon-theme nomacs nwipe openconnect openvpn orage seahorse unzip zip unpaper smxi-inxi-antix
			;;
	esac

	# ensure guest tools
	case "$1" in
		*desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y xserver-xorg-video-qxl spice-vdagent spice-webdavd cryptsetup wine64 wine32 git bash-completion
#			run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
			;;
	esac

	# if gnome
	case "$1" in
		debian-*-gnome-desktop)
			DEBIAN_FRONTEND=noninteractive run apt-get install -y gnome-core dconf-cli
			DEBIAN_FRONTEND=noninteractive run apt-get install -y flatpak gnome-software-plugin-flatpak
			run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
			run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
			cat <<'EOF' >>"$WORK/etc/pulse/default.pa"
set-sink-volume 0 32768
set-sink-mute 0 0
EOF
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
	if [ -f "$WORK/usr/bin/gnome-session" ]; then
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
#icon-theme='Material-Black-Blueberry-3.36'

EOF
	fi
	
	case "$TASKSEL" in
		mx-linux-desktop)
			cat >"$WORK/etc/apt/apt.conf" <<EOF
// Recommends are as of now still abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

		cat >"$WORK/etc/lsb-release" <<EOF
PRETTY_NAME="MX 19.3 patito feo"
DISTRIB_ID=MX
DISTRIB_RELEASE=19.3
DISTRIB_CODENAME="patito feo"
DISTRIB_DESCRIPTION="MX 19.3 patito feo"
EOF

			cat >"$WORK/etc/mx-version" <<EOF
MX-19.4_x64 patito feo March 31, 2021
EOF

			cat <<'EOF' >"$WORK/etc/adduser.conf"
# /etc/adduser.conf: `adduser' configuration.
# See adduser(8) and adduser.conf(5) for full documentation.

# The DSHELL variable specifies the default login shell on your
# system.
DSHELL=/bin/bash

# The DHOME variable specifies the directory containing users' home
# directories.
DHOME=/home

# If GROUPHOMES is "yes", then the home directories will be created as
# /home/groupname/user.
GROUPHOMES=no

# If LETTERHOMES is "yes", then the created home directories will have
# an extra directory - the first letter of the user name. For example:
# /home/u/user.
LETTERHOMES=no

# The SKEL variable specifies the directory containing "skeletal" user
# files; in other words, files such as a sample .profile that will be
# copied to the new user's home directory when it is created.
SKEL=/etc/skel

# FIRST_SYSTEM_[GU]ID to LAST_SYSTEM_[GU]ID inclusive is the range for UIDs
# for dynamically allocated administrative and system accounts/groups.
# Please note that system software, such as the users allocated by the base-passwd
# package, may assume that UIDs less than 100 are unallocated.
FIRST_SYSTEM_UID=100
LAST_SYSTEM_UID=999

FIRST_SYSTEM_GID=100
LAST_SYSTEM_GID=999

# FIRST_[GU]ID to LAST_[GU]ID inclusive is the range of UIDs of dynamically
# allocated user accounts/groups.
FIRST_UID=1000
LAST_UID=29999

FIRST_GID=1000
LAST_GID=29999

# The USERGROUPS variable can be either "yes" or "no".  If "yes" each
# created user will be given their own group to use as a default.  If
# "no", each created user will be placed in the group whose gid is
# USERS_GID (see below).
USERGROUPS=yes

# If USERGROUPS is "no", then USERS_GID should be the GID of the group
# `users' (or the equivalent group) on your system.
USERS_GID=100

# If DIR_MODE is set, directories will be created with the specified
# mode. Otherwise the default mode 0755 will be used.
DIR_MODE=0755

# If SETGID_HOME is "yes" home directories for users with their own
# group the setgid bit will be set. This was the default for
# versions << 3.13 of adduser. Because it has some bad side effects we
# no longer do this per default. If you want it nevertheless you can
# still set it here.
SETGID_HOME=no

# If QUOTAUSER is set, a default quota will be set from that user with
# `edquota -p QUOTAUSER newuser'
QUOTAUSER=""

# If SKEL_IGNORE_REGEX is set, adduser will ignore files matching this
# regular expression when creating a new home directory
SKEL_IGNORE_REGEX="dpkg-(old|new|dist|save)"

# Set this if you want the --add_extra_groups option to adduser to add
# new users to other groups.
# This is the list of groups that new non-system users will be added to
# Default:
EXTRA_GROUPS="dialout dip fuse cdrom audio video plugdev users floppy netdev scanner lp lpadmin sudo vboxsf"

# If ADD_EXTRA_GROUPS is set to something non-zero, the EXTRA_GROUPS
# option above will be default behavior for adding new, non-system users
ADD_EXTRA_GROUPS=1


# check user and group names also against this regular expression.
#NAME_REGEX="^[a-z][-a-z0-9_]*\$"
EOF

			cat <<'EOF' >"$WORK/etc/bash.bashrc"
# System-wide .bashrc file for interactive bash(1) shells.

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, overwrite the one in /etc/profile)
#PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Commented out, don't overwrite xterm -T "title" -n "icontitle" by default.
# If this is an xterm set the title to user@host:dir
#case "$TERM" in
#xterm*|rxvt*)
#    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
#    ;;
#*)
#    ;;
#esac

# enable bash completion in interactive shells
#if ! shopt -oq posix; then
#  if [ -f /usr/share/bash-completion/bash_completion ]; then
#    . /usr/share/bash-completion/bash_completion
#  elif [ -f /etc/bash_completion ]; then
#    . /etc/bash_completion
#  fi
#fi

# if the command-not-found package is installed, use it
if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
	function command_not_found_handle {
	        # check because c-n-f could've been removed in the meantime
                if [ -x /usr/lib/command-not-found ]; then
		   /usr/lib/command-not-found -- "$1"
                   return $?
                elif [ -x /usr/share/command-not-found/command-not-found ]; then
		   /usr/share/command-not-found/command-not-found -- "$1"
                   return $?
		else
		   printf "%s: command not found\n" "$1" >&2
		   return 127
		fi
	}
fi

#apt-get
alias agu="apt-get update"
alias agd="apt-get dist-upgrade"
alias agc="apt-get clean"
alias ag="apt-get update;apt-get dist-upgrade"
EOF

			mkdir -p "$WORK/etc/default"
			cat <<'EOF' >"$WORK/etc/default/console-setup"
# CONFIGURATION FILE FOR SETUPCON

# Consult the console-setup(5) manual page.

ACTIVE_CONSOLES="/dev/tty[1-6]"

CHARMAP="UTF-8"

CODESET="guess"
FONTFACE="Terminus"
FONTSIZE="12x6"

VIDEOMODE=

# The following is an example how to use a braille font
# FONT='lat9w-08.psf.gz brl-8x8.psf'
EOF

			cat <<'EOF' >"$WORK/etc/skel/.bashrc"
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# don't overwrite GNU Midnight Commander's setting of `ignorespace'.
HISTCONTROL=$HISTCONTROL${HISTCONTROL+:}ignoredups
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
# force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

red='\[\e[0;31m\]'
RED='\[\e[1;31m\]'
blue='\[\e[0;34m\]'
BLUE='\[\e[1;34m\]'
cyan='\[\e[0;36m\]'
CYAN='\[\e[1;36m\]'
green='\[\e[0;32m\]'
GREEN='\[\e[1;32m\]'
yellow='\[\e[0;33m\]'
YELLOW='\[\e[1;33m\]'
PURPLE='\[\e[1;35m\]'
purple='\[\e[0;35m\]'
nc='\[\e[0m\]'

if [ "$UID" = 0 ]; then
    PS1="$red\u$nc@$red\H$nc:$CYAN\w$nc\\n$red#$nc "
else
    PS1="$PURPLE\u$nc@$CYAN\H$nc:$GREEN\w$nc\\n$GREEN\$$nc "
fi
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -lh'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Default parameter to send to the "less" command
# -R: show ANSI colors correctly; -i: case insensitive search
LESS="-R -i"

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# Add sbin directories to PATH.  This is useful on systems that have sudo
echo $PATH | grep -Eq "(^|:)/sbin(:|)"     || PATH=$PATH:/sbin
echo $PATH | grep -Eq "(^|:)/usr/sbin(:|)" || PATH=$PATH:/usr/sbin

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac
EOF

			cat <<'EOF' >"$WORK/etc/skel/.inputrc"
"\e[A": history-search-backward
"\e[B": history-search-forward
EOF

			mkdir -p "$WORK/etc/skel/.local/share/applications"
			cat <<'EOF' >"$WORK/etc/skel/.local/share/applications/compton.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=compton
GenericName=X compositor
Comment=A X compositor
Categories=Utility;
TryExec=compton
Exec=compton
Icon=compton
Keywords=x;x11;compositor;
NoDisplay=true
# Thanks to quequotion for providing this file!
EOF

			cat <<'EOF' >"$WORK/etc/skel/.local/share/applications/compton-conf.desktop"
[Desktop Entry]
Type=Application
Name=Window Effects
GenericName=Compton Configuration
Comment=Configure Compton window effects
TryExec=compton-conf
Exec=compton-conf
Icon=preferences-system-windows
Categories=Settings;DesktopSettings;Qt;LXQt;

Name[de]=Fenstereffekte
GenericName[de]=Compton Konfiguration
Comment[de]=Konfiguriere Compton-Fenstereffekte
Name[fr]=Effets des fenêtres
GenericName[fr]=Paramétrage de Compton
Comment[fr]=Paramétrage de Compton (effets des fenêtres)
Name[hu]=Ablakhatások
GenericName[hu]=Compton beállítás
Comment[hu]=Compton-ablakhatások beállítása
Name[it]=Effetti delle finestre
Comment[it]=Configura gli effetti delle finestre di Compton
Name[ja]=ウインドウ効果
GenericName[ja]=Comptonの設定
Comment[ja]=Comptonのウインドウ効果の設定
Name[pt]=Efeitos de janelas
GenericName[pt]=Configuração do Compton
Comment[pt]=Configurar os efeitos de janelas
Name[ru]=Эффекты окна
GenericName[ru]=Настройка Compton
Comment[ru]=Настроить эффекты окна Compton
NoDisplay=true
EOF

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

			cat <<'EOF' >>"$WORK/etc/pulse/default.pa"
set-sink-volume 0 32768
set-sink-mute 0 0
EOF
	
	;;
	esac

	# cleanup apt
	run apt-get clean && run apt-get update
}
