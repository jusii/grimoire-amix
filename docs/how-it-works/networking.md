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
| **Z3660** (accelerator's onboard Zynq GEM) | `zen0` | Zorro III *(eth window at `0x10000000`, inside the identity-mapped low 1 GB)* | modern `z3660eth` STREAMS/DLPI driver — **works on real hardware (2026-06)** | ✅ |
| **Ariadne I** | (Gateway! Vol.2 driver) | Zorro II | community | 🟡 |

The A2065 is the card Commodore shipped and the only Ethernet board Amix supports out of the box ✅. `aen0` is what `ifconfig` and the routing tables refer to. Both modern STREAMS/DLPI add-on drivers (Hydra → `hya0`, Z3660 → `zen0`) are real-hardware-verified — see [Adding other network cards](#adding-other-network-cards).

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

> ⚠️ **Also fix the boot-time `ifconfig`s, or enabling DNS adds ~3 minutes to every
> boot.** After enabling DNS via the procedure above, the box stalls **~3 minutes** at
> `The system is coming up.  Please wait.` on *every* boot. Stock Amix (DNS off) does not.
> Reproduced first-hand on Amix 2.1c under Amiberry, 2026-06-07 ✅.
>
> **Root cause** ✅: `/etc/rc2.d/S69inet` brings networking up with two `ifconfig` calls
> that take **hostnames**, each forcing a `gethostbyname()`:
> - `ifconfig lo0 localhost up` — in `S69inet` itself
> - `ifconfig aen0 \`uname -n\` up -trailers` — in `/etc/inet/network-config`
>
> With DNS enabled, `gethostbyname()` tries **DNS first**, but these run *before* the
> default route is installed (`route add default …` happens later, in
> `/etc/inet/rc.inet`). With no route to the nameservers, each lookup burns the full
> resolver retransmit schedule — **~90 s each, ~180 s total** — before falling back to
> `/etc/hosts`. With DNS *off* (stock) the same names resolve instantly from `/etc/hosts`,
> which is why the trap appears **only after** you enable DNS.
>
> This is **independent of the `/etc/domain` weirdness above** ✅ — a box with an
> already-empty `/etc/domain` still hangs the full 180 s. They are two different problems;
> fix both.

**The fix — give both boot-time `ifconfig`s a literal IP** (boot **210 s → 29 s**; runtime DNS is unaffected) ✅. Configuring your own interface should never depend on a name service:

```diff
# /etc/rc2.d/S69inet
-   /usr/sbin/ifconfig lo0 localhost up
+   /usr/sbin/ifconfig lo0 127.0.0.1 up

# /etc/inet/network-config
-   /usr/sbin/ifconfig aen0 `uname -n` up -trailers
+   /usr/sbin/ifconfig aen0 <this-host-static-ip> up -trailers
```

`lo0` is always `127.0.0.1`; `aen0` takes this host's own static address (the same one already in `/etc/hosts` — e.g. `192.168.2.38` in [the LAN setup](../getting-started/networking-on-the-lan.md)). Only the boot path stops calling the resolver; DNS for clients, mail, etc. is untouched ✅.

> 🔗 **Edit `S69inet` in place** — it is a hardlink (the same inode is also
> `/etc/init.d/inetinit`), so unlink/recreate would desync the two ✅. And never leave
> backup copies named `S*` inside `/etc/rc2.d/` — `rc2`'s `for f in /etc/rc2.d/S*` glob
> will run them at boot; park backups elsewhere ✅.

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

## STREAMS message-block exhaustion — the box wedges with memory to spare 🟡

Under **sustained bench sessions** a box can **wedge while `freemem` is still healthy** 🟡. The console
signature is `WARNING: ldterm: (ldtermsrv) out of blocks` and `console_get_buffer: out of blocks`; the
kernel is still alive (it echoes those warnings on each keypress) but **TCP dies first and console echo
second**. Crucially `freemem` was still ~2100 pages (≈4.3 MB) when it happened, so this is **not** page
exhaustion — SVR4 STREAMS `mblk`s come from their **own preallocated arena**, which the entire network
stack lives on, and that arena can starve while the page pool is fine ✅ (mechanism) / 🟡 (the leak).

It tracked the number of **telnet/FTP sessions opened**, not the filesystem workload — pointing at a
**per-connection / per-packet `mblk` leak on the network path** (the specific driver is not yet
isolated, so this is carried **🟡**). Bench workarounds: power-cycle after heavy session churn, and run
long scripts as a **single** session with output redirected to a file *on the box* rather than streamed
over many short-lived connections.

**Distinguishing it from a heap/page leak is easy once you know the shape:** sample `freemem` (via
[live `adb` on `/dev/kmem`](../drivers/kernel-reverse-engineering.md#live-probing-a-running-kernel-with-adb-on-devkmem-the-load-bias-trap)) —
if it barely moves while the box dies, the culprit is **STREAMS `mblk`s**, not the heap. (This is an
**open** issue on the [`z3660eth`](../drivers/z3660-ethernet-driver.md) / TCP network path; cdfs was
ruled out with these numbers.)


A 2026-07-27 soak of 69 530 cdfs mount/read/unmount cycles measured `FAIL=0` in every STREAMS class
with `use` at baseline, so cdfs is not a source of this ✅; and a *refused* (rather than timed-out)
connection is the [`inetd` throttle](#the-inetd-anti-looping-throttle--one-service-refuses-connections-while-the-box-is-healthy),
not this.

## The `inetd` anti-looping throttle — one service refuses connections while the box is healthy ✅

**If telnet answers `Connection refused` while FTP still answers, ICMP is alive, and the console shows
an undisturbed `login:`, the box is fine — SVR4 `inetd` has disabled that one service because
something opened 40 connections to it inside 60 seconds** ✅. It re-enables itself within ten minutes
with no intervention, and it says so only into a log nobody is reading (below). This is the most
misleading failure shape on a bench Amix box: it was chased for two days as a filesystem/STREAMS wedge
before being reproduced in four minutes from bare TCP connect/close with the filesystem unmounted ✅.

### The mechanism and its constants ✅

`inetd`'s accept loop counts invocations **per service entry** and, on the 40th inside the window,
logs a message, closes and deregisters the listening socket, and arms a re-enable alarm. All three
constants are **compile-time immediates** in the shipped `/usr/sbin/inetd` (Amix 2.1c; 38 228 bytes,
md5 `ddfbd40aaaa02a1935a5ef6a37879337`, not stripped), read out of its disassembly ✅:

| Constant | Value | Governs |
|---|---|---|
| `TOOMANY` | **40** invocations | the trip threshold, counted per service |
| `CNT_INTVL` | **60 s** | the counting window |
| `RETRYTIME` | **600 s** | the `alarm()` that re-enables the service |

These match the classic BSD `inetd` values 🟡 — but this build **encodes them as immediates**, which
is what makes the next section true. The message is
`<service>/<proto> server failing (looping), service terminated` at **`daemon.err`**, tagged
`inetd[<pid>]` (`openlog("inetd", LOG_NOWAIT|LOG_PID, LOG_DAEMON)`) ✅.

Three details change how you reason about it ✅:

- **The window is anchored, not sliding.** `se_time` is stamped when the counter is at 1 and the
  elapsed check runs only once the counter reaches 40, so the real rule is: *the 40th connection of a
  window trips iff it lands within 60 s of the 1st.* A trailing-60 s counter held under 40 is
  therefore a sound and conservative guard.
- **The 600 s re-enable timer is global, not per service.** `retry()` re-`setup()`s *every* service
  whose listening fd is `-1`, so a second service that trips while the timer is already running does
  not get its own 600 s. Recovery is "**up to** 600 s"; a recovery much shorter than ten minutes is
  not evidence against this mechanism.
- **The refusal you observe lands later than the 40th connect**, because the kernel's listen backlog
  keeps completing handshakes while `inetd` works through them. Measured first-refusal indexes across
  four trips: **40, 61, 68, 70** ✅. **40 is the floor and the only safe number to design against** —
  never calibrate a guard against an observed refusal index.

### There is no knob ✅

**This build exposes no per-service rate cap, by any syntax or flag** ✅ — established three
independent ways:

- **The `inetd.conf` wait field is a boolean.** `getconfigent()` parses the 4th field with a single
  full-token `strcmp("wait", …)` and stores 0/1. There is no `se_max` member and no suffix parsing,
  so the 4.4BSD/Linux **`nowait.<max>` syntax is simply not implemented** ✅.
- **Live confirmation.** `telnet stream tcp nowait.100 root /usr/sbin/in.telnetd in.telnetd` plus a
  `SIGHUP` was re-read **without complaint**, telnet kept working — and the service still tripped, at
  connect #68. The `.100` is **silently ignored**: a config that looks like it worked and did
  nothing ✅.
- **No command-line flag either.** Argument parsing is hand-rolled and accepts exactly `-d` (debug),
  `-s` (standalone, i.e. outside the SAF), and `-t` (log every connection); anything else prints
  `inetd: Unknown flag -%c ignored.` There is no `-R rate` ✅.

So the only ways to move the threshold are to patch three immediates in a vendor binary, or not to
trip it. **Don't trip it** — see the operational rule below.

### It is per service — which makes the diagnosis one command ✅

The counter lives in the per-service `servtab` entry, so every `nowait` service in
`/etc/inet/inetd.conf` has its own independent counter (on the stock image: `ftp`, `telnet`, `shell`,
`login`, `exec`, `uucp`, `nntp`, `finger`). Measured in both directions on the same box ✅:

- tripping **ftp** (70 rapid connects to :21) → **:21 refused, :23 still open**
- tripping **telnet** (68 rapid connects to :23) → **:23 refused, :21 still open**

**Port 21 answering while port 23 refuses ⇒ the throttle.** Nothing needs fixing; the service returns
by itself. It also means you can still pull evidence off the box over FTP while telnet is throttled.

Distinguish it from the two failures it imitates ✅:

| What you see | What it is |
|---|---|
| One port **refuses** (`ECONNREFUSED`), another answers, ICMP alive, console healthy | this throttle — wait up to 10 min |
| Ports **time out**, console prints `ldterm: (ldtermsrv) out of blocks` | STREAMS `mblk` starvation (previous section) 🟡 |
| Nothing answers and the console is dead | a genuine kernel wedge |

### Why it is silent: `syslogd` ships deliberately disabled ✅

The box *does* report the trip — into a void. Everything the logging system needs is present and
correct on the stock image: `/usr/sbin/syslogd` (22 728 bytes, May 1992), a valid `/etc/syslog.conf`,
the eight `/var/log/*` targets (all present, all zero-length, never written), and `/dev/log` +
`/dev/conslog`. What is missing is the daemon ever starting — **`/etc/init.d/syslogd` line 8 is a
vendor-hardcoded `exit`** ✅:

```sh
#
#TO USE SYSLOGD, COMMENT OR REMOVE THE exit ON THE NEXT LINE:
exit
```

`sh -x /etc/init.d/syslogd start` outputs exactly `+ exit`. Note also that this SVR4 logs to
**`/var/log/*`, not `/var/adm/messages`** ✅ — looking for the latter finds nothing and misleads you
into "this image has no syslog".

Enabling it is **one commented-out line**, with **no `/etc/syslog.conf` change**: the stock
`*.notice;kern.none  /var/log/notice` line already selects `daemon.err` ✅.

> 🔗 **Edit with `cp` in place, never `mv`.** `/etc/init.d/syslogd` and `/etc/rc2.d/S70syslogd` are
> the **same inode** (3 hard links, inode 10261 on the stock image). `mv` replaces the file and
> silently breaks the `rc2.d` hook, so the fix works once and never again after a reboot ✅. This is
> the same hazard as the `S69inet` / `inetinit` hardlink noted above.

```sh
# on the box, as root
cp /etc/init.d/syslogd /etc/init.d/syslogd.orig
sed '8s/^exit$/#exit/' /etc/init.d/syslogd > /tmp/sl.new
cp /tmp/sl.new /etc/init.d/syslogd        # cp, NOT mv -- preserves the inode
/etc/init.d/syslogd start                 # or reboot; S70syslogd now runs it
```

Verified end to end — both real trips were then recorded ✅:

```text
Mar 23 09:51:02 uaeamix inetd[156]: ftp/tcp server failing (looping), service terminated
Mar 23 10:02:59 uaeamix inetd[156]: telnet/tcp server failing (looping), service terminated
```

**Measured cost**, over 23 minutes of deliberate abuse (2 trips, ~170 telnet logins, 120 batched
commands): one daemon, and **293 bytes total across the whole of `/var/log`** ✅ — roughly 80 bytes
per event, into the eight pre-existing files, with no new files or directories. The 20-minute `mark`
heartbeat is routed to `/dev/console` **only** by the stock config and never to a file, so its disk
cost is zero (`syslogd -m 0` disables it outright) ✅. Nothing else broke across the session. To also
put it on the console, add one line — `daemon.err<TAB>/dev/console`. Reverse it by restoring the
`exit`.

### The operational rule for anything that drives an Amix box ✅

The throttle only ever fires on **automation**. Any harness that opens a fresh telnet (or FTP)
session per command reaches 40 in a minute trivially — a `for f in *; do <one login>; done` loop
self-destructs at the 40th file and then looks dead for ten minutes. Measured: **~30 invocations/min
never tripped across 200 invocations; ~575/min tripped within seconds** ✅.

- **Hold one session open for a batch** of commands instead of one login per command.
- Or keep invocations **under ~30 per 60 s, per service** — the same guard is needed on port 21,
  because a per-file FTP loop trips identically at 40 files.
- Best for bulk work: **run an on-box script and poll for progress at a low rate.** One soak sustained
  ~330 filesystem cycles/min at **0.5 telnet logins/min** for three hours with no trips ✅.

## Serial networking: SLIP is buggy, no PPP

- **PPP is not available** on Amix ✅ — there is no PPP stack to dial out with.
- **SLIP exists but is buggy** 🟡. The reported workaround is to **reboot between SLIP sessions**: a connection that has been torn down does not cleanly reset, so a second `dial → connect` in the same uptime tends to fail. Treat SLIP as a one-shot-per-boot facility. This is recorded in [the quirks checklist](quirks.md).

If you need IP over serial in practice, the community guidance is effectively "use Ethernet (A2065 or Hydra) instead" 🟡.

## Adding other network cards

Because the kernel is monolithic with no loadable modules ✅, a non-A2065 card needs a driver compiled into `/unix`. The modern, fully worked example is the **Hydra AmigaNet** driver — and as of **2026-06 it works on real hardware**: ARP resolves and ICMP `ping` reaches both the local gateway and external IPs, which the repo calls *"believed to be the first working AMIX network driver for the Hydra card"* 🟡 (first-party). See [the Hydra case study](../drivers/case-studies/hydra.md) for the bring-up story.

- `hydra-amix` is a **STREAMS / DLPI** network driver for the Hydra card (an **NE2000 / DP8390** design), rev 1.2a, Zorro II, AutoConfig ID **2121/1 (`0x08490001`)** ✅.
- It registers at **`cdevsw` slot 47** with the `hya` tag. **Amix is SVR4.0 — there is no `ifconfig … plumb`**; you link the interface in with `slink addaen /dev/hya0 hya0`, then `ifconfig hya0 <ip> netmask <m> up -trailers` ✅.
- Its entry points (`hydraopen`, `hydrawput`, `hydraintr`, `setup_ne2000`) handle DLPI primitives (`DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ`) and the INT2 RX/TX interrupt; `hydraopen` runs a **three-method card detect** (`autocon()`/bootinfo with address validation, then direct Zorro II I/O-slot and memory probes — the bootinfo table can be corrupt on 2.1p2), and it deliberately mirrors the existing A2065 LANCE driver (`aen/`) ✅.
- It is built **natively on the Amix box** (`make` in the driver dir, `make force` to relink the kernel) with **GCC 2.7.2.3** packaged on [amigaunix.com](https://amigaunix.com) — no cross-compiler; it is **source-only** because building needs a licensed Amix tree ✅.

Full detail — the build line, the DLPI flow, and the LANCE-mirroring design — is on [the Hydra case study](../drivers/case-studies/hydra.md). The general procedure for writing this class of driver is on [Writing a STREAMS driver](../drivers/writing-a-streams-driver.md), and the relink/boot-partition steps are on [the kernel build page](../drivers/kernel-build.md).

A second real-hardware-verified example is the **`z3660eth`** driver for the **Z3660 accelerator's onboard ethernet** (interface `zen0`) — the network analogue of the [A4091 SCSI work](../drivers/a4091-53c710-driver.md), giving Amix full bidirectional TCP/IP on a physical A4000 + Z3660 (2026-06) ✅. It is a contrasting design to hydra: instead of programming a NIC chip directly it speaks the Z3660 firmware's **frame mailbox** over MMIO, registers at **`cdevsw` slot 51** (tag `zen`; 48 until 2026-07-30), and **services RX from a polled `timeout()` callout — no `int2_tbl`/`init_tbl` edit**. The one real-hardware blocker was an **INT6 interrupt storm** (the firmware raised level-6 on every received frame, but Amix has no eth INT6 handler, so ARP broadcasts hard-locked the box); the fix was to disable the firmware interrupt and keep the polled drain. Bring-up is the same `slink` plumbing as hydra (`slink addaen /dev/zen0 zen0`, then `ifconfig zen0 … up -trailers`). See [the Z3660 ethernet driver case study](../drivers/z3660-ethernet-driver.md) for the mailbox protocol, the storm, and the build/deploy story.

> **Build note:** `hydra-amix` is built **natively on the Amix box** with GCC 2.7.2.3 (a pkg on amigaunix.com). As of 2026-06 a Linux-hosted **cross-toolchain** also exists — [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix) (`m68k-cbm-sysv4-gcc`) — so you can build driver objects on a modern host too ✅. Either way you need a licensed Amix install (its headers/libs aren't redistributable; the cross-toolchain consumes them as a sysroot). See [the toolchain page](../drivers/toolchain.md).

## Quick reference

| Task | Command / file | Tag |
|---|---|---|
| Bring A2065 up | `ifconfig aen0 <ip> netmask <mask> up` | ✅ |
| Bring Hydra up | `slink addaen /dev/hya0 hya0`, then `ifconfig hya0 <ip> … up -trailers` (no `ifconfig plumb` on SVR4.0) | ✅ |
| Bring Z3660 (`zen0`) up | `slink addaen /dev/zen0 zen0`, then `ifconfig zen0 <ip> … up -trailers` (cdevsw 51; real-HW) | ✅ |
| Default route (metric required) | `route add default <gw> 1` | ✅/🟡 |
| Static name→IP, resolver fallback | `/etc/hosts` | ✅ |
| Enable DNS (1/2) | `ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so` + `/etc/resolv.conf` (nameservers only) | ✅ |
| Enable DNS (2/2) | `cp /etc/netconfig.DNS /etc/netconfig` (activates `/usr/lib/resolv.so`) | ✅ |
| **Unset domain** (or DNS breaks) | `cp /dev/null /etc/domain; domainname ""` — else it's appended to every lookup | ✅ |
| **Fix slow boot after DNS** | literal IPs in boot `ifconfig`s: `lo0 127.0.0.1`, `aen0 <static-ip>` — else +180 s/boot | ✅ |
| NFS export / mount | `share` / `shareall`; `mount -F nfs host:/path /mnt` | ✅ |
| SLIP | works once per boot; **reboot between sessions** | 🟡 |
| PPP | not available | ✅ |
| STREAMS `mblk` starvation | box wedges (`ldterm: out of blocks`) while `freemem` is fine; tracks session churn — power-cycle, single-session long jobs | 🟡 |
| **Service refuses connections** (one port only) | `inetd` anti-looping throttle: 40 conns/60 s per service, self-heals ≤ 600 s. Diagnose: port 21 open + port 23 refused ⇒ throttle | ✅ |
| See the throttle (and every other `daemon.*`) | Comment the `exit` on line 8 of `/etc/init.d/syslogd` (**`cp` in place — 3 hard links**); logs land in `/var/log/notice` | ✅ |

## See also

- [Writing a STREAMS driver](../drivers/writing-a-streams-driver.md) — how a network interface attaches to the SVR4 stack.
- [Hydra case study](../drivers/case-studies/hydra.md) — a complete modern STREAMS/DLPI network driver (`hya0`).
- [Z3660 ethernet driver case study](../drivers/z3660-ethernet-driver.md) — a real-hardware STREAMS/DLPI driver (`zen0`) over the Z3660 firmware mailbox; the INT6 storm and polled RX.
- [Kernel architecture](kernel-architecture.md) — monolithic SVR4, STREAMS, no loadable modules.
- [Filesystems and disks](filesystems-and-disks.md) — UFS/s5, needed for NFS server exports.
- [Quirks](quirks.md) — DNS-off-by-default, the `route` metric, and the SLIP reboot bug in one list.
- [Hardware](hardware.md) — the A2065 and other supported expansion.
- [amigaunix.com networking notes](https://www.amigaunix.com/doku.php/networking) — end-user network setup (the community source for the DNS/resolver procedure).

## Sources

- Research brief §11 "Networking, X11, userland" (STREAMS TCP/IP; `aen0`/A2065; static IP, no DHCP; DNS off by default + `libsockdns.so` swap, `in.named`, `/etc/resolv.conf`; `route add default <gw> 1`; NFS server+client; SLIP buggy; no PPP).
- Research brief §2 "Hardware & requirements" (A2065 native; Hydra via `hydra-amix`; Ariadne I via Gateway 🟡).
- Research brief §6 (`isoriano1968/hydra-amix` — STREAMS/DLPI, NE2000/DP8390, `cdevsw` slot 47, `hya0`, AutoConfig `0x08490001`, three-method autoconfig detect, native `make`/`make force` build with GCC 2.7.2.3 from amigaunix.com, `slink` bring-up).
- Research brief §4 "Kernel architecture" (monolithic SVR4; STREAMS, TLI + BSD sockets; no loadable modules).
- Research brief §3 / §10 (`amix_21_boot.adf` string analysis — embedded NFS/RPC client string table), via `tools/inspect-adf.sh`.
- Research brief §12 "Quirks checklist" (DNS off by default; SLIP reboot bug).
- Research brief §13 (cross-toolchain: `gcc-cross-amix` now provides a public `m68k-cbm-sysv4` recipe; native on-box build still simplest).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (cites the SVR4 *Streams Programmer's Guide* and *Network Programmer's Guide*).
- [github.com/isoriano1968/hydra-amix](https://github.com/isoriano1968/hydra-amix)
- [amigaunix.com — networking](https://www.amigaunix.com/doku.php/networking) (community-reported resolver/DNS procedure).
- The A4091-on-Amix project — networking investigation, 2026-06-07 (reproduced locally ✅): instrumented `/etc/rc2` per-script timing on Amix 2.1c under Amiberry; DNS-enabled boot **210 s → 29 s** after replacing the boot-time `ifconfig` hostnames with literal IPs. Source files: `/etc/rc2.d/S69inet`, `/etc/inet/network-config`, `/etc/inet/rc.inet` on the running system.
- The amix-z3660net project — the native `z3660eth` STREAMS/DLPI driver (`zen0`, cdevsw 51 — 48 until 2026-07-30) for the Z3660's onboard ethernet, **validated on a real A4000 + Z3660, 2026-06-21** ✅ (`ifconfig zen0`, `netstat -in` zero-error, laptop↔box `ping`/`ftp`); the firmware-mailbox protocol, the INT6 storm, and the polled-RX design are on [the Z3660 ethernet driver case study](../drivers/z3660-ethernet-driver.md).
- The **amix-kerntools** bench forensics @ `8a76775` — STREAMS `mblk`-arena exhaustion wedges the box (`ldterm: (ldtermsrv) out of blocks`, `console_get_buffer: out of blocks`; TCP then console echo die) while `freemem` stays ~2100 pages, tracking telnet/FTP session count rather than filesystem load; suspected per-connection/per-packet leak on the network path, driver not yet isolated — real A4000 + Z3660, 2026-07-12, carried **🟡**.
- The **amix-kerntools** inetd investigation @ `f7d741d` (`docs/inetd-telnet-throttle.md`), 2026-07-27 ✅ —
  the throttle's constants read out of the shipped `/usr/sbin/inetd` (md5 `ddfbd40aaaa02a1935a5ef6a37879337`):
  `TOOMANY` 40 / `CNT_INTVL` 60 s / `RETRYTIME` 600 s as compile-time immediates, the `daemon.err`
  `openlog()` identity, the anchored (not sliding) window, the global re-enable alarm, the absence of any
  `nowait.<max>` syntax or command-line flag (disassembly **plus** a live `nowait.100` + `SIGHUP` test that
  still tripped at #68), the per-service independence measured both directions (ftp tripped → 23 open;
  telnet tripped → 21 open), and the `syslogd` enablement (`/etc/init.d/syslogd` line-8 `exit`, the
  3-hard-link `cp`-in-place hazard, `daemon.err` already selected by the stock `syslog.conf`, 293 B of
  growth in 23 min of abuse). Measured on a disposable copy of a golden bench image; the golden masters
  were never written to.
- The **amix-cdfs** Packet C wedge soak @ `c3eba7e` (`docs/packet-c-wedge-soak.md`), 2026-07-26/27 ✅ —
  the discovery story and the rate measurements: the wedge reproduced on the first literal sweep replay
  with the filesystem loop **paused**; four bare-TCP trips (29.9/min → no trip in 200 invocations;
  ~550–575/min → trip at 40/61/77); three self-recoveries at 9m48s / 10m11s / 10m00s; FTP up throughout;
  and the box verified healthy *while refusing* (28 processes, zero `in.telnetd`, STREAMS `fail=0` in
  every class, the cdfs mount still traversable).
