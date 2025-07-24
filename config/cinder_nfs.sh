sudo systemctl stop rpcbind.service
sudo systemctl stop rpcbind.socket
cat << EOF > $HOME/nfs_shares
$ADDR:/nfs
EOF

highlight -O ansi $HOME/nfs_shares
