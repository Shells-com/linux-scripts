#!/bin/bash

do_linux_config() {
	do_linux_init_config
	do_linux_polkit_config
}

do_linux_init_config() {
	# initial config for all linux installs
	cat "$WORK/etc/group" | grep -q ^shellsmgmt: || run /usr/sbin/groupadd shellsmgmt
}

do_linux_polkit_config() {
	# configuration for polkit
	if [ -d "$WORK/etc/polkit-1/localauthority/50-local.d/" ]; then
		# create polkit password skip option (see https://askubuntu.com/questions/614534/disable-authentication-prompts-in-15-04/614537#614537 )
		cat >"$WORK/etc/polkit-1/localauthority/50-local.d/99-shells.pkla" <<EOF
[No password prompt]
Identity=unix-group:shellsmgmt
Action=*
ResultActive=yes
EOF
	elif [ -d "$WORK/etc/polkit-1/rules.d/" ]; then
		cat >"$WORK/etc/polkit-1/rules.d/49-nopasswd_shells.rules" <<EOF
// rules for all distros
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("shellsmgmt")) {
        return polkit.Result.YES;
    }
});
EOF
	else
		echo "polkit: skipping configuration as directory was not found"
	fi
}
