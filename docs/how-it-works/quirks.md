---
title: Quirks & Gotchas
summary: The Amiga-port-specific surprises that bite developers and installers.
status: draft
---

# Quirks & Gotchas

Amix is a "quick and dirty" 1990–1992 SVR4 port ✅, and it shows: the kernel hard-codes SCSI IDs and a fixed RAM-description arena, finds the A3000 SCSI by where the kernel was loaded, the bootstrap predates the 68040 and Zorro III, the stock `setclk` breaks in 2000, and the userland is pre-POSIX. This page is the **checklist of port-specific surprises** — the things that are technically correct, technically broken, or just unexpected, that cost people hours before they realize "it's just Amix."

Each item is one line: what it is, the ✅/🟡 confidence tag carried from the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §12 (and §2/§9/§11, plus §17/§18 for the Z3660 driver-authoring items), and a cross-link to the page that covers it in depth.

## TL;DR checklist

| # | Quirk | Tag | Deeper coverage |
|---|---|---|---|
| 1 | **Tape must be ID 4** (hard-coded `/dev/rmt/4h`); **disk ID 6 by convention** — installer prompts for the target, but the ID is baked into device names, so don't change it post-install | ✅/🟡 | [Hardware](hardware.md#scsi-target-ids), [Filesystems & disks](filesystems-and-disks.md) |
| 2 | ~~16 MB Fast RAM ceiling~~ **wrong mechanism** (corrected 2026-09-29) — not a RAM ceiling: the stock kernel's A3000-SCSI guess (row 57) needs the kernel loaded above `0x07000000`, i.e. a 16 MB A3000 motherboard bank. Probing kernels run 64 MB, the 040/060 kernels 128 MB. The real limit — total *describable* RAM, ≈64 MB on a stock 030 kernel, set by a fixed 4 MiB kernel arena — fails **silently** (no output at all) | ✅ | [Hardware](hardware.md), [RAM ceiling](ram-ceiling.md) |
| 3 | **Stock Amix is Zorro II only** — stock drivers can't address Zorro III; but a purpose-written driver that maps the board (`sptalloc`, or a window inside the identity-mapped low 1 GB) **can** — see the [A4091](../drivers/a4091-53c710-driver.md) & [Z3660](../drivers/z3660-ethernet-driver.md) drivers | ✅ | [Hardware](hardware.md), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 4 | **No 68040/68060 in stock Amix** → a stock kernel can't run on an A4000; the public 68040/68060 port boots to login on a real 68LC060 (Z3660 in an A4000T, 2026-09-25) | ✅ | [Hardware](hardware.md), [040/060 status](68040-68060-status.md) |
| 5 | **Superkickstart dual-boot** by holding the right mouse button at power-on | ✅ | [Boot process](boot-process.md) |
| 6 | **DNS resolution is OFF by default** (`/etc/hosts` only) | ✅/🟡 | [Networking](networking.md) |
| 7 | **Y2K is a `setclk` bug, not a kernel cap** — the stock `setclk` writes the year `%02d` (`126` for 2026), `date` rejects it, so a stock box never sets its clock from the battery clock, even when the RTC is right. Fix: the community-patched `setclk` plus `/etc/clkzone` naming the zone the RTC holds; the stock 1991 zone files carry outdated DST rules | ✅/🟡 | [Quirks §7](#7-y2k-setclk-and-the-kernels-1999-date-cap), [Versions](../reference/versions.md) |
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
| 22 | **A fresh miniroot ships no `/etc/mnttab`** — its bare `mount(2)` writes none, yet `pkgadd` needs the file, so an installer must seed it before it calls `pkgadd`; a reused root floppy can carry a stale one and hide the gap | ✅ | [Quirks §22](#22-reused-writable-test-media-accumulates-state-that-masks-bugs), [Package management](package-management.md) |
| 23 | **`inetd` disables a service after 40 connections in 60 s** — that port answers `Connection refused` while every *other* port, ICMP and the console stay healthy; it re-enables itself within 10 min. No config knob exists (`nowait.N` is silently ignored). Diagnosis: port 21 open + port 23 refused ⇒ throttle | ✅ | [Networking](networking.md#the-inetd-anti-looping-throttle-one-service-refuses-connections-while-the-box-is-healthy) |
| 24 | **`syslogd` ships deliberately disabled** — a vendor `exit` on line 8 of `/etc/init.d/syslogd`, so every `daemon.*`/`auth.*` message on the box is discarded. One commented-out line enables it; this SVR4 logs to `/var/log/*`, **not** `/var/adm/messages`. ⚠ that file is one inode with 3 hard links — edit with `cp` in place, never `mv` | ✅ | [Networking](networking.md#why-it-is-silent-syslogd-ships-deliberately-disabled) |
| 25 | **A hand-written UAE-family `.uae` selects the cycle-exact 68030 core and Amix dies at PID 1** — omitting `cycle_exact` is not neutral, the default is `true` (and host-dependent). Pin `cycle_exact=false`; it also silently overrides `cpu_compatible=false` | ✅ | [Emulation fidelity](emulation-fidelity.md#the-cycle-exact-core-a-correct-emulator-default-that-amix-does-not-survive), [Amix on Amiberry](../getting-started/emulation-amiberry.md) |
| 26 | **Three diagnostic tools lie or don't work**: `netstat -a` prints `corrupt control block chain` on a perfectly healthy box; `sar -v` fails `sadc: Not enough space`; `ipcs -a` fails `read error: No such device or address`. Don't chase any of them, and don't budget on them for a capture | ✅ | [Quirks §26](#26-three-diagnostic-tools-that-lie-or-do-not-work) |
| 27 | **`dd skip=` on a `cdfs` file is not an effective seek** — the skipped bytes are really transferred, through the one-sector in-kernel SCSI path, so a read at the 1 GiB mark needs ~20 minutes. Never score that timeout as a read failure | ✅ | [Quirks §27](#27-dd-skip-on-cdfs-is-not-a-seek), [Filesystems & disks](filesystems-and-disks.md#mounting-a-cd) |
| 28 | **The partitioning tools' units are all 512-byte blocks, and `rdb`'s usage text omits the flags that matter** — `rdb -c` requires a `-d disksize` its usage block never mentions; `rdb -p` wants a 1-based partition *number* (a device path `atoi()`s to 0 and is refused); `mkfs_s5`'s size operand is 512-byte blocks (pass a pre-converted 1 KB count and the filesystem covers half the slice) | ✅ | [Filesystems & disks](filesystems-and-disks.md#etcrdb-and-mkfs_s5-the-grammar-and-the-units) |
| 29 | **The stock kernel writes motherboard register `0xde0002` at every boot and at reboot/halt** — on the A3000 that is the SuperKickstart re-kick bit; on an A4000 the same address is Fat Gary's coldreboot latch, which nothing consumes, so the write is benign. Don't chase it in bus traces or emulator logs; decode-and-ignore is the correct model for an A4000 target | ✅ | [Quirks §29](#29-the-kernel-pokes-the-a3000-re-kick-register-0xde0002-at-every-boot-and-reboot) |
| 30 | **A scripted `ed` edit that misses its address search still writes the file** — earlier inserts in the same body stay applied, and a name-wide `grep` guard then reports "already patched" forever: a permanent, invisible half-patch. Pre-probe the target row, one `ed` run per edit, post-verify the row — never trust `ed`'s exit status alone | ✅ | [Quirks §30](#30-a-scripted-ed-edit-that-misses-its-address-still-writes-the-file), [Kernel build](../drivers/kernel-build.md#scripting-the-kernelc-edits-with-ed-the-half-patch-trap) |
| 31 | **On an FPU-less part, floating point dies as SIGSYS ("Bad System Call", exit 140)**, not SIGILL/SIGFPE — and it dies in *libc*: `_doprnt` carries FP on its `%e`/`%f`/`%g` paths, so any program that **prints** a float dies even if its own code is FP-free (`df -k`, `uptime`). `__fpstart` is FP-safe, so everything else runs. Triage rule: *does it print a float?* | ✅ | [Quirks §31](#31-on-an-fpu-less-part-floating-point-dies-as-sigsys-bad-system-call), [040/060 status](68040-68060-status.md) |
| 32 | **`awk` is always a floating-point program** — it holds every number as a C `double`, so on an FPU-less part it dies even on `1+1`. An awk failure on integer arithmetic is not evidence of a second defect | ✅ | [Quirks §32](#32-awk-is-always-a-floating-point-program) |
| 33 | **68060: the FP-disabled frame's stacked "Next PC" is software-maintained** — Motorola's own support package recomputes it from its own decode and treats the faulted-PC slot as the authority. A handler must resume on a PC it computed itself | 🟡 | [Quirks §33](#33-68060-the-fp-disabled-frames-next-pc-is-software-maintained) |
| 34 | **68060: immediate `#<data>` is the one F-line operand the hardware cannot size** — its length lives in the FP command word a disabled FPU has no reason to decode, so the stacked next-PC can be short by the operand's width | 🟡 | [Quirks §34](#34-68060-immediate-data-is-the-one-f-line-operand-the-hardware-cannot-size) |
| 35 | Withdrawn 2026-10-04 — see [§35](#35-a-zero-behind-a-gate-needs-a-pre-gate-denominator) | — | — |
| 36 | Withdrawn 2026-10-04 — see [§36](#36-an-optimised-probe-reporting-no-fault-must-be-disassembled-first) | — | — |
| 37 | Withdrawn 2026-10-04 — see [§37](#37-a-one-byte-binary-diff-is-not-understood-until-the-byte-is-decoded) | — | — |
| 38 | **`uptime` and `w` do not report the machine's load** — the reader resolves a COMMON kernel symbol to a non-address without an error (flat `0.00` and absurd millions are the SAME defect), and even the kernel's own count reads exactly N−1 (the on-CPU process is never counted). Read the truth with `adb -k <running-kernel> /dev/mem`, `avenrun/3X`, ÷256 | ✅ | [Load averages](load-averages.md) |
| 39 | **`<cmd> &;` is a syntax error in the SVR4 Bourne shell** — a command line ending in a bare `&` that then gets `; …` appended (such as a completion marker `; echo DONE_$?`) never parses, so the background job never starts. Parenthesise the background launch: `(… &)` | ✅ | [Quirks §39](#39-transport-ampersand-law) |
| 40 | **Amix keeps no persistent boot log** — no `dmesg` at all, `wtmp` has never recorded a reboot, and boot `fsck` writes only to the console (a delta to quirk 24, independent of `syslogd`). The console is the only record — and it still holds the whole boot transcript at a fresh `login:` prompt. Plan an HDMI capture; there is no log to read | ✅ | [Quirks §40](#40-no-persistent-boot-logging) |
| 41 | **Stock `autocon()` decides whether the A3000 internal SCSI exists from *where the loader put the kernel*, not from the hardware** (`end > 0x07000000`, `end` being the kernel's own end address — once read as a RAM-size test) — wrong in both directions: it fabricates a phantom card 0 where there is no controller, and it silently drops the real one (root disk included) on a machine where the kernel loads lower (a bigger A3000 motherboard bank), renumbering every remaining SCSI card | ✅ | [Quirks §41](#41-scsi-by-ram-size), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 42 | Withdrawn 2026-10-04 — see [§42](#42-neighbour-sweep-law) | — | — |
| 43 | Withdrawn 2026-10-04 — see [§43](#43-disassembly-diff-gate) | — | — |
| 44 | **On-box `adb -k` needs a namelist that still has a symbol table** — `elf2brel` discards symtabs, so `/stand/unix` is useless as a namelist and `adb` reports nonsense instead of failing | ✅ | [Quirks §44](#44-adb-namelist) |
| 45 | **Heavy raw `dd` to the boot slice rebooted one machine mid-write** — a single-unit observation with no known mechanism. The session dies and looks like a failure; trust the verify line the job wrote *to disk*, not the session that vanished | 🟡 | [Quirks §45](#45-boot-slice-dd) |
| 46 | **`adb -k` prints a one-byte kernel flag as `16777216`, not `1`** — `/D` reads four bytes as a big-endian int, so a set byte at the object's address reads as `0x01000000`. The value is right and the *format* is wrong; do not conclude the flag holds garbage | ✅ | [Quirks §46](#46-adb-byte-flag) |
| 47 | **A successful remote halt looks like a transport failure** — `uadmin 2 0` kills the session that issues it, so a remote runner reports a transport failure; that signature **is** the success case. A halt is proven clean only by a **`fsck`-silent next boot** — image a disk only after one | ✅ | [Quirks §47](#47-halt-looks-like-failure) |
| 48 | Withdrawn 2026-10-04 — see [§48](#48-stray-serial-reader) | — | — |
| 49 | **A warm reset is not a clean-state reset** — on one card (stock firmware, emulated-CPU mode) the accelerator's warm-reset command gave a valid reset vector **0/3** where a power cycle gave it **5/5**; a single-unit observation. Power-cycle with **≥20 s off** for anything that needs a known state | 🟡 | [Quirks §49](#49-power-cycle-law) |
| 50 | Withdrawn 2026-10-04 — see [§50](#50-sticky-mask) | — | — |
| 51 | **Memory detection that reads back immediately is fooled by capacitive echo** — an unpopulated bus holds the value it was just driven with and *passes*. Treat any "Detected NNN MB" as unverified until a whole-block address check confirms it | ✅ | [Quirks §51](#51-capacitive-echo) |
| 52 | Withdrawn 2026-10-04 — see [§52](#52-boot-path-evidence) | — | — |
| 53 | **68060: the unimplemented 64-bit integer instructions trap to a vector the stock SVR4 trap table never populated** — the 64-bit `MULU.L`/`MULS.L`/`DIVU.L`/`DIVS.L` forms are left to software by the CPU, the stock trap-dispatch table has no entry for them, and where nothing serves that vector the process is killed with no diagnostic at all (a bare `Killed`, rc 137 — no SIGILL, no SIGFPE, no core). 68060 kernels before amigaux 1.0 emulated at most some 64-bit multiply forms; the 1.0 kernels emulate the 64-bit multiply and divide forms, `MOVEP` and `CMP2`/`CHK2`, so only `CAS2` and a misaligned `CAS` still die. Integer ops, so it is not an FPU matter; a 68060 toolchain should still emit the **32-bit** `MULU.L`/`DIVU.L`/`DIVUL.L` forms (emulation is slow, and older kernels kill) | ✅ | [Quirks §53](#53-unimplemented-integer-vector), [040/060 status](68040-68060-status.md) |
| 54 | **On the Z3660, `amix_mode YES` under `bootmode CPU` silently disables SCSI boot** — the firmware forces `cpu_ram = 0`, and the boot device then disappears with one line of serial as the only warning. A real-CPU Amix preset must set `amix_mode NO` | ✅ | [Quirks §54](#54-amix-mode-scsi-boot) |
| 55 | **A Kickstart proven under emulation is not proven on silicon, and the *file* matters more than the generation** — a ROM that boots under emulation may still fail on the real CPU. Identify a ROM by CRC-32, never by filename or slot | ✅ | [Quirks §55](#55-kickstart-file-not-generation) |
| 56 | **A firmware CRC manifest does not tell you which image ran** — the loader picks at boot time and only its own serial line records the choice; and the boot menu is a single-keystroke consumer where six keys copy firmware images over each other | ✅ | [Quirks §56](#56-which-image-ran) |
| 57 | **The stock kernel finds the A3000's internal SCSI only when the loader placed the kernel above `0x07000000`** — with RAM laid out so the kernel loads lower, no card 0 exists and root fails to mount (`VOP_OPEN error 6`). The "16 MB ceiling" folklore is this guess's one working layout | ✅ | [Quirks §57](#57-loader-placement-a3000-scsi), [RAM ceiling](ram-ceiling.md) |
| 58 | **A run-level change requested over telnet while nobody is logged in on the console stalls at `INIT: New run level: 6`** — stock `init` (reproduced on the stock kernel); `rc6` never runs and only a power cycle recovers. Keep a root shell logged in on the console, or issue reboots from it | ✅ | [Quirks §58](#58-console-getty-shutdown-stall) |
| 60 | **On the Z3660, an `isoN` CD image works only when N equals the SCSI target id** — a mismatch fails silently in both directions (the ISO becomes a read-write disk, an unrelated image becomes a CD); only `iso0`–`iso6` exist | ✅ | [Quirks §60](#60-z3660-iso-slot-equals-target) |
| 61 | **VPOSR: AGA is the Agnus/Alice id's low nibble, not `id >= 0x22`** — the range test misreads an NTSC ECS Agnus (`0x30`) as AGA and skips an NTSC A3000's internal SCSI (its root disk included) | ✅ | [Quirks §61](#61-vposr-low-nibble), [Zorro autoconfig](../drivers/zorro-autoconfig.md#chipset-gated-wd33c93-auto-detection-the-fix) |
| 62 | **On-box `mkfs` fails above a ~603 MB root, and a raw read past that point sleeps forever** — stock `sddevsize()` answers a fixed 1 234 567 blocks for a slice whose table was not read, and `dd.c` clamps to it. Fix: default `0x3FFFFF` + an offset check in `dd.c` | ✅ | [Quirks §62](#62-sddevsize-603mb) |
| 63 | **Stock `dd.c` counts every unit in 512-byte blocks** — a 2048-byte CD driver that multiplies by its own block size overruns the buffer 4×; refuse any request larger than `nbyte` (the Z3660 raw-`dd` CD hang) | ✅ | [Quirks §63](#63-dd-512-unit-overrun), [Z3660 SCSI driver](../drivers/z3660-scsi-driver.md) |
| 64 | **Stock `in.ftpd` silently truncates PASSIVE downloads and still replies `226`** — a byte-exact prefix, no `SIZE` command to catch it. Use active (`PORT`) mode and length-gate every `GET` against `ls -l` | ✅ | [Quirks §64](#64-ftpd-passive-truncation) |
| 65 | **Stock `autocon()` can never match a manufacturer id ≥ `0x8000`** — it compares against a *signed* `id >> 16`; the board is handed over in `bootinfo.autocon[]` but no driver ever attaches (the A4092's `0xC0DE` was the first such id). Fix: an unsigned shift (`asr.l` → `lsr.l`) | ✅ | [Quirks §65](#65-autocon-signed-manufacturer), [Zorro autoconfig](../drivers/zorro-autoconfig.md) |
| 66 | **Under the Z3660, a CPU read of an undecoded local-I/O address (`$D80000`–`$DFFFFF`) hangs forever** — the motherboard raises no timeout bus error there and the card's CPLD has no cycle timeout, so not even a fault handler runs. Never probe `$DD00xx` speculatively | ✅ | [Quirks §66](#66-local-io-read-hangs) |
| 67 | **On the Z3660 the real 68060 cannot boot from the motherboard ROM sockets (`kickstart 0`)** — the firmware clears the MAPROM bit after the FPGA has already latched it, so the CPU fetches an empty DDR region (black screen). On stock firmware (upstream 1.03 beta 21 included), always MAPROM from a Kickstart file; the project's fork firmware 1.0 (`C96EAD03`) carries the fix | ✅ | [Quirks §67](#67-z3660-kickstart-0) |
| 68 | **Real-060 MAPROM boots take the reset vector from the socket ROM** — a stock Kickstart in the sockets (`00F800D2`) needs nothing; DiagROM (`$F800D6`) needs the mapped image `.d6`-patched (`0xD6`: `00414D49` → `6000007A`, checksum at `0x7FFE8`) | ✅ | [Quirks §68](#68-z3660-d6-reset-vector) |
| 69 | **A 68040/68060 kernel writes anything over 4 KiB to disk as 2 KiB requests, and flushes a UFS inode block twice per `sync`** (~70 ms apart) — only a fault on a block's last write persists; the disk layer's error path never misplaces data; mask dinode time fields when comparing inode copies | ✅ | [Quirks §69](#69-040-060-disk-write-stream) |
| 70 | **68060 kernel, emulator run: the stock 1992 `installf` crashes (`User BUS ERROR at 4AFC0002`)**, leaving a core in `/` and a half-registered package entry; APKG's `installf` did the same job cleanly in the same run. Route runtime package operations through the APKG tools on a 68060, with the engine amigaux 1.0 ships (APKGENG 1.12.3): the July 2026 1.12.0 build's own `installf -f` is killed by 64-bit divides on a 68060 kernel before 1.0 | 🟡 | [Quirks §70](#70-stock-installf-060), [Package management](package-management.md) |
| 71 | **A boot node's `fssm_Device` BSTR length counts the terminating NUL** — `MakeDosNode()` adds 1 to the device name's length byte (not to `dn_Name`'s) on every Kickstart from 2.0 to 3.2.3. A loader that matches its boot node against an exec `ln_Name` must compare as a C string, as the strap does | ✅ | [Quirks §71](#71-fssm-device-nul), [Boot process](boot-process.md#fssm-device-nul) |
| 72 | **A local `AF_UNIX` stream socket can deliver stale data under memory pressure** — on Amix 2.1c with about 8 MB of fast RAM and a non-blocking writer, a read can return whole 4 KB pages from earlier in the stream; X clients (Xlib writes non-blocking) die on misparsed requests. Third-party report, not reproduced here; none seen with 12 MB or more | 🟡 | [Quirks §72](#72-af-unix-memory-pressure), [X11 & desktop](x11-and-desktop.md) |
| 73 | **Amiberry builds before upstream commit `845af02` corrupt Amix data in the 68030 MMU's "more compatible" mode** (`cpu_compatible=true`) — a misaligned `MOVES` was not split across a page boundary, and Amix copies between kernel and user space with `MOVES`. On an older build set `cpu_compatible=false`. Third-party report, not reproduced here | 🟡 | [Quirks §73](#73-amiberry-moves-page-boundary), [Amix on Amiberry](../getting-started/emulation-amiberry.md) |

The rest of this page expands each item.

## Hardware & addressing quirks

### 54. On the Z3660, `amix_mode YES` under `bootmode CPU` silently disables SCSI boot ✅ {#54-amix-mode-scsi-boot}

On a Z3660 preset that releases the **real** CPU (`bootmode CPU`), setting `amix_mode YES` makes the
firmware force `cpu_ram = 0` ✅. SCSI boot is then enabled only when `scsiboot && cpu_ram` holds, so
the boot device silently disappears and the machine never finds its disk. **The only warning is one
line on the serial console** — `CPURAM disabled -> SCSI boot disabled` — with nothing on screen.

It reads backwards: the *Amix* preset is the one that must set `amix_mode NO`. The rule is
**`amix_mode NO` on any real-CPU Amix preset**. An emulated preset (`UAE_040_MMU`) keeps
`amix_mode YES` safely, because CPU RAM and autoconfig are emulated in the CPU emulator there, so
the forcing costs nothing — which is why the two preset shapes legitimately differ and should not be
"made consistent" ✅. A companion trap: `amix_ram` is a construct of the emulator core and is inert
under `bootmode CPU`; the firmware says so at boot (`amix_ram 128 ignored: amix_mode is NO`), so
leave the line alone rather than "fixing" it ✅.

### 55. A Kickstart proven under emulation is not proven on silicon ✅ {#55-kickstart-file-not-generation}

**Success under a UAE core is not evidence for the same ROM on silicon** ✅: a ROM that "works" may
only have been shown to work on the easier, emulated path. Prove the ROM on the real CPU before
relying on it.

What it is **not**, checked rather than assumed ✅:

- **Not a generation requirement.** The Unix dostype constant `UNI\1` (`0x554E4901`) appears exactly
  twice in every ROM from 2.04 through 3.2.3 — the code moves address between generations, it does
  not disappear. The boot chain is generic RDB autoboot; the ROM only has to recognise the dostype
  and load the boot block.

**Identify a Kickstart by CRC-32, never by filename or by slot number** ✅. Slot numbers are per-card
config indices and mean nothing across machines, and a file name proves nothing about the ROM inside.

### 56. A firmware CRC manifest does not tell you which image ran ✅ {#56-which-image-ran}

The Z3660 carries three firmware images on its boot volume. `BOOT.BIN` is the **loader**: it loads
`Z3660.bin` when that file is present and valid, falling back to `FAILSAFE.bin` and then to itself
✅. So a checksum inventory of the three files records **what exists**, not **what the loader chose**
— the only record of the actual choice is the firmware's own `[SD Init] Done (…)` serial line. A
causal timeline built from the manifest instead of the log will be confidently wrong.

The same page of the story: **the firmware boot menu is a single-keystroke consumer** ✅. There is no
Enter; every character acts immediately, several are destructive, and typing a word executes it one
letter at a time. Six keys (`M`, `B`, `N`, `J`, `K`, `L`) each copy one of the three boot images over
another, and `D` reflashes the CPLD ✅. **Send keys one at a time; never send a line.**

### 60. On the Z3660, an `isoN` CD image works only when N equals its SCSI target ✅ {#60-z3660-iso-slot-equals-target}

The firmware's `isoN <file>` key (upstream's, since beta 21) fills **image slot N** like `hdfN` and
marks it optical: the target is then presented as a **read-only, 2048-byte-block CD-ROM** (SCSI
device type `0x05`) with no RDB scan, which is what Amix's `cdfs` mounts ✅. But the firmware records
the CD flag **by slot** and consumes it **by SCSI target**: target *t* is a CD if and only if slot *t*
was declared with `isoN`. The `scsiN` line that actually assigns the image is never consulted for
the flag ✅. The only working shape is one where the numbers agree:

```
iso2 iso/amix-tools.iso     # slot 2
scsi2 2                     # target 2  <- same number
```

A mismatch fails **silently in both directions** ✅: the ISO is attached as an ordinary read-write
RDB disk (its ISO filesystem is never found), and whatever image sits on the target matching the
slot number is presented as a read-only CD. Only `iso0`–`iso6` exist (the CD table is seven entries
wide). Beta 21's own shipped example config pairs `iso6` with `scsi4 6` and produces no working CD —
read it as a demonstration of the trap, not a template ✅. The firmware also skips the RDB scan on an
`isoN` unit, so a CD unit cannot be a boot device.

### 61. VPOSR: AGA is the Agnus/Alice id's low nibble, not `id >= 0x22` ✅ {#61-vposr-low-nibble}

Kernel code that must tell an A3000-class machine (OCS/ECS) from an A4000 (AGA) without touching
hardware that may not decode reads **VPOSR** (`0xDFF004`), whose bits 8–14 are the Agnus/Alice id.
The ids are `0x00`/`0x10` OCS (NTSC/PAL), `0x20`/`0x30` ECS (PAL/NTSC), and `0x22`/`0x23`/`0x32`/`0x33`
AGA Alice ✅. The tempting range test `id >= 0x22` is **wrong**: it classifies an **NTSC ECS Agnus,
`0x30`, as AGA**. On an NTSC A3000 that skips the probe for the internal WD33C93 SCSI, and the root
disk on it is lost ✅. The correct test is the **low nibble**: AGA iff `(id & 0x0F) >= 2`.

Found in 2026-09 in a review of a contributed Gayle-IDE driver (Emre Bastuz's `amix-gayle-ide`),
whose own gate was right; the same defect was then fixed in two places that had copied the range
test — the A4091 project's `support.c.patch` and the Z3660 SCSI driver's machine gate — and a bench
run on an emulated ECS-NTSC machine (id `0x30`) confirms
the probe now runs and finds the WD33C93 as card 0 ✅. The corrected gate and its probe are on
[Zorro autoconfig](../drivers/zorro-autoconfig.md#chipset-gated-wd33c93-auto-detection-the-fix).

### 66. Under the Z3660, a read of an undecoded local-I/O address hangs the machine forever ✅ {#66-local-io-read-hangs}

A CPU **read** of an address in the A4000's local I/O space (`$D80000`–`$DFFFFF`) that nothing
decodes **never terminates** on an A4000D with a Z3660 ✅ (measured 2026-10-02 with a
supervisor-mode, fault-catching peek tool under AmigaOS on the card's 68060). No bus error arrives, so
not even a fault handler gets a chance: the first read of `$DD0000` froze the machine ✅. Two facts combine: the motherboard generates **no
timeout bus error** for local I/O space, and the Z3660's CPLD has **no bus-cycle timeout of its
own** — its termination logic waits for `DSACK`, `AVEC` or `BERR` indefinitely ✅ (read from the
card's CPLD sources). The CPLD *does* forward a bus error that something else raises: Buster's Zorro
III timeout (~280 ms) arrives at the CPU as an ordinary access fault ✅.

**Rules for driver and probe authors:** never probe `$DD00xx` (or anything else in `$D80000`–
`$DFFFFF`) speculatively — gate any such access on a positive identification of the machine, the way
the [VPOSR gate](#61-vposr-low-nibble) does; a fault-catching probe does not help, because there is
no fault to catch. And read a freeze after a `c0` access on an A4000-class machine with the stock
kernel's phantom A3000 card ([§41](#41-scsi-by-ram-size)) as **a hung bus cycle**, not a driver
stall. Setting the bit of Gary's `$DE0001`
that emulators treat as the bus-timeout enable does **not** help: on the A4000D the bit reads back
set and the `$DD0000` read still hangs ✅ ([§29](#29-the-kernel-pokes-the-a3000-re-kick-register-0xde0002-at-every-boot-and-reboot)),
so the board logic most likely never raises a bus error for local-I/O non-range addresses 🟡 (not yet
confirmed on a scope). The card's CPLD *would* pass one on. **On the Z3660's emulated 68030/040 the
same read behaves differently:** the emulator times the cycle out itself and its UAE-derived Gary
model can turn it into a bus error ✅ — which is why older emulated-CPU runs saw a fault where the
real 68060 hangs (see the dated note on [Zorro autoconfig](../drivers/zorro-autoconfig.md)).

### 67. On the Z3660, the real 68060 cannot boot from the motherboard ROM sockets (`kickstart 0`) ✅ {#67-z3660-kickstart-0}

With the Z3660 running its **real 68060**, `kickstart 0` — "use the Kickstart in the motherboard's
ROM sockets, no MAPROM" — never boots: black screen, no SCSI activity at all ✅ (A4000D with
Kickstart 3.2.3 in the sockets, 2/2, 2026-10-03). The cause is an ordering problem in the firmware ✅
(read from the FPGA and firmware sources): the FPGA latches its MAPROM-enable bit only while it is
held in reset, and whenever that bit is set it serves `$F80000`–`$FFFFFF` from the card's own DDR.
The firmware enables MAPROM at start-up, pulses the FPGA reset, starts the CPU side, and only *then*
clears the bit for `kickstart 0` — with no further reset, so the cleared bit never takes effect and
the 68060 fetches its Kickstart from a DDR region nothing was loaded into. The upstream firmware
(1.03 beta 21) has the same order ✅. **How to recognise it:** the screen stays black and the
firmware's serial console floods with descending `write SCSI add 0x001FFFFD…` lines — the 68060
executing garbage and sweeping the piscsi register window (about 85 000 such lines in three minutes on
the A4000D, versus none with the fixed firmware; first-party record, 2026-10-03) ✅.

**Rule:** on stock firmware a real-060 Z3660 boots via MAPROM from a Kickstart **file**, always — dump your ROM chips
to a file if that is all you have. The fix is small — take the Kickstart/MAPROM decision before the
final FPGA reset pulse, so the FPGA latches the real state — and it works ✅: built on the project's
firmware fork and proven on one A4000D with Kickstart 3.2.3 in the sockets (2026-10-03), `kickstart 0`
then boots the socket Kickstart and SCSI-boots Amix on the real 68060, and `kickstart 1` boots
unchanged. A second box confirmed it on 2026-10-03: on an A4000T the fixed firmware booted
**DiagROM 2.0 from the motherboard sockets** on the real 68060 ✅ (first-party record, 2026-10-03). The fix ships in
the project's fork firmware 1.0 (`Z3660.bin`, CRC-32 `C96EAD03`; source on branch `release-1.0` of
[jusii/Z3660-amix](https://github.com/jusii/Z3660-amix)) ✅. Stock firmware, upstream 1.03 beta 21
included, still black-screens, so on stock firmware the rule above stands. The emulated-CPU modes are
not affected by this ordering.


### 68. Real-060 MAPROM boots take the reset vector from the socket ROM — the `.d6` patch ✅ {#68-z3660-d6-reset-vector}

When the Z3660's real 68060 boots a MAPROM'd Kickstart, the **reset vector** (the initial stack
pointer and PC at `$0`/`$4`) still comes from the ROM chips in the motherboard **sockets**, read
through the overlay; only the code at `$F80000` onwards comes from the mapped file ✅. So what is in
the sockets matters even though they are "not used":

- A socket ROM whose bytes 4–7 read **`00F800D2`** (a stock Kickstart's entry point) sends the CPU to
  `$F800D2` of the mapped image, which is the mapped Kickstart's own entry — **no patch needed** ✅.
- A socket ROM with another entry point — **DiagROM** enters at `$F800D6` — sends the CPU four bytes
  further into the mapped image, into the middle of the Kickstart's ID string. The mapped image then
  needs a branch there: the **`.d6` patch** replaces the long at offset `0xD6` (`00414D49` →
  `6000007A`, a `BRA` to the real start) and recomputes the Kickstart checksum at `0x7FFE8` ✅.

Known-good pairs (CRC-32 of the original → the `.d6` image): A4000 Kickstart 3.2.3 (A4kOS323)
`B6A4698E` → `FA5F933B`; A4000T Kickstart 47.115 `588A5E6D` → `75B807FE` ✅. Identify ROMs by CRC, never by file
name ([§55](#55-kickstart-file-not-generation)); and keep real Kickstart chips (or a DiagROM with the
`.d6` image) in the sockets for any real-060 MAPROM boot.

### 1. SCSI IDs: tape fixed at 4, disk 6 by convention ✅/🟡

The **tape drive must sit at ID 4** — the root-floppy install scripts hard-reference the literal `/dev/rmt/4h` and look nowhere else for it ✅. The **hard disk is ID 6 by convention**, not by kernel mandate: the installer *prompts* for the disk target and computes the boot partition from a `$SCSI` variable (`BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`), reserving only ID 4 for the tape — so Amix will install on a disk at another target 🟡. The catch is that the chosen ID is baked into the device names (`c6d0s…`) the installed system records in `/etc/vfstab` (the SVR4 mount table) and the boot partition, so **you can't change the disk's SCSI ID after install** without editing `/etc/vfstab` to match 🟡 ([`amix_21_root.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh`; see [hardware](hardware.md#scsi-target-ids)).

**Consequence for emulation:** attach your tape image at SCSI ID 4 (the installer looks only there) and your hardfile (RDB) at SCSI ID 6 — any target works for the disk, but 6 is the convention and saves you re-pointing `/etc/vfstab` later. See the mapping in [the WinUAE setup](../getting-started/emulation-winuae.md) and [the FS-UAE setup](../getting-started/emulation-fs-uae.md). Disk geometry and partitioning are covered in [filesystems & disks](filesystems-and-disks.md).

### 2. The "16 MB Fast RAM ceiling" — a layout requirement, not a ceiling ✅ {#2-the-16-mb-fast-ram-ceiling-retracted}

The folklore says the kernel hard-codes a 16 MB Fast RAM ceiling and that more "mis-maps the SCSI drive". **The symptom was real; the mechanism was wrong** (corrected 2026-09-29) ✅. The stock kernel registers the A3000's internal SCSI only when the loader placed the kernel above `0x07000000` ([§57](#57-loader-placement-a3000-scsi)); a motherboard bank bigger than 16 MB starts lower, so the kernel loads lower, no card 0 exists and root is not mounted — measured on the bench with a 64 MB bank, 2026-09-29. Kernels that probe for the controller (they boot with a 64 MB bank) and the 040/060 kernels (128 MB on real silicon) are not affected. Separately, the *describable-RAM* arena (≈64 MB stock 030, ≈128 MB 4 KB-page 060) on the [RAM-ceiling page](ram-ceiling.md) fails silently, not as a disk error. **For the stock kernel on an (emulated) A3000, give it a 16 MB motherboard bank.** Background in [hardware](hardware.md).

### 3. Zorro III — stock drivers are Zorro II only ✅

**Stock** Amix is **Zorro II only** ✅: its stock drivers simply dereference the address `autocon()` returns, which only reaches Zorro II boards (≤ 24-bit, inside [the identity-mapped low 1 GB](../drivers/zorro-autoconfig.md#the-identity-map)), and that kernel source was never shipped so the *stock* card set can't be patched in place. This is **not** absolute for a *purpose-written* driver, though: one that maps the board explicitly — the kernel's `sptalloc()` primitive, or (when the board's window happens to fall inside the identity map) a direct mapping — **can** reach a Zorro III board. The [A4091 SCSI driver](../drivers/a4091-53c710-driver.md) and the [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) (✅ real hardware) both do exactly this. The A4091 driver's 68040/68060 arm reaches a Zorro III board on real hardware (root on an A4092 in an A4000D with a Z3660 ✅); the A4091 board itself and the 68030 line are proven in emulation only 🟡. For ordinary expansion, still assume a card must present a Zorro II window; see [Zorro autoconfig](../drivers/zorro-autoconfig.md) for how boards are discovered via the AUTOCONFIG / `autocon()` path, and [hardware](hardware.md) for the supported-board list.

### 4. No 68040/68060 in stock Amix — the A4000 is out for a stock kernel ✅ (the 040/060 port changes this: see [040/060 status](68040-68060-status.md))

The kernel **predates the 68040 MMU** ✅, so it runs only on a **68020 or 68030 with a real MMU plus a 68881/68882 FPU** ✅. There is no soft-float and the MMU-less `68EC020/030` variants cannot run Amix ✅. Practical upshot: an **A4000 cannot officially run Amix** ✅ — and that includes the A4000/030 as shipped, whose stock CPU card is a **68EC030** with no MMU ✅; it needs a full-68030 card. Targets are the A3000(UX) and the A2500UX. See [hardware](hardware.md); for what 040/060 support would actually require and the current state of work toward it, see the [040/060 status page](68040-68060-status.md).

### 5. Superkickstart dual-boot via the right mouse button ✅

A3000UX machines ship a **"Superkickstart 1.4"** bootstrap ROM ✅. At power-on:

- **Default** (do nothing) → boot **Amix** from the SCSI disk.
- **Hold the right mouse button** at power-on → load an **AmigaOS Kickstart** instead.

So the "gotcha" is the inverse of what AmigaOS users expect: the machine boots Unix by default, and you reach AmigaOS only by holding a mouse button. Details in [the boot process](boot-process.md).


### 29. The kernel pokes the A3000 re-kick register `0xde0002` at every boot and reboot ✅

The stock Amix kernel writes motherboard address **`0xde0002`** unconditionally — once in its boot
path and again in its reboot/halt path ✅. What that write means depends on the machine:

- **A3000 — the SuperKickstart re-kick control.** Bit 7 of `0xde0002` (a Gary register, flanked by
  the bus-timeout controls at `0xde0000`/`0xde0001` on the A3000) arms a **hard re-kick**: the next reset
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
- **A4000D — `0xde0000`/`0xde0001` decode too.** Reads of both terminate normally (first read
  `0xFF` then `0x7F`, then `0x7F`/`0x7F`; measured 2026-10-02) ✅. Writing `0x80` to `$DE0001` reads
  back `0xFF`, yet a following read of the undecoded `$DD0000` still hangs ✅ (measured 2026-10-02). The only source for the bit names is the UAE Gary model, which calls bit 7 of `$DE0000`
  the timeout, bit 7 of `$DE0001` TOENB (non-existent memory → bus error) and bit 7 of `$DE0002`
  coldboot 🟡; on real A4000 hardware the effect of TOENB, if any, is **unsourced** 🔴 — it does not
  produce a bus error for local I/O space ([§66](#66-local-io-read-hangs)).

The gotcha is diagnostic: the poke surfaces as an unexplained motherboard-register write in bus
traces, emulator logs and disassemblies — on exactly the machine family (A4000-based rigs) where
the register does nothing, which invites chasing it as the cause of whatever else is wrong. Don't:
on a real A4000 + Z3660 the write is exercised on **every** boot — the accelerator forwards
it to the physical bus, where the real Fat Gary latches it — with no ill effect ✅. For emulator
and bus-bridge authors the only requirement is to *tolerate* the access (decode-and-ignore is
correct for an A4000 target; only an A3000 SuperKickstart model needs to honour the bit). And don't
confuse this motherboard address with the similar-looking AutoConfig product code `0xc0de0002` in
[the major-number registry](../reference/major-number-registry.md) — they are unrelated.

### 41. The stock kernel infers the A3000 SCSI from where the kernel was loaded ✅ {#41-scsi-by-ram-size}

Stock `autocon()` (`amiga/kernel/support.c`) decides whether the A3000 internal SCSI controller
exists by testing whether the kernel's own end address `end` lies above `0x07000000` — i.e. where
boot2 placed the kernel — and not by touching the hardware ✅. The A3000 controller is not an
AutoConfig board, so there is nothing in `bootinfo.autocon[]` to look at; the load address was used
as a proxy for "this is an A3000-class machine" (the A3000's classic 16 MB motherboard bank sits at
`0x07000000`). This page long described it as a RAM-size test; it is a **load-address** test
(corrected 2026-09-29, [§57](#57-loader-placement-a3000-scsi)). It is a guess, and it is wrong in
**both** directions:

- **False positive.** On a machine with no internal SCSI — a real A4000, or an A3000 whose controller
  is absent — a kernel loaded high enough fabricates a **phantom card 0** at `0xDD0000`. It claims `queue[0]`, shifts
  every real controller up by one, and the compiled-in root device (which decodes to card 0) sends
  the root read to hardware that does not exist ✅. This is the failure that produced the
  `s5mountroot VOP_OPEN error 5` → `errno 89` panic chain; full story on
  [the boot process](boot-process.md) and [Zorro autoconfig](../drivers/zorro-autoconfig.md).
- **False negative.** On a machine where the loader puts the kernel **below** `0x07000000` — an A3000
  with a motherboard bank bigger than 16 MB (64 MB starts at `0x04000000`), or fast RAM placed lower —
  the same test fails and the **real** internal SCSI is silently dropped — root disk included — and every remaining SCSI card
  renumbers ✅. Nothing is logged; the machine simply cannot find its disk.
- **The A4000T: a phantom that is not empty.** On an A4000 the `0xDD0000` window is empty; on an
  **A4000T** it holds the **onboard NCR 53C710** — real hardware, the wrong driver ✅ (read from the
  shipped kernel's `autocon()` and the stock sources, 2026-09-24). Boot is safe, because the stock
  `sd` initialises a card lazily on its first I/O; but the **first open of any `c0` device** runs the
  A3000 WD33C93 initialisation against the 53C710's registers 🟡 (read from the source). Under the
  Z3660 an unanswered CPU read in local I/O space never terminates ([§66](#66-local-io-read-hangs)),
  so if the uninitialised 53C710 does not answer, a `c0` open is expected to freeze the whole machine
  on a hung bus cycle, not just stall one process 🟡 (predicted; not run). The amigaux 1.0 68060 kernels
  carry the chipset gate below, so they register no phantom and the Z3660 is card 0 ✅. On an 040/060
  kernel built without it (the public port's mainline does not address the guess), never open a `c0`
  device on an A4000T. Details on [the Z3660 SCSI driver page](../drivers/z3660-scsi-driver.md).

Real A3000s with more than 16 MB of motherboard RAM are inside the affected envelope ✅ — this is not an
emulator-only curiosity.

**The law: probe, don't guess.** The fix that replaced the special case is a **chipset gate plus a
WD33C93 write/readback probe** — read a custom-chip register that is always present to tell an
ECS/OCS (A3000-class) machine from an AGA one, then write two different values to two WD33C93
registers through the same data port and read the first back, so an open bus (which aliases the read
to the *last* write) cannot pass ✅. Full source and rationale on
[Zorro autoconfig](../drivers/zorro-autoconfig.md); the anti-alias readback is the reference design
for [any board probe](../drivers/kernel-composition.md). Decode the chipset id by its low nibble ([§61](#61-vposr-low-nibble)).

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
[networking](networking.md#the-inetd-anti-looping-throttle-one-service-refuses-connections-while-the-box-is-healthy).

### 64. Stock `in.ftpd` silently truncates PASSIVE-mode downloads and still replies `226` ✅ {#64-ftpd-passive-truncation}

A `GET` over a **passive** (`PASV`) data connection can arrive **short**, and the stock FTP server
still answers `226 Transfer complete` ✅. Measured on the bench, 2026-10-02: passive transfers from a
`cdfs` mount came back short 18 times in 80 (always exactly 4 096 bytes, a correct prefix); passive
from UFS 0 in 80; **active (`PORT`) mode 0 in 40**; and a single 8 KiB `read()` of the same file was
whole every time ✅. A slow source (such as `cdfs`) is the timing trigger, not the cause. The server
appears to ignore a short socket write on the passive data socket and to set no linger or send-buffer
options on it 🟡 (diagnosis from the behaviour, not yet from the server's code). An earlier 68030
bench measurement saw 57–64 % of 1.4 MB `GET`s come back short ✅ (its FTP mode not recorded).

Because the truncation is always a byte-exact **prefix**, the file looks fine and only a checksum
disagrees. And because this `ftpd` implements no `SIZE` command, a client cannot ask for the length
up front. **Workarounds:** use **active (`PORT`) mode**, and length-gate every `GET` against the size
`LIST`/`ls -l` reports, retrying on a mismatch ✅.

### 72. A local `AF_UNIX` stream socket can deliver stale data under memory pressure 🟡 {#72-af-unix-memory-pressure}

Reported by the [amix-x11-aga](https://github.com/hmlio/amix-x11-aga) project, a colour X server for
the native chipset, and not reproduced here 🟡. On Amix 2.1c, a read from a local `AF_UNIX` stream
socket can return data from whole 4 KB pages earlier in the stream when the system is short of memory
(about 8 MB of fast RAM) and the writer is non-blocking: 8 failures in 9 runs with a non-blocking
writer, 0 in 4 with a blocking one. The reporter saw it in emulation, also with the unmodified kernel
and no third-party driver, and on a real A4000 with the kernel limited to 8 MB; never with 12 MB or
more. X is where it bites: Xlib writes non-blocking and ships as binaries, so a large request (a
172 KB `PutImage`) is misparsed, the client dies with `BadIDChoice` or `BadLength`, and the server
cannot work around it.

**Rule:** give a box that runs X 12 MB or more of fast RAM. The reporter's reproducer,
`test/sockstress.c`, streams 32-bit counters through a local socket with Xlib's write pattern and
exits 2 at the first mismatch.

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

### 53. 68060: the unimplemented integer instructions trap to a vector stock Amix never populated ✅ {#53-unimplemented-integer-vector}

The 68060 does not implement every integer instruction form in silicon. The **64-bit**
`MULU.L`/`MULS.L`/`DIVU.L`/`DIVS.L` forms — a 64-bit product, or a 64-bit dividend with its
quotient/remainder register pair — are trapped out to software through the CPU's
**unimplemented-integer-instruction** exception (vector 61), for an emulation layer to serve ✅. The
stock SVR4 trap-dispatch table on this platform stops at **vector 55**, so that vector has no
handler: on a 68060 kernel that adds none, the trap falls through to the kernel's default
unhandled-vector path and the process is **SIGKILLed with no diagnostic at all** ✅ — a bare `Killed`
and exit status 137, no SIGILL, no SIGFPE, no named fault, no core, and nothing in any log. Two
consequences:

- **It is not an FPU problem, and nothing in the failure says so either way.** The affected
  instructions are *integer* ops the core leaves to software, so the kill fires identically on a
  full-FPU 68060 and on an FPU-less 68LC060 ✅. Do not file it next to the
  [SIGSYS float-printing class](#31-on-an-fpu-less-part-floating-point-dies-as-sigsys-bad-system-call)
  — that one is F-line and FPU-shaped, this one is not.
- **The 32-bit forms are safe.** `MULU.L`/`DIVU.L`/`DIVUL.L` in their 32-bit spellings are
  hardware-implemented and execute normally ✅. `CMP2`/`CHK2`/`CAS2`/`MOVEP` belong to the same
  unimplemented-integer class architecturally and should be expected to behave the same way where
  nothing emulates them 🟡 (class membership per the CPU's own definition of the set, not each form
  separately exercised).

**What the amigaux 1.0 kernels change ✅.** The 1.0 68060 kernels carry Motorola's 68060 Integer
Support Package on that vector: the 64-bit multiply and divide forms, `MOVEP` and `CMP2`/`CHK2` are
emulated and run, and only `CAS2` and a misaligned `CAS` still kill the program. Earlier 68060
kernels emulated at most some 64-bit multiply forms, so a 64-bit divide was still killed there.

Practical rule for anyone *emitting* 68060 code — a compiler, an assembler macro, a hand-patch:
keep to the 32-bit integer forms anyway, because the emulated 64-bit forms are slow and an older
68060 kernel kills the program; never emit `CAS2` or a misaligned `CAS` ✅. Because the trap is
silent, the diagnostic signature is a freshly rebuilt binary that runs a while and then dies
`Killed` with rc 137 where the previous build did not — check the instruction encodings before suspecting the program. This is distinct from the GNU `as`
2.8.1 size-bit defect on [the toolchain page](../drivers/toolchain.md), which produces a 64-bit
divide form by accident on a *68030*: same instruction family, different cause, different platform.

### 70. 68060 (emulator run): the stock 1992 `installf` crashes — use APKG's package tools 🟡 {#70-stock-installf-060}

On a 68060 kernel the **stock** `/usr/sbin/installf`, run as `installf -f core` to finalise a
package entry, dies with `User BUS ERROR at 4AFC0002` ✅. It leaves a core file in `/` and a
half-registered entry in the package database — a `contents` line whose size, checksum and date
fields are still `?`. On the same
system the project's package engine's `installf` (`/usr/apkg/bin/installf`) finalises the same entry
cleanly: exit 0, with the checksum the kernel really has ✅. Observed in an emulator run of the 68060
kernel (2026-10-03); not yet on metal 🟡.

**Rule:** on a 68060 system (no 68040 was tested), route every runtime package operation through the
APKG tools (`/usr/apkg/bin/…`); treat the stock `pkgadd`, `pkgrm`, `installf` and `removef` as suspect
there. Use the engine amigaux 1.0 ships, APKGENG 1.12.3, built without 64-bit divides ✅: the July
2026 1.12.0 build published on the package repository has its own `installf -f` and `pkgchk` killed
by them on a 68060 kernel before 1.0, which does not emulate the divides
([§53](#53-unimplemented-integer-vector)) ✅.
Why the stock binary faults is not established 🔴 — the same kind of 1992-binary-meets-new-CPU
problem as [§53](#53-unimplemented-integer-vector) is a plausible family, not a diagnosis. Run such
tools from a scratch directory such as `/tmp`, so a crash cannot leave a core file in `/`. See
[package management](package-management.md).

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
command timeout of about **20 minutes**, not the usual seconds ✅. **Never score a timeout on a deep `cdfs` read as a read failure** — re-run it with
a real timeout before concluding anything.

### 35. A zero behind a gate needs a pre-gate denominator ✅

Withdrawn 2026-10-04 (test methodology, not an Amix fact).

### 36. An optimised probe reporting "no fault" must be disassembled first ✅

Withdrawn 2026-10-04 (test methodology, not an Amix fact).

### 37. A one-byte binary diff is not understood until the byte is decoded ✅

Withdrawn 2026-10-04 (test methodology, not an Amix fact); the kernel fact (the controller registry's row-count bound must be widened with the table it names) lives on [kernel composition](../drivers/kernel-composition.md).

### 38. `uptime` and `w` do not report the machine's load ✅

Two independent stock defects: `nlist(3)` cannot resolve `avenrun` (a COMMON symbol in the `ET_REL`
kernel) and *succeeds anyway* with the alignment as the value — so the printed number is whatever
sits at a bogus address, flat `0.00` and six-digit garbage being the same defect; and the kernel's
own load count omits the on-CPU process, reading exactly N−1 even when read correctly. Full story,
measurements and the working read recipe: [load averages](load-averages.md).

### 42. When you move a boundary, sweep the neighbours ✅ {#42-neighbour-sweep-law}

Withdrawn 2026-10-04 (method note); the kernel fact (segkmap is sized from physmem) lives on [the RAM ceiling](ram-ceiling.md).

### 43. `nm` and relocation similarity are not enough to place a binary patch ✅ {#43-disassembly-diff-gate}

Withdrawn 2026-10-04 (method note); the kernel fact (segkmap is sized from physmem) lives on [the RAM ceiling](ram-ceiling.md).

### 44. On-box `adb -k` needs a namelist that still has a symbol table ✅ {#44-adb-namelist}

`adb -k` reads symbols from a **namelist file**, and on Amix the obvious candidate is the wrong one:
`/stand/unix` has been through `elf2brel`, which **discards the symbol table** ✅. Point `adb` at it
and you do not get a clean failure — you get resolutions that are silently meaningless.

Keep an unstripped namelist beside the kernel (`unix.namelist`, the pre-`elf2brel` object) and read
against that ✅. The rule generalises: on this platform, *the file you boot and the file you debug
against are two different files* — verify the one you hand a debugger actually has a symtab before
believing anything it prints.

**The one exception is a kernel linked natively on the box.** A `/stand/unix` produced by an on-box
native link still carries its symbol table, so there it **doubles as its own `adb` namelist** ✅ —
`adb -k /stand/unix /dev/mem` resolves correctly, and no separate namelist file is needed. So the
invariant to check is not *which file* but *does this particular file still have a symtab*; the
answer depends on how that kernel was produced.

### 45. Heavy raw `dd` to the boot slice can reboot the box 🟡 {#45-boot-slice-dd}

On one machine, a large raw `dd` to the boot slice **spontaneously rebooted it mid-write** 🟡.
This is a single-unit observation with no known mechanism, so it may be a fault of that unit rather
than Amix behaviour. Because the reboot kills the session that issued the command, the operator
sees a transport failure — a dropped
connection or a timeout — and the natural conclusion is that the write never happened.

**Trust the on-disk record, not the session.** Have the job write its own verify line to a file on
disk, and read that file on the next boot; the session's exit status is not evidence either way. The
general shape is worth naming: **an operation that destroys its own reporting channel always looks
like a failure** — and re-running it blindly is how a half-written boot slice becomes an unbootable
one.

### 46. `adb -k` prints a one-byte kernel flag as a big-endian int ✅ {#46-adb-byte-flag}

Reading a driver's boolean flag out of a running kernel prints an absurd number:

```text
# echo 'z3660_direct_map/D' | adb -k /stand/unix /dev/mem
z3660_direct_map:       16777216
```

**The flag is set, and the read is correct.** `16777216` is `0x01000000`: the flag is a **one-byte**
object, `/D` reads **four** bytes and formats them as a big-endian signed int, so a set byte at the
object's address lands in the top byte of the word ✅. Nothing is wrong with the kernel — the format
letter is wrong for the object's width.

Read a byte object with a byte format, or learn the shape: `16777216`, `65536` and `256` are "a byte
holding 1, read as a 4-byte int" at the first, second and third byte of the word. The trap is
expensive precisely because the wrong answer is *plausible* — a reader who has just patched a driver
sees a huge number and concludes the flag was never initialised.

### 47. A successful remote halt looks like a transport failure ✅ {#47-halt-looks-like-failure}

`sync; sync; /sbin/uadmin 2 0` issued over the box's telnet transport **kills the session executing
it**, so a remote runner reports a transport failure — a no-route or a timeout ✅. **That
signature is the success case.** It is the same family as [§45](#45-boot-slice-dd): an operation that
destroys its own reporting channel always looks like a failure, and re-running or power-cutting it
"because it failed" is how a completed clean halt becomes a dirty one.

**The proof of a clean halt is the next boot, not the halt.** Amix keeps no persistent boot log
([§40](#40-no-persistent-boot-logging)), so the evidence is a **verification boot whose console shows
`fsck` repairing nothing** ✅. Observed twice on a real A4000 + Z3660: runner "failure", fsck-silent
next boot, clean filesystem.

Image a disk only after a halt that a fsck-silent boot has proven clean, or every clone inherits a dirty filesystem.

### 58. A run-level change requested over telnet while the console sits at `login:` stalls in stock `init` ✅ {#58-console-getty-shutdown-stall}

`shutdown -y -g0 -i6` (or `init 6`) issued from a **telnet** session while **nobody is logged in on
the console** — the console `getty` sitting at `login:` — stops at `INIT: New run level: 6` and goes
no further ✅. `init` kills `sac` and the console `getty`, then waits; `/etc/rc6` is never spawned, a
second `init`/`HUP` is ignored, `who -r` reports level 6, the disk keeps working and telnet still
answers. Only a power cycle brings the box back.

It is **stock `init`, not a driver**: discriminated in eight runs (2026-09-29), it reproduces
identically on the stock kernel on an A3000 with no third-party driver. With a **root shell logged in
on the console** the same command reboots normally (100–150 s) on every kernel tried ✅. The stall is
proven for level 6; a level-0 halt requested the same way completed in the one run that tried it 🟡.
The root cause inside `init` is open 🔴 (it needs `init`'s symbols or a crash dump).

**Rule:** request run-level changes from a console root shell, or keep one logged in while you work
over the network. A box that has stalled this way still answers telnet: `sync; sync`, then
power-cycle ([§49](#49-power-cycle-law)), and expect `fsck` on the next boot. As with
[§47](#47-halt-looks-like-failure), a remote shutdown is proven only by the boot that follows it.

### 48. A USB-serial console is a single-reader channel ✅ {#48-stray-serial-reader}

Withdrawn 2026-10-04 (host-side bench practice, not an Amix fact).

### 49. A warm reset is not a clean-state reset — power-cycle, and leave it off 🟡 {#49-power-cycle-law}

A single-unit observation — one Z3660 card running the stock accelerator firmware, in the emulated-CPU
boot mode, not yet reproduced on a second card 🟡:

| reset path | correct reset vector read |
|---|---|
| power cycle / cold boot | **5 / 5** |
| the firmware's warm-reset command | **0 / 3** |

Every warm-reset failure read the reset vector as `0xFFFFFFFF`; the emulated 68k then ran from a
garbage PC and scribbled down through the board's registers and the exception vectors, leaving a
black screen and a flood of unhandled-write messages on the serial 🟡. On that card a warm reset was
fine for "start the machine again" and useless for "start it from a known state".

**Why an odd value at address 4 is not evidence of a corrupted ROM.** With the Kickstart **overlay
cleared**, address 4 is *chip RAM*, not ROM ✅ — an unexpected value there is **stale memory**, not a
corrupted ROM fetch, and a single-bit difference between two observed values is not a bit flip. 

**The off interval is part of the procedure.** Allow **≥15–20 s off** between power-off and
power-on.

**Consequence for any procedure needing a known-clean machine** — a diagnostic run, a clock change, an
acceptance test: power-cycle with a ≥20 s gap, and *gate* the run on the reset vector the firmware
prints before trusting anything the run produces.

### 50. A diagnostic ROM's error mask is sticky within a boot ✅ {#50-sticky-mask}

Withdrawn 2026-10-04 (bench evidence practice, not an Amix fact).

### 51. Memory detection that reads back immediately is fooled by capacitive echo ✅ {#51-capacitive-echo}

A detection probe that **writes a pattern and reads it straight back** cannot tell populated memory
from an **unpopulated bus still holding the value it was just driven with** ✅. Two independent
instances in a single session: a 16 MB motherboard window whose top 4 MB is genuinely empty passed
detection, and a phantom *"Detected 127MB of memory"* over a range the emulator maps to a dummy bank —
one whose reads return all-ones and whose writes are discarded.

**Treat any "Detected NNN MB" as unverified until a whole-block address check confirms it** — fill the
whole block with address-derived data and verify it afterwards, once the echo has decayed.

The same caution applies to a hand-rolled peek/poke check: one that probes only low addresses proves
only that the low addresses echo.

### 52. A run whose boot path was not examined is not evidence ✅ {#52-boot-path-evidence}

Withdrawn 2026-10-04 (bench evidence practice, not an Amix fact).

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
returns 0, while the disc appears "still mounted." This imitates a **broken `umount`** convincingly: a direct `umount(2)` returns 0 with the
filesystem apparently still there, while the real cause is silent stacking on repeated mounts ✅. Stock filesystems guard this in their
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
[building a kernel](../drivers/kernel-build.md#scripting-the-kernelc-edits-with-ed-the-half-patch-trap).

### 63. Stock `dd.c` counts every unit in 512-byte blocks — a 2048-byte CD driver must cap the transfer ✅ {#63-dd-512-unit-overrun}

The stock disk layer addresses **every** SCSI unit in 512-byte units (`count = b_bcount / 512`),
whatever the device's real block size ✅. A driver for a **2048-byte** CD unit that multiplies that
count by its own block size asks the device for **four times** the caller's buffer, and the device
writes it linearly over unrelated memory. On the Z3660 this was the kernel hang behind a raw `dd` of a
CD unit (`/dev/rdsk/c3d0s0`), and the slice open's RDB scan was itself a 1 536-byte overrun ✅. `cdfs`
was never affected — it queues its own correctly-sized requests.

**Rule for driver authors:** before issuing a READ/WRITE, refuse any request whose block count ×
block size exceeds the buffer (`nbyte`) — fail it with `EIO`, count it, and never touch the hardware.
The Z3660 SCSI driver does exactly this since 2026-10-02 (raw `dd` of a CD unit at 512, 2048 and
65 536-byte block sizes returns `I/O error`, the box stays up, the refusal counter steps by 3 — metal,
A4000T) ✅. Kernels without the fix still hang on a raw read of a Z3660 CD unit; mount it with `cdfs`
instead.

### 65. Stock `autocon()` can never match a board whose manufacturer id is ≥ `0x8000` ✅ {#65-autocon-signed-manufacturer}

A driver asks `autocon()` for its board by a 32-bit id, manufacturer in the high half and product in
the low half. Stock `autocon()` (`amiga/kernel/support.c`) holds that id in a **signed** `long` and
compares the board's `er_Manufacturer` with `id >> 16` — an **arithmetic** shift, so for a
manufacturer id at or above `0x8000` the high half comes back sign-extended (`0xC0DE0001 >> 16` =
`0xFFFFC0DE`) and never equals the unsigned 16-bit field ✅. The board is handed over correctly —
boot2 copies every ConfigDev into `bootinfo.autocon[]`, and a read of the live kernel shows the
entry with exactly the right id — yet the driver's `autocon()` call misses it, `sd` registers no
controller, and nothing is printed ✅.

Nobody saw it for 30 years because every Commodore id (`0x0202`), the Z3660 (`0x144B`) and the
other boards Amix has met sit below `0x8000`; the **A4092** (`0xC0DE`) was the first ✅. **Fix:** make
the shift unsigned. In source that is a cast in `support.c` (the compiler's `swap`/`ext.l` becomes
`clr.w`/`swap`); in an already-linked kernel it is one byte, the shift's `asr.l` → `lsr.l`. Ids
below `0x8000` are unaffected. Proven on metal 2026-10-02: on an A4000D the A4092 at `0x40000000`
was handed over but never registered without the fix, and registers as card 1 with it ✅. A driver
for a board with a high manufacturer id cannot rely on stock `autocon()`; it needs the fixed kernel
(or its own scan of `bootinfo.autocon[]`).

### 69. What a 68040/68060 kernel actually sends to the disk: 2 KiB pieces, inode blocks twice ✅ {#69-040-060-disk-write-stream}

Measured on the project's emulator rig (2026-10-03, a capture of every disk write, replayed
exactly onto the image) and read from the kernel binary — the facts a disk-driver author or an
on-disk forensics tool needs about a 68040/68060 kernel relinked from the stock 2.1c binary (4 KiB
pages) ✅:

- **Every write larger than 4 KiB reaches the driver as 2 KiB requests.** The buffer cache breaks
  the buffer up: the first piece runs to the page edge, then `min(remaining, 0x800)` — a 2 KiB
  constant left unconverted in the stock-derived code. A page-aligned 8 KiB UFS block therefore
  arrives as **four 2 KiB requests** at consecutive LBAs; raw (`physio`) I/O is cut into 2 KiB pieces
  as well; a request of 4 096 bytes or less passes whole.
- **A UFS inode block is written twice per `sync`**, about 70 ms apart — even for a single
  `touch f; sync`. The second flush rewrites all four pieces (in the captures, three of them byte-identical to
  the first flush and one carrying updated inode values). A transient fault on the first write of the
  pair is healed by the second; only a fault on a block's **last** write persists on disk.
- **The disk layer's error path never misplaces data.** With a driver refusing one 2 KiB piece of a
  four-piece inode-block write, the refused piece reached no LBA, the rest of that pass was not
  issued, and the next flush rewrote all four pieces at their own LBAs (the write record replayed
  exactly). The retry in `dd.c` rebuilds address and command from the same buffer header.
- **Forensics note:** a shifted or duplicated window of inodes carries **newer** time stamps than its
  original, because the copies are re-stamped on later use. A detector that compares inode copies
  must mask the dinode time fields, or it misses exactly the cases it is looking for.

### 71. A boot node's `fssm_Device` length counts its NUL — compare it as a C string ✅ {#71-fssm-device-nul}

`expansion.library` `MakeDosNode()` (LVO −144) stores the exec device name as a BSTR and then adds 1
to its length byte, so `fssm_Device` for `foo.device` has length 11 with the NUL counted; the DOS name
`dn_Name` is not adjusted ✅. The sequence is the same in all 52 checked Kickstart images from 2.0
(r36.141) to 3.2.3 (47.115) ✅; 1.x was not checked 🟡. The strap itself opens the device from
`BADDR(fssm_Device)` + 1 as a C string and never reads the length ✅ (3.2.3; other releases 🟡). A
loader or mount tool that walks `eb_MountList` and matches `fssm_Device` against a driver's
`ln_Name` over the counted length reads one byte past that name's NUL, so it must stop at the first
NUL instead. Layout, offsets and ROM evidence: [boot process](boot-process.md#fssm-device-nul).

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

In the SVR4 Bourne shell, **`&;` is a syntax error** ✅. So a command line that ends in a bare,
unparenthesised `&` and then has `; <something>` appended — as any tool does that tacks a completion
marker such as `; echo DONE_$?` onto each command it sends — fails to parse, and **the job meant to
run in the background never starts at all** ✅. Nothing on the line runs, so the marker never comes
back either.

**The fix is to parenthesise the background launch** so the line ends in `)`, which composes fine
with an appended `; …`: `(nohup sh job.sh > /job.out 2>&1 &); echo DONE_$?` ✅. A `&` that is not
last on the line, such as `cmd & echo launched-$!`, is not affected.

### 73. Amiberry before upstream `845af02`: `MOVES` across a page boundary corrupts Amix data 🟡 {#73-amiberry-moves-page-boundary}

Reported by the [amix-x11-aga](https://github.com/hmlio/amix-x11-aga) project, and not reproduced
here 🟡. In Amiberry builds before upstream commit
[`845af02`](https://github.com/BlitterStudio/amiberry/commit/845af02) (2026-10-06, a merge of WinUAE
updates), the 68030 MMU's "more compatible" mode — `cpu_compatible=true`, which
`cpu_memory_cycle_exact=true` also forces — did not split a misaligned `MOVES` access across a page
boundary. Amix copies between kernel and user space with `MOVES`, so files, the kernel heap and X
traffic were corrupted. The reporter caught it by compiling the same C file three times and comparing
the outputs.

**Rule:** use an Amiberry build that contains `845af02`; with an older build, set
`cpu_compatible=false` and leave `cpu_memory_cycle_exact` off, since it forces the mode back on.

## Time & Y2K quirks

### 7. Y2K and the battery clock: a `setclk` bug, not a kernel cap ✅/🟡 {#7-y2k-setclk-and-the-kernels-1999-date-cap}

Amix has one real millennium problem, and it sits in the tool that reads the battery clock ✅:

1. The `setclk` utility uses a `%02d` format for the year, so it mishandles dates ≥ 2000.
2. ~~The kernel caps the date at 1999~~ — **corrected 2026-09-29 ✅:** the kernel has NO year cap: `date 092912002026` sets 2026 on a stock 2.1c box. What fails is the tooling: the 2-digit form reads `yy` as `19yy` (clamped at the epoch), the 3-digit form that the stock `setclk` produces (`%02d` of years-since-1900 → "126") gives `date: bad conversion`, and `amixadm`'s finishing-touches step only accepts ≤ 1999.

**What a stock box does at boot ✅.** `/etc/sysinit` runs `/usr/amiga/bin/setclk` at every boot, and the stock `setclk` hands the battery-clock time to `date` in that 3-digit form. `date` refuses it (`date: bad conversion`), nothing else in the rc scripts reads the RTC, and the system clock stays where the kernel started it — on the bench images that was 1977. So a stock box comes up with the wrong date **even when its battery clock is correct**. Measured on a real A4000T (RP5C01 at `$DC0000` ticking, holding the set time through a power-off) and on the bench with the stock image, 2026-09-28/29.

**The fix is a corrected binary, not a kernel change ✅.** The patch disk upgrades to **2.1p2a / kernel 2.1c**, but its cpio carries **no** `setclk` (checked 2026-09-29: 103 members, none is setclk 🟡→✅ corrected). The corrected `setclk` is a separate **community binary** from the 2007 amiga.org thread (Piru's `%02d`-year/buffer fix, a_petri's 4-digit-year follow-up), published on the AmigaUnix wiki's y2k-dst page (binary sha256 6022274f…, with both diffs against `setclk.c`; no licence statement); it can be rebuilt reproducibly from the installed images' `/usr/amiga/src/cmd/setclk` plus those diffs. Because `sysinit` already calls `setclk`, replacing the binary is enough. With it, the console shows a `setclk:` line and the clock is right from the first boot ✅.

**Three details that decide whether the time is right ✅** (measured on the metal and the bench, 2026-09-29):

- **`/etc/clkzone`.** `setclk` reads the RTC value in the zone named in `/etc/clkzone` (`:<zone>`, the tzfile form; default `:GMT`). AmigaOS keeps the battery clock in **local** time, so set `/etc/clkzone` to the box's zone or the clock runs hours off (2–3 h in Finland).
- **Seconds.** The stock route goes through SVR4.0 `date`, which takes no seconds, so even a working Y2K-fixed `setclk` that calls `date` starts the box up to 59 s slow. A `setclk` that sets the time directly (`stime`) is exact to the second.
- **The zone files are 1991 data.** `/usr/lib/locale/TZ` holds 1991 tzfiles with 1991 rules: the European zones end summer time on the last Sunday of **September** (EU since 1996: October) and the US zones use the pre-2007 rule, so in 2026 a Finnish box showed EET while the country was on EEST — the clock was right in UTC and wrong by one hour as local time. Regenerating the compiled zones from current tzdata, in the 1991 file layout the Amix libc reads, fixes it; no-DST zones are unaffected.

The RTC's year register itself holds the AmigaOS battery-clock encoding (years since 1900, so the tens digit runs past 9); the kernel's `/dev/clock` driver encodes and decodes it, and a clock set from AmigaOS and one set from Amix agree ✅. See the patch mechanism in [the patch ADF anatomy](../boot-disks/anatomy-patch-adf.md) and the version timeline in [versions](../reference/versions.md); for why the clock must never be set *forward* on a box with password ages, see [§20](#20-password-expired-is-the-future-lastchg-check-never-set-the-rtc-forward).

### 20. Password expired is the future-lastchg check, never set the RTC forward ✅

An SVR4 box whose RTC battery is dead boots believing it is **January 1978** (~day 2923 of the Unix
epoch). If a previous session ever "fixed" the clock by **setting it forward**, that stamped
`/etc/shadow`'s `lastchg` field far in the future (e.g. 8117 = 1992). On the next cold boot — back at
1978 — `lastchg` is now **in the future relative to "today"**, and SVR4 `login` treats a future
`lastchg` as **expired**, forcing a password change at every login ✅. This is the *future-dated*
check, **not** the max-age rule, so it recurs on every 1978 boot and stalls `amixrun.py`-style
automation at the password dialog. Root-caused on a real A4000 + Z3660 ✅.

**Reliable fix at the prompt:** set the new password to the **same value** (SVR4 accepted a 4-char root
password here); with the clock at 1978 the new `lastchg` (~2923) is not future-dated, so it does not
recur. **Do NOT "fix" it by setting the RTC to now** — that re-arms the trap for the next cold boot ✅.
The deep fix for a golden image is to set `lastchg` to a **pre-1978 value offline**. (This is a
distinct problem from the [Y2K/`setclk`](#7-y2k-setclk-and-the-kernels-1999-date-cap) bug above —
here the danger is setting the clock *forward*, not past 1999.)


### 57. The stock kernel finds the A3000's internal SCSI only if the LOADER put the kernel above 0x07000000 ✅ {#57-loader-placement-a3000-scsi}

The A3000's WD33C93 is not an AutoConfig board. Stock 2.1c `autocon()` registers it through a guess (`.text 0x19222`): `if (index==0 && end > (char *)0x07000000 && pc==0x0202F003) *bp = 0xdd0000` — where `end` is the kernel's own end symbol, i.e. **where boot2 placed the kernel**. With the classic 16 MB motherboard bank at 0x07000000 the kernel loads there and the guess fires (card 0, root on c6d0s1). With 64 MB at 0x04000000 (or any layout that loads the kernel below the line: accelerator fast RAM elsewhere) the guess is skipped, no card 0 exists, `sdopen` answers ENXIO and the boot ends in `s5mountroot VOP_OPEN error 6` / `vfs_mountroot errno 89`. The seven 1-byte reads at 0xfffffffa/c/e that follow are the panic's own `backtrace` decoding its terminal frame, not a memory probe. Measured on the bench 2026-09-29 and symbolised on the stock kernel. The "16 MB ceiling" folklore is this guess's only working placement. Fixes: the A4091 project's `support.c.patch` (chipset gate + a real WD33C93 probe) on the 030 line, and an equivalent probe in the 040/060 port. See §41 for the A4000T's $DD0000 case.

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

A `/etc/TIMEZONE` that sets `TZ=US/Eastern` **without a leading colon** makes every SVR4 program that calls `localtime()`/`tzset()` die with `User BUS ERROR at 474D5400` ✅ — and `0x474D5400` is ASCII `"GMT\0"`, the GMT-fallback timezone abbreviation being dereferenced *as a pointer* after the POSIX-rule parser chokes on the `/` in the zone name. The fix is the **colon** form, `TZ=:US/Eastern`, which tells SVR4 to load `/usr/lib/locale/TZ/US/Eastern` as a tzfile path instead of parsing it as a rule (a valid POSIX rule string such as `EST5EDT` or `GMT0` also works — for a zone file always use the colon form, e.g. `TZ=:EET`). The crash set is exactly the localtime callers — `date`, `who -r`, `cron`, `sac`, `ls -l` — while console `login` survives (it needs `getpwnam`, not localtime), which is the tell that distinguishes this from the passwd-side defect. Second-order symptom: a crashed `who -r` empties the positional parameters in the `/etc/rc2.d/S*` scripts that begin `set \`who -r\``, so those degenerate into `test: unknown operator S` at boot. Note this is a **constant** fault address at cold boot — do not confuse it with the emulator's variable-address MMU-frame bus errors ([emulation fidelity](emulation-fidelity.md)).

### 22. Reused writable test media accumulates state that masks bugs ✅

The Amix fact behind this item: a freshly built miniroot ships no `/etc/mnttab`, and its bare `mount(2)` writes none, yet `pkgadd` needs the file — without it the install stops with `pkgadd: ERROR: unable to open mount table (/etc/mnttab)` ✅. An installer running from the miniroot must therefore seed the file with a `/` line before it calls `pkgadd` (`echo "/dev/root / s5 rw 0" > /etc/mnttab`). A reused root floppy that still carries an `/etc/mnttab` from an earlier mount hides the missing seed. Why the `/` line matters: [package management](package-management.md).

### 28. The partitioning tools' units are 512-byte blocks, and `rdb` won't tell you its own grammar ✅

Three conventions of the miniroot's partitioning tools, each of which bites a scripted install, all bench-proven ✅ (first-party, 2026-07-31):

- **`/etc/rdb -c` requires `-d disksize` — in 512-byte blocks — and `-d` is absent from the usage text the tool prints when it refuses.** The working grammar cannot be learned from the tool itself; the authority is the stock install script (`/etc/profile` on the root floppy).
- **`/etc/rdb -p` takes a 1-based partition number, never a device path** — the argument is `atoi()`-ed, so a path decodes as 0 and every flag/type stamp is refused. Partitions are appended in slice order, so partition *N* is slice *N*.
- **`mkfs_s5`'s size operand is also 512-byte blocks** — it converts to its 1 KB logical blocks itself; hand it a pre-converted count and it builds a filesystem over **half** the slice, silently.

Full grammar, units, and the read-back proofs on [filesystems & disks](filesystems-and-disks.md#etcrdb-and-mkfs_s5-the-grammar-and-the-units); the stock script's own command lines on [the root-floppy anatomy](../boot-disks/anatomy-root-adf.md#the-install-script-is-etcprofile).

### 62. On-box `mkfs` fails on a root slice above ~603 MB, and a raw read past it sleeps forever ✅ {#62-sddevsize-603mb}

Stock `sddevsize()` (`amiga/alien/sdpart.c`) answers a partition's real length only once the
partition table has been read; for any other slice it returns a fixed "large number", **1 234 567
blocks** (602.8 MiB) ✅. Stock `dd.c` clamps every raw read and write to that size and reports it as
the device size. Two failures follow, on 68030 and 68060 kernels alike ✅ (bench, 2026-10-02):

- **`mkfs_ufs` cannot author a root slice above 1 234 567 blocks.** Its first write probes the slice's
  last sector, which lies past the default, and fails: `write error: D / wtfs: No such device or
  address`, rc 32, nothing written (`fsck` then reports `BAD SUPER BLOCK`). The RDB itself is written
  correctly. Bracketed exactly: a root of 1 234 560 blocks authors, 1 234 624 does not; 600 MB disks
  author, 640/900/992/1024 MB disks fail. Host-side minted images are unaffected.
- **A raw read that starts past the default never completes.** On a whole-disk node (`c?d0s0`, never
  partitioned, so always at the default) the remaining count goes negative and the process sleeps
  forever: block 1 100 000 reads, 1 300 000 hangs.

**Fix (proven on the bench, 2026-10-02) ✅:** raise the default to `0x3FFFFF` blocks (the largest whose
byte offset still fits a signed 32-bit value) and make `dd.c` refuse an offset past the size instead
of computing a negative remainder. With it, 600/640/900/992/1024 MB roots all author, and the
whole-disk read past the end returns `I/O error` instead of sleeping. Until a kernel carries the fix,
keep an on-box-authored root at or below 1 234 567 blocks.

## See also

- [Hardware](hardware.md) — the machines, RAM ceiling, Zorro II, FPU/MMU requirements in full.
- [Boot process](boot-process.md) — Superkickstart, the bootstrap, and on-disk layout.
- [Networking](networking.md) — DNS, routing, SLIP, NFS, and clock notes.
- [X11 & desktop](x11-and-desktop.md) — the X server, window managers, and keymap.
- [Glossary](glossary.md) — RDB, AUTOCONFIG, STREAMS, Superkickstart, and other terms used here.

## Sources

- The **`fssm_Device` NUL count** (2026-10-07) ✅ — disassembly of `expansion.library` `MakeDosNode` and the `strap` in Kickstart 3.2.3 and 3.1 r40.68, and a check of 52 Kickstart images from 2.0 to 3.2.3 (first-party record, 2026-10-07); NDK `dos/filehandler.h` (quirk 71). Details on [boot process](boot-process.md#fssm-device-nul).
- The **2026-09-29 stock-kernel RAM-layout measurement** ✅ — on the emulated bench the same 64 MB A3000 motherboard bank boots a kernel that probes for the A3000 SCSI and stops the pinned stock kernel at `s5mountroot VOP_OPEN error 6` (no card 0), symbolised against the stock `autocon()` load-address guess (first-party record, 2026-09-29; [quirks §57](quirks.md#57-loader-placement-a3000-scsi)).
- Research brief §12 (quirks checklist), with specifics pulled from §2 (hardware & limits), §9 (install flow + `viper_kludge`/Y2K), and §11 (networking, X11, userland).
- [`amix_21_root.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh` — `/dev/rmt/4h`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`, `amixpkg -i -m -d -r /mnt -y standard`.
- [`amix_21_patch.adf`](https://www.amigaunix.com/) analysis via `tools/inspect-adf.sh` — patch-disk Y2K/inet fixes (→ 2.1p2a / kernel 2.1c).
- `asokero/va2000-amix` (pre-POSIX `/bin/sh`, no `$(...)`, no `grep -q`; relink hygiene) — <https://github.com/asokero/va2000-amix>.
- Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (driver/kernel model behind the SCSI-ID and `/bin/sh` notes).
- amigaunix.com DokuWiki — requirements, networking, x11, patch-disk, y2k-dst, tips-tricks, dual-boot pages (community-reported items): <https://www.amigaunix.com/doku.php/home>.
- BlitterStudio/amiberry issue #1376 and WinUAE/FS-UAE docs (emulation consequences of the SCSI IDs and RAM ceiling).
- The A4091-on-Amix project — networking investigation, 2026-06-07 (reproduced locally ✅): instrumented `/etc/rc2` per-script timing on Amix 2.1c under Amiberry isolated `S69inet` at 180 s; boot **210 s → 29 s** after switching the boot-time `ifconfig`s to literal IPs. Files: `/etc/rc2.d/S69inet`, `/etc/inet/network-config`, `/etc/inet/rc.inet` on the running system (quirk 13).
- The amix-z3660net project — the `z3660eth` driver bring-up on a real A4000 + Z3660, 2026-06-21 ✅: the firmware INT6-per-RX-frame storm (Amix has no level-6 ethernet handler) and the disable-IRQ/poll fix (`ZZ_CONFIG_DISABLE`, `timeout()` RX drain), diagnosed via the firmware serial `[PC]` heartbeat + `nm` of `relocunix` (quirk 14). See [the Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md).
- The [amix-z3660scsi](https://github.com/jusii/amix-z3660scsi) project, commits `86b7a37` (the multi-method detect, quirk 15) and `0d67693` (the emulator triage, quirk 16) — the `z3660` piscsi block-driver bring-up on a real A4000 + Z3660, 2026-06-12/13 ✅: the 2.1 `bootinfo.autocon[]` miss and the multi-method detect that cleared the silent hang (quirk 15), and the firmware-emulator-vs-driver triage (quirk 16 — the apparent hang was the 68k emulator demand-paging the driver's own pages, not the driver; firmware-owned fix, cited not reproduced). See [the Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md).
- Research brief §19 (emulation fidelity), from the Z3660 firmware project (branch `amix-main`, 2026-06) — quirk 17 (the A3000-SCSI bootstrap's INT2 sensitivity to interrupt-service cadence; the `service_cadence` knob ✅ / the 4-boots-8-hangs boundary 🟡) and the emulator-side mechanism behind quirk 16 (68030 bus-error-frame fidelity on the demand-paging path). See [Emulation Fidelity](emulation-fidelity.md).
- Research brief §20 (stock SVR4 package system), from the amix-packagemanager project (firsthand on a clean Amix 2.1c image, 2026-07-01) — quirk 10's `amixpkg`-is-install-media-only correction ✅/🟡, and quirk 18 (the `/var/sadm/install/contents` space-in-pathname record that breaks `pkgrm`/`pkginfo -l` out of the box, ✅). See [Package management](package-management.md).
- The **amix-cdfs** project @ `31e8c3b` — quirk 19 (`mount(2)` silently stacks on an already-mounted directory; `mount(2)`'s only busy check is `v_vfsmountedhere`, which `lookupname` clears by traversing into the mount; guard in the fs's own mount op like `prmount`/`fdmount`), from stock-kernel disassembly + reproduction on a real A4000 + Z3660, 2026-07-13 ✅ (`844c2ed`). See [the driver model](../drivers/driver-model.md#writing-an-in-kernel-filesystem-the-svr4-vfs_mount-contract).
- **Bench forensics** (first-party record, 2026-07-11) — quirk 20 (SVR4 `login`'s future-`lastchg` "expired" trap on an RTC-1978 box after a clock was set forward; same-password workaround, never set the RTC forward), root-caused on a real A4000 + Z3660 ✅.
- The **Installer-NG** field work (first-party record, 2026-07-22/24; the projects are public as [amix-installng](https://github.com/jusii/amix-installng) and [amix-packagemanager](https://github.com/jusii/amix-packagemanager), released as amigaux 1.0) — a blank-disk→bootable-install effort that root-caused these platform behaviours on the Amiberry bench and the real A4000+Z3660 (acceptance-run captures, s5/UFS state reads, and the on-metal digest attestation) ✅ (🟡 where tagged).
- The **`inetd` investigation** and a **wedge soak on the `cdfs` bench** (first-party record,
  2026-07-26/27) ✅ —
  quirk 23 (the `TOOMANY=40` / `CNT_INTVL=60 s` / `RETRYTIME=600 s` throttle read out of the shipped
  `/usr/sbin/inetd` as compile-time immediates, the absent `nowait.<max>` syntax proven by disassembly
  *and* a live `SIGHUP` test, per-service independence measured both directions, and the rate bound:
  29.9/min never trips in 200 invocations, ~575/min trips within seconds) and quirk 24 (the
  vendor-hardcoded `exit` in `/etc/init.d/syslogd`, its 3-hard-link `cp`-in-place hazard, `/var/log/*`
  rather than `/var/adm/messages`, and the measured 293 B of log growth under abuse). Quirk 26's
  `netstat -a` control run and the `sar -v`/`ipcs -a` failures are from the same soak's wedge-time
  capture ✅.
- A **`cdfs` bench run** (first-party record, 2026-07-26) ✅
  — quirk 27: on a 1.25 GiB multi-extent UDF disc, `dd skip=` to the 1 GiB mark transfers rather than
  seeks and needs a ~20-minute command timeout.
- A **read of the upstream Amiberry source** ([BlitterStudio/amiberry](https://github.com/BlitterStudio/amiberry):
  `src/cfgfile.cpp` `default_prefs()`, `src/main.cpp` `fixup_prefs()` → `fixup_cpu()`, `src/osdep/amiberry.cpp`
  `default_disable_cycle_exact`) and a **rig ablation** on the emulated bench (first-party record,
  2026-07-26) ✅ — quirk 25: the
  `default_prefs()` all-true initialisation, the four non-equivalent config keys, the host-dependent
  `default_disable_cycle_exact`, the `fixup_prefs()` host-log tell (present in 6/6 omitting runs,
  absent in 10/10 pinning runs) and its `cpu_compatible` side effect, and the 10-boot single-variable
  ablation whose decisive run added `cycle_exact=false` and nothing else.
- The **Installer-NG** author-mode matrix proof (amix-installng, 2026-07-31) ✅ — quirk 28: the stock `/etc/rdb -c`/`-a`/`-p` + `mkfs_s5` sequence run on a blank bench disk and read back host-side (the `-d` refusal and its absence from the usage text; the `atoi()` 1-based partition-number convention; the 512-byte-block `mkfs_s5` operand), with the stock install script (`/etc/profile` on the root floppy, read by path with an s5 reader) as the reference caller. See [Filesystems & disks](filesystems-and-disks.md#etcrdb-and-mkfs_s5-the-grammar-and-the-units).
- Linux mainline `arch/m68k/amiga/config.c` — the A3000/A3000T-only `MAGIC_REKICK` hardware feature
  ("Magic Hard Rekick") and its `0xde0002 |= 0x80` write, commented as forcing a hard rekick —
  grounding quirk 29's A3000 register semantics ✅:
  <https://github.com/torvalds/linux/blob/master/arch/m68k/amiga/config.c>.
- BlitterStudio/amiberry, `src/gayle.cpp` (`mbres_write`/`mbres_read`; the bank is mapped at
  `0xde0000` in `src/memory.cpp`) — the UAE-family model of `0xde0002`: Fat Gary's bit-7
  "coldreboot flag", settable and readable (read-back gated on a configured Fat Gary revision), with
  no consumer — grounding quirk 29's A4000 side ✅: <https://github.com/BlitterStudio/amiberry>.
- First-party stock-kernel analysis and the project's metal-boot record (real A4000 + Z3660),
  2026-07 ✅ — quirk 29: the stock kernel's unconditional `0xde0002` write in both the boot and the
  reboot/halt paths, and its benignity on the A4000, where every metal boot forwards the write
  through the accelerator to the physical bus with no ill effect.
- A **cdevsw free-row gate and half-patch audit** (first-party record, 2026-07-30/31) and the
  [amix-z3660net](https://github.com/jusii/amix-z3660net) patch-script hardening (`603c719`) ✅ —
  quirk 30: the `ed` miss-then-write half-patch reproduced host-side with GNU `ed` over the real
  stock file layouts, its name-wide-grep permanence, the wrong-row-overwrite and wrapping-search
  variants, and the pre-probe / one-run-per-edit / post-verify-the-row pattern. See
  [building a kernel](../drivers/kernel-build.md#scripting-the-kernelc-edits-with-ed-the-half-patch-trap).
- The project's **transport lint** (first-party record, 2026-08-27) and the two live defects it
  generalises from — an `amix-kerntools` runner defect (first-party record, 2026-08-27) and the
  [Z3660 firmware fork](https://github.com/jusii/Z3660-amix)'s `CHANGELOG.md` entry of 2026-08-27
  (branch `release-1.0`) ✅ — quirk 39: the transport's appended `; echo DONE_$?` turning a bare trailing `&`
  into the Bourne syntax error `&;`, the parenthesise-the-launch fix, and the four
  superficially-similar shapes that are safe and must not be flagged (the linter's `--self-test`
  exercises all four plus the unsafe one).
- The **RAM-ceiling measurements** (first-party record, 2026-08-12/14)
  ✅ — quirk 41 (stock `autocon()`'s `end > 0x07000000` inference of the A3000 SCSI — read then as a RAM-size test, corrected 2026-09-29 to the kernel's load address, failing
  in both directions, with real A3000s above 16 MB inside the affected envelope) and the measurements'
  own method laws, quirks 42–45: the neighbour sweep that found the arena's derived constants but
  missed `segkmap` (sized from physmem); the mandatory disassembly-diff third gate, every patch site
  located by instruction context rather than by offset; the `elf2brel`-stripped `/stand/unix` that is
  useless as an `adb -k` namelist; and the spontaneous reboot under a heavy raw `dd` to the boot slice,
  whose only reliable record is the verify line the job wrote to disk. See
  [the RAM ceiling](ram-ceiling.md).
- The **accelerator acceptance campaign**, real A4000D + Z3660 with a socketed MC68LC060
  (first-party record, 2026-08-31 / 09-01) ✅ — quirk 49 (the 5/5 versus 0/3 reset-vector rates for a
  power cycle versus the firmware's warm reset, the `0xFFFFFFFF` vector read and the runaway-CPU
  register/vector scribble that follows it, and the overlay-cleared address-4-is-chip-RAM correction), quirk 50 (the
  sticky address-error mask reproduced against a zero-error dense pass, plus the destructive
  Autoconfig assign step, the multi-keypress test stop and the 4-hex-digit scan field), quirk 51 (the
  two capacitive-echo detections — an empty 4 MB motherboard window and a phantom 127 MB
  over a dummy-mapped range), and quirk 52 (the serial signature of a failed warm reset: no
  firmware start, no Kickstart load and no ROM reload). Board-level signal-path documentation and the
  campaign's tooling notes are deliberately not reproduced here.
- A **first-party record, 2026-08-14/15**, real A4000 + Z3660 ✅ —
  quirk 46 (`z3660_direct_map/D` printing `16777216` for a set one-byte flag, read live against the
  running kernel), quirk 47 (`sync; sync; /sbin/uadmin 2 0` reported by the host runner as "failed
  after 3 tries" on both halt cycles, with the `fsck`-silent verification boot as the only proof of
  cleanliness). Same session for
  [§44](#44-adb-namelist)'s exception: the on-box **native-linked** `/stand/unix` keeps its symbol
  table and is a valid `adb` namelist for itself.
- First-party **read-only metal session**, real A4000 + Z3660, 2026-08-27 ✅ — quirk 40: `dmesg` not
  present on the system; `wtmp`'s header dated *Mar 24 1992* with zero reboot records and `last reboot`
  returning nothing; `/sbin/bcheckrc` read verbatim (pre-check verdict discarded to `/dev/null`, repair
  pass to the console with no redirection); and the passive HDMI capture at a fresh `login:` prompt
  recovering the full boot transcript, used in the same session to answer a "did fsck run?" question.
  A delta to quirk 24, orthogonal to the syslogd state.
- The **68060's unimplemented-integer instruction class**, read against the **stock SVR4
  trap-dispatch table** on this platform ✅ — quirk 53: the CPU's own definition of the integer
  forms it declines to implement in silicon and traps out for software emulation (vector 61), versus
  a dispatch table whose populated range ends at vector 55, so the vector reaches only the default
  unhandled-vector path and the process dies as a bare `Killed` (rc 137) with no SIGILL, no SIGFPE
  and no core. Because the forms are integer ops, the outcome does not depend on whether an FPU is
  present ✅. The 32-bit `MULU.L`/`DIVU.L`/`DIVUL.L` spellings are hardware-implemented and
  unaffected ✅; `CMP2`/`CHK2`/`CAS2`/`MOVEP` are named as the same architectural class rather than
  each individually exercised 🟡. The matching porting note is on
  [040/060 status](68040-68060-status.md#what-a-soft-fpu-port-would-require); the unrelated GNU `as`
  2.8.1 mis-encode that produces a 64-bit divide form on a 68030 is on
  [the toolchain page](../drivers/toolchain.md). What the amigaux 1.0 kernels emulate (Motorola's
  68060 Integer Support Package: the 64-bit multiply and divide forms, `MOVEP`, `CMP2`/`CHK2`; only
  `CAS2` and a misaligned `CAS` still killed; earlier kernels only some multiply forms) is from the 1.0
  release notes ([amix-installng](https://github.com/jusii/amix-installng)
  `docs/release-notes-amigaux-1.0.md`, "The package engine: 1.12.3 replaces 1.12.0 on the 68060") and
  the amigaux.org known-issues page ✅.
- The **Z3660 real-68060 sessions**, real A4000 + Z3660 with a real
  68LC060 (first-party record, 2026-09-08/09) ✅ — quirks 54, 55 and 56. Quirk 54 read from the firmware source (the
  `amix_mode` → `cpu_ram = 0` forcing, and the `scsiboot && cpu_ram` gate whose else-arm prints
  `CPURAM disabled -> SCSI boot disabled`), with both preset shapes booting on the metal the same
  evening. Quirk 55 measured on the metal — the same Amix disk booting to multiuser under
  `UAE_040_MMU` on a KS 2.04 A3000 ROM and reset-looping on the real 68060 until the preset named an
  A4000 3.2.x ROM instead — with the "not a generation requirement" half established by scanning the
  `UNI\1` dostype constant across every ROM from 2.04 to 3.2.3, and the CRC-not-filename rule. Quirk 56's
  loader behaviour from the firmware's own `[SD Init]` lines across a deploy (`FAIL (Z3660.BIN) /
  FAIL (FAILSAFE.BIN) / Done (BOOT.BIN)` before, `Done (Z3660.BIN)` after), and its menu half from the firmware's key handling.
- The **A4000T `$DD0000` reading** behind §41's A4000T bullet (first-party record,
  2026-09-24, as cited on [the Z3660 SCSI driver page](../drivers/z3660-scsi-driver.md)): the
  shipped 060 kernel's unstripped `autocon()` disassembly plus the stock `support.c`/`sd.c`/`a3091.c`
  — the load-address phantom at `0xDD0000` sorting as card 0, the lazy first-I/O initialisation, the
  no-timeout busy-wait; on an A4000T that window is the onboard NCR 53C710. The hang itself is
  predicted from source, not reproduced on the metal 🟡. The chipset gate in the amigaux 1.0 68060
  kernels ✅: the [amix-installng](https://github.com/jusii/amix-installng) acceptance-rig configs
  (`configs/accept-z3660-060-fd0.uae`: with the probe in, the Z3660 is card 0) and
  [amix-a4091](https://github.com/jusii/amix-a4091) `docs/A4000T-ONBOARD-710.md` §2 (the A4000T
  kernel must carry the gate, enforced at media build); the public port's mainline leaves the guess
  alone per its [README](https://github.com/asokero/amix-040-060-port).
- The **2026-09-28/29 battery-clock work**, first-party, real A4000T and the installer bench ✅ —
  quirk 7's boot behaviour and its three details: the RP5C01 ticking and holding time across a
  power-off, the stock image coming up at 1977 with a working clock, the stock `setclk` run ending in
  `date: bad conversion`, the minute-granular `date` route, the `/etc/clkzone` convention, the
  battery-clock year encoding read back both ways, and the 1991 zone files' pre-1996 EU and pre-2007
  US rules (first-party record, 2026-09-28/29;
  `amix-installng/docs/installer.md`).
- The **2026-09-29 shutdown-stall discrimination**, first-party, eight runs on the IDE and A3000
  bench rigs ✅ — quirk 58 (first-party record, 2026-09-29;
  `amix-gayle-ide/README.md`, the stock-`init` note).
- The **Z3660 firmware fork's** `docs/AMIX.md`, "`isoN <file>` — CD-ROM images" and the beta-21
  resync defect list (item 4) ✅ — quirk 60, read from the firmware's config parser; the out-of-bounds
  `iso7`–`iso19` half is fixed on the fork.
- The **amix-gayle-ide review** (2026-09-28/29) and the three fixes it prompted — `amix-a4091`
  CHANGELOG 2026-09-29 (`support.c.patch`, low-nibble gate), `amix-z3660scsi` CHANGELOG 2026-09-28,
  and the ECS-NTSC bench row, VPOSR id `0x30` (first-party record, 2026-09-29) ✅ — quirk 61.
- The **2026-10-02 large-target bracket** ✅ — the installer's own author sequence on blank 600–1024 MB targets on a 68030 and a 68060 kernel, the stock `sddevsize()` default of 1 234 567 blocks found as the cause, the whole-disk raw-read hang bisected, and the fix (default `0x3FFFFF` + a `dd.c` offset check) re-run green at every size (first-party record, 2026-10-02).
- The **CD-unit overrun fix** ✅ — `amix-z3660scsi` CHANGELOG 2026-10-02 (commit `e072408`: refuse a READ/WRITE larger than `nbyte`; host harness 184/0) and its metal check on an A4000T the same day (raw `dd` at three block sizes → `I/O error`, counter +3; first-party record, 2026-10-02).
- The **FTP passive-mode truncation** ✅ — the 2026-10-02 bench matrix (passive from `cdfs` 18/80 short, passive from UFS 0/80, active 0/40, `226` on every truncated transfer; first-party record, 2026-10-02) and the earlier 68030 measurement plus the length-gate recipe in `amix-kerntools/tools/amixsync.py` ("the truncation trap"; this `ftpd` has no `SIZE`). The short-write mechanism is a diagnosis from behaviour 🟡.
- The **A4000/030's stock CPU card** — Commodore's 68EC030 card, identified on the bench (first-party record, 2026-10-01) ✅.
- The **signed manufacturer compare in stock `autocon()`** ✅ — `amix-a4091` commit `06a7d96` (2026-10-02, `support.c.patch`: the unsigned shift, codegen `swap`/`ext.l` → `clr.w`/`swap`), the matching one-byte `asr.l` → `lsr.l` patch in the 68040/68060 relink tooling the same day, and the A4000D metal run that proved it (the A4092's `0xC0DE0001` handed over in `bootinfo.autocon[]` but unregistered without the fix, registered as card 1 with it; first-party record, 2026-10-02).
- The **2026-10-02 local-I/O peek measurements**, first-party, on an A4000D with a Z3660 ✅ — a supervisor-mode, fault-catching peek tool under AmigaOS: the first read of `$DD0000` never returned; reads of Gary's `$DE0000`/`$DE0001` on the A4000D terminated (`FF`→`7F`, `7F`) (first-party record, 2026-10-02). The CPLD side is read from the Z3660's CPLD sources (`TERM.vhd`/`BUSTERM.vhd`: termination waits on `DSACK`/`AVEC`/`BERR`, `nTEA` only from the bus-error state, no timeout counter anywhere). The meaning of the A4000's `$DE0000`/`$DE0001` bits is unsourced 🔴.
- The **CPU-path resolution and the TOENB cell** (2026-10-02) — the Z3660 emulator sources (`Z3660_emu/src/cpu_emulator.cpp` `wait_read_ack()` timeout, `uae_emulator.cpp` `make_dummy_address_bank()`, `uae/memory.cpp` Gary non-range → `hardware_exception2` when `gary_toenb`), UAE's Gary register map (`amiberry/src/gayle.cpp`: `$DE0000`/`$DE0001`/`$DE0002` bit 7 = timeout/TOENB/coldboot), and a first-party A4000D test writing `0x80` to `$DE0001` (read back `0xFF`) before a `$DD0000` read that still hung ✅; whether the A4000 board logic can assert a bus error there at all awaits a scope look 🟡.
- The **Z3660 `kickstart 0` ordering and the `.d6` rule** (2026-10-03) ✅ — the FPGA source (`z3660.v`: `maprom_enable` latched only under `RESET_IN || GPIO_s[31]`, the MAPROM range served from DDR when set) and the firmware `main.c` order (MAPROM enabled at start-up, FPGA reset pulsed, CPU side started, the bit cleared for `kickstart 0` afterwards with no further reset), the same order in upstream shanshe/Z3660 `50e98e0` (v1.03 beta 21), and a first-party A4000D run with Kickstart 3.2.3 in the sockets (black screen, no SCSI I/O, 2/2), then the reordered firmware on the project's fork booting `kickstart 0` and SCSI-booting Amix with `kickstart 1` unchanged (same box, 2026-10-03), and on an A4000T booting DiagROM 2.0 from the sockets (2026-10-03); the fix shipping in the fork's firmware 1.0 (`C96EAD03`) per [jusii/Z3660-amix](https://github.com/jusii/Z3660-amix) branch `release-1.0` (`CHANGELOG.md` 2026-10-04, `release/MANIFEST-1.0.txt`) and the amigaux 1.0 release notes; the `.d6` patch and its CRC pairs from the project's patcher, with DiagROM's `$F800D6` reset PC as seen on the bench (first-party record, 2026-10-03).
- The **68040/68060 disk write stream** (2026-10-03) ✅ — measured on the project's emulator rig through a disk-write capture replayed exactly onto the image (every 2 KiB piece landing with its own tag; inode blocks flushed twice per `sync`, 69–75 ms apart in three captures (first-party record, 2026-10-03); a driver fault knob refusing one piece of an inode-block write, with the refused piece reaching no LBA and all four rewritten at their own LBAs on the next flush; a time-masked duplicate detector), and the request break-up read from the kernel binary (first-party record, 2026-10-03).
- The **stock `installf` crash on the 68060** (2026-10-03) 🟡 — an installer acceptance cell in an emulator run of the 68060 kernel: `installf -f core` → `User BUS ERROR at 4AFC0002`, a core in `/`, the entry left with `?` fields; `/usr/apkg/bin/installf -f core` on the same system → exit 0 and the kernel's true checksum; the installer's first-boot step switched to APKG's `installf`, run from `/tmp` (first-party record, 2026-10-03). The engine builds (1.12.3 shipped in 1.0; the July 2026 1.12.0 build killed by 64-bit divides on a 68060 kernel before 1.0) are from the amigaux 1.0 release notes ([amix-installng](https://github.com/jusii/amix-installng) `docs/release-notes-amigaux-1.0.md`, "The package engine: 1.12.3 replaces 1.12.0 on the 68060") ✅.
- The **A4091 driver's real-hardware scope** — the [amix-a4091](https://github.com/jusii/amix-a4091) README's status table: the A4092 on the 68060 line (A4000D + Z3660) with its root filesystem ✅, the A4091 board and the 68030 line still pending on real hardware 🟡 (quirk 3).
- The **`AF_UNIX` memory-pressure corruption and the Amiberry `MOVES` page-boundary defect** 🟡 — third-party reports from [hmlio/amix-x11-aga](https://github.com/hmlio/amix-x11-aga) (`docs/findings.md`; the reproducer `test/sockstress.c`), not reproduced here; the Amiberry fix is upstream commit [`845af02`](https://github.com/BlitterStudio/amiberry/commit/845af02) (quirks 72, 73).
