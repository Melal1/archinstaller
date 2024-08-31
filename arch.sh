#!/bin/bash

echo -ne "
-------------------------------------------------------------------------

  ▄▄▄▄███▄▄▄▄      ▄████████  ▄█          ▄████████  ▄█      
▄██▀▀▀███▀▀▀██▄   ███    ███ ███         ███    ███ ███      
███   ███   ███   ███    █▀  ███         ███    ███ ███      
███   ███   ███  ▄███▄▄▄     ███         ███    ███ ███      
███   ███   ███ ▀▀███▀▀▀     ███       ▀███████████ ███      
███   ███   ███   ███    █▄  ███         ███    ███ ███      
███   ███   ███   ███    ███ ███▌    ▄   ███    ███ ███▌    ▄
 ▀█   ███   █▀    ██████████ █████▄▄██   ███    █▀  █████▄▄██
                             ▀                      ▀        
-------------------------------------------------------------------------
"

echo -ne "
-------------------------------------------------------------------------
                    ArchLinux Installer
                    !!!! NOTE: you need to partition
                    your disk before running this script !!!!
-------------------------------------------------------------------------
"
sleep 1

# Update system and configure Pacman
timedatectl set-ntp true
 pacman -Sy --noconfirm archlinux-keyring 
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

echo -ne "
-------------------------------------------------------------------------
                     Reflector
                     Creating mirror list backup
-------------------------------------------------------------------------
"
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.ba

reflector -a 48 -c Iran -c Germany -c France -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist




echo -ne "
-------------------------------------------------------------------------
                     Create File System
-------------------------------------------------------------------------
"

# Create file systems
read -r -p "Enter the EFI partition (Ex: sda1) : " EFI
mkfs.vfat -F32 -n "EFI" /dev/"$EFI"
echo -ne "\n"

read -r -p "Enter the swap partition : " SWAP
mkswap /dev/"$SWAP"
swapon /dev/"$SWAP"
echo -ne "\n"

read -r -p "Enter the root (/) partition : " MAIN
mkfs.ext4 -L "root" /dev/"$MAIN"

echo -ne "
-------------------------------------------------------------------------
                    Mounting
-------------------------------------------------------------------------
"

# Mount partitions
mount /dev/"$MAIN" /mnt
echo -ne "\nMounted /dev/$MAIN with /mnt\n"

boot="boot/efi"
echo "boot=${boot}" >> /mnt/var.conf
mkdir -p /mnt/"$boot"
echo -ne "\nCreated /mnt/$boot\n"

mount /dev/"$EFI" /mnt/"$boot"
echo -ne "\nMounted /dev/$EFI with /mnt\n"


echo -ne "
Done !!
"

echo -ne "
-------------------------------------------------------------------------

  ▄▄▄▄███▄▄▄▄      ▄████████  ▄█          ▄████████  ▄█      
▄██▀▀▀███▀▀▀██▄   ███    ███ ███         ███    ███ ███      
███   ███   ███   ███    █▀  ███         ███    ███ ███      
███   ███   ███  ▄███▄▄▄     ███         ███    ███ ███      
███   ███   ███ ▀▀███▀▀▀     ███       ▀███████████ ███      
███   ███   ███   ███    █▄  ███         ███    ███ ███      
███   ███   ███   ███    ███ ███▌    ▄   ███    ███ ███▌    ▄
 ▀█   ███   █▀    ██████████ █████▄▄██   ███    █▀  █████▄▄██
                             ▀                      ▀        
-------------------------------------------------------------------------
                          PreSetup
-------------------------------------------------------------------------
"

