#!/bin/sh

# Original script:
# https://github.com/sormy/gentoo-quick-installer

# Made by LJB018
# https://github.com/LJB018

set -e

# Variables

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=4
BACKTITLE="Gentoo-Simple-Installer"
TITLE="Please select the drive you want to install Gentoo onto..."
MENU="A larger selection of drives is coming soon."

OPTIONS=(1 "/dev/sda"
         2 "/dev/sdb"
         3 "/dev/sdc"
         4 "/dev/sdd"
         5 "/dev/sde"
         6 "/dev/sdf"
         7 "/dev/nvme0n1"
         8 "/dev/nvme0n2"
         9 "/dev/nvme0n3"
         10 "/dev/nvme0n4")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            TARGET_DISK=/dev/sda
            ;;
        2)
            TARGET_DISK=/dev/sdb
            ;;
        3)
            TARGET_DISK=/dev/sdc
            ;;
        4)
            TARGET_DISK=/dev/sdd
            ;;
        5)
            TARGET_DISK=/dev/sde
            ;;
        6)
            TARGET_DISK=/dev/sdf
            ;;
        7)
            TARGET_DISK=/dev/nvme0n1
            ;;
        8)
            TARGET_DISK=/dev/nvme0n2
            ;;
        9)
            TARGET_DISK=/dev/nvme0n3
            ;;
        10)
            TARGET_DISK=/dev/nvme0n4
            ;;
esac

GENTOO_MIRROR="http://distfiles.gentoo.org"

GENTOO_ARCH="amd64"
GENTOO_STAGE3="amd64"

TARGET_BOOT_SIZE=512M
TARGET_SWAP_SIZE=2G

GRUB_PLATFORMS=pc

USE_LIVECD_KERNEL=${USE_LIVECD_KERNEL:-1}

SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-}
ROOT_PASSWORD=${ROOT_PASSWORD:-}

echo " Creating partitions..."

sfdisk ${TARGET_DISK} << END
size=$TARGET_BOOT_SIZE,bootable
size=$TARGET_SWAP_SIZE
;
END

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

mount -t proc none /mnt/gentoo/proc
mount -t sysfs none /mnt/gentoo/sys
mount -o bind /dev /mnt/gentoo/dev
mount -o bind /dev/pts /mnt/gentoo/dev/pts
mount -o bind /dev/shm /mnt/gentoo/dev/shm

echo " Changing root..."

chroot /mnt/gentoo /bin/bash -s << END

echo " Downloading script_1.sh..."

cd ~
wget https://raw.githubusercontent.com/LJB018/Gentoo-Simple-Installer/main/script_1.sh
chmod +x script_1.sh
./script_1.sh
