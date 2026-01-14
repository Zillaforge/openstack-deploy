cat << EOF > $HOME/manila-share.conf
[generic]
service_instance_flavor_id = 3a0e8d48-4c78-4b7a-b8d9-7b681094004b
connect_share_server_to_tenant_network = True
EOF

highlight -O ansi $HOME/manila-share.conf