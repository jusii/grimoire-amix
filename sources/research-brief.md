# Amix — Master Research Brief (grounding source of truth)

> **Purpose.** This is the internal, citation-bearing knowledge base that grounds every page in
> `docs/`. Human and AI authors must treat *this file* (plus the cited primary sources) as the
> source of truth. **Do not state a fact in `docs/` that is not supported here or in a cited
> primary source.** When this brief marks something 🟡/🔴, the docs must carry the same tag.
>
> **Fact-confidence tags used throughout:**
> - ✅ **Verified** — from a primary source (Ditto paper, the real disk images, repo source, official manual) or reproduced locally.
> - 🟡 **Community-reported** — from amigaunix.com / forums / Usenet; credible but not primary-verified.
> - 🔴 **Unverified / disputed** — conflicting sources or no authoritative backing; flag explicitly.
>
> **Source-of-truth hierarchy:** primary manuals / Ditto paper / the real disk images & repo source
> **>** archived Usenet (comp.unix.amiga) **>** forum lore. Every `docs/` page ends with a `## Sources` list.

---

## 0. Primary artifacts we hold locally

| Artifact | Location (gitignored) | What it is |
|---|---|---|
| **Ditto driver paper** | `sources/pdf/Writing Amix Device Drivers …(2).pdf` | ✅ The authoritative driver spec by Michael Ditto (the Amix porter). 22 unique pages; **pp. 23–44 are a duplicate scan**. Page headers read **"1990 European Amiga Developer's Conference"** — cite it as such; the *filename's* "North American" is inaccolerate. |
| **boot floppy** | `sources/floppy/amix_21_boot.adf` | ✅ Bootable AmigaDOS bootblock + Amix secondary bootstrap + compressed install kernel. |
| **root floppy** | `sources/floppy/amix_21_root.adf` | ✅ UFS miniroot: installer ELF (m68k) binaries + install shell scripts. |
| **patch floppy** | `sources/floppy/amix_21_patch.adf` | ✅ Self-extracting "Patch Disks 1 & 2" for Amix SVR4 2.1. |

SHA-256 of all four: see `sources/CHECKSUMS.txt`. Inspect any ADF with `tools/inspect-adf.sh <image>`.

---

## 1. Identity, lineage, history

- ✅ Amix = Commodore's port of **AT&T UNIX System V Release 4 (SVR4)** to the Motorola **68030** Amiga. Kernel platform string: `m68k-cbm-sysv4`. Monolithic kernel; **no AmigaOS compatibility layer**; does **not** use the Amiga custom chips (Agnus/Denise/Paula) — treats the machine as a generic 68030 Unix workstation.
- Ported from AT&T's **3B2 (WE32x00) SVR4 codebase** (a licensing-cost choice), not a pre-existing 68k port 🟡 (community-reported — amigaunix.com hedges "it appears that"; corroborated by EAB/datagubbe, no primary citation; one OSnews commenter instead calls it a "SystemV 68K codebase" port). Port led by **Michael Ditto**, "Unix Systems Software Architect" at Commodore 1988–1991 ✅. Contemporaries call it "quick and dirty." (EAB thread on 3B2 codebase; datagubbe.se; Ditto paper opening line: "a direct port of the AT&T Unix System V operating system … essentially identical to … System V Release 4.")
- First public demo: Uniforum, Dallas, **1988** 🟡 (amigaunix.com: "1988 Uniforum Conference in Dallas"; the A2500UX *machine* and *January* month are community-reported, not primary). Commercial window ~**1991–1992**; support ended 1993; Commodore bankrupt Apr 1994 ✅.
- 🟡 Sun Microsystems twice explored OEM-selling the A3000UX as an entry workstation; deals fell through.

### Version matrix
| Version | Date | Notes | Tag |
|---|---|---|---|
| SVR3.x precursors | 1988–89 | A2500UX demos (68020→68030), proprietary windowing | 🟡 |
| 1.1 | 1991 | First widely-referenced SVR4 release; mono X "slow as molasses" | 🟡 |
| 2.0 / 2.01 / 2.03 | 1991 | Color X via A2410; archive.org has 2.01 & 2.03 installers | 🟡 |
| **2.1** | **Feb 1992** 🟡 | **Last retail release.** Pre-formatted man pages only (nroff sources dropped) | ✅ (installer exists; month 🟡) |
| 2.1 patch 2a → kernel **2.1c** | post-1992 | Unofficial but considered definitive; inet/NFS/Y2K fixes. **Our patch.adf is this.** | ✅ |
| "2.2" | — | **Does not exist** in any primary source; likely confusion with 2.1c | 🔴 |
| "2.1c, 1994" (gunkies) | — | 1994 date almost certainly wrong (support ended 1993) | 🔴 |

> Our `patch.adf` self-identifies as: *"Patch Disks 1 and 2 for International, USA-Only, 2-user, and Unlimited-User Amiga UNIX System V Release 4.0 Version 2.1."* ✅ It greps the live `uname -v` for `^2\.1.* 08004..$` before applying.

---

## 2. Hardware & requirements

### Official machines
- **A3000UX** ✅: 68030 @ 25 MHz + 68882 FPU @ 25 MHz; ships 1–2 MB Chip + up to 8 MB Fast; on-board SCSI; A3070 QIC-150 tape; A2065 Ethernet; optional **A2410** color graphics; **"Superkickstart 1.4"** bootstrap ROM (right-click at power-on → load AmigaOS Kickstart; default → boot Amix); 3-button mouse.
- **A2500UX** ✅: A2000 + A2630 (68030/25 + 68882) + A2090/A2091 SCSI; "UX" = shipped with Amix pre-installed. Hardware otherwise identical to a standard A2500.

