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

echo " Creating partitions..."

sfdisk ${TARGET_DISK} << END
size=$TARGET_BOOT_SIZE,bootable
size=$TARGET_SWAP_SIZE
;
END

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

echo " The first part of the installation has finished...
Please run the following commands to continue the installation:"

echo "chroot /mnt/gentoo /bin/bash"

echo "source /etc/profile" 

echo ""export PS1="(chroot) ${PS1}""

echo "wget https://raw.githubusercontent.com/LJB018/Gentoo-Simple-Installer/main/Gentoo-Simple-Installer_1.sh"

echo "chmod +x Gentoo-Simple-Installer_1.sh"

echo "./Gentoo-Simple-Installer_1.sh"