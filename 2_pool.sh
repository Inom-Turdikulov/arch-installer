#!/bin/bash
source vars

set -e

DISK_DRIVE_1="/dev/disk/by-id/$DISK_1"
DISK_DRIVE_2="/dev/disk/by-id/$DISK_2"

ls $DISK_DRIVE_1 $DISK_DRIVE_2

echo Format boot and swap partitions
mkfs.vfat $DISK_DRIVE_1-part1
#mkfs.vfat $DISK_DRIVE_2-part1

mkswap $DISK_DRIVE_1-part2
#mkswap $DISK_DRIVE_2-part2

echo Create swap
swapon $DISK_DRIVE_1-part2
#swapon $DISK_DRIVE_2-part2

echo Create zpool
zpool create \
    -O atime=off \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=lz4 \
    -O dnodesize=legacy \
    -O normalization=formD \
    -O xattr=sa \
    -O devices=off \
    -O mountpoint=none \
    -R /mnt rpool mirror $DISK_DRIVE_1-part3 $DISK_DRIVE_2-part3

echo Create datasets
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o mountpoint=/ -o canmount=noauto rpool/ROOT/default
zfs create -o setuid=off -o devices=off -o sync=disabled -o mountpoint=/tmp rpool/ROOT/tmp

zfs create -o mountpoint=none rpool/DATA
zfs create -o encryption=on -o keyformat=passphrase -o mountpoint=/home rpool/DATA/home
zfs create -o mountpoint=/root rpool/DATA/home/root
zfs create -o mountpoint=/local rpool/DATA/local
zfs create -o mountpoint=none rpool/DATA/var
zfs create -o mountpoint=/var/log rpool/DATA/var/log # after a rollback, systemd-journal blocks at reboot without this dataset
zpool set bootfs=rpool/ROOT/default rpool


echo Unmount all
zfs umount -a
rm -rf /mnt/*

echo Export/Reimport pool
zpool export rpool
zpool import -d /dev/disk/by-id -R /mnt rpool -N

echo Mount
zfs mount rpool/ROOT/default
zfs mount -a

echo Mount boot partition:
mkdir /mnt/boot
mount $DISK_DRIVE_1-part1 /mnt/boot

echo Generate fstab
mkdir /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab

echo Install the base system
pacstrap /mnt base base-devel linux linux-firmware neovim

echo Run chrot script