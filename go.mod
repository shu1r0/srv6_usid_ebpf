module github.com/shu1r0/srv6_usid_ebpf

go 1.18

require (
	github.com/cilium/ebpf v0.11.0
	github.com/urfave/cli v1.22.14
)

require (
	github.com/cpuguy83/go-md2man/v2 v2.0.2 // indirect
	github.com/russross/blackfriday/v2 v2.1.0 // indirect
	github.com/shu1r0/netlink v0.0.0-20230712002221-7aaa8bff150f
	github.com/vishvananda/netlink v1.2.1-beta.2.0.20230705154206-78ac5704cfa0 // indirect
	github.com/vishvananda/netns v0.0.0-20200728191858-db3c7e526aae // indirect
	golang.org/x/exp v0.0.0-20230224173230-c95f2b4c22f2 // indirect
	golang.org/x/sys v0.10.0 // indirect
)

replace github.com/vishvananda/netlink => ./netlink
