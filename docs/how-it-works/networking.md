---
title: Networking
summary: SVR4 STREAMS TCP/IP over the A2065 (aen0), static IP only, DNS off by default, NFS, and the buggy SLIP / no-PPP caveats.
status: draft
---

# Networking

Amix networks the way a stock **AT&T System V Release 4** workstation does: a **STREAMS-based TCP/IP** stack with both **TLI** and **BSD sockets**, configured with static IPv4 addresses ✅. The native Ethernet card is the Commodore **A2065** (a LANCE/Am7990 board), which appears as the interface **`aen0`** ✅. There is **no DHCP** and **no PPP**; **DNS resolution is disabled out of the box** (the resolver falls back to `/etc/hosts`) and must be switched on by hand ✅/🟡. **NFS** works as both server and client ✅. **SLIP** exists but is buggy enough that you must reboot between dial-up sessions 🟡.

For driver-level mechanics of how a network card hangs off the kernel, see [the STREAMS driver guide](../drivers/writing-a-streams-driver.md) and [the Hydra case study](../drivers/case-studies/hydra.md). For the broader kernel picture see [the kernel architecture page](kernel-architecture.md).

> This page condenses §11 of the research brief. Networking facts there are tagged ✅ where they come from SVR4 itself or repo source, and 🟡 where they come from amigaunix.com / community write-ups. Carry those tags as written.

## The stack: SVR4 STREAMS TCP/IP

- Amix uses the SVR4 **STREAMS** framework for its protocol stack ✅. TCP/IP, the transport providers, and the network drivers are all STREAMS modules pushed onto a stream — this is the same architecture SVR4 documents in its *Streams Programmer's Guide* and *Network Programmer's Guide* (both cited by the Ditto driver paper as the references for writing such drivers) ✅.
- Two programming interfaces are available on top of it: **TLI** (the SVR4-native Transport Layer Interface) and **BSD sockets** ✅.
- A network interface driver is therefore a **STREAMS character driver** — a third kind of driver alongside plain block and character drivers, distinguished by carrying a `streamtab` rather than ordinary `read`/`write` entry points ✅. See [how STREAMS drivers differ](../drivers/writing-a-streams-driver.md).

