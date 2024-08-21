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
                    !!!! NOTE : you need to partition
                    your disk before run this script !!!!
-------------------------------------------------------------------------
"
sleep 2


pacman -Syyu --noconfirm --needed
timedatectl set-ntp true
pacman -S archlinux-keyring --noconfirm --needed
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf


echo -ne "
-------------------------------------------------------------------------
                     Create file system
-------------------------------------------------------------------------
"


read -r -p "Enter the efi partition (Ex: sda1) : " EFI
mkfs.vfat -F32 -n "EFI" /dev/"$EFI"
echo -ne "\n"

read -r -p "Enter the swap partition : " SWAP
mkswap /dev/"$SWAP"
swapon /dev/"$SWAP"
echo -ne "\n"

read -r -p "Enter the root(/) partition : " MAIN
mkfs.ext4 -L "root" /dev/"$MAIN"

echo -ne "
-------------------------------------------------------------------------
                    Mounting
-------------------------------------------------------------------------
"
mount /dev/"$MAIN" /mnt

echo -ne "

Mounted /dev/"$MAIN" with /mnt

"


boot="boot/efi"
echo "boot=${boot}" >> /mnt/var.conf
mkdir -p /mnt/"$boot"

echo -ne "
Created /mnt/$boot
"


mount /dev/"$EFI" /mnt/"$boot"

echo -ne "
Mounted /dev/"$EFI" with /mnt
"
sleep 1 

echo -ne " 
Done !!
"

echo -ne "\n"
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



