---
title: Writing a STREAMS / DLPI Driver (hydra)
summary: How a network driver plugs in as a STREAMS provider in Amix, walked through the hydra-amix example.
status: draft
---

# Writing a STREAMS / DLPI Driver (hydra)

A network driver in Amix is **not** a `read`/`write` character driver — it is a **STREAMS** driver. It registers a `streamtab` in its `cdevsw[]` slot (via the `d_str` field) instead of `nostr`, exposes a **DLPI** (Data Link Provider Interface) message interface through a `put` routine, and is brought up with `ifconfig <iface> plumb` rather than by opening a device node directly ✅. The kernel's STREAMS framework, not the syscall layer, drives it.

This page walks the third driver kind using the **`isoriano1968/hydra-amix`** driver — a STREAMS/DLPI driver for the **Hydra AmigaNet** Zorro II Ethernet card (NE2000 / DP8390 chipset) — as the worked example ✅. For the conceptual contrast with block and character drivers see [The Amix device-driver model](driver-model.md); for the networking stack the driver feeds see [Networking](../how-it-works/networking.md). The deep dive on this specific card is the [Hydra DLPI case study](case-studies/hydra.md).

Most of this page is **community-reported 🟡** (it derives from a modern hobby repo, not from the Ditto paper), with the STREAMS-as-a-third-kind framing itself being ✅ from the paper. Tags are marked per claim.

## STREAMS is a distinct driver kind

Amix has three driver categories, not two ✅:

| Kind | Core method(s) | `cdevsw` `d_str` field | Brought up by |
|---|---|---|---|
| **Block** | `strategy()` | n/a (uses `bdevsw[]`) | `mount` |
| **Character** | `read()` / `write()` | `nostr` | open the `/dev` node |
| **STREAMS** | a `put` routine on a `streamtab` | a real `struct streamtab *` | `ifconfig <iface> plumb` (network case) |

A STREAMS driver is *technically* a special character driver: it occupies a `cdevsw[]` slot like any char driver, but its `d_str` field points at a **`streamtab`** instead of the `nostr` stub ✅. That `streamtab` is what tells the kernel "route messages here through the STREAMS framework" rather than calling `d_read`/`d_write`. STREAMS is the SVR4 mechanism for layered, message-based I/O, and in Amix it is how **all networking** (TCP/IP, DLPI) is implemented ✅.

Because the entry point is a message handler (`put`) and not `read`/`write`, the surrounding model differs from the [parallel-port char driver](writing-a-char-driver.md):

