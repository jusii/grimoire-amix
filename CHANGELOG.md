# Changelog

Started 2026-09-26.

## 2026-11-05 — amix-installng is no longer public (a2cfef0)

Links to it are removed, and its documents are cited in plain text as not public. The media builder is to move into amigaux/amix under media/ before 1.1; its test bench stays private.

## 2026-11-04 — quirks 12 and 7: the sh EXIT trap; the stock setclk's year (077b1e8)

Quirk 12: the stock sh's EXIT trap replaces exit's status, and $? reads 0 inside it (measured on both kernel lines); use a cleanup function and trap only the signals. Quirk 7: the stock setclk -s overruns an 11-byte buffer and sets the battery clock to 2012 for 2026 (read from the source); the 1.1 installer's setclk is corrected.

## 2026-11-02 — Z3660 registers read as longs; FW_VERSION; zscsi INQUIRY fixed (3dd02b7)

Z3660: read the register block as longs (the firmware masks reads with 0x1FFFFC, and a word at +0 differs between the real and the emulated CPU); FW_VERSION (0x103) is a nonzero identity; the 144B:01 entry needs ext_kickstart 2. Z3660 SCSI: module 1.0.0-4 answers unmapped units as no device.

## 2026-11-02 — empty Zorro III reads per CPU path; /dev/scsi; probe facts (5c69b80)

Quirk 66: an empty Zorro III read, measured per CPU path (real 68LC060: Buster's bus error after ~285 ms, caught by bprobe at any level; the Z3660's emulated 030 0xFF and Amiberry 0x00, no fault), so fixed-address probes still need an identity check; a bprobe above VSECT1 faults in the MMU. Device list: the stock /dev/scsi interface and limits. Gayle IDE: the slave is off by default. Z3660 SCSI: INQUIRY answers unmapped units as disks. A4091: the first command's bus reset is slow under Amiberry. Z3660 ethernet: MAC_HI is a 32-bit register.

## 2026-11-02 — stock accounts, remote logins and the first-boot system.setup (15eb3ed)

First login: the stock 2.1 accounts ship without passwords, PASSREQ=NO, and inetd runs telnet and the r-services as root. The first boot runs Commodore's system.setup, whose "assign a password to all of the system accounts?" copies root's password to every system account but guest. The amixadm wording is corrected (it is a menu for later) in the install walkthrough, the cheat sheet and the kernel architecture page.

## 2026-11-02 — ddsize on the a3091 path; quirk 98, vfork and the signal table (4a1b551, c9ae68a)

Disks: /etc/ddsize hangs for good on the A3000 onboard SCSI (a3091) in emulation; the miniroot can't bound it, and the 1.1 installer avoids it; other controllers unmeasured. Quirk 98: a vfork child that calls signal/sigset/sigaction rewrites the parent's libc handler table and kills it with SIGBUS (xinit on a real A4000D); vsyslog's LOG_CONS fallback does the same to SIGALRM (🟡); toolchain: the static vfork is a true vfork; Imake's HasVFork must be NO on SVR4.

## 2026-11-02 — loadable modules: how each line maps the low 1 GiB (b4dfc83)

Loadable modules: the identity map below VSECT1 is a root-table early-termination descriptor on k30 and DTT0 on k46 (DTT1 also maps 0x80000000 up; only 0x40000000–0x7FFFFFFF needs page mapping).

## 2026-11-02 — Zorro III and the identity map, made precise (9ef6bc5)

Zorro III wording made precise across 13 pages: the space starts at 0x10000000 and its bottom (to 0x3FFFFFFF) is inside the identity map; AutoConfig places Z3 boards at 0x40000000 and above (VSECT1 on both kernel lines), outside it.

## 2026-11-02 — the A3000/A4000 physical address map (01792fa)

Hardware: the A3000/A4000 physical address map (secondary ranges at 🟡, first-party rows at ✅); Zorro III space begins at 0x10000000, inside the identity map, while AutoConfig'd Z3 boards land at 0x40000000 and above.

