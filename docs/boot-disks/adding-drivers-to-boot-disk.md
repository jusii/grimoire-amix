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
| **(b) Custom bootable floppy** | install/recovery media that boots *your* kernel | ✅ boots in Amiberry (same kernel) · 🟡 driver-modified kernel untested |
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
| Make custom install/recovery media that boots your kernel | (b) `build-bootfloppy.sh` | ✅ boots in Amiberry |
| Distribute a driver for users to install | (c) `build-custom-bootdisk.sh` | ✅ host-verified · 🟡 emulator-test |

Recommended workflow regardless: **build and test the driver the manual way first** (relink into a live
system per [kernel-build](../drivers/kernel-build.md)) before automating any packaging.

## What's still open

The boot floppy format is solved (layout, `compress`/LZW kernel, `IBLK` descriptor, and the
folded-byte-sum checksum are all pinned) and a rebuilt floppy boots in Amiberry to the root-disk prompt;
these are the remaining loose ends, none blocking:

- 🟡 **Driver-modified kernel** end-to-end: the rebuild was verified with the *same* kernel; booting a
  floppy whose kernel was relinked with a new driver (needs a kernel built on Amix `/usr/sys`) is the
  next validation.
- 🟡 **Full install** through the tape stage needs A3000 SCSI/tape emulation (see
  [Amiberry status](../getting-started/emulation-amiberry.md)).
- 🔴 **Exact RDB partition type IDs** Amix uses (boot vs swap vs UFS) are undocumented — relevant only
  if you script creating a boot *partition* from scratch rather than letting the installer do it.

If you boot-test a rebuilt floppy, or pin the checksum, please contribute the result back.

## See also
- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) — how the format was cracked.
- [Building & installing a kernel](../drivers/kernel-build.md) — the relink all three surfaces share.
- [Anatomy of the boot ADF](anatomy-boot-adf.md) / [patch ADF](anatomy-patch-adf.md) — the formats built here.
- [The build pipeline](build-pipeline.md) — the `tools/` end-to-end.
- [VA2000 case study](../drivers/case-studies/va2000.md) · [Hydra case study](../drivers/case-studies/hydra.md).

## Sources
- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) and research brief §3, §10, §13
  ([`../../sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md)): the `compress`/LZW kernel at
  `0x2800` → m68k ELF, the 16-bit folded **non-fatal** checksum (bootstrap disassembly), and the
  host-verified round-trip via `tools/extract-kernel.sh` + `tools/build-bootfloppy.sh`.
- Kernel relink flow (`/usr/sys` → `make force` / `relocunix` → `make bootpart`; keep old `/unix`) —
  Ditto paper; research brief §3, §5, §6.
- Patch-disk self-extraction model — `amix_21_patch.adf` analysis; research brief §10;
  [`tools/build-custom-bootdisk.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-custom-bootdisk.sh).
- VA2000 / Hydra driver-install procedures — research brief §6; repos
  [`github.com/asokero/va2000-amix`](https://github.com/asokero/va2000-amix),
  [`github.com/isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix).
- Install media (user-supplied): [amigaunix.com](https://www.amigaunix.com/doku.php/downloads) ·
  [archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix).
