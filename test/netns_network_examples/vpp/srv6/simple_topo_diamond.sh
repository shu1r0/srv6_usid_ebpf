#!/usr/bin/env bash


# ref:
#    * https://wiki.fd.io/view/VPP/Progressive_VPP_Tutorial


if [[ $(id -u) -ne 0 ]]; then 
    echo "Require root privilege"
    exit 1
fi

current_script=$(realpath $0)
current_dir=$(dirname $current_script)
source $current_dir/../../functions.sh

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

    echo_run add_link s1 s1_h1 h1_s1 h1
    echo_run add_link s1 s1_s2 s2_s1 s2
    echo_run add_link s1 s1_s3 s3_s1 s3

    echo_run add_link s2 s2_h2 h2_s2 h2
    echo_run add_link s2 s2_s3 s3_s2 s3

    echo_run add_link s3 s3_h3 h3_s3 h3
    echo_run add_link s3 s3_s4 s4_s3 s4

    echo_run add_link s4 s4_h4 h4_s4 h4

    echo_run ip netns exec s1 $current_dir/../../functions.sh setup_vpp s1
    echo_run ip netns exec s2 $current_dir/../../functions.sh setup_vpp s2
    echo_run ip netns exec s3 $current_dir/../../functions.sh setup_vpp s3
    echo_run ip netns exec s4 $current_dir/../../functions.sh setup_vpp s4

    echo_run set_addr_vpp_hostinf s1 s1_h1 fd00:1::1/32
    echo_run set_addr_vpp_hostinf s1 s1_s2 fd00:a::1/32
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