## 2026-11-02 — tar on four systems and heirtar; O_NDELAY connect and SVR4 ptys (e2eaf01)

Quirk 96: the stock tar crashes on a 68060 kernel with the TT fix too, while the 1.1 image's 68060 kernel extracts and gives every file to 0/0; it reads no GNU long names or pax headers; heirtar is the first workaround. Quirk 12: ${1:?word} ends at the first blank. Toolchain: %llo through libc writes 0; new SVR4 pty section. Networking: non-blocking connect under O_NDELAY vs O_NONBLOCK. Package management: under -n the stock pkgadd stops at a path another package owns, whatever the admin file says (🟡 for a shared directory with a different owner).

## 2026-11-01 — quirk 96 explained: the stock tar and a failed owner lookup (bb48556)

The stock /usr/sbin/tar (1992), restoring ownership from a ustar or GNU header, reads the uid and gid through a failed getpwnam/getgrnam result and dies with SIGSEGV after the first file whenever the owner or group name is missing on the box, including the empty names of GNU --numeric-owner (✅). Root's plain tar xf of foreign tarballs hits it (🟡). Workarounds: tar xof, a non-root user, /opt/amix/bin/tar, v7 archives (✅). The 68040/060 kernels before the TT fix don't fault on the NULL read (🟡).

## 2026-11-01 — the 040/060 user address space (8861759)

Port, fixed in emulation, not yet in a release: every 68040/060 kernel up to the fix loaded ITT0/DTT0 matching user accesses too, so user code could read, write and execute physical memory below 1 GiB (✅); now supervisor-only. The fix exposed a root page shared by the 040 tree and the legacy 030 section descriptors, which made user pages at 0–256 MiB walk chip RAM; legacy growth is now off for user spaces (✅). Quirk 97: 193 of 434 stock executables carry a read-only zero page, gcc14 binaries none (✅). modadmin -p resolves only exported symbols; the k46 load layout gives the rest (✅).

## 2026-11-01 — quirk 96: tar formats on the 68030 module-kernel test image (7e6ab05)

On an emulated 68030 module-kernel test image, tar xf of a GNU or ustar archive from host GNU tar dies with SIGSEGV; v7 headers extract (🟡). The 68040/060 test image takes all three (🟡). Cause not examined. Staging rule: a v7 archive of regular files, owner 0, group 3; the per-file passwd/owner messages are harmless (✅).

## 2026-11-01 — kernel memory at first use: HZ 60, the allocator at 32 MB, small KM_SLEEP (1069b1c)

On the 1.1 module kernels (emulated, 32 MB): HZ is 60 on both lines (✅, CIA-A clock). After multi-user the kernel
allocator holds about 2.36 MB on k46 and 1.57 MB on k30, and cdfs keeps 4–12 % of it (✅). A 4096-byte KM_SLEEP on an
empty allocator sleeps until memory is freed (✅) and once missed its wakeup (✅, mechanism 🔴). New processes wait
while the allocator is empty (🟡).

## 2026-11-01 — kernel probing on 1.1: adb reads live values through the namelist (d4f6bc5)

On a 1.1 module kernel, kbootset keeps /stand/unix as the booted generation's namelist at runtime addresses, so
`adb -k /stand/unix /dev/kmem` reads live `freemem`, `availrmem` and `physmem` (✅). `sar -r` and `crash` still
fail there, with the messages recorded (✅). Quirks 26, 44 and 80 updated; the stock-kernel adb re-checks stay 🟡.

## 2026-10-31 — Public text cleanup (1709d0c)

Sources name the amix directory or project behind a measurement; the licensing and publishing text states outcomes
without attribution; local tool files leave .gitignore. No fact or confidence tag changed.

## 2026-10-31 — aen DLPI: a short DL_UNITDATA_REQ fails with ERANGE (fe88b0b)

