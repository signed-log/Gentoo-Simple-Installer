#!/bin/sh

# Made by LJB018
# https://github.com/LJB018

# Original script:
# https://github.com/sormy/gentoo-quick-installer

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

echo " Installing kernel configuration..."

mkdir -p /mnt/gentoo/etc/kernels
cp -v /etc/kernels/* /mnt/gentoo/etc/kernels

echo " Copying network options..."

cp -v /etc/resolv.conf /mnt/gentoo/etc/

echo " Configuring fstab..."

cat >> /mnt/gentoo/etc/fstab << END
# added by gentoo installer
LABEL=boot /boot ext4 noauto,noatime 1 2
LABEL=swap none  swap sw             0 0
LABEL=root /     ext4 noatime        0 1
END

echo " Mounting proc/sys/dev..."

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys 
mount --make-rslave /mnt/gentoo/sys 
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev 

echo " Script 1.sh has finished please refer to README.md for instructions."
