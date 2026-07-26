---
title: Running Amix in FS-UAE
summary: A verified FS-UAE config file for booting and installing Amix, line by line, mapped to the equivalent WinUAE settings.
status: draft
---

# Running Amix in FS-UAE

FS-UAE can run Amix, and a working configuration has been reported against FS-UAE **3.1.66** 🟡. The whole config fits in a handful of `key = value` lines: emulate an **A3000**, attach the boot floppy, and attach an RDB hardfile on the on-board SCSI controller at **ID 6**. This page gives the verified snippet, explains each line, and maps every line back to the corresponding setting in [Running Amix in WinUAE](emulation-winuae.md) so you can move a setup between the two emulators.

FS-UAE shares the WinUAE emulation core, so the *same* hard rules apply: 68030 + MMU, no JIT, 68882 FPU, the hard disk on **SCSI ID 6**, the tape on **SCSI ID 4**, and **≤ 16 MB** of Fast RAM. If a setting below looks under-specified, it is because FS-UAE's A3000 model preset already supplies the matching CPU/MMU/ROM defaults that WinUAE makes you set by hand.

## The verified config

Save this as e.g. `amix.fs-uae` and launch with `fs-uae amix.fs-uae` 🟡:

```ini
amiga_model = A3000
floppy_drive_0 = amix_2.1_boot.adf
hard_drive_0 = a3000ux.hdf
hard_drive_0_controller = scsi6
hard_drive_0_type = rdb
motherboard_ram = 16384
```