Raw DLPI on the stock A2065 `aen` driver: a `DL_UNITDATA_REQ` whose data part is under 60 bytes fails at the stream
head with `ERANGE`, because the driver's `module_info` minimum (`AEN_MIN`, 64 − CRC) counts the 14-byte header. Pad
ARP and other short frames to 60 bytes (✅). Added to networking, writing a STREAMS driver, and quirk 95.

## 2026-10-31 — stock userland: grep \|, pkgadd's ? minor, unlisted classes (ac4eeea)

`grep -v 'a\|b'` passes every line, so such a filter changes nothing (✅, commands cheatsheet). Stock `pkgadd` records a
device minor of 0 as `?` in `contents` while making the node at 0, unlike `core`'s own records (✅). An object of a
class that `CLASSES` doesn't list is skipped silently while `pkgadd` reports success (✅).

## 2026-10-31 — quirk 92 on the 040/060 line (edbd05a)

The 68040/68060 kernel has the stock 2.1c STREAMS code and the same five freeq call sites (✅, byte compare), and the
68030 guard, unchanged, is bound in its cut candidate. Seven guarded emulated runs were clean, but the freed queue never
occurred in them, so the save on 040/060 is untested (🔴), as is hardware.

## 2026-10-31 — quirk 93: the bench image's /stand/unix is the retail 2.1 kernel (dfe92d7)

The 2.1c bench image's /stand/unix (one inode with /stand/2.1_unix) is byte-identical to the retail 2.1 kernel in
amix-system kernels/2.1/unix, with no other kernel in /stand; the booted 2.1c link is larger and has no symbol table, so
namelist readers on that image get retail 2.1 symbols (✅, read offline from the image file). That this causes the
netstat failures stays 🟡.

## 2026-10-31 — stock sources linked in amigaux/amix-system (c2308b2)

Stock sources linked in the now-public amigaux/amix-system (pinned to 7cba961): aen, the bootstrap, the SCSI layer, the
console, the RAM disk, support.c and kernel.c, from the 10 pages that cite them. The bibliography, versions and
toolchain pages no longer call the repository planned or not created.

## 2026-10-31 — networking: raw DLPI on aen0 for a DHCP client; quirk 95 (4c3cf20)

Raw DLPI on aen0 for a DHCP client (Style 1, silent DL_ATTACH_REQ, reused slots open bound with stale frames, +14-byte
frames, ICMP port unreachable without a :68 socket, limited broadcast leaves directed), with the driver-side view on the
STREAMS driver page. New quirk 95. Emulation fidelity: Amiberry's A2065 rewrites the station address except inside DHCP
options (✅; same MAC on every board 🟡, no-board aen open 🔴).

## 2026-10-31 — quirk 93 follow-up; quirk 94: sh background jobs (52e2d56)

On the 2.1c bench image, naming /stand/unix changes nothing, netstat -s is wrong too, and /stand/unix is an unbound
ET_REL link to /stand/2.1_unix (✅); the cause is still 🟡. New quirk 94: four 2.1 /bin/sh facts for background jobs
(wait loses a finished child's status, >> writers collide, a waiting shell outlives SIGTERM, sh -c sets $0) (✅; the
O_APPEND mechanism 🟡).

## 2026-10-31 — package management: stock pkgadd refuses BASEDIR (89395ae)

The stock pkgadd refuses any package whose pkginfo has a BASEDIR line ("requires a base directory", exit 5), whatever
the admin file says; APKGENG's pkgadd installs both forms; rule: packages for stock-pkgadd boxes carry no BASEDIR
(✅, emulation).

## 2026-10-31 — quirk 92: prngd package test on three kernels (802b9b6, 3a8145b)

The prngd package's smoke test panics the 2.1c bench image before any load (heap pc, vector 0x4; consistent with quirk
92, not confirmed, since the booted kernel has no symbols). A 2.1c kernel with only the freeq guard and the project's
68030 test kernel pass the smoke test and three loads (🟡, emulation, one boot each).

## 2026-10-31 — quirk 92 root cause and 68030 fix; quirk 93 rescoped (b2c2e62)

