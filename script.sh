#!/bin/sh

# Original script:
# https://github.com/sormy/gentoo-quick-installer

# Made by LJB018
# https://github.com/LJB018

set -e

echo Thank you for using Gentoo Simple Installer

# Variables

while true
do
    read -r -p "Please select your drive
    [1] /dev/sda [2] /dev/sdb [3] /dev/sdc [4] /dev/sdd
    [5] /dev/sde [6] /dev/sdf [7] /dev/sdg [8] /dev/sdh
    
    A larger selection of drives is coming soon." input

    case $input in
        [1])
            TARGET_DISK=/dev/sda
            break
            ;;
        [2])
            TARGET_DISK=/dev/sdb
            break
            ;;
        [3])
            TARGET_DISK=/dev/sdc
            break
            ;;
        [4])
            TARGET_DISK=/dev/sdd
            break
            ;;
        [5])
            TARGET_DISK=/dev/sde
            break
            ;;
        [6])
            TARGET_DISK=/dev/sdf
            break
            ;;
        [7])
            TARGET_DISK=/dev/sdg
            break
            ;;
        [8])
            TARGET_DISK=/dev/sdh
            break
                ;;
        *)
        echo "Invalid input..."
        ;;
    esac
done

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

END

echo " Updating configuration"
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

END

echo " Installing portage..."
mkdir -p /etc/portage/repos.conf
cp -f /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
emerge-webrsync

echo " Installing kernel sources..."

emerge sys-kernel/gentoo-sources
if [ "$USE_LIVECD_KERNEL" = 0 ]; then
    echo " Installing kernel..."
    echo "sys-kernel/genkernel -firmware" > /etc/portage/package.use/genkernel
    echo "sys-apps/util-linux static-libs" >> /etc/portage/package.use/genkernel
    emerge sys-kernel/genkernel
    genkernel all --kernel-config=$(find /etc/kernels -type f -iname 'kernel-config-*' | head -n 1)
fi

echo " Installing bootloader..."
emerge grub
cat >> /etc/portage/make.conf << IEND
# added by gentoo installer
GRUB_PLATFORMS="$GRUB_PLATFORMS"
IEND
cat >> /etc/default/grub << IEND
# added by gentoo installer
GRUB_CMDLINE_LINUX="net.ifnames=0"
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
IEND
grub-install ${TARGET_DISK}
grub-mkconfig -o /boot/grub/grub.cfg
echo " Configuring network..."
ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default
if [ -z "$ROOT_PASSWORD" ]; then
    echo " Removing root password..."
    passwd -d -l root
else
    echo " Configuring root password..."
    echo "root:$ROOT_PASSWORD" | chpasswd
fi
if [ -n "$SSH_PUBLIC_KEY" ]; then
    echo " Configuring SSH..."
    rc-update add sshd default
    mkdir /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 750 /root/.ssh
    chmod 640 /root/.ssh/authorized_keys
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
fi
END

echo "Please set a root password"
passwd root

while true
do
    read -r -p "Do you want to create a user? [Y/n] " input

0    case $input in
        [yY][eE][sS]|[yY])
            echo "What should this user be called?"
            read input
            useradd $input
            break
            ;;
        [nN][oO]|[nN])
            break
                ;;
        *)
        echo "Invalid input..."
        ;;
    esac
done

while true
do
    read -r -p "Setup has finished, would you like to reboot this system now? [Y/n] " input

    case $input in
        [yY][eE][sS]|[yY])
            reboot
            ;;
        [nN][oO]|[nN])
            break
                ;;
        *)
        echo "Invalid input..."
        ;;
    esac
done
