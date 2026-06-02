---
title: Running Amix in WinUAE
summary: The exact WinUAE configuration that boots Amix, plus the MMU/JIT/SCSI gotchas that silently break it.
status: draft
---

# Running Amix in WinUAE

WinUAE is the **reference emulator** for Amix ✅. It is the only emulator that combines accurate 68030 **MMU** emulation (added in WinUAE 2.6.0, 2013) with working Amiga SCSI and tape emulation — the two things Amix cannot boot or install without. This page gives you the complete, copy-checkable settings table and the step-by-step path to the first boot prompt. Get one of the four highlighted rows wrong (MMU, JIT, "More Compatible", or the two SCSI IDs) and Amix will either panic, freeze, or fail to find its disk.

If you want the *why* behind these settings, see [how Amix uses the hardware](../how-it-works/hardware.md). For the install itself once you have a booting emulator, see the [install walkthrough](install-walkthrough.md). For a non-Windows host, see [Running Amix in FS-UAE](emulation-fs-uae.md).

## Before you start: what you need

You supply your own images — none of these files are redistributable, so this repo does not ship them. Get them from [amigaunix.com](https://www.amigaunix.com/doku.php/home) and the [Internet Archive Amix collection](https://archive.org/details/commodore-amiga-operating-systems-amix).

| File | What it is | Where it goes |
|---|---|---|
| `amix_2.1_boot.adf` | Bootable floppy: AmigaDOS bootblock + Amix bootstrap + compressed install kernel ✅ | Floppy drive **DF0** |
| Distribution tape image | The Amix package stream (`cpio`) read during install ✅ | **SCSI ID 4** (tape) |
| A blank RDB hardfile (`.hdf`), ~450–900 MB | Becomes your Amix disk | **SCSI ID 6** |
| A3000 Kickstart ROM | 2.04 (rev 37.175) or 3.1 (40.68) ✅ | ROM slot |

**Note:** Amix does not use the Amiga custom chips and has no AmigaOS compatibility layer ✅ — it treats the machine as a generic 68030 Unix workstation. You are emulating an **A3000UX**-class machine, not a games Amiga.

## The mandatory WinUAE configuration

All of the following are required for a *clean* boot. The four bolded rows are the ones that silently break Amix if set wrong. This table is ✅ except where a row carries 🟡.

| WinUAE setting | Value | Why |
|---|---|---|
| CPU | **68030** | Required; Amix runs only on a real-MMU 68020/030 ✅ |
| **MMU** | **ON** | Amix uses the full 68030 MMU (HAT layer); without it the kernel cannot map memory ✅ |
| **JIT** | **OFF** | JIT translation causes kernel panics ✅ |
| FPU | **68882** | Mandatory; there is no soft-float ✅ |
| "More Compatible" | **OFF** | If ON, boot freezes (reported symptom: `sort: fatal: line too long`) 🟡 |
| Wait for Blitter | **ON** | 🟡 |
| ROM | A3000 KS **2.04 (rev 37.175)** or **3.1 (40.68)** | Must be an A3000 ROM ✅ |
| Chip RAM | **2 MB** | ✅ |
| Fast RAM | **≤ 16 MB** | Kernel hard-codes a 16 MB ceiling; **more mis-maps the SCSI drive** ✅ |
| Floppy **DF0** | `amix_2.1_boot.adf` | The bootable install floppy ✅ |
| **SCSI ID 4** | Tape image | Install script reads the distribution from `/dev/rmt/4hn`, hard-coded ✅ |
| **SCSI ID 6** | RDB hardfile, ~450–900 MB | The conventional Amix disk target — the installer prompts for it, but use 6 (see [hardware](../how-it-works/hardware.md#scsi-target-ids)) ✅ |

### Why each gotcha bites

- **MMU ON / JIT OFF** — these two are a pair. Amix is one of the very few classic-Amiga OSes that *requires* the MMU, and JIT and the MMU emulation do not coexist for it. JIT on → panic ✅.
- **More Compatible OFF** — counter-intuitive, because for AmigaOS games you usually want it ON. For Amix it triggers a boot-time freeze 🟡.
- **16 MB Fast RAM ceiling** — the kernel hard-codes the limit. Exceeding 16 MB does not just waste RAM; it **mis-maps the SCSI controller**, so the symptom looks like a disk problem, not a memory problem ✅.
- **SCSI ID 4 = tape, ID 6 = disk.** The **tape ID 4 is hard-coded** (the scripts read `/dev/rmt/4h` and look nowhere else); the **disk ID 6 is convention** — the installer prompts for the disk target and computes the boot partition from `c${SCSI}d0s${BOOTPART}`. Use 6: it's the universal default and gets baked into the installed device names (`/etc/vfstab`), so you'd only have to undo it later. ✅/🟡

See the [quirks page](../how-it-works/quirks.md) for the full list of hard-coded assumptions, and the [device list](../reference/device-list.md) for the `/dev/rmt/4h` and `/dev/dsk/c0d0s*` naming.

## Step by step to the first boot prompt

1. **Create the RDB hardfile.** In WinUAE's hard-drive panel, add a new hardfile of ~450–900 MB. It must be presented as an **RDB** disk (the Amiga Rigid Disk Block scheme ✅), because the Amix installer scans the RDB to find a "suitable UNIX rdb". Assign it **SCSI unit/ID 6**.

   ```text
   Add Hardfile…
     Path:        a3000ux.hdf      (new, blank)
     Controller:  A3000/A3000T SCSI (or "SCSI")
     Unit (ID):   6
     RDB mode:    yes (let Amix partition it)
   ```

2. **Attach the tape image to SCSI ID 4.** Add the distribution tape image as a SCSI device at **ID 4**. This is what the installer streams the OS from during install (`dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`) ✅. You can ignore this row only if you intend a tape-free install (see below), but the standard, documented path uses it.

3. **Set CPU, MMU, JIT, FPU.** CPU = 68030, **MMU = ON**, **JIT = OFF**, FPU = 68882. Turn **"More Compatible" OFF** and **"Wait for Blitter" ON**.

4. **Set RAM.** Chip = 2 MB, Fast = anything **≤ 16 MB** (16 MB is the documented maximum used by amigaunix.com and FS-UAE configs ✅; do not exceed it).

5. **Set the ROM.** Point the Kickstart ROM at an A3000 ROM image: 2.04 (37.175) or 3.1 (40.68) ✅.

6. **Insert the boot floppy.** Put `amix_2.1_boot.adf` in **DF0**.

7. **Start the emulation.** The A3000's "Superkickstart" bootstrap behavior is what you are reproducing: at power-on, the default path boots Amix (holding the right mouse button would instead load AmigaOS Kickstart on real hardware) ✅. WinUAE will run the bootblock from DF0, the Amix secondary bootstrap loads and **decompresses the install kernel** (you may see messages such as `Load boot volume %d`; failures print `Decompression failed!` or `WARNING! Kernel file checksum mismatch.`) ✅, and the kernel comes up.

8. **You reach the install kernel / first prompt.** From here you are in the Amix installer flow: insert the root floppy when prompted, the UFS miniroot mounts, and the installer runs. That process is covered in detail in the [install walkthrough](install-walkthrough.md).

**Tip:** Save this as a WinUAE configuration (e.g. `amix-a3000ux.uae`) immediately after step 6, so you never re-enter the table. A single wrong row (JIT back ON, RAM bumped over 16 MB) is the most common cause of "it stopped booting."

## After install: logging in

Once Amix is installed to the SCSI ID 6 disk and you boot from it, the default post-install login password is reported to be **`wasp`** 🟡 (community-reported; not primary-verified). You will set your own root password during the `amixadm` finishing step of the install. See [first login and tour](first-login-and-tour.md).

## Tape-free installs

The tape image at SCSI ID 4 is the standard route, but a tape-free install is documented on comp.unix.amiga 🟡: write a `cpio` image of the distribution to the swap area (e.g. `dd` it from Linux or AmigaDOS) and extract it with `cpio` from the miniroot. If you use a non-standard tape drive on real hardware, the `viper_kludge` patch ships on the root floppy ✅ — but it is **not** needed under emulation, where you control the emulated tape device. See the [install walkthrough](install-walkthrough.md) for both routes.

## Troubleshooting quick table

| Symptom | Most likely cause |
|---|---|
| Kernel panic shortly after boot | JIT is **ON** — set it **OFF** ✅ |
| Boot freezes; `sort: fatal: line too long` | "More Compatible" is **ON** — set it **OFF** 🟡 |
| Installer can't find a disk / SCSI errors | Disk not at **SCSI ID 6**, or Fast RAM **> 16 MB** mis-mapping the controller ✅ |
| Installer can't read the distribution | Tape image not at **SCSI ID 4** ✅ |
| `Decompression failed!` / `WARNING! Kernel file checksum mismatch.` | Corrupt or wrong `boot.adf` — re-verify against the checksum on amigaunix.com ✅ |
| Won't map memory / boots then dies in MMU code | MMU is **OFF**, or you used a non-A3000 ROM ✅ |

## See also
- [Install walkthrough](install-walkthrough.md) — the full installer flow once the emulator boots.
- [Running Amix in FS-UAE](emulation-fs-uae.md) — the same machine on a non-Windows host.
- [Running Amix in Amiberry](emulation-amiberry.md) — Amiberry 8.x also runs and installs Amix (A3000 SCSI disk + tape).
- [How Amix uses the hardware](../how-it-works/hardware.md) — why the MMU, FPU, and SCSI IDs are mandatory.
- [Quirks](../how-it-works/quirks.md) — the complete list of hard-coded limits.

## Sources
- Research brief §8 (Emulation — WinUAE mandatory config table; "wasp" login 🟡), §2 (hardware minimums: 68030 + real MMU + 68882, 4–16 MB Fast RAM ceiling, SCSI ID 6 disk / ID 4 tape), §3 (Superkickstart boot path, RDB layout), §9 (installation flow, `dd if=/dev/rmt/4hn … | cpio`, tape-free install, `viper_kludge`).
- `amix_2.1_boot.adf` analysis via `tools/inspect-adf.sh` (bootblock + compressed kernel; decompression/checksum strings) — brief §3, §10.
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) (install media, image checksums, requirements).
- [Internet Archive: Commodore Amiga operating systems — Amix](https://archive.org/details/commodore-amiga-operating-systems-amix).
- WinUAE MMU emulation since 2.6.0 (2013) — brief §8.
