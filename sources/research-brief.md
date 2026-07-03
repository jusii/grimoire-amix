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
- **✅ Real-hardware milestone (2026-06, commit `3147725`):** verified on a real Hydra card under Amix — ARP resolves, ICMP `ping` works to the local gateway and external IPs (`8.8.8.8`), RX/TX LEDs show traffic; README says *"believed to be the first working AMIX network driver for the Hydra card"* 🟡 (first-party). **Key unlock = the RX min-frame fix:** the DP8390 RX ring count includes the 4-byte CRC, so post-CRC min frame = **60 not 64** (`ETH_MINFRAME = ETH_MINPACKET − ETH_CRC_LEN`); the old `<64` check dropped min-size ARP replies (frames below it are rejected, not padded — TX padding is separate, vs `ETH_MINPACKET`). It rode on a broader RX/init hardening pass (`NIC_DELAY()` chip-select timing, RX-ring guards/telemetry, NIC-init overhaul `BNRY`/`CURR`/`DCR`/`TCR`/`RCR`/`IMR`, bounded RAM helpers). New: **register-6/`TBCR1`/FIFO trap guard** (raw access while NIC stopped can trap the kernel — a *diagnostic* hazard, not a proven TX cause) and the **`hydra_test`** diagnostic tool + `HYDRA_GET_STATUS`/`HYDRA_IOCTL_TEST` ioctls + `hydra_status_t` counters (in `hydrauser.h`).

> 🟡 The earlier research note "asokero handle not found / isoriano1968 only does AmigaOS Mesa" is **wrong** — these four repos exist and are the project's centerpiece examples. Use the repo facts above.
> ✅ A public, reproducible **cross**-toolchain now exists (2026-06): `isoriano1968/gcc-cross-amix` — a Linux-hosted `Makefile` building binutils 2.8.1 + GCC 2.7.2.3 for `m68k-cbm-sysv4` (real binary `m68k-cbm-sysv4-gcc`), taking the user's licensed Amix tree as a sysroot. C/as/ld work and a dynamically-linked Amix exe runs on real hardware; C++ WIP 🟡. *(Was 🔴 "no public recipe / private build".)* Native on-box build is still simplest for a single driver.

---

## 7. Toolchain & packaging

- ✅ Native compilers: **AT&T SVR4 `cc`** (used for kernel + simple drivers) and bundled **GCC**. Community built GCC up to **2.7.2.3** natively (2.03). Old `gcc 1.4.2` at `/usr/public/bin/gcc`; prefer newer via `CC`. GNU `make` 3.80, GAS, perl 5.005_4 available 🟡.
- 🔴 Symbolic debugger (sdb/dbx/adb) presence on Amix is **unconfirmed**.
- ✅ The modern drivers build **natively on the box** (Hydra: `make`/`make force` with native GCC 2.7.2.3, an amigaunix.com pkg; VA2000: `cc va2000.c`). ✅ A **cross** path is now also public & reproducible: `isoriano1968/gcc-cross-amix` builds `m68k-cbm-sysv4-gcc` (binutils 2.8.1 + GCC 2.7.2.3) on Linux from a user-supplied Amix sysroot — `make all AMIX_ROOT=…`, `m68k-cbm-sysv4-gcc hello.c` → runnable Amix exe; `make test-random CPUFLAGS=-m68030` → a relocatable driver `.o`. Triple `m68k-cbm-sysv4` (autodetect gives `m68k-unknown-sysv4`); the wrapper does `-S` → `.lcomm` fixup → `as -m68020`. C done, C++ WIP 🟡.
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
1. ✅ **RESOLVED (2026-06):** the cross-toolchain now has a public, reproducible recipe — `isoriano1968/gcc-cross-amix` (binutils 2.8.1 + GCC 2.7.2.3 → `m68k-cbm-sysv4-gcc`, user-supplied Amix sysroot; C works, C++ WIP 🟡). *(Was 🔴 "no public build recipe".)* Native on-box build remains simplest for a single driver. The cross binary is `m68k-cbm-sysv4-gcc` — earlier docs' "`m68k-amix-gcc`" was a placeholder name.
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

**Primary:** Ditto, *Writing Amix Device Drivers*, 1990 European Amiga DevCon (our PDF) · the three install ADFs (our analysis) · the repos: github.com/asokero/{va2000-amix,xrtg-amix,lszorro-amix}, github.com/isoriano1968/{hydra-amix, gcc-cross-amix (Linux cross-toolchain)} · AT&T SVR4 *DDI/DKI Reference Manual* · Commodore manuals on archive.org: *Installing/Using/Learning Amiga UNIX* (1990) · amigaunix.com *V2.1 Addendum* PDF.
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

## 17. Z3660 onboard ethernet — `zen0` — first-party, real hardware (2026-06-21) ✅

Native Amix (SVR4.0 / 68030) **STREAMS/DLPI** ethernet driver (`z3660eth`) for the **Z3660** Zorro III accelerator's onboard **Zynq Gigabit Ethernet (GEM)**, presented as interface **`zen0`**. Full bidirectional TCP/IP on a real A4000 + Z3660; the box was driven entirely over the link (telnet/ftp). Source: the amix-z3660net project — `src/z3660eth.{c,h}`, `driver.conf`, `userland/S99zen` — plus the Z3660 firmware source. Full page: `docs/drivers/z3660-ethernet-driver.md`.

