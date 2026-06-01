---
title: Supported Hardware & Requirements
summary: The two official machines, the mandatory 68020/030+MMU+FPU CPU, the hard 16 MB Fast RAM ceiling, the SCSI ID 6/4 rules, Zorro II only, and which expansion cards work.
status: draft
---

# Supported Hardware & Requirements

Amix runs on exactly two officially-supported Amigas — the **A3000UX** and the **A2500UX** — and on close equivalents you assemble from the same parts. The non-negotiable requirements are a **68020 or 68030 with a real MMU**, a **68881/68882 FPU**, **4–16 MB of Fast RAM**, and SCSI disks wired to specific, hard-coded target IDs. There is **no 68040/68060 support** (so no A4000) and **no Zorro III support** — Amix is **Zorro II only**. ✅ (This whole page is uniformly ✅ unless a claim is tagged otherwise.)

If you are setting up an emulator instead of real iron, jump to [the WinUAE emulation guide](../getting-started/emulation-winuae.md), which encodes all of these limits as concrete config values. For the device-node side (major/minor numbers, `/dev` paths) see [the device list](../reference/device-list.md).

## The two official machines

### A3000UX

The flagship Amix machine — an Amiga 3000 configured and badged for Unix. ✅

| Component | Spec |
|---|---|
| CPU | 68030 @ 25 MHz |
| FPU | 68882 @ 25 MHz |
| Chip RAM | 1–2 MB |
| Fast RAM | up to 8 MB (as shipped; the kernel ceiling is 16 MB — see below) |
| SCSI | on-board (A3000 SCSI) |
| Tape | A3070 QIC-150 |
| Ethernet | A2065 |
| Graphics (optional) | **A2410** color graphics card |
| Bootstrap ROM | "Superkickstart 1.4" |
| Mouse | 3-button |

The **"Superkickstart 1.4"** bootstrap ROM is the dual-boot mechanism: hold the **right mouse button at power-on** to load an AmigaOS Kickstart instead; the default action boots Amix. ✅ See [the boot process page](boot-process.md) for what happens after the ROM hands off.

### A2500UX

An Amiga 2500 sold pre-loaded with Amix. The "UX" suffix means *shipped with Amix pre-installed* — the hardware is otherwise identical to a standard A2500. ✅

| Component | Spec |
|---|---|
| Base | A2000 chassis |
| CPU/FPU board | **A2630** (68030 @ 25 MHz + 68882) |
| SCSI controller | A2090 or A2091 |

The first public Amix demo was an A2500UX at Uniforum, Dallas, January 1988 — running SVR3 at that point. ✅ Early demo hardware used a 68020 that later transitioned to the 68030. 🟡 See [the overview](overview.md) for the full lineage.

## Minimum requirements and hard limits

These are not recommendations — they are enforced by the kernel and the install scripts. Violating them produces boot freezes, panics, or silently corrupted SCSI access.

### CPU, MMU, FPU — all three mandatory

- **CPU:** 68020 or 68030. ✅
- **MMU:** a *real* MMU is required. ✅ The kernel uses a full HAT (Hardware Address Translation) layer over the 68030 MMU; there is no software-MMU fallback. A plain 68000, or the MMU-less **68EC020/68EC030** parts, **cannot run Amix**. ✅
- **FPU:** a **68881 or 68882** floating-point unit is required. ✅ There is no soft-float build.

**Note:** "020/030 *with* MMU" excludes the cut-down EC variants specifically — the EC chips drop the MMU (and sometimes the FPU interface), which is exactly the hardware Amix depends on.

### Fast RAM: 4 MB minimum, 16 MB hard ceiling

- **Minimum:** 4 MB Fast RAM. ✅
- **Maximum:** 16 MB Fast RAM — and this is a **hard kernel ceiling**, not a guideline. ✅
- **Exceeding 16 MB mis-maps the SCSI drive.** ✅ The kernel's memory-mapping layer hard-codes the ceiling; install more than 16 MB of Fast RAM and the SCSI disk lands at the wrong address, so the system cannot reach its own disk.

In emulation this translates directly to "set Fast RAM ≤ 16 MB." See [the WinUAE config table](../getting-started/emulation-winuae.md).

### SCSI target IDs are hard-coded

The kernel and the installer assume fixed SCSI target IDs. You do not get to choose them. ✅

| Device | SCSI target ID | Why |
|---|---|---|
| **Hard disk** | **ID 6** | Hard-coded in kernel and install scripts |
| **Tape drive** | **ID 4** | Hard-coded; the installer streams the distribution from here |

Evidence is in the install media itself: `amix_21_root.adf` references the tape as `/dev/rmt/4h` and computes the boot partition device as `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` keyed on the disk target. ✅ (Analysis via `tools/inspect-adf.sh amix_21_root.adf`.)

This is why emulator configs pin the disk hardfile to **SCSI ID 6** and the tape image to **SCSI ID 4** — get either wrong and the install fails. See [the WinUAE guide](../getting-started/emulation-winuae.md).

