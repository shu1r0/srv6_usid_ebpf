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
    # create netns
    echo_run ip netns add h1
    echo_run ip netns add h2
    echo_run ip netns add h3
    echo_run ip netns add h4
    echo_run ip netns add s1
    echo_run ip netns add s2
    echo_run ip netns add s3
    echo_run ip netns add s4

    # set hosts
    echo_run ip link add name h1_s1 type veth peer name s1_h1
    echo_run ip link add name h2_s1 type veth peer name s1_h2
    echo_run ip link add name h3_s4 type veth peer name s4_h3
    echo_run ip link add name h4_s4 type veth peer name s4_h4
    echo_run ip link set h1_s1 netns h1
    echo_run ip link set s1_h1 netns s1
    echo_run ip link set h2_s1 netns h2
    echo_run ip link set s1_h2 netns s1
    echo_run ip link set h3_s4 netns h3
    echo_run ip link set s4_h3 netns s4
    echo_run ip link set h4_s4 netns h4
    echo_run ip link set s4_h4 netns s4

    echo_run ip link add name s1_s2 type veth peer name s2_s1
    echo_run ip link add name s1_s3 type veth peer name s3_s1
    echo_run ip link add name s2_s4 type veth peer name s4_s2
    echo_run ip link add name s3_s4 type veth peer name s4_s3
    echo_run ip link set s1_s2 netns s1
    echo_run ip link set s2_s1 netns s2
    echo_run ip link set s1_s3 netns s1
    echo_run ip link set s3_s1 netns s3
    echo_run ip link set s2_s4 netns s2
    echo_run ip link set s4_s2 netns s4
    echo_run ip link set s3_s4 netns s3
    echo_run ip link set s4_s3 netns s4

    echo_run ip netns exec h1 ip link set h1_s1 up
    echo_run ip netns exec h2 ip link set h2_s1 up
    echo_run ip netns exec h3 ip link set h3_s4 up
    echo_run ip netns exec h4 ip link set h4_s4 up

    echo_run ip netns exec s1 /usr/bin/vpp unix {cli-listen /run/vpp/cli-vpp-s1.sock} api-segment { prefix vpp-s1 }
    echo_run ip netns exec s2 /usr/bin/vpp unix {cli-listen /run/vpp/cli-vpp-s2.sock} api-segment { prefix vpp-s2 }
    echo_run ip netns exec s3 /usr/bin/vpp unix {cli-listen /run/vpp/cli-vpp-s3.sock} api-segment { prefix vpp-s3 }
    echo_run ip netns exec s4 /usr/bin/vpp unix {cli-listen /run/vpp/cli-vpp-s4.sock} api-segment { prefix vpp-s4 }
    sleep 1  # wait vpp

    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock create host-interface name s1_s2
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock create host-interface name s1_s3
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock create host-interface name s1_h1
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock create host-interface name s1_h2
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock create host-interface name s2_s1
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock create host-interface name s2_s4
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock create host-interface name s3_s1
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock create host-interface name s3_s4
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock create host-interface name s4_s2
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock create host-interface name s4_s3
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock create host-interface name s4_h3
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock create host-interface name s4_h4
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface state host-s1_s2 up
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface state host-s1_s3 up
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface state host-s1_h1 up
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface state host-s1_h2 up
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock set interface state host-s2_s1 up
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock set interface state host-s2_s4 up
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock set interface state host-s3_s1 up
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock set interface state host-s3_s4 up
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface state host-s4_s2 up
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface state host-s4_s3 up
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface state host-s4_h3 up
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface state host-s4_h4 up

    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface ip address host-s1_s2 fd00:a::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface ip address host-s1_s3 fd00:b::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface ip address host-s1_h1 fd00:1::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface ip address host-s1_h2 fd00:2::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface ip address host-s1_h1 192.168.1.1/24
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set interface ip address host-s1_h2 192.168.2.1/24
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock set interface ip address host-s2_s1 fd00:a::2/32
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock set interface ip address host-s2_s4 fd00:c::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock set interface ip address host-s3_s1 fd00:b::2/32
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock set interface ip address host-s3_s4 fd00:d::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface ip address host-s4_s2 fd00:c::2/32
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface ip address host-s4_s3 fd00:d::2/32
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface ip address host-s4_h3 fd00:3::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface ip address host-s4_h4 fd00:4::1/32
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface ip address host-s4_h3 192.168.3.1/24
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set interface ip address host-s4_h4 192.168.4.1/24

    echo_run ip netns exec h1 ip addr add 192.168.1.2/24 dev h1_s1
    echo_run ip netns exec h1 ip -6 addr add fd00:1::2/32 dev h1_s1
    echo_run ip netns exec h1 ip route add default via 192.168.1.1
    echo_run ip netns exec h1 ip -6 route add default via fd00:1::1
    echo_run ip netns exec h2 ip addr add 192.168.2.2/24 dev h2_s1
    echo_run ip netns exec h2 ip -6 addr add fd00:2::2/32 dev h2_s1
    echo_run ip netns exec h2 ip route add default via 192.168.2.1
    echo_run ip netns exec h2 ip -6 route add default via fd00:2::1
    echo_run ip netns exec h3 ip addr add 192.168.3.2/24 dev h3_s4
    echo_run ip netns exec h3 ip -6 addr add fd00:3::2/32 dev h3_s4
    echo_run ip netns exec h3 ip route add default via 192.168.3.1
    echo_run ip netns exec h3 ip -6 route add default via fd00:3::1
    echo_run ip netns exec h4 ip addr add 192.168.4.2/24 dev h4_s4
    echo_run ip netns exec h4 ip -6 addr add fd00:4::2/32 dev h4_s4
    echo_run ip netns exec h4 ip route add default via 192.168.4.1
    echo_run ip netns exec h4 ip -6 route add default via fd00:4::1

    # S1 SRv6 setting
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock set sr encaps source addr fd00:bbbb:a::
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr localsid address fd00:bbbb:a:: behavior end
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr localsid address fd00:bbbb:a::4 behavior end.dt4 0
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr localsid address fd00:bbbb:a::6 behavior end.dt6 0
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr policy add bsid fd00:bbbb:a::e4 next fd00:bbbb:d::4 encap
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr policy add bsid fd00:bbbb:a::3e4 next fd00:bbbb:c:: next fd00:bbbb:d::4 encap
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr steer l3 192.168.3.0/24 via bsid fd00:bbbb:a::e4
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock sr steer l3 192.168.4.0/24 via bsid fd00:bbbb:a::3e4
    # sid route
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock ip route add fd00:bbbb:b::/48 via fd00:a::2 host-s1_s2
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock ip route add fd00:bbbb:c::/48 via fd00:b::2 host-s1_s3
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock ip route add fd00:bbbb:d::/48 via fd00:a::2 host-s1_s2
    echo_run vppctl -s /run/vpp/cli-vpp-s1.sock ip route add fd00:bbbb:d::/48 via fd00:b::2 host-s1_s3

    # s2 SRv6 setting
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock set sr encaps source addr fd00:bbbb:b::
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock sr localsid address fd00:bbbb:b:: behavior end
    # sid route
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock ip route add fd00:bbbb:a::/48 via fd00:a::1 host-s2_s1
    echo_run vppctl -s /run/vpp/cli-vpp-s2.sock ip route add fd00:bbbb:d::/48 via fd00:c::2 host-s2_s4

    # s3 SRv6 setting
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock set sr encaps source addr fd00:bbbb:c::
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock sr localsid address fd00:bbbb:c:: behavior end
    # sid route
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock ip route add fd00:bbbb:a::/48 via fd00:b::1 host-s3_s1
    echo_run vppctl -s /run/vpp/cli-vpp-s3.sock ip route add fd00:bbbb:d::/48 via fd00:d::2 host-s3_s4

    # s4 SRv6 setting
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock set sr encaps source addr fd00:bbbb:d::
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr localsid address fd00:bbbb:d:: behavior end
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr localsid address fd00:bbbb:d::4 behavior end.dt4 0
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr localsid address fd00:bbbb:d::6 behavior end.dt6 0
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr policy add bsid fd00:bbbb:d::e4 next fd00:bbbb:a::4 encap
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr policy add bsid fd00:bbbb:d::2e4 next fd00:bbbb:b:: next fd00:bbbb:a::4 encap
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr steer l3 192.168.1.0/24 via bsid fd00:bbbb:d::e4
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock sr steer l3 192.168.2.0/24 via bsid fd00:bbbb:d::2e4
    # sid route
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock ip route add fd00:bbbb:b::/48 via fd00:c::1 host-s4_s2
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock ip route add fd00:bbbb:c::/48 via fd00:d::1 host-s4_s3
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock ip route add fd00:bbbb:a::/48 via fd00:c::1 host-s4_s2
    echo_run vppctl -s /run/vpp/cli-vpp-s4.sock ip route add fd00:bbbb:a::/48 via fd00:d::1 host-s4_s3

    # enable seg6
    echo_run ip netns exec h1 $current_dir/../../functions.sh enable_seg6
    echo_run ip netns exec h2 $current_dir/../../functions.sh enable_seg6
    echo_run ip netns exec h3 $current_dir/../../functions.sh enable_seg6
    echo_run ip netns exec h4 $current_dir/../../functions.sh enable_seg6
}


test_net() {
    echo_run ip netns exec h1 ping -c 2 192.168.3.2
    echo_run ip netns exec h4 ping -c 2 192.168.2.2
}


destroy_net() {
    echo_run ip netns delete h1
    echo_run ip netns delete h2
    echo_run ip netns delete h3
    echo_run ip netns delete h4
    echo_run ip netns delete s1
    echo_run ip netns delete s2
    echo_run ip netns delete s3
    echo_run ip netns delete s4

    echo_run kill $(ps aux | grep '[c]li-vpp-s1.sock' | awk '{print $2}')
    echo_run kill $(ps aux | grep '[c]li-vpp-s2.sock' | awk '{print $2}')
    echo_run kill $(ps aux | grep '[c]li-vpp-s3.sock' | awk '{print $2}')
    echo_run kill $(ps aux | grep '[c]li-vpp-s4.sock' | awk '{print $2}')
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
