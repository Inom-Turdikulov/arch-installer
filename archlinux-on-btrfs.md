# Arch Linux on Btrfs RAID1
## Setup instalation via SSH
1. Set a root password `passwd`
2. Confirm that PermitRootLogin yes is set in /etc/ssh/sshd_config. If it is not, set it and reload the OpenSSH daemon sshd.service 
3. On the local machine, connect to the target machine via SSH with the following command: `ssh root@ip.address.of.target`

## Prepare
```
pacman -Syy # update mirrors

# Set disk drives
DISK_DRIVE_1="/dev/disk/by-id/..."
DISK_DRIVE_2="/dev/disk/by-id/..."
[ -z "$DISK_DRIVE_1" ] && echo "Warning $DISK_DRIVE_1 Empty"
[ -z "$DISK_DRIVE_2" ] && echo "Warning $DISK_DRIVE_2 Empty"
```

## Wipe existing disk
```
# cleanup partition information
sgdisk --zap-all $DISK_DRIVE_1
sgdisk --zap-all $DISK_DRIVE_2

# one pass, with entropy from e.g. /dev/urandom, and a final overwrite with zeros.
shred --verbose --random-source=/dev/urandom -n1 --zero $DISK_DRIVE_1
shred --verbose --random-source=/dev/urandom -n1 --zero $DISK_DRIVE_2
```

## Partitioning
Since we use cgdisk, it use 1 MiB alignment automatically (useful for perfomance). 
```
# create two partitions on each disks
cgdisk $DISK_DRIVE_1
```
o - Override partition table

Create an EFI (EF00) partition with the last possible ID (128):
n, 128, [ENTER], +64M, EF00

### Create a BOOT partition:
> First sector...:
\n
> Size in sectors or {KMGTP} (default = ...): 
500M
> Hex code or GUID (L to show codes, Enter = 8300): 
\n
> Enter new partition name, or <Enter> to use the current name:
boot

### Create a ROOT partition:
> First sector...: 
\n
> Size in sectors or {KMGTP} (default = ...):
\n
> Hex code or GUID (L to show codes, Enter = 8300): 
\n
> Enter new partition name, or <Enter> to use the current name:
root

**Repeat process for $DISK_DRIVE_2**

## Filesystem creation
```
# Create EFI (FAT32) filesystem:
mkfs.vfat -F32 -n "EFI" /dev/sda128
```
  
Since this is a two disk simple mirror, we specify raid1 for both metadata and data when making the two filesystems.
```
mkfs -t btrfs -L BOOT -m raid1 -d raid1 $DISK_DRIVE_1... $DISK_DRIVE_2...
mkfs -t btrfs -L BTROOT -m raid1 -d raid1 $DISK_DRIVE_1... DISK_DRIVE_2...
```
  
  
# Sources
- https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH  
- https://wiki.gentoo.org/wiki/Btrfs/Native_System_Root_Guide#Partitioning
- https://wiki.archlinux.org/title/btrfs#Compression
- https://gist.github.com/broedli/5604637d5855bef68f3e#72-bootloader-grub2-install
