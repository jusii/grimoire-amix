# Changelog

Started 2026-09-26; entries are written after the owner's review.

## 2026-10-30 — quirk 74 fixed on the 68030 line in emulation (dfa7b22)

k30 2a3e894 gates sendsig's fpu_setup call with fpu_setup_gated, so an FPU-less 68030 boots and survives signals; a
real FPU-less 68030 is still pending. The Amiberry page notes that cpu_type=68020 overrides cpu_model and leaves no MMU,
so Amix reset-loops after "starting the kernel".

## 2026-10-30 — quirk 91: cold-cache extent, cause narrowed, fixed on k30 in emulation (a2316de)

With the file cached, [roundup(M, PAGESIZE), block end) reads old; without, all of [M, block end). pvn_vptrunc zeroes
nothing when the file isn't cached; the async write loses to the abort, by elimination. Fixed on the 68030 line in
emulation (synchronous tail zeroing, kernel/k30 1be27f8); the 040/060 line pending. Workaround corrected: only an
8 KiB-aligned cut, or writing zeros from M, is safe.

## 2026-10-30 — quirk 90: the kzero fix passes on a real 68060 (7e27e2b)

The 040/060 kzero fix passes on a real 68060 (A4000T + Z3660, 128 MB): nine shrink cases intact, three caught faults,
none foreign. The 040/060 panic itself is measured only in emulation (no unfixed metal control).

## 2026-10-30 — quirk 91: the old bytes survive a reboot on the 040/060 line (bcbfff5)

On the 040/060 line the stale bytes survive a sync, clean shutdown and fresh start: the same 4096 bytes as a same-boot
control.

## 2026-10-30 — quirk 91: the dropped write is open (b6ca40d)

Why the async put leaves no zeros on disk is open: ufs_putpage's locked-inode return is only the pid 0/2 pageout guard
and is ruled out. Two untested candidates: the segmap-zeroed pages are not seen as modified, or the abort races the
write.

## 2026-10-30 — quirk 91: stock 2.1c measured, old bytes on disk, the cause (d5fb469)

Quirk 91 holds on stock 2.1c and both kernel lines, and the old bytes come from disk (they survive a remount). Cause,
read from the stock objects: pvn_vptrunc zeroes the block in the page cache, issues an async put, then aborts every page
at or past M; an 8 KiB-page design on Amix's 2/4 KiB pages. Workaround: write real zeros through the gap, or cut
block-aligned.

## 2026-10-30 — quirk 91 on both kernel lines; the extent rule (c664b12)

An F_FREESP shrink to an unaligned M in an earlier 8 KiB block past the direct blocks, followed by a sparse regrow,
reads old bytes in [roundup(M, PAGESIZE), roundup(M, 8192)) on both lines, so the 4 KiB-page line needs M in the block's
lower half. A block-aligned M is clean, so the quirk-90 aligned cut covers it. Mechanism inferred, not read.

## 2026-10-30 — quirk 91: shrink then regrow reads old bytes (3ca4438, 2c76ccb)

On the 68030 kernel line, an F_FREESP shrink to an earlier 8 KiB block past the direct blocks, followed by a sparse
regrow, reads the file's old bytes from roundup(M, 2048) to the end of M's block (no crash). Stock 2.1c, 040/060 and the
cause are untested. Workaround: regrow by writing zeros. Quirk 90's 030 survivor rows point to it.

## 2026-10-30 — stock libm: sqrt and FPCR (c10fd4a)

A direct sqrt() in GCC 14 code is an inline fsqrt (correctly rounded, hardware on the 040/060); libm's own sqrt,
reached through a pointer, is within 1 ulp but not correctly rounded. FPCR is 0 at process start, and fpsetmask(0)
touches only the enable byte.

## 2026-10-30 — quirk 90 fixed on the 040/060 line (4caab45)

