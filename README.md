# Linux scripts for Shells™

This repository includes scripts used for building Linux images used on Shells™.

To run these scripts you need to have relevant packages installed on your machine:

## sudo apt install git qemu qemu-utils qemu-system php8.1 debootstrap squashfs-tools jq

After which you clone this repo and run the build (and test scripts).

# build_image.sh

This script will build an image for a given distibution.

For example:

	./build_image.sh ubuntu-focal-ubuntu-desktop
	
For list of currently available builds, take a look at [official_images.txt](https://github.com/Shells-com/linux-scripts/blob/master/official_images.txt).

# Submit/maintain your distribution

Shells wants to help Linux community as much as it can, so if you would like to see your own distribution on the list, submit PR with it and we will gladly merge it. Be sure to read about some simple rules around how to build images for Shells at [os_requirements.md](https://github.com/Shells-com/linux-scripts/blob/master/os_requirements.md).

# Testing

It is possible to test Shells images prior to shipping.

	$ ./test-linux.sh generated-disk-image.qcow2

This will run the disk image inside qemu with a configuration similar to what is used on Shells. The machine will run with a special UUID recognized by first run that will create a "test" user with password "test".

During testing, an overlay with the name `xxx_test.qcow2` will be generated and changes will be written there (the original .qcow2 file won't be modified in test mode). Erasing this file allows returning to the initial state.
