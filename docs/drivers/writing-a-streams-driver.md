---
title: Writing a STREAMS / DLPI Driver (hydra)
summary: How a network driver plugs in as a STREAMS provider in Amix, walked through the hydra-amix example.
status: draft
---

# Writing a STREAMS / DLPI Driver (hydra)

A network driver in Amix is **not** a `read`/`write` character driver — it is a **STREAMS** driver. It registers a `streamtab` in its `cdevsw[]` slot (via the `d_str` field) instead of `nostr`, exposes a **DLPI** (Data Link Provider Interface) message interface through a `put` routine, and is linked into the IP stack with **`slink`** rather than by opening a device node directly ✅. (Amix is SVR4.0 and **predates `ifconfig … plumb`** — that mechanism does not exist here; see [Bringing the interface up](#bringing-the-interface-up-slink).) The kernel's STREAMS framework, not the syscall layer, drives it.

This page walks the third driver kind using the **`isoriano1968/hydra-amix`** driver — a STREAMS/DLPI driver for the **Hydra AmigaNet** Zorro II Ethernet card (NE2000 / DP8390 chipset) — as the worked example ✅. For the conceptual contrast with block and character drivers see [The Amix device-driver model](driver-model.md); for the networking stack the driver feeds see [Networking](../how-it-works/networking.md). The deep dive on this specific card is the [Hydra DLPI case study](case-studies/hydra.md).

Most of this page is **community-reported 🟡** (it derives from a modern hobby repo, not from the Ditto paper), with the STREAMS-as-a-third-kind framing itself being ✅ from the paper. Tags are marked per claim.

## STREAMS is a distinct driver kind

Amix has three driver categories, not two ✅:

| Kind | Core method(s) | `cdevsw` `d_str` field | Brought up by |
|---|---|---|---|
| **Block** | `strategy()` | n/a (uses `bdevsw[]`) | `mount` |
| **Character** | `read()` / `write()` | `nostr` | open the `/dev` node |
| **STREAMS** | a `put` routine on a `streamtab` | a real `struct streamtab *` | `slink` (network case; Amix has no `ifconfig plumb`) |

A STREAMS driver is *technically* a special character driver: it occupies a `cdevsw[]` slot like any char driver, but its `d_str` field points at a **`streamtab`** instead of the `nostr` stub ✅. That `streamtab` is what tells the kernel "route messages here through the STREAMS framework" rather than calling `d_read`/`d_write`. STREAMS is the SVR4 mechanism for layered, message-based I/O, and in Amix it is how **all networking** (TCP/IP, DLPI) is implemented ✅.

Because the entry point is a message handler (`put`) and not `read`/`write`, the surrounding model differs from the [parallel-port char driver](writing-a-char-driver.md):

- You do not `open()` `hya0` and `write()` packets to it. The TCP/IP stack pushes STREAMS messages down to your `put` routine.
- The card is **probed at boot** (an `init_tbl`/`hydrainit` entry) but **fully initialized at open** (when `slink` opens the stream) — see [Init split](#init-split-probe-at-boot-full-init-on-open).
- The driver speaks **DLPI primitives** (`DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ`, …) to the layer above it — see [The DLPI message interface](#the-dlpi-message-interface-hydrawput).

## Where hydra registers: cdevsw slot 47 (hya)

The Hydra driver installs into **`cdevsw` slot 47** under the short driver tag **`hya`** 🟡. Following the standard Amix [entry-point naming convention](driver-model.md#naming-convention-prefix-every-entry-point), the routines are prefixed for the longer card name (`hydra…`) while the device/interface tag is `hya`:

| Routine | Role | Notes |
|---|---|---|
| `hydraopen` | STREAMS open | init + multi-method card detection (see below) 🟡 |
| `hydrawput` | STREAMS write-side `put` | handles DLPI primitives 🟡 |
| `hydraintr` | INT2 interrupt handler | RX/TX completion 🟡 |
| `setup_ne2000` | low-level DP8390/NE2000 setup helper | called during init 🟡 |

The `cdevsw[47]` entry therefore has a real `streamtab` in `d_str` (whose write-side `put` procedure resolves to `hydrawput`), and `hydraopen` as its open routine. The interface name the kernel exposes is **`hya0`** (unit 0) 🟡.

> **Note:** `cdevsw` slot 47 is what the brief and repo record for `hya` 🟡. When you add your own STREAMS driver, pick an unused major; see the [device list](../reference/device-list.md) for known assignments. A `master.d/kernel.c` (with `cdevsw`/`int2_tbl`/`init_tbl`) is now published in the [hydra-amix repo](https://github.com/isoriano1968/hydra-amix), so the wiring can be read directly 🟡 (whether it is the pristine original or a working copy is unconfirmed) — still confirm free slots against your own `/usr/sys`.

## The card: Hydra AmigaNet (NE2000 / DP8390)

Hardware facts the driver depends on 🟡:

- **Hydra rev 1.2a**, Zorro II.
- AutoConfig ID **2121 / 1** = **`0x08490001`** (manufacturer 2121, product 1).
- DP8390 NIC registers at **`base + 0xffe1`** (odd byte lane).
- MAC-address PROM at **`base + 0xffc0`**.
- **16 KB** on-board SRAM packet buffer.
- Media: **10Base2** (coax) and **10BaseT** (twisted pair).

The DP8390 is the NE2000 register-compatible Ethernet controller, which is why the helper is called `setup_ne2000` 🟡. For how Zorro II boards are discovered at all, see [Zorro II autoconfig for drivers](zorro-autoconfig.md).

## hydraopen: init + multi-method card detection

`hydraopen` is the STREAMS open routine. Beyond the usual STREAMS open bookkeeping it performs a **three-method card detect** (`hydraautoconfig`, run once and cached) 🟡, trying each in turn:

1. **`autocon()` / bootinfo** — read the board from the kernel's bootinfo `ConfigDev` autoconfig table, *with Zorro II address validation*.
2. **Direct Zorro II I/O-slot probe** — read the MAC PROM at each 64 KB I/O slot across `0xE90000–0xEFFFFF`.
3. **Zorro II memory-space probe** — scan `0x200000–0x9FFFFF` in 64 KB steps.

It uses several methods because the `autocon()` bootinfo table can be **corrupted** on Amix 2.1p2, so the driver validates the address and falls back to direct probes 🟡. (An earlier version had an **A2065-emulation fallback** — stand in for the stock LANCE card when no Hydra was present — but it was **removed**; the driver still *mirrors* the `aen/` A2065 driver's structure — see [Mirroring the A2065 LANCE driver](#mirroring-the-a2065-lance-driver-aen) — without emulating it.)

After detection, `hydraopen` calls `hydra_initialize`, which reads the MAC from the PROM at `base + 0xffc0` (step-2, every other byte) via `get_ethernet_address`, then programs the DP8390 via `setup_ne2000` 🟡.

## The DLPI message interface (hydrawput)

`hydrawput` is the write-side STREAMS **`put` procedure**. The layer above (the IP/STREAMS plumbing) sends it **DLPI** M_PROTO/M_PCPROTO messages; `hydrawput` switches on the primitive 🟡. The three primitives the driver handles 🟡:

| DLPI primitive | Meaning | hydra's response |
|---|---|---|
| `DL_INFO_REQ` | "describe yourself" — capabilities query | reply with a `DL_INFO_ACK` describing the link (address length, SAP, MAC, MTU, …) |
| `DL_BIND_REQ` | bind a SAP (Service Access Point) to this stream | acknowledge the bind so the stream can send/receive that SAP |
| `DL_UNITDATA_REQ` | send one datagram (a connectionless data unit) | build the Ethernet frame and queue it to the DP8390 for transmission |

Inbound frames take the reverse path: `hydraintr` pulls received packets off the card and pushes them **up** the stream to whatever bound the matching SAP 🟡. The brief records `hydraintr` handles RX/TX but does not name the specific DLPI indication primitive used for received frames; the exact upstream message type is 🔴 unconfirmed from primary sources.

This is why a STREAMS net driver has **no `read`/`write`**: the data path is the DLPI message exchange, not byte syscalls. Contrast the [character-driver](writing-a-char-driver.md) `read`/`write` core.

## hydraintr: the INT2 interrupt path

`hydraintr` is registered as a **level-2 (INT2) autovector** interrupt handler — the same level-2 mechanism the parallel and SCSI drivers use (`parintr`, `a2090intr`, …) via `int2_tbl[]` ✅. It fires on RX and TX events from the DP8390 🟡:

- **RX:** drain received frames from the 16 KB SRAM ring and send them up the stream 🟡 (specific DLPI indication primitive used is 🔴 not named in the brief).
- **TX:** acknowledge transmit completion and start the next queued frame.

Adding a level-2 interrupt driver means contributing an entry to `int2_tbl[]` in `kernel.c`, exactly as a char driver would; see [the *_tbl arrays](driver-model.md#the-_tbl-arrays) and [Building and installing a kernel](kernel-build.md).

> **RX gotcha worth stealing — the DP8390 frame length includes the CRC.** The single fix that got hydra from "compiles" to "ARP and ping work on real hardware" (2026-06) was in the RX length check: the DP8390 receive ring's reported byte count **includes the 4-byte Ethernet CRC**, so after you strip CRC the **minimum frame is 60 bytes, not 64**. The driver had been rejecting post-CRC frames below 64, which silently **dropped minimum-size ARP replies** — so ARP never completed. The fix is to validate against `ETH_MINFRAME` (= `ETH_MINPACKET − ETH_CRC_LEN` = 60), not the on-the-wire 64 ✅. If you write a DP8390/NE2000 RX path, get this boundary right or small control frames vanish. (It rode on a broader RX-ring and NIC-init hardening pass — see [the Hydra case study](case-studies/hydra.md#what-made-it-work).)

## Init split: probe at boot, full-init on open

hydra registers a **boot-time `init_tbl[]` entry** (`hydrainit`) that calls the idempotent `hydraautoconfig()` to **probe for the board at boot** ✅. But the *heavy* setup — reading the MAC PROM and programming the DP8390 — is **deferred to open**: it runs the first time the interface is brought up, when `slink` opens the stream and `hydraopen` calls `hydra_initialize` 🟡. So "detect at boot, initialize on open," not all-at-boot.

The practical consequence: the table edits in `kernel.c` for hydra add a `cdevsw[]` slot (47) with a `streamtab`, an `int2_tbl[]` entry for `hydraintr`, **and** an `init_tbl[]`/`io_init[]` entry (`hydrainit`) — like the [VA2000 framebuffer driver](case-studies/va2000.md) (`va2000init`). The difference from VA2000 is *what* the init does: hydra's boot init only *probes*; it defers the real programming to open, whereas VA2000 must claim its Zorro window at boot ✅.

> **A simpler variant — no `init_tbl`/`int2_tbl` at all.** The [`z3660eth` driver](z3660-ethernet-driver.md) (interface `zen0`) takes hydra's "init on open" idea one step further: it autoconfigs entirely on first `open` and services received frames from a **polled clock-level `timeout()` callout** instead of an interrupt — so its only `kernel.c` edit is the single `cdevsw[48]` `streamtab` slot ✅. That keeps a board-less build kernel safe (a missing board just makes `open()` return `ENXIO`, never a boot-time panic), and on the Z3660 it was the *necessary* design: the board's firmware raises Amiga **INT6** on every received frame, but Amix has no level-6 ethernet handler, so leaving interrupts on storms the kernel. Polled RX with the firmware interrupt disabled is the robust path when you can't safely own the IRQ. See [the Z3660 ethernet driver case study](z3660-ethernet-driver.md).

## Bringing the interface up: slink

Amix is **SVR4.0** and **has no `ifconfig … plumb`** — that operation came later in the SVR4 line ✅. A STREAMS network driver is linked into the IP stack with **`slink`**, then configured with `ifconfig` 🟡:

```sh
# Link the STREAMS driver under IP (slink), then configure the interface.
slink addaen /dev/hya0 hya0
ifconfig hya0 <ip-address> netmask <mask> up -trailers
```

`slink addaen` is the Amix operation that links the driver's stream under IP (the same `addaen` form used for the stock A2065); it opens `/dev/hya0`, which triggers `hydraopen`, the multi-method detection, and `setup_ne2000` 🟡. The interface name matches the device minor (`hya0` for minor 0). From there the interface behaves like any Amix Ethernet interface — see [Networking](../how-it-works/networking.md) for the rest (static IP only, DNS off by default, `route add default <gw> 1`, NFS).

## Mirroring the A2065 LANCE driver (aen)

The hydra driver was written to **mirror the existing A2065 LANCE Ethernet driver** in the kernel source tree, whose tag is **`aen`** (interface `aen0`) 🟡. This is the recommended way to write a new Amix net driver: start from the in-tree `aen/` driver as a template, because it already shows the correct `streamtab` shape, DLPI handling, and STREAMS plumbing for an Amix Ethernet provider 🟡.

Because the two drivers share so much structure, an early version of hydra could even *emulate* `aen` as a fallback when no Hydra board was present; that fallback has since been **removed** from the repo, but the shared structure is still why the in-tree `aen/` driver is the right template to start from 🟡.

## Building the driver (natively on Amix)

hydra is **source-only** and is **built natively on the Amix box — no cross-compiler** ✅. You still need a licensed Amix install (kernel headers/libs are not redistributable), which is why no binaries ship. The driver `Makefile` uses the on-box compiler (`cc`/`ld -r`); the build is just:

```sh
su
cd /usr/sys/amiga/driver/hydra && make      # builds the relocatable 'exp' from hydra.o
cd /usr/sys && make force                    # relinks the full kernel with the driver
mknod /dev/hya0 c 47 0                        # create the device node
```

The native compiler is **GCC 2.7.2.3 for Amix**, distributed as an installable **pkg on [amigaunix.com](https://amigaunix.com)** (the stock AT&T SVR4 `cc` also compiles kernel C) ✅. The kernel-image / boot-relocatable conversion (`elf2brel`, the `boot/`/`stand/` tooling) is part of this on-box kernel build, not a separate cross step. For the relink mechanics see [Building and installing a kernel](kernel-build.md), and keep the old `/unix` as a fallback.

> **Note:** hydra builds on-box with the amigaunix.com GCC pkg. As of 2026-06 a Linux-hosted **cross-toolchain** also exists — [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix) (`m68k-cbm-sysv4-gcc`), which closes the earlier "no public cross recipe" gap ✅ — so you can build driver objects on a modern host too (it takes your licensed Amix tree as a sysroot). See the [toolchain page](toolchain.md) and the [licensing boundary](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md) (obtain Amix media via [amigaunix.com](https://www.amigaunix.com/doku.php/home) / archive.org, never by redistribution).

## Checklist: adding a STREAMS net driver

Putting it together — the STREAMS-specific deltas on top of the generic [add-a-driver workflow](driver-model.md#adding-a-driver-the-table-workflow) 🟡:

1. Write the driver mirroring the in-tree `aen/` LANCE driver: a `streamtab`, a write-side `put` routine, and an INT2 handler.
2. Implement the DLPI primitives the stack needs at minimum: `DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ` (down, per the brief 🟡); what the interrupt path sends upstream is 🔴 not confirmed in primary sources — use the `aen/` driver as the template.
3. In `master.d/kernel.c`: add a `cdevsw[]` slot at your major with `d_str` pointing at your `streamtab` (not `nostr`), add your interrupt routine to `int2_tbl[]`, and (like hydra) an `init_tbl[]` entry that *probes* the board at boot — deferring the heavy init to open if you wish.
4. Build **natively on the Amix box**: `make` in the driver dir, then `cd /usr/sys && make force` to relink the kernel (per [kernel build](kernel-build.md)). Keep the old `/unix` as a fallback ✅.
5. Create the node (`mknod /dev/<iface> c <major> 0`), then bring it up with `slink addaen /dev/<iface> <iface>` and `ifconfig <iface> <ip> netmask <m> up -trailers`.

## See also

- [The Amix device-driver model](driver-model.md) — block vs char vs STREAMS, `cdevsw`/`bdevsw`, the naming convention.
- [Writing a character driver](writing-a-char-driver.md) — the `read`/`write` contrast (the `par` driver).
- [Hydra DLPI case study](case-studies/hydra.md) — the full device-level deep dive.
- [Z3660 ethernet driver case study](z3660-ethernet-driver.md) — a second worked example: polled RX over the Z3660 firmware mailbox, no `int2_tbl`, real-hardware-verified.
- [Networking](../how-it-works/networking.md) — the STREAMS TCP/IP stack hydra feeds; A2065, static IP, DNS, NFS.
- [Toolchain](toolchain.md) — the native on-box build, `elf2brel`, and the `gcc-cross-amix` cross-toolchain.
- [Building and installing a kernel](kernel-build.md) — relink (`make force`) and boot-partition install.
- [Zorro II autoconfig for drivers](zorro-autoconfig.md) — discovering the board (`autocon()`, AutoConfig IDs).
- [Device list reference](../reference/device-list.md) — known major/minor and `cdevsw` slot assignments.

## Sources

- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §6 (`isoriano1968/hydra-amix`: `cdevsw` slot 47 `hya`, `hydraopen`/`hydrawput`/`hydraintr`/`setup_ne2000`, DLPI `DL_INFO_REQ`/`DL_BIND_REQ`/`DL_UNITDATA_REQ`, three-method autoconfig detect (autocon/bootinfo + Zorro II I/O-slot + memory probe; A2065 fallback removed), init split (boot `init_tbl`/`hydrainit` probe + full init on open), mirrors `aen/` LANCE, **native** `make`/`make force` build with GCC 2.7.2.3 from amigaunix.com, `slink` bring-up (no `ifconfig plumb`), Hydra rev 1.2a / AutoConfig `0x08490001` / DP8390 at `base+0xffe1` / MAC PROM `base+0xffc0` step-2 / 16 KB SRAM / 10Base2 + 10BaseT, the `hya` tool), §5 (STREAMS as a third driver kind, `cdevsw` `d_str`/`nostr`, `int2_tbl[]`, naming convention), §11 (networking: STREAMS TCP/IP, `aen0`), §7 (toolchain: native GCC 2.7.2.3, `m68k-cbm-sysv4` triple; cross-toolchain via `gcc-cross-amix`), §13 (cross-toolchain now public via `gcc-cross-amix`; native on-box still simplest).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — §5 of the brief (STREAMS = special char driver with a `streamtab`; `int2_tbl[]`; entry-point prefix convention).
- `isoriano1968/hydra-amix` repo: <https://github.com/isoriano1968/hydra-amix>
- amigaunix.com — historical and end-user reference: <https://www.amigaunix.com/doku.php/home>
