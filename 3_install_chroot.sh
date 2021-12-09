#!/bin/bash
set -e

echo "Configure time zone (change accordingly)"
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

echo "Generate locale (change accordingly)"
sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Configure **vconsole**, **hostname**, **hosts**"
echo -e "KEYMAP=us\n#FONT=latarcyrheb-sun32" > /etc/vconsole.conf
echo al-zfs > /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost" >> /etc/hosts

echo Install ZFS, microcode etc:
echo "I choose the default options for the *archzfs-linux* group: ```zfs-linux```, ```zfs-utils```, and ```mkinitcpio``` for initramfs."
pacman -Syu --noconfirm networkmanager sudo openssh rsync borg git dhcpcd

echo Generate host id:
zgenhostid $(hostid)

echo Create cache file:
zpool set cachefile=/etc/zfs/zpool.cache rpool

echo Configure initial ramdisk
sed -i "/HOOKS=/c\HOOKS=(base udev autodetect modconf block keyboard keymap zfs filesystems\)" /etc/mkinitcpio.conf
mkinitcpio -p linux

echo Enable ZFS services
systemctl enable zfs.target
systemctl enable zfs-import-cache.service
systemctl enable zfs-mount.service
systemctl enable zfs-import.target

echo Enable networkmanager
systemctl enable NetworkManager

echo Install the bootloader:
bootctl --path=/boot install

echo "Add an EFI boot manager update hook in */etc/pacman.d/hooks/100-systemd-boot.hook*"

mkdir /etc/pacman.d/hooks
touch /etc/pacman.d/hooks/100-systemd-boot.hook
cat > /etc/pacman.d/hooks/100-systemd-boot.hook <<EOL
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = update systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOL

touch /boot/loader/loader.conf
echo "Replace content of */boot/loader/loader.conf* with"
cat > /boot/loader/loader.conf <<EOL
default arch
timeout 3
# bigger boot menu on a 4K laptop display
console-mode 1
EOL

touch /boot/loader/entries/arch.conf
echo "Create a */boot/loader/entries/**arch**.conf* containing"
cat > /boot/loader/entries/arch.conf <<EOL
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options zfs=rpool/ROOT/default rw
EOL


echo "Create a zfs pam mount script"
touch /sbin/mount-zfs-homedir
chmod +x /sbin/mount-zfs-homedir
cat > /sbin/mount-zfs-homedir <<EOL
#!/bin/bash
# simplified from https://talldanestale.dk/2020/04/06/zfs-and-homedir-encryption/
set -eu
# Password is given to us via stdin, save it in a variable for later
PASS=$(cat -)
VOLNAME="rpool/DATA/home"
# Unlock and mount the volume
zfs load-key "$VOLNAME" <<< "$PASS" || continue
zfs mount "$VOLNAME" || true # ignore errors
EOL


# If using an Intel processor, replace ```/amd-ucode.img``` with ```/intel-ucode.img```.

echo Exit and unmount all
#exit
zfs umount -a
umount -R /mnt

echo EPORT POOL by
echo zpool export rpool
