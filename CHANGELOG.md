# Changelog

Started 2026-09-26; entries are written after the owner's review.

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
