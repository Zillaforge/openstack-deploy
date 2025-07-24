sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install Docker From Docker Official
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/containerd.io_1.7.25-1_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce_27.5.1-1~ubuntu.22.04~jammy_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-rootless-extras_27.5.1-1~ubuntu.22.04~jammy_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-cli_27.5.1-1~ubuntu.22.04~jammy_amd64.deb

sudo dpkg -i *.deb
rm *.deb
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker
sudo docker version

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml
grep SystemdCgroup /etc/containerd/config.toml
sudo systemctl restart containerd

# change docker cgroup driver to systemd
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo systemctl daemon-reload
sudo systemctl restart docker
systemctl status --no-pager docker



# Essential Tweaks
sudo swapoff -a
cat << EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sleep 2