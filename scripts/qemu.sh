#!/bin/sh

QEMUSYS="$(which qemu-system-x86_64)"

qemukernel() {
	# arguments: qemukernel <qcow2 file> <kernel commandline opts>

	# ensure we have a kernel
	if [ ! -f shells-kernel/guest-linux-x86_64/release.txt ]; then
		getfile shells-kernel-5.4.99-684c6b0.tar.bz2 684c6b0ab4fd3ac8ba6f6b37c2f7b2d38e0c2d99a84bc578d358715f9185ce7c
		tar xjf shells-kernel-5.4.99-684c6b0.tar.bz2
	fi

	local KVER="$(cat shells-kernel/guest-linux-x86_64/release.txt)"
	echo "Running linux $KVER"

	local KERNEL="shells-kernel/guest-linux-x86_64/linux-${KVER}.img"
	local INITRD="shells-kernel/guest-linux-x86_64/initrd-${KVER}.img"
	local MODULES="shells-kernel/guest-linux-x86_64/modules-${KVER}.squashfs"

	OPTS=(
		-name guest=shell-xxxxxx-xxxx-xxxx-xxxx-xxxxxxxx,debug-threads=on
		# -object secret,id=masterKey0,format=raw,file=.../master-key.aes
		-machine q35,accel=kvm,usb=off,dump-guest-core=off
		-cpu qemu64,svm=off
		-m 8192 -overcommit mem-lock=off
		-smp 4,sockets=1,dies=1,cores=4,threads=1
		-uuid bdef7bde-f7bd-ef7b-def7-bdef7bdef7bd
		-no-user-config -nodefaults

		#-chardev socket,id=charmonitor,fd=30,server,nowait
		#-mon chardev=charmonitor,id=monitor,mode=control
		-rtc base=utc
		-boot strict=on
		-device i82801b11-bridge,id=pci.1,bus=pcie.0,addr=0x1e
		-device pci-bridge,chassis_nr=2,id=pci.2,bus=pci.1,addr=0x0
		-device pcie-root-port,port=0x10,chassis=3,id=pci.3,bus=pcie.0,multifunction=on,addr=0x2
		-device pcie-root-port,port=0x11,chassis=4,id=pci.4,bus=pcie.0,addr=0x2.0x1
		-device pcie-root-port,port=0x12,chassis=5,id=pci.5,bus=pcie.0,addr=0x2.0x2
		-device pcie-root-port,port=0x13,chassis=6,id=pci.6,bus=pcie.0,addr=0x2.0x3
		-device pcie-root-port,port=0x14,chassis=7,id=pci.7,bus=pcie.0,addr=0x2.0x4
		-device pcie-root-port,port=0x15,chassis=8,id=pci.8,bus=pcie.0,addr=0x2.0x5
		-device qemu-xhci,p2=8,p3=8,id=usb,bus=pci.4,addr=0x0
		-device virtio-serial-pci,id=virtio-serial0,bus=pci.5,addr=0x0
		-blockdev "{\"driver\":\"file\",\"filename\":\"$1\",\"node-name\":\"libvirt-1-storage\",\"auto-read-only\":true,\"discard\":\"unmap\"}"
		-blockdev '{"node-name":"libvirt-1-format","read-only":false,"driver":"qcow2","file":"libvirt-1-storage"}'
		-device virtio-blk-pci,bus=pci.6,addr=0x0,drive=libvirt-1-format,id=virtio-disk0,bootindex=1
		-netdev user,id=hostnet0,hostfwd=tcp::10022-:22
		-device virtio-net-pci,netdev=hostnet0,id=net0,mac=d2:89:f4:90:ee:76,bus=pci.3,addr=0x0
		-chardev stdio,id=charserial0
		-device isa-serial,chardev=charserial0,id=serial0
		#-chardev socket,id=charchannel0,fd=34,server,nowait
		#-device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=org.qemu.guest_agent.0
		-chardev spicevmc,id=charchannel1,name=vdagent
		-device virtserialport,bus=virtio-serial0.0,nr=2,chardev=charchannel1,id=channel1,name=com.redhat.spice.0
		-chardev spiceport,id=charchannel2,name=org.spice-space.stream.0
		-device virtserialport,bus=virtio-serial0.0,nr=3,chardev=charchannel2,id=channel2,name=org.spice-space.stream.0
		-chardev spiceport,id=charchannel3,name=org.spice-space.webdav.0
		-device virtserialport,bus=virtio-serial0.0,nr=4,chardev=charchannel3,id=channel3,name=org.spice-space.webdav.0
		-device usb-tablet,id=input2,bus=usb.0,port=1
		-spice port=19308,addr=127.0.0.1,image-compression=auto_glz,jpeg-wan-compression=always,zlib-glz-wan-compression=always,playback-compression=on,seamless-migration=on
		-device qxl-vga,id=video0,ram_size=67108864,vram_size=16777216,vram64_size_mb=0,vgamem_mb=16,max_outputs=1,bus=pcie.0,addr=0x1
		-device intel-hda,id=sound0,bus=pci.2,addr=0x1
		-device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0
		#-chardev spicevmc,id=charredir0,name=usbredir
		#-device usb-redir,chardev=charredir0,id=redir0,bus=usb.0,port=2
		#-chardev spicevmc,id=charredir1,name=usbredir
		#-device usb-redir,chardev=charredir1,id=redir1,bus=usb.0,port=3
		#-chardev spicevmc,id=charredir2,name=usbredir
		#-device usb-redir,chardev=charredir2,id=redir2,bus=usb.0,port=4
		-device virtio-balloon-pci,id=balloon0,bus=pci.8,addr=0x0
		-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
		-msg timestamp=on
		-display gtk

		# since we use kernel boot
		-blockdev '{"driver":"file","filename":"'"$MODULES"'","node-name":"modules-storage","auto-read-only":true,"discard":"unmap"}'
		-blockdev '{"node-name":"modules-format","read-only":true,"driver":"raw","file":"modules-storage"}'
		-device virtio-blk-pci,bus=pci.7,addr=0x0,drive=modules-format,id=virtio-disk23
		-kernel "$KERNEL"
		-initrd "$INITRD"
		-append "rw $2"
	)

	"$QEMUSYS" "${OPTS[@]}"
}
