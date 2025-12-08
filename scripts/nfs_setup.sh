#!/bin/bash

sudo apt update
sudo apt install nfs-kernel-server

sudo mkdir -p /mnt/nfs
sudo chown nobody:nogroup /mnt/nfs
sudo chmod 777 /mnt/nfs

echo '/mnt/nfs *(rw,sync,no_root_squash,no_subtree_check)' | sudo tee -a /etc/exports
sudo exportfs -a

sudo systemctl restart nfs-kernel-server
