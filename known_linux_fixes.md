# Known Linux Fixes

Fixes for one image will sometimes work for another image if they share the same DE, base distribution, or other supporting software. These are some example fixes that may work, so it's worth looking through this if you're setting up a new image or debugging a common issue with an existing one.

## gdm3

Disable Wayland (SPICE doesn't work well with Wayland, xorg is preferred):
```
sed -i "/\[daemon]/a WaylandEnable=false" "$WORK/etc/gdm3/custom.conf"
```

## GNOME

Disabling sleep, suspend, and hibernating:
```
run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

## KDE

Disable locking:
```
cat >"$WORK/etc/skel/.config/kscreenlockerrc" <<EOF
[Daemon]
Autolock=false
LockOnResume=false
EOF
```

## LightDM

Logging in automatically, and also logging back in when the Logout button is pressed:
```
echo autologin-user=${SHELLS_USERNAME} >> /etc/lightdm/lightdm.conf.d/70-xubuntu.conf
echo autologin-user-timeout=0 >> /etc/lightdm/lightdm.conf.d/70-xubuntu.conf
echo session-cleanup-script=pkill -P1 -fx /usr/sbin/lightdm >> /etc/lightdm/lightdm.conf.d/70-xubuntu.conf
```

## PulseAudio

Fix sound being muted by default:
```
cat <<'EOF' >>"$WORK/etc/pulse/default.pa"
set-sink-volume 0 32768
set-sink-mute 0 0
EOF
```