Because the stack is statically linked into a monolithic kernel with **no loadable modules** ✅, adding or swapping a network card driver means relinking `/unix` (see [Adding a driver](#adding-other-network-cards) below and [the kernel build page](../drivers/kernel-build.md)).

## Interfaces and devices

| Card | Interface | Bus | Driver | Tag |
|---|---|---|---|---|
| **A2065** (Am7990 LANCE Ethernet) | `aen0` | Zorro II | native (`aen/` in the kernel source tree) | ✅ |
| **Hydra AmigaNet** (NE2000 / DP8390) | `hya0` | Zorro II | modern `hydra-amix` STREAMS/DLPI driver | ✅ |
| **Ariadne I** | (Gateway! Vol.2 driver) | Zorro II | community | 🟡 |

The A2065 is the card Commodore shipped and the only Ethernet board Amix supports out of the box ✅. `aen0` is what `ifconfig` and the routing tables refer to.

**Note:** the loopback interface (`lo0`) and the conventional `127.0.0.1` are SVR4 standard; only the physical-interface name `aen0` is Amix-specific here.

## Static IP configuration (no DHCP)

There is **no DHCP client** in Amix — every host gets a **static IPv4 address** ✅. The pieces are the standard SVR4 / BSD-derived files and commands:

```sh
# Bring the A2065 up with a static address and netmask.
ifconfig aen0 192.168.0.10 netmask 255.255.255.0 up

# Verify.
ifconfig aen0
```

Hostname and host/network databases live where SVR4 keeps them:

```text
/etc/hosts        # name → IP, and the resolver's only source until DNS is enabled
/etc/netmasks     # subnet masks per network
/etc/networks     # network names
/etc/netconfig    # STREAMS/TLI transport provider table
```

**Default route — the metric is mandatory.** Amix requires a metric (hop count) argument on `route add default`; omit it and the route is rejected ✅/🟡:

```sh
# Correct: gateway followed by metric 1.
route add default 192.168.0.1 1
```

The trailing `1` is the metric/hopcount, not an option flag. This is the single most common networking gotcha on Amix and is listed in [the quirks checklist](quirks.md).

## DNS is off by default — turning it on

By default the C library resolves names from **`/etc/hosts` only**; **DNS lookups are disabled** ✅. This is deliberate in the shipped configuration — the stock `libsocket.so` does not call a name server. Enabling DNS means swapping in the DNS-capable library on **two** resolution paths and providing a resolver config. This procedure is now **first-hand verified** on a running Amix 2.1 ✅:

```sh
# 1. gethostbyname() path (ping / telnet / ftp clients): swap libsocket -> libsockdns.
cp /usr/lib/libsocket.so /usr/lib/libsocket.so.orig
ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so

# 2. TLI / netdir path: activate the DNS-enabled transport table.
cp /etc/netconfig /etc/netconfig.TCP
cp /etc/netconfig.DNS /etc/netconfig          # appends /usr/lib/resolv.so to tcp/udp/icmp/rawip

# 3. resolver config — nameservers ONLY (see the domain warning below).
cat > /etc/resolv.conf <<'EOF'
nameserver 192.168.0.1
nameserver 192.168.0.2
EOF
```

Notes and caveats:

- `/usr/lib/libsockdns.so` is the **DNS-enabled socket library**; hard-linking `libsocket.so` onto it is what flips `gethostbyname()` from hosts-only to DNS ✅. Use `ln -f` (atomic relink) so already-running daemons keep the old inode safely.
- `/etc/netconfig.DNS` is a ready-made variant of the SVR4 transport table that appends **`/usr/lib/resolv.so`** to each provider; copying it over `/etc/netconfig` enables DNS on the TLI/`netdir_getbyname()` path ✅. Both files ship with the install.
- `in.named` (BIND) is **only** needed if this host is *serving* DNS; a pure client needs just the two swaps above plus `/etc/resolv.conf` ✅.

> 🛑 **Leave the domain UNSET — the `/etc/domain` "general weirdness".** If a default
> domain is set, the resolver **appends it to every lookup, including fully-qualified
> names** — so `www.google.com` is queried as `www.google.com.<yourdomain>`. If your
> local zone has a wildcard, that resolves to the *wrong* address and never falls back
> (the classic symptom is `ping` getting `ICMP Host Unreachable` for a name while the
> literal IP works). The domain is set at `sysinit` from **`/etc/domain`** via
> `domainname \`cat /etc/domain\``. Fix it by emptying the file (`cp /dev/null
> /etc/domain`, or `echo nodomain > /etc/domain`) and `domainname ""` to apply now.
> `options ndots:1` does **not** help — this resolver ignores it. ✅ (Documented as
> "general weirdness" on [amigaunix.com](https://www.amigaunix.com/doku.php/networking)
> and confirmed first-hand.)

For a complete, reproducible LAN setup (static IP at boot, gateway, DNS, internet, reachable inbound — all surviving reboot) under Amiberry, see **[Putting Amix on your real LAN](../getting-started/networking-on-the-lan.md)**.

## NFS (server and client)

Amix includes **NFS as both server and client** ✅, the SVR4-standard RPC/NFS stack. The install/boot kernel is itself NFS/RPC-capable: the on-floppy bootstrap embeds a full **NFS/RPC client string table** (confirmed by string analysis of `amix_21_boot.adf`) ✅, so network booting / network install paths are wired in at the bootstrap level.

Typical usage follows ordinary SVR4 conventions:

```sh
# Server: export a directory (entries in /etc/dfs/dfstab, then):
shareall
share

# Client: mount a remote export.
mount -F nfs server:/export/home /mnt
```

`share`/`shareall`/`dfstab` and `mount -F nfs` are the SVR4 distributed-filesystem (DFS) interfaces; Amix carries them as part of the SVR4 base ✅. For local disk and filesystem details (UFS vs s5) see [filesystems and disks](filesystems-and-disks.md).

## Serial networking: SLIP is buggy, no PPP

- **PPP is not available** on Amix ✅ — there is no PPP stack to dial out with.
- **SLIP exists but is buggy** 🟡. The reported workaround is to **reboot between SLIP sessions**: a connection that has been torn down does not cleanly reset, so a second `dial → connect` in the same uptime tends to fail. Treat SLIP as a one-shot-per-boot facility. This is recorded in [the quirks checklist](quirks.md).

If you need IP over serial in practice, the community guidance is effectively "use Ethernet (A2065 or Hydra) instead" 🟡.

## Adding other network cards

Because the kernel is monolithic with no loadable modules ✅, a non-A2065 card needs a driver compiled into `/unix`. The modern, fully worked example is the **Hydra AmigaNet** driver.

- `hydra-amix` is a **STREAMS / DLPI** network driver for the Hydra card (an **NE2000 / DP8390** design), rev 1.2a, Zorro II, AutoConfig ID **2121/1 (`0x08490001`)** ✅.
- It registers at **`cdevsw` slot 47** with the `hya` tag; you bring it up with `ifconfig hya0 plumb` and then assign an address as above ✅.
- Its entry points (`hydraopen`, `hydrawput`, `hydraintr`, `setup_ne2000`) handle DLPI primitives (`DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ`) and the INT2 RX/TX interrupt; `hydraopen` even includes a **3-way card detect** with an **A2065 fallback emulation** path, and it deliberately mirrors the existing A2065 LANCE driver (`aen/`) ✅.
- It is **cross-compiled** with `m68k-amix-gcc` (GCC 2.7.2.3, SVR4 target) and converted to Amix boot format via `elf2brel`; it is **source-only** because building it needs a licensed Amix tree ✅.

Full detail — the build line, the DLPI flow, and the LANCE-mirroring design — is on [the Hydra case study](../drivers/case-studies/hydra.md). The general procedure for writing this class of driver is on [Writing a STREAMS driver](../drivers/writing-a-streams-driver.md), and the relink/boot-partition steps are on [the kernel build page](../drivers/kernel-build.md).

> 🔴 **Toolchain gap:** there is no public, reproducible build recipe for the `m68k-amix-gcc` cross-compiler — it appears to be a private build requiring Amix SVR4 headers and libraries. Anyone planning to build `hydra-amix` (or any cross-compiled network driver) should expect to solve the toolchain problem first. See [the toolchain page](../drivers/toolchain.md).

## Quick reference

| Task | Command / file | Tag |
|---|---|---|
| Bring A2065 up | `ifconfig aen0 <ip> netmask <mask> up` | ✅ |
| Bring Hydra up | `ifconfig hya0 plumb` then assign address | ✅ |
| Default route (metric required) | `route add default <gw> 1` | ✅/🟡 |
| Static name→IP, resolver fallback | `/etc/hosts` | ✅ |
| Enable DNS (1/2) | `ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so` + `/etc/resolv.conf` (nameservers only) | ✅ |
| Enable DNS (2/2) | `cp /etc/netconfig.DNS /etc/netconfig` (activates `/usr/lib/resolv.so`) | ✅ |
| **Unset domain** (or DNS breaks) | `cp /dev/null /etc/domain; domainname ""` — else it's appended to every lookup | ✅ |
| NFS export / mount | `share` / `shareall`; `mount -F nfs host:/path /mnt` | ✅ |
| SLIP | works once per boot; **reboot between sessions** | 🟡 |
| PPP | not available | ✅ |

## See also

- [Writing a STREAMS driver](../drivers/writing-a-streams-driver.md) — how a network interface attaches to the SVR4 stack.
- [Hydra case study](../drivers/case-studies/hydra.md) — a complete modern STREAMS/DLPI network driver (`hya0`).
- [Kernel architecture](kernel-architecture.md) — monolithic SVR4, STREAMS, no loadable modules.
- [Filesystems and disks](filesystems-and-disks.md) — UFS/s5, needed for NFS server exports.
- [Quirks](quirks.md) — DNS-off-by-default, the `route` metric, and the SLIP reboot bug in one list.
- [Hardware](hardware.md) — the A2065 and other supported expansion.
- [amigaunix.com networking notes](https://www.amigaunix.com/doku.php/networking) — end-user network setup (the community source for the DNS/resolver procedure).

## Sources

- Research brief §11 "Networking, X11, userland" (STREAMS TCP/IP; `aen0`/A2065; static IP, no DHCP; DNS off by default + `libsockdns.so` swap, `in.named`, `/etc/resolv.conf`; `route add default <gw> 1`; NFS server+client; SLIP buggy; no PPP).
- Research brief §2 "Hardware & requirements" (A2065 native; Hydra via `hydra-amix`; Ariadne I via Gateway 🟡).
- Research brief §6 (`isoriano1968/hydra-amix` — STREAMS/DLPI, NE2000/DP8390, `cdevsw` slot 47, `hya0`, AutoConfig `0x08490001`, A2065 fallback, `m68k-amix-gcc`/`elf2brel`).
- Research brief §4 "Kernel architecture" (monolithic SVR4; STREAMS, TLI + BSD sockets; no loadable modules).
- Research brief §3 / §10 (`amix_21_boot.adf` string analysis — embedded NFS/RPC client string table), via `tools/inspect-adf.sh`.
- Research brief §12 "Quirks checklist" (DNS off by default; SLIP reboot bug).
- Research brief §13 (open gap 🔴: no public `m68k-amix-gcc` build recipe).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (cites the SVR4 *Streams Programmer's Guide* and *Network Programmer's Guide*).
- [github.com/isoriano1968/hydra-amix](https://github.com/isoriano1968/hydra-amix)
- [amigaunix.com — networking](https://www.amigaunix.com/doku.php/networking) (community-reported resolver/DNS procedure).
