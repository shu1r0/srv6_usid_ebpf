#!/usr/bin/env bash

cd ../; make build; cd -

sudo ./netns_network_examples/simple/2hosts_1router.sh -c
sudo ip netns exec r1 ../cmd/srv6_usid/main add fdbb:bbbb:0100::/48 -action uN -l r1_h1
sudo sleep 1
sudo ip netns exec r1 ip -6 r
sudo sleep 1
sudo ip netns exec h1 srv6ping -c 3 -d 2001:db8:20::1 -s fdbb:bbbb:0100::/48
sudo ./netns_network_examples/simple/2hosts_1router.sh -d