- ✅ **Not NIC emulation.** The firmware already moves whole ethernet frames between the 68k guest and the Zynq GEM; the driver speaks the firmware's **MMIO frame mailbox** (RTG register page at `board_base + 0x000`; piscsi is at `+0x2000`) and presents a **DLPI Style-1** connectionless provider, brought up with stock `slink` + `ifconfig` (SVR4.0 has **no `ifconfig plumb`**). Registers: `ZZ_CONFIG 0x104`, `ZZ_ETH_TX 0x190`, `ZZ_ETH_RX 0x194`, `ZZ_ETH_MAC_HI/LO 0x198/0x19C`, `ZZ_ETH_RX_ADDR 0x1A4`, `ZZ_INT_STATUS 0x1A8` (verified vs `src/z3660eth.h` + firmware `rtg/rtg.c`, `ethernet.c`, `memorymap.h`, `rtg/zzregs.h`).
- ✅ Wired into `cdevsw[]` at **char major 48** (the free `nostr` slot on the stock/A4091 kernel), tag `zen` → `zen0`; AutoConfig id **`0x144B0001`**, fixed combo base **`0x10000000`** (AGA fallback), station MAC `00:80:51:01:02:03` on the wire. `driver.conf` stanza `net z3660eth z3660eth.c z3660ethinfo 48 zen "Z3660 Ethernet"` (consumed by kerntools `build-net-kernel.sh`).
- ✅ **Lazy-open + polled RX → no `int2_tbl`/`init_tbl` edit.** Autoconfigs on first `open`, services RX from a clock-level `timeout()` callout; a GEM-less build box boots cleanly and `open()` simply returns `ENXIO`.
- ✅ **★ INT6 interrupt-storm — the real-hardware blocker.** The firmware raises Amiga **INT6 (EXTER)** on *every* received frame; Amix has no level-6 ethernet handler, so ordinary ARP broadcast traffic stormed INT6 and **hard-locked the box** the moment the interface came up. Fix (commit `b06cf45`): write `ZZ_CONFIG_DISABLE` (0) so INT6 is never raised; RX still works via the bounded poll/drain. **No firmware change needed.** (Carried as quirks §12 item 14.)
- ✅ FCS boundary: the firmware delivers the raw `XEmacPs_BdGetLength` and does **not** strip the FCS; the driver pads TX to the 60-byte minimum and must **not** subtract `ETH_CRC_LEN` from RX (opposite of hydra's DP8390, which reports a CRC-inclusive length — §6). `spl6`/`splx` **don't exist in Amix SVR4.0** → no-ops in `z3660eth.h`; STREAMS code must spell out `unsigned char/long/short` (no `rico.h` `uchar`/`ulong`/`ushort`). The 030 data-cache flush (`Z3660ETH_CACHE_FLUSH`) was **not needed** (windows under TT0), left OFF.
- ✅ Validated live (2026-06-21, A4000 + Z3660): `ifconfig zen0` UP, 40/40 inbound flood ping (0% loss), outbound ping to laptop + gateway, `netstat -in` **0 errors / 0 collisions**, telnet/ftp over `zen0`; sustained FTP ~185 KiB/s 🟡 (working baseline, not tuned). Built on a networked Amix box; the clean-kernel bar is **`nm -u`** (not `sum -r` recurrence or `checkunix`), via kerntools `build-clean-net-kernel.sh`. ⚠️ never delete the 22 generic SVR4 `exp` blobs (no source on the box, not regenerable).

## 18. Z3660 onboard "SCSI" (piscsi) — `z3660.c` — first-party, real hardware (2026-06-12/13) ✅

Native Amix (SVR4.0 / 68030) **block** driver for the **Z3660** accelerator's onboard "SCSI" — the SCSI counterpart to the Z3660 *ethernet* driver (§17) on the same combo board, and a third Zorro III data point alongside the A4091 (§15). Amix boots **multiuser with the piscsi disk as root** on a real A4000 + Z3660; every boot transfer byte-perfect from the first real-hardware boot. Source: the amix-z3660scsi project @ `8ea1605` — `src/z3660.c`, `src/kernel-patches/sd.c`, `driver.conf`, `NOTES.md`, `README.md`; firmware-side facts from the Z3660 firmware fork (branch `amix-main`; the earlier `amix-boot` branch was rebased into it), cited not reproduced. Full page: `docs/drivers/z3660-scsi-driver.md`.

- ✅ **The onboard "SCSI" is not a SCSI chip** — it is the PiStorm `piscsi` register mailbox ported to the card's Zynq ARM: **no 53C710, no SCRIPTS, no DSA, no bus-phase management, no interrupt/poll completion** (empty `z3660intr()` stub; synchronous `timeout()`/`z3660done`). ~5 register pokes per I/O — **lower-risk to port than the A4091 53C710 driver (§15)**. (`z3660.c:4-8` header, :379-381, :246-250,374; `README.md:8-10`.) 🟡 sub-detail: leftover `siop_softc`/`a4091` symbols are vestigial AmigaOS/boot-ROM scaffolding from upstream `shanshe/Z3660` `z3660_scsi.h` (now-removed vendored clone) — asserted in `NOTES.md`, not re-verifiable from the committed repo.
- ✅ **Protocol** (32-bit big-endian MMIO at `board_base + 0x2000 + cmd`, `PISCSI_OFFSET 0x2000`): per-I/O = write `P_DRVNUMX`(0x90)=unit → the **direction's address triple** = block, byte length, buffer addr (READ uses `P_READ_ADDR1/2/3` `0x20`/`0x24`/`0x28`; WRITE uses `P_WRITE_ADDR1/2/3` `0x240`/`0x244`/`0x248`) → command register `P_WRITE`(0x00)/`P_READ`(0x04) **with value=unit**. That single command-register write is **both trigger and completion** (the ARM intercepts the Zorro III bus cycle and finishes the whole transfer before it returns; no poll, no IRQ). All Amix RAM `< 0x08000000` (`BOUNCE_THRESH`) so the path **always bounces** through `board_base + 0x80000` (`BOUNCE_OFFSET`): WRITE bcopies in before issuing; READ checks `P_USED_DMA`(0x9C) and bcopies back. `MAXXFER 65536` (≤64 KB). Geometry from `P_DRVTYPE`(0x0C) + per-unit `P_BLOCKSIZE0`(0x200)/`P_BLOCKS0`(0x220) (`+unit*4`). `INQUIRY`/`READ_CAPACITY`/`TEST_UNIT_READY`/`MODE_SENSE` **synthesized in software** in `z3660queue`; READ/WRITE 6/10 → `z3660_rw`; multi-byte SCSI fields byte-wise big-endian (alignment-safe). (`z3660.c` :64,72-79,181,191,206-228,278,286-335.) Firmware superset names the chunk constant `PISCSI_MAX_BLOCK_SIZE` and exposes an unused `READBYTES`/`WRITEBYTES`(0x88/0x8C) family.
- ✅ **Board identity / window:** mfr `0x144B` product **`0x01`** = the Z3 RTG+piscsi combo window **both** Z3660 drivers probe (`0x144B0001`); `0x03` = Z2 RTG+SCSI combo (advertises 64 KB); `0x02` = Z3 fast RAM. With `autoconfig_rtg NO` the window is at a **fixed `0x10000000`** (`Z3660_FIXED`); the driver `sptalloc`-maps the register window + bounce buffer into kernel VA (`z3660.c:139-142`), the same primitive the A4091 uses (§15) — the real difference from the A4091 is the bus protocol (mailbox vs SCRIPTS/DSA), **not** direct-deref vs mapping (both page-map). The fixed base does fall inside the documented TT0 range (§15), so here the `sptalloc` is a convenience, not forced by an unmapped TT gap. **The Z2 variant (`product 0x03`) is unusable for Amix piscsi**: base `0xE90000` + bounce `0x80000` = `0xF10000` = extended-ROM space (ext kickstart at `0xF00000`); since RAM `< 0x08000000` the firmware always bounces, so the Z2 path can't move data. (`Z3660_PROD 0x144B0001`:58, `Z3660_FIXED 0x10000000`:59; firmware taxonomy from `NOTES.md` "Real-hardware findings (2026-06-12)" + firmware fork branch `amix-main` (formerly `amix-boot`, since rebased), firmware-repo-owned.)
- ✅ **Detection — the original silent hang → multi-method detect.** The 2.1 `bootinfo.autocon[]` misses the board both with `autoconfig_rtg NO` (expected: fixed base, not in the chain) **and** `YES` (KS configures it at `0x40000000` but the 2.1 table still misses it). An `sd.c` that registers controllers **only** via `autocon()` → `z3660queue` never runs → kernel banner then **silence** (no panic, no I/O). Fix = `autocon()` → **AGA-gated** (`VPOSR>=0x22`) probe of the fixed `0x10000000` requiring `DRVTYPE ∈ {0,1}` → `driver.conf` `probe=z3660present` fallback hook (the `probe=` *dispatch* lives in the **amix-kerntools** `sd.c` template, not this repo's committed `sd.c`, which only adds the `scsicard[]` row). This carried the real-HW boot past the silent banner. (`z3660map` :131-155, `z3660present` :163-171, `driver.conf:5`; `NOTES.md`:173-179,204.)
- ✅ **`P_DRVTYPE`(0x0C) is a safe 0/1 presence probe** for an un-enumerated board (the driver rejects `t>1` as open bus); a reported block size of `0` is coerced to `512`. (`z3660map` :148-153, `z3660_blocksize` :182.)
- ✅ **Kernel integration:** registers a queue function in `sd.c`'s `scsicard[]` registry (the stock SCSI stack — block major 18 / char major 40, like the A4091 §15), via `driver.conf`: `0x144B0001 z3660queue "Z3660 SCSI" z3660.c probe=z3660present`. Real-HW root disk = `/dev/rdsk/c6d0s1` (SCSI target 6, card 0). Boots multiuser byte-perfect, ~100+ reads/writes per boot, **first try**; spot-checked page-in first-longs of `/sbin/init` + `libc.so.1` matched file content. (Live boots 2026-06-12/13; `NOTES.md` :204-208,269-296; `CLAUDE.md` status line.)
- ✅ **The "boots then hangs" was the firmware EMU core, not the driver.** The 68k emulator faulted while demand-paging the driver's own text back in — two MMU format-`$B` exception-frame bugs (SIGILL on instruction-fetch-fault resume; SIGSEGV on mid-instruction replay state); `init` died at libc `_rt_boot+0`. **Firmware-owned fix** (branch `amix-main`, `3069e22` ifetch-fault resume/prefetch sentinel, `0b42cb8` mid-instruction frame-storage — these are the live successors of the earlier `amix-boot`-branch hashes `c8b9398`/`e3f9440`, which no longer exist after that branch was rebased; `0b42cb8`'s body names `c8b9398` as its predecessor). A **later, distinct** pair — `7ff5774` + `acdfe15` — fixed a multi-fault-continuation frame corruption seen as an intermittent *under-load* `User BUS ERROR` (see §19). Reusable lesson = the **driver-vs-emulator triage method**: kernel-side serial instrumentation + core-dump (adb/capstone) analysis to prove transfers byte-perfect and isolate the fault to the emulator, not the driver. (`NOTES.md` :199-228,269-296.)
- 🟡 **Firmware debug lever + hazard** (asserted in `NOTES.md` §"Free 68k→serial debug channel" :180-189 from real-HW sessions, **no firmware file+symbol citation and no recorded standalone reproduction**; the register offsets `P_BLOCKS 0x10` and `P_BLOCKS0 0x220` *are* confirmed in `z3660.c`): (a) writing the **read-only** `P_BLOCKS` register makes the Zynq ARM print `WARN: Write to read only register …(addr: value)` on serial — a free 68k→serial breadcrumb technique; (b) **never** read `P_BLOCKS0 + unit*4` of an **unmapped** drive — the ARM divides by that unit's `block_size 0` (Zynq divide-by-zero), which is why the driver gates on `DRVTYPE ∈ {0,1}` before touching per-unit registers.

## 19. Emulation fidelity — what a 68030/MMU/interrupt emulator must get right to boot Amix — first-party (2026-06) ✅/🟡

Amix leans on the raw 68030 harder than any other classic-Amiga OS (full MMU/HAT demand paging + INT2 SCSI bootstrap), so an emulator can pass every AmigaOS test yet fail Amix — often silently. These findings come from the **Z3660** accelerator, whose firmware runs a **UAE-4.4.0-derived 68030+MMU software CPU** on its Zynq SoC; a real A4000 + Z3660 therefore executes Amix on that emulator, and the fixes were verified on real hardware (2026-06: cold-boot to multiuser root login, HDMI console + telnet, `uname -a` → `UNIX_System_V … 2.1c … m68k`). **Firmware-owned; cited not reproduced.** Source: Z3660 firmware repo, branch `amix-main` @ `703c0dc` — `src/uae/cpummu030.cpp`, `src/uae/newcpu.cpp`, `Z3660/src/config_file.{c,h}`, `docs/AMIX.md`, `CHANGES.md`; delivered as the first-party `import/z3660-emulation` handoff. Full page: `docs/how-it-works/emulation-fidelity.md`.

- ✅ **68030 bus-error-frame semantics are load-bearing for demand paging.** On a page fault the 030 stacks a format-`$B`/`$A` bus-error frame and `RTE` resumes the faulted instruction mid-flight; an emulator that builds/resumes that frame wrong silently resumes the process at the wrong PC/mode/opcode. Two generations of fixes:
  - **First generation (boot-time first-fault death):** `3069e22` restores the "fault during opcode prefetch" sentinel in the format-`$B` frame (else `init` dies **SIGILL** at libc `_rt_boot+0`); `0b42cb8` ports the full WinUAE format-`$B` frame-storage so a fault part-way through a non-idempotent instruction (`MOVEM`, `(An)+`/`-(An)`, RMW) restarts correctly (else **SIGSEGV** on a later fault). ✅ These are the **live successors of the dead `amix-boot` hashes `c8b9398`/`e3f9440`** (§18) — proven because `0b42cb8`'s body names `c8b9398` as its predecessor and the old hashes are absent from the current tree.
  - **Second generation (multi-fault continuation, under load):** when an instruction resumed *from its bus-error frame* faults **again** (a `MOVEM` prologue growing the user stack across a not-yet-resident page; the still-unmappable page hit by the `RTE`'s own retry-access), the emulator rebuilt the new frame from a **stale outer-loop snapshot** — the kernel trap-return epilogue PC `~0x0800129C`/opcode `0x4E73` — so a format-`$B` frame carried a wild kernel PC (observed constant `0x5C000000`) and a format-`$A` frame's opcode flipped a user `clr.b 0x4218` to `0x4E73`; the next `RTE` resumed a user process at a kernel PC **in user mode** → intermittent `User BUS ERROR … FAULT:6` + panic, killing `cron`/`in.telnetd` under fork/exec load (telnet-storm reproducer). Fix: `7ff5774` re-snapshots `mmu030_insn_start_pc`/`regs.instruction_pc` at the inner-loop continuation point (behavioural change in `newcpu.cpp`); `acdfe15` (its declared residual) re-points `mmu030_insn_start_pc = pc; regs.opcode = regs.irc = mmu030_opcode` just before the in-`RTE` retry-access (in `cpummu030.cpp`). ✅ Verified: host MMU harness 60/60 → **64/64** with a two-fault-continuation regression test; a **27-reboot** multi-hour soak under fork/exec load ran clean. 🟡 One rare bus-error-frame `SR`-flip under *extreme* sustained paging load remains tracked (did not recur across the soak).
  - **General requirement (emulator-agnostic):** any emulator running Amix's demand-paging boot must implement format-`$B`/`$A` frames faithfully — fault PC, prefetch sentinel, mid-instruction replay state, and correct re-attribution on continuation re-faults. UAE-derivatives historically diverge here; the fixes trace to porting WinUAE's frame handling.
- ✅/🟡 **A3000-mainboard SCSI bootstrap is sensitive to INT2 (level 2) detection latency.** The bootstrap is interrupt-driven on Amiga INT2 *before* the banner; an emulator that batches instructions between interrupt-service polls raises worst-case INT2 latency to ~batch size and can **hang the bootstrap before the banner**. Exposed by the `service_cadence N` knob = instructions run between `check_uae_int_request()` polls (`do_specialties()` stays per-instruction): ✅ **default 1**, clamped `<1 → 1`, boot-settable (`z3660cfg.txt` + per-preset, commit `e0e17d5`) and runtime-cyclable `1→…→64` via serial `SERV` (commit `f7bbdb0`); ~**1.3× CPU** at cadence 64 (Dhrystone 2.1 on real A4000+Z3660), knee ~8, disk I/O flat. 🟡 **Amix-safe boundary:** cadence **2 and 4 boot**, cadence **8 hangs** the A3000-SCSI bootstrap → recommend `service_cadence 4` at boot, raise to 8 only after boot via `SERV`. The knob/default/clamp/semantics are code-grounded ✅; the **INT2-latency attribution and the 4/8 boundary are an author HW sweep** (firmware `docs/AMIX.md` + shipped `z3660cfg.txt`), not a root-caused defect or committed artifact — **🟡, not upgraded**. `e0e17d5`'s own message was initially more conservative ("any cadence > 1 hangs before MMU-enable; keep the Amix preset at default"); the 4-safe result is a later refinement, and no shipped preset bakes in a non-default cadence (the `4` is a recommendation).

## 20. Stock SVR4 package system — internals + a `contents`-DB corruption defect — first-party (2026-07-01) ✅/🟡

Amix ships the **standard AT&T SVR4 packaging system** (`pkgadd`/`pkgrm`/`pkginfo`/`pkgmk`/`pkgtrans`, master DB under `/var/sadm`). All findings **reproduced firsthand on a clean Amix 2.1c image** (`UNIX_System_V … 4.0 2.1c 0800430 … m68k`) under WinUAE over telnet/ftp; the **amix-packagemanager** project (repo not yet under git; command transcripts retained there). Runtime-behaviour + on-disk data-record layout only — no proprietary `pkg*` source/media reproduced (the one malformed `contents` record below is cited as factual defect data, not vendored source). Full page: `docs/how-it-works/package-management.md`. This complements grimoire's existing pkg *usage* coverage (`docs/reference/commands-cheatsheet.md`, `docs/drivers/toolchain.md`) with the DB internals, media format, mutation mechanics, and a shipped-image defect.

- ✅ **Installed toolset + three absences (F1):** `/usr/bin` = `pkginfo pkgmk pkgproto pkgparam pkgtrans`; `/usr/sbin` = `pkgadd pkgrm pkgchk installf` (`pkgadd`/`pkgrm`/`installf` are `r-x------` root-only). **`pkgask`, `removef`, `amixpkg` are NOT installed** (`installf` present without partner `removef`). No `pkg*` man pages (Amiga-reorganised man tree: `man1A/1X/3A/5A/6/…`, no `man1m`/`man4`). Lands in `commands-cheatsheet.md`.
- ✅ **`/var/sadm` layout (F2):** `/var/sadm/install/contents` = master installed-object DB (~2.3 MB / **28,645 lines** on this image, mode **`rw-rw-rw-` world-writable**); `/var/sadm/install/admin/default` = `admin(4)` policy; `/var/sadm/pkg/<PKG>/` = `pkginfo` + `install/` (scripts) + `save/`. **No per-package `pkgmap` in the installed DB** — file ownership is the trailing package field of each `contents` line. **31 packages**, all `ARCH=Amiga`, `CATEGORY=system`, **no `VERSION`**.
- ✅ **`contents(4)` grammar (F3):** whitespace-delimited, one line/pathname, trailing field(s) = owning package(s). By ftype: `f` → `path f class mode owner group size cksum modtime pkg` (e.g. `/usr/bin/ls f none 0555 bin bin 13824 51698 690829200 core`); `d` → `path d class mode owner group pkg`; `s` → `path=target s class pkg` (e.g. `/bin=/usr/bin s none core`); `c`/`b` → `path c|b class major minor mode owner group pkg`. Header comment `# Last modified by <amixpkg|pkgadd> for <PKG> package` records the last writer. **No quoting** → assumes no whitespace in pathnames (violated → F7).
- ✅ **Media formats (F4):** *Directory* (what `pkgmk` emits, `pkgadd -d <dir>` reads) = `<PKG>/` with `pkgmap` (`: <nparts> <nblocks>` then `<part> <ftype> <class> <path> <mode> <own> <grp> [size cksum mtime]`) + `pkginfo` (`pkgmk` stamps `PSTAMP=<host><YYMMDDhhmmss>`, `CLASSES=none`) + `root/` (absolute payload) and/or `reloc/` (relocatable). *Datastream* `.pkg` (`pkgtrans` output; the form **AmixBP/amigaunix.com distribute** 🟡) = ASCII header `# PaCkAgE DaTaStReAm` / `<PKG> <nparts> <nblocks>` / `# end of header`, then SVR4 **`070701` (portable ASCII / "newc")** cpio carrying pkginfo, pkgmap, payload.
- ✅ **`pkgadd` DB-mutation mechanics (F5):** inserts each object line into `contents` **in sorted pathname position** (not appended), tags the trailing field with the package name, creates `/var/sadm/pkg/<PKG>/{pkginfo,install,save}`, installs payload, rewrites the "Last modified by" marker to `pkgadd`. `pkgrm` reverses via a full `contents` parse (→ F7 blocks it).
- ✅ **Stock packages are pure payloads (F6):** empty `install/` (no preinstall/postinstall/request/checkinstall/class-action scripts), `CLASSES=none`, no `depend` file (no formal deps). Only non-`pkginfo` files in the DB are saved sysadm `.mi` menu-interface files under `save/intf_install/` for `bnu/lp/nsu/face/sysadm` (the one non-`none` class, `intf_install`, tied to `OAMBASE=/usr/sadm/sysadm`).
- ✅ **⚠ Space-in-pathname corrupts `contents`, breaking `pkgrm` + `pkginfo -l` on the stock image (F7):** both abort `ERROR: bad read of contents file / pathname=/usr/x11r5/fonts/server/MacFS/TrueType / problem=unknown ftype`. Cause: a record for a file **named with a space** — `/usr/x11r5/fonts/server/MacFS/TrueType Fonts f none 0444 x sys 525157 64049 679609720 X11R5 X11R5`; the unquoted whitespace-delimited parser ends the pathname at the space, reads `Fonts` as the ftype → "unknown ftype", and every full-parse tool aborts (record also ends with duplicated `X11R5 X11R5`). **Sole blocker:** deleting that one line makes `pkgrm` succeed (cleanly reverses an install) and `pkginfo -l` work. Strong candidate for part of the "pkg tools broken" reputation. Lands in `package-management.md` + `quirks.md`.
- ✅/🟡 **`amixpkg` is an install-media front-end, absent from the installed system (F8):** not in `/usr/sbin`,`/usr/bin`,`/sbin` ✅, yet `contents` names it the DB's **original writer** (`# Last modified by amixpkg for X11r5src package`) ✅ — i.e. it is the root.adf installer that populates `/var/sadm` via the same machinery as `pkgadd` (`amixpkg -i -m -d … -r /mnt -y standard`, §9). Its "widely reported broken" reputation 🟡 is at minimum consistent with the F7 corruption (which disables removal/query on the stock DB). **Reconciles the existing 🟡 "amixpkg wrapper broken" note (§4/§7/quirks §12.10):** the concrete reproducible breakage on the stock image is the `contents` data defect, and `amixpkg` is an install-time wrapper **not present on the running box** — not (necessarily) a bug in `amixpkg`/`pkgadd` themselves. Tag ✅ (absence + writer marker) / 🟡 (reputation + exact root.adf invocation).

## 21. ZZ9000 RTG stack — kernel framebuffer driver + X11R6.3 port + Mesa 3.1 (isoriano1968, 2026-07-03) ✅ (from repo source/READMEs)

Three sibling repos published **2026-07-03** by **isoriano1968** (Ignacio Soriano — the `hydra-amix` / `gcc-cross-amix` author) form a complete modern **graphics stack** for Amix on the MNT **ZZ9000** Zorro II RTG card: a kernel framebuffer driver, an **X11R6.3** port whose server is `Xzz9000`, and a **Mesa 3.1** software-rendering bootstrap. Target machine: a real **A3000UX**. All repo facts below are ✅ (read from the repo source/READMEs at the initial commits: `zz9000-amix@75e2449`, `x11r6.3-amix@43383c5`, `mesa-amix@78fe054`); runtime results ("links and starts at 1920×800", "tested primary mode") are the **author's reports** on his hardware, not reproduced on this project's bench. All three are **MIT** (new code) and **overlay-style**: they ship only the Amix delta; each `install.sh` downloads the pristine upstream sources (X11R6.3 `xc-1/2/3.tar.gz` from x.org; `MesaLib-3.1`/`MesaDemos-3.1` from archive.mesa3d.org), **verifies SHA-256** against a committed `SOURCES.sha256`, extracts, and applies `overlay/` — the same never-commit-upstream licensing discipline this project uses.

### `isoriano1968/zz9000-amix` — kernel framebuffer/mode driver, `/dev/zz9000` char major 49 (v0.1.0)
- ✅ **Zorro II product 3 only.** MNT manufacturer `0x6d6e`, product 3 (`autocon(0x6d6e0003)`); the ZZ9000's **Zorro III identity (product 4, `0x6d6e0004`) is detected and deliberately rejected** — Amix has no Zorro III bus support; the driver prints "configure card as Zorro II product 3 for AMIX". Presence sanity check: HW-version reg `0x00` and FW-version reg `0xc0` must not both read 0/0xffff; warns if firmware < `0x010d`.
- ✅ **Address map** (from `zz9000.h`): registers `0x0000–0x1FFF` (`ZZ9K_REG_SIZE 0x2000`); framebuffer at **board + `0x10000`** (`ZZ9K_FB_OFFSET`); usable `fb_size = board_size − 0x10000 − 0x20000` (a reserved Zorro II tail). Key regs: `MODE 0x02` (packs `mode | color<<8 | scale<<12`), `CONFIG 0x04`, 32-bit `PAN 0x0a/0x0c`, `VCAP_MODE 0x0e`, `VBLANK_STATUS 0x4c`, `FW_VERSION 0xc0`; blitter block `0x10–0x5e`; capture/CX block `0x1000–0x1006`. 18 mode IDs (0–17; `1920x800 = 17` is the author's tested primary), color modes 8-bit/RGB565/32-bit/15-bit.
- ✅ **Classic SVR4 char driver** at **major 49 minor 0** (`/dev/zz9000`, `mknod c 49 0`, mode 666): `zz9000init` in `init_tbl[]` probes unit 0 at boot; `open/close/read/write` (uiomove over the whole board window), **`mmap`** (`phystopfn(base+offset)`), and 13 ioctls in group `'Z'<<8`: `GETINFO 1, SETMODE 2, SETPAN 3, SETSWITCH 4, FILL 5, GETREG 6, SETREG 7, GETAUTOCON 8, PROBE 9, CONSOLE 10, GETFBINFO 11, FILLRECT 12, COPYRECT 13`. `GETFBINFO` returns geometry + stride + per-channel masks/shifts. `SETSWITCH` toggles RTG (1) vs the native-video capture pass-through (0; capture restores pan `0x00e00000` and sets `CX_CAPTURE`).
- ✅ **`FILLRECT`/`COPYRECT` are CPU loops** (RGB565 only, with full bounds checks); the driver *contains* blitter register code (`zz9k_blit_fill`/`zz9k_blit_copy` writing the `0x10–0x5e` block) but **no ioctl calls it in 0.1.0** — acceleration is scaffolded, not wired.
- ✅ **Kernel framebuffer console with an ANSI/CSI parser**, 1920×800 RGB565: cursor movement `A/B/C/D/H/f`, clears `J/K`, SGR `0/1/7/30–37/40–47` over an 8-color RGB565 palette; glyphs from Amix's own console font (`builtinfont[0]`, magic `0x2a46`; the Makefile links `amiga/console/sunfont.o` into the driver's `exp`) with a 5×7 built-in fallback; CPU scroll. Exported hooks `zz9000consoleputc()`/`zz9000consolewrite()` force the display switch to RTG before drawing.
- ✅ **Safety model — no early console takeover.** README: earlier experiments that enabled RTG console output before the native Amix console was initialized **could stop the machine before filesystems or networking came up**; the supported design activates redirect **late**, from `/etc/rc2.d/S99zz9000` (`zz9k_test /dev/zz9000 redirect`; `stop` returns HDMI to the native capture path). The optional `c1.c` hook is 2 lines in `c1write()` gated on **`sp == displayedscreen`** — without that test *every* virtual terminal's output lands in the one framebuffer console. X11 use needs **neither** the hook nor the init script.
- ✅ **Integration = 3 documented fragments** (`integration/`): `master.d/kernel.c` (extern + `zz9000init,` in `init_tbl[]` + a `cdevsw[49]` row with real `mmap`), `amiga/driver/Makefile` (`zz9000/exp` in `OBJ`), optional `amiga/console/c1.c` hook. Build: `install-source.sh [prefix]` copies the subtree to `/usr/sys/amiga/driver/zz9000`; `make` there (gcc, `-O -traditional -fno-builtin -D_KERNEL -DSVR40 -DSVR4`, `ld -r → exp`), then `cd /usr/sys && make force`.
- ✅ ⚠ **Major-number collision across community trees:** the author's tree assigns **47 hydra, 48 `random`, 49 zz9000, 50 `sad`** — while this project's family assigns **48 to `z3660eth`/`zen0`** (§17). Both are self-picked free slots; INSTALL.md itself says to verify major 49 is free in *your* `cdevsw[]`. There is no registry — always check before merging community drivers.
- ✅ **Tools** (installed to `/usr/amiga/bin`): `zz9k_test` (diagnostic: board report — must show mfr `0x6d6e`, product `0x03`, Zorro II address, fw version, geometry — plus mode tests `zz9k_test /dev/zz9000 16 1920x800`, `blit`, and console subcommands `console/consoletest/redirect/noconsole`), `colorls` (LS_COLORS-driven color `ls` for the framebuffer console), `zz9k_console` + `zz9k_colorls_env` wrappers.
- ✅ **Scope:** graphics + console only — no USB, and **no ZZ9000 ethernet driver** in this release. The README names the driver as the foundation used by "the ZZ9000 X11R5 and X11R6.3 RTG servers" (only the R6.3 server is among the published repos).

### `isoriano1968/x11r6.3-amix` — an X11R6.3 port; server `Xzz9000` over `/dev/zz9000`
- ✅ **Author-reported status:** builds with **GCC 2.7.2.3** + the GNU cpp at `/usr/public/lib/gcc-cpp`; `Xzz9000` **links and starts at 16-bit modes including 1920×800**; R6 pixmap-private storage works for both 16-bit drawing and depth-1 font/cursor bitmaps; dynamic `xclock`/`xterm`/`twm` are the validation targets; **GLX/Mesa not included yet**; explicitly development software. Installs under **`/usr/x11r6`**, coexisting with the stock X11R4/R5.
- ✅ **Platform config `config/cf/amix.cf`:** `-DAMIX -Dm68k -DSVR4`, `SystemV4`, OSName "Amiga UNIX System V Release 4.0" / vendor Commodore-Amiga; `ProjectRoot /usr/x11r6`; **`HasShm NO`** ("MIT-SHM … is unsafe on AMIX" — independent of the shared-library choice); shared libraries **YES** in the **SunOS-4-style shared-code/shared-data model** (`SharedDataSeparation YES`, `-DSHAREDCODE`/`-DSUNSHLIB`, `gcc -fpic`, `SharedLibraryLoadFlags -G`) — deliberately matching the working X11R5 Amix ABI; `XawI18nDefines -DUSE_XWCHAR_STRING -DUSE_XMBTOWC` because Amix lacks `wctype.h`/`widec.h`; sockets `-lsocket -lnsl`, server extras `-ldbm -lscreen`; `BuildPex NO`, `BuildXKB YES` (but the launcher passes `-kb`: the XKB *device* path is unfinished); `XAmixServer YES`.
- ✅ **Server composition** (`programs/Xserver/Imakefile`): `Xzz9000` = DIX + `mfb` + `cfb` + `cfb16` + the `hw/amix` DDX libs (`amix`, `rtg`, `zz9000`). `servermd.h` gains an `AMIX` block: `IMAGE_BYTE_ORDER`/`BITMAP_BIT_ORDER = MSBFirst`, `GLYPHPADBYTES 4`, `FAST_UNALIGNED_READS`.
- ✅ **DDX lineage & layering:** `hw/amix/` (amixInit/Io/Kbd/KeyMap/Mouse/Mono/Cursor) carries 1987 Sun/UC-Regents copyright — the same Sun-derived DDX family as the stock Amix X server — with a probe/create table `amixFbData[]`. New **generic RTG layer** `hw/amix/rtg/` (`rtgProbe`/`rtgCreate`/`rtgScreenInit`, per-screen `rtgScreenRec`, GC clip privates "same pattern as TIGA's GCPRIV") and the **card driver** `hw/amix/rtg/zz9000/` (Probe/InitHW/ScreenInit + the drawing vector; GC management "modelled on dmi/tiggc.c" — the TIGA DDX). Fills go to `ZZ9000FillSpans`/`ZZ9000SolidRect`, CopyArea to `ZZ9000CopyArea`; tile/stipple currently fall back to solid (marked TODO); lines/arcs/text delegate to the mi layer. **A second RTG card would be a new subdir under `rtg/`** — the layer is explicitly card-generic ("Each card provides its own header … First supported card in this tree: MNT ZZ9000").
- ✅ **DDX↔driver contract** (`zz9000hw.c`): open `/dev/zz9000` → `ZZ9KIOC_PROBE` → `SETMODE` (RGB565; built-in mode table 640×480…1920×800, default **1920×800**, `-mode` server flag) → `GETINFO`+`GETFBINFO` → `mmap` the whole board window → `FILL` to clear → `SETSWITCH RTG`; on close `SETSWITCH CAPTURE` + munmap. **All drawing is CPU into the mmap'd framebuffer** — the kernel FILLRECT/COPYRECT ioctls are not used. TrueColor RGB565 visual; **software cursor** (no hardware sprite).
- ✅ **Input path:** `OpenScreen()` on the Amix screen manager → event fd; then **`SIOCACTIVATE`** — *not* `DisplayScreen()`, which would require `NewBitmap` (a chip-RAM native bitmap) and take over the ECS display, making the screen manager **SIGHUP the X server** when the native console loses its screen; `SIOCACTIVATE` selects the screen as event target only, leaving the native display alone. Then `SIOCSETINPUTMODE SIM_RAWKEY` for raw keycodes. If `OpenScreen` fails the server starts **display-only** with a no-op wakeup handler (guarding `FD_ISSET(-1)` — undefined behaviour that crashes on m68k SVR4). The comment cross-checks the approach against Klaus Burkert's `Xsvga`, which uses the same input path.
- ✅ **The Amix shared-library ABI** (SHARED-LIBRARIES.md; "validated on AMIX with GCC 2.7.2.3 and the native link editor"): SVR4 runtime loader with a **split shared-code/shared-data model**. `libfoo.so.N` is an ELF runtime image built by the **native linker: `ld -G -h libfoo.so.N -o … objects`** — both `-G` and the `-h` SONAME required; **never `gcc -G`** (GCC 2.7.2.3 adds executable startup objects → runtime "missing `main`"); `-Bsymbolic` was tested and does **not** fix loader failures. Companion **`.sa` stub archives** (`libXt.sa`, `libXmu.sa`, each containing exactly `sharedlib.o`) supply executable-resident entry points/data the shared-data ABI needs; **Xaw has no `.sa`**; a `.sa` must never be named/used as `libfoo.so`. **Link order is left-to-right and load-bearing:** each `.sa` immediately after its `-l`, providers after users — `-lXaw -lXmu libXmu.sa -lXt libXt.sa -lSM -lICE -lXext -lX11 -lsocket -lnsl`; omitting `libXt.sa` → unresolved `XtOpenApplication`/`XtToolkitInitialize`. **Stale experiment `.so`s are fatal** (a stale `libICE.so.6.3` crashed every Xt client before `main`); never mix static and PIC objects. `config/util/amix-shared-rebuild.sh` (modes `libs/all/clients/shdata`) deletes old objects, rebuilds, and validates (`file` + `dump -Lv` each image, `.sa` content check, relink `xinit`/`xsetroot`/`xclock`/`xterm`/`twm` before ever starting `Xzz9000`).
- ✅ **Launcher:** `config/util/startXzz9000 [:display]` (env `ZZ9K_MODE`/`ZZ9K_FONT_PATH`/`X11R6_TOP`) runs `xinit` + `xinitrc.zz9000` (twm/xterm/xclock session from the build tree) with `-ac -kb -terminate` — insecure by design for the local test; don't expose it.
- ✅ **Compat shims:** imake bootstrap (`Makefile.ini`, `imakemdep.h`), old-cpp/make fixes (`programs/Imakefile`, `rstart/Imakefile`), an Amix-`lex`-compatible `twm/lex.l`. Licensing: X11R6.3 = X Consortium; Amix glue derived from historical X11 keeps UC/Sun/MIT notices; new material MIT.

### `isoriano1968/mesa-amix` — Mesa 3.1 software-rendering bootstrap (Xlib driver)
- ✅ **Design:** Mesa **3.1** with the **Xlib software driver** against the X11R6.3 tree — needs **no server-side GLX and no ZZ9000 3D acceleration**; renders client-side and ships pixels over the X protocol. Build trees: `/usr/mesa3/Mesa-3.1` (Mesa) against `/usr/x11r6` (X). Deliberately independent of the `xc` source tree.
- ✅ **The one config trick:** upstream Mesa 3.1 **already contains a historical AMIX target**; the overlay keeps it but **replaces the multi-platform `Make-config` wholesale with an AMIX-only version** (`config/Make-config.amix`) because the old Amix `make` parses *every* included rule and chokes on malformed backslash continuations in unrelated platform targets. CFLAGS `-O -ansi -finline-functions -DAMIX -Dm68k -DSVR4`; libs `-lX11 -lsocket -lnsl -lm` from `/usr/x11r6/xc/exports/lib`.
- ✅ **Exclusions (first milestone):** no MIT-SHM, no pthread/Solaris threads, no CPU assembly, no DRI, no server-side GLX, no ZZ9000 hardware accel. **Static first**: `amix-build.sh libs` builds `libGL.a` (src, Xlib driver) → `libGLU.a` (src-glu) → `libglut.a` (src-glut); then `amix-build.sh xdemos` for a minimal visual test against `Xzz9000` (`DISPLAY=:1`, `LD_LIBRARY_PATH=/usr/x11r6/xc/exports/lib:/usr/lib`). Native Amix `.so` rules come only after the static renderer + demos are proven.
- ✅ **Ownership split:** the X11R6.3 repo owns any future server-side GLX extension; the Mesa repo owns the renderer, GL/GLU/GLUT libraries, demos, and client-side GLX/Xlib integration.

> Cross-note for this project (the Z3660 family): the R6.3 tree's `hw/amix/rtg/<card>/` seam plus the `/dev/zz9000`-style char-framebuffer contract (SETMODE/GETFBINFO/mmap) is exactly the shape a future **Z3660 RTG** pairing would slot into — kernel driver at a free major + a new card subdir under `rtg/`. (Planning observation, not a repo fact.)
