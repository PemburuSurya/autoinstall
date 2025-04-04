#!/bin/bash

# Unmount volumes
sudo umount /mnt/volume_sgp1_01
sudo umount /mnt/volume_sgp1_02
sudo umount /mnt/volume_sgp1_03
sudo umount /mnt/volume_sgp1_04
sudo umount /mnt/volume_sgp1_05

# Create Physical Volumes
sudo pvcreate /dev/sda
sudo pvcreate /dev/sdb
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf

# Create Volume Group
sudo vgcreate vg_var /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf  # Changed from vg_home to vg_var

# Create Logical Volume
sudo lvcreate -l 100%FREE -n lv_var vg_var  # Changed from lv_home to lv_var

# Format Logical Volume
sudo mkfs.ext4 /dev/vg_var/lv_var  # Changed path to reflect new names

# Backup existing /var data (important!)
sudo mkdir -p /mnt/var_backup
sudo rsync -avx /var/ /mnt/var_backup/

# Mount Logical Volume to temporary location
sudo mkdir -p /mnt/new_var
sudo mount /dev/vg_var/lv_var /mnt/new_var

# Copy data from backup to new location
sudo rsync -avx /mnt/var_backup/ /mnt/new_var/

# Unmount temporary location
sudo umount /mnt/new_var

# Rename original /var (don't delete yet)
sudo mv /var /var.old

# Create new /var directory
sudo mkdir /var

# Add entry to /etc/fstab
echo '/dev/vg_var/lv_var  /var  ext4  defaults  0  2' | sudo tee -a /etc/fstab

# Mount the new /var
sudo mount /dev/vg_var/lv_var /var

# Verify the mount
df -h | grep /var

# Final message
echo "=========================================="
echo "Script executed successfully!"
echo "Logical Volume created and mounted to /var."
echo "Original /var data preserved in /var.old"
echo "After verification, you can remove /var.old with:"
echo "sudo rm -rf /var.old"
echo "=========================================="