The 040/060 port fixes the ftruncate shrink panic with a fault-catching kzero (port ISSUE-107, b65b43d). Verified in
emulation; hardware pending; the 68030 line not yet fixed. The aligned-cut workaround stays the advice until both
lines carry the fix.

## 2026-10-30 — the stock root floppy's miniroot is s5 (148aadb)

Corrected from UFS to s5 in the research brief, install walkthrough, glossary, bibliography and WinUAE page, and the
brief's FS-default line (the stock prompt defaults to s5; ufs must be typed). Restates the 2026-07-05 measurement.

## 2026-10-30 — package repository: the licence gate records stock libm, refuses ROMs (74012af)

The payload-licence gate now records embedded stock SVR4 libm instead of refusing it, and refuses Kickstart ROM images
by content (magic word + JMP, byte-swapped, AMIROMTYPE1; split halves not seen). The stripped-binary limit is restated.

## 2026-10-30 — stock libm.a; LC060 status corrected (b239450)

Toolchain: the stock libm.a is archive-only software math (40 members, 21 fmovecr and 16 fintrz sites, a per-function
table of what traps on the 040/060), bit-identical through the 040 FPSP, within 1 ulp, SVID errors (EDOM, matherr
line, -HUGE/0). musl 1.2.5 math is wrong under extended precision (🟡). 040/060 status: the LC060 software FPU is merged
but not accepted, so FPU-less parts have no usable floating point yet.

## 2026-10-30 — quirk 90 exposure measured; %lld in run-time formats (9b024ff)

On stock 2.1c, dd seek= without conv=notrunc, cp --sparse=always ending in a hole and tar -b 1 --delete all panic;
tar's default -b 20 is safe. Porting rule: ftruncate is weak in the static libc, so link a strong aligned-cut
replacement. Toolchain: %lld also hides in formats built at run time from PRIdMAX (coreutils stat, od).

## 2026-10-30 — quirk 90 covers both kernel lines (a3ef7c7, 96df1ae)

The ftruncate shrink panic hits the 040/060 line too: past the 12 direct blocks, an unaligned EOF in the old last block
panics when that block ends past the old EOF's page (roundup(N, PAGESIZE) < roundup(N, 8192)), so the cases differ
between 2 KiB and 4 KiB pages. Amix's kzero has no fault catch; the aligned-cut workaround is proven on both lines.
Source lines cite the rsync port commit e7ac916.

## 2026-10-30 — quirk 90 and networking/porting notes (8d6f76f, 552227f)

Quirk 90: stock 2.1c panics when ftruncate shrinks a file past its direct blocks to an unaligned EOF in the old last
block (rows, path to bzero, aligned-cut workaround). Networking: the hosts-only gethostbyname() rejects dotted quads
(measured). Porting notes: ftruncate, IPv4 literals, /usr/bin/rsh is BSD rsh, nobody 60001 with no nogroup.
llms-full regenerated.

## 2026-10-29 — quirks 88–89 and porting notes (e4b4f07, 8e9ed98)

Quirk 88: stock sed drops a final line with no newline. Quirk 89: libc.so.1's TZ parser writes into the TZ string in place,
so putenv() of a string literal crashes the next time conversion. toolchain.md: a porting section (absent functions,
exported-but-undeclared ones, static-only members, -include in CFLAGS breaks autoconf probes).

## 2026-10-29 — RAM per CPU line (c407def, 12db4bf)

The ≈128 MB describable-RAM limit is a property of the 4 KiB-page 040/060 kernel line, not of the 68060: the 68040 and
68060 MMUs have no 2 KiB page. Measured at 128 MB on a 68060 ✅, not yet on a 68040 🟡; the stock 68030 kernel with
2 KiB pages ≈64 MB. ram-ceiling, hardware, quirks, 68040-68060-status, install-walkthrough, research brief, llms.txt.

## 2026-10-29 — repositories and grounding (3de1f8a, c624138)