# Pre-setup configuration
while true; do
    read -p "Enter username : " preUser
    if [[ "${preUser}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        echo "USER=${preUser,,}" >> /mnt/var.conf
        break
    else
        echo "Incorrect username. The username does not comply with username rules."
    fi
done

read -r -p "Enter hostname : " HOSTNAME
echo "HOSTNAME=${HOSTNAME}" >> /mnt/var.conf
echo -ne "\n"

# Password setup
sec_password() {
    read -r -p "Enter your password : " PASS1
    echo -ne "\n"
    read -r -p "Re-enter your password : " PASS2
    if [[ "$PASS1" == "$PASS2" ]]; then
        echo "PASS=${PASS1}" >> /mnt/var.conf
    else
        echo -ne "\nERROR !! Passwords don't match.\n\n"
        sec_password
    fi
}

sec_password

echo -ne "
-------------------------------------------------------------------------
                          Setting Timezone 
-------------------------------------------------------------------------
"

# Determine timezone
timezone=$(curl --fail https://ipapi.co/timezone)
echo -ne "------------------------------------------------------------------------------------------ \n"

timezone() {
    echo -ne "\nYour timezone is '$timezone', is that right? (Y/n) : \n"
    read -r timezone_answer

    if [[ -z "$timezone_answer" || "$timezone_answer" == "y" ]]; then
        echo -ne "Setting your time zone to '$timezone' "
        echo "TIMEZONE=${timezone}" >> /mnt/var.conf
    elif [[ "$timezone_answer" == "n" ]]; then
        sure() {
            echo -ne "Please write your time zone (Ex: Asia/Damascus) : \n"
            read -r TIMEZONE

            echo -ne "Your timezone will be set to '$TIMEZONE'. Continue? (Y/n) : \n"
            read -r continue

            if [[ -z "$continue" || "${continue}" == "y" ]]; then
                echo -ne "Setting your timezone to $TIMEZONE"
                echo "TIMEZONE=${TIMEZONE}" >> /mnt/var.conf
            else
                sure
            fi
        }
        sure
    else
        echo -ne "\nPlease select y or n \n"
        timezone
    fi
}
timezone

echo -ne "
-------------------------------------------------------------------------
                        CPU Type
-------------------------------------------------------------------------
"

# Determine CPU type and set microcode package
cpu_type=$(lscpu)
if grep -E "GenuineIntel" <<< ${cpu_type}; then
    echo "This system runs on Intel CPU"
    echo "Installing Intel Microcode"
    CPU="intel"
elif grep -E "AuthenticAMD" <<< ${cpu_type}; then
    echo "This system runs on AMD CPU"
    echo "Installing AMD Microcode"
    CPU="amd"
fi

echo -ne "
-------------------------------------------------------------------------
                    Determine Graphics Drivers
-------------------------------------------------------------------------
"

# Determine graphics drivers
sec_vm() {
    read -r -p "Are you on a virtual machine? (y/n) : " VM
    if [[ "$VM" == "y" ]]; then
        echo "GPKG=("xf86-video-fbdev")" >> /mnt/var.conf
    elif [[ "$VM" == "n" ]]; then
        gpu_type=$(lspci)
        if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
            echo "GPU=NVIDIA" >> /mnt/var.conf
            echo "GPKG=("nvidia" "nvidia-utils")" >> /mnt/var.conf
            echo "You have an NVIDIA GPU"
        elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
            echo "GPU=AMD" >> /mnt/var.conf
            echo "GPKG=("xf86-video-amdgpu")" >> /mnt/var.conf
            echo "You have an AMD GPU"
        elif grep -E "Integrated Graphics Controller" <<< ${gpu_type}; then
            echo "GPU=INTEL" >> /mnt/var.conf
            echo "GPKG=("xf86-video-intel" "libva-intel-driver" "libvdpau-va-gl" "lib32-vulkan-intel" "vulkan-intel" "libva-intel-driver" "libva-utils" "lib32-mesa")" >> /mnt/var.conf
            echo "You have an Intel GPU"
        elif grep -E "Intel Corporation UHD" <<< ${gpu_type}; then
            echo "GPU=INTEL" >> /mnt/var.conf
            echo "GPKG=("xf86-video-intel" "libva-intel-driver" "libvdpau-va-gl" "lib32-vulkan-intel" "vulkan-intel" "libva-intel-driver" "libva-utils" "lib32-mesa")" >> /mnt/var.conf
            echo "You have an Intel GPU"
        else
            echo "Please choose (y/n)"
            sec_vm
        fi
    fi
}
sec_vm


echo -ne "
-------------------------------------------------------------------------
                        Installing Arch Base
-------------------------------------------------------------------------
"

# Install base system
pacstrap /mnt linux linux-firmware base base-devel "${CPU}"-ucode vim --noconfirm --needed

echo -ne "
-------------------------------------------------------------------------
                          Create fstab
-------------------------------------------------------------------------
"

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Create setup script for chroot
cat << 'REALEND' > /mnt/2-Setup.sh
source ./var.conf

echo -ne "
-------------------------------------------------------------------------

  ▄▄▄▄███▄▄▄▄      ▄████████  ▄█          ▄████████  ▄█      
▄██▀▀▀███▀▀▀██▄   ███    ███ ███         ███    ███ ███      
███   ███   ███   ███    █▀  ███         ███    ███ ███      
███   ███   ███  ▄███▄▄▄     ███         ███    ███ ███      
███   ███   ███ ▀▀███▀▀▀     ███       ▀███████████ ███      
███   ███   ███   ███    █▄  ███         ███    ███ ███      
███   ███   ███   ███    ███ ███▌    ▄   ███    ███ ███▌    ▄
 ▀█   ███   █▀    ██████████ █████▄▄██   ███    █▀  █████▄▄██
                             ▀                      ▀        
-------------------------------------------------------------------------
                          Setup-2 (arch-chroot)
-------------------------------------------------------------------------
"


ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc

echo -ne "
-------------------------------------------------------------------------
                          Setting Locale 
-------------------------------------------------------------------------
"

# Set locale
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf # Enable multilib
pacman -Syuu
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#ar_SA.UTF-8 UTF-8/ar_SA.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

echo -ne "
-------------------------------------------------------------------------
                          Adding User
-------------------------------------------------------------------------
"

# Configure hostname and users
echo "$HOSTNAME" >> /etc/hostname

cat <<END > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
END

groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USER
echo "User: $USER created!"
echo $USER:$PASS | chpasswd
echo "Setting $USER password to $PASS"

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Add sudo no password rights
# sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
# sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

echo -ne "
-------------------------------------------------------------------------
                          Installing Packages
-------------------------------------------------------------------------
"

# Install packages
PKG=("neovim" "grub" "efibootmgr" "networkmanager" "git" "${GPKG[@]}")
for pkg in "${PKG[@]}"; do
    echo "Installing $pkg ..."
    sudo pacman -S "$pkg" --noconfirm --needed
done

echo -ne "
-------------------------------------------------------------------------
                          Installing Melal's Suckless Repository
-------------------------------------------------------------------------
"
git clone https://github.com/Melal1/suckless.git


echo -ne "
-------------------------------------------------------------------------
                          Mkinitcpio
-------------------------------------------------------------------------
"

# Regenerate initramfs
if [[ "$GPU" == "AMD" ]]; then
    sed -i 's/^MODULES=()/MODULES=(amdgpu)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
elif [[ "$GPU" == "NVIDIA" ]]; then
    sed -i 's/^MODULES=()/MODULES=(nvidia)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
elif [[ "$GPU" == "INTEL" ]]; then
    sed -i 's/^MODULES=()/MODULES=(i915)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
else
    echo "Skipping ..."
fi

echo -ne "
-------------------------------------------------------------------------
                          Bootloader Install (GRUB)
-------------------------------------------------------------------------
"

# Install GRUB bootloader
grub-install --target=x86_64-efi --efi-directory=/$boot --bootloader-id="GRUB"
grub-mkconfig -o /boot/grub/grub.cfg

echo -ne "
-------------------------------------------------------------------------
                          Services Enable
-------------------------------------------------------------------------
"

# Enable essential services
systemctl enable NetworkManager

echo -ne "
-------------------------------------------------------------------------
                          Install Complete, You can reboot now
-------------------------------------------------------------------------
"
REALEND

# Run the chroot script
arch-chroot /mnt sh 2-Setup.sh
