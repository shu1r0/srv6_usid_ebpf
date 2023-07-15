from mininet.log import setLogLevel
from ipnet import IPNetwork, IPNode, CLIX
"""
ルーティングテーブルの設定どうするか問題
fdbb:bbbb::になったらどうなるの問題
"""


n1_conf = """\
configure terminal
interface n1_h1
  ipv6 address fd00:a::1/64
  ipv6 router isis 1
interface n1_n2
  ipv6 address fd00:12::1/64
  ipv6 router isis 1
interface n1_n3
  ipv6 address fd00:13::1/64
  ipv6 router isis 1
interface lo
  ipv6 address fdbb:bbbb:0100::/40
  ipv6 router isis 1

router isis 1
  net 49.0000.0000.0000.0001.00
  is-type level-1
exit

"""

n2_conf = """\
configure terminal
interface n2_h2
  ipv6 address fd00:b::1/64
  ipv6 router isis 1
interface n2_n1
  ipv6 address fd00:12::2/64
  ipv6 router isis 1
interface n2_n4
  ipv6 address fd00:24::1/64
  ipv6 router isis 1
interface lo
  ipv6 address fdbb:bbbb:0200::/40
  ipv6 router isis 1

router isis 1
  net 49.0000.0000.0000.0002.00
  is-type level-1
exit

"""

n3_conf = """\
configure terminal
interface n3_n1
  ipv6 address fd00:13::2/64
  ipv6 router isis 1
interface n3_n4
  ipv6 address fd00:34::1/64
  ipv6 router isis 1
interface n3_n5
  ipv6 address fd00:35::1/64
  ipv6 router isis 1
interface lo
  ipv6 address fdbb:bbbb:0300::/40
  ipv6 router isis 1

router isis 1
  net 49.0000.0000.0000.0003.00
  is-type level-1
exit

"""

n4_conf = """\
configure terminal
interface n4_n2
  ipv6 address fd00:24::2/64
  ipv6 router isis 1
interface n4_n3
  ipv6 address fd00:34::2/64
  ipv6 router isis 1
interface n4_n6
  ipv6 address fd00:46::1/64
  ipv6 router isis 1
interface lo
  ipv6 address fdbb:bbbb:0400::/40
  ipv6 router isis 1

router isis 1
  net 49.0000.0000.0000.0004.00
  is-type level-1
exit

"""

n5_conf = """\
configure terminal
interface n5_n3
  ipv6 address fd00:35::1/64
  ipv6 router isis 1
interface n5_n6
  ipv6 address fd00:56::1/64
  ipv6 router isis 1
interface lo
  ipv6 address fdbb:bbbb:0500::/40
  ipv6 router isis 1

router isis 1
  net 49.0000.0000.0000.0005.00
  is-type level-1
exit

"""

n6_conf = """\
configure terminal
interface n6_n4
  ipv6 address fd00:46::2/64
  ipv6 router isis 1
interface n6_n5
  ipv6 address fd00:56::2/64
  ipv6 router isis 1
interface lo
  ipv6 address fdbb:bbbb:0600::/40
  ipv6 router isis 1

router isis 1
  net 49.0000.0000.0000.0006.00
  is-type level-1
exit

"""


def main():
    setLogLevel("info")
    net = IPNetwork()

    h1 = net.addHost("h1", cls=IPNode)
    h2 = net.addHost("h2", cls=IPNode)
    n1 = net.addFRR("n1", enable_daemons=["isisd", "staticd"])
    n2 = net.addFRR("n2", enable_daemons=["isisd", "staticd"])
    n3 = net.addFRR("n3", enable_daemons=["isisd", "staticd"])
    n4 = net.addFRR("n4", enable_daemons=["isisd", "staticd"])
    n5 = net.addFRR("n5", enable_daemons=["isisd", "staticd"])
    n6 = net.addFRR("n6", enable_daemons=["isisd", "staticd"])

    net.addLink(h1, n1, intfName1="h1_n1", intfName2="n1_h1")
    net.addLink(h2, n2, intfName1="h2_n2", intfName2="n2_h2")
    net.addLink(n1, n2, intfName1="n1_n2", intfName2="n2_n1")
    net.addLink(n1, n3, intfName1="n1_n3", intfName2="n3_n1")
    net.addLink(n2, n4, intfName1="n2_n4", intfName2="n4_n2")
    net.addLink(n3, n4, intfName1="n3_n4", intfName2="n4_n3")
    net.addLink(n3, n5, intfName1="n3_n5", intfName2="n5_n3")
    net.addLink(n4, n6, intfName1="n4_n6", intfName2="n6_n4")
    net.addLink(n5, n6, intfName1="n5_n6", intfName2="n6_n5")

    h1.set_ipv6_cmd("fd00:a::2/64", "h1_n1")
    h1.cmd("ip -6 route add default dev h1_n1 via fd00:a::1")
    h2.set_ipv6_cmd("fd00:b::2/64", "h2_n2")
    h2.cmd("ip -6 route add default dev h2_n2 via fd00:b::1")

    net.start()

    n1.vtysh_cmd(n1_conf)
    n2.vtysh_cmd(n2_conf)
    n3.vtysh_cmd(n3_conf)
    n4.vtysh_cmd(n4_conf)
    n5.vtysh_cmd(n5_conf)
    n6.vtysh_cmd(n6_conf)

    n1.cmd("../cmd/srv6_usid/main add fdbb:bbbb:0100::/48 -action uN -link n1_n2")
    n1.cmd("ip -6 route add fdbb:bbbb:0100::/64 encap seg6local End flavors psp,usp dev n1_n2", verbose=True)
    n2.cmd("../cmd/srv6_usid/main add fdbb:bbbb:0200::/48 -action uN -link n2_n1")
    n2.cmd("ip -6 route add fdbb:bbbb:0200::/64 encap seg6local End flavors psp,usp dev n2_n1", verbose=True)
    n3.cmd("../cmd/srv6_usid/main add fdbb:bbbb:0300::/48 -action uN -link n3_n4")
    n3.cmd("ip -6 route add fdbb:bbbb:0300::/64 encap seg6local End flavors psp,usp dev n3_n4", verbose=True)
    n4.cmd("../cmd/srv6_usid/main add fdbb:bbbb:0400::/48 -action uN -link n4_n3")
    n4.cmd("ip -6 route add fdbb:bbbb:0400::/64 encap seg6local End flavors psp,usp dev n4_n3", verbose=True)
    n5.cmd("../cmd/srv6_usid/main add fdbb:bbbb:0500::/48 -action uN -link n5_n6")
    n5.cmd("ip -6 route add fdbb:bbbb:0500::/64 encap seg6local End flavors psp,usp dev n5_n6", verbose=True)
    n6.cmd("../cmd/srv6_usid/main add fdbb:bbbb:0600::/48 -action uN -link n6_n5")
    n6.cmd("ip -6 route add fdbb:bbbb:0600::/64 encap seg6local End flavors psp,usp dev n6_n5", verbose=True)

    CLIX(net)

    net.stop()


if __name__ == '__main__':
    main()
