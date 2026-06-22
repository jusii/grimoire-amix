---
title: Device & Card Reference
summary: Known /dev major/minor numbers and the hardware cards Amix supports.
status: draft
---

# Device & Card Reference

This is the quick-reference table for two things you keep needing when you work with Amix: the **`/dev` major/minor numbers** the kernel uses, and the **expansion cards** Amix actually supports. The two tables below are the answer; the notes after each table explain the encodings and caveats.

A device node in Amix carries a **major** number (which driver) and a **minor** number (which sub-device). The kernel indexes a per-class switch table by the major and never looks at the file name — see [the device-driver model](../drivers/driver-model.md) for the mechanism. Hardware support is constrained by hard kernel rules (Zorro II only, 68020/030 + MMU + FPU, 4–16 MB Fast RAM, SCSI disk at ID 6 / tape at ID 4) — those are covered in full on [the hardware page](../how-it-works/hardware.md).

Each row carries the same confidence tag the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) uses: ✅ verified (primary source / repo source / reproduced locally), 🟡 community-reported, 🔴 unverified.

## /dev major/minor numbers

The four stock entries below come from the `ls -l /dev` excerpt in the Ditto driver paper (§5 of the brief) ✅. The three community-driver entries (va2000, hydra, z3660eth) come from the modern driver projects ✅ — va2000 and hydra from §6 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), and z3660eth from the amix-z3660net project (see [## Sources](#sources)).

| `/dev` node | Class | Major | Minor | Driver / purpose | Tag |
|---|---|---|---|---|---|
| `/dev/console` | char | **0** | 0 | System console | ✅ |
| `/dev/par` | char | **21** | 0 | Amiga parallel port (output-only Centronics) | ✅ |
| `/dev/fd0` | block | **16** | — | Floppy disk driver | ✅ |
| `/dev/dsk/c0d0s1` | block | **18** | encoded (see below) | SCSI hard-disk driver | ✅ |
| `/dev/va2000` | char | **68** | 0 | MNT VA2000 RTG framebuffer (`asokero/va2000-amix`) | ✅ |
| `/dev/<hya>` | char | **47** | — | Hydra AmigaNet STREAMS/DLPI driver, tag `hya` (`isoriano1968/hydra-amix`) | ✅ |
| `/dev/zen0` | char | **48** | 0 | Z3660 onboard-ethernet STREAMS/DLPI driver, tag `zen` (amix-z3660net) | ✅ |

**Note:** the major number is the **index into `cdevsw[]` (character) or `bdevsw[]` (block)** in `master.d/kernel.c`. A driver "registers" at a major by occupying that slot. There is no global registry that allocates them — community drivers pick a free slot (va2000 took char 68, hydra took char 47, z3660eth took char 48) and patch it into `kernel.c` themselves ✅. See [Building and installing a kernel](../drivers/kernel-build.md) for how a slot is wired in.

### Minor-number encoding for the SCSI disk (major 18)

For the SCSI hard-disk driver, the minor number is **not** a simple index — it packs three fields. The Ditto paper describes them as **SCSI address**, **LUN**, and **partition** ✅; reading the actual `amiga/alien/sd.h` macros (reproduced locally on Amix 2.1c ✅) the three fields are precisely **SCSI target**, **card index**, and **slice/partition**. The paper's example node `/dev/dsk/c0d0s1` is **block major 18, minor 1** = SCSI target 0, card 0, slice 1 ✅.

The block disk driver is **block major 18 / char major 40** ✅. (A separate `gsioctl` passthrough node, `/dev/scsi`, is **char major 11** — that's the raw SCSI-command path, not the block path; see [the A4091 53C710 driver](../drivers/a4091-53c710-driver.md).)

In the `c<addr>d<lun>s<part>` naming you will see on disk:

- `c0d0s1` → controller/SCSI-address 0, drive/LUN 0, slice (partition) 1.
- The boot/root logic uses this directly: root.adf computes `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` ✅.

#### Exact minor decode and the "cN" computation ✅

The minor number is decoded by three macros in `amiga/alien/sd.h` (verified against the running 2.1c kernel source ✅):

```c
#define SDCARDS         2                    /* only two SCSI cards: queue[0], queue[1] */
#define sdunit(dev)     ((dev) >> 0 & 07)    /* SCSI target id   0-7 */
#define sdcard(dev)     ((dev) >> 3 & 01)    /* card index (queue[] slot) -- only 0 or 1 */
#define sdpart(dev)     ((dev) >> 4 & 07)    /* slice / partition 0-7 */
```

So the minor byte is laid out as `(slice << 4) | (card << 3) | target`. The **`cN` in a device name is *computed*, not stored** — there is no "card N" field; the `N` is rebuilt from two fields as `cN = sdcard * 8 + sdunit` (target). Worked examples ✅:

| Device | card (`sdcard`) | target (`sdunit`) | slice (`sdpart`) | minor | `dev_t` |
|---|---|---|---|---|---|
| `c6d0s1` | 0 | 6 | 1 | 22 | `makedevice(18, 22)` |
| `c8d0s0` | 1 | 0 | 0 | 8 | `makedevice(18, 8)` |
| `c14d0s2` | 1 | 6 | 2 | 46 | `makedevice(18, 46)` |

A full `dev_t` packs the major above the minor: **`dev_t = (major << 18) | minor`** ✅. The root device is compiled into the kernel as `ROOTDEV = makedevice(18, 22)` (i.e. `c6d0s1`) via `/stand/CONFIG`, consumed by `amiga/config/unix.c`'s `-DROOTDEV` ✅. The `card` field is the index into the kernel's `queue[SDCARDS]` table, populated in board-base-address order at first root open — see [the A4091 53C710 driver](../drivers/a4091-53c710-driver.md) for how a controller claims a `queue[]` slot.

Two SCSI target rules — one genuinely fixed, one a strong convention ✅:

- **Hard disk: ID 6 by convention.** The installer prompts for the disk target and builds device names from it; ID 6 is the universal default, but it is baked into the `c6d0s…` names in `/etc/vfstab` once installed (so don't change it afterward — see [hardware](../how-it-works/hardware.md#scsi-target-ids)). 🟡
- **Tape must be SCSI ID 4** — the raw tape node is `/dev/rmt/4h` (and `/dev/rmt/4hn` for the no-rewind variant used by the installer's `dd if=/dev/rmt/4hn …`) ✅.

See [Quirks](../how-it-works/quirks.md) for why these IDs are fixed and what breaks if you ignore them.

### The hydra STREAMS driver (char 47)

Hydra is a **STREAMS/DLPI network driver**, which in Amix is a special kind of character driver: it occupies a `cdevsw[]` slot (**47**, tag `hya`) but exposes a `streamtab` rather than ordinary `read()`/`write()` ✅. You do not normally `cat` its `/dev` node; Amix is SVR4.0 (no `ifconfig … plumb`), so you link the interface in with `slink`, then configure it:

```sh
slink addaen /dev/hya0 hya0
ifconfig hya0 <ip> netmask <mask> up -trailers
```

hydra has a boot-time `init_tbl[]` entry (`hydrainit`) that only *probes* for the board; the full init (MAC read, DP8390 programming) is deferred to open (`slink`) time ✅. For the full driver internals see [the Hydra case study](../drivers/case-studies/hydra.md); for the networking stack it plugs into see [Networking](../how-it-works/networking.md).

### The z3660eth STREAMS driver (char 48)

`z3660eth` is the second modern STREAMS/DLPI network driver, for the **Z3660 accelerator's onboard ethernet** — interface **`zen0`**, tag **`zen`**, at **`cdevsw` slot 48** (the free `nostr` slot above hydra's 47 on the stock / A4091 kernel) ✅. Like hydra it is a character driver carrying a `streamtab`, brought up with `slink` (no `ifconfig plumb` on SVR4.0):

```sh
mknod /dev/zen0 c 48 0
slink addaen /dev/zen0 zen0
ifconfig zen0 <ip> netmask <mask> up -trailers
```

Unlike hydra it programs **no NIC chip** — it talks the Z3660 firmware's frame mailbox over MMIO — and it takes **no `init_tbl`/`int2_tbl` entry at all**: it autoconfigs on first `open` and services RX from a **polled `timeout()` callout**, so a GEM-less build kernel boots cleanly and `open()` just returns `ENXIO`. It is **real-hardware-verified** (A4000 + Z3660, 2026-06). See [the Z3660 ethernet driver case study](../drivers/z3660-ethernet-driver.md).

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
| `/dev/scsi` | `gsioctl` raw-SCSI-command passthrough, **char major 11** (`scsi.c:gsioctl`); used by the `gsio` userspace tool to send arbitrary CDBs — *not* the block path (block 18 / char 40) ✅ | ✅ |
| `/dev/rmt/4h`, `/dev/rmt/4hn` | Raw / no-rewind tape at SCSI ID 4 ✅ | ✅ |
| `aen0` | A2065 Ethernet **network interface** (not a `/dev` node — an `ifconfig` name) ✅ | ✅ |
| `hya0` | Hydra network interface name (linked via `slink` from the char-47 driver) ✅ | ✅ |
| `zen0` | Z3660 onboard-ethernet interface name (linked via `slink` from the char-48 driver) ✅ | ✅ |

**Note:** `aen0`, `hya0` and `zen0` are *interface* names managed via `ifconfig`/STREAMS, distinct from `/dev` device-file majors. The underlying A2065 LANCE driver source lives in `aen/` in the kernel tree (both the hydra and z3660eth drivers were modelled on it) ✅.

## Supported expansion cards

Everything **stock** here is **Zorro II only** — Amix's stock drivers just dereference the `autocon()` address, and Zorro II boards (≤ 24-bit, inside the 68030's TT0 transparent-translation window) are directly reachable while Zorro III space is not, by default ✅. That source was never shipped, so the *stock* card set cannot be community-fixed in place ✅. Cards are grouped by function. Tags follow the brief.

> 🔴 **Correction (Zorro III is reachable after all):** "Amix can never drive a Zorro III board" was the long-standing belief, and it is **wrong for a driver that maps the board explicitly.** The A4091-on-Amix project drove the **Zorro III A4091** by page-table-mapping its register block with the kernel's own `sptalloc()` primitive (the board sits in the unmapped `0x40000000–0x7FFFFFFF` TT gap, so a plain pointer deref *does* fail — but `sptalloc()` gets a working kernel VA) 🟡 (reproduced in Amiberry; real-hardware confirmation pending). See [the A4091 53C710 driver](../drivers/a4091-53c710-driver.md). A second, **real-hardware** data point: the **Z3660** accelerator presents a Zorro III AutoConfig identity (`0x144B0001`) and Amix now drives its **onboard ethernet** (`zen0`) via the `z3660eth` driver, `sptalloc`-mapping the firmware register page + frame windows ✅ — though here the windows sit at `0x10000000` (inside TT0), so the mechanism is the firmware mailbox rather than the A4091's TT-gap mapping. See [the Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md). The **same board's onboard "SCSI"** (the PiStorm `piscsi` mailbox, not a 53C710) is driven the same mailbox way — Amix boots **multiuser with root** on it on real hardware (2026-06); see [the Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md).

### SCSI host adapters

| Card | Notes | Tag |
|---|---|---|
| **A3000 on-board SCSI** | The reference controller on the A3000UX (WD33C93); AutoConfig product id `0x0202F003` | ✅ |
| **A2090** | A2000-family SCSI controller; product id `0x02020001` | ✅ |
| **A2091** | A2000-family SCSI controller; product id `0x02020003` | ✅ |
| **A4091** | **Zorro III** SCSI-2 host adapter (NCR/Symbios **53C710**); AutoConfig product id `0x02020054`, phys base `0x40000000`. Not stock — driven by the community [A4091 53C710 driver](../drivers/a4091-53c710-driver.md) 🟡 (Amiberry; real-hardware pending) | 🟡 |
| **Z3660** (accelerator onboard piscsi "SCSI") | **Not a SCSI chip** — the PiStorm `piscsi` register mailbox on the card's Zynq ARM (no 53C710); AutoConfig product id `0x144B0001`, fixed combo base `0x10000000`. Driven by the community [Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md); **works on real hardware (2026-06)** — Amix boots multiuser with **root** on it (`/dev/rdsk/c6d0s1`) | ✅ |
| **GVP Series II** | Needs a **kernel rebuild + an RDB `dummy_handler`** | 🟡 |

The A2090/A2091 interrupt handlers (`a2090intr`, `a2091intr`) appear in the kernel's level-2 autovector table `int2_tbl[]` ✅ — concrete evidence these controllers are wired into the stock kernel. Remember the disk sits at **SCSI ID 6** by convention (above).

The kernel's `sd.c` selector maps these product ids to per-card queue functions in its `scsicard[]` registry; the A4091 work added the row `0x02020054, &a4091queue, "A4091 SCSI"` (verified in `src/kernel-patches/sd.c` ✅). The Z3660 piscsi driver registers the same way, adding `0x144B0001, &z3660queue, "Z3660 SCSI"` — plus a `probe=z3660present` fallback hook (in the kerntools `sd.c` template) for the case where the 2.1 `bootinfo.autocon[]` table misses the board ✅. See [the Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md).

#### Card index when both an A3000 SCSI and an A4091 are present ✅

Because `sd.c` inserts detected controllers **sorted ascending by board base address**, the lower-addressed controller takes `queue[0]` (card 0) and the next takes `queue[1]` (card 1). With both present, the A3000 SCSI (`0xDD0000`) is **card 0** and the A4091 (`0x40000000`) is **card 1** ✅ — so an A4091 disk at target 0, slice 0 is reached as **`/dev/dsk/c8d0s0`** (block major 18, minor 8) and **`/dev/rdsk/c8d0s0`** (char major 40, minor 8): `cN = 1*8 + 0 = 8` ✅. When the A4091 is the **only** controller it becomes card 0 instead, so the same disk is `c0d0s0`-class (and an autoboot disk at target 6 appears as `c6d0s1`-class). Which card index the A4091 lands on therefore depends on what else is in the machine — see [the A4091 53C710 driver](../drivers/a4091-53c710-driver.md) and [the boot process](../how-it-works/boot-process.md) for the rootdev↔card-index consequences.

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
| **Hydra AmigaNet** | `hya0` (char 47) | Via the modern `hydra-amix` STREAMS/DLPI driver (NE2000/DP8390); **works on real hardware (2026-06)** — ARP + ICMP ping verified | ✅ |
| **Z3660** (accelerator onboard ethernet) | `zen0` (char 48) | Via the modern `z3660eth` STREAMS/DLPI driver (Zynq GEM over the firmware mailbox, **not** chip-level); **works on real hardware (2026-06)** — full bidirectional TCP/IP, telnet/ftp | ✅ |

Hydra's AutoConfig identity is **ID 2121/1 (`0x08490001`)**, rev 1.2a, with 10Base2 + 10BaseT ✅. The Z3660 accelerator's AutoConfig id is **`0x144B0001`** (combo base `0x10000000` on AGA), station MAC `00:80:51:01:02:03` observed on the wire ✅. See [Networking](../how-it-works/networking.md).

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
- [Quirks](../how-it-works/quirks.md) — the SCSI ID rules (tape hard-coded at ID 4, disk ID 6 by convention) and the 16 MB / Zorro III limits.
- [Versions](versions.md) — which Amix releases these numbers and cards apply to.

## Sources

- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — §5 of [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) (console char 0, par char 21, fd0 block 16, SCSI disk block 18, minor = addr/LUN/partition; `cdevsw`/`bdevsw` switch tables; `int2_tbl[]` interrupt handlers).
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §2 (supported machines & expansion cards, Zorro II only, SCSI ID 6 / tape ID 4), §6 (va2000 char 68, hydra char 47/`hya`, AutoConfig IDs).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` (`/dev/rmt/4h`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`).
- Driver repos: [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix), [`asokero/lszorro-amix`](https://github.com/asokero/lszorro-amix), [`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix).
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — A2232, requirements, networking pages (community-reported items: GVP Series II, Ariadne, Gateway! graphics cards).
- The A4091-on-Amix project — `NOTES.md` §3, §8, §12–§15 (lab notebook, reproduced locally ✅) and `src/`/`tools/`. The minor decode (`sdunit`/`sdcard`/`sdpart`, `SDCARDS`), block major 18 / char major 40, and `dev_t = (major<<18)|minor` are verified against `amiga/alien/sd.h`; the `/dev/scsi` char major 11 `gsioctl` path against `src/gsio.c`.
- `src/kernel-patches/sd.c` — the `0x02020054, &a4091queue, "A4091 SCSI"` `scsicard[]` row and the base-address-sorted `queue[]` insertion.
- `src/a4091-wr.c` — `A4091_PROD = 0x02020054`, phys base `0x40000000`; the `sptalloc()`-mapped 53C710 driver.
- a4091.device open-source project: [`A4091/a4091-software`](https://github.com/A4091/a4091-software) (A4091 ROM + SCRIPTS assembler).
- The amix-z3660net project — the native `z3660eth` STREAMS/DLPI driver (`src/z3660eth.{c,h}`, `driver.conf`'s `net z3660eth … 48 zen` stanza), **validated on a real A4000 + Z3660, 2026-06-21** ✅: `cdevsw` char major **48**, tag `zen` / interface `zen0`, AutoConfig `0x144B0001`, combo base `0x10000000`, MAC `00:80:51:01:02:03`. See [the Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md).
- The amix-z3660scsi project @ `8ea1605` — the native `z3660` piscsi **block** driver (`src/z3660.c`, `src/kernel-patches/sd.c`, `driver.conf`'s `0x144B0001 z3660queue "Z3660 SCSI" z3660.c probe=z3660present` stanza), **validated on a real A4000 + Z3660, 2026-06-12/13** ✅: registers in `sd.c`'s `scsicard[]` (block major 18 / char major 40), root disk `/dev/rdsk/c6d0s1`, AutoConfig `0x144B0001`, fixed combo base `0x10000000`. See [the Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md).