bibliography.md: the amigaux project's repositories (amigaux/amix, the port fork and pin, amix-system planned, the
toolchain forks, Z3660-amix, the collaborators' repos). versions.md: amigaux release numbers are not Commodore's; the
k30/k46 line names. 68040-68060-status.md: the org fork and pin. kernel-composition.md: a 1.1 module note.
research-brief.md §22 indexes every fact of the 2026-10-29 currency sweep with its page, tag and source.

## 2026-10-29 — hardware (f57108e, 16422ed)

a4091-53c710-driver.md: the Zynq side of Z3 DMA (ACP coherence, arbiter priority), A4092 CPLD 1.4.21 gates the bus grant
on CTEST8.SM, 53C710 behaviours and rates, the A4000T onboard 53C710 (root 3/3 on the 1.1 k46 module kernel), no
bus-master DMA with the Z3660 in 68030 mode. hardware.md: A4092, A4000T onboard and Gayle IDE rows and a Gayle IDE
subsection. z3660-scsi-driver.md: the address-capture race (platform behaviour, tripwire, arm-every-write rule).
z3660-ethernet-driver.md: INT6 receive in the 1.1 module form. Quirk 87. z3660-timings.md: scoped clock claim, campaign 1.

## 2026-10-29 — boot, quirks 76–86, the gcc14 runtime correction (69641df, f669feb)

boot-process.md: what the Kickstart strap checks, the AN_BootError reset loop, loader-writer notes, CD boot through an
A4091/A4092 ROM. Quirks 76–86: stock diff without -u, syslogd needs m4, putbuf, bcheckrc reboots after a root repair,
/stand/unix namelist users, sh read buffer across exec, 4 KiB pages vs small-block filesystems, the running CIA-A timer,
/dev/audio open without timeout, OCS/ECS-only console, swap not optional. Quirk 63: ATAPI dd bs=2048. toolchain.md:
upstream gcc14 at 58130fe builds a 68060-only runtime (not 68881-safe); the m68020-60 runtime is the project's build.

## 2026-10-29 — toolchains and system files (0f1fbfd, 41f0bb6)

toolchain.md: a gcc14-cross-amix section (userland only; m68k-elf; AMIX's return convention; -malign-int as ABI; specs
and link line; the m68020-60 runtime; -mno-strict-align; check-68060-safe.py; known defects), which compiler for which
code, the sysroot's patch level, vfork/sigaltstack/help2man/sdiff -o, gcc-cross-amix #7 merged 2026-10-19.
anatomy-patch-adf.md: the patch disk holds no kernel; the four files outside /usr/sys patch 2a changes. versions.md: 2.1c
has no vendor kernel bytes; sha256 of the retail 2.1 and 2.1c stand/unix. commands-cheatsheet.md: stock diff has no -u,
/usr/public/bin/patch applies unified diffs.

## 2026-10-29 — loadable modules page (3e2a9eb, 456e254)

New page drivers/loadable-modules.md from amigaux/amix kernel/dlm and kernel/modules @ 95bf2f3: status (emulator on both
lines, metal on the 060 line, nothing released), the parts, the k30/k46 lines and the kabi rule, root/boot/demand classes,
the static floor and safe mode, a short module guide and kernel facts for driver authors. Major registry: c 52 monsw,
53 kinfo, 54 paula, b 20 ramdisk; free 55–67/69. kernel-architecture: the DLM core is MIT from 2026-10-14. ram-ceiling:
the k30 bind cap at 64 MiB; no kernel binds at or above 0x40000000. mkdocs build --strict clean; llms-full 58 pages.

## 2026-10-26 — stale /etc/syslog.pid; Z3660 ethernet page and quirk 75 (502f80b, 4d1dc1b)

