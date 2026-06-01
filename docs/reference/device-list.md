---
title: Device & Card Reference
summary: Known /dev major/minor numbers and the hardware cards Amix supports.
status: draft
---

# Device & Card Reference

This is the quick-reference table for two things you keep needing when you work with Amix: the **`/dev` major/minor numbers** the kernel uses, and the **expansion cards** Amix actually supports. The two tables below are the answer; the notes after each table explain the encodings and caveats.

A device node in Amix carries a **major** number (which driver) and a **minor** number (which sub-device). The kernel indexes a per-class switch table by the major and never looks at the file name — see [the device-driver model](../drivers/driver-model.md) for the mechanism. Hardware support is constrained by hard kernel rules (Zorro II only, 68020/030 + MMU + FPU, 4–16 MB Fast RAM, SCSI disk at ID 6 / tape at ID 4) — those are covered in full on [the hardware page](../how-it-works/hardware.md).

Each row carries the same confidence tag the [research brief](../../sources/research-brief.md) uses: ✅ verified (primary source / repo source / reproduced locally), 🟡 community-reported, 🔴 unverified.

## /dev major/minor numbers

The four stock entries below come from the `ls -l /dev` excerpt in the Ditto driver paper (§5 of the brief) ✅. The two community-driver entries (va2000, hydra) come from the modern driver repos (§6) ✅.

| `/dev` node | Class | Major | Minor | Driver / purpose | Tag |
|---|---|---|---|---|---|
| `/dev/console` | char | **0** | 0 | System console | ✅ |
| `/dev/par` | char | **21** | 0 | Amiga parallel port (output-only Centronics) | ✅ |
| `/dev/fd0` | block | **16** | — | Floppy disk driver | ✅ |
| `/dev/dsk/c0d0s1` | block | **18** | encoded (see below) | SCSI hard-disk driver | ✅ |
| `/dev/va2000` | char | **68** | 0 | MNT VA2000 RTG framebuffer (`asokero/va2000-amix`) | ✅ |
| `/dev/<hya>` | char | **47** | — | Hydra AmigaNet STREAMS/DLPI driver, tag `hya` (`isoriano1968/hydra-amix`) | ✅ |

**Note:** the major number is the **index into `cdevsw[]` (character) or `bdevsw[]` (block)** in `master.d/kernel.c`. A driver "registers" at a major by occupying that slot. There is no global registry that allocates them — community drivers pick a free slot (va2000 took char 68, hydra took char 47) and patch it into `kernel.c` themselves ✅. See [Building and installing a kernel](../drivers/kernel-build.md) for how a slot is wired in.

### Minor-number encoding for the SCSI disk (major 18)

For the SCSI hard-disk driver, the minor number is **not** a simple index — it packs three fields: **SCSI address**, **LUN**, and **partition** ✅. The paper's example node `/dev/dsk/c0d0s1` is **block major 18, minor 1** = SCSI address 0, LUN 0, partition 1 ✅.

In the `c<addr>d<lun>s<part>` naming you will see on disk:

- `c0d0s1` → controller/SCSI-address 0, drive/LUN 0, slice (partition) 1.
- The boot/root logic uses this directly: root.adf computes `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` ✅.

Two **hard-coded SCSI target rules** the kernel and install scripts enforce (these are device-addressing facts, not just conventions) ✅:

