#!/usr/bin/env bash


if [[ $(id -u) -ne 0 ]]; then 
    echo "Require root privilege"
    exit 1
fi


current_script=$(realpath $0)
current_dir=$(dirname $current_script)

echo_run () {
    echo "$@"
    $@ || exit 1
}


create_net() {
    echo_run ip netns add ns1
    echo_run ip netns add ns2

    echo_run ip link add name ns1_vpp0 type veth peer name vpp0_ns1
    echo_run ip link set ns1_vpp0 netns ns1
    echo_run ip link add name ns2_vpp0 type veth peer name vpp0_ns2
    echo_run ip link set ns2_vpp0 netns ns2

    echo_run ip netns exec ns1 ip link set ns1_vpp0 up
    echo_run ip link set vpp0_ns1 up
    echo_run ip netns exec ns2 ip link set ns2_vpp0 up
    echo_run ip link set vpp0_ns2 up

    echo_run ip netns exec ns1 ip link set lo up
    echo_run ip netns exec ns2 ip link set lo up

    echo_run ip netns exec ns1 ip addr add 192.168.100.1/24 dev ns1_vpp0
    echo_run ip netns exec ns2 ip addr add 192.168.100.2/24 dev ns2_vpp0

    echo_run vppctl create host-interface name vpp0_ns1
    echo_run vppctl create host-interface name vpp0_ns2
    echo_run vppctl set int state host-vpp0_ns1 up
    echo_run vppctl set int state host-vpp0_ns2 up
    echo_run vppctl set int l2 bridge host-vpp0_ns1 1
    echo_run vppctl set int l2 bridge host-vpp0_ns2 1
}

test_net() {
    echo_run ip netns exec ns1 ping -c 1 192.168.100.2
    echo_run ip netns exec ns2 ping -c 1 192.168.100.1
}


destroy_net() {
    echo_run ip netns delete ns1
    echo_run ip netns delete ns2

    echo_run vppctl delete host-interface name vpp0_ns1
    echo_run vppctl delete host-interface name vpp0_ns2
}

while getopts "cdt" opt; do
    case "${opt}" in
        d)
            destroy_net
            ;;
        c)
            create_net
            ;;
        t)
            test_net
            ;;
        *)
            exit 1
            ;;
    esac
done
