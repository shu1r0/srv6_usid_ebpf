#!/usr/bin/env bash


if [[ $(id -u) -ne 0 ]]; then 
    echo "Require root privilege"
    exit 1
fi

current_script=$(realpath $0)
current_dir=$(dirname $current_script)
# echo $current_dir

echo_run () {
    echo "$@"
    $@ || exit 1
}

create_net() {
    echo_run ip netns add ns1
    echo_run ip netns add ns2
    echo_run ip netns add ns3
    echo_run ip netns add ns4


    echo_run ip link add name ns1_ns2 type veth peer name ns2_ns1
    echo_run ip link add name ns2_ns3 type veth peer name ns3_ns2
    echo_run ip link add name ns3_ns4 type veth peer name ns4_ns3
    echo_run ip link set ns1_ns2 netns ns1
    echo_run ip link set ns2_ns1 netns ns2
    echo_run ip link set ns2_ns3 netns ns2
    echo_run ip link set ns3_ns2 netns ns3
    echo_run ip link set ns3_ns4 netns ns3
    echo_run ip link set ns4_ns3 netns ns4

    echo_run ip netns exec ns1 ip link set ns1_ns2 up
    echo_run ip netns exec ns2 ip link set ns2_ns1 up
    echo_run ip netns exec ns2 ip link set ns2_ns3 up
    echo_run ip netns exec ns3 ip link set ns3_ns2 up
    echo_run ip netns exec ns3 ip link set ns3_ns4 up
    echo_run ip netns exec ns4 ip link set ns4_ns3 up
    echo_run ip netns exec ns1 ip link set lo up
    echo_run ip netns exec ns2 ip link set lo up
    echo_run ip netns exec ns3 ip link set lo up
    echo_run ip netns exec ns4 ip link set lo up

    echo_run ip netns exec ns1 ip addr add 192.168.10.1/24 dev ns1_ns2
    echo_run ip netns exec ns2 ip addr add 192.168.10.2/24 dev ns2_ns1
    echo_run ip netns exec ns1 ip -6 addr add 2001:db8:10::1/48 dev ns1_ns2
    echo_run ip netns exec ns2 ip -6 addr add 2001:db8:10::2/48 dev ns2_ns1
    echo_run ip netns exec ns2 ip addr add 192.168.20.1/24 dev ns2_ns3
    echo_run ip netns exec ns3 ip addr add 192.168.20.2/24 dev ns3_ns2
    echo_run ip netns exec ns2 ip -6 addr add 2001:db8:20::1/48 dev ns2_ns3
    echo_run ip netns exec ns3 ip -6 addr add 2001:db8:20::2/48 dev ns3_ns2
    echo_run ip netns exec ns3 ip addr add 192.168.30.1/24 dev ns3_ns4
    echo_run ip netns exec ns4 ip addr add 192.168.30.2/24 dev ns4_ns3
    echo_run ip netns exec ns3 ip -6 addr add 2001:db8:30::1/48 dev ns3_ns4
    echo_run ip netns exec ns4 ip -6 addr add 2001:db8:30::2/48 dev ns4_ns3

    # enable seg6
    echo_run ip netns exec ns1 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec ns2 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec ns3 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec ns4 $current_dir/../functions.sh enable_seg6
}


destroy_net() {
    echo_run ip netns delete ns1
    echo_run ip netns delete ns2
    echo_run ip netns delete ns3
    echo_run ip netns delete ns4
}

while getopts "cd" opt; do
    case "${opt}" in
        d)
            destroy_net
            ;;
        c)
            create_net
            ;;
        *)
            exit 1
            ;;
    esac
done
