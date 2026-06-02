---
title: "Case Study: hydra-amix"
summary: A STREAMS/DLPI Ethernet driver for the Hydra AmigaNet (NE2000/DP8390) Zorro II card.
status: draft
---

# Case Study: hydra-amix

[`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix) is a modern, source-only **STREAMS/DLPI Ethernet driver** that brings the Hydra Systems *AmigaNet* card (an NE2000-class board built around the National Semiconductor **DP8390** chip) up as a first-class network interface under Amix 2.1p2a on a 68030 Amiga 3000 ✅. It registers at **`cdevsw` slot 47** under the tag `hya`, and once configured you plumb it the SVR4 way: `ifconfig hya0 plumb` ✅.

This page is the worked example for [Writing a STREAMS driver](../writing-a-streams-driver.md): hydra-amix is the project's reference STREAMS network driver, mirroring the structure of the stock A2065 LANCE driver. Everything here is grounded in §6 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), which in turn draws on the repo's README and source ✅. The driver is **source-only** — it requires a licensed Amix SVR4 environment to build, so no binaries are distributed ✅.

> **Status note.** hydra-amix is a recent, AI-assisted hobby effort like its sibling RTG drivers. Treat the build recipe below as "works for the author against real Amix headers," not as a turnkey, publicly reproducible toolchain (see [Toolchain caveat](#toolchain-caveat)).

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
| DP8390 NIC registers | `base + 0xffe1` | On the **odd byte lane** (8-bit access on the odd address) | ✅ |
| MAC address PROM | `base + 0xffc0` | Station (hardware) Ethernet address | ✅ |
| Packet buffer SRAM | (on-card) | **16 KB** ring buffer for RX/TX | ✅ |

The odd-byte-lane mapping (`+0xffe1`, not `+0xffe0`) is the usual Zorro II trick for putting an 8-bit peripheral on the data bus; the driver's register accessors must honor it. The 16 KB SRAM is the classic NE2000 send/receive ring; `setup_ne2000` initializes the DP8390 to use it (see [entry points](#entry-points)).

## Where it lives in the kernel: cdevsw slot 47, tag "hya"

hydra-amix is a **character driver with a `streamtab`** — that is, a STREAMS driver, the "third kind" of device in the Amix model ([driver model](../driver-model.md)). It occupies **`cdevsw` slot 47**, and its entry points use the short driver tag **`hya`** ✅, following the Amix convention of prefixing every entry point with the driver tag (`hya` → `hydraopen`, and so on; see [the device-driver model](../driver-model.md)).

A defining design choice: the driver does **lazy initialization**. It has **no `init_tbl` entry** — it is not initialized at boot. Instead it configures the hardware the first time the interface is plumbed, i.e. at `ifconfig` time ✅. This is the opposite of the eager, boot-time `*init` pattern used by, e.g., the parallel driver's `parinit`.

```sh
# Bring the Hydra interface up (SVR4 STREAMS network plumbing).
ifconfig hya0 plumb
ifconfig hya0 <ip-address> netmask <mask> up
```

For the broader picture of how STREAMS, TLI, and BSD sockets fit together on Amix, and how the stock `aen0` (A2065) interface is configured, see [Networking](../../how-it-works/networking.md). The `hya0` interface participates in the same SVR4 TCP/IP stack as `aen0`.

## Entry points

The driver implements the standard STREAMS/DLPI surface plus an interrupt handler and a chip-setup helper ✅:

| Entry point | Role | Notes | Tag |
|---|---|---|---|
| `hydraopen` | Stream open / device init | Runs the **3-way card detect** (below), then initializes the board | ✅ |
| `hydrawput` | STREAMS write-side `put` procedure | Handles DLPI primitives: `DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ` | ✅ |
| `hydraintr` | Interrupt service routine | **Level-2 autovector (INT2)** RX/TX handling | ✅ |
| `setup_ne2000` | Helper | Programs the DP8390 / NE2000 ring buffer for operation | ✅ |

A few things worth highlighting for anyone porting another NE2000-class card:

- **DLPI is the contract.** Higher layers talk to the driver through the SVR4 **Data Link Provider Interface** by sending M_PROTO messages down the stream. `hydrawput` is where those land: `DL_INFO_REQ` reports the link's capabilities (address length, MAC type, SAP, etc.), `DL_BIND_REQ` binds a SAP, and `DL_UNITDATA_REQ` carries an outbound datagram. This is exactly the message-driven model covered in [Writing a STREAMS driver](../writing-a-streams-driver.md).
- **Interrupts are level-2 autovector.** `hydraintr` is wired into the Amix **INT2** path — the same level-2 autovector mechanism the Ditto paper describes via the kernel's `int2_tbl[]` (see [the driver model](../driver-model.md) and [kernel build](../kernel-build.md)). It services both received frames and transmit completions out of the 16 KB ring.

## Three-way card detection (including A2065 fallback)

`hydraopen` tries three strategies, in order, to find and identify the card before it configures it ✅:

1. **bootinfo** — read board information already collected by the bootstrap / kernel AutoConfig pass.
2. **Zorro probe** — actively scan Zorro II AutoConfig space for the Hydra's ID **0x08490001** (see [Zorro AutoConfig](../zorro-autoconfig.md)).
3. **A2065 fallback emulation** — if no Hydra is found, fall back to driving an **A2065** (the stock Amiga LANCE Ethernet card) ✅.

The A2065 fallback is the most interesting part: hydra-amix is built **mirroring the existing A2065 LANCE driver**, whose source lives in the `aen/` directory of the Amix kernel tree ✅. Because the new code is structured against that reference driver, it can fall back to emulating the A2065 path when the Hydra hardware is absent — useful for development and for systems that have the stock card instead. (`aen` is the device tag of the A2065 driver; its interface is `aen0`, the default Amix Ethernet device — see [Networking](../../how-it-works/networking.md).)

## Building it: cross-compile with m68k-amix-gcc

hydra-amix is **cross-compiled** on a modern host with the `m68k-amix-gcc` toolchain (**GCC 2.7.2.3**, SVR4 target) rather than built natively on the Amix box ✅. The output is an ELF object that is then converted into Amix's boot/relocatable kernel format and linked into the kernel.

```sh
# 1. Cross-compile the driver to an m68k SVR4 ELF object.
make CC=m68k-amix-gcc CFLAGS="-O -D_KERNEL -DSVR40 -DSVR4"

# 2. Convert the ELF to Amix boot-relocatable format with elf2brel (lives in stand/),
#    then build the kernel image for the boot partition.
make oldboot KERNEL=<kernel-image>
```

Notes on each step ✅:

- `-D_KERNEL` selects the kernel-side headers/macros; `-DSVR40 -DSVR4` flag the SVR4 ABI the Amix kernel expects. The triple for this target is `m68k-cbm-sysv4` (autodetect tends to produce `m68k-unknown-sysv4`) — see [Toolchain](../toolchain.md).
- **`elf2brel`** is the helper (shipped in the repo's `stand/` directory) that converts the cross-compiled ELF object into Amix's **boot-relocatable** format so it can be linked into the kernel image ✅.
- `make oldboot` builds the kernel image suitable for writing to the boot partition (the modern Amix 2.1 kernel image is `relocunix`; the 1990 Ditto paper called the equivalent `rdbunix` — a historical rename 🟡). For the general kernel build/install cycle and how the boot partition is written, see [Building and installing a kernel](../kernel-build.md) and [Adding drivers to the boot disk](../../boot-disks/adding-drivers-to-boot-disk.md).

### Toolchain caveat

🔴 **There is no public, reproducible build recipe for the `m68k-amix-gcc` cross-compiler.** It appears to be a private build that needs the proprietary Amix SVR4 headers and libraries, which cannot be redistributed. Treat the commands above as the author's working invocation, not a recipe you can run from a clean machine without first obtaining a licensed Amix environment. This is tracked as an open gap in [Toolchain](../toolchain.md) and in §13 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md). Because of this dependency, the repo is **source-only** — no prebuilt driver is distributed ✅.

## Why this is a good template

If you are writing another NE2000/DP8390-class or Zorro II network driver for Amix, hydra-amix is the closest thing to a template the project has ✅:

- It shows the full **STREAMS/DLPI** write-side handling (`DL_INFO_REQ` / `DL_BIND_REQ` / `DL_UNITDATA_REQ`) you must implement to join the SVR4 stack.
- It demonstrates **lazy, `ifconfig`-time** initialization — no `init_tbl` entry needed — which is appropriate for a network interface you may not always have plugged in.
- It mirrors the stock **`aen/` LANCE driver**, so reading both side by side teaches the conventions a Commodore-era Amix network driver follows.
- Its **3-way detect with A2065 fallback** is a practical pattern for a driver that must cope with absent or alternative hardware.

## See also

- [Writing a STREAMS driver](../writing-a-streams-driver.md) — the general method this case study illustrates.
- [Networking on Amix](../../how-it-works/networking.md) — the SVR4 STREAMS TCP/IP stack, `aen0`, and how interfaces are configured.
- [Toolchain](../toolchain.md) — `m68k-amix-gcc`, the `m68k-cbm-sysv4` triple, and the cross-build gap.
- [The Amix device-driver model](../driver-model.md) — major/minor numbers, `cdevsw`, STREAMS as the third device class, and `int2_tbl[]`.
- [Zorro II AutoConfig for drivers](../zorro-autoconfig.md) — how Amix discovers and maps Zorro II boards by AutoConfig ID.
- [Building and installing a kernel](../kernel-build.md) — the relink-and-write-boot-partition cycle the build feeds into.
- Sibling case studies: [VA2000 framebuffer driver](va2000.md), [Xrtg X11 server](xrtg.md), [lszorro AutoConfig scanner](lszorro.md).

## Sources

- [`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix) — repo README and source (driver entry points, AutoConfig ID, register offsets, build commands). ✅
- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §6 (`isoriano1968/hydra-amix` case-study facts) and §13 (cross-toolchain gap). ✅/🔴
- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §11 (networking: SVR4 STREAMS TCP/IP, `aen0`) and §5 (driver model: `cdevsw`, STREAMS, `int2_tbl[]`). ✅
- AT&T SVR4 *Streams Programmer's Guide* / *Network Programmer's Guide* and the DLPI specification (for the `DL_*` primitives), as cited in the Ditto paper. ✅
