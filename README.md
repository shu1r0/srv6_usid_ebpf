

## 

```
2023/07/13 08:46:23 field DoUsidUN: program do_usid_uN: load program: permission denied: cannot write into packet (24 line(s) omitted)
```


## github.com/shu1r0/netlinkについて
End.BPFを実装したnetlinkモジュールです．
なぜか，shu1r0/netlink/go.modでreplaceしても上手く行かない．
```
< GOPROXY=direct go mod tidy
go: found github.com/vishvananda/netlink/nl in github.com/vishvananda/netlink v1.2.1
go: github.com/shu1r0/netlink@v0.0.0-20230712002221-7aaa8bff150f used for two different module paths (github.com/shu1r0/netlink and github.com/vishvananda/netlink)
```
ので，gitのsubmoduleを置いて置き換えています．
```
╭─shu1r0@shu1r0-ryzen-desktop /home/shu1r0/workspace/ebpf_lwt_test/srv6_usid_end_ebpf  (master →☡)
╰─(*ﾉ･ω･)ﾉ < cat go.mod | grep replace
replace github.com/vishvananda/netlink v1.2.1 => ./netlink
```