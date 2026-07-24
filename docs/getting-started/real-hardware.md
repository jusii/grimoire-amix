---
title: Running Amix on Real Hardware
summary: A3000UX/A2500UX setup notes — required machines and ROMs, the SCSI rule (tape hard-coded at ID 4, disk ID 6 by convention), modern SCSI emulation (ZuluSCSI), tape-free installs, and 10 Mbps Ethernet realities.
status: draft
---

# Running Amix on Real Hardware

If you have an actual Commodore 68030 Amiga, you can run Amix on it — but the machine, CPU, RAM, SCSI IDs, and graphics must fall inside a narrow envelope the kernel hard-codes. This page collects what you need to bring up Amix 2.1 on real iron: which machines and ROMs work, the **disk-ID-6 / tape-ID-4** rule that trips up everyone, how people substitute modern flash-SCSI (ZuluSCSI) for the long-dead hard disk and tape drive, and the realities of feeding it a distribution and a network in 2026.

Most of the *machine* facts here are ✅ verified from the Ditto paper and the install scripts on the root floppy. Almost everything about *modern* substitutes (ZuluSCSI, tape-free installs, finding 10 Mbps Ethernet) is 🟡 **community-reported** — credible hobbyist practice, not primary-verified. Where this page is uncertain it says so.

**If you just want to run Amix today, emulation is far easier than real hardware.** Start with [the WinUAE setup guide](emulation-winuae.md); this page is for people committed to original Commodore gear. The actual OS install steps (partitioning, streaming the distribution, kernel build, patch disk) live in [the installation walkthrough](install-walkthrough.md) and apply identically on real hardware and emulators — the only difference is the SCSI back end.

## The two official machines

Amix shipped on exactly two Commodore configurations. ✅

### A3000UX

The reference platform. ✅

