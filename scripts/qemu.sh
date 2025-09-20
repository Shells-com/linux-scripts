#!/bin/sh

doqemu() {
	local DISK="$1"
	shift

	if [ x"$ARCH" = x ]; then
		ARCH=x86_64
	fi
	local MACHINE="q35"
	local CPU="max"
	local VIDEO="cirrus-vga" # "virtio-gpu-pci"

	case "$ARCH" in
		x86_64)
			MACHINE="q35,accel=kvm,usb=off,dump-guest-core=off"
			CPU="qemu64,svm=off,vmx=on,vmx-vnmi=on"
			VIDEO="qxl-vga,ram_size=67108864,vram_size=16777216,vram64_size_mb=0,vgamem_mb=16,max_outputs=1"
			;;
		aarch64)
			MACHINE="virt"
			;;
		arm64)
			ARCH="aarch64"
			MACHINE="virt"
			;;
		ppc64)
			MACHINE="pseries"
			;;
		*)
			echo "unsupported value for ARCH; $ARCH"
			exit 1
	esac

	local QEMUSYS="$(command -v "qemu-system-$ARCH")"

	OPTS=(
		-name guest=shell-xxxxxx-xxxx-xxxx-xxxx-xxxxxxxx,debug-threads=on
		# -object secret,id=masterKey0,format=raw,file=.../master-key.aes
		-machine "$MACHINE"
		-cpu "$CPU"
		-m 8192 -overcommit mem-lock=off
		-smp 4,sockets=1,dies=1,cores=4,threads=1
		-uuid bdef7bde-f7bd-ef7b-def7-bdef7bdef7bd
		-no-user-config -nodefaults

		-chardev vc,id=charmonitor
		-mon chardev=charmonitor,id=monitor
		-rtc base=utc
		-boot strict=on
		-device i82801b11-bridge,id=pci.1,bus=pcie.0,addr=0x1e
		-device pci-bridge,chassis_nr=2,id=pci.2,bus=pci.1,addr=0x0
		-device pcie-root-port,port=0x10,chassis=3,id=pci.3,bus=pcie.0,multifunction=on,addr=0x2
		-device pcie-root-port,port=0x11,chassis=4,id=pci.4,bus=pcie.0,addr=0x2.0x1
		-device pcie-root-port,port=0x12,chassis=5,id=pci.5,bus=pcie.0,addr=0x2.0x2
		-device pcie-root-port,port=0x13,chassis=6,id=pci.6,bus=pcie.0,addr=0x2.0x3
		-device pcie-root-port,port=0x14,chassis=7,id=pci.7,bus=pcie.0,addr=0x2.0x4
		-device pcie-root-port,port=0x15,chassis=2,id=pci3.1,bus=pcie.0,multifunction=on,addr=0x3
		-device qemu-xhci,p2=8,p3=8,id=usb,bus=pci.4,addr=0x0
		#-device nec-usb-xhci,p2=8,p3=8,id=usb,bus=pci.4,addr=0x0
		-device usb-ehci,bus=pci.2,addr=0x2,id=ehci
		-device virtio-serial-pci,id=virtio-serial0,bus=pci.5,addr=0x0
		-blockdev "{\"driver\":\"file\",\"filename\":\"$DISK\",\"node-name\":\"libvirt-1-storage\",\"auto-read-only\":true,\"discard\":\"unmap\"}"
		-blockdev '{"node-name":"libvirt-1-format","read-only":false,"driver":"qcow2","file":"libvirt-1-storage"}'
		-device virtio-blk-pci,bus=pci.6,addr=0x0,drive=libvirt-1-format,id=virtio-disk0,bootindex=1,logical_block_size=4096,physical_block_size=4096,min_io_size=4096,opt_io_size=1048576
		-netdev user,id=hostnet0,hostfwd=tcp::10022-:22
		#-netdev socket,id=hostnet0,connect=:4221
		-device virtio-net-pci,netdev=hostnet0,id=net0,mac=d2:89:f4:90:ee:76,bus=pci.3,addr=0x0
		-chardev vc,id=ttyS0
		-device pci-serial,chardev=ttyS0,id=serial0,bus=pcie.0,addr=0x3.0x1
		-chardev vc,id=ttyS1
		-device pci-serial,chardev=ttyS1,id=serial1,bus=pcie.0,addr=0x3.0x2
		-chardev vc,id=ttyS2
		-device pci-serial,chardev=ttyS2,id=serial2,bus=pcie.0,addr=0x3.0x3
		-chardev socket,id=ttyUSB0,host=127.0.0.1,port=4281,reconnect=10
		-device usb-serial,chardev=ttyUSB0,id=serialu0,bus=usb.0,port=2
		-chardev vc,id=ttyUSB1
		-device usb-serial,chardev=ttyUSB1,id=serialu1,bus=usb.0,port=3

		-chardev socket,id=charchannel0,path=/tmp/qga.sock,server=on,wait=off
		-device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=org.qemu.guest_agent.0
		-chardev spicevmc,id=charchannel1,name=vdagent
		-device virtserialport,bus=virtio-serial0.0,nr=2,chardev=charchannel1,id=channel1,name=com.redhat.spice.0
		-chardev spiceport,id=charchannel2,name=org.spice-space.stream.0
		-device virtserialport,bus=virtio-serial0.0,nr=3,chardev=charchannel2,id=channel2,name=org.spice-space.stream.0
		-chardev spiceport,id=charchannel3,name=org.spice-space.webdav.0
		-device virtserialport,bus=virtio-serial0.0,nr=4,chardev=charchannel3,id=channel3,name=org.spice-space.webdav.0
		-device usb-tablet,id=input2,bus=usb.0,port=1
		-spice port=19308,addr=127.0.0.1,image-compression=auto_glz,jpeg-wan-compression=always,zlib-glz-wan-compression=always,playback-compression=on,seamless-migration=on
		-device "$VIDEO,id=video0,bus=pcie.0,addr=0x1"
		-device intel-hda,id=sound0,bus=pci.2,addr=0x1
		-device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0
		-audio driver=none
		#-chardev spicevmc,id=charredir0,name=usbredir
		#-device usb-redir,chardev=charredir0,id=redir0,bus=usb.0,port=2
		#-chardev spicevmc,id=charredir1,name=usbredir
		#-device usb-redir,chardev=charredir1,id=redir1,bus=usb.0,port=3
		#-chardev spicevmc,id=charredir2,name=usbredir
		#-device usb-redir,chardev=charredir2,id=redir2,bus=usb.0,port=4
		-device virtio-balloon-pci,id=balloon0,bus=pci.7,addr=0x0
		-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
		-msg timestamp=on
		-display gtk

		"$@"
	)

	"$QEMUSYS" "${OPTS[@]}"
}

