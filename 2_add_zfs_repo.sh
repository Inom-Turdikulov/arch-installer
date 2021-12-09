#!/bin/bash
set -e
echo "Remove all lines in ```/etc/fstab```, leaving only the entries for ```swap``` and ```boot```."
sed -i '/swap\|boot\|SWAP/!d' /etc/fstab

echo "Add archzfs repo"
sed -i '/\[core\]/i[archzfs]\nServer = http://archzfs.com/$repo/x86_64\n' /etc/pacman.conf

echo Add GPG keys
curl -O https://archzfs.com/archzfs.gpg
pacman-key -a archzfs.gpg
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman -Syy