- **Hard disk must be SCSI ID 6.**
- **Tape must be SCSI ID 4** — the raw tape node is `/dev/rmt/4h` (and `/dev/rmt/4hn` for the no-rewind variant used by the installer's `dd if=/dev/rmt/4hn …`) ✅.

See [Quirks](../how-it-works/quirks.md) for why these IDs are fixed and what breaks if you ignore them.

### The hydra STREAMS driver (char 47)

Hydra is a **STREAMS/DLPI network driver**, which in Amix is a special kind of character driver: it occupies a `cdevsw[]` slot (**47**, tag `hya`) but exposes a `streamtab` rather than ordinary `read()`/`write()` ✅. You do not normally `cat` its `/dev` node; you bring the interface up with:

```sh
ifconfig hya0 plumb
```

Unlike most drivers, hydra has **no `init_tbl[]` entry** — it does lazy initialization at `ifconfig`-plumb time rather than at boot ✅. For the full driver internals see [the Hydra case study](../drivers/case-studies/hydra.md); for the networking stack it plugs into see [Networking](../how-it-works/networking.md).

### The va2000 framebuffer (char 68)

The VA2000 driver is a single-file char framebuffer driver. After building and installing it you create the node with:

```sh
mknod /dev/va2000 c 68 0
```

It supports 800×600 / 1024×768 / 1280×720 at 16-bit ✅, and it is the device the `Xrtg` X11 server draws into. See [the VA2000 case study](../drivers/case-studies/va2000.md) and [X11/RTG drivers](../drivers/x11-rtg-drivers.md).

### Other device nodes referenced in the brief

These appear in the brief but without an authoritative major/minor pairing, so they are listed for orientation only:

| `/dev` node | Notes | Tag |
|---|---|---|
| `/dev/mem` | Physical-memory device; `lszorro` opens it and `mmap()`s AutoConfig windows ✅ | ✅ |
| `/dev/rmt/4h`, `/dev/rmt/4hn` | Raw / no-rewind tape at SCSI ID 4 ✅ | ✅ |
| `aen0` | A2065 Ethernet **network interface** (not a `/dev` node — an `ifconfig` name) ✅ | ✅ |
| `hya0` | Hydra network interface name (plumbed from the char-47 driver) ✅ | ✅ |

**Note:** `aen0` and `hya0` are *interface* names managed via `ifconfig`/STREAMS, distinct from `/dev` device-file majors. The underlying A2065 LANCE driver source lives in `aen/` in the kernel tree (the hydra driver was modelled on it) ✅.

## Supported expansion cards

Everything here is **Zorro II only** — Amix's memory-mapping layer cannot address Zorro III space, and that source was never shipped so it cannot be community-fixed ✅. Cards are grouped by function. Tags follow the brief.

### SCSI host adapters

| Card | Notes | Tag |
|---|---|---|
| **A3000 on-board SCSI** | The reference controller on the A3000UX | ✅ |
| **A2090** | A2000-family SCSI controller | ✅ |
| **A2091** | A2000-family SCSI controller | ✅ |
| **GVP Series II** | Needs a **kernel rebuild + an RDB `dummy_handler`** | 🟡 |

The A2090/A2091 interrupt handlers (`a2090intr`, `a2091intr`) appear in the kernel's level-2 autovector table `int2_tbl[]` ✅ — concrete evidence these controllers are wired into the stock kernel. Remember the disk must sit at **SCSI ID 6** (above).

### Graphics

| Card | Notes | Tag |
|---|---|---|
| **Built-in (mono X)** | Default; monochrome X server, reportedly slow | ✅ / 🟡 |
| **A2410 "Lowell"** | TMS34010, 1024×768, native color graphics via TIGA (`olinit -- -tiga`) | ✅ |
| **MNT VA2000 (RTG)** | Via the `va2000-amix` char-68 driver + the `Xrtg` X11R5 server | ✅ |
| Picasso II / Piccolo / Domino / etc. | Added by Gateway! Vol.2 CD; **Zorro II / linear modes only** | 🟡 |

The A2410 is the *officially* supported color option; the VA2000 path is the modern community route. See [X11 & the desktop](../how-it-works/x11-and-desktop.md) and [X11/RTG drivers](../drivers/x11-rtg-drivers.md).

### Networking

| Card | Interface / device | Notes | Tag |
|---|---|---|---|
| **A2065** | `aen0` | Native Ethernet (LANCE); the A3000UX ships with it | ✅ |
| **Ariadne I** | — | Via Gateway! Vol.2 drivers | 🟡 |
| **Hydra AmigaNet** | `hya0` (char 47) | Via the modern `hydra-amix` STREAMS/DLPI driver (NE2000/DP8390) | ✅ |

Hydra's AutoConfig identity is **ID 1053/1 (`0x041D0001`)**, rev 1.2a, with 10Base2 + 10BaseT ✅. See [Networking](../how-it-works/networking.md).

### Serial

| Card | Notes | Tag |
|---|---|---|
| **A2232** | Adds **7 extra RS-232 ports**, managed with `pmadm` | ✅ |

## How to inspect what's actually installed

On a running system, list the device nodes and read their major/minor with `ls -l /dev` (the leading `b`/`c` is the class; the two numbers after the owner/group are major, minor) ✅. To enumerate Zorro II AutoConfig boards from user space, use the community `lszorro` tool, which `mmap()`s `/dev/mem` and decodes the AutoConfig nibble format ✅ — see [the lszorro case study](../drivers/case-studies/lszorro.md) and [Zorro II AutoConfig](../drivers/zorro-autoconfig.md).

## See also

- [The Amix device-driver model](../drivers/driver-model.md) — what major/minor numbers mean and how `cdevsw[]`/`bdevsw[]` work.
- [Supported hardware & requirements](../how-it-works/hardware.md) — the CPU/RAM/SCSI/Zorro rules behind the card list.
- [Building and installing a kernel](../drivers/kernel-build.md) — how a driver claims a major slot in `master.d/kernel.c`.
- [Quirks](../how-it-works/quirks.md) — the hard-coded SCSI ID 6 / ID 4 rules and the 16 MB / Zorro III limits.
- [Versions](versions.md) — which Amix releases these numbers and cards apply to.

## Sources

- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — §5 of [`sources/research-brief.md`](../../sources/research-brief.md) (console char 0, par char 21, fd0 block 16, SCSI disk block 18, minor = addr/LUN/partition; `cdevsw`/`bdevsw` switch tables; `int2_tbl[]` interrupt handlers).
- [`sources/research-brief.md`](../../sources/research-brief.md) §2 (supported machines & expansion cards, Zorro II only, SCSI ID 6 / tape ID 4), §6 (va2000 char 68, hydra char 47/`hya`, AutoConfig IDs).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` (`/dev/rmt/4h`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`).
- Driver repos: [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix), [`asokero/lszorro-amix`](https://github.com/asokero/lszorro-amix), [`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix).
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — A2232, requirements, networking pages (community-reported items: GVP Series II, Ariadne, Gateway! graphics cards).