A failed STREAMS open is undone by qdetach(q, 0), whose short path frees an already-enabled queue still on qhead;
queuerun then calls qi_srvp through freed memory (trigger: prngd exhausting a 10 MB swap reservation). Fixed on the
68030 line by a freeq guard (amix kernel/k30 f4aef26). Quirk 93: the bench image boots a 2.1c kernel with drivers
added that is not its /stand/unix, so the netstat failure is most likely quirk 80's namelist mismatch (🟡); kernel
measurements on that image now say "2.1c bench image" rather than "stock 2.1c".

## 2026-10-30 — quirk 93: netstat -rn fails on stock 2.1c (d713caf)

On the stock 2.1c image (emulated A3000) `netstat -rn` prints "read error on routehash" and exits 1, and
`netstat -in` prints only its header ✅; cause unknown 🔴. Set routes with `route` and keep your own record.
Networking gains "reading the routing table back"; quirk 26's observation is kept as another box's.

## 2026-10-30 — pkg* man pages exist in /usr/catman/1m (362d72e)

pkgadd(1M), pkgask(1M), pkgchk(1M) and pkgrm(1M) are installed, formatted only, in /usr/catman/1m; there is no page for
pkginfo, pkgmk, pkgtrans or pkgproto, and no contents(4). This corrects the "no pkg* man pages" claim, which had looked
only at the source tree.

## 2026-10-30 — how stock man(1) works; "pre-formatted only" corrected (8f77de1)

MANPATH is one directory, lookup goes through whatis, there is no -M, a man1/ layout is not found, and MANPATH without
CATPATH writes into, and shadows, the stock /usr/catman. The SVR4 base pages are formatted only, but the Amiga sections
ship as nroff source, which man formats on first view with /usr/ucb/nroff.

## 2026-10-30 — quirks 90 and 91 fixed on both kernel lines in emulation (90ef24a)

Quirk 91: fixed on the 040/060 line in emulation by the 68030 line's tail-zeroing routine bound into its ufs module
(port ISSUE-108); 68/68 runs clean, a control kernel stale on 56/68. Quirk 90: fixed on the 68030 line in emulation by
the kzero fault catch (amix kernel/k30 8b670ad); not in a released 68030 kernel yet. Hardware pending for both.

## 2026-10-30 — networking: AF_UNIX mode bits are not checked (683443d)

The AF_UNIX path is mode 000 under any umask (000/022/077 measured), and the mode bits are not checked, so a non-root
client connects anyway; chmod is what breaks the socket (ENOTSOCK), not the mode.

## 2026-10-30 — quirk 92 and the AF_UNIX chmod trap (a9aefc6)

Networking: a bound AF_UNIX path is a mode-000 FIFO, and chmod on it makes every connect() fail with ENOTSOCK; never
chmod it. Quirk 92: prngd 0.9.29 under prngd-ctl traffic panics stock 2.1c (Illegal Instruction, pc in kernel data,
backtrace ureturn → queuerun); a deferred put through a garbage qi_putp is the likely cause.

## 2026-10-30 — quirk 74: the gate saves the kernel, installs still need an FPU (2ae04e2)

The 68030 signal gate keeps the kernel up, but on an FPU-less 68030 stock mkfs -F ufs and the gcc14-built GNU cp and
gtar still die with SIGSYS (§31), so installs need a 68881/68882. The plan line now names a software FPU on the 68030
line (NetBSD's FPE).

## 2026-10-30 — quirk 31 on an FPU-less 68030 (8fe8cfe)

With the signal-gated 68030 kernel, an FPU-less 68030 also gets SIGSYS (exit 140) from stock mkfs -F ufs, so no new
ufs can be made, and from gcc14-built GNU cp and gtar; dd, cmp, sh, sleep and stock cp run. Emulation only; which FP
instruction each program reaches is untraced. The real-hardware FPU row notes the mkfs limit.

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

## 2026-10-11 — quirks 71 (0d766a2, b77b04a)

boot-process, quirks 71: fssm_Device's BSTR length counts the NUL.

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