Stale /etc/syslog.pid (4d1dc1b): the stock syslogd start script trusts kill -0 on the previous boot's pid, which nothing
clears at boot, so a small addition to the early boot can leave an enabled syslogd unstarted on every boot; remedy =
removing the pid file before S70 (🟡). Z3660 ethernet (502f80b): new how-it-works page (the card's receive path, the MAC-write
ring offset, the five z3660cfg.txt keys, GEM counters, Amix vs AmigaOS numbers), the zen0 page's 60 Hz service model;
quirks 75: stock TCP's 4 KB lower read queue drops bursts uncounted in ipintr, 2.1c fix at file 0xe6ba4 0x1000 → 0x4000
(push 24.6 → 334 KB/s).

## 2026-10-14 — quirk 74: the stock 68030 kernel without an FPU panics at the first signal (7b4ca6f, 579ac44)

Boots past `no fpu detected`, then `sendsig`'s ungated FRESTORE (text 0x12A) faults in pid 1; seen on a real A1200 030
card and in Amiberry (`fpu_model=0`). Triage rule and pointers from the hardware pages; FPU-less 030 support marked
planned.

## 2026-10-14 — consistency audit against the amigaux 1.0 facts (daa69f2..59e03ee)

127 fixes from the audit of every confidence-tagged claim: public citations for the newly published repos; stale and
wrong driver/platform facts (z3660 bounce, spl6/splx, autocon() signature, VPOSR order, X on AGA, the s5 root floppy);
one canonical stock-only loadable-module caveat; quirks 72 (AF_UNIX under memory pressure) and 73 (Amiberry MOVES
before 845af02); amix-x11-aga and manx in the bibliography; llms-full regenerated.

## 2026-10-11 — quirks 71; station notes local-only (0d766a2, b77b04a)

boot-process, quirks 71: fssm_Device's BSTR length counts the NUL. The station notes file is untracked and ignored
with .claude/ (owner rule 2026-10-10).

## 2026-10-05 — 040/060, Z3660, A4092, quirks 58-70, the content review

One entry for the work of 2026-09-14 to 2026-10-04.

- Licensing wording follows the 2026-09-23 outcome (Amiga Corporation's approval; the release restriction is
  lifted); README carries the amigaux.org trademark disclaimer. Media are still never committed here.
- Package repository: pkg.amigaux.org is canonical; the two publish gates, names.conf, the regenerate trap.
- 68040/68060 status rewritten for the public port asokero/amix-040-060-port: what it is, how it builds, what
  works, 060-direct versus the Z3660 software-030 route, 128 MB on metal. "No 68040/68060, no A4000" is
  qualified as a stock-kernel limit. Amix 2.1c boots to login on a real 68LC060.
- RAM: the envelope is 16-64 MB on the stock 030 line and 128 MB on the 040/060 kernels; no page states a 16 MB
  ceiling. Zorro III lies outside the stock identity map; a driver that maps its board with sptalloc() reaches it.
- Toolchain: the stock on-box compiler is GNU GCC 1.40.5; the GCC 2.7.2.3 package claim is withdrawn.
- Quirks 58-61: the telnet run-level stall in stock init, stock Z3660 firmware and the warm reset, the Z3660
  isoN slot = SCSI target rule, the VPOSR AGA test. Battery clock: stock sysinit runs setclk and date rejects
  its year; Y2K is a setclk bug.
- Quirks 66-70: undecoded local-I/O reads under the Z3660, kickstart 0 on the Z3660 real 060, the .d6
  reset-vector rule, the 040/060 kernel's disk write stream, stock installf on a 68060 kernel (use APKG).
- A4092: the autocon signed-shift bug, Zorro III DMA into Z3660 RAM, 68LC060. Boot process: boot priority picks
  the loader, rootdev picks the root. Kernel build: verify /stand/unix after an install.
- X11/RTG: the Z3660 hard-mapped RTG window; the Z3660 RTG target shares zz9000's major 49 by design.
- Content review: Amix and platform facts only; example addresses per RFC 5737; one Sources convention;
  broken anchors fixed; llms-full regenerated.
