If you want to submit and/or maintain distribution of your choice for official Shells build, you must meet the following criteria:

* Make sure image is ready for Shells infrastructure (look for example into other OS build scripts here in repository).
* No password for users (we disable the passwords, enabled passwordless sudo and passwordless polkit auth in firstrun script, so keep that in mind).
* Set user to autologin (we try to achieve this in firstrun script but if you see difference not applying for your OS, be sure to do it).
* Disable power saving (screensavers, sleep, automatic logout etc).
* Be sure to have in your image spice-vdagent and qemu-guest-agent.
* Either disable logout or make it so users can't get stuck if they do log out (make sure they auto-login again immediately or they can click a login button / press enter to get logged in again).
* Disable sleep button if one exists (or make it do a no-op). We want to avoid images freezing up when the sleep button gets pressed.
* Disable lock button, or make it so that if the user does click it they can simply move the mouse or click to escape.
* Make sure the OS gets all latest updates when the image gets built. If your image requires a special update command (for example [pkcon](https://neon.kde.org/faq#command-to-update)) then make sure that is being run.
* Sound should work out of the box and not be muted.
* Be sure to have `https://github.com/Shells-com/shells-helper` installed on the image, so that notifications will be passed to the Shell host.

## Naming

All images are typically named as `distribution-version-variation`. For
example Ubuntu Focal with Ubuntu Desktop installed would be called
`ubuntu-focal-ubuntu-desktop`. All images providing a desktop environment must
end in `-desktop`.

## Custom kernel

By default Shells boots all images with the Shells kernel, which is a LTS
vanilla kernel built by the Shells team. This kernel comes with an initrd that
will perform a number of operations prior to booting the OS, such as ensuring
the modules are installed for the running kernel, resizing the disk partition
to use the whole disk, setup a swap partition, etc.

You can however supply your own kernel but will need to ensure the following:

* The image must be a 8GB or less BIOS-bootable bootable partition
* On boot, you should check if the disk is larger than the partition(s) cover,
  and resize the disk appropriately. If you have a swap partition you may
  consider moving it toward the end of the disk.
* Make sure you have the virtio modules enabled in your kernel, as well as
  anything required to run qxl if doing an desktop image.

