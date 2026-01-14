cat << EOF > $HOME/manila.conf
[DEFAULT]
storage_availability_zone = nova
service_instance_user = manila
service_instance_password = manila
EOF

highlight -O ansi $HOME/manila.conf