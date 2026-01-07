#!/bin/bash
export HOME=$(eval echo ~$SUDO_USER)
GREEN="\e[32m"
ENDCOLOR="\e[0m"
export NIC=$(ip -o -4 route show to default | awk '{print $5}')
export ADDR=$(ip -o -4 addr show dev $NIC | awk '$3 == "inet" {print $4}' | cut -d/ -f1)
export EXTERNAL_IP=$(curl -s ifconfig.me)


echo -e "${GREEN} Find unuse IP for Haproxy VIP ${ENDCOLOR}"

sudo apt update -y
sudo apt install ipcalc -y

CIDR=$(ip -o -4 addr show dev $NIC | awk '$3 == "inet" {print $4}')
NETWORK=$(ipcalc -n -b $CIDR | grep Network | awk '{print $2}')
BROADCAST=$(ipcalc -n -b $CIDR | grep Broadcast | awk '{print $2}')
IFS='.' read -r i1 i2 i3 i4 <<< "${NETWORK%/*}"
IFS='.' read -r b1 b2 b3 b4 <<< "$BROADCAST"

# 建立可用 IP 範圍陣列並隨機打亂順序
available_ips=()
for ip in $(seq $((i4+1)) $((b4-1))); do
  available_ips+=($ip)
done

# 使用 shuf 隨機打亂陣列（如果沒有 shuf，則用 sort -R）
if command -v shuf >/dev/null 2>&1; then
  randomized_ips=($(printf '%s\n' "${available_ips[@]}" | shuf))
else
  randomized_ips=($(printf '%s\n' "${available_ips[@]}" | sort -R))
fi


# 隨機檢查 IP
for ip in "${randomized_ips[@]}"; do
  candidate="$i1.$i2.$i3.$ip"
  echo "Checking IP: $candidate"
  ping -c1 -W1 $candidate &> /dev/null
  if [ $? -ne 0 ]; then
    echo -e "${GREEN} found unused ip address: $candidate ${ENDCOLOR}"
    
    # 檢查是否啟用自動部署模式
    if [ "$ENABLE_AUTO_DEPLOY_MODE" = "true" ]; then
      VIP=$candidate
      echo -e "${GREEN} Auto deploy mode enabled, using VIP: $VIP ${ENDCOLOR}"
      break
    else
      # 手動確認模式
      while true; do
        read -p "Do you want to use $candidate as VIP? (y/n): " answer
        case "$answer" in
          [Yy]* )
            VIP=$candidate
            echo -e "${GREEN} Using VIP: $VIP ${ENDCOLOR}"
            break 2
            ;;
          [Nn]* )
            echo "Skipping $candidate, looking for next available IP..."
            break
            ;;
          * )
            echo "Invalid input. Please enter 'y' or 'n'."
            ;;
        esac
      done
    fi
  fi
done

# 檢查是否找到並確認了 VIP
if [ -z "$VIP" ]; then
  echo -e "\e[31mNo VIP was selected or no available IP found. Exiting.\e[0m"
  exit 1
fi


echo -e "${GREEN} install necessary package ${ENDCOLOR}"
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
sudo cp ./scripts/setup-interfaces.sh       /usr/local/bin/setup-interfaces.sh
sudo chmod +x /usr/local/bin/setup-interfaces.sh
sudo cp ./scripts/setup-interfaces.service  /etc/systemd/system/setup-interfaces.service
sudo systemctl daemon-reload
sudo systemctl enable setup-interfaces.service
sudo systemctl start  setup-interfaces.service

echo -e "${GREEN} generate ml2_conf.ini ${ENDCOLOR}"
bash ./config/ml2_conf.sh
echo -e "${GREEN} generate neutron config ${ENDCOLOR}"
bash ./config/neutron_conf.sh
echo -e "${GREEN} generate nova config ${ENDCOLOR}"
bash ./config/nova_conf.sh
echo -e "${GREEN} generate cinder config ${ENDCOLOR}"
bash ./config/cinder_conf.sh
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
mv $HOME/neutron.conf $HOME/nova.conf $HOME/cinder.conf $HOME/nfs_shares $HOME/octavia.conf /etc/kolla/config
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
sed -i "s|^#kolla_external_vip_address: \"{{ kolla_internal_vip_address }}\"|kolla_external_vip_address: \"$EXTERNAL_IP\"|" /etc/kolla/globals.yml
sed -i 's|^#horizon_port: 80|horizon_port: 8080|' /etc/kolla/globals.yml
sed -i 's|^#horizon_tls_port: 443|horizon_tls_port: 8443|' /etc/kolla/globals.yml
echo "run bootstrap script"
kolla-ansible bootstrap-server -i $HOME/all-in-one 
echo "deploy nfs-server "
sudo bash ./scripts/nfs_setup.sh
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
    # 根據模式決定是否有超時限制
    if [ "$ENABLE_AUTO_DEPLOY_MODE" = "true" ]; then
        # 自動模式：最多等30秒，超時預設為n
        read -t 30 -p "Do you want to set up Keystone LDAP? (y/n): " answer
        if [ -z "$answer" ]; then
            answer="n"
            echo -e "\n${GREEN} Auto deploy mode: timeout reached, skipping Keystone LDAP setup. ${ENDCOLOR}"
        fi
    else
        # 手動模式：無超時限制，一直等待使用者輸入
        read -p "Do you want to set up Keystone LDAP? (y/n): " answer
    fi
    
    # 處理使用者輸入
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
