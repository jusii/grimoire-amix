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
| 2 | **16 MB Fast RAM ceiling**; more mis-maps the SCSI drive. A second, far-higher limit — total *describable* RAM, ≈64 MB on a stock 030 kernel, set by a fixed 4 MiB kernel arena — fails **silently** (no output at all) | ✅ | [Hardware](hardware.md), [RAM ceiling](ram-ceiling.md) |
| 3 | **Stock Amix is Zorro II only** — stock drivers can't address Zorro III; but a purpose-written driver that maps the board (`sptalloc`, or a window inside the identity-mapped low 1 GB) **can** — see the [A4091](../drivers/a4091-53c710-driver.md) & [Z3660](../drivers/z3660-ethernet-driver.md) drivers | ✅ | [Hardware](hardware.md), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 4 | **No 68040/68060** → the A4000 can't officially run Amix | ✅ | [Hardware](hardware.md), [040/060 status](68040-68060-status.md) |
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
| 21 | **A colon-less zoneinfo `TZ` crashes every `tzset()` caller** — `TZ=US/Eastern` gives `User BUS ERROR at 474D5400` (= ASCII `"GMT\0"` dereferenced as a pointer) in `date`, `who -r`, `cron`, `ls -l`…; use the colon form `TZ=:US/Eastern` | ✅ | [Quirks §21](#21-a-colon-less-zoneinfo-tz-crashes-every-tzset-caller) |
| 22 | **Reused writable test media accumulates state that masks bugs** — acceptance runs must start from fresh media; two green passes were green only because a reused root floppy carried an `/etc/mnttab` written by an earlier, unrelated run | ✅ | [Quirks §22](#22-reused-writable-test-media-accumulates-state-that-masks-bugs) |
| 23 | **`inetd` disables a service after 40 connections in 60 s** — that port answers `Connection refused` while every *other* port, ICMP and the console stay healthy; it re-enables itself within 10 min. No config knob exists (`nowait.N` is silently ignored). Diagnosis: port 21 open + port 23 refused ⇒ throttle | ✅ | [Networking](networking.md#the-inetd-anti-looping-throttle--one-service-refuses-connections-while-the-box-is-healthy) |
| 24 | **`syslogd` ships deliberately disabled** — a vendor `exit` on line 8 of `/etc/init.d/syslogd`, so every `daemon.*`/`auth.*` message on the box is discarded. One commented-out line enables it; this SVR4 logs to `/var/log/*`, **not** `/var/adm/messages`. ⚠ that file is one inode with 3 hard links — edit with `cp` in place, never `mv` | ✅ | [Networking](networking.md#why-it-is-silent-syslogd-ships-deliberately-disabled) |
| 25 | **A hand-written UAE-family `.uae` selects the cycle-exact 68030 core and Amix dies at PID 1** — omitting `cycle_exact` is not neutral, the default is `true` (and host-dependent). Pin `cycle_exact=false`; it also silently overrides `cpu_compatible=false` | ✅ | [Emulation fidelity](emulation-fidelity.md#the-cycle-exact-core-a-correct-emulator-default-that-amix-does-not-survive), [Amix on Amiberry](../getting-started/emulation-amiberry.md) |
| 26 | **Three diagnostic tools lie or don't work**: `netstat -a` prints `corrupt control block chain` on a perfectly healthy box; `sar -v` fails `sadc: Not enough space`; `ipcs -a` fails `read error: No such device or address`. Don't chase any of them, and don't budget on them for a capture | ✅ | [Quirks §26](#26-three-diagnostic-tools-that-lie-or-do-not-work) |
| 27 | **`dd skip=` on a `cdfs` file is not an effective seek** — the skipped bytes are really transferred, through the one-sector in-kernel SCSI path, so a read at the 1 GiB mark needs ~20 minutes. Never score that timeout as a read failure | ✅ | [Quirks §27](#27-dd-skip-on-cdfs-is-not-a-seek), [Filesystems & disks](filesystems-and-disks.md#mounting-a-cd) |
| 28 | **The partitioning tools' units are all 512-byte blocks, and `rdb`'s usage text omits the flags that matter** — `rdb -c` requires a `-d disksize` its usage block never mentions; `rdb -p` wants a 1-based partition *number* (a device path `atoi()`s to 0 and is refused); `mkfs_s5`'s size operand is 512-byte blocks (pass a pre-converted 1 KB count and the filesystem covers half the slice) | ✅ | [Filesystems & disks](filesystems-and-disks.md#etcrdb-and-mkfs_s5-the-grammar-and-the-units) |
| 29 | **The stock kernel writes motherboard register `0xde0002` at every boot and at reboot/halt** — on the A3000 that is the SuperKickstart re-kick bit; on an A4000 the same address is Fat Gary's coldreboot latch, which nothing consumes, so the write is benign. Don't chase it in bus traces or emulator logs; decode-and-ignore is the correct model for an A4000 target | ✅ | [Quirks §29](#29-the-kernel-pokes-the-a3000-re-kick-register-0xde0002-at-every-boot-and-reboot) |
| 30 | **A scripted `ed` edit that misses its address search still writes the file** — earlier inserts in the same body stay applied, and a name-wide `grep` guard then reports "already patched" forever: a permanent, invisible half-patch. Pre-probe the target row, one `ed` run per edit, post-verify the row — never trust `ed`'s exit status alone | ✅ | [Quirks §30](#30-a-scripted-ed-edit-that-misses-its-address-still-writes-the-file), [Kernel build](../drivers/kernel-build.md#scripting-the-kernelc-edits-with-ed--the-half-patch-trap) |
| 31 | **On an FPU-less part, floating point dies as SIGSYS ("Bad System Call", exit 140)**, not SIGILL/SIGFPE — and it dies in *libc*: `_doprnt` carries FP on its `%e`/`%f`/`%g` paths, so any program that **prints** a float dies even if its own code is FP-free (`df -k`, `uptime`). `__fpstart` is FP-safe, so everything else runs. Triage rule: *does it print a float?* | ✅ | [Quirks §31](#31-on-an-fpu-less-part-floating-point-dies-as-sigsys-bad-system-call-), [040/060 status](68040-68060-status.md) |
| 32 | **`awk` is always a floating-point program** — it holds every number as a C `double`, so on an FPU-less part it dies even on `1+1`. An awk failure on integer arithmetic is not evidence of a second defect | ✅ | [Quirks §32](#32-awk-is-always-a-floating-point-program-) |
| 33 | **68060: the FP-disabled frame's stacked "Next PC" is software-maintained** — Motorola's own support package recomputes it from its own decode and treats the faulted-PC slot as the authority. A handler must resume on a PC it computed itself | 🟡 | [Quirks §33](#33-68060-the-fp-disabled-frames-next-pc-is-software-maintained-) |
| 34 | **68060: immediate `#<data>` is the one F-line operand the hardware cannot size** — its length lives in the FP command word a disabled FPU has no reason to decode, so the stacked next-PC can be short by the operand's width | 🟡 | [Quirks §34](#34-68060-immediate-data-is-the-one-f-line-operand-the-hardware-cannot-size-) |
| 35 | **A zero from a counter behind a gate is not evidence the gate was reached** — every never-engage counter needs a pre-gate denominator census, and the regression bar must name which counters are exempt | ✅ | [Quirks §35](#35-a-zero-behind-a-gate-needs-a-pre-gate-denominator-) |
| 36 | **An optimised probe that reports "no fault" must be disassembled before it is believed** — the compiler may have constant-folded the faulting instruction away entirely, so the negative is the compiler's answer, not the silicon's | ✅ | [Quirks §36](#36-an-optimised-probe-reporting-no-fault-must-be-disassembled-first-) |
| 37 | **A one-byte binary diff is not understood until the byte is decoded** — two kernels differed by one byte and that byte was a table row-count *bound*, gating a driver that sat outside the compared window; "the code is identical, so it's the environment" was wrong. Decode what the byte does before concluding | ✅ | [Quirks §37](#37-a-one-byte-binary-diff-is-not-understood-until-the-byte-is-decoded-), [Kernel composition](../drivers/kernel-composition.md) |
| 38 | **`uptime` and `w` do not report the machine's load** — the reader resolves a COMMON kernel symbol to a non-address without an error (flat `0.00` and absurd millions are the SAME defect), and even the kernel's own count reads exactly N−1 (the on-CPU process is never counted). Read the truth with `adb -k <running-kernel> /dev/mem`, `avenrun/3X`, ÷256 | ✅ | [Load averages](load-averages.md) |
| 39 | **A bare trailing `&` in a command sent to the box's telnet transport silently never runs** — the transport appends `; echo DONE_$?` for completion detection, so `<cmd> &` arrives as `<cmd> &; echo …` and `&;` is a Bourne syntax error: the job never starts, the retries re-login into the [inetd throttle](#23-inetd-disables-a-service-after-40-connections-in-60-seconds), and any poller waiting on it spins forever. Parenthesise the background launch: `(… &)` | ✅ | [Quirks §39](#39-transport-ampersand-law) |
| 40 | **Amix keeps no persistent boot log** — no `dmesg` at all, `wtmp` has never recorded a reboot, and boot `fsck` writes only to the console (a delta to quirk 24, independent of `syslogd`). The console is the only record — and it still holds the whole boot transcript at a fresh `login:` prompt. Plan an HDMI capture; there is no log to read | ✅ | [Quirks §40](#40-no-persistent-boot-logging) |
| 41 | **Stock `autocon()` decides whether the A3000 internal SCSI exists from the *RAM size*, not from the hardware** (`end > 0x07000000`) — wrong in both directions: it fabricates a phantom card 0 where there is no controller, and it silently drops the real one (root disk included) on a machine whose RAM does not reach the threshold, renumbering every remaining SCSI card | ✅ | [Quirks §41](#41-scsi-by-ram-size), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 42 | **When you move a boundary, sweep the neighbours and ask what each one is sized by** — "what else assumes 4 MiB?" finds the constants derived from the thing you moved and misses the neighbour sized from somewhere else entirely | ✅ | [Quirks §42](#42-neighbour-sweep-law), [RAM ceiling](ram-ceiling.md) |
| 43 | **`nm` plus relocation similarity is not enough to place a binary patch** — the disassembly diff is a mandatory third gate; locate every site by *instruction context*, never by a remembered offset | ✅ | [Quirks §43](#43-disassembly-diff-gate) |
| 44 | **On-box `adb -k` needs a namelist that still has a symbol table** — `elf2brel` discards symtabs, so `/stand/unix` is useless as a namelist and `adb` reports nonsense instead of failing | ✅ | [Quirks §44](#44-adb-namelist) |
| 45 | **Heavy raw `dd` to the boot slice can spontaneously reboot the box** — the session dies mid-write and looks like a failure. Trust the verify line the job wrote *to disk*, not the session that vanished | ✅ | [Quirks §45](#45-boot-slice-dd) |

The rest of this page expands each item.

## Hardware & addressing quirks

### 1. SCSI IDs: tape fixed at 4, disk 6 by convention ✅/🟡

The **tape drive must sit at ID 4** — the root-floppy install scripts hard-reference the literal `/dev/rmt/4h` and look nowhere else for it ✅. The **hard disk is ID 6 by convention**, not by kernel mandate: the installer *prompts* for the disk target and computes the boot partition from a `$SCSI` variable (`BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`), reserving only ID 4 for the tape — so Amix will install on a disk at another target 🟡. The catch is that the chosen ID is baked into the device names (`c6d0s…`) the installed system records in `/etc/vfstab` (the SVR4 mount table) and the boot partition, so **you can't change the disk's SCSI ID after install** without editing `/etc/vfstab` to match 🟡 ([`amix_21_root.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh`; see [hardware](hardware.md#scsi-target-ids)).

**Consequence for emulation:** attach your tape image at SCSI ID 4 (the installer looks only there) and your hardfile (RDB) at SCSI ID 6 — any target works for the disk, but 6 is the convention and saves you re-pointing `/etc/vfstab` later. See the mapping in [the WinUAE setup](../getting-started/emulation-winuae.md) and [the FS-UAE setup](../getting-started/emulation-fs-uae.md). Disk geometry and partitioning are covered in [filesystems & disks](filesystems-and-disks.md).

### 2. The 16 MB Fast RAM ceiling ✅

The kernel hard-codes a Fast RAM ceiling of **16 MB** (minimum 4 MB) ✅. Going **above 16 MB mis-maps the SCSI drive** ✅ — the symptom is disk corruption / failure rather than an honest "too much RAM" error, which makes it a nasty trap. Set your emulator's Fast RAM to **≤ 16 MB**. Background in [hardware](hardware.md).

### 3. Zorro III — stock drivers are Zorro II only ✅

**Stock** Amix is **Zorro II only** ✅: its stock drivers simply dereference the address `autocon()` returns, which only reaches Zorro II boards (≤ 24-bit, inside [the identity-mapped low 1 GB](../drivers/zorro-autoconfig.md#the-identity-map)), and that kernel source was never shipped so the *stock* card set can't be patched in place. This is **not** absolute for a *purpose-written* driver, though: one that maps the board explicitly — the kernel's `sptalloc()` primitive, or (when the board's window happens to fall inside the identity map) a direct mapping — **can** reach a Zorro III board. The [A4091 SCSI driver](../drivers/a4091-53c710-driver.md) (🟡 emulation) and the [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) (✅ real hardware) both do exactly this. For ordinary expansion, still assume a card must present a Zorro II window; see [Zorro autoconfig](../drivers/zorro-autoconfig.md) for how boards are discovered via the AUTOCONFIG / `autocon()` path, and [hardware](hardware.md) for the supported-board list.

### 4. No 68040/68060 — the A4000 is out ✅

The kernel **predates the 68040 MMU** ✅, so it runs only on a **68020 or 68030 with a real MMU plus a 68881/68882 FPU** ✅. There is no soft-float and the MMU-less `68EC020/030` variants cannot run Amix ✅. Practical upshot: an **A4000 cannot officially run Amix** ✅. Targets are the A3000(UX) and the A2500UX. See [hardware](hardware.md); for what 040/060 support would actually require and the current state of work toward it, see the [040/060 status page](68040-68060-status.md).

### 5. Superkickstart dual-boot via the right mouse button ✅

A3000UX machines ship a **"Superkickstart 1.4"** bootstrap ROM ✅. At power-on:

- **Default** (do nothing) → boot **Amix** from the SCSI disk.
- **Hold the right mouse button** at power-on → load an **AmigaOS Kickstart** instead.

So the "gotcha" is the inverse of what AmigaOS users expect: the machine boots Unix by default, and you reach AmigaOS only by holding a mouse button. Details in [the boot process](boot-process.md).


### 29. The kernel pokes the A3000 re-kick register `0xde0002` at every boot and reboot ✅

The stock Amix kernel writes motherboard address **`0xde0002`** unconditionally — once in its boot
path and again in its reboot/halt path ✅. What that write means depends on the machine:

- **A3000 — the SuperKickstart re-kick control.** Bit 7 of `0xde0002` (a Gary register, flanked by
  the bus-timeout controls at `0xde0000`/`0xde0001`) arms a **hard re-kick**: the next reset
  re-enters the bootstrap ROM and reloads the soft Kickstart from disk instead of warm-starting the
  RAM-resident image ✅. This is public, non-Amix hardware knowledge — Linux/m68k performs the
  identical write (`0xde0002 |= 0x80`) on A3000-class machines and names the mechanism "Magic Hard
  Rekick". On a SuperKickstart machine that is the right bit for a Unix to arm — see
  [Superkickstart dual-boot](#5-superkickstart-dual-boot-via-the-right-mouse-button) and
  [the boot process](boot-process.md).
- **A4000 — an unconsumed latch.** The same address decodes to **Fat Gary's coldreboot/re-kick
  latch** (the same bit-7 convention), but an A4000 boots Kickstart from real ROM — there is no
  soft-Kickstart machinery, and **nothing on the machine consumes the latch** ✅. The write
  terminates normally and has no effect. UAE-family emulators model it accordingly: a settable,
  readable bit-7 "coldreboot flag" with no consumer ✅.

The gotcha is diagnostic: the poke surfaces as an unexplained motherboard-register write in bus
traces, emulator logs and disassemblies — on exactly the machine family (A4000-based rigs) where
the register does nothing, which invites chasing it as the cause of whatever else is wrong. Don't:
on this project's A4000 the write is exercised on **every** metal boot — the accelerator forwards
it to the physical bus, where the real Fat Gary latches it — with no ill effect ✅. For emulator
and bus-bridge authors the only requirement is to *tolerate* the access (decode-and-ignore is
correct for an A4000 target; only an A3000 SuperKickstart model needs to honour the bit). And don't
confuse this motherboard address with the similar-looking AutoConfig product code `0xc0de0002` in
[the major-number registry](../reference/major-number-registry.md) — they are unrelated.

### 41. The stock kernel infers the A3000 SCSI from the RAM size ✅ {#41-scsi-by-ram-size}

Stock `autocon()` (`amiga/kernel/support.c`) decides whether the A3000 internal SCSI controller
exists by testing **how far RAM extends** — `end > 0x07000000` — and not by touching the hardware ✅.
The A3000 controller is not an AutoConfig board, so there is nothing in `bootinfo.autocon[]` to look
at; the RAM size was used as a proxy for "this is an A3000-class machine". It is a guess, and it is
wrong in **both** directions:

- **False positive.** On a machine with no internal SCSI — a real A4000, or an A3000 whose controller
  is absent — enough RAM fabricates a **phantom card 0** at `0xDD0000`. It claims `queue[0]`, shifts
  every real controller up by one, and the compiled-in root device (which decodes to card 0) sends
  the root read to hardware that does not exist ✅. This is the failure that produced the
  `s5mountroot VOP_OPEN error 5` → `errno 89` panic chain; full story on
  [the boot process](boot-process.md) and [Zorro autoconfig](../drivers/zorro-autoconfig.md).
- **False negative.** On a machine whose RAM does **not** reach the threshold, the same test fails and
  the **real** internal SCSI is silently dropped — root disk included — and every remaining SCSI card
  renumbers ✅. Nothing is logged; the machine simply cannot find its disk.

Real A3000s with more than 16 MB are inside the affected envelope ✅ — this is not an
emulator-only curiosity.

**The law: probe, don't guess.** The fix that replaced the special case is a **chipset gate plus a
WD33C93 write/readback probe** — read a custom-chip register that is always present to tell an
ECS/OCS (A3000-class) machine from an AGA one, then write two different values to two WD33C93
registers through the same data port and read the first back, so an open bus (which aliases the read
to the *last* write) cannot pass ✅. Full source and rationale on
[Zorro autoconfig](../drivers/zorro-autoconfig.md); the anti-alias readback is the reference design
for [any board probe](../drivers/kernel-composition.md).

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

### 23. `inetd` disables a service after 40 connections in 60 seconds ✅

A port that answers **`Connection refused`** while ICMP, the console and *every other port* stay
healthy is almost never a wedge. SVR4 `inetd` counts invocations **per service entry** and, on the
40th inside a 60-second window, logs `<service>/<proto> server failing (looping), service terminated`,
closes the listening socket and arms a **600-second** re-enable alarm ✅. All three constants are
compile-time immediates in the shipped `/usr/sbin/inetd` — **there is no config knob**: the
`inetd.conf` wait field is parsed as a boolean, so the 4.4BSD `nowait.<max>` syntax is **silently
ignored** (tested: `nowait.100` + `SIGHUP` was accepted without complaint and still tripped) ✅.

Because the counter is per service, tripping telnet leaves FTP up and vice versa — which makes the
diagnosis one command: **port 21 answering while port 23 refuses ⇒ the throttle** ✅. Nothing needs
fixing; wait up to ten minutes. It only ever fires on **automation**: a harness that opens one telnet
(or FTP) session per command reaches 40 in a minute trivially. Hold one session open for a batch, keep
invocations under **~30 per 60 s per service**, or drive bulk work from an on-box script and poll at a
low rate. Measured: 29.9/min never tripped in 200 invocations; ~575/min tripped within seconds ✅.
Full mechanism, constants and the syslog story on
[networking](networking.md#the-inetd-anti-looping-throttle--one-service-refuses-connections-while-the-box-is-healthy).

### 14. An unhandled board interrupt storms the kernel ✅

A gotcha for **driver authors**, learned bringing up the [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) on real hardware: if a board (or its firmware) raises a CPU interrupt level for which **Amix installs no handler**, the unacknowledged source fires continuously and **hard-locks the machine** ✅. The Z3660 firmware raises Amiga **INT6 (EXTER)** on *every* received ethernet frame, but Amix has no level-6 ethernet handler — so the moment the interface came up, normal LAN **ARP broadcast traffic stormed INT6 and instantly froze the box** (caps-lock LED dead). The whole kernel had booted to `login:` fine; only bringing the interface up triggered it.

**Fix:** disable the board/firmware interrupt and **poll** the receive path instead — `z3660eth` writes the firmware's `ZZ_CONFIG_DISABLE` so INT6 is never raised, and drains RX from a clock-level `timeout()` callout ✅. Interrupt-driven RX would need a level-6 hook the firmware's model doesn't safely give Amix. The general lesson: when adding a driver, don't enable an interrupt source Amix can't service — confirm there's a handler (and an ack path) for that level, or run polled. Full story on [the Z3660 ethernet driver case study](../drivers/z3660-ethernet-driver.md).

## FPU & floating-point quirks

### 31. On an FPU-less part, floating point dies as SIGSYS ("Bad System Call") ✅

The F-line trap's stock mapping is **SIGSYS**, so an FP instruction on a part with no FPU exits 140
with `Bad System Call - core dumped` — a label that points a debugger at the syscall interface,
which is not involved. Anything grepping crash reports for illegal-instruction traps misses every
one of these. The reach is wider than "programs that compute with floats": libc's `_doprnt` carries
FP instructions on its `%e`/`%f`/`%g` conversion paths, so **any program that prints a float dies
inside libc** — `df -k` and `uptime` die in the print call, not in their own arithmetic. `__fpstart`
does not touch FP hardware, which is why everything else runs normally and the failure set is
exactly the float-printers. Because the whole class funnels through one libc path, one fix covers
all of it. Triage rule: *"program dies with SIGSYS in a print call" means FP-in-libc, not a syscall
bug* — ask "does it print a float?" before investigating anything else.

### 32. `awk` is always a floating-point program ✅

`awk 'BEGIN{print 1+1}'` dying on an FPU-less part looks like proof of a second, non-FP defect. It
is the opposite: awk holds every number as a C `double`, so it prints a float even for pure-integer
expressions. An awk failure on integer arithmetic is the *same* FP defect, not a new one.

## 68060 CPU quirks

### 33. 68060: the FP-disabled frame's "Next PC" is software-maintained 🟡

In the 68060's eight-word FPU-disabled exception frame, the stacked "Next PC" is **not** an
architectural guarantee that the CPU sized the faulting instruction: Motorola's own 68060 support
package builds and rewrites that field itself, from its own decode, and treats the
PC-of-faulted-instruction slot as the authority. Any handler for this frame should resume on a PC it
computed from its own decode and treat the stacked Next PC as advisory. (Tag stays 🟡: read from the
vendor package's source behaviour, not verified against the MC68060 User's Manual.)

### 34. 68060: immediate `#<data>` is the one F-line operand the hardware cannot size 🟡

For every F-line addressing mode except immediate data, instruction length follows from the
operation word alone. For `#<data>` the operand's byte count lives in the **FP command word's**
source-specifier field — precisely the field a *disabled* FPU has no reason to decode — so the
stacked next-PC can be short by the operand's width (an IEEE double immediate is 8 bytes the frame
never accounted for). This is the structural reason quirk 33's field cannot be trusted, and it names
the one instruction class where the discrepancy occurs.

## Diagnostics & logging quirks

### 24. `syslogd` is present, correct, and deliberately switched off ✅

The stock image has a complete, working logging system that never starts. `/usr/sbin/syslogd`, a valid
`/etc/syslog.conf`, all eight `/var/log/*` targets and `/dev/log` are present — but
**`/etc/init.d/syslogd` line 8 is a vendor-hardcoded `exit`** ✅, so the daemon is never started and
every `syslog(3)` message on the box is written into `/dev/log` with nothing reading it. The comment
above the line says so out loud: `#TO USE SYSLOGD, COMMENT OR REMOVE THE exit ON THE NEXT LINE:`.
Consequence: **every `daemon.*` and `auth.*` event this system generates is discarded**, which is why
failures like [quirk 23](#23-inetd-disables-a-service-after-40-connections-in-60-seconds) look
inexplicable. Note also that this SVR4 logs to **`/var/log/*`, not `/var/adm/messages`** ✅ — looking
for the latter finds nothing and yields the wrong conclusion ("this image has no syslog").

Enabling it is one commented-out line and needs **no** `/etc/syslog.conf` change (the stock
`*.notice;kern.none /var/log/notice` line already selects `daemon.err`) ✅. Measured cost across
23 minutes of deliberate abuse: one daemon and **293 bytes** total in `/var/log` ✅.

> 🔗 **Edit it with `cp` in place, never `mv`.** `/etc/init.d/syslogd` and `/etc/rc2.d/S70syslogd` are
> the **same inode** (3 hard links). `mv` replaces the file and silently breaks the `rc2.d` hook, so
> the fix works once and never again after a reboot ✅ — the same hazard as `S69inet`/`inetinit`.

### 40. Amix keeps no persistent boot log — the console is the only record ✅ {#40-no-persistent-boot-logging}

Quirk 24 is about `syslogd` shipping switched off. This is the **broader, orthogonal** fact it sits
inside: **Amix has no persistent boot logging at all, whether or not `syslogd` is ever turned on** ✅.
Three independent subsystems each drop their boot-time output on the floor, so "what happened when
this box last booted?" has no on-disk answer:

- **There is no `dmesg` on Amix** ✅. Unlike Linux or BSD, there is no kernel ring buffer to dump
  after the fact — the command and the facility simply do not exist. (Confirmed on a real box, and by
  zero `dmesg` hits anywhere in this corpus.)
- **`wtmp` has never recorded a single reboot — on any boot, ever** ✅. SVR4's login-accounting file,
  which `last`/`last reboot` read for boot history, holds **zero** reboot records across its whole
  life: its own header timestamp is *Mar 24 1992* and `last reboot` returns nothing. This is
  **independent of the syslogd question** — `wtmp` is a separate, always-on accounting mechanism, and
  it is still empty of boot history.
- **The boot-time root `fsck` leaves no on-disk trace by design** ✅. `/sbin/bcheckrc` discards its
  pre-check verdict to `/dev/null` and sends the real repair pass's output to the **console only** —
  no `tee`, no log file — so even a root-fsck repair, had one run, would leave zero evidence it
  happened.

The practical consequence: **for any "what happened at boot" question — a hang, a fsck repair, a
kernel's boot banner — plan for a passive HDMI console capture, because there is no log to read** ✅.
Turning `syslogd` on (quirk 24) does not fill this gap: it starts capturing *future* daemon/kernel
`syslog(3)` messages, a narrower channel than the raw console boot transcript. The one channel that
*does* survive is the physical console — and at a fresh login prompt the console has **not scrolled
past the boot transcript**: the visible frame still holds the first kernel line through to `login:`,
so a single passive HDMI capture at the prompt recovers the whole boot sequence with no login and no
keystroke ✅ (used exactly this way to answer a "did fsck run?" question with no other evidence
source). See [quirk 24](#24-syslogd-is-present-correct-and-deliberately-switched-off) for the
syslogd half and [networking](networking.md#why-it-is-silent-syslogd-ships-deliberately-disabled)
for its config.

### 26. Three diagnostic tools that lie or do not work ✅

Recorded so nobody re-chases them, and so nobody plans a capture around them:

- **`netstat -a` prints `corrupt control block chain`** — on a **fully healthy** box. A control run
  during a known-good session prints the identical message, so it is an Amix `netstat` limitation,
  **not** evidence of anything ✅. (`netstat -m` likewise answers
  `Memory information not currently supported`.) `netstat -in` and `netstat -rn` *do* work.
- **`sar -v` fails** with `sadc: Not enough space` ✅.
- **`ipcs -a` fails** with `read error: No such device or address` ✅.

The last two are pre-existing tooling gaps on the stock image, not symptoms — don't budget on them
when planning what to capture from a box in a bad state.

### 27. `dd skip=` on `cdfs` is not a seek ✅

SVR4 `dd`'s `skip=` on a `cdfs` file **really transfers** the skipped bytes rather than seeking past
them, and the in-kernel `cdfs` read path is capped at **one 2048-byte sector per SCSI transfer** (see
[the in-kernel DMA cap](../drivers/kernel-build.md#gotcha-in-kernel-scsi-dma-corrupts-transfers-larger-than-one-2048-byte-block)).
A read at the **1 GiB** mark of a large disc therefore takes **minutes of real transfer** — budget a
command timeout of about **20 minutes**, not the usual seconds ✅. This matters for scoring as much as
for patience: the first attempt at such a read was recorded as a **failure** purely because it hit a
300-second cap ✅. **Never score a timeout on a deep `cdfs` read as a read failure** — re-run it with
a real timeout before concluding anything.

### 35. A zero behind a gate needs a pre-gate denominator ✅

A lane that must never run on most rigs gets an entry counter that must read 0 — but a counter
placed *behind* the decline gate reads 0 both when the lane correctly declined and when the event
never arrived at all. The fix is a pre-gate census: count and classify every event ahead of the
arming test, so a zero on the behavioural counter is provably a *declined* path, not an *unreached*
one. The census counters are then expected to move everywhere — so the regression bar must exempt
them **by name**. *A zero from a counter behind a gate is not evidence the gate was reached.*

### 36. An optimised probe reporting "no fault" must be disassembled first ✅

A divide-by-zero probe built at `-O` reported "no trap" — because the binary contained no divide at
all; the compiler had constant-folded it. The negative was the compiler's answer, not the silicon's.
When any probe reports that *nothing happened*, prove the instruction exists in the binary before
believing the hardware. Build probes at `-O0`.

### 37. A one-byte binary diff is not understood until the byte is decoded ✅

A failing and a working kernel compared byte-identical across a megabyte of text except one byte —
and a window-compare around the faulting driver concluded "driver identical, so the environment is
the variable". Both halves true, conclusion wrong: the byte was the controller registry's row-count
**bound**, and the driver it gates sat outside the compared window. When a byte-compare turns up
exactly one difference, decode what that byte *does* before concluding anything.

### 38. `uptime` and `w` do not report the machine's load ✅

Two independent stock defects: `nlist(3)` cannot resolve `avenrun` (a COMMON symbol in the `ET_REL`
kernel) and *succeeds anyway* with the alignment as the value — so the printed number is whatever
sits at a bogus address, flat `0.00` and six-digit garbage being the same defect; and the kernel's
own load count omits the on-CPU process, reading exactly N−1 even when read correctly. Full story,
measurements and the working read recipe: [load averages](load-averages.md).

### 42. When you move a boundary, sweep the neighbours ✅ {#42-neighbour-sweep-law}

The instinctive search after moving a kernel constant is *"what else assumes the old value?"* — and it
finds every constant that was **derived from** the thing you moved. It does not find the neighbour
that is sized from somewhere else entirely, because that neighbour never mentions the old value at
all.

The worked case: moving the kernel's fixed 4 MiB arena upward found the constants sized from the
arena, and missed `segkmap` — the map between `kvsegmap` and `kvsegu` — which is sized from
**physmem**. Moving `kvsegmap` therefore silently *shrank* it ✅. The right question is not "what
assumes 4 MiB?" but **"for each neighbour of this boundary, what is it sized by?"** Ask it of every
neighbour, including the ones the grep did not return. Full context on
[the RAM ceiling](ram-ceiling.md#lifting-the-ceiling).

### 43. `nm` and relocation similarity are not enough to place a binary patch ✅ {#43-disassembly-diff-gate}

Two gates are commonly used to locate a patch site in a binary kernel: the symbol table (`nm`) says
which function you are in, and a relocation/similarity check says the surrounding bytes match what you
expected. Both can agree and both can be pointing at the wrong instruction — a neighbouring inlined
copy, a different call site of the same helper, a compiler-reordered sequence.

**The disassembly diff is a mandatory third gate** ✅: disassemble before and after, and read the
changed instruction. Every site in the RAM campaign was located by **instruction context**, never by a
remembered offset — offsets do not survive a rebuild, and an offset that is *nearly* right produces a
kernel that boots. This is the same family as [§36](#36-an-optimised-probe-reporting-no-fault-must-be-disassembled-first)
(prove the instruction exists before believing a negative) and
[§37](#37-a-one-byte-binary-diff-is-not-understood-until-the-byte-is-decoded) (decode the byte before
concluding).

### 44. On-box `adb -k` needs a namelist that still has a symbol table ✅ {#44-adb-namelist}

`adb -k` reads symbols from a **namelist file**, and on Amix the obvious candidate is the wrong one:
`/stand/unix` has been through `elf2brel`, which **discards the symbol table** ✅. Point `adb` at it
and you do not get a clean failure — you get resolutions that are silently meaningless.

Keep an unstripped namelist beside the kernel (`unix.namelist`, the pre-`elf2brel` object) and read
against that ✅. The rule generalises: on this platform, *the file you boot and the file you debug
against are two different files* — verify the one you hand a debugger actually has a symtab before
believing anything it prints.

### 45. Heavy raw `dd` to the boot slice can reboot the box ✅ {#45-boot-slice-dd}

A large raw `dd` to the boot slice can **spontaneously reboot the machine mid-write** ✅. Because the
reboot kills the session that issued the command, the operator sees a transport failure — a dropped
connection or a timeout — and the natural conclusion is that the write never happened.

**Trust the on-disk record, not the session.** Have the job write its own verify line to a file on
disk, and read that file on the next boot; the session's exit status is not evidence either way. The
general shape is worth naming: **an operation that destroys its own reporting channel always looks
like a failure** — and re-running it blindly is how a half-written boot slice becomes an unbootable
one.

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

### 30. A scripted `ed` edit that misses its address still writes the file ✅

Anyone scripting kernel-source edits (`master.d/kernel.c`, `master.d/filesys.c`, a subdir
Makefile) ends up pushing an `ed` heredoc — and its worst failure mode is silent ✅. When an
address search misses, `ed` prints `?`, but the commands that already ran stay applied to the
buffer and the trailing `w` still writes the file. Pair an insert with an address-searched change
in one body and a miss leaves the file **half-patched**: insert landed, row change never happened,
kernel builds and links, device never answers. If the wrapper's idempotency guard is a
**name-wide grep**, the surviving insert satisfies it, and every later run reports
already-patched — a permanent, invisible half-patch produced *and then defended* by the same
script ✅. Measured variants: a tag-addressed change **overwriting the wrong claimant's row** with
no error, and `ed`'s wrapping `/re/` search landing a table row **inside a different table**,
exit 0 ✅. `ed`'s exit status is a weak oracle (behaviour across `?` errors is not portable
between the host's GNU `ed` and the box's SVR4 `ed`, and a remote-shell transport can swallow it)
— the reliable mechanism is **pre-probe the exact target row before writing, one `ed` run per
edit, and post-verify the row in the file afterwards** ✅. The full failure catalogue and the
fail-closed verify-then-apply pattern are on
[building a kernel](../drivers/kernel-build.md#scripting-the-kernelc-edits-with-ed--the-half-patch-trap).

## Emulation & bench quirks

(Two more emulator gotchas live under driver authoring, because that is where they bite:
[16 — the machine hung ≠ your driver hung](#16-on-an-emulator-the-machine-hung-your-driver-hung) and
[17 — instruction-batching and the SCSI bootstrap](#17-an-instruction-batching-emulator-can-hang-the-scsi-bootstrap).)

### 25. A hand-written `.uae` selects the cycle-exact core, and Amix dies at PID 1 ✅

**Omitting `cycle_exact` from a UAE-family config does not leave cycle-exactness neutral — it selects
the cycle-exact 68030 core**, and an Amix guest does not survive it ✅. Amiberry's `default_prefs()`
initialises `cpu_cycle_exact`, `cpu_memory_cycle_exact` and `blitter_cycle_exact` **all `true`**, and
nothing in the plain config-load path lowers them; the only thing that does is a **host-side**
`default_disable_cycle_exact` in `amiberry.conf`, which itself defaults to false — so **the same
`.uae` can select different CPU cores on two machines** ✅.

The failure imitates a guest/driver/memory-map bug perfectly. The kernel boots, configures devices and
mounts root, and then PID 1 dies:

```text
NOTICE: User BUS ERROR at E0001770, PC:C100F35E FAULT:6 PID:1 CMD:/sbin/init
```

**Pin `cycle_exact=false`** — it is the one key that clears all three flags (`blitter_cycle_exact=false`
alone leaves the cycle-exact CPU enabled and fixes nothing) ✅. It also matters for a knob you thought
you had: `fixup_prefs()` forces `cpu_compatible = true` whenever memory-cycle-exactness is set, so
`cpu_compatible=false` silently does not take while the trap is armed ✅.

**There is a pre-boot host-log tell**: with sound disabled, the host log prints `Cycle-exact mode
requires at least Disabled but emulated sound setting.` **if and only if** the cycle-exact core
survived config load — grep for it before blaming the guest ✅. Why the cycle-exact core kills Amix
has not been root-caused; that it does is measured. Full mechanism on
[emulation fidelity](emulation-fidelity.md#the-cycle-exact-core-a-correct-emulator-default-that-amix-does-not-survive);
config keys on [Amix on Amiberry](../getting-started/emulation-amiberry.md).

### 39. A bare trailing `&` sent to the box's transport silently never runs ✅ {#39-transport-ampersand-law}

Every caller of the Amix command transport (`amixrun.py`, and grimoire's own
`tools/host-net/amixsh.py` — same wire protocol) sends a command over telnet as
**`<cmd>; echo DONE_$?`**, because a completion marker echoed back over the stream is the *only* way
the host side can tell a command has finished — there is no separate exit-status channel ✅. So a
command whose text **ends in a bare, unparenthesised `&`** (the shell background operator) arrives on
the box as **`<cmd> &; echo DONE_$?`** — and **`&;` is a syntax error in the SVR4 Bourne shell** the
box runs. The failure is silent on the host side: the marker never comes back, the transport's retry
logic fires up to three times — each retry a **fresh telnet login**, which counts against the
[inetd throttle](#23-inetd-disables-a-service-after-40-connections-in-60-seconds) — and **the job the
caller wanted backgrounded never starts at all** ✅. Any poll loop waiting on that job's output then
spins forever against a box where nothing is running.

This is not hypothetical — it was found as a **real defect twice, in two different repos, one day
apart** ✅: a soak harness's launch line ended in `&` and silently launched nothing (the harness then
read the idle box as healthy), and a *reboot*-soak's `/etc/shutdown -y -i6 -g0 … &` had the identical
defect in another repo, turning an entire reboot test into a scored-green no-op (the box never
rebooted; a weak "port 23 answers" check let the false pass through).

**The fix is to parenthesise the background launch** so the string ends in `)`, which composes fine
with the appended `; echo DONE_$?`: `"(nohup sh $REMOTE > /soak.out 2>&1 &)"` ✅. This is a property
of the **transport itself**, not of any one script — every caller, present and future, in every repo
that drives the box this way must wrap a backgrounded command in parentheses (or otherwise end it in
a token other than a bare `&`). Note the shapes that are **not** this defect and must not be
"fixed": a `&` inside an on-box script's own text or a pushed heredoc (the marker is appended per
*transport call*, never injected into file contents); **host-side** backgrounding of the
`amixrun.py`/`amixsh.py` invocation itself (that `&` never crosses the wire); and a **non-final** `&`
such as `& echo launched-$!` (the marker still lands after a `;`-safe token) ✅.

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


### 28. The partitioning tools' units are 512-byte blocks, and `rdb` won't tell you its own grammar ✅

Three conventions of the miniroot's partitioning tools, each of which bites a scripted install, all bench-proven ✅ (first-party, 2026-07-31):

- **`/etc/rdb -c` requires `-d disksize` — in 512-byte blocks — and `-d` is absent from the usage text the tool prints when it refuses.** The working grammar cannot be learned from the tool itself; the authority is the stock install script (`/etc/profile` on the root floppy).
- **`/etc/rdb -p` takes a 1-based partition number, never a device path** — the argument is `atoi()`-ed, so a path decodes as 0 and every flag/type stamp is refused. Partitions are appended in slice order, so partition *N* is slice *N*.
- **`mkfs_s5`'s size operand is also 512-byte blocks** — it converts to its 1 KB logical blocks itself; hand it a pre-converted count and it builds a filesystem over **half** the slice, silently.

Full grammar, units, and the read-back proofs on [filesystems & disks](filesystems-and-disks.md#etcrdb-and-mkfs_s5-the-grammar-and-the-units); the stock script's own command lines on [the root-floppy anatomy](../boot-disks/anatomy-root-adf.md#the-install-script-is-etcprofile).

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
- The **amix-kerntools** inetd investigation @ `f7d741d` (`docs/inetd-telnet-throttle.md`) and the
  **amix-cdfs** Packet C wedge soak @ `c3eba7e` (`docs/packet-c-wedge-soak.md`), 2026-07-26/27 ✅ —
  quirk 23 (the `TOOMANY=40` / `CNT_INTVL=60 s` / `RETRYTIME=600 s` throttle read out of the shipped
  `/usr/sbin/inetd` as compile-time immediates, the absent `nowait.<max>` syntax proven by disassembly
  *and* a live `SIGHUP` test, per-service independence measured both directions, and the rate bound:
  29.9/min never trips in 200 invocations, ~575/min trips within seconds) and quirk 24 (the
  vendor-hardcoded `exit` in `/etc/init.d/syslogd`, its 3-hard-link `cp`-in-place hazard, `/var/log/*`
  rather than `/var/adm/messages`, and the measured 293 B of log growth under abuse). Quirk 26's
  `netstat -a` control run and the `sar -v`/`ipcs -a` failures are from the same soak's wedge-time
  capture ✅.
- The **amix-cdfs** Packet C bench run @ `419e16c` (`docs/packet-c-bench-results.md` §6), 2026-07-26 ✅
  — quirk 27: on a 1.25 GiB multi-extent UDF disc, `dd skip=` to the 1 GiB mark transfers rather than
  seeks and needs a ~20-minute command timeout; the first tail read was scored a failure only because
  it hit a 300 s cap.
- The **amiberry** workspace fork `docs/amix-guest-cycle-exact.md` @ `aa077b0` and the
  **amix-kerntools** rig ablation `docs/piscsi-rig.md` §3 @ `33ab7c3`, 2026-07-26 ✅ — quirk 25: the
  `default_prefs()` all-true initialisation, the four non-equivalent config keys, the host-dependent
  `default_disable_cycle_exact`, the `fixup_prefs()` host-log tell (present in 6/6 omitting runs,
  absent in 10/10 pinning runs) and its `cpu_compatible` side effect, and the 10-boot single-variable
  ablation whose decisive run added `cycle_exact=false` and nothing else.
- The **Installer-NG** author-mode matrix proof (amix-installng, 2026-07-31) ✅ — quirk 28: the stock `/etc/rdb -c`/`-a`/`-p` + `mkfs_s5` sequence run on a blank bench disk and read back host-side (the `-d` refusal and its absence from the usage text; the `atoi()` 1-based partition-number convention; the 512-byte-block `mkfs_s5` operand), with the stock install script (`/etc/profile` on the root floppy, read by path with an s5 reader) as the reference caller. See [Filesystems & disks](filesystems-and-disks.md#etcrdb-and-mkfs_s5-the-grammar-and-the-units).
Append these bullets to the page's `## Sources` list (after the amiberry cycle-exact bullet):

- Linux mainline `arch/m68k/amiga/config.c` — the A3000/A3000T-only `MAGIC_REKICK` hardware feature
  ("Magic Hard Rekick") and its `0xde0002 |= 0x80` write, commented as forcing a hard rekick —
  grounding quirk 28's A3000 register semantics ✅:
  <https://github.com/torvalds/linux/blob/master/arch/m68k/amiga/config.c>.
- BlitterStudio/amiberry, `src/gayle.cpp` (`mbres_write`/`mbres_read`; the bank is mapped at
  `0xde0000` in `src/memory.cpp`) — the UAE-family model of `0xde0002`: Fat Gary's bit-7
  "coldreboot flag", settable and readable (read-back gated on a configured Fat Gary revision), with
  no consumer — grounding quirk 28's A4000 side ✅: <https://github.com/BlitterStudio/amiberry>.
- First-party stock-kernel analysis and the project's metal-boot record (real A4000 + Z3660),
  2026-07 ✅ — quirk 28: the stock kernel's unconditional `0xde0002` write in both the boot and the
  reboot/halt paths, and its benignity on the A4000, where every metal boot forwards the write
  through the accelerator to the physical bus with no ill effect.
- The **amix-kerntools** cdevsw free-row gate + 2026-07-31 half-patch audit (`2b23808` →
  `f025444`) and the **amix-z3660net** patch-script hardening (`603c719`), 2026-07-30/31 ✅ —
  quirk 28: the `ed` miss-then-write half-patch reproduced host-side with GNU `ed` over the real
  stock file layouts, its name-wide-grep permanence, the wrong-row-overwrite and wrapping-search
  variants, and the pre-probe / one-run-per-edit / post-verify-the-row pattern. See
  [building a kernel](../drivers/kernel-build.md#scripting-the-kernelc-edits-with-ed--the-half-patch-trap).
- The **amix-kerntools** transport lint (`amix-transport-lint.py` @ `2de5264`) and the two live
  defects it generalises from — `amix-kerntools` and **Z3660** (`d40ce94`/`0fe57b4`) CHANGELOG entries,
  both 2026-08-27 ✅ — quirk 39: the transport's appended `; echo DONE_$?` turning a bare trailing `&`
  into the Bourne syntax error `&;`, the two independent repo instances found a day apart (a soak
  launch line and a `shutdown -i6` reboot soak), the parenthesise-the-launch fix, and the four
  superficially-similar shapes that are safe and must not be flagged (the linter's `--self-test`
  exercises all four plus the unsafe one).
- The **2026-08-12/14 RAM campaign** (amix-kerntools with Z3660 and amix-z3660net, workspace record)
  ✅ — quirk 41 (stock `autocon()`'s `end > 0x07000000` RAM-size inference of the A3000 SCSI, failing
  in both directions, with real A3000s above 16 MB inside the affected envelope) and the campaign's
  own method laws, quirks 42–45: the neighbour sweep that found the arena's derived constants but
  missed `segkmap` (sized from physmem); the mandatory disassembly-diff third gate, every patch site
  located by instruction context rather than by offset; the `elf2brel`-stripped `/stand/unix` that is
  useless as an `adb -k` namelist; and the spontaneous reboot under a heavy raw `dd` to the boot slice,
  whose only reliable record is the verify line the job wrote to disk. See
  [the RAM ceiling](ram-ceiling.md).
- First-party **read-only metal session**, real A4000 + Z3660, 2026-08-27 ✅ — quirk 40: `dmesg` not
  present on the system; `wtmp`'s header dated *Mar 24 1992* with zero reboot records and `last reboot`
  returning nothing; `/sbin/bcheckrc` read verbatim (pre-check verdict discarded to `/dev/null`, repair
  pass to the console with no redirection); and the passive HDMI capture at a fresh `login:` prompt
  recovering the full boot transcript, used in the same session to answer a "did fsck run?" question.
  A delta to quirk 24, orthogonal to the syslogd state.