### Minimums / hard limits
- ✅ **68020 or 68030 with a real MMU** + **68881/68882 FPU** (both mandatory; no soft-float; 68000 and MMU-less 68EC020/030 cannot run Amix).
- ✅ **4 MB Fast RAM min; 16 MB Fast RAM MAX** — kernel hard-codes the ceiling; **>16 MB mis-maps the SCSI drive**.
- **Tape must be ID 4** ✅ — hard-coded literal `/dev/rmt/4h` in the install scripts. **Disk is ID 6 by convention** 🟡 — the installer *prompts* for the disk target and templates `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` from `$SCSI` (only target 4 is reserved, for the tape), so Amix installs on other targets; but the chosen ID is baked into device names in `/etc/vfstab` + the boot partition, so it can't be changed post-install without editing those. (Verified against the installer's disk-selection loop + amigaunix.com — "preferably … ID 6" for the disk but "won't look anywhere else than SCSI4" for the tape; corrects an earlier "disk hard-coded in kernel" overclaim.)
- ✅ **No 68040/68060** (kernel predates 68040 MMU) → **A4000 cannot officially run Amix**.
- ✅ **No Zorro III** — memory-mapping layer can't address Zorro III space; that source was not shipped, so it can't be community-fixed. **Zorro II only.**

### Supported expansion (✅ unless noted)
- SCSI: A3000 on-board, A2090, A2091; GVP Series II 🟡 (needs kernel rebuild + RDB `dummy_handler`).
- Graphics: built-in (mono X) ; **A2410** "Lowell" (TMS34010, 1024×768) native; 🟡 Gateway! Vol.2 CD adds Picasso II/Piccolo/Domino/etc. (Zorro II / linear modes only).
- Network: **A2065** native; 🟡 Ariadne I via Gateway drivers; **Hydra** via the modern `hydra-amix` driver.
- Serial: **A2232** (7 extra RS-232 ports, `pmadm`).

---

## 3. Boot process & disk layout

- ✅ Power-on → Superkickstart ROM → boots from SCSI HD (or a boot floppy). Right-click → AmigaOS.
- ✅ Disk uses the Amiga **Rigid Disk Block (RDB)** scheme. Install default partition layout: `/` (root), swap, a **2 MB boot/bootstrap partition** (`BOOTSIZE=2` MB → `BOOTLEN = BOOTSIZE*2048` blocks, from root.adf ✅), and data. Keep partitions ≲1 GB 🟡.
- ✅ Filesystem choice at install: **s5** (System V; default but *not* recommended — likely a 3B2-lineage default) vs **UFS** (Berkeley FFS; recommended; root.adf scripts default `ANS="ufs"`).
- ✅ Kernel install flow (Ditto paper + modern repos): build kernel in `/usr/sys` via `make` → kernel image (paper calls it **`rdbunix`** in 1990; modern 2.1 systems/repos call it **`relocunix`** — note the historical rename), copy to `/stand`, then `make bootpart KERNEL=relocunix` writes the boot partition; reboot (`shutdown -i6`).
- ✅ Amiga **AUTOCONFIG** assigns Zorro II board addresses at reset; Amix reads these via the kernel `autocon()` interface (Zorro II only).

### What the real boot.adf contains ✅ — FULLY REVERSE-ENGINEERED (2026-06)
The boot.adf format was an open question in the first draft; it is now **solved**. Method and evidence:
`tools/inspect-adf.sh`, entropy mapping, LZW decompression, capstone M68K disassembly of the bootstrap,
and verified round-trip rebuild via `tools/extract-kernel.sh` + `tools/build-bootfloppy.sh`.

**Disk layout (901,120-byte / 880 KB image):** ✅
| Range | Contents |
|---|---|
| `0x000000–0x000400` | AmigaDOS **OFS bootblock**: `44 4f 53 00` (`DOS\0`) + valid checksum + start of 68k bootstrap. Bootblock checksum **verified to compute to 0** (valid). |
| `0x000400–0x002800` | Secondary **bootstrap** loader: a4-relative compiled C using exec/DOS libs (`OpenLibrary`, block `Read` of `$400`=512 B). Contains the **LZW decompressor** and the error strings. |
| `0x002800` | Start of the **kernel**, stored as a standard **Unix `compress` (`.Z`, LZW)** stream: magic `1f 9d`, flags byte `0x90` = block-mode + 16-bit maxbits. |
| `0x002800–≈0xa5c00` | The compressed kernel (~668 KB). Decompresses to a **1,171,200-byte m68k ELF** (`7f 45 4c 46`, ET=`0xff00` processor-specific, EM_68K, big-endian). |
| `≈0xa5c00–0x0dc000` | **Slack / free space** — fragments of the (same) kernel + ~30% zeros; **not used by boot** (9/12 sampled chunks appear verbatim in the decompressed kernel). |

