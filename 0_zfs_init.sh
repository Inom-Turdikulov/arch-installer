# set bigger font
setfont latarcyrheb-sun32
pacman -Syy
pacman -Syy # sometimes core.db is broken, need rerun this
curl -s https://raw.githubusercontent.com/inomoz/archiso-zfs-1/master/init | bash
