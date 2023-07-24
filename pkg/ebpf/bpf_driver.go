package ebpf

import (
	"fmt"
	_ "unsafe"

	"github.com/cilium/ebpf"
)

// -cflags "-O2 -Wall"
//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -cflags "-O2 -Wall" srv6usid ../../ebpf/srv6_usid.c -- -I../../ebpf/ -I/usr/include/

type EBpfObjects struct {
	srv6usidObjects
}

func NewEBpfObjects(usidBlockLen uint16, options *ebpf.CollectionOptions) (*EBpfObjects, error) {
	driver := &EBpfObjects{}

	spec, err := loadSrv6usid()
	if err != nil {
		return nil, fmt.Errorf("Load program err: %s", err)
	}
	// if _, ok := spec.Maps[".rodata"]; !ok {
	// 	return nil, fmt.Errorf("could not find .rodata section to set argument\n")
	// }
	if err := spec.RewriteConstants(map[string]interface{}{"USID_BLOCK_LENGTH": usidBlockLen}); err != nil {
		return nil, fmt.Errorf("Rewrite USID_BLOCK_LENGTH err: %s", err)
	}

	if err := spec.LoadAndAssign(driver, options); err != nil {
		return nil, fmt.Errorf("Load and Assign err: %s", err)
	}
	return driver, nil
}

func (obj *EBpfObjects) GetStats() (map[string]uint32, error) {
	stats := map[string]uint32{
		"BPF_OK":   0,
		"BPF_DROP": 0,
	}
	if err := obj.Stats.Lookup(0, stats["BPF_OK"]); err != nil {
		return nil, err
	}
	if err := obj.Stats.Lookup(1, stats["BPF_DROP"]); err != nil {
		return nil, err
	}
	return stats, nil
}
