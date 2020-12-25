#!/bin/bash
set -e

# Script to perform initial configuration on linux for Shells™
# To be saved in /.firstrun.sh

# force regen of machine-id
rm -f /etc/machine-id
/usr/bin/dbus-uuidgen --ensure=/etc/machine-id

# ensure ssh host keys if ssh is installed
if [ -f /usr/bin/ssh-keygen ]; then
	/usr/bin/ssh-keygen -A
fi

# get internal API token
TOKEN="$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-shells-metadata-token-ttl-seconds: 300")"

# get various values from the API
SHELLS_HS="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/hostname")"
SHELLS_USERNAME="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/username")"
SHELLS_SHADOW="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/shadow")"
SHELLS_SSH="$(curl -s -H "X-shells-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/public-keys/*/openssh-key")"

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

# create user
if [ x"$SHELLS_USERNAME" != x ]; then
	# only create user if not existing yet
	id >/dev/null 2>&1 "$SHELLS_USERNAME" || useradd -G sudo,audio,video,plugdev,games,users --shell /bin/bash --create-home "$SHELLS_USERNAME"

	if [ x"$SHELLS_SHADOW" != x ]; then
		usermod -p "$SHELLS_SHADOW" "$SHELLS_USERNAME"
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

	if [ -f /etc/gdm3/custom.conf ]; then
		# replace "#  AutomaticLogin" → "  AutomaticLogin = xxx"
		sed -i -e "s/#? *AutomaticLogin.*/  AutomaticLogin = $SHELLS_USERNAME/" "/etc/gdm3/custom.conf"
	fi
	if [ -f /etc/gdm/custom.conf ]; then
		# replace "#  AutomaticLogin" → "  AutomaticLogin = xxx"
		sed -i -e "s/#? *AutomaticLogin.*/  AutomaticLogin = $SHELLS_USERNAME/" "/etc/gdm/custom.conf"
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

# complete, erase self
if [ -f /.firstrun.sh ]; then
	rm -f /.firstrun.sh && exit || exit
fi
