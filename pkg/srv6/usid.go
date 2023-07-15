package srv6

import (
	"fmt"
	"github.com/shu1r0/netlink"
	"github.com/shu1r0/netlink/nl"
	"net"
)

const USID_LENGTH = 16

func SEG6uNRouteAdd(dst *net.IPNet, link string, fd int, name string) error {
	if err := AddRouteLWT(dst, link, nl.LWT_BPF_XMIT, fd, name, 0, nil); err != nil {
		return err
	}
	return nil
}

func AddRouteEndBPF(dst *net.IPNet, link string, fd int, name string, table int, via netlink.Destination) error {
	var flags_end_bpf [nl.SEG6_LOCAL_MAX]bool
	flags_end_bpf[nl.SEG6_LOCAL_ACTION] = true
	flags_end_bpf[nl.SEG6_LOCAL_BPF] = true
	endBpfEncap := netlink.SEG6LocalEncap{Flags: flags_end_bpf, Action: nl.SEG6_LOCAL_ACTION_END_BPF}
	if err := endBpfEncap.SetProg(fd, name); err != nil {
		return fmt.Errorf("Set EndBpfEncap error : %s", err)
	}

	oif, err := netlink.LinkByName(link)
	if err != nil {
		return fmt.Errorf("link by name error : %s", err)
	}
	route := netlink.Route{LinkIndex: oif.Attrs().Index, Dst: dst, Encap: &endBpfEncap, Table: table, Via: via}
	if err := netlink.RouteAdd(&route); err != nil {
		return fmt.Errorf("route add error : %s", err)
	}
	return nil
}

func AddRouteLWT(dst *net.IPNet, link string, lwt_hook int, fd int, name string, table int, via netlink.Destination) error {
	bpfEncap := netlink.BpfEncap{}
	if err := bpfEncap.SetProg(lwt_hook, fd, name); err != nil {
		return err
	}

	oif, err := netlink.LinkByName(link)
	if err != nil {
		return fmt.Errorf("link by name error : %s", err)
	}
	route := netlink.Route{LinkIndex: oif.Attrs().Index, Dst: dst, Encap: &bpfEncap, Table: table, Via: via}
	if err := netlink.RouteAdd(&route); err != nil {
		return fmt.Errorf("route add error : %s", err)
	}
	return nil
}
