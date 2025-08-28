#!/bin/bash
export HOME=$(eval echo ~$SUDO_USER)
GREEN="\e[32m"
ENDCOLOR="\e[0m"
export NIC=$(ip -o -4 route show to default | awk '{print $5}')
export ADDR=$(ip -o -4 addr show dev $NIC | awk '$3 == "inet" {print $4}' | cut -d/ -f1)


echo -e "${GREEN} Find unuse IP for Haproxy VIP ${ENDCOLOR}"

sudo apt update -y
sudo apt install ipcalc -y

CIDR=$(ip -o -4 addr show dev $NIC | awk '$3 == "inet" {print $4}')
NETWORK=$(ipcalc -n -b $CIDR | grep Network | awk '{print $2}')
BROADCAST=$(ipcalc -n -b $CIDR | grep Broadcast | awk '{print $2}')
IFS='.' read -r i1 i2 i3 i4 <<< "${NETWORK%/*}"
IFS='.' read -r b1 b2 b3 b4 <<< "$BROADCAST"
for ip in $(seq $((i4+1)) $((b4-1))); do
  candidate="$i1.$i2.$i3.$ip"
  echo "Checking IP: $candidate"
  ping -c1 -W1 $candidate &> /dev/null
  if [ $? -ne 0 ]; then
    VIP=$candidate
    echo -e "${GREEN} found unuse ip address:  $VIP ${ENDCOLOR}"
    break
  fi
done

echo -e "${GREEN} install necessery package ${ENDCOLOR}"
sudo apt update -y
sudo apt install git python3-dev libffi-dev gcc libssl-dev dnsmasq-base highlight nfs-common -y
sudo apt install build-essential libdbus-glib-1-dev libgirepository1.0-dev -y
sudo apt install python3-venv  python3-pip -y
python3 -m venv $HOME/venv
source $HOME/venv/bin/activate
echo -e "${GREEN} setup docker ${ENDCOLOR}"
./scripts/docker_setup.sh

echo -e "${GREEN} install python package ${ENDCOLOR}"
pip install  'ansible-core>=2.16,<2.17.99'
pip install  dbus-python
pip install  docker
pip install   git+https://opendev.org/openstack/kolla-ansible@stable/2025.1

echo -e "${GREEN} install kolla-ansible dependencies ${ENDCOLOR}"
kolla-ansible install-deps
echo -e "${GREEN} copy config to /etc/kolla ${ENDCOLOR}"
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
mkdir -p /etc/kolla/config
mkdir -p /etc/kolla/config/neutron
mkdir -p /etc/kolla/config/keystone/domains
cp -r $HOME/venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp ./config/globals.yml /etc/kolla/
cp $HOME/venv/share/kolla-ansible/ansible/inventory/all-in-one $HOME/.
echo -e "${GREEN} generate password ${ENDCOLOR}"
kolla-genpwd

echo -e "${GREEN} create fake interface for openstack external network ${ENDCOLOR}"
sudo ip link add dummy1 type bridge
sudo ip link set dummy1 up
sudo ip addr add 10.0.2.2/24 dev dummy1
sudo ip link add veth-ovs type veth peer name veth-br
sudo ip link set veth-br master dummy1
sudo ip link set veth-ovs up
sudo ip link set veth-br up

echo -e "${GREEN} generate ml2_conf.ini ${ENDCOLOR}"
bash ./config/ml2_conf.sh
echo -e "${GREEN} generate neutron config ${ENDCOLOR}"
bash ./config/neutron_conf.sh
echo -e "${GREEN} generate nova config ${ENDCOLOR}"
bash ./config/nova_conf.sh
echo -e "${GREEN} generate nfs config for cinder ${ENDCOLOR}"
bash ./config/cinder_nfs.sh
echo -e "${GREEN} generate keystone config for ldap service ${ENDCOLOR}"
bash ./config/keystone_conf.sh
echo -e "${GREEN} generate octavia config ${ENDCOLOR}"
bash ./config/octavia_conf.sh
echo "generate install script"
cat << EOF > ./kolla_deploy.sh
#!/bin/bash
source $HOME/venv/bin/activate

