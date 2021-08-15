## Prepare
Download iso & signature from https://archlinux.org/download/
In my case `archlinux-2021.08.01-x86_64.iso.sig` and `archlinux-2021.08.01-x86_64.iso`

Verify sha1 checksum (replace archlinux-2021.08.01-x86_64.iso with your image path, image can be in download directory)
```
cd ~/downloads # optional
sha1sum archlinux-2021.08.01-x86_64.iso
# 4904c8a6df8bac8291b7b7582c26c4da9439f1cf
```

Compare checksumm with listed on site:
...
SHA1: 4904c8a6df8bac8291b7b7582c26c4da9439f1cf

Verify signature

```
gpg --keyserver-options auto-key-retrieve --verify archlinux-2021.08.01-x86_64.iso.sig
```
Primary key fingerprint: `4AA4 767B BC9C 4B1D 18AE  28B7 7F2D 434B 9741 E8AC`

Same as fingerprint from downloads pages
PGP fingerprint: 0x9741E8AC (0x9741E8AC - is clickable).

## Install zfs

curl -s https://raw.githubusercontent.com/inomoz/archiso-zfs-1/master/init | bash

## Arch Linux Root on ZFS

Installation steps for running Arch Linux with root on ZFS using UEFI and ```systemd-boot```. All steps are run as ```root```.

### In live environment

- Set a bigger font if needed:

```
setfont latarcyrheb-sun32
```

- To connect to the internet add the *ESSID* and passphrase:
```
 wpa_passphrase ESSID PASSPHRASE > /etc/wpa_supplicant/wpa_supplicant.conf
```

- Start *wpa_supplicant* and get an IP address:

```
wpa_supplicant -B -c /etc/wpa_supplicant/wpa_supplicant.conf -i <wifi interface>
dhclient <wifi interface>
```

