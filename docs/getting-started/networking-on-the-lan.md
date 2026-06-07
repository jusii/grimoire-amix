---
title: Putting Amix on your real LAN (Amiberry)
summary: A verified, end-to-end recipe to make an Amiberry-emulated Amix a real host on your physical LAN — static IP, gateway, DNS and internet, surviving reboot — using the A2065 on a routed TAP plus proxy-ARP, and the SVR4 files that make it persistent.
status: draft
---

# Putting Amix on your real LAN (Amiberry)

This is a complete, **first-hand-verified** recipe (2026-06: Amiberry **8.1.6**, Amix **2.1 / SVR4.0**, Linux host) for turning an emulated Amix into a **real, reachable host on your physical LAN** — with a static IP, a working default gateway, **DNS name resolution and internet access**, reachable inbound (telnet/ftp/rlogin), and **coming up automatically at boot**. ✅

The result, with the example values used throughout:

| | |
|---|---|
| Amix IP | `192.168.2.38/24` (`aen0`) |
| Gateway | `192.168.2.1` |
| DNS | `192.168.2.14`, `192.168.2.23` |
| From the LAN | `ping 192.168.2.38`, `telnet 192.168.2.38` reach Amix |
| From Amix | `ping www.google.com`, internet, NFS, etc. |

It builds on the conceptual [networking page](../how-it-works/networking.md) (the SVR4 STREAMS stack, `aen0`, static-IP/no-DHCP, DNS-off-by-default) and [the Amiberry page](emulation-amiberry.md): **Amiberry 8.x fully runs and installs Amix** — its A3000 on-board SCSI emulates the disk (ID 6) and tape (ID 4) — and adds real A2065 networking. ✅

