#!/bin/bash
# export ROOT_PASSWORD=
# export DISK_1=
# export DISK_2=
source vars

set -e

DISK_DRIVE_1="/dev/disk/by-id/$DISK_1"
DISK_DRIVE_2="/dev/disk/by-id/$DISK_2"

ls $DISK_DRIVE_1 $DISK_DRIVE_2

sgdisk --zap-all $DISK_DRIVE_1
sgdisk -n1:0:+512M -t1:ef00 $DISK_DRIVE_1
sgdisk -n2:0:+8G -t2:8200 $DISK_DRIVE_1
sgdisk -n3:0:0 -t3:bf00 $DISK_DRIVE_1

sgdisk --zap-all $DISK_DRIVE_2
sgdisk -n1:0:+512M -t1:ef00 $DISK_DRIVE_2
sgdisk -n2:0:+8G -t2:8200 $DISK_DRIVE_2
sgdisk -n3:0:0 -t3:bf00 $DISK_DRIVE_2
echo "You need reboot"
