cat << EOF > $HOME/cinder.conf
[DEFAULT]
glance_core_properties = checksum,container_format,disk_format,image_name,image_id,min_disk,min_ram,name,size,signature_verified
EOF

highlight -O ansi $HOME/cinder.conf
