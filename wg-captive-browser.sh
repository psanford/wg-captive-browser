#!/bin/bash

set -e
set -x

physicalif=wlp61s0
browser_user=psanford
wgif=wg0
hostip=10.129.0.129
nsip=10.129.0.130
# https://github.com/FiloSottile/captive-browser
browser_command=captive-browser

netns=novpn
hostif=novpnhost0
nsif=novpnguest0

die() {
	echo "$PROGRAM: $*" >&2
	exit 1
}

main() {
  if ! wg show $wgif; then
    die "[!] Wireguard interface $wgif not found"
  fi

  trap "cleanup; exit" INT TERM EXIT
  add_netns
  add_veth
  add_iptable_rules

  ip netns exec $netns sudo -u $browser_user -i $browser_command

  cleanup;

  trap - INT TERM EXIT
}

cleanup() {
  rm_iptable_rules
  rm_veth
  rm_netns
}

end() {
  echo 2>/dev/null
  echo "Cleanup veth"
}

netns_exists() {
  ip netns list | egrep '^novpn' || return 1
  return 0
}

add_netns() {
  if netns_exists; then
    return 0
  fi

  ip netns add $netns
}

rm_netns() {
  ip netns delete $netns
}

add_veth() {
  ip link add name $hostif type veth peer name $nsif
  ip link set $nsif netns $netns
  ip addr add $hostip/30 dev $hostif
  ip netns exec $netns ip addr add $nsip/30 dev $nsif
  ip link set $hostif up
  ip netns exec $netns ip link set $nsif up
  ip netns exec $netns ip route add default via $hostip

  ip netns exec $netns ip addr add 127.0.0.1 dev lo
  ip netns exec $netns ip link set lo up
}

rm_veth() {
  ip link delete $hostif || true
}

add_iptable_rules() {
  iptables -A FORWARD -i $hostif -o $physicalif -j ACCEPT
  iptables -A FORWARD -i $physicalif  -o $hostif -m state --state ESTABLISHED,RELATED  -j ACCEPT
  iptables -t nat -A POSTROUTING -s $hostip/30 ! -d $hostip/30 -j MASQUERADE

  fwmark="$(wg show "wg0" fwmark)"
  iptables -t mangle -A PREROUTING -i $hostif -j MARK --set-mark $fwmark
}

rm_iptable_rules() {
  fwmark="$(wg show "wg0" fwmark)"
  iptables -t mangle -D PREROUTING -i $hostif -j MARK --set-mark $fwmark || true

  iptables -t nat -D POSTROUTING -s $hostip/30 ! -d $hostip/30 -j MASQUERADE || true

  iptables -D FORWARD -i $physicalif -o $hostif -m state --state ESTABLISHED,RELATED  -j ACCEPT || true
  iptables -D FORWARD -i $hostif -o $physicalif -j ACCEPT || true
}

main