- Wipe disks, create *boot*, *swap* and ZFS partitions:
```
ls /dev/disk/by-id/
DISK_DRIVE=/dev/disk/by-id/<disk0> # replace <disk0> with your drive

sgdisk --zap-all $DISK_DRIVE
sgdisk -n1:0:+512M -t1:ef00 /dev/disk/by-id/<disk0>
sgdisk -n2:0:+8G -t2:8200 /dev/disk/by-id/<disk0>
sgdisk -n3:0:+210G -t3:bf00 /dev/disk/by-id/<disk0>

sgdisk --zap-all /dev/disk/by-id/<disk1>
sgdisk -n1:0:+512M -t1:ef00 /dev/disk/by-id/<disk1>
sgdisk -n2:0:+8G -t2:8200 /dev/disk/by-id/<disk1>
sgdisk -n3:0:+210G -t3:bf00 /dev/disk/by-id/<disk1>

```
You can also use a ```zvol``` for swap, but see [this](https://wiki.archlinux.org/index.php/ZFS#Swap_volume) first.

- Format boot and swap partitions
```
mkfs.vfat /dev/disk/by-id/<disk0>-part1
mkfs.vfat /dev/disk/by-id/<disk1>-part1

mkswap /dev/disk/by-id/<disk0>-part2
mkswap /dev/disk/by-id/<disk1>-part2
```
- Create swap
```
swapon /dev/disk/by-id/<disk0>-part2 /dev/disk/by-id/<disk1>-part2
```

- On choosing ```ashift```

*You should specify an ashift when that value is too low for what you actually need, either today (disk lies) or into the future (replacement disks will be AF)*. Looks like a sound advice to me. If in doubt, [clarify](https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/) before going any further. I will go with the defaults here, which will trigger autodetection.

Disk block size check:
```
cat /sys/class/block/<disk>/queue/{phys,log}ical_block_size
```

- Create pool (here's for a RAID 0 equivalent):
```
zpool create -f mymirrorpoolname1 mirror sdb sdc

sudo zpool create  -f [new pool name] mirror /dev/sdb /dev/sdc

# regular linux distro however, I recommend to always set the flags as follows: acltype=posixacl xattr=sa

zpool create \
    -O atime=off \
    -O acltype=posixacl
    -O canmount=off
    -O compression=lz4 \
    -O dnodesize=legacy \
    -O normalization=formD \
    -O xattr=sa \
    -O devices=off \
    -O mountpoint=none \
    -R /mnt  rpool $DISK_DRIVE_0-part3 /dev/disk/by-id/$DISK_DRIVE_1-part3
```

If the pool is larger than 10 disks you should identify them ```by-path``` or ```by-vdev``` (see [here](https://openzfs.github.io/openzfs-docs/Project%20and%20Community/FAQ.html#selecting-dev-names-when-creating-a-pool-linux) for more details).

Check ```ashift``` with:

```
zdb -C | grep ashift
```

- Create datasets:
```
zfs create -o canmount=off -o mountpoint=none rpool/ROOT

zfs create -o mountpoint=/ -o canmount=noauto rpool/ROOT/default

zfs create -o mountpoint=none rpool/DATA

zfs create -o mountpoint=/home rpool/DATA/home

zfs create -o mountpoint=/root rpool/DATA/home/root

zfs create -o mountpoint=/local rpool/DATA/local

zfs create -o mountpoint=none rpool/DATA/var

zfs create -o mountpoint=/var/log rpool/DATA/var/log # after a rollback, systemd-journal blocks at reboot without this dataset

zpool set bootfs=rpool/ROOT/default rpool
```

- Create swap (not needed if you have dedicated partitions, like above)

```
zfs create -V 16G -b $(getconf PAGESIZE) -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false rpool/swap
mkswap /dev/zvol/rpool/swap
```

- Unmount all
```
zfs umount -a
rm -rf /mnt/*
```

- *Export pool*:
```
zpool export rpool
```

- Re import it:
```
zpool import -d /dev/disk/by-id -R /mnt rpool -N
```

- Mount root, then the other datasets:
```
zfs mount rpool/ROOT/default
zfs mount -a
```

- Mount boot partition:
```
mkdir /mnt/boot
mount /dev/disk/by-id/<disk0>-part1 /mnt/boot
```

- Generate **fstab**:
```
mkdir /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab
```

- Add swap (not needed if you created swap partitions, like above):
```
echo "/dev/zvol/rpool/swap    none       swap  discard                    0  0" >> /mnt/etc/fstab
```

- Install the base system:
```
pacstrap /mnt base base-devel linux linux-firmware vim
```
If it fails, add GPG keys (see bellow).

- Change root into the new system:
```
arch-chroot /mnt
```
### In chroot

- Remove all lines in ```/etc/fstab```, leaving only the entries for ```swap``` and ```boot```.

- Add ZFS repository in ```/etc/pacman.conf```:
```
[archzfs]
Server = http://archzfs.com/$repo/x86_64
```

- Add GPG keys:
```
curl -O https://archzfs.com/archzfs.gpg
pacman-key -a archzfs.gpg
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman -Syy
```

- Configure time zone (change accordingly):
```
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc
```

- Generate locale (change accordingly):
```
sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

- Configure **vconsole**, **hostname**, **hosts**:
```
echo -e "KEYMAP=us\n#FONT=latarcyrheb-sun32" > /etc/vconsole.conf
echo al-zfs > /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost" >> /etc/hosts
```

- Set root password

- Install ZFS, microcode etc:
```bash
pacman -Syu archzfs-linux amd-ucode networkmanager sudo openssh rsync borg
```
I choose the default options for the *archzfs-linux* group: ```zfs-linux```, ```zfs-utils```, and ```mkinitcpio``` for initramfs.

For Intel processors install ```intel-ucode``` instead of ```amd-ucode```.

- Generate host id:
```
zgenhostid $(hostid)
```

- Create cache file:
```
zpool set cachefile=/etc/zfs/zpool.cache rpool
```

- Configure initial ramdisk in ```/etc/mkinitcpio.conf```:
```
HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
```
and regenerate it:
```
mkinitcpio -p linux
```

- Enable ZFS services:
```
systemctl enable zfs.target
systemctl enable zfs-import-cache.service
systemctl enable zfs-mount.service
systemctl enable zfs-import.target
```

- Install the bootloader:
```
bootctl --path=/boot install
```
- Add an EFI boot manager update hook in */etc/pacman.d/hooks/100-systemd-boot.hook*:
```
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = update systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
```

- Replace content of */boot/loader/loader.conf* with:
```
default arch
timeout 3
# bigger boot menu on a 4K laptop display
#console-mode 1
```
- Create a */boot/loader/entries/**arch**.conf* containing:
```
title Arch Linux
linux /vmlinuz-linux
initrd /amd-ucode.img
initrd /initramfs-linux.img
options zfs=rpool/ROOT/default rw
```
If using an Intel processor, replace ```/amd-ucode.img``` with ```/intel-ucode.img```.
- Exit and unmount all:
```
exit
zfs umount -a
umount -R /mnt
```

- *Export pool*:
```
zpool export rpool
```

- Reboot

A minimal Arch Linux system with root on ZFS should now be configured.

### Optional

- Create user
```
zfs create -o mountpoint=/home/user rpool/DATA/home/user
groupadd -g 1234 group
useradd -g group -u 1234 -d /home/user -s /bin/bash user
cp /etc/skel/.bash* /home/user
chown -R user:group /home/user && chmod 700 /home/user
```

- Create non-root pools:
```
zpool create \
    -O atime=off \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O dnodesize=auto \
    -O xattr=sa -O devices=off -O mountpoint=none pool:a /dev/disk/by-id/<disk2> /dev/disk/by-id/<disk3>

zpool create \
    -O atime=off \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O dnodesize=auto \
    -O xattr=sa -O devices=off -O mountpoint=none pool:b mirror /dev/disk/by-id/<disk4> /dev/disk/by-id/<disk5> mirror /dev/disk/by-id/<disk6> /dev/disk/by-id/<disk7>
```

- Create non-root datasets:
```
zfs create -o canmount=off -o mountpoint=none pool:a/DATA
zfs create -o mountpoint=/path pool:a/DATA/path
zfs create -o mountpoint=/path/games -o recordsize=1M pool:a/DATA/path/games
zfs create -o mountpoint=/path/transmission -o recordsize=1M pool:a/DATA/path/transmission
zfs create -o mountpoint=/path/backup -o compression=off pool:a/DATA/path/backup
```

- Create NFS share:

Set *Domain* in ```idmapd.conf``` on server and clients.
```
zfs set sharenfs=rw=@10.0.0.0/24 pool:a/DATA/path/name
systemctl enable nfs-server.service zfs-share.service --now
```

- Postinstall
  https://github.com/inomoz/spark/
___

#### References:

1. [https://wiki.archlinux.org/index.php/Install_Arch_Linux_on_ZFS](https://wiki.archlinux.org/index.php/Install_Arch_Linux_on_ZFS)
2. [https://wiki.archlinux.org/index.php/ZFS](https://wiki.archlinux.org/index.php/ZFS)
3. [https://ramsdenj.com/2016/06/23/arch-linux-on-zfs-part-2-installation.html](https://ramsdenj.com/2016/06/23/arch-linux-on-zfs-part-2-installation.html)
4. [https://github.com/reconquest/archiso-zfs](https://github.com/reconquest/archiso-zfs)
5. [https://zedenv.readthedocs.io/en/latest/setup.html](https://zedenv.readthedocs.io/en/latest/setup.html)
6. [https://docs.oracle.com/cd/E37838_01/html/E60980/index.html](https://docs.oracle.com/cd/E37838_01/html/E60980/index.html)
7. [https://ramsdenj.com/2020/03/18/zectl-zfs-boot-environment-manager-for-linux.html](https://ramsdenj.com/2020/03/18/zectl-zfs-boot-environment-manager-for-linux.html)
8. [https://superuser.com/questions/1310927/what-is-the-absolute-minimum-size-a-uefi-partition-can-be](https://superuser.com/questions/1310927/what-is-the-absolute-minimum-size-a-uefi-partition-can-be), [https://systemd.io/9OOT_LOADER_SPECIFICATION/](https://systemd.io/BOOT_LOADER_SPECIFICATION/)
9. [OpenZFS Admin Documentation](https://openzfs.github.io/openzfs-docs/Project%20and%20Community/Admin%20Documentation.html)
10. [zfs(8)](https://openzfs.github.io/openzfs-docs/man/8/zfs.8.html)
11. [zpool(8)](https://openzfs.github.io/openzfs-docs/man/8/zpool.8.html)
12. [https://jrs-s.net/category/open-source/zfs/](https://jrs-s.net/category/open-source/zfs/)
13. [https://github.com/ewwhite/zfs-ha/wiki](https://github.com/ewwhite/zfs-ha/wiki)
14. [http://nex7.blogspot.com/2013/03/readme1st.html](http://nex7.blogspot.com/2013/03/readme1st.html)
15. [https://kiljan.org/2018/09/23/a-reference-guide-to-zfs-on-arch-linux/#addzfstoarch](https://kiljan.org/2018/09/23/a-reference-guide-to-zfs-on-arch-linux/)
