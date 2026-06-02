---
title: Amix on Amiberry
summary: Amiberry 8.x fully runs and installs Amix — its A3000 on-board SCSI emulates a disk at ID 6 and a tape at ID 4 (the two devices the installer needs), plus real A2065 networking.
status: draft
---

# Amix on Amiberry

**Amiberry 8.x is a full Amix target — you can both install *and* run Amix on it.** ✅ Amiberry's
A3000 on-board SCSI controller emulates a hard disk at **SCSI ID 6** and a **tape at SCSI ID 4** — the
two devices the Amix kernel and installer require. First-hand on Amiberry **8.1.6** (2026-06): an
installed Amix 2.1 boots to login from the A3000 SCSI hardfile ✅, and the GUI's *Hard drives / CD*
page shows both devices mounted — **`A3000 SCSI:6 → HDF`** and **`A3000 SCSI:4 → TAPE`** — with a
dedicated **"Add Tape Drive…"** button ✅.

This **supersedes** the long-standing "Amix can't install on Amiberry" status: the feature request
[BlitterStudio/amiberry #1376](https://github.com/BlitterStudio/amiberry/issues/1376) ("Add A3000 SCSI
controller and tape support for Amiga UNIX") has been **implemented** in current Amiberry. Older 5.7.x
/ 7.x builds genuinely lacked it (and reportedly crashed with an A3000 config); **use 8.x**. 🟡 (older
versions)

## What works (Amiberry 8.1.6)

| Capability | Status | Tag |
|---|---|---|
| Boot floppy / install kernel loads | Yes | ✅ |
| A3000 SCSI **disk** at ID 6 (`scsi6_a3000`, RDB hardfile) | Yes | ✅ (GUI + booted) |
| A3000 SCSI **tape** at ID 4 (`scsi4_a3000`) | Yes — "Add Tape Drive…" in the GUI | ✅ (GUI) |
| Full **tape install** completes | Yes — confirmed by a live from-tape install | ✅ |
| Run a **pre-installed** Amix | Yes — boots to login from the HDF | ✅ (first-hand) |
| Real **A2065 networking** (LAN host) | Yes — TAP/PCAP backend in 8.x | ✅ ([LAN guide](networking-on-the-lan.md)) |

## The storage IDs that matter (and how to set them)

Amix hard-codes its storage hardware — these are not configurable knobs:

- The hard disk **must be at SCSI ID 6** and the tape **at ID 4** ✅ — baked into the kernel and the
  install scripts (`/dev/rmt/4h` for the tape; `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` for the boot
  partition). See [root.adf anatomy](../boot-disks/anatomy-root-adf.md) and
  [filesystems & disks](../how-it-works/filesystems-and-disks.md).
- The standard install **streams the distribution from the tape at ID 4** ✅
  (`dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`).

In Amiberry, set these in the machine `.uae` (or via **Hard drives/CD → Add Hardfile / Add Tape Drive**):

```ini
scsi_a3000=true
hardfile2=rw,DH0:/path/to/Amix.hdf,32,1,2,512,0,,scsi6_a3000
uaehf1=tape0,rw,:/path/to/amix_21_tape.zip,0,0,0,512,0,,scsi4_a3000,SCSI1
```

## Minimum machine config

Same as any Amix target ✅ — and the CPU/MMU settings are mandatory or it won't boot:

- **68030 with MMU on** (`cpu_model=68030`, `mmu_model=68030`) + a **68881/68882 FPU**
- **JIT off** (`cachesize=0`) and **"More compatible" off** (`cpu_compatible=false`)
- **4–16 MB Fast RAM** (16 MB hard ceiling) and an **A3000 Kickstart 2.04** ROM
- `scsi_a3000=true`

See [hardware & requirements](../how-it-works/hardware.md) and the [WinUAE config table](emulation-winuae.md)
for the shared requirement list.

## Networking

Amiberry 8.x added a real **A2065** Ethernet backend (TAP / PCAP), so an Amiberry-hosted Amix can be a
genuine host on your LAN — static IP, gateway, DNS, internet. Full verified recipe:
**[Putting Amix on your real LAN](networking-on-the-lan.md)**.

## See also
- [`tools/amix-amiberry.uae`](../../tools/amix-amiberry.uae) — a complete, ready-to-edit working Amiberry config (A3000 / KS 2.04 / 68030+MMU / SCSI disk@6 + tape@4 / A2065).
- [Install walkthrough](install-walkthrough.md) — the end-to-end tape install (works on Amiberry 8.x, WinUAE, and FS-UAE).
- [Amix on WinUAE](emulation-winuae.md) / [Amix on FS-UAE](emulation-fs-uae.md) — the other UAE-family targets.
- [Hardware & requirements](../how-it-works/hardware.md) — why the SCSI IDs and RAM ceiling are fixed.
- [Putting Amix on your real LAN](networking-on-the-lan.md) — A2065 networking on Amiberry.

## Sources
- First-hand, 2026-06, Amiberry **8.1.6**: an installed Amix 2.1 boots to login from the `scsi6_a3000` hardfile; the GUI *Hard drives/CD* page shows `A3000 SCSI:6 → HDF` and `A3000 SCSI:4 → TAPE` mounted (RW) with an "Add Tape Drive…" button; a full from-tape install completes on Amiberry 8.1.6 (confirmed first-hand, 2026-06). Working config: `scsi_a3000=true`, `hardfile2=…,scsi6_a3000`, `uaehf1=tape0,…,scsi4_a3000`.
- [BlitterStudio/amiberry #1376](https://github.com/BlitterStudio/amiberry/issues/1376) — "Add A3000 SCSI controller and tape support for amix" (the requested support is present in 8.x).
- Research brief §2 (SCSI disk ID 6 / tape ID 4 hard-coding) and §9 (`dd … /dev/rmt/4hn | cpio` install flow).
- [BlitterStudio/amiberry](https://github.com/BlitterStudio/amiberry) project repository.
