#!/bin/bash

# Get default IP from current route
default_ip=$(ip -o -4 addr show $(ip -o -4 route show to default | awk '{print $5}') | awk '{print $4}' | cut -d/ -f1)
default_user="test@trusted-cloud.nchc.org.tw"
default_password="password123"
# Prompt with default
read -t 30 -p "Enter ldap server IP address (default ldap ip addr: [${default_ip}]): " allowed_ip
allowed_ip=${allowed_ip:-$default_ip}
echo ""
read -t 30 -p "Enter ldap user (default ldap user: [${default_user}]): " ldap_user
echo ""
read -t 30 -p "Enter ldap password (default ldap password: [${default_password}]): " ldap_password
echo ""

echo "User: ${ldap_user:-$default_user}"
cat << EOF > $HOME/keystone.trustedcloud.conf
[ldap]
url=ldap://${allowed_ip}:30891
user=dc=${ldap_user:-$default_user}
password=${ldap_password:-$default_password}
user_tree_dn=ou=users,dc=cloud-infra,dc=asus,dc=com,dc=tw
user_objectclass = iamUsers
user_allow_create=False
user_allow_update=False
user_allow_delete=False
chase_referrals=False
use_pool=False
pool_size=10
pool_retry_max=3
pool_retry_delay=0.1
pool_connection_timeout=-1
pool_connection_lifetime=600
use_auth_pool=False
auth_pool_size=100
auth_pool_connection_lifetime=60
query_scope=sub
user_id_attribute=uid
user_name_attribute=cn
group_allow_create = True
group_allow_update = True
group_allow_delete = True

[identity]
driver=ldap
EOF

highlight -O ansi $HOME/keystone.trustedcloud.conf
