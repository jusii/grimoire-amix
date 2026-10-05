# tools/host-net — put a networked Amix on your real LAN (Amiberry)

These are the host-side helpers that make an **Amiberry-emulated Amix** appear as a
**real, reachable host on your physical LAN** — with working DNS and internet — and
keep it that way across reboots. They encode exactly the setup verified in
[the LAN networking guide](../../docs/getting-started/networking-on-the-lan.md)
(first-hand, 2026-06: Amiberry 8.1.6, Amix 2.1 / SVR4.0). ✅

## The model: routed TAP + proxy-ARP (not an L2 bridge)

Amiberry 8.x can attach its emulated **A2065** Ethernet card to a Linux **TAP**
device (`a2065=tap0`). We then make the host a tiny **proxy-ARP router** between
that TAP and the LAN NIC, and route the guest's reserved `/32` at the TAP.

Why routed rather than a true L2 bridge:

- It **never touches the host's own IP, default route, or NetworkManager**, so it
  cannot knock the host off the network (important when the same NIC is your only
  uplink). A bridge has to move the host IP onto `br0` — a needless risk here.
- `a2065=tap0` uses `/dev/net/tun` (a `TUNSETIFF` attach, no `cap_net_admin`), **not
  libpcap** — so it works in restricted environments where pcap capture is blocked.
- The guest still gets a genuine LAN IP, is pingable from other LAN hosts, and
  reaches the gateway / DNS / internet. (A true L2 bridge is also fine if you
  prefer it — `ip link add br0 type bridge`, enslave the NIC + `tap0`, move the
  host IP onto `br0`, and set `a2065=tap0`. Same Amiberry/guest config.)

## Files

| File | Purpose |
|---|---|
| `amix-lan-up.sh`   | Idempotent host setup: TAP, proxy-ARP, ip_forward, `/32` route, forward rules (Docker-aware). |
| `amix-lan-down.sh` | Full teardown. |
| `amix-lan.service` | systemd unit so the host side comes up at boot (after `docker.service`). |
| `amixsh.py`        | Run shell commands on Amix over telnet, scripted (no PTY). Good for automation / agents. |
| `amixput.py`       | Upload a file to Amix via FTP (PASV, root). |

**Set your own addresses.** The built-in defaults are RFC 5737 documentation addresses
(`192.0.2.0/24`), which will not work on a real LAN. Everything comes from the environment:

| Variable | Used by | Meaning (example default) |
|---|---|---|
| `GUEST_IP` | `amix-lan-up.sh`, `amix-lan-down.sh` | the Amix guest's address on your LAN (`192.0.2.38`) |
| `TAP_ANCHOR` | `amix-lan-up.sh` | a host-side `/32` on the TAP, any address unused on your LAN (`192.0.2.17`) |
| `ETH`, `TAP`, `TAP_OWNER` | `amix-lan-up.sh` | LAN uplink (autodetected from the default route), TAP name (`tap0`), TAP owner (the invoking user) |
| `AMIX_HOST`, `AMIX_PORT`, `AMIX_USER`, `AMIX_PASS` | `amixsh.py`, `amixput.py`, `amixsync.py` | the guest to talk to (`192.0.2.38`), FTP port, login (`root` / a placeholder password) |

For example: `GUEST_IP=192.168.1.50 TAP_ANCHOR=192.168.1.250 ETH=eth0 sudo -E sh amix-lan-up.sh`,
then `AMIX_HOST=192.168.1.50 python3 amixsh.py 'uname -a'`.

## Quick start

```sh
# 1. Host side (once per boot, or install the service below):
sudo sh amix-lan-up.sh

# 2. Start Amiberry with the A2065 on the TAP. In your .uae config:
#       a2065=tap0
#       a2065_rom_options=mac=00:80:10:00:00:38     # MUST be Commodore OUI 00:80:10; unique on your LAN
#       bsdsocket_emu=false
#    (plus the usual A3000 / KS 2.04 / 68030+MMU / scsi_a3000 Amix settings)

# 3. The guest auto-configures aen0=$GUEST_IP at boot (see the guide for the
#    one-time in-guest setup that makes that happen). Then from the host:
ping "$GUEST_IP"
AMIX_HOST="$GUEST_IP" python3 amixsh.py 'ifconfig aen0' 'ping www.google.com'
```

## Install the boot-time service (host persistence)

```sh
sudo cp amix-lan-up.sh amix-lan-down.sh /usr/local/sbin/
sudo chmod 755 /usr/local/sbin/amix-lan-up.sh /usr/local/sbin/amix-lan-down.sh
sudo cp amix-lan.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now amix-lan.service
```

Undo: `sudo systemctl disable --now amix-lan.service` then `sudo sh amix-lan-down.sh`.

> The TAP has **no carrier until Amiberry attaches to it**, so the guest is only
> reachable while Amiberry is running — the service just makes the routing/ARP
> plumbing ready so launching Amiberry "just works".

See [the full guide](../../docs/getting-started/networking-on-the-lan.md) for the
in-guest configuration (the `/etc/inet/hosts`, DNS, and `/etc/domain` steps) and
the verification checklist.
