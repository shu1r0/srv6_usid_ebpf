#!/usr/bin/env bash


# ref:
#    * https://wiki.fd.io/view/VPP/Progressive_VPP_Tutorial


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

    echo_run ip netns exec ns1 ip link set lo up
    echo_run ip netns exec ns2 ip link set lo up
    echo_run ip netns exec ns3 ip link set lo up
    echo_run ip netns exec ns4 ip link set lo up

    echo_run ip netns exec ns1 ip link set ns1_ns2 up
    echo_run ip netns exec ns4 ip link set ns4_ns3 up

    echo_run ip netns exec ns2 /usr/bin/vpp unix {cli-listen /run/vpp/cli-vpp-ns2.sock} api-segment { prefix vpp-ns2 } 
    echo_run ip netns exec ns3 /usr/bin/vpp unix {cli-listen /run/vpp/cli-vpp-ns3.sock} api-segment { prefix vpp-ns3 } 
    sleep 1

    echo_run ip netns exec ns1 ip addr add 192.168.10.1/24 dev ns1_ns2
    echo_run ip netns exec ns1 ip -6 addr add 2001:db8:10::1/48 dev ns1_ns2
    echo_run ip netns exec ns1 ip route add default via 192.168.10.2
    echo_run ip netns exec ns1 ip -6 route add default via 2001:db8:10::2
    echo_run ip netns exec ns4 ip addr add 192.168.30.2/24 dev ns4_ns3
    echo_run ip netns exec ns4 ip -6 addr add 2001:db8:30::2/48 dev ns4_ns3
    echo_run ip netns exec ns4 ip route add default via 192.168.30.1
    echo_run ip netns exec ns4 ip -6 route add default via 2001:db8:30::1

    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock create host-interface name ns2_ns1
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock create host-interface name ns2_ns3
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock create host-interface name ns3_ns2
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock create host-interface name ns3_ns4

    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set interface state host-ns2_ns1 up
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set interface state host-ns2_ns3 up
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set interface state host-ns3_ns2 up
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set interface state host-ns3_ns4 up

    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set interface ip address host-ns2_ns1 192.168.10.2/24
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set interface ip address host-ns2_ns1 2001:db8:10::2/48
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set interface ip address host-ns2_ns3 192.168.20.1/24
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set interface ip address host-ns3_ns2 192.168.20.2/24
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set interface ip address host-ns2_ns3 2001:db8:20::1/48
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set interface ip address host-ns3_ns2 2001:db8:20::2/48
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set interface ip address host-ns3_ns4 192.168.30.1/24
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set interface ip address host-ns3_ns4 2001:db8:30::1/48

    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock set sr encaps source addr A1::
    # echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock sr localsid address A1:: behavior end
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock sr localsid address A1::4 behavior end.dx4 host-ns2_ns1 192.168.10.1
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock sr policy add bsid A1::999 next A2::4 encap
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock sr steer l3 192.168.30.0/24 via bsid A1::999
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock ip route add A2::/16 via 2001:db8:20::2 host-ns2_ns3

    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock set sr encaps source addr A2::
    # echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock sr localsid address A2:: behavior end
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock sr localsid address A2::4 behavior end.dx4 host-ns3_ns4 192.168.30.2
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock sr policy add bsid A2::999 next A1::4 encap
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock sr steer l3 192.168.10.0/24 via bsid A2::999
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock ip route add A1::/16 via 2001:db8:20::1 host-ns3_ns2

    # enable seg6
    echo_run ip netns exec ns1 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec ns4 $current_dir/../functions.sh enable_seg6
}


test_net() {
    echo_run ip netns exec ns1 ping -c 1 192.168.30.2
    echo_run ip netns exec ns4 ping -c 1 192.168.10.1
}


destroy_net() {
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock delete host-interface name host-ns2_ns1
    echo_run vppctl -s /run/vpp/cli-vpp-ns2.sock delete host-interface name host-ns2_ns3
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock delete host-interface name host-ns3_ns2
    echo_run vppctl -s /run/vpp/cli-vpp-ns3.sock delete host-interface name host-ns3_ns4

    echo_run ip netns delete ns1
    echo_run ip netns delete ns2
    echo_run ip netns delete ns3
    echo_run ip netns delete ns4

    echo_run kill $(ps aux | grep '[c]li-vpp-ns2.sock' | awk '{print $2}')
    echo_run kill $(ps aux | grep '[c]li-vpp-ns3.sock' | awk '{print $2}')
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
