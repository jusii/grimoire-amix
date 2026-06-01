---
title: Amix on Amiberry (status)
summary: What works and what's missing for Amix under Amiberry — the boot floppy loads, but the SCSI/tape install stage is unsupported.
status: draft
---

# Amix on Amiberry (status)

**Partial.** The Amix **boot floppy loads and runs in [Amiberry](https://github.com/BlitterStudio/amiberry)** — verified reaching the install kernel's `Insert floppy disk 2 (root file system)` prompt ✅. What is missing is the **A3000 on-board SCSI controller** and **SCSI tape** emulation the *install* needs (to read the distribution tape at ID 4 and write the RDB disk at ID 6) — so a full install cannot complete on Amiberry as of issue [#1376](https://github.com/BlitterStudio/amiberry/issues/1376). For an actual install, **use [WinUAE](emulation-winuae.md) or [FS-UAE](emulation-fs-uae.md)**, which emulate the A3000 SCSI + tape. 🟡

This page documents the current state so you don't burn time. If you have new information (a working config, a fixed build), it belongs here.

## Current status: boots, can't install

| Question | Answer | Tag |
|---|---|---|
| Does the boot floppy / install kernel load on Amiberry? | **Yes** — reaches the `Insert floppy disk 2 (root file system)` prompt | ✅ (observed) |
| Can a full install complete on Amiberry? | **No** — the SCSI-disk / tape stage is unsupported | 🟡 |
| Tracking issue | [BlitterStudio/amiberry #1376](https://github.com/BlitterStudio/amiberry/issues/1376), **closed as an enhancement request** (not a bug fix) | 🟡 |
| Root cause | Missing **A3000 SCSI controller** + **SCSI tape** emulation | 🟡 |
| Recommended emulator for installing | [WinUAE](emulation-winuae.md) (reference target) or [FS-UAE](emulation-fs-uae.md) | 🟡 |

## Why it fails

Amix is unusually demanding about its storage hardware, and the requirements are baked into both the kernel and the installer — they are not configurable knobs:

- The SCSI **hard disk must be at ID 6** and the **tape must be at ID 4** ✅ — these IDs are hard-coded in the kernel and in the install scripts on the root floppy (e.g. `/dev/rmt/4h` for the tape, and `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` for the boot partition). See [the root.adf anatomy page](../boot-disks/anatomy-root-adf.md) and [the disk/filesystem internals](../how-it-works/filesystems-and-disks.md) for how this is wired up.
- The standard install **streams the distribution from a SCSI tape at ID 4** ✅ (`dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`), so an emulator must present a working SCSI tape device, not just a hard disk.

WinUAE and FS-UAE emulate the **A3000's on-board SCSI** well enough to satisfy the kernel and to attach both a hardfile (the RDB disk at ID 6) and a tape image (at ID 4). Amiberry, as of issue [#1376](https://github.com/BlitterStudio/amiberry/issues/1376), does **not** provide equivalent A3000 SCSI + tape emulation. The floppy-loaded **install kernel still comes up** (it doesn't need SCSI to reach the root-disk prompt) ✅, but the install can't proceed once it needs the SCSI disk/tape. 🟡

**Note:** the issue being **closed as an enhancement** means this is treated as a missing feature in Amiberry, not a regression that will be quickly patched. Do not assume a near-term fix.

## What would need to change

For Amix to run on Amiberry, the emulator would need to grow the same A3000 storage support the other UAE-family emulators already have 🟡:

- A3000 on-board SCSI controller emulation that the Amix kernel recognizes.
- A SCSI **tape** device that can be addressed as **ID 4** (`/dev/rmt/4h`) so the installer's tape pipeline works — or a documented tape-free install path (some exist on comp.unix.amiga: `dd` a cpio image to swap from Linux/AmigaDOS, then extract with `cpio`) 🟡 that sidesteps the tape entirely.
- A disk attachable as **ID 6** with the Amiga **Rigid Disk Block (RDB)** scheme.

The minimum-machine requirements are otherwise the same as for any Amix emulation target: a **68030 with a real MMU** plus a **68881/68882 FPU**, **4–16 MB Fast RAM** (16 MB hard ceiling), and an **A3000 Kickstart ROM** ✅. See [the hardware page](../how-it-works/hardware.md) for the full requirement list and [the WinUAE config table](emulation-winuae.md) for the concrete settings that *are* known to work.

## Use this instead

Until Amiberry gains A3000 SCSI/tape emulation, target one of these:

- **[WinUAE](emulation-winuae.md)** — the reference emulator. MMU emulation since 2.6.0 (2013); the page has the mandatory CPU/MMU/JIT/SCSI-ID config table.
- **[FS-UAE](emulation-fs-uae.md)** — verified against FS-UAE 3.1.66 on amigaunix.com 🟡; cross-platform, config-file driven.

Both attach the hardfile at `scsi6` (RDB) and a tape image at SCSI ID 4, which is what the installer expects. Start from [the install walkthrough](install-walkthrough.md) once you have a working emulator.

## See also
- [Amix on WinUAE](emulation-winuae.md) — the recommended, reference-grade setup.
- [Amix on FS-UAE](emulation-fs-uae.md) — the cross-platform alternative that also works.
- [Hardware and requirements](../how-it-works/hardware.md) — why the SCSI IDs and RAM ceiling are fixed.
- [Install walkthrough](install-walkthrough.md) — the end-to-end install once you have a working emulator.

## Sources
- First-hand observation (2026-06, Amiberry): a rebuilt Amix boot floppy loads the install kernel and reaches the `Insert floppy disk 2 (root file system)` prompt; the SCSI/tape install stage is where Amiberry's missing A3000 storage emulation (issue #1376) bites. Recorded in research brief §8.
- Research brief §2 (Hardware): SCSI hard disk must be ID 6, tape must be ID 4 (hard-coded in kernel and install scripts; `/dev/rmt/4h`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`).
- Research brief §9 (Installation flow): distribution streamed from tape at SCSI ID 4 via `dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`; tape-free install notes on comp.unix.amiga.
- [BlitterStudio/amiberry issue #1376](https://github.com/BlitterStudio/amiberry/issues/1376) (closed as enhancement).
- [BlitterStudio/amiberry](https://github.com/BlitterStudio/amiberry) project repository.
