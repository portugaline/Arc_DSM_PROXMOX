#!/bin/bash
#
# Script name: install_arc_dsm.sh
# Author: Helio Rodrigues   -   King Tam
# Website: https://portugaline.com    -    https://kingtam.eu.org/posts/pve-dsm/
# Date: 4 November, 2023
# Purpose: Automatic creation of Proxmox VM using Arc Loader for DSM 7+.
#

set -e

# Ask for VMID
read -p "Enter Virtual Machine ID for Synology DSM install: " VMID

# Check if VMID already exists
if qm status $VMID &> /dev/null
then
    read -p "VM $VMID already exists. Do you want to remove it? (y/n) " choice
    case "$choice" in
        y|Y )
            qm stop $VMID
            qm destroy $VMID
            echo "VM $VMID has been removed."
            ;;
        * )
            echo "Please enter a different VMID."
            exit 1
            ;;
    esac
fi

# Check if unzip is installed, install if not
if ! command -v unzip &> /dev/null; then
    echo "unzip could not be found, installing..."
    apt install unzip -y
fi

# Get latest release version from GitHub API
version=$(curl -s https://api.github.com/repos/AuxXxilium/arc/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
newversion=${version:1}
 
# Construct download URL using latest release version
url="https://github.com/AuxXxilium/arc/releases/download/$version/arc-$version-stable.img.zip"
 
# Download and extract Arc image
wget $url
image_folder="/var/lib/vz/template/iso/"
unzip "arc-$version-stable.img.zip" -d $image_folder
rm "arc-$version-stable.img.zip"

# Create virtual machine
qm create "$VMID" --name DSM --memory 4096 --sockets 1 --cores 2 --cpu host --net0 virtio,bridge=vmbr0 --ostype l26

# Import Arc image as boot disk
image="/var/lib/vz/template/iso/arc.img"
qm importdisk "$VMID" "$image" local-lvm
qm set "$VMID" -sata0 local-lvm:vm-$VMID-disk-0
qm set "$VMID" --boot c --bootdisk sata0

# Add a new SATA disk to the virtual machine
qm set "$VMID" --sata1 volume02:32

# Start the virtual machine
qm start "$VMID"