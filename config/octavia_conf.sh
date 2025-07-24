cat << EOF > $HOME/octavia.conf
[nova]
availability_zone = default

[database]
max_overflow = 1000
EOF

highlight -O ansi $HOME/octavia.conf
