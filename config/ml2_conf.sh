cat << EOF > $HOME/ml2_conf.ini
[ml2_type_vlan]
network_vlan_ranges = physnet1:1500:4000,physnet2:1400:1450

[ml2_type_flat]
flat_networks = *
EOF

highlight -O ansi $HOME/ml2_conf.ini
