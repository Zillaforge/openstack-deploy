#!/bin/bash

sudo mkdir -p /mnt/nfs

echo "check if disk can mount"
for disk in /dev/sd?; do
    # Skip the root disk
    mountpoint=$(lsblk -no MOUNTPOINT "$disk" | grep '/$')
    [ -n "$mountpoint" ] && continue

    # Skip if mounted
    if lsblk -no MOUNTPOINT "$disk" | grep -qv '^$'; then
        echo "$disk is in use (mounted), skipping."
        continue
    fi

    # Check if any partitions are mounted
    if lsblk -ln "$disk" | awk '{print $1}' | grep -q -v "^$(basename $disk)$"; then
        partitions=$(lsblk -ln "$disk" | awk '{print $1}' | grep -v "^$(basename $disk)$")
        for part in $partitions; do
            if mount | grep -q "/dev/$part"; then
                echo "$disk partition $part is mounted, skipping."
                continue 2
            fi
        done
    fi

    echo "Wiping $disk..."
    wipefs -a "$disk"
    dd if=/dev/zero of="$disk" bs=1M count=10 status=progress

    echo "Creating new partition on $disk..."
    echo -e "o\nn\np\n1\n\n\nw" | fdisk "$disk"

    part="${disk}1"
    sleep 1
    partprobe "$disk"

    echo "Formatting $part as ext4..."
    mkfs.ext4 "$part"

    mkdir -p /mnt/nfs
    echo "Mounting $part to /mnt/nfs..."
    mount "$part" /mnt/nfs

    echo "Done. Mounted $part to /mnt/nfs"
    break  # Remove this if you want to do multiple disks
done

sudo chown $USER:$USER /mnt/nfs

sudo docker run -d --privileged --restart=always --network=host --name nfs-server \
-v /mnt/nfs:/nfs \
-e NFS_EXPORT_DIR_1=/nfs \
-e NFS_EXPORT_DOMAIN_1=\* \
-e NFS_EXPORT_OPTIONS_1=rw,insecure,no_subtree_check,no_root_squash,fsid=1 \
fuzzle/docker-nfs-server:latest
