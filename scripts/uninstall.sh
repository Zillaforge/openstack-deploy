HOME=$(eval echo ~$SUDO_USER)

source $HOME/venv/bin/activate
kolla-ansible destroy -i $HOME/all-in-one  --yes-i-really-really-mean-it
sudo docker kill nfs-server
sudo docker rm nfs-server
