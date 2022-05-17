## Building and running [Linux From Scratch Version 11.1](https://www.linuxfromscratch.org/lfs/view/11.1/) inside Qemu/KVM

We will use Qemu and Libvirt VM to ensure compatibility with Mac's with m1 chip where virtualbox is not available. But it is highly recommended to use x86_64 system for native virtualization with KVM

- Install QEMU `sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils`
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
```
- Open VNCViewer or Remmina and connect to localhost:5900
- Install Ubuntu Server with Open SSH server and without LVM using full 30gb disk and reboot
- Now you can connect with `ssh -p 2222 your_user@localhost`
- In the VM run `sudo fdisk /dev/vdb` then create GPT table 13G partition for root and 2G partition for swap and choose Linux swap type for swap partition then Write and Quit
- Then format partition and mount it
```sh
export LFS=/mnt/lfs
# For persistance after reboot/shutdown
echo "export LFS=/mnt/lfs" >> .bashrc

sudo mkdir -pv $LFS
sudo mkfs -v -t ext4 /dev/vdb1
sudo mount -v -t ext4 /dev/vdb1 $LFS

# For persistance after reboot/shutdown
echo "/dev/vdb1  $LFS ext4   defaults      1     1" | sudo tee -a /etc/fstab
```
- And finally got to scripts and run them 0 to 14
- Shutdown vm
- Modify `lfs.xml` to point it to the lfs.qcow2 disk
```xml
        <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2'/>
            <source file='ABSOLUTE_LFS_DISK_PATH'/>
            <target dev='vda' bus='virtio'/>
        </disk>
```
- Define VM and start it
```sh
virsh define lfs.xml
virsh start lfs
```
- Login using `root` username and password you chose in step 8


## SSH

Enable Root login with password is /etc/ssh/sshd_config
```
PasswordAuthentication yes
PermitRootLogin yes
```
Now you can connect to your LFS with ssh
```sh
ssh -p 2223 root@localhost
```