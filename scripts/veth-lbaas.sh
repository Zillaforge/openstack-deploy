#!/bin/bash
sudo ip link add v-lbaas-vlan type veth peer name v-lbaas
sudo ip addr add 172.18.255.254/16 dev v-lbaas
sudo ip link set v-lbaas-vlan up
sudo ip link set v-lbaas up