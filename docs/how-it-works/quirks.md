---
title: Quirks & Gotchas
summary: The Amiga-port-specific surprises that bite developers and installers.
status: draft
---

# Quirks & Gotchas

Amix is a "quick and dirty" 1990–1992 SVR4 port ✅, and it shows: the kernel hard-codes SCSI IDs and a RAM ceiling, the bootstrap predates the 68040 and Zorro III, the clock breaks in 2000, and the userland is pre-POSIX. This page is the **checklist of port-specific surprises** — the things that are technically correct, technically broken, or just unexpected, that cost people hours before they realize "it's just Amix."

Each item is one line: what it is, the ✅/🟡 confidence tag carried from the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §12 (and §2/§9/§11), and a cross-link to the page that covers it in depth.

## TL;DR checklist

| # | Quirk | Tag | Deeper coverage |
|---|---|---|---|
| 1 | SCSI hard disk **must be ID 6**, tape **must be ID 4** — hard-coded | ✅ | [Filesystems & disks](filesystems-and-disks.md), [WinUAE setup](../getting-started/emulation-winuae.md) |
| 2 | **16 MB Fast RAM ceiling**; more mis-maps the SCSI drive | ✅ | [Hardware](hardware.md) |
| 3 | **No Zorro III** — memory-mapping layer can't address it; unfixable | ✅ | [Hardware](hardware.md), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 4 | **No 68040/68060** → the A4000 can't officially run Amix | ✅ | [Hardware](hardware.md) |
| 5 | **Superkickstart dual-boot** by holding the right mouse button at power-on | ✅ | [Boot process](boot-process.md) |
| 6 | **DNS resolution is OFF by default** (`/etc/hosts` only) | ✅/🟡 | [Networking](networking.md) |
| 7 | **Y2K bugs**: `setclk` `%02d` year + kernel date cap at 1999 | ✅/🟡 | [Versions](../reference/versions.md), [Patch ADF anatomy](../boot-disks/anatomy-patch-adf.md) |
| 8 | **SLIP is buggy** — reboot between sessions; no PPP at all | 🟡 | [Networking](networking.md) |
| 9 | **X keymap is wrong**: y/z swapped, `/` is SHIFT-8 | 🟡 | [X11 & desktop](x11-and-desktop.md) |
| 10 | **`amixpkg` is widely reported broken** (the wrapper, not `pkgadd`) | 🟡 | [Install walkthrough](../getting-started/install-walkthrough.md) |
| 11 | **Clock drift** via SCSI interaction | 🟡 | [Networking](networking.md) |
| 12 | **`/bin/sh` is pre-POSIX**: no `$(...)`, no `grep -q` | ✅ | [Driver model](../drivers/driver-model.md), [Writing a char driver](../drivers/writing-a-char-driver.md) |

The rest of this page expands each item.

## Hardware & addressing quirks

### 1. SCSI IDs are hard-coded: disk = 6, tape = 4 ✅