### No 68040/68060 — and therefore no A4000

The Amix kernel **predates the 68040 MMU** and has no support for it (or the later 68060). ✅ Consequently the **A4000 cannot officially run Amix** ✅ — its standard 68040 CPU is exactly the part the kernel cannot drive. This is a fundamental limit, not a missing driver you could add: the MMU model differs.

### No Zorro III — Zorro II only

Amix supports **Zorro II expansion only**; it has **no Zorro III support**. ✅ The kernel's memory-mapping layer cannot address Zorro III space, and — critically — **that source was never shipped**, so the community cannot fix it. ✅ Any card you want to use must work in (or fall back to) **Zorro II** address ranges.

Board addresses are assigned at reset by the Amiga **AUTOCONFIG** mechanism, which Amix reads through the kernel's `autocon()` interface — again, **Zorro II only**. ✅ See [the Zorro autoconfig driver page](../drivers/zorro-autoconfig.md) for how drivers consume this.

## Supported expansion cards

The following cards are known to work. Entries are ✅ unless tagged 🟡 (community-reported). For the full per-device table with major/minor numbers and `/dev` paths, see [the device list](../reference/device-list.md).

### SCSI controllers

| Card | Status | Notes |
|---|---|---|
| A3000 on-board SCSI | ✅ | The reference controller (A3000UX) |
| A2090 | ✅ | A2500UX option |
| A2091 | ✅ | A2500UX option |
| GVP Series II | 🟡 | Needs a kernel rebuild + an RDB `dummy_handler` |

### Graphics

| Card | Status | Notes |
|---|---|---|
| Built-in (mono) | ✅ | Drives the monochrome X server |
| **A2410** "Lowell" | ✅ | TMS34010, 1024×768, native color support |
| Picasso II / Piccolo / Domino / etc. | 🟡 | Via *Gateway! Vol.2* CD drivers — **Zorro II / linear modes only** |

There is also a modern RTG path: the [MNT VA2000 char framebuffer driver](../drivers/case-studies/va2000.md) plus the [Xrtg X11R5 server](../drivers/case-studies/xrtg.md), both Zorro II.

### Network

| Card | Status | Notes |
|---|---|---|
| **A2065** | ✅ | Native Ethernet (LANCE); device `aen0` |
| Ariadne I | 🟡 | Via *Gateway!* drivers |
| **Hydra** AmigaNet | ✅ | Via the modern [`hydra-amix` STREAMS/DLPI driver](../drivers/case-studies/hydra.md) |

See [the networking page](networking.md) for STREAMS TCP/IP, static-IP setup, and the DNS-off-by-default quirk.

### Serial

| Card | Status | Notes |
|---|---|---|
| **A2232** | ✅ | Adds 7 extra RS-232 ports; managed with `pmadm` |

## How this affects emulation

Every limit above maps onto a specific emulator setting. WinUAE (with MMU emulation, since 2.6.0) is the reference target. The short version:

- CPU **68030**, **MMU ON**, **JIT OFF**, FPU **68882**.
- Fast RAM **≤ 16 MB**.
- Disk hardfile at **SCSI ID 6**; tape image at **SCSI ID 4**.
- A3000 Kickstart ROM (2.04 rev 37.175 or 3.1 40.68).

The full, annotated config table lives in [the WinUAE emulation guide](../getting-started/emulation-winuae.md). FS-UAE works similarly; **Amiberry currently does not** (it lacks A3000 SCSI + tape emulation).

## See also

- [How Amix boots](boot-process.md) — Superkickstart, the bootstrap, the dual-boot mouse button.
- [Filesystems and disks](filesystems-and-disks.md) — RDB layout, the 2 MB boot partition, s5 vs UFS.
- [Quirks](quirks.md) — the SCSI ID rules, 16 MB ceiling, no Zorro III, and the rest, as a checklist.
- [Device list](../reference/device-list.md) — every supported device with its major/minor numbers.
- [WinUAE emulation guide](../getting-started/emulation-winuae.md) — these limits as a config table.
- [Glossary](glossary.md) — MMU, FPU, HAT, AUTOCONFIG, Zorro, RDB, STREAMS.

## Sources

- `sources/research-brief.md` §2 (Hardware & requirements) — primary grounding for this page.
- `sources/research-brief.md` §3 (boot process, AUTOCONFIG/`autocon()`, Zorro II) and §4 (kernel HAT/MMU, RAM ceiling).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — `/dev/rmt/4h` tape path and `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` confirming the SCSI ID 6 disk / ID 4 tape rules.
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — `autocon()` Zorro II board discovery; device major/minor model.
- Hardware/requirements pages on [amigaunix.com](https://www.amigaunix.com/doku.php/home) (community-reported items: GVP Series II, Picasso II/Piccolo/Domino, Ariadne I).
- Card-specific repos: [`hydra-amix`](https://github.com/isoriano1968/hydra-amix), [`va2000-amix`](https://github.com/asokero/va2000-amix), [`xrtg-amix`](https://github.com/asokero/xrtg-amix).