- 68030 @ 25 MHz with a **68882 FPU** @ 25 MHz (the FPU is mandatory — see below).
- 1–2 MB Chip RAM + up to 8 MB Fast RAM as shipped.
- On-board (A3000) SCSI controller.
- **A3070** QIC-150 tape drive (the original install medium).
- **A2065** Zorro II Ethernet card (10 Mbps; see [networking realities](#10-mbps-ethernet-realities)).
- Optional **A2410** "Lowell" color graphics card (TMS34010, 1024×768) for color X11; without it you get monochrome X on the built-in chipset.
- **"Superkickstart 1.4"** bootstrap ROM: a special A3000 boot ROM that decides at power-on whether to boot Amix or AmigaOS. **Hold the right mouse button at power-on** to load an AmigaOS Kickstart instead of booting Amix; default (no button) boots Amix from SCSI. ✅
- 3-button mouse (X11 and the AT&T windowing tools expect three buttons).

### A2500UX

An A2000 pre-configured for Unix. ✅ The "UX" suffix means it shipped with Amix pre-installed; the hardware is otherwise a standard A2500:

- A2000 chassis + **A2630** accelerator (68030 @ 25 MHz + 68882 FPU).
- **A2090** or **A2091** Zorro II SCSI controller (no on-board SCSI on the A2000).
- First publicly demoed at Uniforum, Dallas, January 1988 (then running SVR3, not SVR4). 🟡 (event + year documented; the *machine* and *month* are community-reported)

> **A2500UX has no Superkickstart.** The dual-boot-by-mouse-button behavior is an A3000UX feature of its boot ROM ✅. On an A2500UX you boot from the SCSI disk (or a boot floppy) the normal way.

## Hard requirements (the kernel will not negotiate)

These are absolute and enforced by the kernel or the install scripts; you cannot patch around most of them because the relevant source was not shipped. ✅ throughout unless tagged.

| Requirement | Detail | Why it's fixed |
|---|---|---|
| **CPU** | 68020 **or** 68030 with a **real MMU** | Amix uses the 68030 MMU (HAT layer); a 68EC020/68EC030 (no MMU) **cannot** run Amix |
| **FPU** | **68881 or 68882** mandatory | No soft-float; the kernel and userland assume hardware FP |
| **No 68040/68060** | A4000 **cannot** officially run Amix | Kernel predates the 68040 MMU |
| **Fast RAM** | **4 MB minimum, 16 MB MAXIMUM** | Kernel hard-codes a 16 MB ceiling; **>16 MB mis-maps the SCSI drive** |
| **SCSI disk** | **ID 6** (convention) | Installer prompts for the disk target; ID 6 is the universal default, baked into device names once installed |
| **SCSI tape** | **must be SCSI ID 4** | Hard-coded in install scripts (`/dev/rmt/4h`) |
| **No Zorro III** | **Zorro II cards only** | The memory-mapping layer can't address Zorro III space, and that source wasn't shipped, so it can't be community-fixed |

For the full hardware story — supported SCSI/graphics/network/serial cards, the AUTOCONFIG mechanism, the RAM-ceiling failure mode — see [the hardware reference page](../how-it-works/hardware.md).

**On the Z3660 accelerator, the 16 MB contract is enforced in firmware, not left to you.** ✅ When the Z3660's Amix-interop mode is enabled, its emulator hard-wires a single 16 MB memory window (compile-time fixed — there is no config knob to raise it) and maps a dummy bank above it so nothing can coalesce past the ceiling; the same mode disables the accelerator's large CPU-RAM board, which is incompatible with the Amix memory map. The historical "address not in section 1" panics came from presenting *more* than 16 MB or a split/second window — never from 16 MB exactly, which is the intended, working configuration. (One consequence: the metal Amix console is display-only, so unlike emulation there is no serial-log capture of the SVR4 boot banner's memory line.)

### Why SCSI ID 6 and ID 4 matter so much

The install scripts on the root floppy stream the distribution from the tape at the literal `/dev/rmt/4h` / `/dev/rmt/4hn`, and reference the disk through a `$SCSI` variable (`/dev/dsk/c${SCSI}d0s${BOOTPART}`). ✅ The **tape must be at ID 4** — the installer looks nowhere else for the distribution media. The **disk is ID 6 by convention**: the installer prompts for the disk target, so another ID would work, but pick 6 — the chosen ID is baked into the device names (`/etc/vfstab`) once installed, so changing it later means editing that file 🟡. **Set the tape to SCSI ID 4 and the disk to SCSI ID 6 before you start.** Getting the *tape* ID wrong is the single most common reason a real-hardware install can't find its distribution media. ✅/🟡

This same ID rule is what the emulator configs reproduce: WinUAE/FS-UAE put the disk hardfile on SCSI ID 6 and the tape image on SCSI ID 4 (see [the WinUAE guide](emulation-winuae.md)).

## Modern SCSI: replacing dead disks and tape with flash 🟡

Original SCSI hard disks and QIC-150 tape drives are 30+ years old, unreliable, and increasingly impossible to source. The community substitutes a modern SCSI emulator — most commonly a **ZuluSCSI** (or BlueSCSI-class device) — that presents SD-card-backed images as SCSI devices. This is **🟡 community-reported** hobbyist practice; it is not described in any Amix primary source.

The principle is straightforward because Amix only cares about *SCSI IDs*, not the underlying media:

- Configure the SCSI emulator to expose a **disk image on SCSI ID 6** (this becomes your `c0d0` Amix hard disk, RDB-partitioned). 🟡
- Configure a second device on **SCSI ID 4** to stand in for the tape, if you need a tape-style install path. 🟡

> **Warning (🟡, unverified depth):** This page does **not** have a primary-verified ZuluSCSI profile for Amix. SCSI emulators vary in how faithfully they emulate a *sequential* (tape) device versus a *block* (disk) device, sector sizes, and parity/termination behavior — and Amix's SCSI handling is old and picky. Treat any specific device-profile recipe you find online as unverified until you reproduce it. The reliable, well-trodden path most people use is the **tape-free install** below, which sidesteps tape emulation entirely.

For how the disk is laid out once Amix sees it (RDB scheme, the 2 MB boot partition, swap, UFS-vs-s5 choice), see [filesystems and disks](../how-it-works/filesystems-and-disks.md) and [the installation walkthrough](install-walkthrough.md).

### Keep partitions reasonably small 🟡

Keep Amix partitions roughly **≲ 1 GB** each. 🟡 This is community guidance, not a documented hard limit — but combined with the 16 MB RAM ceiling and the era's filesystem assumptions, oversized partitions are a known source of trouble. A modern SD card is enormous relative to what Amix expects, so size the *Amix RDB partitions* conservatively rather than the card.

## Tape-free install (dd/cpio from another host) 🟡

You do **not** need a working tape drive to install Amix. The distribution is streamed from tape only because that was the 1992 medium; the actual data is a `cpio` archive, and you can deliver that archive by other means. Building the distribution onto a disk/swap area from another host (Linux or AmigaDOS) and extracting it with `cpio` is **documented on comp.unix.amiga** 🟡.

The mechanism mirrors what the installer does from tape. The install scripts on the root floppy run, in effect: ✅ (the command form is verified from the root.adf scripts)

```sh
# What the installer does when reading from real tape at SCSI ID 4:
dd if=/dev/rmt/4hn bs=256k | cpio -imdcu
# (a variant pipes through zcat for a compressed stream)
#   dd if=/dev/rmt/4hn bs=256k | zcat | cpio -imdcu
```

The tape-free approach replaces `if=/dev/rmt/4hn` with a regular file (or a raw partition such as swap) that already contains the same `cpio` stream — written there beforehand from another machine. 🟡 In outline:

1. On a modern host, write the Amix distribution `cpio` image to a SCSI/SD region that the Amix installer can read as a device (for example, a spare partition or the swap area). 🟡
2. Boot Amix from the boot floppy and into the root miniroot as usual ([walkthrough](install-walkthrough.md)).
3. Point the extract step at that file/device instead of the tape: `dd if=<file-or-device> bs=256k | cpio -imdcu`. 🟡

> **Note:** The exact device/partition you stage the image on, and how you wire that into the installer's package flow (`amixpkg -i -r /mnt`), are **not primary-verified here** — the precise recipe is community lore and varies by setup. The *fact* that tape-free installs are possible and were done is 🟡-documented on comp.unix.amiga; the *byte-level how-to* is left to that source. See [the installation walkthrough](install-walkthrough.md) for the package-install flow this plugs into.

### Non-standard tape drives: `viper_kludge` 🟡

If you *do* use a real tape drive that isn't the original A3070, note that the root floppy ships **`viper_kludge`** (by Frank "Crash" Edwards), which patches kernel memory so a non-standard **Archive Viper 2150S** drive works. ✅ (it is present on root.adf, with `viper.README`). Its own README warns it is **incompatible with the A3070, Caliper, Wangtek, and Sankyo** drives — do not run it with those. ✅ It does not help with arbitrary modern SCSI-emulated tape devices; it is specific to the Viper 2150S.

## 10 Mbps Ethernet realities

Amix networks over the **A2065** Zorro II card (Amix device `aen0`). ✅ The A2065 is a 10 Mbps card 🟡 (10Base2 coax / 10BaseT in the original A3000UX configuration), and that creates practical problems on a 2026 network:

- **Modern switches are gigabit-only and often won't negotiate 10 Mbps.** You typically need an **old 10/100 hub or switch**, or a **media converter** that explicitly supports 10BaseT, between the Amix machine and your modern LAN. 🟡 (This is general 10 Mbps-vintage-hardware reality, widely reported by the retro-Amiga community rather than stated in an Amix primary source.)
- For coax-only cards, you may need a 10Base2-to-10BaseT converter and proper terminators. 🟡

On the software side (✅/🟡, from the brief's networking notes):

- **Static IP only** — there is no DHCP client. ✅/🟡
- **DNS is off by default**; Amix resolves names from `/etc/hosts`. To enable resolver DNS you relink the socket library and configure a resolver:
  ```sh
  ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so
  # then configure /etc/netconfig, run in.named (or point at one), and write /etc/resolv.conf
  ```
- The default route **requires a metric**: `route add default <gateway> 1`. ✅/🟡
- **NFS** client and server work. **SLIP is buggy** (reboot between sessions); there is **no PPP**. 🟡

For the fuller networking picture (STREAMS TCP/IP, TLI + sockets, the A2065/Hydra options), see [the networking page](../how-it-works/networking.md).

## What "real hardware" buys you, and what it doesn't

Be honest with yourself about the trade-off:

- **Emulation (WinUAE) is the reference target** and is what almost all current driver work is built and tested against. ✅ It is easier to set up, snapshot, and recover. Start there: [WinUAE](emulation-winuae.md), [FS-UAE](emulation-fs-uae.md). (Note: [Amiberry](emulation-amiberry.md) **8.x** also runs and installs Amix now — it emulates the A3000 SCSI disk + tape. ✅)
- **Real hardware** gives you authenticity and native I/O, but you inherit every hard limit on this page plus the sourcing problem for 68030 boards, FPUs, working SCSI/tape, and 10 Mbps networking.

If your goal is to *develop* drivers or explore the system, emulation is the pragmatic choice. If your goal is to run Amix on the metal it was written for, this page is your checklist.

## See also
- [Installation walkthrough](install-walkthrough.md) — the OS install steps (partitioning, streaming the distribution, kernel build, patch disk) that run identically on real hardware
- [Hardware reference](../how-it-works/hardware.md) — supported cards, AUTOCONFIG, the 16 MB ceiling, RAM/CPU/MMU requirements in depth
- [Emulation with WinUAE](emulation-winuae.md) — the recommended way to run Amix today
- [Filesystems and disks](../how-it-works/filesystems-and-disks.md) — RDB layout, the 2 MB boot partition, UFS vs s5
- [Networking](../how-it-works/networking.md) — STREAMS TCP/IP, DNS, NFS, the A2065
- [Quirks checklist](../how-it-works/quirks.md) — the SCSI-ID, RAM-ceiling, and Y2K gotchas in one place
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — the most authoritative community resource for end-user install/history/media

## Sources
- Research brief §2 (Hardware & requirements: A3000UX/A2500UX specs, Superkickstart, 68020/030+MMU+FPU mandatory, 4–16 MB Fast RAM, SCSI disk ID 6 / tape ID 4, no Zorro III, no 68040, A2065 networking) — primary facts ✅, expansion notes 🟡.
- Research brief §9 (Installation flow: `dd if=/dev/rmt/4hn bs=256k | cpio -imdcu` and `… | zcat | cpio` variants reconstructed from `amix_21_root.adf` scripts; `viper_kludge` / `viper.README`; tape-free installs documented on comp.unix.amiga 🟡).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` (install scripts: `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`, `/dev/rmt/4h`, `viper.README`) ✅.
- Research brief §11 (Networking: A2065 `aen0`, static IP only, DNS off by default + relink recipe, `route add default … 1`, NFS, SLIP/PPP) ✅/🟡.
- Research brief §8 (Emulation: WinUAE reference target; Amiberry 8.x adds A3000 SCSI + tape support — BlitterStudio/amiberry issue #1376, implemented). First-hand confirmation on Amiberry 8.1.6.
- ZuluSCSI/flash-SCSI substitution, old hub / media-converter need, and the byte-level tape-free recipe: **community-reported (🟡)**, retro-Amiga community practice and comp.unix.amiga; not primary-verified in any Amix source.
- The **Z3660** Amix-interop firmware fork — the compile-time-fixed single 16 MB window (`AMIX_A3000MEM_MB`), the dummy bank preventing coalescing past the ceiling, the `amix_mode`-forces-CPU-RAM-off contract, and the "not in section 1" panics coming only from >16 MB / split windows: read from `Z3660_emu/src/uae/uae_emulator.cpp`, `Z3660/src/config_file.c`, `AMIX_SCSI_design.md`, `docs/AMIX.md` ✅.