The SCSI **hard disk must sit at ID 6** and the **tape drive must sit at ID 4**. These IDs are baked into the kernel *and* into the install scripts — they are not configurable knobs. The root-floppy install scripts reference `/dev/rmt/4h` (tape at ID 4) and compute the boot partition as `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` against the ID-6 disk ✅ ([`amix_21_root.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh`).

**Consequence for emulation:** attach your hardfile (RDB) at SCSI ID 6 and your tape image at SCSI ID 4, or the installer will not find them. See the mandatory mapping in [the WinUAE setup](../getting-started/emulation-winuae.md) and [the FS-UAE setup](../getting-started/emulation-fs-uae.md). Disk geometry and partitioning are covered in [filesystems & disks](filesystems-and-disks.md).

### 2. The 16 MB Fast RAM ceiling ✅

The kernel hard-codes a Fast RAM ceiling of **16 MB** (minimum 4 MB) ✅. Going **above 16 MB mis-maps the SCSI drive** ✅ — the symptom is disk corruption / failure rather than an honest "too much RAM" error, which makes it a nasty trap. Set your emulator's Fast RAM to **≤ 16 MB**. Background in [hardware](hardware.md).

### 3. No Zorro III ✅

Amix's memory-mapping layer **cannot address Zorro III space** ✅. It is **Zorro II only**. Worse, the relevant kernel source was never shipped, so this can't be patched by the community ✅ — there is no community fix and there won't be one. Any expansion board you intend to use must present a Zorro II window; see [Zorro autoconfig](../drivers/zorro-autoconfig.md) for how boards are discovered via the AUTOCONFIG / `autocon()` path, and [hardware](hardware.md) for the supported-board list.

### 4. No 68040/68060 — the A4000 is out ✅

The kernel **predates the 68040 MMU** ✅, so it runs only on a **68020 or 68030 with a real MMU plus a 68881/68882 FPU** ✅. There is no soft-float and the MMU-less `68EC020/030` variants cannot run Amix ✅. Practical upshot: an **A4000 cannot officially run Amix** ✅. Targets are the A3000(UX) and the A2500UX. See [hardware](hardware.md).

### 5. Superkickstart dual-boot via the right mouse button ✅

A3000UX machines ship a **"Superkickstart 1.4"** bootstrap ROM ✅. At power-on:

- **Default** (do nothing) → boot **Amix** from the SCSI disk.
- **Hold the right mouse button** at power-on → load an **AmigaOS Kickstart** instead.

So the "gotcha" is the inverse of what AmigaOS users expect: the machine boots Unix by default, and you reach AmigaOS only by holding a mouse button. Details in [the boot process](boot-process.md).

## Networking quirks

### 6. DNS resolution is off by default ✅/🟡

Out of the box, name resolution uses **`/etc/hosts` only — DNS is disabled** ✅/🟡. To turn DNS on you relink the socket library and add config:

```sh
ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so   # swap in the DNS-capable socket lib
# then provide /etc/netconfig, start in.named (or point elsewhere), and write /etc/resolv.conf
```

Also note the routing gotcha: the default route needs an explicit metric — `route add default <gw> 1` (the trailing `1` is required) ✅/🟡. Full procedure in [networking](networking.md).

### 8. SLIP is buggy; no PPP 🟡

SLIP works but is **buggy: you must reboot between SLIP sessions** 🟡, and there is **no PPP at all** 🟡. If you need a serial IP link, plan for a reboot cycle rather than re-dialing. See [networking](networking.md).

### 11. Clock drift via SCSI interaction 🟡

The system clock **drifts**, reportedly because of an interaction with SCSI activity 🟡. On a networked box you'll want a time-sync workaround; combined with the Y2K issues below, treat timekeeping as something to actively manage rather than trust. See [networking](networking.md).

## Time & Y2K quirks

### 7. Y2K: `setclk` and the kernel's 1999 date cap ✅/🟡

Amix has **two** millennium problems ✅/🟡:

1. The `setclk` utility uses a `%02d` format for the year, so it mishandles dates ≥ 2000.
2. The **kernel caps the date at 1999** — even the finishing-touches install step (`amixadm`) only accepts a date **≤ 1999** ✅.

These are **community-patched** ✅/🟡: applying the patch disk (which upgrades to **2.1p2a / kernel 2.1c**) ships Y2K fixes, after which you run the corrected `setclk` ✅. See the patch mechanism in [the patch ADF anatomy](../boot-disks/anatomy-patch-adf.md) and the version timeline in [versions](../reference/versions.md).

## X11 & desktop quirks

### 9. The X keymap is wrong 🟡

Under X11 the default keymap is mis-mapped 🟡:

- **y and z are swapped.**
- **`/` is produced by SHIFT-8.**

There are other X annoyances in the same family — `xload` crashes and the X11R4 server leaks memory 🟡. The modern RTG path ([Xrtg / VA2000](../drivers/x11-rtg-drivers.md)) sidesteps the old server but not the keymap mapping itself. Full X11 notes (mono `tvtwm`, A2410 color via TIGA, OpenLook font-path breakage on the R5 upgrade) are in [X11 & desktop](x11-and-desktop.md).

## Userland & packaging quirks

### 10. `amixpkg` is flaky 🟡

The **`amixpkg` wrapper** around the SVR4 packaging tools is **widely reported to be broken** 🟡 — note this is the wrapper, not the underlying `pkgadd`/`pkgmk`/`pkgtrans`, which work. Despite the reputation, the official install path *does* drive it: the root-floppy installer runs `amixpkg -i -m -d -r /mnt -y standard` ✅. A related packaging gotcha: `pkgproto` omits symlinks 🟡. See [the install walkthrough](../getting-started/install-walkthrough.md).

### 12. `/bin/sh` is pre-POSIX ✅

Amix's **`/bin/sh` predates POSIX** ✅. The two bites that catch driver authors and scripters:

- **No command substitution with `$(...)`** — you must use backticks `` `...` ``.
- **No `grep -q`** — redirect to `/dev/null` and test `$?` instead.

This was discovered the hard way porting the [VA2000 driver](../drivers/case-studies/va2000.md): install scripts written with modern shell syntax silently misbehave ✅. The default *interactive* shell is **ksh** (with `sh`/`csh`/`tcsh` also present), but build and install scripts that run under `/sbin/sh` or `/bin/sh` must stay pre-POSIX ✅. See [the driver model](../drivers/driver-model.md) and [writing a char driver](../drivers/writing-a-char-driver.md) for the driver-build implications, including the companion rule to `rm -f` stale objects before relinking the kernel.

## See also

- [Hardware](hardware.md) — the machines, RAM ceiling, Zorro II, FPU/MMU requirements in full.
- [Boot process](boot-process.md) — Superkickstart, the bootstrap, and on-disk layout.
- [Networking](networking.md) — DNS, routing, SLIP, NFS, and clock notes.
- [X11 & desktop](x11-and-desktop.md) — the X server, window managers, and keymap.
- [Glossary](glossary.md) — RDB, AUTOCONFIG, STREAMS, Superkickstart, and other terms used here.

## Sources

- Research brief §12 (quirks checklist), with specifics pulled from §2 (hardware & limits), §9 (install flow + `viper_kludge`/Y2K), and §11 (networking, X11, userland).
- [`amix_21_root.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh` — `/dev/rmt/4h`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`, `amixpkg -i -m -d -r /mnt -y standard`.
- [`amix_21_patch.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh` — patch-disk Y2K/inet fixes (→ 2.1p2a / kernel 2.1c).
- `asokero/va2000-amix` (pre-POSIX `/bin/sh`, no `$(...)`, no `grep -q`; relink hygiene) — <https://github.com/asokero/va2000-amix>.
- Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (driver/kernel model behind the SCSI-ID and `/bin/sh` notes).
- amigaunix.com DokuWiki — requirements, networking, x11, patch-disk, y2k-dst, tips-tricks, dual-boot pages (community-reported items): <https://www.amigaunix.com/doku.php/home>.
- BlitterStudio/amiberry issue #1376 and WinUAE/FS-UAE docs (emulation consequences of the hard-coded SCSI IDs and RAM ceiling).
