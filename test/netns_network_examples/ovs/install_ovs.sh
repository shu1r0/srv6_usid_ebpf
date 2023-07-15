#!/usr/bin/env bash

## install ovs
apt install -y openvswitch-switch
systemctl start openvswitch-switch
