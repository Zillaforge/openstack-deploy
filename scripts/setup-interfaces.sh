#!/bin/bash
ip link add dummy1 type bridge
ip link set dummy1 up
ip addr add 10.0.2.2/24 dev dummy1
ip link add veth-ovs type veth peer name veth-br
ip link set veth-br master dummy1
ip link set veth-ovs up
ip link set veth-br up
