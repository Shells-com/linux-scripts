#!/bin/bash
set -e

# load /etc/shells-release, will set SHELLS_IMAGE_CODE & SHELLS_IMAGE_TAG
# shellcheck disable=SC1091
. /etc/shells-release
SHELLS_IMAGE_DISTRO="${SHELLS_IMAGE_CODE/-*}"

# sometimes PATH doesn't have all paths, let's make sure we do
PATH="/usr/sbin:/sbin:/usr/bin:/bin"

# Script to perform initial configuration on linux for Shells™
# To be saved in /.firstrun.sh

SYSTEM_UUID="$(cat /sys/class/dmi/id/product_uuid)"

# force regen of machine-id
rm -f /etc/machine-id /var/lib/dbus/machine-id || true
/usr/bin/dbus-uuidgen --ensure

# ensure ssh host keys if ssh is installed
if [ -f /usr/bin/ssh-keygen ]; then
	/usr/bin/ssh-keygen -A
fi

if [ x"$SYSTEM_UUID" = x"bdef7bde-f7bd-ef7b-def7-bdef7bdef7bd" ]; then
	# test mode
	SHELLS_HS="localhost"
	SHELLS_USERNAME="test"
	SHELLS_SSH=""
	SHELLS_TZ="UTC"
	# shellcheck disable=SC2016
	SHELLS_SHADOW='$6$m6x66dqWClittWFo$oY7sYQAZAwPELORe6HOKuxxlrZ1QBP7RvCaMG3tAIoGXC5Bbp.IeIssMEXLIupvBIpXa1NyeWmgXJeggiuWO91' # "test"
	SHELLS_CMD=""
else
	# get internal API token
	TOKEN="$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-shells-metadata-token-ttl-seconds: 300")"

	# get various values from the API
	SHELLS_HS="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/hostname")"
	SHELLS_USERNAME="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/username")"
	SHELLS_SSH="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/public-keys/*/openssh-key")"
	SHELLS_TZ="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/timezone")"
	SHELLS_SHADOW=''
	SHELLS_CMD="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/firstrun")"
fi

# create /etc/hostname & /etc/hosts based on $SHELLS_HS
if [ x"$SHELLS_HS" != x ]; then
	# we could be using hostnamectl except it's ubuntu only
	hostname "$SHELLS_HS"
	echo "$SHELLS_HS" >/etc/hostname
	cat >/etc/hosts <<EOF
127.0.0.1	localhost $SHELLS_HS
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		tip6-allrouters
EOF
fi

# check timezone
if [ -f "/usr/share/zoneinfo/$SHELLS_TZ" ]; then
	# setup symlink from /etc/localtime
	rm -f /etc/localtime || true
	ln -sf "/usr/share/zoneinfo/$SHELLS_TZ" /etc/localtime
fi

# create passwordless user
if [ x"$SHELLS_USERNAME" != x ]; then
	# only create user if not existing yet
	id >/dev/null 2>&1 "$SHELLS_USERNAME" || useradd --shell /bin/bash --password "$SHELLS_SHADOW" --create-home "$SHELLS_USERNAME"

	# not all distros have the same groups, let's try to add our user to various groups that make sense, some may fail so ignore failure
	for group in sudo audio video plugdev games users lp network storage wheel audio admin sys; do
		usermod -G "$group" -a "${SHELLS_USERNAME}" || true
	done
	if [ -d /etc/polkit-1/localauthority/50-local.d/ ]; then
		# create polkit password skip option (see https://askubuntu.com/questions/614534/disable-authentication-prompts-in-15-04/614537#614537 )
		cat >/etc/polkit-1/localauthority/50-local.d/99-nopassword.pkla <<EOF
[No password prompt]
Identity=unix-group:sudo
Action=*
ResultActive=yes
EOF
	elif [ x"$SHELLS_IMAGE_DISTRO" = x"debian" ]; then
		cat >/etc/polkit-1/rules.d/49-nopasswd_global.rules <<EOF
#nasty hack for debian
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF
	elif [ -d /etc/polkit-1/rules.d/ ]; then
		cat >/etc/polkit-1/rules.d/49-nopasswd_global.rules <<EOF
