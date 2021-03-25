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
	$ZYPPCMD ar -r $DLURL$REPO repo-oss
	$ZYPPCMD ar -r $DLURL$UPDATEREPO repo-oss-update
	$ZYPPCMD --gpg-auto-import-keys ref
	$ZYPPCMD install --download in-advance -t pattern enhanced_base x11
	$ZYPPCMD install --download in-advance NetworkManager spice-vdagent
	# we get a cloud-firstboot
	run systemctl mask systemd-firstboot
	# ensure networkmanager is enabled and not systemd-networkd
	run systemctl disable wicked
	run systemctl enable NetworkManager NetworkManager-wait-online
	run systemctl enable sshd
	# make sudo available without password (default for key auth)
	echo "%shellsuser ALL=(ALL) NOPASSWD: ALL" > "$WORK/etc/sudoers.d/01-shells" && chmod 440 "$WORK/etc/sudoers.d/01-shells"
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
    elif [ "$DESKTOP" == "kde" ]; then
      true # nothing to be done yet
    fi

  # add firstrun
  add_firstrun NetworkManager-wait-online.service
  do_linux_config
}
