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

    echo_run ovs-vsctl add-br br0

    echo_run ip link add name ns1_br0 type veth peer name br0_ns1
    echo_run ip link set ns1_br0 netns ns1
    echo_run ovs-vsctl add-port br0 br0_ns1
    echo_run ip link add name ns2_br0 type veth peer name br0_ns2
    echo_run ip link set ns2_br0 netns ns2
    echo_run ovs-vsctl add-port br0 br0_ns2

    echo_run ip link set br0 up
    echo_run ip netns exec ns1 ip link set ns1_br0 up
    echo_run ip link set br0_ns1 up
    echo_run ip netns exec ns2 ip link set ns2_br0 up
    echo_run ip link set br0_ns2 up

    echo_run ip netns exec ns1 ip link set lo up
    echo_run ip netns exec ns2 ip link set lo up

    echo_run ip netns exec ns1 ip addr add 192.168.100.1/24 dev ns1_br0
    echo_run ip netns exec ns2 ip addr add 192.168.100.2/24 dev ns2_br0

    echo_run ovs-ofctl add-flow br0 cookie=1,ip,nw_dst=192.168.100.1,actions=NORMAL
    echo_run ovs-ofctl add-flow br0 cookie=1,ip,nw_dst=192.168.100.2,actions=NORMAL

    echo_run ovs-ofctl add-flow br0 cookie=2,ip,nw_dst=192.168.100.1,actions=NORMAL
}


destroy_net() {
    echo_run ip netns delete ns1
    echo_run ip netns delete ns2

    echo_run ovs-vsctl del-br br0
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
