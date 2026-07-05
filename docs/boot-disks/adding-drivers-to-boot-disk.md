---
title: Adding Drivers to a Custom Boot Disk
summary: Three ways to ship extra hardware drivers — relink the on-HD boot partition, rebuild a custom bootable floppy, or ship a self-extracting add-on disk — and exactly how tractable each is.
status: draft
---

# Adding Drivers to a Custom Boot Disk

If you want an extra hardware driver available on an Amix machine, there are **three delivery surfaces**.
All three are now tractable — an update from this project's first draft, where the bootable-floppy path
was an open reverse-engineering problem. It is now solved (see
[Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md)).

| Surface | Use it for | Status |
|---|---|---|
| **(a) On-HD boot partition** | adding a driver to an already-installed system | ✅ supported, normal kernel rebuild |
| **(b) Custom bootable floppy** | install/recovery media that boots *your* kernel | ✅ boots in Amiberry (same kernel) · ✅ a **driver-modified** kernel boots + runs a **full install** (WinUAE) |
| **(c) Self-extracting add-on disk** | *distributing* a driver to other users to install | ✅ host-verified · 🟡 not yet run on real Amix |

A driver in Amix is **statically linked into a monolithic kernel — there are no loadable modules** ✅, so
every path below ultimately means "relink the kernel with your driver, then deliver that kernel." The
relink is the same in all three; they differ only in packaging.

This is the strategy/decision page. The mechanics live in:

- [Building & installing a kernel](../drivers/kernel-build.md) — the `/usr/sys` relink (the shared core).
- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) — how the floppy format was decoded.
- [Anatomy of the boot ADF](anatomy-boot-adf.md) / [patch ADF](anatomy-patch-adf.md) — the formats we build.
- [The build pipeline](build-pipeline.md) — the `tools/` end-to-end.

## The shared core: relink the kernel ✅

Run on a live 2.1 system as root ([full procedure](../drivers/kernel-build.md)):

```sh
cd /usr/sys
# 1. put your driver .o in its subdir + that subdir's Makefile, and register it in
#    master.d/kernel.c (cdevsw[]/bdevsw[], int2_tbl[], io_init[]).
rm -f amiga/config/unix.o master.d/exp unix     # drop stale objects
make                                            # -> relocunix (an m68k ELF)
```

You now have a relinked kernel (`relocunix`). The three surfaces below each take it from here.

> The kernel image is `relocunix` on 2.1 systems and in the modern repos; the 1990 Ditto paper calls it
> `rdbunix` — a historical rename, match what your version produces. 🟡 Amix `/bin/sh` is **pre-POSIX**
> (no `$(...)`, no `grep -q`) ✅ — script the `kernel.c` edits with backticks. The
> [VA2000 case study](../drivers/case-studies/va2000.md) is a complete worked patch set.

## Surface (a): the on-HD boot partition — for an installed system ✅

If the machine already boots Amix, you do **not** need any custom floppy. Stage the relinked kernel and
let `make bootpart` write it into the 2 MB boot partition:

```sh
cp relocunix /stand
make bootpart KERNEL=relocunix     # writes the boot partition from the staged kernel
mknod /dev/<name> c <major> <minor>
shutdown -i6                       # reboot
```

`make bootpart` is the supported tool that emits the compressed+checksummed boot payload for you ✅.
**Always keep the old `/unix` / boot kernel as a fallback** — a bad relink can leave the machine
unbootable; the Ditto paper makes this explicit ✅. A STREAMS/network driver builds the same way —
natively, `make` in the driver dir then `make force` to relink (`elf2brel` converts the kernel to
boot format in the process); see the [Hydra case study](../drivers/case-studies/hydra.md).

### Installing a kernel into the Amix boot partition ✅

What `make bootpart` actually does, and how to do it by hand for a *different* disk — verified
first-party on Amix 2.1c (the A4091 work used this exact pipeline to install a driver-modified
kernel onto a separate boot disk).

The full install flow from `/usr/sys` is two stages ✅:

```sh
cd /usr/sys
make install          # stages the linked kernel to /stand (preserves the old one as /stand/OLDunix)
cd /stand
make bootpart         # writes the boot payload into BOOTPART (default /dev/dsk/c6d0s3)
```

`make bootpart` `dd`s a **concatenated five-part image** to the boot partition ✅ — each file
preceded by its own **`IBLK` infoblock**:

