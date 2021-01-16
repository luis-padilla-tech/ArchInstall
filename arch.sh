#!/bin/bash

### Set up logging ###
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

### Get infomation from user ###
echo -n "Enter new root password"
read -s root_password

echo Enter new root password again
read root_password2
[[ "$root_password" == "$root_password2" ]] || ( echo "Passwords did not match"; exit 1; )

echo Enter hostname
read hostname

echo Enter User name
read user

echo Enter password
read password
echo Enter password again
read password2
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )



devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
clear


timedatectl set-ntp true

### Setup the disk and partitions ###

fdisk "${device}"

part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"

mkfs.fat -F32 "${part_boot}"
mkswap "${part_swap}"
mkfs.ext4 "${part_root}"

mount "${part_root}" /mnt
swapon "${part_swap}"

pacstrap /mnt base linux linux-headers linux-lts linux-lts-headers linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

### Set local time/lang###
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc

pacman -S nano
nano /etc/locale.gen

gen-locale

echo "${hostname}" > /etc/hostname

nano /etc/hosts

### Set Admin ###
passwd
"${admin_password}"
"${admin_password}"

### Add primary user ###
useradd -m "${user}"
passwd 
"${password}"
"${password}"

usermod -aG wheel,audio,video,storage,optical "${user}"

pacman -S sudo

EDITOR=nano visudo

### Boot loader ###
pacman -S grub efibootmgr dosfstools os-prober mtools

mkdir /boot/EFI
mount "${part_boot}" /boot/EFI

grub-installer --target=x86_64-efi --bootloader-id=grub_uefi --recheck
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

exit
umount -R /mnt
shutdown

### Remove iso, usb, or disk, turn on and enjoy ###