**Note:** the image filenames (`amix_2.1_boot.adf`, `a3000ux.hdf`) are yours to supply — the ADFs are proprietary Commodore material and are not redistributed here. See [where to get the disk images](#where-to-get-the-disk-images) below. The `.hdf` is a hardfile you create yourself (a blank RDB disk that the installer partitions).

## Line-by-line, mapped to WinUAE

Each FS-UAE line and what it does, with the equivalent in the [WinUAE config table](emulation-winuae.md):

| FS-UAE line | What it sets | WinUAE equivalent |
|---|---|---|
| `amiga_model = A3000` | Selects the A3000 machine model: 68030 CPU + on-board SCSI + A3000 Kickstart ROM, all in one preset ✅ (A3000 is the reference machine). | CPU = **68030**, ROM = **A3000 KS 2.04 (rev 37.175)** or **3.1 (40.68)**, plus the on-board SCSI controller — set individually. |
| *(implied by `A3000`)* | MMU enabled, FPU present. Amix **requires** a real MMU and a 68881/68882 FPU ✅. | **MMU = ON**, **FPU = 68882**, **JIT = OFF** (JIT causes kernel panics ✅). Set these explicitly in WinUAE; on the A3000 model FS-UAE wires the MMU/FPU in for you. Verify JIT stays off. |
| `floppy_drive_0 = amix_2.1_boot.adf` | Inserts the Amix boot floppy in DF0; the Superkickstart ROM boots it and decompresses the install kernel ✅. | **DF0 = `amix_2.1_boot.adf`**. |
| `hard_drive_0 = a3000ux.hdf` | Attaches your RDB hardfile as the system disk. | Hardfile (RDB), roughly **450–900 MB** 🟡. |
| `hard_drive_0_controller = scsi6` | Puts that disk on the SCSI bus at **ID 6** — the conventional Amix disk target (the installer prompts for it, but everything assumes 6) ✅. | **SCSI ID 6 = hardfile** (convention; see [hardware](../how-it-works/hardware.md#scsi-target-ids)). |
| `hard_drive_0_type = rdb` | Tells FS-UAE the image is partitioned with the Amiga **Rigid Disk Block** scheme (not a single auto-mounted AmigaDOS partition) ✅. | Hardfile type / geometry = **RDB**. |
| `motherboard_ram = 16384` | 16384 KB = **16 MB** of Fast RAM — the kernel's hard ceiling ✅. Going over mis-maps the SCSI drive ✅. | **Fast RAM ≤ 16 MB**. |

### Settings FS-UAE supplies that the table doesn't name

WinUAE's reference table lists several values that are **not** explicit lines in the snippet because the `A3000` model preset already provides sensible equivalents. Carry them across mentally when comparing the two:

- **Chip RAM** — WinUAE uses 2 MB; the A3000 model defaults are fine for Amix (Amix ignores the custom chips and treats the machine as a generic 68030 workstation ✅).
- **"More Compatible" = OFF / "Wait for Blitter" = ON** 🟡 — these are WinUAE-specific CPU-accuracy toggles. With "More Compatible" left **on**, WinUAE boots freeze with `sort: fatal: line too long` 🟡. FS-UAE exposes accuracy via different options (e.g. `accuracy`); if you hit an early-boot freeze, lowering CPU accuracy is the analogous knob to try 🟡.

## Adding the tape drive (for a from-scratch install)

The config above is enough to **boot** an already-installed disk. To run the installer you also need the distribution tape on **SCSI ID 4** — the installer reads it with `dd if=/dev/rmt/4hn ... | cpio` ✅. Add a second drive on the matching controller ID:

```ini
hard_drive_1 = a3000ux-tape.hdf
hard_drive_1_controller = scsi4
```

**Note:** these IDs are shared with WinUAE — **disk = ID 6, tape = ID 4** ✅. The **tape ID 4 is hard-coded** (the scripts reference the literal `/dev/rmt/4h` and look nowhere else); the **disk ID 6 is convention** (the installer prompts for it and builds `BPART` from a `$SCSI` variable). Use 6 anyway — the ID is baked into the installed system's device names, so it's the path of least resistance. See [hardware](../how-it-works/hardware.md#scsi-target-ids).

For the full install sequence (boot floppy → root floppy miniroot → stream the distribution from tape → build the kernel and write the boot partition → apply the patch disk), see the [install walkthrough](install-walkthrough.md). A tape-free install (writing a `cpio` image where the installer expects it) is reported on comp.unix.amiga 🟡 and is also covered there.

## Where to get the disk images

The boot/root/patch floppies and the scanned manuals are **proprietary Commodore material** treated as abandonware; this project does not redistribute them. Obtain `amix_2.1_boot.adf` (and the root and patch ADFs) from [amigaunix.com](https://www.amigaunix.com/doku.php/home) or the [Internet Archive Amix collection](https://archive.org/details/commodore-amiga-operating-systems-amix), and verify them against `sources/CHECKSUMS.txt`. The `a3000ux.hdf` system disk is a **blank RDB hardfile you create yourself**; the Amix installer partitions and formats it.

## Known limits

- The config is **community-verified against FS-UAE 3.1.66** 🟡, not primary-verified. Other FS-UAE versions may need accuracy tweaks.
- If you prefer the reference emulator, use [WinUAE](emulation-winuae.md), which has had the MMU emulation Amix needs since **2.6.0 (2013)** ✅.
- **Amiberry 8.x now works** for Amix too — its A3000 on-board SCSI emulates the disk (ID 6) and tape (ID 4), so it both installs and runs Amix (BlitterStudio/amiberry issue #1376 — implemented; older builds lacked it) ✅; see [Amix on Amiberry](emulation-amiberry.md). **QEMU** still has no working Amiga-SCSI/hardware setup 🟡.

## See also
- [Running Amix in WinUAE](emulation-winuae.md) — the reference emulator and the full mandatory settings table.
- [Install walkthrough](install-walkthrough.md) — the end-to-end boot/root/tape/patch install flow.
- [Running Amix in Amiberry](emulation-amiberry.md) — Amiberry 8.x runs and installs Amix too.
- [Hardware and requirements](../how-it-works/hardware.md) — the SCSI-ID rules and 16 MB ceiling these settings exist to satisfy.
- [The Amix RAM ceiling](../how-it-works/ram-ceiling.md) — what happens far *past* the 16 MB rule, and why it is silent.
- [Quirks](../how-it-works/quirks.md) — the hard-coded limits (ID 6 / ID 4, 16 MB, no JIT) summarized.

## Sources
- Master research brief, §8 "Emulation" (FS-UAE snippet verified vs FS-UAE 3.1.66; WinUAE reference table) and §2 "Hardware & requirements" (SCSI ID 6 disk / ID 4 tape; 16 MB Fast RAM ceiling; MMU + FPU mandatory).
- Master research brief, §9 "Installation flow" (tape at SCSI ID 4; `dd if=/dev/rmt/4hn | cpio`; `BPART`/`BOOTPART` from SCSI ID in the root.adf scripts).
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) (FS-UAE configuration; install media).
- [Internet Archive — Commodore Amiga Operating Systems: Amix](https://archive.org/details/commodore-amiga-operating-systems-amix) (disk images).
- BlitterStudio/amiberry issue #1376 (A3000 SCSI + tape support for Amix — implemented in Amiberry 8.x).
