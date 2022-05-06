## Building from scratch

We will use Qemu and Libvirt VM to ensure compatibility with Mac's with m1 chip where virtualbox is not available.

- Install QEMU `brew install qemu`
- Install libvirt `brew install libvirt`
- Install VNC Viewer `brew install --cask vnc-viewer`
- Download `ubuntu-22.04-live-server-amd64.iso` from official repository
- Create 30gb disk for ubuntu to build LFS `qemu-img create -f qcow2 ubuntu.qcow2 30g`
- Create 15gb disk for lfs build `qemu-img create -f qcow2 lfs.qcow2 15g`
- Modify `ubuntu.xml` to point it to the new disk and iso by changing ABSOLUTE_DISK_PATH ABSOLUTE_ISO_PATH to the absolute path of the qcow2 disk file and downloaded iso image

```xml
        <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2'/>
            <source file='ABSOLUTE_UBUNTU_DISK_PATH'/>
            <target dev='vda' bus='virtio'/>
        </disk>
        <disk type='file' device='cdrom'>
            <source file='ABSOLUTE_ISO_PATH'/>
            <target dev='sdb' bus='sata'/>
        </disk>
        <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2'/>
            <source file='ABSOLUTE_LFS_DISK_PATH'/>
            <target dev='vdb' bus='virtio'/>
        </disk>
```

- Register VM, run, and connect with VNC

```sh
virsh define ubuntu.xml
virsh start ubuntu
# Open VNC Viewer and connect to 127.0.0.1:5900
```
- Install Ubuntu Server with Open SSH server and without LVM using full 50gb disk
- NOTE: After reboot prompt it will stuck at cdrom unmount run `virsh destroy ubuntu` and then `virsh start ubuntu`
- Now you can connect with `ssh -p 2222 your_user@localhost`
- In the VM run `sudo fdisk /dev/vdb` then create partition then Write and Quit
- Then format partition and mount it
```sh
export LFS=/mnt/lfs
# For persistance after reboot/shutdown
echo "export LFS=/mnt/lfs" >> .bashrc

sudo mkdir -pv $LFS
sudo mkfs -v -t ext4 /dev/vdb1
sudo mount -v -t ext4 /dev/vdb1 $LFS

# For persistance after reboot/shutdown
sudo echo "/dev/vdb1  $LFS ext4   defaults      1     1" >> /etc/fstab
```
