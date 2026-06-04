---
title: "Case Study: hydra-amix"
summary: A STREAMS/DLPI Ethernet driver for the Hydra AmigaNet (NE2000/DP8390) Zorro II card, built natively on Amix.
status: draft
---

# Case Study: hydra-amix

[`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix) is a modern, source-only **STREAMS/DLPI Ethernet driver** that brings the Hydra Systems *AmigaNet* card (an NE2000-class board built around the National Semiconductor **DP8390** chip) up as a first-class network interface under Amix 2.1p2 on a 68030 Amiga 3000 ✅. It registers at **`cdevsw` slot 47** under the tag `hya`, and once built into the kernel you link it into the IP stack with **`slink`** — Amix is SVR4.0 and has no `ifconfig … plumb` (see [Bringing the interface up](#bringing-the-interface-up-slink-not-ifconfig-plumb)) ✅.

This page is the worked example for [Writing a STREAMS driver](../writing-a-streams-driver.md): hydra-amix is the project's reference STREAMS network driver, mirroring the structure of the stock A2065 LANCE driver (`aen/`). Everything here is grounded in the repo's README and source ✅ and in §6 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md). The driver is **source-only** — it builds against a licensed Amix SVR4 environment, so no binaries are distributed ✅.

> **Status note.** hydra-amix is a recent, AI-assisted hobby effort, under active development (the source has changed substantially over time — e.g. the AutoConfig ID was corrected and an early A2065-emulation fallback was removed). Facts here track the current `master`; check the repo for newer changes.

## What the Hydra AmigaNet card is

The Hydra is a Zorro II Ethernet board in the NE2000 family ✅:

| Property | Value | Tag |
|---|---|---|
| Card | Hydra Systems AmigaNet, **rev 1.2a** | ✅ |
| Bus | **Zorro II** only (no Zorro III — see [Quirks](../../how-it-works/quirks.md)) | ✅ |
| Ethernet chip | National Semiconductor **DP8390** (NE2000-class NIC) | ✅ |
| Media | **10Base2** (BNC / thin coax) and **10BaseT** (RJ-45) | ✅ |
| AutoConfig ID | **2121 / 1**, i.e. manufacturer `2121` (0x0849), product `1` → combined **0x08490001** | ✅ |

Because it is a Zorro II AutoConfig board, the Amiga firmware assigns its base address at reset and Amix discovers it through the kernel AutoConfig interface — see [Zorro II AutoConfig for drivers](../zorro-autoconfig.md) for how Amix maps these boards. Zorro III is categorically unsupported by Amix, so a Zorro III network card could not be driven this way ✅.

### Register / memory layout on the board

The DP8390 and its supporting memory are mapped at fixed offsets from the card's AutoConfig-assigned base address ✅:

| Region | Offset from base | Notes | Tag |
|---|---|---|---|
| DP8390 NIC registers | `base + 0xffe1` | On the **odd byte lane** (8-bit access, D0–D7) | ✅ |
| MAC address PROM | `base + 0xffc0` | Station address; read **every other byte** (16-bit bus, step-2) | ✅ |
| Packet buffer SRAM | (on-card) | **16 KB** ring buffer for RX/TX | ✅ |

The odd-byte-lane mapping (`+0xffe1`, not `+0xffe0`) is the usual Zorro II trick for putting an 8-bit peripheral on the data bus; the driver's register accessors must honor it. **MAC PROM gotcha:** the PROM at `+0xffc0` sits on a 16-bit bus and must be read with a **step-2 stride** (`base+0xffc0`, `+0xffc2`, …) — a naive contiguous read returns garbage ✅. The 16 KB SRAM is the classic NE2000 send/receive ring; `setup_ne2000` initializes the DP8390 to use it (see [entry points](#entry-points)).

## Where it lives in the kernel: cdevsw slot 47, tag "hya"

hydra-amix is a **character driver with a `streamtab`** — that is, a STREAMS driver, the "third kind" of device in the Amix model ([driver model](../driver-model.md)). It occupies **`cdevsw` slot 47**, and its entry points use the short driver tag **`hya`** ✅, following the Amix convention of prefixing every entry point with the driver tag (`hya` → `hydraopen`, and so on; see [the device-driver model](../driver-model.md)). The device node is created with `mknod /dev/hya0 c 47 0` ✅.

**How it initializes (detect early, init on open).** hydra registers a **boot-time `init_tbl[]` entry**, `hydrainit`, which calls the idempotent `hydraautoconfig()` to **probe for the board at boot** ✅ (`kernel.c` `init_tbl[]`; `hydrainit()` → `hydraautoconfig()`). The *heavy* setup is deferred, though: reading the MAC PROM and programming the DP8390 happen later, the first time the interface is opened (`hydraopen` → `hydra_initialize` → `get_ethernet_address` + `setup_ne2000`) ✅. So "detect at boot, initialize on open" — not the all-at-boot `*init` pattern of, e.g., the parallel driver's `parinit`, but not init-free either. (`hydraautoconfig()` carries a static `hydraautoconfigured` guard so the probe runs once, whether boot or open reaches it first.)

For the broader picture of how STREAMS, TLI, and BSD sockets fit together on Amix, and how the stock `aen0` (A2065) interface is configured, see [Networking](../../how-it-works/networking.md). The `hya0` interface participates in the same SVR4 TCP/IP stack as `aen0`.

## Entry points

The driver implements the standard STREAMS/DLPI surface plus an interrupt handler and a chip-setup helper ✅:

| Entry point | Role | Notes | Tag |
|---|---|---|---|
| `hydraopen` | Stream open / device init | Runs the **multi-method card detect** (below), then initializes the board | ✅ |
| `hydrawput` | STREAMS write-side `put` procedure | Handles DLPI primitives: `DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ` | ✅ |
| `hydraintr` | Interrupt service routine | **Level-2 autovector (INT2)** RX/TX handling | ✅ |
| `setup_ne2000` | Helper | Programs the DP8390 / NE2000 ring buffer for operation | ✅ |

A few things worth highlighting for anyone porting another NE2000-class card:

- **DLPI is the contract.** Higher layers talk to the driver through the SVR4 **Data Link Provider Interface** by sending M_PROTO messages down the stream. `hydrawput` is where those land: `DL_INFO_REQ` reports the link's capabilities (address length, MAC type, SAP, etc.), `DL_BIND_REQ` binds a SAP, and `DL_UNITDATA_REQ` carries an outbound datagram. This is exactly the message-driven model covered in [Writing a STREAMS driver](../writing-a-streams-driver.md).
- **Interrupts are level-2 autovector.** `hydraintr` is wired into the Amix **INT2** path — the same level-2 autovector mechanism the Ditto paper describes via the kernel's `int2_tbl[]` (see [the driver model](../driver-model.md) and [kernel build](../kernel-build.md)). It services both received frames and transmit completions out of the 16 KB ring.

## Multi-method card detection

`hydraautoconfig()` (called from `hydraopen`, run once and cached) tries three strategies, in order, to find and identify the card ✅:

1. **`autocon(NE8390_BOARD_ID, …)`** — read the board from the kernel's **bootinfo `ConfigDev` autoconfig table** (populated by `config()` in `support.c`), *with Zorro II address validation*.
2. **Direct Zorro II I/O-slot probe** — read the MAC PROM at each 64 KB Zorro II I/O slot across **`0xE90000–0xEFFFFF`**.
3. **Zorro II memory-space probe** — scan **`0x200000–0x9FFFFF`** in 64 KB steps for the board.

It uses several methods because, on Amix 2.1p2, the `autocon()` bootinfo table can be **corrupted** (address/size mismatches), so the driver validates the returned address and falls back to direct probes ✅. (The board identity is the AutoConfig ID **0x08490001** — manufacturer `0x0849` / product `1`; see [Zorro AutoConfig](../zorro-autoconfig.md).)

> **Historical note.** An earlier version of the driver included an **A2065-emulation fallback** (stand in for the stock LANCE card when no Hydra was present); it was **removed** (commit *"Purge … A2065 fallback"*). The driver still *mirrors* the `aen/` A2065 driver's STREAMS/DLPI structure (below), but it no longer emulates it.

## Building it: natively on Amix

hydra-amix is **compiled natively on the Amiga under Amix — no cross-compiler is required** ✅. The driver `Makefile` uses the on-box compiler (`cc`/`ld -r`); the build commands are:

```sh
su
# 1. Build the driver object (a relocatable 'exp' linked from hydra.o).
cd /usr/sys/amiga/driver/hydra
make

# 2. Relink the full kernel with the driver.
cd /usr/sys
make force

# 3. Create the device node.
mknod /dev/hya0 c 47 0
```

The native compiler is **GCC 2.7.2.3 for Amix**, distributed as an installable **pkg on [amigaunix.com](https://amigaunix.com)** (the stock AT&T SVR4 `cc` also compiles kernel C) ✅. The kernel-image/boot-relocatable conversion (`elf2brel`, the `stand/`/`boot/` tooling) is part of the on-box kernel build, not a cross step. See [Building and installing a kernel](../kernel-build.md) for the general relink-and-write-boot-partition cycle, and keep the old `/unix` as a fallback.

> **Note on the toolchain "gap".** Earlier project notes flagged the `m68k-amix-gcc` *cross*-compiler as an open 🔴 gap (no public recipe). That gap is real but **not on the path to building this driver**: hydra builds **on-box** with the amigaunix.com GCC pkg. You still need a **licensed Amix install** (kernel headers/libs are not redistributable), which is why the repo is source-only ✅. See [Toolchain](../toolchain.md).

## Bringing the interface up: slink, not `ifconfig plumb`

Amix is **SVR4.0**, which predates the `ifconfig … plumb` mechanism — **`ifconfig plumb` does not exist on Amix** ✅. A STREAMS network interface is linked into IP with **`slink`** instead, then configured with `ifconfig` ✅:

```sh
su
slink addaen /dev/hya0 hya0
ifconfig hya0 <ip-address> netmask <mask> up -trailers
route add default <gateway> 1          # the trailing 1 is the (required) metric
```

The interface name matches the device minor (`hya0` for minor 0). For boot-time setup, the repo adds these to `/etc/inet/network-config` (sourced by `/etc/rc2.d/S69inet`), guarded by `hya -S` (below) so the boot script does not hang on `slink` when no board is present ✅. From here the interface behaves like any Amix Ethernet interface — see [Networking](../../how-it-works/networking.md) for the rest (static IP only, DNS off by default, `route add default <gw> 1`, NFS).

## The `hya` control utility

The repo ships a small user-space tool, **`hya`** (`usr/sys/amiga/driver/hydra/hya/`, installed to `/usr/amiga/bin/hya`), modeled on the A2065's `aen` tool ✅:

| Flag | Description |
|---|---|
| `-S` | Silent check — exit 0 if a board is found, 1 if not (for boot scripts) |
| `-n` | Print the number of Hydra boards detected |
| `-c` | Show MAC address, board base, and debug level |
| `-d dev` | Use an alternate device (default `/dev/hya0`) |

It is backed by two driver ioctls, `HYDRA_NUMBER_OF_BOARDS` and `HYDRA_GET_CONFIG` ✅. The `hya -S` guard is what makes the boot-time `slink` conditional.

## Known issues (from the repo)

The repo's README documents several real-world gotchas worth carrying ✅:

- **`autocon()` table corruption on 2.1p2** — the bootinfo `ConfigDev` table can have address/size mismatches, which is why the driver validates and falls back to direct slot/memory probes (above).
- **MAC PROM byte lane** — the PROM at `base+0xffc0` is a 16-bit bus and must be read with a step-2 (every-other-byte) stride; direct contiguous reads return garbage.
- **Remote-DMA hang** — the standard NE2000 byte-at-the-data-port Remote-DMA method does **not** raise RDC on the Hydra. The hydra-amix driver therefore writes packet data **directly to the card's buffer RAM** (`hydra_ram_write`/`hydra_ram_read` at `board_base + (page<<8)`) instead of using the RDMA data port ✅. (For the *same* problem, the AmigaOS reference driver — [vjouppi/hydra](https://github.com/vjouppi/hydra) — uses Hydra-specific ASIC registers `HYDRA_LOAD1`/`HYDRA_LOAD2` at `board+0x8000+0x7FD2`/`0x7FD5`; those symbols are **not** in the hydra-amix source 🟡.)

## Why this is a good template

If you are writing another NE2000/DP8390-class or Zorro II network driver for Amix, hydra-amix is the closest thing to a template the project has ✅:

- It shows the full **STREAMS/DLPI** write-side handling (`DL_INFO_REQ` / `DL_BIND_REQ` / `DL_UNITDATA_REQ`) you must implement to join the SVR4 stack.
- It demonstrates the **"probe at boot (`init_tbl`/`hydrainit`), full-init on open"** split — a useful pattern for a network interface whose heavy setup you want to defer until it is actually brought up.
- It mirrors the stock **`aen/` LANCE driver**, so reading both side by side teaches the conventions a Commodore-era Amix network driver follows.
- Its **validated multi-method autoconfig** is a practical pattern for coping with the unreliable bootinfo table on real 2.1p2.

## See also

- [Writing a STREAMS driver](../writing-a-streams-driver.md) — the general method this case study illustrates.
- [Networking on Amix](../../how-it-works/networking.md) — the SVR4 STREAMS TCP/IP stack, `aen0`, and how interfaces are configured.
- [Toolchain](../toolchain.md) — native on-box build, the `m68k-cbm-sysv4` triple, and the (separate) cross-compiler gap.
- [The Amix device-driver model](../driver-model.md) — major/minor numbers, `cdevsw`, STREAMS as the third device class, and `int2_tbl[]`.
- [Zorro II AutoConfig for drivers](../zorro-autoconfig.md) — how Amix discovers and maps Zorro II boards by AutoConfig ID.
- [Building and installing a kernel](../kernel-build.md) — the relink-and-write-boot-partition cycle the build feeds into.
- Sibling case studies: [VA2000 framebuffer driver](va2000.md), [Xrtg X11 server](xrtg.md), [lszorro AutoConfig scanner](lszorro.md).

## Sources

- [`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix) — repo README and source (driver entry points, AutoConfig ID `0x08490001`, register offsets, the three-method `hydraautoconfig`, `slink` plumbing, native `make`/`make force` build, the `hya` tool, and the known-issues list). ✅
- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §6 (`isoriano1968/hydra-amix` case-study facts). ✅
- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §11 (networking: SVR4 STREAMS TCP/IP, `aen0`) and §5 (driver model: `cdevsw`, STREAMS, `int2_tbl[]`). ✅
- [vjouppi/hydra](https://github.com/vjouppi/hydra) — Ville Jouppi's AmigaOS Hydra reverse-engineering (register offsets, board schematics), cited by the hydra-amix README. ✅
- AT&T SVR4 *Streams Programmer's Guide* / *Network Programmer's Guide* and the DLPI specification (for the `DL_*` primitives), as cited in the Ditto paper. ✅
