HOME=$(eval echo ~$SUDO_USER)

echo "Destroying OpenStack services..."
source $HOME/venv/bin/activate
kolla-ansible destroy -i $HOME/all-in-one  --yes-i-really-really-mean-it

echo "Stopping and removing NFS server..."
sudo docker kill nfs-server 2>/dev/null || true
sudo docker rm nfs-server 2>/dev/null || true

echo "Cleaning up network interfaces..."
# Remove veth pair interfaces
sudo ip link set veth-ovs down 2>/dev/null || true
sudo ip link set veth-br down 2>/dev/null || true
sudo ip link delete veth-ovs 2>/dev/null || true

# Remove bridge interface  
sudo ip link set dummy1 down 2>/dev/null || true
sudo ip link delete dummy1 2>/dev/null || true

echo "Network cleanup completed."