echo "copy config"
mv $HOME/neutron.conf $HOME/nova.conf $HOME/nfs_shares $HOME/octavia.conf /etc/kolla/config
mv $HOME/ml2_conf.ini /etc/kolla/config/neutron/
mv $HOME/keystone.trustedcloud.conf /etc/kolla/config/keystone/domains/
echo "enable service in global.yml"
sed -i "s|^#network_interface: \"eth0\"$|network_interface: \"$NIC\"|" /etc/kolla/globals.yml
sed -i "s|^#kolla_internal_vip_address: \"10.10.10.254\"$|kolla_internal_vip_address:  \"$VIP\"|" /etc/kolla/globals.yml
sed -i 's|^#kolla_base_distro: "rocky"$|kolla_base_distro: "ubuntu"|' /etc/kolla/globals.yml
sed -i 's|^#neutron_external_interface: "eth1"$|neutron_external_interface: "veth-ovs"|' /etc/kolla/globals.yml
sed -i 's|^#neutron_plugin_agent: "openvswitch"$|neutron_plugin_agent: "ovn"|' /etc/kolla/globals.yml
sed -i 's|^#enable_cinder_backup: "yes"$|enable_cinder_backup: "no"|' /etc/kolla/globals.yml
sed -i 's|^#enable_cinder_backend_nfs: "no"$|enable_cinder_backend_nfs: "yes"|' /etc/kolla/globals.yml
sed -i 's|^#enable_cinder: "no"$|enable_cinder: "yes"|' /etc/kolla/globals.yml
sed -i 's|^#enable_neutron_provider_networks: "no"$|enable_neutron_provider_networks: "yes"|' /etc/kolla/globals.yml
echo "run bootstrap script"
kolla-ansible bootstrap-server -i $HOME/all-in-one 
echo "deploy nfs-server "
sudo bash ./scripts/nfs_mount.sh
echo "run precheck script"
kolla-ansible prechecks -i $HOME/all-in-one
echo "generate octavia certificate"
kolla-ansible octavia-certificates -i $HOME/all-in-one
echo "deploy kolla openstack"
kolla-ansible deploy -i $HOME/all-in-one
echo "run post-deploy script"
pip install python-openstackclient
kolla-ansible post-deploy -i $HOME/all-in-one
echo "post-deploy script complete"
EOF
echo -e "${GREEN} run install script kolla_deploy.sh ${ENDCOLOR}"
sudo chmod 755 ./kolla_deploy.sh
bash ./kolla_deploy.sh

# echo -e "${GREEN} Reconfig kolla-openstack for novnc external access ${ENDCOLOR}"
# Get IP configuration
# export HOSTIP=$(curl -s ipinfo.io/ip)
# export HOSTIP_DASH=$(echo "$HOSTIP" | sed 's/\./-/g')
# sed -i "s/^#\?kolla_external_fqdn: .*/kolla_external_fqdn: \"${HOSTIP_DASH}.nip.io\"/" /etc/kolla/globals.yml
# kolla-ansible reconfig -i $HOME/all-in-one --tags nova


echo -e "${GREEN} Deploy kolla-openstack complete ${ENDCOLOR}"

echo ""
echo -e "${GREEN} Check if openstack is accessible ${ENDCOLOR}"
bash ./scripts/openstack_health_check.sh 

while true; do
    read -t 30 -p "Do you want to set up Keystone LDAP? (y/n): " answer
    if [ -z "$answer" ]; then
        answer="n"
    fi
    case "$answer" in
        [Yy]* )
            echo "Setting up Keystone LDAP..."
            bash ./scripts/keystone_ldap_setup.sh
            break
            ;;
        [Nn]* )
            echo "Skipping Keystone LDAP setup."
            break
            ;;
        * )
            echo "Invalid input. Please enter 'y' or 'n'."
            ;;
    esac
done

echo -e "${GREEN} you may now login via ${ENDCOLOR} http://$ADDR"
echo -e "default admin password \033[0;31m $(cat /etc/kolla/passwords.yml | grep keystone_admin | awk '{print $2}') \033[0m stores in /etc/kolla/passwords.yml"
echo -e "${GREEN} to use openstack-cli you will need to  export the path to your env with following command ${ENDCOLOR}"
echo -e "source $HOME/venv/bin/activate\nexport OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml\nexport OS_CLOUD=kolla-admin"

sudo rm ./kolla_deploy.sh
