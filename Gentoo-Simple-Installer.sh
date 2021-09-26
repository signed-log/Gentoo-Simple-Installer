# Gentoo Simple Installer

# https://github.com/LJB018/Gentoo-Simple-Installer


read -r -p "Please note:
This script requires an ethernet connection to install Gentoo
Do you have an ethernet connection? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 echo "You can continue now."
 ;;
    [nN][oO]|[nN])
 exit
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac

# Variables

read -p "Enter the drive you want to install Gentoo onto: (This will destroy all data on your drive!)" TARGET_DISK

GENTOO_MIRROR="http://distfiles.gentoo.org"

GENTOO_ARCH="amd64"
GENTOO_STAGE3="amd64"

TARGET_BOOT_SIZE=512M
TARGET_SWAP_SIZE=4G

GRUB_PLATFORMS=pc

USE_LIVECD_KERNEL=${USE_LIVECD_KERNEL:-1}

SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-}
ROOT_PASSWORD=${ROOT_PASSWORD:-}

# 

echo " Setting time"

ntpd -q -g

echo " Formatting partitions..."

yes | mkfs.ext4 ${TARGET_DISK}1
yes | mkswap ${TARGET_DISK}2
yes | mkfs.ext4 ${TARGET_DISK}3

echo " Labeling partitions..."

e2label ${TARGET_DISK}1 boot
swaplabel ${TARGET_DISK}2 -L swap
e2label ${TARGET_DISK}3 root

echo " Mounting partitions..."

swapon ${TARGET_DISK}2

mkdir -p /mnt/gentoo
mount ${TARGET_DISK}3 /mnt/gentoo

mkdir -p /mnt/gentoo/boot
mount ${TARGET_DISK}1 /mnt/gentoo/boot

echo " Setting work directory..."

cd /mnt/gentoo

echo " Installing stage3..."

STAGE3_PATH_URL="$GENTOO_MIRROR/releases/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_STAGE3.txt"
STAGE3_PATH=$(curl -s "$STAGE3_PATH_URL" | grep -v "^#" | cut -d" " -f1)
STAGE3_URL="$GENTOO_MIRROR/releases/$GENTOO_ARCH/autobuilds/$STAGE3_PATH"

wget "$STAGE3_URL"

tar xvpf "$(basename "$STAGE3_URL")" --xattrs-include='*.*' --numeric-owner

rm -fv "$(basename "$STAGE3_URL")"

if [ "$USE_LIVECD_KERNEL" != 0 ]; then
    echo " Installing LiveCD kernel..."

    LIVECD_KERNEL_VERSION=$(cut -d " " -f 3 < /proc/version)

    cp -v "/mnt/cdrom/boot/gentoo" "/mnt/gentoo/boot/vmlinuz-$LIVECD_KERNEL_VERSION"
    cp -v "/mnt/cdrom/boot/gentoo.igz" "/mnt/gentoo/boot/initramfs-$LIVECD_KERNEL_VERSION.img"
    cp -vR "/lib/modules/$LIVECD_KERNEL_VERSION" "/mnt/gentoo/lib/modules/"
fi

read -r -p "Do you want to edit /mnt/gentoo/etc/portage/make.conf? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /mnt/gentoo/etc/portage/make.conf
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac

read -r -p "Do you want to select mirrors? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac

mkdir --parents /mnt/gentoo/etc/portage/repos.conf

cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/


echo " Mounting the necessary filesystems"


mount --types proc /proc /mnt/gentoo/proc

mount --rbind /sys /mnt/gentoo/sys 

mount --make-rslave /mnt/gentoo/sys 

mount --rbind /dev /mnt/gentoo/dev

mount --make-rslave /mnt/gentoo/dev


echo " Entering the new environment"


chroot /mnt/gentoo /bin/bash 

source /etc/profile 

export PS1="(chroot) ${PS1}"


echo " Mounting the boot partition"


mount /dev/sda1 /boot


echo " Configuring Portage"


emerge-webrsync

eselect profile list


echo " Updating the @world set"

emerge --ask --verbose --update --deep --newuse @world


echo " Configuring the USE variable"

emerge --info | grep ^USE

USE="X acl alsa amd64 berkdb bindist bzip2 cli cracklib crypt cxx dri ..."


read -r -p "Do you want to configure locales? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/locale.gen
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


echo " Reloading into the new environment"

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"


echo " Installing the sources"

emerge --ask sys-kernel/gentoo-sources

eselect kernel set 1

emerge --ask sys-apps/pciutils

cd /usr/src/linux 

make menuconfig

make && make modules_install

make install

echo " Configuring the modules"


find /lib/modules/<kernel version>/ -type f -iname '*.o' -or -iname '*.ko' | less

mkdir -p /etc/modules-load.d

nano -w /etc/modules-load.d/network.conf 


read -r -p "Do you want to install drivers? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 emerge --ask sys-kernel/linux-firmware
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


blkid


read -r -p "Do you want to choose a hostname? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/conf.d/hostname
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


echo " Configuring the network"

emerge --ask --noreplace net-misc/netifrc

read -r -p "Do you want to configure the network DHCP settings? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/conf.d/net
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


echo " Setting up network autostart at boot"

cd /etc/init.d 

ln -s net.lo net.eth0 

rc-update add net.eth0 default


read -r -p "Do you want to configure the hosts file? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/hosts
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


read -r -p "Do you want to set a root password? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 passwd root
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


read -r -p "Do you want edit /etc/rc.conf? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/rc.conf
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


read -r -p "Do you want edit keymaps? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/conf.d/keymaps
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


read -r -p "Do you want edit the clock? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 nano -w /etc/conf.d/hwclock
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


echo " Installing System logger"
emerge --ask app-admin/sysklogd



read -r -p "Do you want to install a Cron daemon? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 emerge --ask sys-process/cronie
 rc-update add cronie default
 crontab /etc/crontab
 emerge --config sys-process/fcron
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


echo " Installing mlocate"

emerge --ask sys-apps/mlocate


echo " Installing DHCP client"

emerge --ask net-misc/dhcpcd


echo " Installing PPPoE client"
emerge --ask net-dialup/ppp


read -r -p "Do you want to add support for WiFi networking? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 emerge --ask net-wireless/iw net-wireless/wpa_supplicant
 ;;
    [nN][oO]|[nN])
 echo " No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


echo " Installing grub2"

emerge --ask --verbose sys-boot/grub:2

echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf

emerge --ask sys-boot/grub:2

emerge --ask --update --newuse --verbose sys-boot/grub:2

grub-install ${TARGET_DISK}

grub-mkconfig -o /boot/grub/grub.cfg


read -r -p "Congratulations, you have successfully installed Gentoo! Would you like to setup a user for daily use? [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 echo "What should this user be called?"
 read input
 useradd $input
 ;;
    [nN][oO]|[nN])
 echo " No" 
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac


rm ${STAGE3_PATH}

reboot