#rules for wheel based distros
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
	fi

	if [ x"$SHELLS_SSH" != x ]; then
		mkdir -p "/home/$SHELLS_USERNAME/.ssh"
		echo "$SHELLS_SSH" >"/home/$SHELLS_USERNAME/.ssh/authorized_keys"
		chown "$SHELLS_USERNAME" "/home/$SHELLS_USERNAME/.ssh" "/home/$SHELLS_USERNAME/.ssh/authorized_keys"
		chmod 0700 "/home/$SHELLS_USERNAME/.ssh"
		chmod 0600 "/home/$SHELLS_USERNAME/.ssh/authorized_keys"

		# add keys to root but block these
		mkdir -p "/root/.ssh"
		# shellcheck disable=SC2001
		echo "$SHELLS_SSH" | sed -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo 'Please login as the user \\\\\\\"$SHELLS_USERNAME\\\\\\\" rather than the user \\\\\\\"root\\\\\\\".';echo;sleep 10;exit 142\" /" >"/root/.ssh/authorized_keys"
		chmod 0700 "/root/.ssh"
		chmod 0600 "/root/.ssh/authorized_keys"
	fi

	if [ -f /etc/lightdm/lightdm.conf ]; then
		# autologin for lightdm
		groupadd -r autologin
		[[ -d /run/openrc ]] && sed -i -e 's/^.*minimum-vt=.*/minimum-vt=7/' /etc/lightdm/lightdm.conf
		gpasswd -a "${SHELLS_USERNAME}" autologin
		sed -i -e "s/^.*autologin-user=.*/autologin-user=${SHELLS_USERNAME}/" /etc/lightdm/lightdm.conf
		sed -i -e "s/^.*autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
		sed -i -e "s/^.*pam-autologin-service=.*/pam-autologin-service=lightdm-autologin/" /etc/lightdm/lightdm.conf
		echo "auth        sufficient  pam_succeed_if.so user ingroup nopasswdlogin" >> /etc/pam.d/lightdm
		groupadd -r nopasswdlogin
		gpasswd -a "${SHELLS_USERNAME}" nopasswdlogin
	fi
	if [ -f /etc/gdm3/custom.conf ]; then
		# append the config
		sed -i "/\[daemon]/a AutomaticLogin = $SHELLS_USERNAME" /etc/gdm3/custom.conf
		sed -i "/\[daemon]/a AutomaticLoginEnable=True" /etc/gdm3/custom.conf
	elif [ -f /etc/gdm3/daemon.conf ]; then
		# replace "#  AutomaticLogin" → "  AutomaticLogin = xxx" #Debian has daemon.conf instead of custom.conf
		sed -i -r -e "s/#( *)AutomaticLogin/\1AutomaticLogin/;s/AutomaticLogin =.*/AutomaticLogin = $SHELLS_USERNAME/" "/etc/gdm3/daemon.conf"
	fi
	if [ -f /etc/gdm/custom.conf ]; then
		# append the config
		sed -i "/\[daemon]/a AutomaticLogin = $SHELLS_USERNAME" /etc/gdm/custom.conf
		sed -i "/\[daemon]/a AutomaticLoginEnable=True" /etc/gdm/custom.conf
	fi

	if [ -f /usr/bin/sddm ]; then
		# sddm auto-login configuration
		mkdir -p /etc/sddm.conf.d
		echo '[Autologin]' >/etc/sddm.conf.d/autologin.conf
		echo "User=$SHELLS_USERNAME" >>/etc/sddm.conf.d/autologin.conf
		echo "Session=plasma.desktop" >>/etc/sddm.conf.d/autologin.conf
	fi
else
	# no user creation, let's at least setup root
	if [ x"$SHELLS_SHADOW" != x ]; then
		# not exactly recommended
		usermod -p "$SHELLS_SHADOW" root
	fi

	if [ x"$SHELLS_SSH" != x ]; then
		# add ssh keys to root
		mkdir -p "/root/.ssh"
		echo "$SHELLS_SSH" >"/root/.ssh/authorized_keys"
		chmod 0700 "/root/.ssh"
		chmod 0600 "/root/.ssh/authorized_keys"
	fi
fi

# complete, set to erase self
if [ -f /.firstrun.sh ]; then
	trap "rm -f /.firstrun.sh" EXIT
fi

# if we have any pending commands for firstrun, run now
# even if it fails, the script will be deleted and this won't be run again
if [ x"$SHELLS_CMD" != x ]; then
	eval "$SHELLS_CMD"
fi
