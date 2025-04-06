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

# Create Volume Group
sudo vgcreate vg_opt /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde # Changed to vg_opt

# Create Logical Volume
sudo lvcreate -l 100%FREE -n lv_opt vg_opt  # Changed to lv_opt

# Format Logical Volume
sudo mkfs.ext4 /dev/vg_opt/lv_opt  # Changed path

# Backup existing /opt data if exists
if [ -d "/opt" ]; then
    sudo mkdir -p /mnt/opt_backup
    sudo rsync -avx /opt/ /mnt/opt_backup/
fi

# Mount Logical Volume to temporary location
sudo mkdir -p /mnt/new_opt
sudo mount /dev/vg_opt/lv_opt /mnt/new_opt

# Copy data from backup to new location if backup exists
if [ -d "/mnt/opt_backup" ]; then
    sudo rsync -avx /mnt/opt_backup/ /mnt/new_opt/
fi

# Unmount temporary location
sudo umount /mnt/new_opt

# Rename original /opt if exists (don't delete yet)
if [ -d "/opt" ]; then
    sudo mv /opt /opt.old
fi

# Create new /opt directory
sudo mkdir /opt

# Add entry to /etc/fstab
echo '/dev/vg_opt/lv_opt  /opt  ext4  defaults  0  2' | sudo tee -a /etc/fstab

# Mount the new /opt
sudo mount /dev/vg_opt/lv_opt /opt

# Set proper permissions (common for /opt)
sudo chmod 755 /opt

# Verify the mount
df -h | grep /opt
ls -ld /opt

# Final message
echo "=========================================="
echo "Script executed successfully!"
echo "Logical Volume created and mounted to /opt."
if [ -d "/opt.old" ]; then
    echo "Original /opt data preserved in /opt.old"
    echo "After verification, you can remove /opt.old with:"
    echo "sudo rm -rf /opt.old"
else
    echo "No existing /opt directory was found/migrated."
fi
echo "=========================================="
