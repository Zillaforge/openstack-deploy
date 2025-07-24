export ADDR=$(ip -o -4 route show to default | awk '{print $9}')
export OS_USERNAME=test@trusted-cloud.nchc.org.tw
export OS_PROJECT_NAME=trustedcloud
export OS_USER_DOMAIN_NAME=trustedcloud
export OS_PROJECT_DOMAIN_NAME=trustedcloud
export OS_AUTH_URL=http://$ADDR:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_PASSWORD='password123'

source $HOME/venv/bin/activate

wget https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-20250506.2.x86_64.qcow2 -O CentOS-10.qcow2
openstack image create "CentOS-10" --file CentOS-10.qcow2 --disk-format qcow2 --container-format bare --public
openstack network create --provider-network-type vlan --provider-physical-network physnet1 --provider-segment 1600 n1 --share
openstack subnet create --subnet-range 172.16.100.0/24 --network n1 n1subnet
openstack flavor create small --ram 4096 --disk 80 --vcpus 4
openstack server create test2   --flavor small --image "CentOS-10" --network n1 --boot-from-volume 80

openstack server list
openstack volume list
rm CentOS-10.qcow2
