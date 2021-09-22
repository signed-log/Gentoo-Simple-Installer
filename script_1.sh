# This script is designed to finish the job of script.sh; don't download this script; this script will be downloaded and executed by script.sh.


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
