---
title: Glossary
summary: Definitions of Amix/Amiga/SVR4 terms used across the docs.
status: draft
---

# Glossary

Concise definitions of the Amix-, Amiga-, and SVR4-specific terms that recur across these docs.
Each entry is one or two lines and links to the page that covers the term in depth. Confidence
tags (✅ verified, 🟡 community-reported, 🔴 unverified/disputed) carry over from the
[research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) — they are *not* upgraded here.

Entries are alphabetical. Acronyms sort by their letters (so "RDB" sits under R, "s5" under S).

## 3B2

AT&T's WE32x00-based minicomputer line whose SVR4 codebase Commodore actually ported, for
licensing-cost reasons, rather than starting from a pre-existing 68k port ✅. The 3B2 lineage is
the suspected reason Amix defaults to the [s5](#s5) filesystem at install even though everyone uses
[UFS](#ufs) 🟡. See [How Amix works: overview](overview.md).

## /usr/sys

The kernel build tree. Amix ships the kernel as **compiled object libraries** under `/usr/sys`; you
relink `/unix` here ✅. Some `.o` files come with source, others are object-only. Driver
sources/objects are dropped into a subdir under `/usr/sys` and added to that dir's makefile ✅. See
[the kernel build process](../drivers/kernel-build.md) and the [driver model](../drivers/driver-model.md).

## AUTOCONFIG

The Amiga bus protocol that assigns [Zorro II](#zorro-ii--iii) board addresses at every reset ✅.
Amix reads the assigned addresses through the kernel's [`autocon()`](#autocon) interface; Zorro II
only ✅. The on-disk nibble format (two nibbles per logical byte, upper nibble D15–D12, most fields
ones-complement) is decoded by the `lszorro` scanner ✅. See
[Zorro AutoConfig for driver authors](../drivers/zorro-autoconfig.md).

## `autocon()`

The Amix-specific kernel call a driver uses to discover its Zorro II board:
`autocon(product_id, dev, &board, &dummy)` 🟡 (repo-confirmed). Used by the
[va2000](../drivers/case-studies/va2000.md) and [hydra](../drivers/case-studies/hydra.md) drivers.
See [Zorro AutoConfig](../drivers/zorro-autoconfig.md). Distinct from the boot-time init tables
[`init_tbl[]`/`io_init[]`](#kernelc) declared in [`kernel.c`](#kernelc).

## Amix

Commodore's port of **AT&T UNIX System V Release 4 (SVR4)** to the 68030 Amiga; kernel platform
string `m68k-cbm-sysv4` ✅. Monolithic kernel, **no AmigaOS compatibility layer**, does not touch
the Amiga custom chips — it treats the machine as a generic 68030 Unix workstation ✅. See the
[overview](overview.md).

## cdevsw / bdevsw

The two kernel **device switch tables**, declared in `conf.h` and instantiated in
[`kernel.c`](#kernelc), indexed by [major number](#major--minor) ✅. `cdevsw[]` is for character
devices (`d_open/d_close/d_read/d_write/d_ioctl/d_mmap/d_segmap/d_poll/d_xpoll/d_xhalt`, plus
`d_ttys`, `d_str`, `d_flag`); `bdevsw[]` is for block devices
(`d_open/d_close/d_strategy/d_print/d_size/d_xpoll/d_xhalt/d_flag`) ✅. Unused slots get `nodev`,
`notty`, `nostr`, or `nullflag`. See the [driver model](../drivers/driver-model.md).

## clist

The SVR4 character-list queue used to buffer slow byte-stream I/O; manipulated with `getc()`/`putc()`
✅. The parallel-port driver (`par.c`) in the Ditto paper uses a clist for its output queue ✅. See
[writing a char driver](../drivers/writing-a-char-driver.md).

## DLPI

**Data Link Provider Interface** — the SVR4 STREAMS service interface a link-layer network driver
exposes (messages `DL_INFO_REQ`, `DL_BIND_REQ`, `DL_UNITDATA_REQ`) ✅. The
[hydra](../drivers/case-studies/hydra.md) NE2000 driver is a DLPI STREAMS driver registered at
[`cdevsw`](#cdevsw--bdevsw) slot 47 ✅. See [writing a STREAMS driver](../drivers/writing-a-streams-driver.md)
and [networking](networking.md).

## elf2brel

The converter in the kernel `stand/` directory that turns a cross-compiled ELF kernel into Amix's
boot ("brel") format ✅. Used in the [hydra](../drivers/case-studies/hydra.md) cross-build flow:
`m68k-amix-gcc` → ELF → `elf2brel` → `make oldboot KERNEL=…` ✅. See the
[toolchain](../drivers/toolchain.md).

## HAT

**Hardware Address Translation** — the SVR4 MMU abstraction layer ✅. Amix uses the full 68030 MMU
through HAT ✅; the install kernel even carries the panic string
`hat_vtokp_prot: user addr in kernel space` ✅. The MMU requirement is why Amix needs MMU emulation
in WinUAE and cannot run on MMU-less CPUs or the 68040 (whose MMU the kernel predates) ✅. See the
[kernel architecture](kernel-architecture.md) and [hardware](hardware.md).

## kernel.c

The kernel configuration file (`master.d/kernel.c`), provided in **source**, that holds the device
switch tables ([`cdevsw[]`/`bdevsw[]`](#cdevsw--bdevsw)), the interrupt tables (`int2_tbl[]`, a
level-6 table), and the boot-time init table (`init_tbl[]`/`io_init[]`) ✅. Adding a driver means
editing `kernel.c` to add the entries, then rebuilding ✅. The full original file is **not** publicly
archived; its schema is inferred from the Ditto paper plus the modern repos 🔴. See the
[driver model](../drivers/driver-model.md) and [kernel build](../drivers/kernel-build.md).

## m68k-cbm-sysv4

The Amix kernel platform / configure triple string ✅. GNU autodetect on Amix instead reports
`m68k-unknown-sysv4`, so cross-toolchains must set the triple explicitly ✅. See the
[overview](overview.md) and [toolchain](../drivers/toolchain.md).

## major / minor

The two numbers that identify a [`/dev`](../reference/device-list.md) node: the **major** selects the
driver (an index into [`cdevsw[]`/`bdevsw[]`](#cdevsw--bdevsw)), the **minor** selects the sub-device;
the kernel knows only the numbers, not the name ✅. Examples from the Ditto paper: `/dev/console` =
char major 0 minor 0; `/dev/dsk/c0d0s1` = block major 18 minor 1 (SCSI driver); `/dev/fd0` = block
major 16; `/dev/par` = char major 21 ✅. You create a node with `mknod /dev/<name> c|b <major> <minor>`
✅. See the [device list](../reference/device-list.md) and [driver model](../drivers/driver-model.md).

## miniroot

The minimal UFS root filesystem on the install **root floppy** (`amix_21_root.adf`) that mounts
during installation and runs the installer ELF binaries and shell scripts ✅. It carries the
partition/install logic, the installer programs (cpio, fsck, dd, amixpkg, …), and
[`viper_kludge`](#viper_kludge) ✅. See the [root floppy anatomy](../boot-disks/anatomy-root-adf.md)
and the [install walkthrough](../getting-started/install-walkthrough.md).

## pkgadd

The SVR4 package installer (with siblings `pkgmk`, `pkgproto`, `pkgtrans`) used to install software
on Amix ✅. The install scripts drive it through the `amixpkg` wrapper
(`amixpkg -i -m -d -r /mnt -y standard`), which is widely reported as flaky/"broken" 🟡; `pkgproto`
also omits symlinks 🟡. Michael Parson's **AmixBP** re-bundles 40+ `.pkg`s on amigaunix.com/downloads 🟡. See the
[kernel architecture](kernel-architecture.md) and [toolchain](../drivers/toolchain.md).

## RDB

**Rigid Disk Block** — the Amiga's on-disk partition scheme, which Amix uses for its hard disk ✅.
The default install lays out root (`/`), swap, a **2 MB boot/bootstrap partition** (`BOOTSIZE=2` MB →
`BOOTLEN = BOOTSIZE*2048` blocks), and data ✅; keep partitions ≲1 GB 🟡. The exact RDB partition
type IDs Amix uses are not documented 🔴. See [filesystems and disks](filesystems-and-disks.md).

## relocunix / rdbunix

The relinked Amix kernel image. The 1990 Ditto paper calls it **`rdbunix`**; modern 2.1 systems and
repos call it **`relocunix`** — a historical rename (verify per version 🟡). After building you
`cp relocunix /stand`, then `make bootpart KERNEL=relocunix` writes it to the boot partition ✅. See
the [kernel build process](../drivers/kernel-build.md).

## RTG

**ReTargetable Graphics** — driving a third-party graphics card instead of the Amiga's built-in
display. On Amix this is the [va2000](../drivers/case-studies/va2000.md) char framebuffer driver
(`/dev/va2000`, char major 68) plus the [xrtg](../drivers/case-studies/xrtg.md) X11R5 server `Xrtg`
✅. See [X11 RTG drivers](../drivers/x11-rtg-drivers.md) and
[X11 and the desktop](x11-and-desktop.md).

## s5

The System V (s5) filesystem — the **default but not recommended** choice offered by the Amix
installer ✅; the recommendation (and the script default `ANS="ufs"`) is [UFS](#ufs) ✅. The s5
default is likely a [3B2](#3b2)-lineage artifact 🟡. See [filesystems and disks](filesystems-and-disks.md).

## spl / splN

The SVR4 interrupt-priority masking primitives a driver uses to protect critical sections
(`spl2()`/`splx()`, etc.) ✅. The Ditto `par` driver wraps its critical regions with `splpar()`,
which equals `spl2()` ✅. See [writing a char driver](../drivers/writing-a-char-driver.md).

## STREAMS

The SVR4 modular I/O framework used for networking; a STREAMS driver is a distinct third driver
class (a special character driver carrying a `streamtab`, the `d_str` field in
[`cdevsw`](#cdevsw--bdevsw)) ✅. Amix networking (TCP/IP, [DLPI](#dlpi)) is STREAMS-based ✅. See
[writing a STREAMS driver](../drivers/writing-a-streams-driver.md) and [networking](networking.md).

## Superkickstart

The A3000UX bootstrap ROM ("Superkickstart 1.4") that chooses what to boot at power-on: hold the
**right mouse button** to load an AmigaOS Kickstart, or by default boot Amix from SCSI ✅. See the
[boot process](boot-process.md) and [hardware](hardware.md).

## SVR4

**AT&T UNIX System V Release 4** — the operating system Amix *is* a port of ✅. Brings STREAMS
networking, TLI plus BSD sockets, POSIX.1, `init`/`/etc/inittab`/run levels, and the
[`pkgadd`](#pkgadd) packaging tools ✅. See the [overview](overview.md) and
[kernel architecture](kernel-architecture.md).

## UFS

The Berkeley Fast File System (UFS), the **recommended** Amix filesystem; the installer scripts
default to it (`ANS="ufs"`) ✅. The install [miniroot](#miniroot) itself is a UFS filesystem ✅.
Contrast [s5](#s5). See [filesystems and disks](filesystems-and-disks.md).

## viper_kludge

A patch (by Frank "Crash" Edwards) shipped on the [root floppy](../boot-disks/anatomy-root-adf.md)
that pokes kernel memory so **non-standard tape drives** (e.g. the Archive Viper 2150S) work during
install ✅. Its own README warns it is **incompatible** with the A3070/Caliper/Wangtek/Sankyo
drives ✅. See the [install walkthrough](../getting-started/install-walkthrough.md).

## Zorro II / III

The Amiga expansion bus. Amix supports **Zorro II only**: its memory-mapping layer cannot address
Zorro III space, and that source was never shipped, so the limit can't be community-fixed ✅. Board
addresses are assigned by [AUTOCONFIG](#autoconfig) at reset ✅. See [hardware](hardware.md),
[Zorro AutoConfig](../drivers/zorro-autoconfig.md), and the [quirks list](quirks.md).

## See also

- [How Amix works: overview](overview.md) — the one-page mental model that ties these terms together
- [Kernel architecture](kernel-architecture.md) — where the switch tables, HAT, and STREAMS live
- [The device-driver model](../drivers/driver-model.md) — majors/minors, `cdevsw`/`bdevsw`, adding a driver
- [Reference: device list](../reference/device-list.md) — concrete major/minor assignments

## Sources

- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) — sections 1, 2, 3, 4, 5, 6, 7, 9, 11 (the grounding source of every definition above)
- Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — driver model, `cdevsw`/`bdevsw`, majors/minors, `spl`/clist, `rdbunix` (the Ditto paper)
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — miniroot, UFS, `viper_kludge`, install/partition logic, `relocunix`/`make bootpart`
- `amix_21_boot.adf` analysis via `tools/inspect-adf.sh` — compressed kernel, HAT panic string
- Driver repos: [asokero/va2000-amix](https://github.com/asokero/va2000-amix), [asokero/xrtg-amix](https://github.com/asokero/xrtg-amix), [asokero/lszorro-amix](https://github.com/asokero/lszorro-amix), [isoriano1968/hydra-amix](https://github.com/isoriano1968/hydra-amix) — `autocon()`, RTG/`/dev/va2000`, DLPI/STREAMS, `elf2brel`, `m68k-cbm-sysv4`
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — community-reported (🟡) details: `s5`-vs-UFS default rationale, `amixpkg` flakiness, AmixBP