qemukernel() {
	# arguments: qemukernel <qcow2 file> <kernel commandline opts>

	# ensure we have a kernel
	KVER=""
	if [ -f shells-kernel/guest-linux-x86_64/release.txt ]; then
		KVER="$(cat shells-kernel/guest-linux-x86_64/release.txt)"
	fi
	if [ x"$KVER" != x"6.12.47-shells" ]; then
		getfile shells-kernel-6.12.47-9171e9f.tar.bz2 9171e9fb4e0519f266b3106a6d2257168f7babca2705ea4ddd37f4981d66410c
		tar xjf shells-kernel-6.12.47-9171e9f.tar.bz2
	fi

	if [ x"$ARCH" = x ]; then
		ARCH=x86_64
	fi

	local KARCH="x86_64"

	case $ARCH in
		aarch64)
			KARCH="arm64"
			;;
		*)
			KARCH="$ARCH"
			;;
	esac

	local KVER="$(cat shells-kernel/guest-linux-$KARCH/release.txt)"
	echo "Running linux $KVER"

	local KERNEL="shells-kernel/guest-linux-$KARCH/linux-${KVER}.img"
	local INITRD="shells-kernel/guest-linux-$KARCH/initrd-${KVER}.img"
	local MODULES="shells-kernel/guest-linux-$KARCH/modules-${KVER}.squashfs"

	OPTS=(
		-device pcie-root-port,port=0x15,chassis=8,id=pci.8,bus=pcie.0,addr=0x2.0x5
		# since we use kernel boot
		-blockdev '{"driver":"file","filename":"'"$MODULES"'","node-name":"modules-storage","auto-read-only":true,"discard":"unmap"}'
		-blockdev '{"node-name":"modules-format","read-only":true,"driver":"raw","file":"modules-storage"}'
		-device virtio-blk-pci,bus=pci.8,addr=0x0,drive=modules-format,id=virtio-disk23
		-kernel "$KERNEL"
		-initrd "$INITRD"
		-append "rw $2"
	)

	doqemu "$1" "${OPTS[@]}"
}

qemubios() {
	doqemu "$1"
}
