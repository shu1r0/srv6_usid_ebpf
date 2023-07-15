#!/usr/bin/env bash


if [[ $(id -u) -ne 0 ]]; then 
    echo "Require root privilege"
    exit 1
fi


curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | sudo bash
apt-get update -y
apt-get install -y vpp vpp-plugin-core vpp-plugin-dpdk
apt-get install -y vpp-api-python python3-vpp-api vpp-dbg vpp-dev
