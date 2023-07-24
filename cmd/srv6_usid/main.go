package main

import (
	cebpf "github.com/cilium/ebpf"
	"github.com/shu1r0/srv6_usid_ebpf/pkg/ebpf"
	"github.com/shu1r0/srv6_usid_ebpf/pkg/srv6"
	"github.com/urfave/cli"
	"log"
	"net"
	"os"
)

var Commands = []cli.Command{
	{
		Name:  "add",
		Usage: "add uSID Local Action Route",
		Flags: []cli.Flag{
			cli.StringFlag{
				Name: "action, a",
			},
			cli.StringFlag{
				Name: "link, l",
			},
		},
		Action: func(c *cli.Context) error {
			dstS := c.Args().First()
			_, dst, err := net.ParseCIDR(dstS)
			_, masklen := dst.Mask.Size()
			ebpfObj, err := ebpf.NewEBpfObjects(uint16(masklen-srv6.USID_LENGTH), &cebpf.CollectionOptions{
				Programs: cebpf.ProgramOptions{
					LogLevel: 5,
					LogSize:  65536,
				}})
			if err != nil {
				log.Fatal(err)
			}
			switch c.String("a") {
			case "uN":
				if err := srv6.SEG6uNRouteAdd(dst, c.String("l"), ebpfObj.DoUsidUN.FD(), ebpfObj.DoUsidUN.String()); err != nil {
					log.Fatal(err)
				}
			}
			return nil
		},
	},
}

func main() {
	app := cli.NewApp()
	app.Name = "srv6_usid"
	app.Commands = Commands

	if err := app.Run(os.Args); err != nil {
		panic(err)
	}
}
