#!/bin/bash
ip link add dummy1 type bridge
ip link set dummy1 up
ip addr add 10.0.2.2/24 dev dummy1
ip link add veth-ovs type veth peer name veth-br
ip link set veth-br master dummy1
ip link set veth-ovs up
ip link set veth-br up

# 1. 取得對外網卡的名稱
# 使用 ip route 查詢預設路由 (default)，過濾出 IPv4 (-4) 並以單行顯示 (-o)。
# 輸出通常格式為 "default via 192.168.95.1 dev ens3 ..."
# 使用 awk 取出第 5 個欄位 (即 dev 後面的介面名稱，例如 ens3)，並存入變數 NIC。
NIC=$(ip -o -4 route show to default | awk '{print $5}')

# 2. 設定 NAT (Masquerade) 規則
# -t nat: 操作 nat 表。
# -A POSTROUTING: 將規則附加到路由後 (POSTROUTING) 的鏈。
# -s 10.0.2.0/24: 指定來源 IP 網段為 10.0.2.0/24 (你的 dummy1 網段)。
# -o $NIC: 指定封包流出的介面為剛剛抓到的網卡 (例如 ens3)。
# -j MASQUERADE: 執行偽裝動作，將流出封包的來源 IP 修改為該網卡的 IP。
iptables -t nat -A POSTROUTING -s 10.0.2.0/24 -o $NIC -j MASQUERADE

