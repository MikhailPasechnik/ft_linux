#!/bin/bash
set -e

# https://www.linuxfromscratch.org/lfs/view/stable/chapter08/man-pages.html

if [[ -z "${LFS}" ]]; then
    echo "No LFS env!"
    exit
else
    echo "LFS at ${LFS}"
fi


sudo chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    /bin/bash --login +h -x <<'HEOF'
set -e
export MAKEFLAGS="-j6"


cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/vda1      /            ext4     defaults            1     1
/dev/vda2      swap         swap     pri=1               0     0
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0

# End /etc/fstab
EOF

cd /sources
tar -xf linux-5.16.9.tar.xz
cd linux-5.16.9

make mrproper
make defconfig

# https://github.com/fedorenchik/lfs-kvm/blob/main/09-system-config.sh
sed -e 's/.*\bCONFIG_UEVENT_HELPER\b.*/# CONFIG_UEVENT_HELPER is not set (required by LFS)/' -i .config
sed -e 's/.*\bCONFIG_DEVTMPFS\b.*/CONFIG_DEVTMPFS=y/' -i .config
sed -e 's/.*\bCONFIG_EFI_STUB\b.*/CONFIG_EFI_STUB=y/' -i .config
sed -e 's/.*\bCONFIG_EXT4_FS\b.*/CONFIG_EXT4_FS=y/' -i .config
sed -e 's/.*\bCONFIG_VIRTIO_BLK\b.*/CONFIG_VIRTIO_BLK=y/' -i .config
sed -e 's/.*\bCONFIG_SCSI_VIRTIO\b.*/CONFIG_SCSI_VIRTIO=y/' -i .config
sed -e 's/.*\bCONFIG_VIRTIO_CONSOLE\b.*/CONFIG_VIRTIO_CONSOLE=y/' -i .config
sed -e 's/.*\bCONFIG_VIRTIO_PCI\b.*/CONFIG_VIRTIO_PCI=y/' -i .config
cat >> .config << "EOF"
CONFIG_VIRTIO_BLK=y
CONFIG_SCSI_VIRTIO=y
CONFIG_VIRTIO_PCI=y
EOF

make
make modules_install
cp -iv arch/x86_64/boot/bzImage /boot/vmlinuz-5.16.9-lfs-11.1
cp -iv System.map /boot/System.map-5.16.9
cp -iv .config /boot/config-5.16.9
install -d /usr/share/doc/linux-5.16.9
cp -r Documentation/* /usr/share/doc/linux-5.16.9

install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF


HEOF