while true
 do 
		read -p "Enter username : " preUser

		if [[ "${preUser}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]] ; then
		  echo "USER=${preUser,,}" >> /mnt/var.conf
			break
     else 
		 echo "Incorrect username , the username does not comply with username rules"
    fi
done 


read -r -p "Enter hostname : " HOSTNAME
echo "HOSTNAME=${HOSTNAME}" >> /mnt/var.conf
echo -ne "\n"

sec_password() {
  read -r -p "Enter your password : " PASS1
  echo -ne "\n"
  read -r -p "Re-enter your password : " PASS2
  if [[ "$PASS1" == "$PASS2" ]] ; then 
      echo "PASS=${PASS1}" >>  /mnt/var.conf 
   else
    echo -ne "\n"
    echo -ne "
    
     - ERROR !! - Passwords don't match . \n
     
     "
     sec_password
  fi
}

sec_password

echo -ne "
-------------------------------------------------------------------------
                          Setting timezone 
-------------------------------------------------------------------------
"

timezone=$(curl --fail https://ipapi.co/timezone)
echo -ne "------------------------------------------------------------------------------------------ \n"

timezone () {
echo -ne "\n Your timezone is '$timezone' , is that right ? (y/n) : \n"
read -r timezone_answer 

if [[ "$timezone_answer" == "y" ]] ; then
  echo -ne "Setting your time zone to '$timezone' "
  echo "TIMEZONE=${timezone}" >> /mnt/var.conf


  elif [[ "$timezone_answer" == "n" ]]; then
  
  sure() {
    echo -ne "Please write your time zone ( Ex: Asia/Damascus ) : \n"
    read -r TIMEZONE 

    echo -ne "Your timezone will be set to '$TIMEZONE' \n Continue ? (y/n) : \n"
    read -r continue

    if [[ "${continue}" == "y" ]]; then
      echo -ne "Setting your timezone to $TIMEZONE"
      echo "TIMEZONE=${TIMEZONE}" >> /mnt/var.conf
      else
        sure
    fi

  }

    sure
  else
    echo -ne "\n Please select (y/n) \n"
    timezone
fi 
}
timezone

echo -ne "
-------------------------------------------------------------------------
                    Cpu Type
-------------------------------------------------------------------------
"
cpu_type=$(lscpu)
if grep -E "GenuineIntel" <<< ${cpu_type}; then

    echo "This system runs on intel cpu"
    echo "Installing Intel Microcode"
    
    CPU="intel"
    
elif grep -E "AuthenticAMD" <<< ${cpu_type}; then

    echo "This system runs on amd cpu"
    echo "Installing AMD Microcode"
    CPU="amd"
    
fi



echo -ne "

-------------------------------------------------------------------------
                    Determine Graphics Drivers
-------------------------------------------------------------------------

"

sec_vm() {
read -r -p "Are you on virtual machine ? (y/n) : " VM
if [[ "$VM" == "y" ]] ; then 
    # echo "GPU=VM" >> /mnt/var.conf
    echo "GPKG=("xf86-video-fbdev")" >> /mnt/var.conf

  elif [[ "$VM" == "n" ]]; then 
      gpu_type=$(lspci)
      if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
          echo "GPU=NVIDIA" >> /mnt/var.conf
          echo "GPKG=("nvidia" "nvidia-utils")" >> /mnt/var.conf
          echo "You have a nvidia gpu"
          
        elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then

          echo "GPU=AMD" >> /mnt/var.conf
          echo "GPKG=("xf86-video-amdgpu")" >> /mnt/var.conf
          echo "You have a amd gpu"

        elif grep -E "Integrated Graphics Controller" <<< ${gpu_type}; then
          echo "GPU=INTEL" >> /mnt/var.conf
          echo "GPKG=("xf86-video-intel" "libva-intel-driver" "libvdpau-va-gl" "lib32-vulkan-intel" "vulkan-intel" "libva-intel-driver" "libva-utils" "lib32-mesa")" >> /mnt/var.conf
          echo "You have a intel gpu"
        elif grep -E "Intel Corporation UHD" <<< ${gpu_type}; then
          echo "GPU=INTEL" >> /mnt/var.conf
          echo "GPKG=("xf86-video-intel" "libva-intel-driver" "libvdpau-va-gl" "lib32-vulkan-intel" "vulkan-intel" "libva-intel-driver" "libva-utils" "lib32-mesa")" >> /mnt/var.conf
          echo "You have a intel gpu"
        else
          echo "Please choose (y/n)"
          sec_vm

       fi
fi
}
sec_vm
sleep 2

echo -ne "


-------------------------------------------------------------------------
                        Installing Arch Base
-------------------------------------------------------------------------


"

pacstrap /mnt linux linux-firmware base base-devel "${CPU}"-ucode vim  --noconfirm --needed

echo -ne "


-------------------------------------------------------------------------
                          Create fstab
-------------------------------------------------------------------------

"

genfstab -U /mnt >> /mnt/etc/fstab




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
sleep 2

 ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
 hwclock --systohc
 
echo -ne "
-------------------------------------------------------------------------
                          Setting Locale 
-------------------------------------------------------------------------
"


sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf #  enable multilib
pacman -Syuu
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#ar_SA.UTF-8 UTF-8/ar_SA.UTF-8 UTF-8/' /etc/locale.gen
locale-gen


echo -ne "

-------------------------------------------------------------------------
                          Adding User
-------------------------------------------------------------------------

"

echo "$HOSTNAME" >> /etc/hostname

cat <<END > /etc/hosts

127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
END

groupadd libvirt

useradd -m -G wheel,libvirt -s /bin/bash $USER

echo "User:$USER created ! "

echo $USER:$PASS | chpasswd
echo Setting $USER password to $PASS

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Add sudo no password rights
# sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
# sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers




echo -ne "

-------------------------------------------------------------------------
                          Installing Packages
-------------------------------------------------------------------------
"

PKG=("neovim" "grub" "efibootmgr" "networkmanager" "git" "${GPKG[@]}")


 for pkg in "${PKG[@]}"; do
     echo Installing "$pkg" ....
    sudo pacman -S "$pkg" --noconfirm --needed
     
    
 done






echo -ne "

-------------------------------------------------------------------------
                          Mkinitcpio
-------------------------------------------------------------------------
"


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
    echo "Skipping .... "


fi

echo -ne "

-------------------------------------------------------------------------
                          Bootloader install (Grub)
-------------------------------------------------------------------------

"

grub-install --target=x86_64-efi --efi-directory=/$boot --bootloader-id="GRUB"
grub-mkconfig -o /boot/grub/grub.cfg


echo -ne "

-------------------------------------------------------------------------
                          Services enable
-------------------------------------------------------------------------
"

systemctl enable NetworkManager
echo -ne "

-------------------------------------------------------------------------
                          Install Complete, You can reboot now
-------------------------------------------------------------------------


"

REALEND

arch-chroot /mnt sh 2-Setup.sh
