#!/bin/bash
source vars

set -e

DISK_DRIVE_1="/dev/disk/by-id/$DISK_1"
DISK_DRIVE_2="/dev/disk/by-id/$DISK_2"

ls $DISK_DRIVE_1 $DISK_DRIVE_2

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