```sh
# what `make bootpart` does, expanded (BOOTPART = /dev/dsk/c6d0s3 by default):
( cat boot1.boot; ./makeiblk boot2.boot; cat boot2.boot; ./makeiblk unix; cat unix ) \
  | dd conv=sync of=/dev/dsk/c6d0s3
```

`makeiblk` is the **same `IBLK` infoblock tool** that the boot-floppy format is built from — the
512-byte `struct infoblock` (magic `IBLK`, compressed/decompressed lengths, checksum) that precedes
each file the bootstrap loads. See
[Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md#the-iblk-descriptor-and-the-overrun-trap)
for the on-disk descriptor layout and the SVR4-`sum` checksum it carries. (On the boot partition the
kernel is stored **uncompressed**; on the boot *floppy* it is `compress`'d. The `IBLK` framing is the
same; only the payload differs.) ✅

#### Targeting a *different* disk's boot partition ✅

`make install` always writes **whatever disk the box booted from** (it resolves `BOOTPART` to the
running root's boot slice — `c6d0s3`). To install a kernel onto **another** disk's boot partition —
for example an A4091 disk mounted as card 1, whose boot slice is `c8d0s3` — run the pipeline **by
hand** and never plain `make install` ✅:

```sh
cd /stand
( cat boot1.boot; ./makeiblk boot2.boot; cat boot2.boot; ./makeiblk unix; cat unix ) \
  | dd conv=sync of=/dev/dsk/c8d0s3
```

This is exactly the trick used to build an A4091-bootable disk from a separate A3000 build host: the
build environment mounts both disks, links the kernel against the A3000 root, then writes the
*A4091* disk's boot slice (`c8d0s3`) by hand. (`c8` = card 1, target 0; `c6` = card 0, target 6 —
see the [A4091/53C710 driver](../drivers/a4091-53c710-driver.md) for the SCSI `cN` device-numbering
scheme.) Plain `make install` here would have rewritten the *build host's* own boot partition. ✅

#### ✅ Safety rule: never `make install` an unverified kernel onto your working disk

`make install` / `make bootpart` **rewrites the boot partition in place**. If the kernel you install
is corrupt, the next boot **bricks that disk** — the bootstrap relocator chokes and you get a
`D245 4C41` Guru with no usable system. This is not hypothetical: the Amix kernel link suffers an
intermittent (~70%) `ld` write-corruption that produces exactly such a kernel. Three rules ✅:

1. **Always clean-gate the build** — relink until the kernel checksum recurs, which proves a clean
   `ld` output, before you install it. See the
   [D245 boot-breaker and the build-until-stable clean-gate](../drivers/kernel-build.md) on the
   kernel-build page (and [`tools/build-clean-kernel.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-clean-kernel.sh)).
2. **Keep a backup HDF** of your working disk before any boot-partition write — recovery is a file
   copy, not a reinstall.
3. **Install onto a throwaway / clone disk**, not your daily driver — use the by-hand `c8d0s3`
   pipeline above to target the clone, never `make install`.

Never `make install` a test or diagnostic kernel (one with `printf` tracing, a half-finished driver,
an unverified link) onto the disk you actually rely on. ✅

## Surface (b): a custom bootable floppy — solved ✅🟡

The boot floppy is no longer a black box. From the [reverse-engineering writeup](reverse-engineering-boot-adf.md):

- The kernel is a **standard Unix `compress` (`.Z`, LZW `-b16`) stream at offset `0x2800`** that
  decompresses to an m68k ELF. ✅
- The "Kernel file checksum" is a 16-bit folded sum, and **a mismatch is non-fatal** — the bootstrap
  prints `WARNING! Kernel file checksum mismatch.` and **boots anyway**. ✅

A custom bootable floppy is: **donor bootblock+bootstrap + your `compress`'d kernel + zero pad**, with
the bootstrap's **`IBLK` descriptor** (`0x2600`: compressed length, decompressed size, checksum)
rewritten to describe *your* stream. [`tools/build-bootfloppy.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-bootfloppy.sh) does
all of that (and self-tests via the descriptor):

```sh
tools/extract-kernel.sh   amix_2.1_boot.adf  unix.elf        # (optional) pull the stock kernel
# ... relink unix.elf with your driver via /usr/sys, or supply your own kernel ELF ...
tools/build-bootfloppy.sh --donor amix_2.1_boot.adf --kernel unix.elf --out custom_boot.adf
```

What you get and what to watch:

- ✅ The donor's first `0x2800` bytes (bootblock + bootstrap) are copied **verbatim**, so the AmigaDOS
  bootblock checksum stays valid and the ROM still boots it.
- ✅ The build **self-tests**: it confirms the floppy decompresses back to the exact kernel you supplied.
- 🟡 Your kernel must fit **compressed** within `880 KB − 0x2800` (≈ 868 KB of `.Z`). The stock kernel
  compresses to ~668 KB, leaving headroom for a driver or two.
- ✅ The tool **patches `IBLK`** (`comp_len`, `decomp_size`, and `checksum` = folded byte-sum of your
  `.Z`), so it loads with **no overrun and no checksum warning**. *(A naive rebuild that leaves `IBLK`
  stale fails with `WARNING! Kernel decompression overrun.` — the bootstrap reads the old, longer length
  and decodes your zero-padding. Don't do that; the tool handles it.)*
- ⚠️ **The kernel you supply must be in `elf2brel` "brel" boot format (`e_type=0xff00`, ET_LOPROC), NOT
  the raw `ld -r` ET_REL (`e_type=0x1`).** Framing a raw ET_REL Guru's with **`D245 4C41`** during
  bootstrap relocation (the loader consumes the compact `.rel.boot` table `elf2brel` builds, not standard
  ELF relocations). On a native on-box `make`, `elf2brel` runs automatically; a **cross-built** kernel
  must pass through `elf2brel` **explicitly** first (there is a host Python port,
  `amix-kerntools/tools/elf2brel.py`, mirroring `amiga/boot/elf2brel.c`). `build-bootfloppy.sh` does
  **not** run `elf2brel` — it only ever worked because it re-framed the already-brel *donor* kernel. ✅
  (Proven 2026-07-05: a raw-ET_REL floppy `D245`'d; re-framing the brel booted and ran a full install.)
- ✅ **Verified in an emulator (Amiberry):** a rebuilt floppy boots and reaches the original's
  `Insert floppy disk 2 (root file system)` prompt. Still worth verifying your own builds in
  [WinUAE](../getting-started/emulation-winuae.md) / [FS-UAE](../getting-started/emulation-fs-uae.md).

## Surface (c): a self-extracting add-on disk — to distribute a driver ✅🟡

To *ship* a driver to other users (who already run Amix), the cleanest vehicle is a **self-extracting
disk modeled on the real Amix 2.1 patch disk** ([fully decoded](anatomy-patch-adf.md)): a ≤1 KB
`/sbin/sh` header followed by an SVR4 `cpio` archive. The header extracts the payload into the
filesystem and runs your installer, which does the surface-(a) relink on the user's machine.

The real patch disk's self-extraction idiom ✅:

```sh
QUIETDD=y dd if="$0" bs=1k iseek=1 2>/dev/null | (cd /; QUIETCPIO=y cpio -icdmuv)
uncompress -f /var/patch/*.Z
exec /var/patch/apply
```

Build one with [`tools/build-custom-bootdisk.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-custom-bootdisk.sh):

```sh
tools/build-custom-bootdisk.sh --payload ./payload --out my-driver-addon.adf --install var/addon/install
```

Lay out `./payload` so it extracts under `/` (e.g. `var/addon/install` for the installer plus your
driver source/`.o`); keep the installer **pre-POSIX-shell-safe** and the header **under 1024 bytes** ✅.
This disk runs *on* an already-booted Amix — it is not itself bootable.

## Which surface should I use?

| Goal | Use | Status |
|---|---|---|
| Add a driver to a running system | (a) relink + `make bootpart` | ✅ works |
| Make custom install/recovery media that boots your kernel | (b) `build-bootfloppy.sh` | ✅ driver kernel boots + full install (WinUAE) |
| Distribute a driver for users to install | (c) `build-custom-bootdisk.sh` | ✅ host-verified · 🟡 emulator-test |

Recommended workflow regardless: **build and test the driver the manual way first** (relink into a live
system per [kernel-build](../drivers/kernel-build.md)) before automating any packaging.

## What's still open

The boot floppy format is solved (layout, `compress`/LZW kernel, `IBLK` descriptor, and the
folded-byte-sum checksum are all pinned) and a rebuilt floppy boots in Amiberry to the root-disk prompt;
these are the remaining loose ends, none blocking:

- ✅ **Driver-modified kernel** end-to-end (WinUAE, 2026-07-05): a floppy whose kernel was relinked with
  new drivers (a4091 + z3660scsi, cross-built on the host and `elf2brel`'d) boots and runs a **full Amix
  install** from tape to disk; the laid-down system then boots from the disk into first-boot config. This
  closes the long-standing "next validation." (The install/floppy kernel carried the drivers; making the
  *installed* system's boot-partition kernel carry them is a further step — see the install-media project.)
- ✅ **Full install** through the tape stage: done under WinUAE. Note the emulator specifics — the install
  **target disk must be on the A3000 onboard SCSI**, not the a4091 (WinUAE emulates a4091 **tapes** but
  not a4091 hard disks), and the tape (ID 4) must sit on the **same controller / card 0** as the disk
  (the `/dev/rmt/4hn` device routes to card 0). See [the WinUAE setup](../getting-started/emulation-winuae.md).
- ✅ **RDB partition type IDs** Amix uses are now known — read from the installer (`/etc/rdb -F`): boot
  `0x554e4900` (`UNI\0`), UNIX root `0x554e4901` (`UNI\1`), swap `0x72657376` (`resv`); see
  [the boot process](../how-it-works/boot-process.md) and
  [root floppy anatomy](anatomy-root-adf.md#rdb-partition-type-tags). Relevant if you script creating a
  boot *partition* from scratch rather than letting the installer do it.

If you boot-test a rebuilt floppy, or pin the checksum, please contribute the result back.

## See also
- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) — how the format was cracked.
- [Building & installing a kernel](../drivers/kernel-build.md) — the relink all three surfaces share.
- [Anatomy of the boot ADF](anatomy-boot-adf.md) / [patch ADF](anatomy-patch-adf.md) — the formats built here.
- [The build pipeline](build-pipeline.md) — the `tools/` end-to-end.
- [The A4091/53C710 driver](../drivers/a4091-53c710-driver.md) — the SCSI `cN` device-numbering scheme
  and a worked case of installing a driver kernel onto a separate boot disk via `c8d0s3`.
- [VA2000 case study](../drivers/case-studies/va2000.md) · [Hydra case study](../drivers/case-studies/hydra.md).

## Sources
- **Driver-modified-kernel full install + the `elf2brel`/brel requirement** (2026-07-05, live under WinUAE):
  a host-cross-linked universal kernel (a4091 + z3660scsi), `elf2brel`'d to brel (`e_type=0xff00`) and framed
  with `build-bootfloppy.sh`, boots and drives the Amiga UNIX installer through a full install (partition →
  format → read tape → install all package sets → laid-down system boots). Framing a raw `ld -r` ET_REL
  (`e_type=0x1`) instead Guru's `D245 4C41` at relocation. From `amix-kerntools/tools/elf2brel.py` (port of
  `amiga/boot/elf2brel.c`) + `amix-installng/tools/build-universal-bootfloppy.sh`.
- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) and research brief §3, §10, §13
  ([`../../sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md)): the `compress`/LZW kernel at
  `0x2800` → m68k ELF, the 16-bit folded **non-fatal** checksum (bootstrap disassembly), and the
  host-verified round-trip via `tools/extract-kernel.sh` + `tools/build-bootfloppy.sh`.
- Kernel relink flow (`/usr/sys` → `make force` / `relocunix` → `make bootpart`; keep old `/unix`) —
  Ditto paper; research brief §3, §5, §6.
- **Installing a kernel into the boot partition** (the `make install` → `cd /stand; make bootpart`
  flow; the five-part `boot1 + makeiblk(boot2) + boot2 + makeiblk(unix) + unix` `dd` to
  BOOTPART = `/dev/dsk/c6d0s3`; the by-hand `c8d0s3` pipeline for a *different* disk; the
  "never `make install` an unverified kernel" safety rule) — The A4091-on-Amix project,
  `NOTES.md` §11 (build/install flow), §16 + §18 (boot-partition write bricks a disk; D245 `ld`
  corruption), §19 (the by-hand `c8d0s3` install onto a separate disk) — reproduced locally ✅;
  handoff §8;
  [`tools/build-clean-kernel.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-clean-kernel.sh)
  is the clean-gate that proves a kernel safe to install.
- Patch-disk self-extraction model — `amix_21_patch.adf` analysis; research brief §10;
  [`tools/build-custom-bootdisk.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-custom-bootdisk.sh).
- VA2000 / Hydra driver-install procedures — research brief §6; repos
  [`github.com/asokero/va2000-amix`](https://github.com/asokero/va2000-amix),
  [`github.com/isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix).
- Install media (user-supplied): [amigaunix.com](https://www.amigaunix.com/doku.php/downloads) ·
  [archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix).