- You do not `open()` `hya0` and `write()` packets to it. The TCP/IP stack pushes STREAMS messages down to your `put` routine.
- Configuration happens at **plumb time** (`ifconfig hya0 plumb`), not at boot — see [Lazy init](#lazy-init-configure-at-plumb-time-not-boot).
- The driver speaks **DLPI primitives** (`DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ`, …) to the layer above it — see [The DLPI message interface](#the-dlpi-message-interface-hydrawput).

## Where hydra registers: cdevsw slot 47 (hya)

The Hydra driver installs into **`cdevsw` slot 47** under the short driver tag **`hya`** 🟡. Following the standard Amix [entry-point naming convention](driver-model.md#naming-convention-prefix-every-entry-point), the routines are prefixed for the longer card name (`hydra…`) while the device/interface tag is `hya`:

| Routine | Role | Notes |
|---|---|---|
| `hydraopen` | STREAMS open | init + 3-way card detection (see below) 🟡 |
| `hydrawput` | STREAMS write-side `put` | handles DLPI primitives 🟡 |
| `hydraintr` | INT2 interrupt handler | RX/TX completion 🟡 |
| `setup_ne2000` | low-level DP8390/NE2000 setup helper | called during init 🟡 |

The `cdevsw[47]` entry therefore has a real `streamtab` in `d_str` (whose write-side `put` procedure resolves to `hydrawput`), and `hydraopen` as its open routine. The interface name the kernel exposes is **`hya0`** (unit 0) 🟡.

> **Note:** `cdevsw` slot 47 is what the brief and repo record for `hya` 🟡. When you add your own STREAMS driver, pick an unused major; see the [device list](../reference/device-list.md) for known assignments. The full original `master.d/kernel.c` is not publicly archived, so confirm free slots against your own `/usr/sys` 🔴.

## The card: Hydra AmigaNet (NE2000 / DP8390)

Hardware facts the driver depends on 🟡:

- **Hydra rev 1.2a**, Zorro II.
- AutoConfig ID **2121 / 1** = **`0x08490001`** (manufacturer 2121, product 1).
- DP8390 NIC registers at **`base + 0xffe1`** (odd byte lane).
- MAC-address PROM at **`base + 0xffc0`**.
- **16 KB** on-board SRAM packet buffer.
- Media: **10Base2** (coax) and **10BaseT** (twisted pair).

The DP8390 is the NE2000 register-compatible Ethernet controller, which is why the helper is called `setup_ne2000` 🟡. For how Zorro II boards are discovered at all, see [Zorro II autoconfig for drivers](zorro-autoconfig.md).

## hydraopen: init + 3-way card detection

`hydraopen` is the STREAMS open routine. Beyond the usual STREAMS open bookkeeping it performs **3-way card detection** 🟡, trying each method in turn:

1. **bootinfo** — read the board address/parameters the bootstrap already discovered.
2. **Zorro probe** — actively probe Zorro II AutoConfig space for ID `0x08490001`.
3. **A2065 fallback emulation** — if no Hydra is found, **fall back to emulating the A2065** LANCE Ethernet card 🟡.

That A2065 fallback is the notable design choice: it lets the same `hya0` plumb path work on a machine that only has the stock [A2065 Ethernet](../how-it-works/networking.md) card, by emulating its behaviour rather than failing. This is possible because hydra deliberately **mirrors the existing A2065 LANCE driver** (`aen/` in the kernel source tree) — see [Mirroring the A2065 LANCE driver](#mirroring-the-a2065-lance-driver-aen) 🟡.

After detection, `hydraopen` calls `setup_ne2000` to program the DP8390 and reads the MAC from the PROM at `base + 0xffc0` 🟡.

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

## Lazy init: configure at plumb time, not boot

Unlike most drivers, hydra has **no `init_tbl[]` (boot-time init) entry** 🟡. It uses **lazy initialization**: the card is detected and programmed when the interface is first plumbed, i.e. at `ifconfig hya0 plumb` time, by way of `hydraopen` — not once at boot 🟡.

The practical consequence: the table edits in `kernel.c` for hydra add a `cdevsw[]` slot (47) with a `streamtab`, and an `int2_tbl[]` entry for `hydraintr`, but **no** `init_tbl[]`/`io_init[]` line. Compare the [VA2000 framebuffer driver](case-studies/va2000.md), which *does* add a `va2000init` to its init array because it must claim its Zorro window at boot ✅.

## Bringing the interface up: ifconfig hya0 plumb

A STREAMS network driver is activated by plumbing it into the protocol stack, not by opening a `/dev` node 🟡:

```sh
# Plumb the STREAMS interface into the IP stack, then configure it.
ifconfig hya0 plumb
ifconfig hya0 <ip-address> netmask <mask> up
```

`plumb` is the SVR4 operation that links the driver's stream under IP; it triggers `hydraopen`, the 3-way detection, and `setup_ne2000` 🟡. From there the interface behaves like any Amix Ethernet interface — see [Networking](../how-it-works/networking.md) for the rest (static IP only, DNS off by default, `route add default <gw> 1`, NFS).

## Mirroring the A2065 LANCE driver (aen)

The hydra driver was written to **mirror the existing A2065 LANCE Ethernet driver** in the kernel source tree, whose tag is **`aen`** (interface `aen0`) 🟡. This is the recommended way to write a new Amix net driver: start from the in-tree `aen/` driver as a template, because it already shows the correct `streamtab` shape, DLPI handling, and STREAMS plumbing for an Amix Ethernet provider 🟡.

This mirroring is also what makes the [A2065 fallback emulation](#hydraopen-init--3-way-card-detection) in `hydraopen` natural — the two drivers share enough structure that hydra can stand in for `aen` when no Hydra board is present 🟡.

## Cross-building the driver

hydra is **source-only** and **cross-compiled**; it needs a licensed Amix SVR4 toolchain to link against (kernel headers/libs are not redistributable) 🟡. The recorded build uses **`m68k-amix-gcc`** (GCC 2.7.2.3, SVR4 target) and the in-tree boot tooling:

```sh
# Cross-compile the driver objects (kernel build flags).
make CC=m68k-amix-gcc CFLAGS="-O -D_KERNEL -DSVR40 -DSVR4"
```

The pipeline 🟡:

1. `m68k-amix-gcc` compiles/links the driver into an **ELF** object (target triple `m68k-cbm-sysv4`; autodetect yields `m68k-unknown-sysv4`) ✅.
2. **`elf2brel`** (in the `stand/` directory of the build) converts that ELF into the **Amix boot relocatable format** the bootstrap expects 🟡.
3. `make oldboot KERNEL=…` writes the resulting kernel image so it can be booted 🟡.

For the compiler, the `_KERNEL`/`SVR4` flags, and the rest of the cross-build story see [Toolchain](toolchain.md) and the kernel-relink mechanics in [Building and installing a kernel](kernel-build.md).

> **Warning:** there is **no public, reproducible build recipe** for the `m68k-amix-gcc` cross-compiler — it is a private build that needs the proprietary Amix SVR4 headers and libraries 🔴. Treat the toolchain as an open gap: you cannot currently reproduce this build from scratch without already having an Amix install to harvest headers/libs from. See the [licensing boundary](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md) — obtain media via [amigaunix.com](https://www.amigaunix.com/doku.php/home) / archive.org, never by redistribution.

## Checklist: adding a STREAMS net driver

Putting it together — the STREAMS-specific deltas on top of the generic [add-a-driver workflow](driver-model.md#adding-a-driver-the-table-workflow) 🟡:

1. Write the driver mirroring the in-tree `aen/` LANCE driver: a `streamtab`, a write-side `put` routine, and an INT2 handler.
2. Implement the DLPI primitives the stack needs at minimum: `DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ` (down, per the brief 🟡); what the interrupt path sends upstream is 🔴 not confirmed in primary sources — use the `aen/` driver as the template.
3. In `master.d/kernel.c`: add a `cdevsw[]` slot at your major with `d_str` pointing at your `streamtab` (not `nostr`), and add your interrupt routine to `int2_tbl[]`. **No** `init_tbl[]` entry if you initialise lazily at plumb time.
4. Cross-build with `m68k-amix-gcc`, convert with `elf2brel`, install with `make oldboot KERNEL=…` (or relink natively per [kernel build](kernel-build.md)). Keep the old `/unix` as a fallback ✅.
5. Bring it up with `ifconfig <iface> plumb` then configure the address.

## See also

- [The Amix device-driver model](driver-model.md) — block vs char vs STREAMS, `cdevsw`/`bdevsw`, the naming convention.
- [Writing a character driver](writing-a-char-driver.md) — the `read`/`write` contrast (the `par` driver).
- [Hydra DLPI case study](case-studies/hydra.md) — the full device-level deep dive.
- [Networking](../how-it-works/networking.md) — the STREAMS TCP/IP stack hydra feeds; A2065, static IP, DNS, NFS.
- [Toolchain](toolchain.md) — `m68k-amix-gcc`, `elf2brel`, the SVR4 cross-build.
- [Building and installing a kernel](kernel-build.md) — relink, boot-partition/`oldboot` install.
- [Zorro II autoconfig for drivers](zorro-autoconfig.md) — discovering the board (`autocon()`, AutoConfig IDs).
- [Device list reference](../reference/device-list.md) — known major/minor and `cdevsw` slot assignments.

## Sources

- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §6 (`isoriano1968/hydra-amix`: `cdevsw` slot 47 `hya`, `hydraopen`/`hydrawput`/`hydraintr`/`setup_ne2000`, DLPI `DL_INFO_REQ`/`DL_BIND_REQ`/`DL_UNITDATA_REQ`, 3-way detect with A2065 fallback, lazy init, mirrors `aen/` LANCE, `m68k-amix-gcc` + `elf2brel` + `make oldboot`, Hydra rev 1.2a / AutoConfig `0x08490001` / DP8390 at `base+0xffe1` / MAC PROM `base+0xffc0` / 16 KB SRAM / 10Base2 + 10BaseT), §5 (STREAMS as a third driver kind, `cdevsw` `d_str`/`nostr`, `int2_tbl[]`, naming convention), §11 (networking: STREAMS TCP/IP, `aen0`, plumb model), §7 (`m68k-amix-gcc` GCC 2.7.2.3, `m68k-cbm-sysv4` triple), §13 (🔴 no public `m68k-amix-gcc` recipe; 🔴 `kernel.c` not archived).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — §5 of the brief (STREAMS = special char driver with a `streamtab`; `int2_tbl[]`; entry-point prefix convention).
- `isoriano1968/hydra-amix` repo: <https://github.com/isoriano1968/hydra-amix>
- amigaunix.com — historical and end-user reference: <https://www.amigaunix.com/doku.php/home>
