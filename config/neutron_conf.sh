cat << EOF > $HOME/neutron.conf
[DEFAULT]
global_physnet_mtu = 9000

[quotas]
default_quota = -1
quota_network = -1
quota_subnet = -1
quota_port = -1
quota_router = -1
quota_floatingip = -1
quota_security_group = -1
quota_security_group_rule = -1
quota_rbac_policy = -1
EOF

highlight -O ansi $HOME/neutron.conf