> Substitute your own IP/gateway/DNS throughout. The host-side helpers in
> [`tools/host-net/`](https://github.com/Jusii/grimoire-amix/tree/master/tools/host-net/) default to exactly these values and
> autodetect your LAN interface.

## Why this works on Amiberry (and the design choice)

- **Amiberry ≥ 8.0** added a **TAP backend** for the emulated **A2065** card: set
  `a2065=tap0` and Amiberry attaches the card to a Linux TAP via `TUNSETIFF`. This
  uses `/dev/net/tun` (no `cap_net_admin`, no libpcap), which is why it works even
  in locked-down environments where pcap capture is blocked. ✅
- We then run the **host as a proxy-ARP router** between that TAP and the LAN NIC,
  routing the guest's `/32` at the TAP. This makes Amix a real LAN host **without
  ever touching the host's own IP, default route, or NetworkManager** — so it can't
  knock the host off the network. ✅
- A **true L2 bridge** (`br0` enslaving the NIC + `tap0`, host IP moved onto `br0`)
  also works and is more "native", but it momentarily blips the host's connectivity
  and risks the uplink for no functional gain here. The Amiberry/guest config is
  identical either way (`a2065=tap0`); only the host plumbing differs. 🟡

## Step 1 — Host side (proxy-ARP routed TAP)

Run the helper (idempotent; defaults to `GUEST_IP=192.168.2.38`, autodetects the NIC):

```sh
sudo sh tools/host-net/amix-lan-up.sh
```

That is exactly equivalent to (LAN NIC shown as `$ETH`):

```sh
# user-owned TAP Amiberry attaches to (no caps needed)
sudo ip tuntap add dev tap0 mode tap user "$USER"
sudo ip link set tap0 up
sudo ip addr replace 192.168.2.2/32 dev tap0          # host-side anchor (host<->guest)

# route the guest's /32 at the tap, with a same-subnet source
sudo ip route replace 192.168.2.38/32 dev tap0 src 192.168.2.2

# make the host a proxy-ARP router
sudo sysctl -wq net.ipv4.ip_forward=1
sudo sysctl -wq net.ipv4.conf.$ETH.proxy_arp=1
sudo sysctl -wq net.ipv4.conf.tap0.proxy_arp=1

# allow forwarding past Docker's FORWARD=DROP policy (DOCKER-USER if Docker present)
sudo iptables -I DOCKER-USER 1 -i tap0 -o $ETH -j ACCEPT
sudo iptables -I DOCKER-USER 1 -i $ETH -o tap0 -j ACCEPT
```

> **Gotcha — Docker.** If Docker is installed it sets the iptables `FORWARD` policy
> to `DROP`; without the two ACCEPT rules above, the host will answer ARP for the
> guest but silently drop its forwarded packets, and `ping <gateway>` from Amix
> returns *"no answer"*. This is the single most confusing host-side failure. ✅
>
> `tap0` shows state **DOWN / NO-CARRIER until Amiberry attaches to it** — that is
> normal; the carrier comes up when the emulator opens the device. ✅

## Step 2 — Amiberry config

In your machine's `.uae` (a complete working example is committed at
[`tools/amix-amiberry.uae`](https://github.com/Jusii/grimoire-amix/blob/master/tools/amix-amiberry.uae)), the networking lines are:

```ini
a2065=tap0
a2065_rom_options=mac=00:80:10:00:00:38
bsdsocket_emu=false
```

plus the standard, **mandatory** Amix machine settings (see
[Amiberry status](emulation-amiberry.md) and [hardware](../how-it-works/hardware.md)):

```ini
cpu_model=68030
fpu_model=68882
mmu_model=68030          ; MMU ON  — required or Amix won't boot
cpu_compatible=false     ; "More compatible" OFF
cachesize=0              ; JIT OFF
chipset_compatible=A3000
scsi_a3000=true
kickstart_rom_file=Kickstart v2.04 r37.175 (1991)(Commodore)(A3000).rom
hardfile2=rw,DH0:/path/to/Amix.hdf,32,1,2,512,0,,scsi6_a3000
```

> **Gotcha — the MAC must be a Commodore OUI (`00:80:10:xx:xx:xx`).** The Amix
> `aen0`/LANCE path expects it; an arbitrary MAC misbehaves. The host-side TAP keeps
> its own random MAC (correct — the bridge/host learns the Amiga MAC from frames). ✅
>
> Launching headless is possible (`Xvfb` + a controlling TTY + `xdotool`); see
> [Headless operation](#headless-operation-optional). Otherwise just launch Amiberry
> normally and use its window.

## Step 3 — Inside Amix (one-time, persistent)

Three files make the network come up automatically at every boot. Edit them as
root (over the console, or once networking is up, over `telnet`/`ftp`).

### 3a. `/etc/inet/hosts` — the key to boot-time bring-up

At boot, `/etc/init.d/inetinit` sources `/etc/inet/network-config`, which runs:

```sh
/usr/amiga/bin/aen -S && /usr/sbin/slink addaen /dev/aen0 aen0 \
    && /usr/sbin/ifconfig aen0 `uname -n` up -trailers
```

So `aen0`'s address is **whatever `` `uname -n` `` (here: `amix`) resolves to in
`/etc/inet/hosts`**. If that file is empty, you get `ifconfig: amix: bad value` at
boot and no interface. Populate it (`/etc/hosts` is a symlink to this file):

```text
127.0.0.1     localhost loghost
192.168.2.38  amix amix.localdomain
192.168.2.1   gateway
192.168.2.14  ns1
192.168.2.23  ns2
```

No explicit netmask is needed: `192.168.2.x` takes the class-C default (`ffffff00`
= `/24`) automatically. ✅

### 3b. Default route — in `/etc/inet/rc.inet`

`rc.inet` (run right after `network-config`) is where the persistent default route
lives. Add (note the **mandatory metric** — `1`):

```sh
/usr/sbin/route add default 192.168.2.1 1
```

### 3c. DNS — library swap + transport table + resolv.conf

Amix resolves from `/etc/hosts` only until you enable DNS. Two libraries are
involved — swap **both**:

```sh
# 1. gethostbyname() path (ping, telnet, ftp clients): swap libsocket -> libsockdns
cp /usr/lib/libsocket.so /usr/lib/libsocket.so.orig
ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so

# 2. TLI/netdir path: activate the DNS-enabled transport table
cp /etc/netconfig /etc/netconfig.TCP
cp /etc/netconfig.DNS /etc/netconfig          # adds /usr/lib/resolv.so to tcp/udp/...

# 3. resolver config — nameservers ONLY, no `domain`/`search` (see the gotcha)
cat > /etc/resolv.conf <<'EOF'
nameserver 192.168.2.14
nameserver 192.168.2.23
EOF
```

> **⚠️ Also fix the boot-time `ifconfig`s, or every boot gets ~3 min slower.** As
> soon as DNS is enabled (the `libsockdns` link above), the two `ifconfig` calls
> that bring up `lo0` and `aen0` at boot **each hang ~90 s** (~180 s total), because
> they take **hostnames**, and `gethostbyname()` now tries **DNS first** — but they
> run *before* the default route is installed (`route add default …` is later, in
> [`/etc/inet/rc.inet`](#3b-default-route-in-etcinetrcinet)), so with no route to the
> nameservers each lookup burns the full resolver retransmit schedule before falling
> back to `/etc/hosts`. Stock (DNS-off) Amix resolves these names from `/etc/hosts`
> instantly, which is exactly why the trap appears **only after** you enable DNS, and
> why the [Step 3a `/etc/inet/hosts`](#3a-etcinethosts-the-key-to-boot-time-bring-up)
> recipe is *not* enough on its own once DNS is on. The fix is to give both boot-time
> `ifconfig`s a **literal IP** so no resolver call happens before the network is up
> (boot **210 s → 29 s**; runtime DNS for clients/mail is untouched). ✅

```sh
# /etc/rc2.d/S69inet        -- the loopback bring-up
-   /usr/sbin/ifconfig lo0 localhost up
+   /usr/sbin/ifconfig lo0 127.0.0.1 up

# /etc/inet/network-config  -- the aen0 bring-up (replaces the `uname -n` from Step 3a)
-   /usr/sbin/ifconfig aen0 `uname -n` up -trailers
+   /usr/sbin/ifconfig aen0 192.168.2.38 up -trailers   # this host's static IP, literal
```

`lo0` is always `127.0.0.1`; `aen0` uses this host's own static address (the same
`.38` already in `/etc/inet/hosts`). Configuring your own interface should never
depend on a name service, so this is the correct design regardless. ✅

> **Editing gotchas for `/etc/rc2.d/S69inet` — read before you `sed`:**
>
> - **`S69inet` is a hardlink.** The same inode is also `/etc/init.d/inetinit`. Edit
>   it **in place** so both names stay in sync — `sed` to a temp then `cat >` the
>   original, or use `ed`. Do **not** `mv`/unlink and recreate, or you break the link
>   and `inetinit` keeps the old (slow) behaviour:
>   ```sh
>   sed 's/ifconfig lo0 localhost up/ifconfig lo0 127.0.0.1 up/' \
>       /etc/rc2.d/S69inet > /tmp/S69inet.new && cat /tmp/S69inet.new > /etc/rc2.d/S69inet
>   ```
> - **Never leave a backup named `S*` inside `/etc/rc2.d/`.** `rc2` runs
>   `for f in /etc/rc2.d/S*` at boot, so a copy like `S69inet.bak` or `S69inet.orig`
>   **gets executed too** (verified against the live `/etc/rc2` glob). Park backups
>   **outside** that directory:
>   ```sh
>   cp /etc/rc2.d/S69inet /root/S69inet.orig     # NOT /etc/rc2.d/S69inet.orig
>   ```
> - This no-route boot hang is **independent of** the `/etc/domain` "general
>   weirdness" below — a box with an already-empty `/etc/domain` still hangs the full
>   180 s. They are two different problems; fix both. ✅

> **Gotcha — leave the domain UNSET (`/etc/domain`).** This is the documented Amix
> "[general weirdness](https://www.amigaunix.com/doku.php/networking)": if a domain
> is set, the resolver **appends it to every lookup — even fully-qualified names** —
> so `www.google.com` is queried as `www.google.com.<yourdomain>`. With a wildcard
> in your local zone this resolves to the *wrong* address and the lookup never falls
> back. The domain is set at `sysinit` from **`/etc/domain`** (via
> `domainname \`cat /etc/domain\``). Empty it:
> ```sh
> cp /etc/domain /etc/domain.orig
> cp /dev/null /etc/domain          # or: echo nodomain > /etc/domain
> domainname ""                     # apply now, without a reboot
> ```
> `options ndots:1` in `resolv.conf` does **not** help — this old resolver ignores
> it. Cosmetic side effect: the console banner becomes `Node: amix` instead of
> `amix.<domain>` (the FQDN still resolves via `/etc/inet/hosts`). ✅

## Verification checklist

```sh
# From the host:
ping 192.168.2.38                       # -> replies
python3 tools/host-net/amixsh.py 'ifconfig aen0' 'netstat -rn' 'domainname' \
        'ping 192.168.2.1' 'ping www.google.com'
# Expect: aen0 inet 192.168.2.38 netmask ffffff00 ; default -> 192.168.2.1 via aen0 ;
#         domainname empty ; "192.168.2.1 is alive" ; "www.google.com is alive"

# From any other LAN machine:
telnet 192.168.2.38                     # -> Amix login: prompt
```

SVR4 `ping host` is single-shot ("`host is alive`" / "`no answer`"), not a
continuous stream — handy for scripting. ✅

## Persistence (survives reboot)

- **Guest:** everything in Step 3 is on-disk (`/etc/inet/hosts`, `rc.inet`,
  `/etc/resolv.conf`, `/etc/netconfig`, the `libsocket.so` link, empty `/etc/domain`)
  and is re-applied by the normal SVR4 boot. **Reboot-verified**: after
  `shutdown -i6`, `aen0` comes up at `.38`, the route is set, `domainname` is empty,
  and `ping www.google.com` works — with zero manual steps. ✅
- **Host:** the `ip`/`sysctl`/`iptables` state is not persistent. Install the
  service so it's recreated at boot:
  ```sh
  sudo install -m 755 tools/host-net/amix-lan-up.sh tools/host-net/amix-lan-down.sh /usr/local/sbin/
  sudo install -m 644 tools/host-net/amix-lan.service /etc/systemd/system/
  sudo systemctl daemon-reload && sudo systemctl enable --now amix-lan.service
  ```

## Headless operation (optional)

Useful for automation / agents driving Amix without a visible window:

- Run Amiberry under `Xvfb` with a **controlling TTY** and software rendering:
  `DISPLAY=:77 SDL_RENDER_DRIVER=software script -qfc "amiberry -f amix_net.uae" /dev/null`
  (start `Xvfb :77 -screen 0 1280x1024x24 -nolisten tcp` first; drive the console
  with `xdotool windowfocus <id>` + `xdotool type/key`, screenshot with
  `import -window root`). ✅
- Once `aen0` is up, skip the console entirely and use the LAN: scripted shell via
  [`tools/host-net/amixsh.py`](https://github.com/Jusii/grimoire-amix/blob/master/tools/host-net/amixsh.py) (telnet) and file
  uploads via [`amixput.py`](https://github.com/Jusii/grimoire-amix/blob/master/tools/host-net/amixput.py) (FTP). ✅

## See also

- [Networking (concepts)](../how-it-works/networking.md) — the SVR4 STREAMS stack, `aen0`, DNS-off-by-default, the `route` metric.
- [Amix on Amiberry (status)](emulation-amiberry.md) — what runs vs. what needs WinUAE/FS-UAE.
- [`tools/host-net/`](https://github.com/Jusii/grimoire-amix/tree/master/tools/host-net/) — the host scripts, systemd unit, and telnet/ftp helpers used here.
- [Quirks](../how-it-works/quirks.md) — DNS-off, the `route` metric, the domain-append trap, and the **DNS-enable slow-boot** (literal-IP `ifconfig` fix).
- [amigaunix.com — networking](https://www.amigaunix.com/doku.php/networking) — the community source that documents the `/etc/domain` "general weirdness".

## Sources

- First-hand reproduction, 2026-06-02: Amiberry 8.1.6 (`a2065=tap0`, A2065 attached to a host TAP, MAC `00:80:10:00:00:38`), Amix 2.1 on `Amix.hdf` at `scsi6_a3000`; host = Linux on `192.168.2.0/24` with Docker. Verified host↔guest, gateway/DNS/internet, inbound telnet/ftp, and **reboot persistence** (aen0/route/DNS auto-up after `shutdown -i6`).
- Amiberry 8.0.0 release + PRs [#1784](https://github.com/BlitterStudio/amiberry/pull/1784) (TAP backend, `a2065=tap0`/`a2065=br0`), [#1777](https://github.com/BlitterStudio/amiberry/pull/1777) (PCAP bridged rewrite), [#1774](https://github.com/BlitterStudio/amiberry/pull/1774) (config parse fix). Source: `src/cfgfile.cpp`, `src/ethernet.cpp`, `src/osdep/amiberry_uaenet.cpp`, `src/a2065.cpp`.
- Amix boot path: `/etc/inittab` (`S2::sysinit:/etc/sysinit`), `/etc/sysinit` (`domainname \`cat /etc/domain\``), `/etc/init.d/inetinit`, `/etc/inet/network-config` (`ifconfig aen0 \`uname -n\` up -trailers`), `/etc/inet/rc.inet` — read directly off the running system.
- DNS enable: `/etc/netconfig.DNS` (adds `/usr/lib/resolv.so`), `/usr/lib/libsockdns.so` — present on the install; the `domain`-append behaviour matches [amigaunix.com networking notes](https://www.amigaunix.com/doku.php/networking) and was confirmed via a `gethostbyname()` probe.
- DNS-enable slow-boot + literal-IP fix: The A4091-on-Amix project — networking investigation, 2026-06-07 (reproduced locally ✅) — instrumented `/etc/rc2` per-script timing on Amix 2.1c under Amiberry, isolating the ~180 s hang to the two boot-time `gethostbyname()` calls; boot **210 s → 29 s** after the fix. `/etc/rc2.d/S69inet` (hardlinked to `/etc/init.d/inetinit`), `/etc/inet/network-config` (`ifconfig aen0 \`uname -n\`` → literal IP), `/etc/inet/rc.inet` (default route runs *after* `network-config`) — read directly off the running system; `for f in /etc/rc2.d/S*` glob confirms backup S\* files execute at boot.
- Research brief §11 (networking) and the conceptual [networking page](../how-it-works/networking.md).
