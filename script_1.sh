# This script is designed to finish the job of script.sh; don't download this script; this script will be downloaded and executed by script.sh.

set -e

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

echo "### Upading configuration..."

env-update
source /etc/profile

echo "### Installing portage..."

mkdir -p /etc/portage/repos.conf
cp -f /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
emerge-webrsync

echo "### Installing kernel sources..."

emerge sys-kernel/gentoo-sources

if [ "$USE_LIVECD_KERNEL" = 0 ]; then
    echo "### Installing kernel..."

    echo "sys-kernel/genkernel -firmware" > /etc/portage/package.use/genkernel
    echo "sys-apps/util-linux static-libs" >> /etc/portage/package.use/genkernel

    emerge sys-kernel/genkernel

    genkernel all --kernel-config=$(find /etc/kernels -type f -iname 'kernel-config-*' | head -n 1)
fi

echo "### Installing bootloader..."

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

echo "### Configuring network..."

ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default

if [ -z "$ROOT_PASSWORD" ]; then
    echo "### Removing root password..."
    passwd -d -l root
else
    echo "### Configuring root password..."
    echo "root:$ROOT_PASSWORD" | chpasswd
fi

if [ -n "$SSH_PUBLIC_KEY" ]; then
    echo "### Configuring SSH..."

    rc-update add sshd default

    mkdir /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 750 /root/.ssh
    chmod 640 /root/.ssh/authorized_keys
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
fi

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
