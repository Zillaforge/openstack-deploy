cat << EOF > $HOME/nova.conf
[quota]
count_usage_from_placement = True
metadata_items = -1
injected_file_content_bytes = -1
server_group_members = -1
server_groups = -1
injected_file_path_length = -1
ram = -1
floating_ips = -1
security_group_rules = -1
instances = -1
key_pairs = -1
injected_files = -1
cores = -1
fixed_ips = -1
security_groups = -1
EOF

highlight -O ansi $HOME/nova.conf
