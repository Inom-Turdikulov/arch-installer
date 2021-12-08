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
zpool create -f \
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


