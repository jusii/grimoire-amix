---
title: Quirks & Gotchas
summary: The Amiga-port-specific surprises that bite developers and installers.
status: draft
---

# Quirks & Gotchas

Amix is a "quick and dirty" 1990–1992 SVR4 port ✅, and it shows: the kernel hard-codes SCSI IDs and a RAM ceiling, the bootstrap predates the 68040 and Zorro III, the clock breaks in 2000, and the userland is pre-POSIX. This page is the **checklist of port-specific surprises** — the things that are technically correct, technically broken, or just unexpected, that cost people hours before they realize "it's just Amix."

Each item is one line: what it is, the ✅/🟡 confidence tag carried from the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §12 (and §2/§9/§11, plus §17/§18 for the Z3660 driver-authoring items), and a cross-link to the page that covers it in depth.

## TL;DR checklist

| # | Quirk | Tag | Deeper coverage |
|---|---|---|---|
| 1 | **Tape must be ID 4** (hard-coded `/dev/rmt/4h`); **disk ID 6 by convention** — installer prompts for the target, but the ID is baked into device names, so don't change it post-install | ✅/🟡 | [Hardware](hardware.md#scsi-target-ids), [Filesystems & disks](filesystems-and-disks.md) |
| 2 | **16 MB Fast RAM ceiling**; more mis-maps the SCSI drive | ✅ | [Hardware](hardware.md) |
| 3 | **Stock Amix is Zorro II only** — stock drivers can't address Zorro III; but a purpose-written driver that maps the board (`sptalloc`, or a window inside TT0) **can** — see the [A4091](../drivers/a4091-53c710-driver.md) & [Z3660](../drivers/z3660-ethernet-driver.md) drivers | ✅ | [Hardware](hardware.md), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 4 | **No 68040/68060** → the A4000 can't officially run Amix | ✅ | [Hardware](hardware.md) |
| 5 | **Superkickstart dual-boot** by holding the right mouse button at power-on | ✅ | [Boot process](boot-process.md) |
| 6 | **DNS resolution is OFF by default** (`/etc/hosts` only) | ✅/🟡 | [Networking](networking.md) |
| 7 | **Y2K bugs**: `setclk` `%02d` year + kernel date cap at 1999 | ✅/🟡 | [Versions](../reference/versions.md), [Patch ADF anatomy](../boot-disks/anatomy-patch-adf.md) |
| 8 | **SLIP is buggy** — reboot between sessions; no PPP at all | 🟡 | [Networking](networking.md) |
| 9 | **X keymap is wrong**: y/z swapped, `/` is SHIFT-8 | 🟡 | [X11 & desktop](x11-and-desktop.md) |
| 10 | **`amixpkg` is install-media-only, not an installed tool** — it drives the `root.adf` install; its "broken" reputation is partly the item below (the raw `pkgadd`/`pkgmk` tools *are* installed and work) | ✅/🟡 | [Package management](package-management.md), [Install walkthrough](../getting-started/install-walkthrough.md) |
| 11 | **Clock drift** via SCSI interaction | 🟡 | [Networking](networking.md) |
| 12 | **`/bin/sh` is pre-POSIX**: no `$(...)`, no `grep -q` | ✅ | [Driver model](../drivers/driver-model.md), [Writing a char driver](../drivers/writing-a-char-driver.md) |
| 13 | **Enabling DNS adds ~3 min to every boot** unless the boot-time `ifconfig`s (`S69inet` `lo0`, `network-config` `aen0`) use **literal IPs** instead of hostnames | ✅ | [Networking](networking.md), [Networking on the LAN](../getting-started/networking-on-the-lan.md) |
| 14 | **A board interrupt Amix has no handler for will storm the kernel** — the Z3660 firmware raised level-6 (INT6) on every RX frame; with no Amix eth-INT6 handler, ordinary ARP broadcasts hard-locked the box. Fix: disable the firmware IRQ and **poll** | ✅ | [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) |
| 15 | **A board the 2.1 `bootinfo.autocon[]` table misses, registered via `autocon()` alone, silently never runs** — kernel banner, then a dead box (no panic, no I/O). Fix: multi-method detect (autocon → a chipset-gated fixed-base probe → a `probe=` fallback) | ✅ | [Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md), [A4091](../drivers/a4091-53c710-driver.md) |
| 16 | **On an emulated 68k, "boots then hangs" may be the *emulator*, not your driver** — the Z3660's 68k emulator faulted demand-paging the driver's own pages, while the driver carried every transfer byte-perfectly. Triage with serial instrumentation + core-dump analysis before blaming the driver | ✅ | [Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md), [Emulation Fidelity](emulation-fidelity.md) |
| 17 | **An emulator that batches instructions between interrupt polls can hang the A3000-SCSI bootstrap** — that bootstrap is INT2-driven; too-coarse interrupt-service cadence starves it and Amix hangs *before the banner*. Keep INT2 latency low through boot (on the Z3660, `service_cadence ≤ 4`) | 🟡 | [Emulation Fidelity](emulation-fidelity.md) |
| 18 | **`pkgrm` and `pkginfo -l` fail out of the box on the stock 2.1c image** — one malformed `contents` record (a filename containing a space) aborts every full parse of the package DB (`bad read of contents file … unknown ftype`). Delete that one line to fix both | ✅ | [Package management](package-management.md#the-space-in-a-pathname-defect) |
| 19 | **`mount(2)` silently *stacks* a second mount on an already-mounted directory** — the second `mount` returns 0, `umount` then pops one layer and returns 0 while the media looks "still mounted": a perfect fake broken-umount. An in-kernel filesystem must refuse it itself. Smoking gun: duplicate fstype lines in `/etc/mnttab` | ✅ | [Driver model](../drivers/driver-model.md#writing-an-in-kernel-filesystem-the-svr4-vfs_mount-contract) |
| 20 | **"Password expired" at login is the *future-`lastchg`* check, not max-age** — a dead RTC battery boots the box in 1978; if a previous session set the clock forward, `/etc/shadow`'s `lastchg` is now in the future and SVR4 `login` forces a password change every boot. **Never set the box RTC forward** | ✅ | [Time & Y2K](#20-password-expired-is-the-future-lastchg-check-never-set-the-rtc-forward) |

The rest of this page expands each item.

## Hardware & addressing quirks

### 1. SCSI IDs: tape fixed at 4, disk 6 by convention ✅/🟡

The **tape drive must sit at ID 4** — the root-floppy install scripts hard-reference the literal `/dev/rmt/4h` and look nowhere else for it ✅. The **hard disk is ID 6 by convention**, not by kernel mandate: the installer *prompts* for the disk target and computes the boot partition from a `$SCSI` variable (`BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`), reserving only ID 4 for the tape — so Amix will install on a disk at another target 🟡. The catch is that the chosen ID is baked into the device names (`c6d0s…`) the installed system records in `/etc/vfstab` (the SVR4 mount table) and the boot partition, so **you can't change the disk's SCSI ID after install** without editing `/etc/vfstab` to match 🟡 ([`amix_21_root.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh`; see [hardware](hardware.md#scsi-target-ids)).

**Consequence for emulation:** attach your tape image at SCSI ID 4 (the installer looks only there) and your hardfile (RDB) at SCSI ID 6 — any target works for the disk, but 6 is the convention and saves you re-pointing `/etc/vfstab` later. See the mapping in [the WinUAE setup](../getting-started/emulation-winuae.md) and [the FS-UAE setup](../getting-started/emulation-fs-uae.md). Disk geometry and partitioning are covered in [filesystems & disks](filesystems-and-disks.md).

### 2. The 16 MB Fast RAM ceiling ✅

The kernel hard-codes a Fast RAM ceiling of **16 MB** (minimum 4 MB) ✅. Going **above 16 MB mis-maps the SCSI drive** ✅ — the symptom is disk corruption / failure rather than an honest "too much RAM" error, which makes it a nasty trap. Set your emulator's Fast RAM to **≤ 16 MB**. Background in [hardware](hardware.md).

### 3. Zorro III — stock drivers are Zorro II only ✅

**Stock** Amix is **Zorro II only** ✅: its stock drivers simply dereference the address `autocon()` returns, which only reaches Zorro II boards (≤ 24-bit, inside the 68030's TT0 window), and that kernel source was never shipped so the *stock* card set can't be patched in place. This is **not** absolute for a *purpose-written* driver, though: one that maps the board explicitly — the kernel's `sptalloc()` primitive, or (when the board's window happens to fall inside TT0) a direct mapping — **can** reach a Zorro III board. The [A4091 SCSI driver](../drivers/a4091-53c710-driver.md) (🟡 emulation) and the [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) (✅ real hardware) both do exactly this. For ordinary expansion, still assume a card must present a Zorro II window; see [Zorro autoconfig](../drivers/zorro-autoconfig.md) for how boards are discovered via the AUTOCONFIG / `autocon()` path, and [hardware](hardware.md) for the supported-board list.

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

### 13. Enabling DNS adds ~3 minutes to every boot ✅

Turning DNS on (quirk 6 above) drops a hidden tax on the **boot path**: with DNS enabled the box stalls **~3 minutes** at `The system is coming up.  Please wait.` on *every* boot ✅ (reproduced locally on Amix 2.1c under Amiberry). Stock Amix, with DNS off, does not.

The cause is two boot-time `ifconfig` calls that take **hostnames**, each forcing a `gethostbyname()` ✅:

- `ifconfig lo0 localhost up` — in `/etc/rc2.d/S69inet`
- ``ifconfig aen0 `uname -n` up -trailers`` — in `/etc/inet/network-config`

Both run **before** the default route is installed (`route add default …` happens later, in `/etc/inet/rc.inet`). With DNS on, `gethostbyname()` tries DNS first, but there is no route to the nameservers yet, so each lookup burns the full resolver retransmit schedule — **~90 s each, ~180 s total** — before falling back to `/etc/hosts` ✅. With DNS off the same names resolve instantly from `/etc/hosts`, which is exactly why this trap appears **only after** you enable DNS.

This is **independent of the `/etc/domain` weirdness** ✅: a box with an already-empty `/etc/domain` still hangs the full 180 s — the domain-append bug and this no-route hang are two different problems.

**Fix (boot 210 s → 29 s; runtime DNS unaffected):** give both boot-time `ifconfig`s a **literal IP** so no resolver call happens before the network is up ✅:

```
# /etc/rc2.d/S69inet
-   /usr/sbin/ifconfig lo0 localhost up
+   /usr/sbin/ifconfig lo0 127.0.0.1 up
# /etc/inet/network-config
-   /usr/sbin/ifconfig aen0 `uname -n` up -trailers
+   /usr/sbin/ifconfig aen0 <this-host-static-ip> up -trailers
```

`lo0` is always `127.0.0.1`; `aen0` uses the host's own static address (the one already in `/etc/hosts`). Configuring your own interface should never depend on a name service, so this is the correct design regardless — and DNS for clients/mail/etc. is untouched. Full procedure in [networking](networking.md) and [networking on the LAN](../getting-started/networking-on-the-lan.md).

### 14. An unhandled board interrupt storms the kernel ✅

A gotcha for **driver authors**, learned bringing up the [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) on real hardware: if a board (or its firmware) raises a CPU interrupt level for which **Amix installs no handler**, the unacknowledged source fires continuously and **hard-locks the machine** ✅. The Z3660 firmware raises Amiga **INT6 (EXTER)** on *every* received ethernet frame, but Amix has no level-6 ethernet handler — so the moment the interface came up, normal LAN **ARP broadcast traffic stormed INT6 and instantly froze the box** (caps-lock LED dead). The whole kernel had booted to `login:` fine; only bringing the interface up triggered it.

**Fix:** disable the board/firmware interrupt and **poll** the receive path instead — `z3660eth` writes the firmware's `ZZ_CONFIG_DISABLE` so INT6 is never raised, and drains RX from a clock-level `timeout()` callout ✅. Interrupt-driven RX would need a level-6 hook the firmware's model doesn't safely give Amix. The general lesson: when adding a driver, don't enable an interrupt source Amix can't service — confirm there's a handler (and an ack path) for that level, or run polled. Full story on [the Z3660 ethernet driver case study](../drivers/z3660-ethernet-driver.md).

## Driver-authoring quirks

### 15. An un-enumerated board silently never runs ✅

Amix 2.1's `bootinfo.autocon[]` table can **miss** a board that is physically present — seen on the
Z3660, both when its combo window sits at a fixed base outside the AutoConfig chain
(`autoconfig_rtg NO`) and when Kickstart *does* configure it (`autoconfig_rtg YES`) but the 2.1 table
still doesn't list it ✅. If the kernel's `sd.c` registers controllers **only** via `autocon()`, the
driver's queue function never runs — and the failure is **silent**: the kernel prints its banner, then
nothing (no panic, no I/O, no log) ✅. The same `bootinfo` table is independently known to be
unreliable on 2.1p2 — the [hydra driver](../drivers/case-studies/hydra.md) carries a three-method
detect for the same reason.

**Fix — register the board by more than one method:** try `autocon()` first, then a **chipset-gated
probe of the board's known fixed base** accepted only if a presence register reads a valid value (so an
absent board can't false-positive), then a `driver.conf` **`probe=` fallback hook**. On the Z3660
piscsi driver this multi-method detect is exactly what carried the first real-hardware boot past the
silent banner ✅. Full story on [the Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md); the
chipset (AGA/ECS) gate is shared with [the A4091 driver](../drivers/a4091-53c710-driver.md).

### 16. On an emulator, "the machine hung" ≠ "your driver hung" ✅

A board can appear to **boot and then hang** with a brand-new driver as the obvious suspect — and be
innocent. Bringing up the [Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md) on real
hardware, the box booted and then froze; the cause was the Z3660's **firmware 68k emulator core**
faulting while demand-paging the driver's *own* text back in (two MMU exception-frame bugs), **not**
the driver — which was carrying every disk transfer byte-perfectly ✅. On an emulated 68k the "CPU" is
itself software, so a crash there presents identically to a driver lock-up.

**Triage method:** combine **kernel-side serial instrumentation** (prove your transfers completed and
were byte-correct) with **core-dump analysis** (`adb` / capstone disassembly of where the "CPU"
actually died) to isolate the fault to the emulator rather than the driver, *before* rewriting working
driver code ✅. The emulator fixes themselves are owned by the Z3660 firmware repo; the durable lesson
here is the triage discipline. The emulator-side mechanism — 68030 bus-error-frame semantics on the
demand-paging path — is documented on [Emulation Fidelity](emulation-fidelity.md).

### 17. An instruction-batching emulator can hang the SCSI bootstrap 🟡

Amix's **A3000-mainboard SCSI** bootstrap is driven by an **INT2** (level 2) interrupt during the
earliest kernel startup, *before* the banner. An emulator that, for throughput, runs several guest
instructions between checks of the interrupt line raises the worst-case **INT2-detection latency** to
roughly that batch size — and if the batch is too coarse the bootstrap is starved of timely service
and **hangs before the banner** 🟡 (a pre-banner stall, distinct from the demand-paging faults in #16).
On the Z3660's emulator this is exposed by a `service_cadence N` knob (instructions per
interrupt-service poll, default 1): cadence 2 and 4 boot, but cadence 8 hangs the SCSI bootstrap, so
the Amix-safe value is `service_cadence 4` (raise it only after boot). The knob mechanics are ✅; the
INT2-latency attribution and the exact boundary are an author hardware sweep 🟡. Full story on
[Emulation Fidelity](emulation-fidelity.md#scsi-int2-interrupt-latency-a3000-mainboard-bootstrap).

### 19. mount(2) silently stacks mounts (a fake broken-umount) ✅

`mount(2)`'s **only** busy check is `v_vfsmountedhere` on the vnode `lookupname` returns — but for a
directory that is *already* a mount point, `lookupname` **traverses into** the mounted filesystem,
whose root has that flag clear ✅. So a second identical `mount` of the same media on the same
directory **returns 0 and stacks a second layer**; a later `umount` pops exactly one layer and also
returns 0, while the disc appears "still mounted." This imitates a **broken `umount`** so convincingly
that it was chased as one (a direct `umount(2)` probe returned 0 with the filesystem apparently still
there) — the real bug was silent stacking on repeated mounts ✅. Stock filesystems guard this in their
*own* mount op (`prmount`/`fdmount` refuse when the covered vnode has `v_count > 1` or `VROOT`), and an
in-kernel filesystem must do the same (return `EBUSY` on the second mount). **Diagnostic:** count the
fstype's lines in `/etc/mnttab` — duplicates are the smoking gun. Full contract on
[the driver model](../drivers/driver-model.md#writing-an-in-kernel-filesystem-the-svr4-vfs_mount-contract).

## Time & Y2K quirks

### 7. Y2K: `setclk` and the kernel's 1999 date cap ✅/🟡

Amix has **two** millennium problems ✅/🟡:

1. The `setclk` utility uses a `%02d` format for the year, so it mishandles dates ≥ 2000.
2. The **kernel caps the date at 1999** — even the finishing-touches install step (`amixadm`) only accepts a date **≤ 1999** ✅.

These are **community-patched** ✅/🟡: applying the patch disk (which upgrades to **2.1p2a / kernel 2.1c**) ships Y2K fixes, after which you run the corrected `setclk` ✅. See the patch mechanism in [the patch ADF anatomy](../boot-disks/anatomy-patch-adf.md) and the version timeline in [versions](../reference/versions.md).

### 20. Password expired is the future-lastchg check, never set the RTC forward ✅

An SVR4 box whose RTC battery is dead boots believing it is **January 1978** (~day 2923 of the Unix
epoch). If a previous session ever "fixed" the clock by **setting it forward**, that stamped
`/etc/shadow`'s `lastchg` field far in the future (e.g. 8117 = 1992). On the next cold boot — back at
1978 — `lastchg` is now **in the future relative to "today"**, and SVR4 `login` treats a future
`lastchg` as **expired**, forcing a password change at every login ✅. This is the *future-dated*
check, **not** the max-age rule, so it recurs on every 1978 boot and stalls `amixrun.py`-style
automation at the password dialog. Root-caused on a real A4000 + Z3660 after it cost hours and a full
lockout ✅.

**Reliable fix at the prompt:** set the new password to the **same value** (SVR4 accepted a 4-char root
password here); with the clock at 1978 the new `lastchg` (~2923) is not future-dated, so it does not
recur. **Do NOT "fix" it by setting the RTC to now** — that re-arms the trap for the next cold boot ✅.
The deep fix for a golden image is to set `lastchg` to a **pre-1978 value offline**. (This is a
distinct problem from the [Y2K/`setclk`](#7-y2k-setclk-and-the-kernels-1999-date-cap) cap above —
here the danger is setting the clock *forward*, not past 1999.)

## X11 & desktop quirks

### 9. The X keymap is wrong 🟡

Under X11 the default keymap is mis-mapped 🟡:

- **y and z are swapped.**
- **`/` is produced by SHIFT-8.**

There are other X annoyances in the same family — `xload` crashes and the X11R4 server leaks memory 🟡. The modern RTG path ([Xrtg / VA2000](../drivers/x11-rtg-drivers.md)) sidesteps the old server but not the keymap mapping itself. Full X11 notes (mono `tvtwm`, A2410 color via TIGA, OpenLook font-path breakage on the R5 upgrade) are in [X11 & desktop](x11-and-desktop.md).

## Userland & packaging quirks

### 10. `amixpkg` is install-media-only, and its "broken" reputation is partly a data defect ✅/🟡

The **`amixpkg` wrapper** is **not present on the installed system at all** ✅ — it lives only on the
`root.adf` install media, where it drives the whole distribution install (`amixpkg -i -m -d -r /mnt -y
standard`) ✅ via the same `/var/sadm` machinery as `pkgadd`. So its long-standing "widely reported
broken" reputation 🟡 is **not** about a flaky command you run day-to-day (you can't — it isn't
installed); the raw SVR4 tools that *are* installed (`pkgadd`/`pkgrm`/`pkgmk`/`pkgtrans`/`pkginfo`)
work. A large part of the "package tools are broken" lore is instead the concrete, reproducible defect
in the next item. A separate build-side gotcha: `pkgproto` omits symlinks 🟡. Full internals on
[package management](package-management.md); install flow in [the install walkthrough](../getting-started/install-walkthrough.md).

### 18. The stock package database is corrupt out of the box ✅

On a clean Amix 2.1c image, **`pkgrm <anything>` and `pkginfo -l <anything>` abort immediately** ✅
with `ERROR: bad read of contents file … problem=unknown ftype`. The cause is a single malformed
record in the `/var/sadm/install/contents` package database: an X11R5 font file **named with a space**
(`…/MacFS/TrueType Fonts`). Because `contents(4)` is whitespace-delimited with no quoting, the parser
ends the pathname at the space and reads the next word as the file-type field — which is invalid — so
every tool that fully parses the database aborts ✅. Deleting that one line makes both `pkgrm` and
`pkginfo -l` work again (and the DB is world-writable, so the fix needs no special privilege beyond
root's normal access) ✅. This is a strong candidate for much of the "Amix package tools are broken"
reputation (quirk 10). Full diagnosis and the fix on
[package management](package-management.md#the-space-in-a-pathname-defect).

### 12. `/bin/sh` is pre-POSIX ✅

Amix's **`/bin/sh` predates POSIX** ✅. The two bites that catch driver authors and scripters:

- **No command substitution with `$(...)`** — you must use backticks `` `...` ``.
- **No `grep -q`** — redirect to `/dev/null` and test `$?` instead.

This was discovered the hard way porting the [VA2000 driver](../drivers/case-studies/va2000.md): install scripts written with modern shell syntax silently misbehave ✅. The default *interactive* shell is **ksh** (with `sh`/`csh`/`tcsh` also present), but build and install scripts that run under `/sbin/sh` or `/bin/sh` must stay pre-POSIX ✅. See [the driver model](../drivers/driver-model.md) and [writing a char driver](../drivers/writing-a-char-driver.md) for the driver-build implications, including the companion rule to `rm -f` stale objects before relinking the kernel.

Five more that specifically bite installer/automation scripts, each bench-proven on Amix 2.1c ✅:

- **`while read … done < FILE` runs in a SUBSHELL** — a counter incremented inside the loop reverts to its pre-loop value at `done`. Write per-iteration state to a temp file and read it back *after* the loop.
- **An empty `set -- \`cmd\`` is a no-op on `$@`** — if the command prints nothing, `$#` keeps its *previous* value instead of going to 0. Guard with `[ -s file ]` before counting.
- **`mkdir -p` is not idempotent** — it exits rc=2 "File exists" on an already-present leaf directory, not 0. Guard with `[ -d dir ] || mkdir -p dir`.
- **`wc -c` LEFT-PADS its count** with spaces, so a raw `wc -c` in a numeric test fails; strip the padding (e.g. via `read`) first.
- **The console tty truncates canonical input at ~256 characters** — long one-liners are silently cut. Push a script file and run it rather than typing a long command.

And the toolbox is thin: an install **miniroot ships no `basename`/`sed`/`touch`/`date`/`wc`**. The portable substitutes are `expr` (for `basename`-style path/field work), `: > file` (for `touch`), and `set …/*; echo $#` (to count matches).

### 21. A colon-less zoneinfo `TZ` crashes every `tzset()` caller ✅

A `/etc/TIMEZONE` that sets `TZ=US/Eastern` **without a leading colon** makes every SVR4 program that calls `localtime()`/`tzset()` die with `User BUS ERROR at 474D5400` ✅ — and `0x474D5400` is ASCII `"GMT\0"`, the GMT-fallback timezone abbreviation being dereferenced *as a pointer* after the POSIX-rule parser chokes on the `/` in the zone name. The fix is the **colon** form, `TZ=:US/Eastern`, which tells SVR4 to load `/usr/lib/locale/TZ/US/Eastern` as a tzfile path instead of parsing it as a rule (a valid POSIX rule string such as `EST5EDT` or `GMT0` also works — the stock golden uses `TZ=:EET`, always the colon form). The crash set is exactly the localtime callers — `date`, `who -r`, `cron`, `sac`, `ls -l` — while console `login` survives (it needs `getpwnam`, not localtime), which is the tell that distinguishes this from the passwd-side defect. Second-order symptom: a crashed `who -r` empties the positional parameters in the `/etc/rc2.d/S*` scripts that begin `set \`who -r\``, so those degenerate into `test: unknown operator S` at boot. Note this is a **constant** fault address at cold boot — do not confuse it with the emulator's variable-address MMU-frame bus errors ([emulation fidelity](emulation-fidelity.md)).

### 22. Reused writable test media accumulates state that masks bugs ✅

A defect can hide for entire test campaigns because a *reused* piece of writable media carries residue from earlier runs. The concrete case: a from-scratch install died on the real hardware with `pkgadd: ERROR: unable to open mount table (/etc/mnttab)` — a freshly built miniroot ships no `/etc/mnttab` and its bare `mount(2)` writes none. Two prior emulator acceptance passes had gone green only because the **reused** root floppy still held an `/etc/mnttab` that a `cdfs` mount had written in an *earlier, unrelated* run. The rule: **acceptance runs must start from fresh media**, because reused writable media silently accumulates state that can satisfy a broken assumption and mask a whole class of defect until the day the media is clean. (The mnttab consumer requirement itself is quirk-adjacent — see [package management](package-management.md).)

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
- BlitterStudio/amiberry issue #1376 and WinUAE/FS-UAE docs (emulation consequences of the SCSI IDs and RAM ceiling).
- The A4091-on-Amix project — networking investigation, 2026-06-07 (reproduced locally ✅): instrumented `/etc/rc2` per-script timing on Amix 2.1c under Amiberry isolated `S69inet` at 180 s; boot **210 s → 29 s** after switching the boot-time `ifconfig`s to literal IPs. Files: `/etc/rc2.d/S69inet`, `/etc/inet/network-config`, `/etc/inet/rc.inet` on the running system (quirk 13).
- The amix-z3660net project — the `z3660eth` driver bring-up on a real A4000 + Z3660, 2026-06-21 ✅: the firmware INT6-per-RX-frame storm (Amix has no level-6 ethernet handler) and the disable-IRQ/poll fix (`ZZ_CONFIG_DISABLE`, `timeout()` RX drain), diagnosed via the firmware serial `[PC]` heartbeat + `nm` of `relocunix` (quirk 14). See [the Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md).
- The amix-z3660scsi project @ `8ea1605` — the `z3660` piscsi block-driver bring-up on a real A4000 + Z3660, 2026-06-12/13 ✅: the 2.1 `bootinfo.autocon[]` miss and the multi-method detect that cleared the silent hang (quirk 15), and the firmware-emulator-vs-driver triage (quirk 16 — the apparent hang was the 68k emulator demand-paging the driver's own pages, not the driver; firmware-owned fix, cited not reproduced). See [the Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md).
- Research brief §19 (emulation fidelity), from the Z3660 firmware project (branch `amix-main`, 2026-06) — quirk 17 (the A3000-SCSI bootstrap's INT2 sensitivity to interrupt-service cadence; the `service_cadence` knob ✅ / the 4-boots-8-hangs boundary 🟡) and the emulator-side mechanism behind quirk 16 (68030 bus-error-frame fidelity on the demand-paging path). See [Emulation Fidelity](emulation-fidelity.md).
- Research brief §20 (stock SVR4 package system), from the amix-packagemanager project (firsthand on a clean Amix 2.1c image, 2026-07-01) — quirk 10's `amixpkg`-is-install-media-only correction ✅/🟡, and quirk 18 (the `/var/sadm/install/contents` space-in-pathname record that breaks `pkgrm`/`pkginfo -l` out of the box, ✅). See [Package management](package-management.md).
- The **amix-cdfs** project @ `31e8c3b` — quirk 19 (`mount(2)` silently stacks on an already-mounted directory; `mount(2)`'s only busy check is `v_vfsmountedhere`, which `lookupname` clears by traversing into the mount; guard in the fs's own mount op like `prmount`/`fdmount`), from stock-kernel disassembly + reproduction on a real A4000 + Z3660, 2026-07-13 ✅ (`844c2ed`). See [the driver model](../drivers/driver-model.md#writing-an-in-kernel-filesystem-the-svr4-vfs_mount-contract).
- The **amix-kerntools** bench forensics @ `8a76775` — quirk 20 (SVR4 `login`'s future-`lastchg` "expired" trap on an RTC-1978 box after a clock was set forward; same-password workaround, never set the RTC forward), root-caused on a real A4000 + Z3660, 2026-07-11 ✅.
- The **Installer-NG** Waves 5–6 field campaign (amix-installng @ `7106f1b`, amix-packagemanager @ `4539ad2`), 2026-07-22/24 — a blank-disk→bootable-install effort that root-caused these platform behaviours on the Amiberry bench and the real A4000+Z3660 (acceptance-run captures, s5/UFS state reads, and the on-metal digest attestation) ✅ (🟡 where tagged).
