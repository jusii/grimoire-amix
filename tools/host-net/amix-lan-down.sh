#!/bin/sh
# amix-lan-down.sh -- tear down everything amix-lan-up.sh created. Idempotent.
# Does NOT touch the host's own IP/route (the routed-TAP model never changed them).
GUEST_IP="${GUEST_IP:-192.168.2.38}"
TAP="${TAP:-tap0}"
ETH="${ETH:-$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')}"

ip route del "$GUEST_IP/32" dev "$TAP" 2>/dev/null || true
for CHAIN in DOCKER-USER FORWARD; do
    iptables -D "$CHAIN" -i "$TAP" -o "$ETH" -j ACCEPT 2>/dev/null || true
    iptables -D "$CHAIN" -i "$ETH" -o "$TAP" -j ACCEPT 2>/dev/null || true
done
[ -n "$ETH" ] && sysctl -wq "net.ipv4.conf.$ETH.proxy_arp=0" 2>/dev/null || true
ip link del "$TAP" 2>/dev/null || true
# ip_forward is left as-is (Docker and others rely on it).
echo "[amix-lan] down."
