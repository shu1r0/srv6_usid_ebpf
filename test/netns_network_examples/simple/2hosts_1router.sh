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
    echo_run ip netns add h1
    echo_run ip netns add r1
    echo_run ip netns add h2


    echo_run ip link add name h1_r1 type veth peer name r1_h1
    echo_run ip link add name r1_h2 type veth peer name h2_r1
    echo_run ip link set h1_r1 netns h1
    echo_run ip link set r1_h1 netns r1
    echo_run ip link set r1_h2 netns r1
    echo_run ip link set h2_r1 netns h2

    echo_run ip netns exec h1 ip link set h1_r1 up
    echo_run ip netns exec r1 ip link set r1_h1 up
    echo_run ip netns exec r1 ip link set r1_h2 up
    echo_run ip netns exec h2 ip link set h2_r1 up
    echo_run ip netns exec h1 ip link set lo up
    echo_run ip netns exec r1 ip link set lo up
    echo_run ip netns exec h2 ip link set lo up

    echo_run ip netns exec h1 ip addr add 192.168.10.2/24 dev h1_r1
    echo_run ip netns exec r1 ip addr add 192.168.10.1/24 dev r1_h1
    echo_run ip netns exec h1 ip -6 addr add 2001:db8:10::2/48 dev h1_r1
    echo_run ip netns exec r1 ip -6 addr add 2001:db8:10::1/48 dev r1_h1
    echo_run ip netns exec r1 ip addr add 192.168.20.1/24 dev r1_h2
    echo_run ip netns exec h2 ip addr add 192.168.20.2/24 dev h2_r1
    echo_run ip netns exec r1 ip -6 addr add 2001:db8:20::1/48 dev r1_h2
    echo_run ip netns exec h2 ip -6 addr add 2001:db8:20::2/48 dev h2_r1

    echo_run ip netns exec h1 ip route add default dev h1_r1 via 192.168.10.1
    echo_run ip netns exec h1 ip -6 route add default dev h1_r1 via 2001:db8:10::1
    echo_run ip netns exec h2 ip route add default dev h2_r1 via 192.168.20.1
    echo_run ip netns exec h2 ip -6 route add default dev h2_r1 via 2001:db8:20::1

    # enable seg6
    echo_run ip netns exec h1 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec r1 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec h2 $current_dir/../functions.sh enable_seg6
}

test_net() {
    echo_run ip netns exec h1 ping -c 2 192.168.20.2
    echo_run ip netns exec h1 ping -c 2 2001:db8:20::2
}


destroy_net() {
    echo_run ip netns delete h1
    echo_run ip netns delete r1
    echo_run ip netns delete h2
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