- **Compression = standard Unix `compress`** (LZW, `-b 16`, block mode). ✅ Proven twice: (a) `gzip -d`/`zcat`/`uncompress` decode it to a clean ELF; (b) the bootstrap's decompressor disassembles to the canonical `compress` reader — the `rmask[] = 00 01 03 07 0f 1f 3f 7f ff` table at `$840(a2)` and the `1f`/`9d` magic check at ~0x1782. **Rebuild round-trips**: `compress -b16` of the extracted kernel decompresses back to the byte-identical kernel.
- **Boot descriptor `IBLK` @ `0x2600`** — a 512-byte `struct infoblock` (Commodore 1991) that precedes each file in the boot image: `ib_ident[8]`=`"IBLK\0"`, `ib_size`(`+0x8`)=**compressed size** (`0xa32a2`=668,322), `ib_fullsize`(`+0xc`)=**decompressed size** (`0x11df00`=1,171,200; `>0`⇒compressed), `ib_chksum`(`+0x10`)=**SVR4-`sum` checksum** (`0x156d`), `ib_bind`(`+0x14`)=text bind address (`0xFFFFFFFF`=auto). ✅ The bootstrap reads `ib_size` bytes from `0x2800` and checks decompression doesn't exceed `ib_fullsize` (else `"Kernel decompression overrun."`). **Confirmed against the now-public Commodore boot source** (`infoblock.h`, `boot1.c`/`boot2.c`); the `0x2600`→`0x2800` gap *is* the 512-byte infoblock.
- **Kernel checksum — fully pinned** ✅: `ib_chksum` (`IBLK+0x10`) = the **SVR4 `sum` algorithm** over the compressed `.Z` stream — sum every byte into a u32, then fold hi+lo into the low 16 bits **twice** (confirmed verbatim by the published `chksum.c`/`makeiblk.c` and by exact match: `0x156d`). Our disassembly showed the same two folds (`0x0bcc`), and `boot2.c` re-derives it and compares against `ib_chksum`. A mismatch is **non-fatal** (warns `"WARNING! …checksum mismatch."` and falls through), **but** a correctly-rebuilt floppy makes it match → no warning.
- **Rebuild trap:** keeping the donor's `IBLK` verbatim while swapping the kernel makes the bootstrap read the *old* `comp_len`; if the new stream is shorter, it decodes the zero-padding → **overrun**. Fix: patch `IBLK` (`comp_len`, `decomp_size`, `checksum`) to the new stream — `tools/build-bootfloppy.sh` does this (locating the genuine `IBLK` by checksum-consistency, since several byte-runs spell `IBLK` by accident).
- Other bootstrap strings: `"Load boot volume %d"`, `"Decompression failed!"`, `"WARNING! Kernel decompression overrun."`, `"Kernel may have been corrupted."`, plus an NFS/RPC client string table and `hat_vtokp_prot: user addr in kernel space` (these last live in the *decompressed* kernel, which is why they're readable once unpacked).

**Consequence:** building a custom bootable floppy with your own kernel is **tractable today** — splice `[donor bootblock+bootstrap | compress -b16 <your-kernel.elf> | zero-pad to 880 KB]`. The donor's first `0x2800` bytes are copied verbatim so the bootblock checksum stays valid; a differing kernel just yields the cosmetic checksum warning. Implemented by `tools/build-bootfloppy.sh` (host round-trip verified; **not yet booted on real Amix** 🟡). Full writeup: `docs/boot-disks/reverse-engineering-boot-adf.md`.

---

## 4. Kernel architecture

- ✅ Monolithic SVR4; **no loadable modules** — drivers are statically linked into the kernel.
- ✅ Kernel shipped as **compiled object libraries in `/usr/sys`**; the user relinks `/unix`. Some `.o` files come with source, others object-only. The config file **`kernel.c`** holds the switch tables and is provided in source. (Ditto paper, "Adding a device driver".)
- ✅ Uses full **68030 MMU** (HAT layer). RAM ceiling 16 MB (§2).
- ✅ SVR4-standard: **STREAMS** networking, **TLI** + BSD sockets, POSIX.1, `sysadm`/`amixadm`, `init`/`/etc/inittab`/run levels, virtual consoles **Alt+F1..F8**. Package tools `pkgadd`/`pkgmk`/`pkgtrans` (the `amixpkg` wrapper is widely reported 🟡 "broken"; root.adf nonetheless drives install via `amixpkg -i -m -d -r /mnt -y standard`).

---

## 5. Device-driver model (from the Ditto paper — the spec) ✅

**User-level view.** A device is a file in `/dev` with a **major** (which driver) and **minor** (which sub-device) number; the kernel knows only the numbers, not the name. Two classes: **block** (filesystem access) and **character** (general I/O). Example `ls -l /dev` from the paper: `/dev/console` = char major 0 minor 0; `/dev/dsk/c0d0s1` = **block major 18** (the SCSI hard-disk driver) minor 1 (= SCSI addr 0, LUN 0, partition 1); `/dev/par` = char major 21; `/dev/fd0` = block major 16.

**Kernel-level view — table-driven switch tables in `kernel.c`:**

```c
/* Character device switch (struct cdevsw, from conf.h) */
struct cdevsw {
    int (*d_open)(); int (*d_close)(); int (*d_read)(); int (*d_write)();
    int (*d_ioctl)(); int (*d_mmap)(); int (*d_segmap)(); int (*d_poll)();
    int (*d_xpoll)(); int (*d_xhalt)();
    struct tty *d_ttys; struct streamtab *d_str; int *d_flag;
};
/* Block device switch (struct bdevsw) */
struct bdevsw {
    int (*d_open)(); int (*d_close)(); int (*d_strategy)(); int (*d_print)();
    int (*d_size)(); int (*d_xpoll)(); int (*d_xhalt)(); int *d_flag;
};
```

- `cdevsw[]` / `bdevsw[]`: the actual switch tables, **indexed by major number**. Unused entry points → `nodev` (returns ENODEV); no tty → `notty`; no streams → `nostr`; flag → `nullflag`.
- `int2_tbl[]`: **level-2 autovector interrupt** handlers (e.g. `parintr, a2090intr, a2091intr, …`). A **level-6** table exists too.
- `init_tbl[]`: one-shot **boot-time init** functions (e.g. `parinit, coinit, …`).
- Naming convention: prefix every entry point with a short driver tag (`par` → `paropen`, `parclose`, …; `dd` → `ddopen`, `ddstrategy`, …).

**Block vs char semantics:** block driver's core is `strategy()` (queue I/O, returns immediately; completion via interrupt; DMA typical) + `print()`. Char driver core is `read()`/`write()` (+ optional `ioctl()`, `mmap()`, `poll()`). **STREAMS** drivers are a distinct third kind (a special char driver with a `streamtab` — used for networking; see hydra below).

**Adding a driver (paper's procedure):** ✅
1. Put the driver `.o` (and ideally source) in a subdir under `/usr/sys`; add it to that dir's makefile.
2. Edit `kernel.c` — add entries to `cdevsw[]`/`bdevsw[]` and/or `int2_tbl[]`/`init_tbl[]`.
3. `make` in `/usr/sys` → new kernel (`rdbunix`/`relocunix`).
4. Install (copy to `/unix` or write to a boot floppy/partition) and reboot. **Keep the old `/unix`** as fallback.
5. `mknod /dev/<name> c|b <major> <minor>` to create the node.

**Worked example in the paper:** `par.c` — the Amiga parallel-port char driver (output-only Centronics). Demonstrates `open/close/read/write/ioctl/poll` + interrupt routine + `timeout()`/`untimeout()` + `sleep()/wakeup()` + `pollwakeup()` + clist output queue + `splpar()` (=`spl2()`) interrupt masking + `uwritec()/getc()/putc()` + `copyin/copyout`. Plus the **`par(7A)` man page** (p.22): `/dev/par`, `O_WRONLY` only, `PIOCSETCTL`/`PIOCGETCTL` ioctls over `PC_SEL|PC_POUT|PC_BUSY` handshake lines. **This is the canonical teaching example for `docs/drivers/writing-a-char-driver.md`.**

**Key kernel APIs a driver uses:** `major()/minor()/getmajor()/getminor()`, `copyin()/copyout()`, `uiomove()`, `uwritec()`, `getc()/putc()` (clist), `sleep(chan,pri[|PCATCH])/wakeup(chan)`, `timeout()/untimeout()`, `spl2()/splx()`, `pollwakeup()`, and (Amix-specific) `autocon(product_id, dev, &board, &dummy)` for Zorro II board discovery 🟡(repo-confirmed).

**Driver references the paper cites:** AT&T SVR4 *DDI/DKI Reference Manual*; SVR4 *Streams Programmer's Guide*, *Network Programmer's Guide*; Egan & Teixeira *Writing a UNIX Device Driver* (Wiley, 1988); Bach *The Design of the UNIX Operating System* (1986); K&P *The UNIX Programming Environment* (1984).

---

## 6. Modern driver repos (case-study facts) ✅ (from repo READMEs/source)

All target **Amix 2.1p2a**, Amiga 3000 / 68030, Zorro II. All are recent "AI-assisted hobby" efforts.

### `asokero/va2000-amix` — char framebuffer driver for the MNT VA2000 RTG card
- Device `/dev/va2000`, **char major 68** minor 0. Modes 800×600 / 1024×768 / 1280×720 @ 16-bit.
- VA2000: AutoConfig **mfr 0x6D6E, product 0x01**, 4 MB Zorro II window (regs `0x000000–0x00FFFF`, framebuffer `0x010000–0x3FFFFF`).
- Build: native `cc va2000.c` (single file). Install script patches **6 kernel files**: `amiga/driver/Makefile` (+`va2000.o`), `amiga/console/{scrdev.c,c0.c,screen.c}` (RTG screen type), `master.d/kernel.c` (extern decls + `cdevsw[]` slot 68 + `va2000init` in `io_init[]`), then `mknod /dev/va2000 c 68 0`, `make install` → `relocunix`, `cp relocunix /stand && make bootpart KERNEL=relocunix`, reboot.
- APIs: `autocon()`, `uiomove()`, `copyin/copyout`; page frame `(base+off)>>11` (Piccolo convention).
- Gotchas (great for docs): Amix `/bin/sh` is **pre-POSIX** (no `$(...)`, no `grep -q`); `extern` decls must precede `io_init[]`; always `rm -f amiga/config/unix.o master.d/exp unix` before relinking.

### `asokero/xrtg-amix` — X11R5 server (`Xrtg`) for the VA2000 (needs va2000 driver first)
- TrueColor RGB565 640×480 → 1920×1080; hardware blitter fills/copies; software cursor.
- Build: X11R5 **imake** with custom `config/amix.cf` (`BuildPex=NO`; SVR4 lib rules avoiding ranlib issues). DDX layered: clients → Xrtg → AMIX DDX (`ddx/amix/`) → RTG layer → VA2000 (`ddx/amix/rtg/va2000/`) → `/dev/va2000`. Input via AMIX screen mgr (`OpenScreen()`, `SIOCACTIVATE`). New code MIT; X11R5 retains X Consortium terms.

### `asokero/lszorro-amix` — userspace Zorro II scanner (lspci-style)
- Native `cc lszorro.c -o lszorro`. Opens **`/dev/mem`** (root), `mmap()` 128-byte (`0x80`) windows; scans I/O slots `0xE90000–0xEFFFFF` and memory `0x200000–0x9FFFFF`. Decodes AutoConfig nibble format (two nibbles per logical byte, upper nibble D15–D12, most fields ones-complement). 461-entry ID DB from the Linux kernel Zorro list. Detects register-only boards (e.g. VA2000) by fingerprint. Can't see RAM/accelerator boards (no AutoConfig ROM).

### `isoriano1968/hydra-amix` — STREAMS/DLPI network driver for Hydra AmigaNet (NE2000/DP8390)
- Hydra rev 1.2a, Zorro II, AutoConfig **ID 2121/1 (0x08490001)** (manuf 0x0849 = Hydra Systems, product 1; verified against driver source `ne2000.h` `NE8390_BOARD_ID 0x08490001` and amiga.resource.cx — corrects an earlier 1053/0x041D transcription error); DP8390 regs at base+0xffe1 (odd byte lane), MAC PROM at base+0xffc0, 16 KB SRAM; 10Base2 + 10BaseT.
- Registers at **`cdevsw` slot 47** (`hya`). **Amix is SVR4.0 — no `ifconfig … plumb`**; the interface is linked in with `slink addaen /dev/hya0 hya0`, then `ifconfig hya0 <ip> … up -trailers` (node `mknod /dev/hya0 c 47 0`). Entry points: `hydraopen` (init + **three-method** card detect: `autocon()`/bootinfo with Zorro II address validation → direct Zorro II I/O-slot probe `0xE90000–0xEFFFFF` → memory-space probe `0x200000–0x9FFFFF`; bootinfo table can be corrupt on 2.1p2. An earlier **A2065-emulation fallback was removed**), `hydrawput` (DLPI `DL_INFO_REQ`/`DL_BIND_REQ`/`DL_UNITDATA_REQ`), `hydraintr` (INT2 RX/TX), `setup_ne2000`. Init split: a boot-time `init_tbl[]` entry `hydrainit` calls idempotent `hydraautoconfig()` to **probe** the board at boot; the heavy init (MAC read via `get_ethernet_address`, DP8390 program via `setup_ne2000`) is deferred to open (`hydraopen`→`hydra_initialize`). [Corrects the earlier "no init_tbl entry / lazy" note — verified against `master.d/kernel.c` `init_tbl[]` + `hydra.c` now in the repo.] Ships a `hya` user tool (`-S/-n/-c/-d`) backed by `HYDRA_NUMBER_OF_BOARDS`/`HYDRA_GET_CONFIG` ioctls. MAC PROM read step-2 (every-other-byte); Remote-DMA hang worked around via Hydra ASIC regs (`HYDRA_LOAD1/2`) + direct buffer-RAM writes.
- **Built natively on the Amix box — no cross-compiler**: `cd /usr/sys/amiga/driver/hydra && make` (Makefile `CFLAGS="-O -D_KERNEL -DSVR40 -DSVR4"`, links `exp` via `ld -r`), then `cd /usr/sys && make force` to relink the kernel (`elf2brel` in `boot/` converts to brel format). Native compiler **GCC 2.7.2.3** for Amix — an installable pkg on amigaunix.com (AT&T `cc` also works). Mirrors the existing A2065 LANCE driver (`aen/`). Source-only (needs a licensed Amix install). Ref: vjouppi/hydra (AmigaOS RE).

> 🟡 The earlier research note "asokero handle not found / isoriano1968 only does AmigaOS Mesa" is **wrong** — these four repos exist and are the project's centerpiece examples. Use the repo facts above.
> 🔴 A public, reproducible build recipe for the `m68k-amix-gcc` **cross**-compiler was **not found**; it appears to be a private build needing Amix SVR4 headers/libs. **But this is moot** — the modern drivers build **natively** on-box (Hydra: `make`/`make force`), so the cross-compiler is not on the critical path.

---

## 7. Toolchain & packaging

- ✅ Native compilers: **AT&T SVR4 `cc`** (used for kernel + simple drivers) and bundled **GCC**. Community built GCC up to **2.7.2.3** natively (2.03). Old `gcc 1.4.2` at `/usr/public/bin/gcc`; prefer newer via `CC`. GNU `make` 3.80, GAS, perl 5.005_4 available 🟡.
- 🔴 Symbolic debugger (sdb/dbx/adb) presence on Amix is **unconfirmed**.
- ✅ The modern drivers build **natively on the box** (Hydra: `make`/`make force` with native GCC 2.7.2.3, an amigaunix.com pkg; VA2000: `cc va2000.c`). A `m68k-amix-gcc` *cross* path is conceivable (triple `m68k-cbm-sysv4`; autodetect gives `m68k-unknown-sysv4`) but has no public recipe 🔴 and is not used by these repos.
- ✅ Packaging: SVR4 `pkgproto`/`pkgmk`/`pkgtrans`/`pkgadd` (gotcha 🟡: `pkgproto` omits symlinks). Michael Parson's **AmixBP** = 40+ re-bundled `.pkg`s on amigaunix.com/downloads. Alt install: `zoo`-compressed cpio.

---

## 8. Emulation (getting-started core) ✅/🟡

**WinUAE** (MMU emulation since 2.6.0, 2013) — the reference target. Mandatory config:
| Setting | Value | Why |
|---|---|---|
| CPU | 68030 | required |
| **MMU** | **ON** | Amix needs the MMU |
| **JIT** | **OFF** | JIT → kernel panics |
| FPU | 68882 | required |
| "More Compatible" | **OFF** | else boot freezes ("sort: fatal: line too long") 🟡 |
| Wait for Blitter | ON | 🟡 |
| ROM | A3000 KS 2.04 (rev 37.175) or 3.1 (40.68) | A3000 ROM |
| Chip RAM | 2 MB | |
| Fast RAM | ≤ 16 MB | kernel ceiling |
| DF0 | `amix_2.1_boot.adf` | |
| **SCSI ID 4** | tape image | install script hard-coded |
| **SCSI ID 6** | hardfile (RDB), ~450–900 MB | disk convention (installer prompts; not kernel-fixed) |

**FS-UAE** (amigaunix.com verified vs 3.1.66) snippet 🟡:
```
amiga_model = A3000
floppy_drive_0 = amix_2.1_boot.adf
hard_drive_0 = a3000ux.hdf
hard_drive_0_controller = scsi6
hard_drive_0_type = rdb
motherboard_ram = 16384
```
**Amiberry**: **8.x fully installs AND runs Amix** (✅ confirmed first-hand 2026-06 on Amiberry 8.1.6 — the GUI mounts an A3000 SCSI disk at ID 6 and a tape at ID 4, a full from-tape install completes, and an installed system boots to login). Issue #1376 (A3000 SCSI + tape support) is implemented in 8.x; *older* Amiberry builds only booted the floppy install kernel (to the `Insert floppy disk 2` prompt) but couldn't complete the install. **QEMU**: no working setup (no Amiga SCSI/hw). 🟡 default post-install login password "wasp".

---

## 9. Installation flow ✅ (reconstructed from root.adf scripts)

1. Boot `boot.adf` (DF0) → install kernel loads & decompresses.
2. Insert `root.adf` → **UFS miniroot** mounts; installer runs.
3. Installer detects a "suitable UNIX rdb", computes "obvious" partition choices or asks the user; sets `BOOTSIZE=2` (MB), swap (larger when disk > `BREAKPT=120` MB), FS default **`ufs`**.
4. Distribution streamed from **tape at SCSI ID 4**: `dd if=/dev/rmt/4hn bs=256k | cpio -imdcu` (and a `… | zcat | cpio` variant); driven by `amixpkg -b/-i -r /mnt`.
5. Kernel built/patched; `make bootpart KERNEL=relocunix` writes boot partition; reboot; finish via `amixadm` (nodename/domain/tz/date≤1999/root pw/X11).
6. Apply the **patch disk** (→ 2.1p2a / kernel 2.1c); run Y2K-fixed `setclk`.
- ✅ `viper_kludge` (Frank "Crash" Edwards) ships on root.adf: patches kernel memory so **non-standard tape drives** (Archive Viper 2150S) work; **incompatible** with A3070/Caliper/Wangtek/Sankyo — its own README warns not to. Tape-free installs (dd a cpio image to swap from Linux/AmigaDOS, extract with cpio) are documented on comp.unix.amiga 🟡.

---

## 10. Boot / root / patch disk anatomy ✅ (our primary analysis — the differentiator)

### boot.adf — FULLY REVERSE-ENGINEERED ✅
OFS bootblock (`DOS\0` + valid checksum + 68k bootstrap) → bootstrap LZW-decompresses a kernel. The kernel is a **standard Unix `compress` (`.Z`, LZW `-b16`) stream at offset `0x2800`** that unpacks to a **1,171,200-byte m68k ELF** kernel; the tail of the disk is unused slack. The "kernel file checksum" is the **SVR4 `sum`** (16-bit folded, twice) and a mismatch is **non-fatal (warning only)**. No AmigaDOS FS. Full layout table, compression proof, disassembly evidence, and the rebuild method are in §3 ("What the real boot.adf contains") and `docs/boot-disks/reverse-engineering-boot-adf.md`. Tools: `extract-kernel.sh`, `build-bootfloppy.sh`.

### root.adf
- First sectors zeroed (no AmigaDOS bootblock → `xdftool` "Invalid Boot Block @0"); the body is a **UFS filesystem** (`lost+found`, fsck strings).
- First embedded **m68k ELF** (`32-bit MSB, Motorola 68020, SYSV`) at offset **0x6800**, referencing `/usr/lib/libc.so.1`; many more ELF binaries follow (cpio, fsck, dd, amixpkg, …), interleaved `/bin/sh` scripts, and a POSIX **tar** member at 0x17180.
- Contains the partition/install logic (§9) and `viper.README`.

### patch.adf — self-extracting hybrid (fully decoded ✅)
- Offset 0: `#!/sbin/sh`, comment `# THIS FILE 1024 CHARACTERS MAX`. The 1 KB header script: starts `flopd`, `sleep 10  # REQUIRED!`, checks `uname -v` matches `^2\.1.* 08004..$` (else "USE AT YOUR OWN RISK"), requires `uid=0(root)`, then:
  ```sh
  QUIETDD=y dd if="$0" bs=1k iseek=1 2>/dev/null | (cd /; QUIETCPIO=y cpio -icdmuv)
  uncompress -f /var/patch/*.Z
  exec /var/patch/apply
  ```
- After byte 1024: a single **SVR4 ASCII cpio (`070701`) archive** with members:
  `var/patch/` , `apply.Z` (0x1893), `lha.Z` (0x6954), `replace.list.Z`, `preload`, `changes.Z`, `modify.list.Z`, **`archive.lha` (0xCC0CB — the actual patched-file payload, LHA-compressed)**, `delete.list.Z`, then `TRAILER!!!`.
- So the patch mechanism = bootstrap script → extract cpio → `apply` script uses bundled `lha` to unpack `archive.lha`, honoring `replace/modify/delete.list` + `changes`/`preload`. **This is the model for `docs/boot-disks/anatomy-patch-adf.md` and informs how custom add-on disks could be built.**

---

## 11. Networking, X11, userland (condensed)

- **Networking** ✅/🟡: SVR4 STREAMS TCP/IP; device `aen0` (A2065). Static IP only (no DHCP). **DNS off by default** (uses `/etc/hosts`); enable by `ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so` + `/etc/netconfig` + `in.named` + `/etc/resolv.conf`. `route add default <gw> 1` (metric required). NFS server+client. SLIP buggy (reboot between sessions). No PPP.
- **X11** ✅/🟡: default **X11R4**; upgrade to **X11R5** via Gateway! Vol.2. Mono = `tvtwm`; A2410 color via TIGA: `olinit -- -tiga [-tm 3]`. OpenLook `olwm`/`olwsm` (needs Xol fonts; R5 upgrade breaks font path → `xset fp+ …/Xol`). Quirks: y/z swapped, `/`=SHIFT-8; `xload` crashes; R4 leaks. (Modern alternative: the `xrtg`/`va2000` RTG path.)
- **Userland** ✅/🟡: default shell **ksh** (+ sh/csh/tcsh); **Amix `/bin/sh` is pre-POSIX** (see va2000 gotcha). Ships `cc`, GCC, make, troff/nroff (2.1 = pre-formatted man only). Games (nethack etc.). No audio, no IDE, no AmigaOS compat.

---

## 12. Quirks checklist (for `docs/how-it-works/quirks.md`) ✅/🟡

tape ID 4 hard-coded (disk ID 6 by convention); 16 MB RAM ceiling; no Zorro III; no 68040/A4000; Superkickstart dual-boot via mouse button; DNS off by default; **enabling DNS adds ~3 min boot** unless boot `ifconfig`s use literal IPs (§16, first-party 2026-06); **Y2K**: `setclk` `%02d` year bug + kernel date cap 1999 (community-patched); SLIP reboot bug; X y/z + `/` keymap; `amixpkg` flaky; clock drift via SCSI interaction; `/bin/sh` pre-POSIX.

---

## 13. Open questions / gaps / conflicts (carry as 🔴/🟡 in docs)
1. 🔴 `m68k-amix-gcc` cross-toolchain has no public build recipe (needs Amix headers/libs) — **moot**: drivers build natively on-box (Hydra README: native `make`/`make force`, GCC 2.7.2.3 pkg from amigaunix.com).
2. 🔴 "Amix 2.2" and "2.1c (1994)" — treat as nonexistent/erroneous.
3. 🟡 `rdbunix` (1990 paper) vs `relocunix` (2.1/repos) kernel-image name — historical rename; verify per-version.
4. 🔴 No archived Amix-specific *Programmer's Guide* / *Driver Reference* found (use generic SVR4 DDI/DKI + the Ditto paper).
5. 🟡 Default install FS is `s5` though everyone uses UFS — rationale (3B2 lineage) unconfirmed.
6. 🟡 A `master.d/kernel.c` (cdevsw/int2_tbl/init_tbl) is now published in the isoriano1968/hydra-amix repo, so the switch-table wiring can be read directly (whether pristine-original or a working copy is unconfirmed); previously thought unarchived. The whole `/usr/sys` tree + boot sources (`decompress.c`, `makeiblk.c`, `infoblock.h`, `chksum.c`, `elf2brel.c`) now appear there too — relevant to the boot.adf RE pages.
7. 🟡 X11R4-vs-R5 "default" claims conflict; amigaunix.com (most authoritative) says R4 default.
8. ✅ RDB partition type IDs decoded from the installer (`/etc/rdb -F`): boot `0x554e4900` (`UNI\0`), UNIX root `0x554e4901` (`UNI\1`), swap `0x72657376` (`resv`) — see `anatomy-root-adf.md`. *(Was 🔴 "not documented".)*
9. ✅ boot.adf kernel **checksum** — **fully pinned**: `ib_chksum` (`IBLK+0x10`) = the **SVR4 `sum`** (fold-twice) of the compressed `.Z` stream; sizes in `IBLK` (`ib_size`+0x8 comp, `ib_fullsize`+0xc decomp), plus `ib_bind`+0x14. Non-fatal anyway. `build-bootfloppy.sh` patches the size/checksum fields so a rebuild matches (no warning). **Confirmed against the published Commodore `infoblock.h`/`chksum.c`/`boot2.c`.** *(Was 🔴 "compression+checksum entirely unknown".)*
10. ✅ `tools/build-bootfloppy.sh` — a same-kernel rebuild (re-`compress`'d, `IBLK` patched) **boots in Amiberry** to the original's `Insert floppy disk 2 (root file system)` prompt (no overrun, no warning). 🟡 Next: a *driver-modified* relinked kernel, and the full tape install. (A first attempt that left `IBLK` stale failed with "decompression overrun"; patching `IBLK` fixed it.)

---

## 14. Bibliography (seed for `docs/reference/bibliography.md`)

**Primary:** Ditto, *Writing Amix Device Drivers*, 1990 European Amiga DevCon (our PDF) · the three install ADFs (our analysis) · the four repos: github.com/asokero/{va2000-amix,xrtg-amix,lszorro-amix}, github.com/isoriano1968/hydra-amix · AT&T SVR4 *DDI/DKI Reference Manual* · Commodore manuals on archive.org: *Installing/Using/Learning Amiga UNIX* (1990) · amigaunix.com *V2.1 Addendum* PDF.
**Community/reference:** amigaunix.com DokuWiki pages — home, history, requirements, installation, networking, x11, more_software, tips-tricks, patch-disk, y2k-dst, a2232, tape-creation, dual-boot, file-transfers, boxed, downloads, vi-editor · en.wikipedia.org/wiki/Amiga_Unix · /wiki/Amiga_3000UX · HandWiki Software:Amiga_Unix · osnews.com (Feb 2026) · datagubbe.se/amix · virtuallyfun.com/2013/01/13/amix · ode2commies.blogspot.com (2024) · archive.org/details/commodore-amiga-operating-systems-amix · EAB threads · comp.unix.amiga (Google Groups / narkive) · BlitterStudio/amiberry issue #1376 · WinUAE/FS-UAE docs.
**llms.txt convention:** llms.txt (Jeremy Howard, Answer.AI, Sept 2024).

---

## 15. A4091 / Zorro III SCSI — first-party (A4091-on-Amix project, 2026-06)

Native NCR/Symbios **53C710** block driver for the Commodore **A4091** (Zorro III SCSI-2); Amix boots with root/swap/fs entirely on an A4091. ✅ emulation-proven (Amiberry: A3000/ECS + A4000/AGA, one universal kernel); 🟡 real-hardware pending. Source: the A4091-on-Amix project repo — `NOTES.md` §1–§20, `src/a4091-wr.c`, `src/kernel-patches/{sd.c,support.c}`, `tools/` — plus github.com/A4091/a4091-software (ROM + `ncr53cxxx` SCRIPTS assembler). Full page: `docs/drivers/a4091-53c710-driver.md`.

- ✅ A4091 AutoConfigs at product id **0x02020054**, base **0x40000000**, 16 MB window.
- 🔴 "Zorro III is unaddressable" is imprecise — `autocon()` *does* return Zorro III bases. The real wall is the 68030 **Transparent-Translation gap**: TT0 maps 0x00000000–0x3FFFFFFF, TT1 0x80000000–0xFFFFFFFF, leaving **0x40000000–0x7FFFFFFF unmapped** (where the A4091 sits). Fix: **`sptalloc()`** page-maps the board + 53C710 regs into kernel VA. DMA unaffected (53C710 bus-masters to RAM at 0x07800000+, inside TT0).
- ✅ Integration: `sd.c` `scsicard[]` maps product id → queue fn; added `0x02020054,&a4091queue,"A4091 SCSI"`. Cards inserted in ascending base-address order → A3000 SCSI (0xDD0000)=card 0, A4091 (0x40000000)=card 1. Driver `a4091-wr.c` drives any CDB via a table-indirect 53C710 **SCRIPTS** program + DSA; one program does READ(10)+WRITE(10) via live-phase dispatch; DMA straight into the caller's buffer. Completion = single ISTAT read ✅ (emulation, synchronous target) / 🟡 real disk needs bounded poll or interrupt.
- 🔴 The mountroot panic (`s5mountroot VOP_OPEN error 5`) booting A4091-only was a **device-DISPATCH** bug, not the driver: the **phantom A3000** (autocon hardcoded a WD33C93 at 0xDD0000 when RAM>7 MB regardless of presence) took card 0, pushing the A4091 to card 1, while compiled-in rootdev=c6d0s1 → card 0 → root read went to non-existent hardware → EIO. ✅ Fix: replace the RAM heuristic with a **chipset gate + WD33C93 probe** — read VPOSR (0xDFF004): ECS Agnus id <0x22 / AGA Alice ≥0x22; on ECS, write/readback-probe the WD33C93 (SASR 0xDD0041 / SCMD 0xDD0043), register only if echoed; on AGA, skip (never touch 0xDD0000). One universal kernel then boots A3000(ECS) AND A4000(AGA). 🟡 Amiberry open-bus false-positives the readback (harmless for real targets).
- ✅ SCSI numbering (`sd.h`): block major **18** / char **40** / gsioctl `/dev/scsi` char **11**; minor = (slice<<4)|(card<<3)|target; **cN = card*8 + target** (computed). e.g. c6d0s1=card0/t6/s1=makedevice(18,22); c8d0s0=card1/t0/s0=makedevice(18,8). rootdev compiled via `/stand/CONFIG`. Install a kernel to a *different* disk's boot partition by hand (`( cat boot1.boot; ./makeiblk boot2.boot; cat boot2.boot; ./makeiblk unix; cat unix ) | dd of=/dev/dsk/c8d0s3`) — never plain `make install` (writes the booted disk).
- 🔴/✅ **AGA finding:** "Amix won't boot on AGA (white screen)" was NOT an Amix limit — it was **Kickstart 2.04 (A3000) ROM has no AGA support**. With **KS 3.0 (A4000)** Amix boots on AGA incl. console; KS 3.0 also runs on A3000. (Distinct from the 68040/A4000 limit — a real A4000's 68040 still can't run Amix; proven on an 030+AGA emulation profile.)
- ✅ **D245 boot-breaker** (kernel-build): `D245 4C41` = `"RELA"|AT_DeadEnd` from the boot relocator (`amiga/boot/rel.c`) on a corrupt image; cause = intermittent (~70%) **ld write corruption** (one ~8 KB block shifted 8 bytes), code-independent. Fix: relink until `sum` recurs (clean `ld` output is byte-deterministic) — `tools/build-clean-kernel.sh`; detectors `tools/checkunix.c` (symtab) + `tools/relsim.py` (full offline oracle). Corollary: `make` doesn't reliably recompile a changed `.c` — rm the stale `.o` + subsystem `exp` + `amiga/exp` first; `/tmp` wiped on reboot; SVR4 `grep` has no `\|`.

## 16. Networking: enabling DNS makes boot ~3 min slower — first-party (2026-06-07) ✅

Enabling DNS (the documented `libsockdns` swap) stalls Amix **~3 min** at "The system is coming up. Please wait." every boot. Cause: boot-time `ifconfig`s take hostnames (`S69inet` `lo0 localhost`; `network-config` `aen0 \`uname -n\``) → `gethostbyname()` runs *before* the default route (`rc.inet`) is up → full resolver retransmit ~90 s each (~180 s). Independent of the `/etc/domain` bug. Fix (210 s → 29 s): literal IPs — `ifconfig lo0 127.0.0.1`; `ifconfig aen0 <static-ip>`. Edit gotchas: `/etc/rc2.d/S69inet` is a hardlink (= `/etc/init.d/inetinit`) — edit in place; never leave `S*` backups in `/etc/rc2.d/` (the `for f in /etc/rc2.d/S*` glob runs them). Folded into `networking.md` / `networking-on-the-lan.md` / `quirks.md`.
