#!/bin/bash
# WARNING: this script will destroy data on the selected disk.
# This script can be run by executing the following:
#   curl -sL https://git.io/vNxbN | bash

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

### Get infomation from user ###
root_password=$(dialog --stdout --passwordbox "Enter new root password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
root_password2=$(dialog --stdout --passwordbox "Enter new root password again" 0 0) || exit 1
clear
[[ "$root_password" == "$root_password2" ]] || ( echo "Passwords did not match"; exit 1; )

hostname=$(dialog --stdout --inputbox "Enter hostname" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --inputbox "Enter username" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(dialog --stdout --passwordbox "Enter password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Enter password again" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )



devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
clear

### Set up logging ###
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

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

### Awesome setup ###

pacman -S networkmanager alacritty code awesome xorg xorg-init git krusader compositer

systemctl enable NetworkManager

exit
umount -R /mnt
shutdown

### Remove iso, usb, or disk, turn on and enjoy ###
