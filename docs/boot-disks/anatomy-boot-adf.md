---
title: Anatomy of the Boot Floppy
summary: What is inside amix boot.adf — an AmigaDOS OFS bootblock, a 68k secondary bootstrap, and the kernel stored as a Unix compress (.Z, LZW) stream that unpacks to an m68k ELF (no AmigaDOS filesystem).
status: reviewed
---

# Anatomy of the Boot Floppy

`amix_21_boot.adf` is a standard 880 KB Amiga floppy image whose job is to get a UNIX kernel running on a bare 68030 Amiga. It does this with three layers and **nothing else**: an AmigaDOS **OFS bootblock** so the Kickstart ROM will load it ✅, a small **68k secondary bootstrap** ✅, and a **compressed, checksummed install kernel** with NFS/RPC support ✅. There is **no AmigaDOS filesystem on the disk** ✅ — it is bootblock + raw bootstrap + payload, so tools like `xdftool` that expect a directory tree will fail.

If you want the runtime story (Superkickstart → bootstrap → kernel → root miniroot), read [the boot process walkthrough](../how-it-works/boot-process.md). This page is about the *bytes on the floppy*.

> **Scope / confidence.** Everything below tagged ✅ is reproduced locally from the real image (`tools/inspect-adf.sh`); the brief's §3 and §10 cover the same evidence. The image itself is proprietary Commodore media and is **not** shipped with this repo — see [Where to get the image](#where-to-get-the-image).

## At a glance

| Property | Value | Tag |
|---|---|---|
| Image | `amix_21_boot.adf` | ✅ |
| Size | 901,120 bytes (= 880 KB Amiga DD floppy) | ✅ |
| SHA-256 | `0d8af1c06b524411cc43d33c4a156afe6216ec895f50188747d0f3a6bed65272` | ✅ |
| Disk type id (first 4 bytes) | `44 4f 53 00` = `DOS\0` (OFS bootblock) | ✅ |
| AmigaDOS filesystem? | **No** — `xdftool list` → "Invalid Root Block @880" | ✅ |
| Payload | kernel as a Unix `compress` `.Z` (LZW) stream at `0x2800` → **1,171,200-byte m68k ELF** (NFS/RPC-capable install kernel) | ✅ |
| Kernel checksum | `IBLK+0x10` = 16-bit folded byte-sum of the `.Z` stream; mismatch is non-fatal | ✅ |

## The three layers

```text
+--------------------------------------------------------------+
| Layer 0:  AmigaDOS OFS bootblock                             |
|           "DOS\0" magic + bootblock checksum + 68k boot code |  <- Kickstart ROM loads & runs this
+--------------------------------------------------------------+
| Layer 1:  Amix secondary bootstrap (68k machine code)        |
|           loads the payload, decompresses it, checksums it,   |  <- "Load boot volume %d", error strings
|           then jumps into the kernel                          |
+--------------------------------------------------------------+
| Layer 2:  kernel as a Unix compress (.Z, LZW) stream @0x2800  |
|           -> unpacks to a 1,171,200-byte m68k ELF kernel      |  <- decode with extract-kernel.sh
+--------------------------------------------------------------+
```

There is no fourth layer: no FFS/OFS root block, no `lost+found`, no file table. The space between the bootblock and the end of the disk is the bootstrap plus the compressed kernel image.

### Layer 0 — the AmigaDOS OFS bootblock ✅

The first bytes of the disk are a normal Amiga bootblock so the Kickstart/Superkickstart ROM recognises the floppy as bootable. The magic `44 4f 53 00` (`DOS\0`) marks an **OFS** (Old File System) boot type, followed by a bootblock checksum and 68k bootstrap code. First 64 bytes, straight from the image:

```text
00000000: 444f 5300 cb55 b5e2 0000 0370 4857 2f09  DOS..U.....pHW/.
00000010: 61ff 0000 00be 504f 4a80 66ff 0000 000c  a.....POJ.f.....
00000020: 203c 8765 4321 4e75 2040 7000 4e75 4e71   <.eC!Nu @p.NuNq
00000030: 4e56 0000 48e7 2028 246e 0008 4878 0002  NV..H. ($n..Hx..
```

- `44 4f 53 00` — `DOS\0`, the AmigaDOS boot type id. The trailing `00` flag byte means plain OFS (no FFS / international / directory-cache bits set). The ROM uses this to decide the floppy is bootable. ✅
- `cb 55 b5 e2` — the **bootblock checksum**. The Amiga ROM sums the bootblock and refuses to run it on mismatch, so this value has to be correct for the disk to boot. ✅
- From offset `0x000C` on, it is **68k machine code** — the start of the boot logic that the ROM calls. (`4e75` = `RTS`, `4e56` = `LINK`, `48e7` = `MOVEM.L`, etc.) ✅

That is all the Amiga ROM needs: a valid `DOS\0` signature, a valid checksum, and code to jump into. The rest of the disk is opaque to AmigaOS.

> **Note (boot priority).** On a fully installed system the ROM boots from the SCSI hard disk (ID 6); this floppy is the path used at install time and as a recovery boot. Right-click at power-on drops you into AmigaOS Kickstart instead of Amix ✅. See [the boot process page](../how-it-works/boot-process.md) for the Superkickstart dual-boot detail.

### Layer 1 — the secondary bootstrap ✅

The bootblock code is the **secondary bootstrap**: it locates the kernel payload on the floppy, **decompresses** it into RAM, **verifies a checksum**, and transfers control to it. Its behaviour is visible in the embedded strings (these are the bootstrap's own messages, recovered with `strings`):

| String | What it tells us | Tag |
|---|---|---|
| `Load boot volume %d` | the bootstrap prompts for / reports the boot volume it is reading from | ✅ |
| `Decompression failed!` | the payload is compressed and the bootstrap decompresses it in place | ✅ |
| `WARNING! Kernel decompression overrun.` | bounds check on the decompressed size | ✅ |
| `WARNING! Kernel file checksum mismatch.` | the bootstrap verifies a 16-bit folded checksum — but a mismatch is **non-fatal** (it warns and boots anyway; see [the RE writeup](reverse-engineering-boot-adf.md)) | ✅ |
| `Kernel may have been corrupted.` | follow-on to a failed checksum / overrun | ✅ |
| `unix.` | the kernel name fragment the bootstrap is loading | ✅ |

So the load sequence is unambiguous from the strings alone: **read the boot volume → decompress the kernel → checksum it → run it**, with a guarded error path at every step. ✅

### Layer 2 — the kernel, as a Unix `compress` (`.Z`) stream ✅

The payload starting at file offset **`0x2800`** is the kernel, stored as a **standard Unix `compress`
(`.Z`, LZW) stream** — the same `compress(1)` format ubiquitous on SVR4. The header proves it:

```text
00002800: 1f 9d 90 ...
          ^^^^^      = compress(.Z) magic
                ^^   = 0x90 = block-mode (bit 7) + 16-bit maxbits (low 5 bits = 0x10)
```

Decompressing from `0x2800` with any standard decoder yields a **1,171,200-byte ELF**:

```sh
dd if=amix_21_boot.adf bs=1 skip=$((0x2800)) | gzip -dc | file -
#   /dev/stdin: ELF 32-bit MSB processor-specific, Motorola m68k, 68020, version 1 (SYSV)
```

This is **fully reverse-engineered** — both that the decoder accepts it *and* that the bootstrap's own
decompressor disassembles to the canonical `compress` reader (its `rmask[]` table and `1f`/`9d` magic
check). The complete method, disassembly evidence, and the rebuild recipe are in
[Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md). Extract it in one step:

```sh
tools/extract-kernel.sh amix_21_boot.adf unix.elf
```

> **About the earlier "binwalk noise".** `binwalk` does not flag a `.Z` stream and instead reports
> false-positive "JBOOT STAG header" hits with absurd sizes — that is just high-entropy LZW data
> tripping its heuristics, **not** evidence of a custom/opaque format. The format is plain `compress`.

Once decompressed, the kernel's own strings are plainly readable — a full **NFS/RPC client string
table** and an SVR4 **HAT/MMU panic message**, confirming this is the **install kernel** (it can mount a
root filesystem and pull the distribution over the network):

```text
hat_vtokp_prot: user addr in kernel space   <- SVR4 HAT (MMU) panic
RPC: Program/version mismatch
lock-manager: RPC error: %s
ip_input: bad header checksum
```

`hat_vtokp_prot` confirms the kernel drives the [68030 MMU via the SVR4 HAT layer](../how-it-works/kernel-architecture.md). ✅

**Why compressed?** An 880 KB floppy cannot hold a full uncompressed ~1.17 MB SVR4 kernel plus the
bootstrap. Compressing it (~668 KB) and decompressing at boot is how it fits — which is why
[the boot process](../how-it-works/boot-process.md) has a visible decompression step.

### Building a custom boot floppy ✅🟡

Because the format is `compress` → ELF and the checksum is non-fatal, you can build a bootable floppy
carrying **your own** kernel — splice your `compress -b16`'d kernel onto a donor's bootblock+bootstrap:

```sh
tools/build-bootfloppy.sh --donor amix_21_boot.adf --kernel my-unix.elf --out custom_boot.adf
```

The donor's first `0x2800` bytes are copied verbatim (bootblock checksum stays valid) **except** the
bootstrap's **`IBLK` descriptor** (at `0x2600`: compressed length, decompressed size, checksum), which
the tool rewrites to match your stream — so it loads with no overrun and no checksum warning. ✅
**verified booting in Amiberry** (reaches the original's root-disk prompt). See
[Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) and
[Adding Drivers to a Custom Boot Disk](adding-drivers-to-boot-disk.md).

## Inspecting it yourself

Use [`tools/inspect-adf.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/inspect-adf.sh) — it is read-only and never modifies the image. Point it at **your own** copy (see [below](#where-to-get-the-image)):

```sh
tools/inspect-adf.sh amix_21_boot.adf
```

It auto-detects the disk type from the first 12 bytes, dumps the bootblock, greps the kernel/bootstrap strings, runs `xdftool` (to *demonstrate* there is no FS), and runs `binwalk`. Abridged real output for the boot disk:

```text
== Amix ADF inspector ==
file : amix_21_boot.adf
size : 901120 bytes
       (901120 = standard 880 KB Amiga DD floppy)
sha256: 0d8af1c06b524411cc43d33c4a156afe6216ec895f50188747d0f3a6bed65272
detected disk type : boot
  -> bootable AmigaDOS bootblock; expect a compressed kernel payload, no AmigaDOS FS
[bootblock] DOS type id: 444f5300 (expect 444f5300 = 'DOS\0', OFS bootblock)
[xdftool] attempting AmigaDOS directory listing (expected to fail for boot/root):
    'list' FSError: Invalid Root Block(2):block=RootBlock:@880
[binwalk] embedded object signatures (first 30):
    695462  0xA9CA6  JBOOT STAG header, ... image size: 36219622 bytes ...
    780310  0xBE816  JBOOT STAG header, ... image size: 4110356480 bytes ...
    ...
```

If you only have base utilities, you can reproduce the key facts by hand:

```sh
# 1. Disk type id — should be 444f5300 ("DOS\0")
xxd -l 4 amix_21_boot.adf
#   00000000: 444f 5300  DOS.

# 2. Bootstrap / kernel strings
strings -n 6 amix_21_boot.adf | grep -iE 'boot volume|decompress|checksum|corrupt|RPC|hat_'

# 3. No AmigaDOS filesystem (amitools' xdftool) — this is SUPPOSED to fail
xdftool amix_21_boot.adf list
#   'list' FSError: Invalid Root Block(2):block=RootBlock:@880
```

### Reading the "Invalid Root Block @880" error correctly

`xdftool list` failing is **not** a sign of a bad image — it is the expected result and is itself diagnostic. AmigaOS expects a root block in the middle of the disk (block 880 on a DD floppy); this disk has compressed kernel data there instead of a filesystem, so amitools reports `Invalid Root Block @880`. A **healthy** Amix boot floppy produces exactly that error. If `xdftool` *succeeds* and lists files, you do not have an Amix boot disk. ✅

## How this disk is produced

This page documents the *finished* artifact. The companion [boot-disk build pipeline](build-pipeline.md) covers the producing side — and the same machinery underlies how a custom kernel gets onto bootable media on a real system. On an installed Amix box you build a kernel in `/usr/sys`, then `make bootpart KERNEL=relocunix` writes it to the boot partition ✅; the floppy is the equivalent self-contained, single-disk packaging of bootblock + bootstrap + compressed kernel. The Ditto paper calls the kernel image `rdbunix` (1990) while 2.1-era systems and the modern repos call it `relocunix` — a historical rename; verify per version 🟡.

## Relationship to the other install disks

The boot floppy is one of three in the Amix 2.1 install set, and the three are deliberately *different on disk*:

| Disk | On-disk structure | Detected by `inspect-adf.sh` as |
|---|---|---|
| **boot** (this page) | OFS bootblock + 68k bootstrap + compressed kernel; **no FS** | `boot` (first bytes `DOS\0`) |
| **root** | zeroed boot area + a **UFS miniroot** (installer ELF binaries + scripts) | `root` (`lost+found` fingerprint) |
| **patch** | ~1 KB `/sbin/sh` header + an embedded cpio archive | `patch` (first bytes `#!`) |

At install time the boot floppy's kernel comes up first, then you swap in the root floppy and its UFS miniroot takes over the installer. Continue with [the anatomy of the root floppy](anatomy-root-adf.md) and [the anatomy of the patch floppy](anatomy-patch-adf.md).

## Where to get the image

The Amix install floppies are **proprietary Commodore media** — treated as abandonware but **not licensed for redistribution**, so this repo never ships them. Obtain your own copy and verify by hash (filenames vary, e.g. `amix_2.1_boot.adf` vs `amix_21_boot.adf` — match on SHA-256, not name):

- amigaunix.com → Downloads: <https://www.amigaunix.com/doku.php/downloads>
- Internet Archive: <https://archive.org/details/commodore-amiga-operating-systems-amix>

Expected SHA-256: `0d8af1c06b524411cc43d33c4a156afe6216ec895f50188747d0f3a6bed65272` ✅ (see `sources/CHECKSUMS.txt`).

## See also

- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) — the full decode + rebuild method behind this page.
- [How Amix boots](../how-it-works/boot-process.md) — the runtime sequence this floppy kicks off.
- [The boot-disk build pipeline](build-pipeline.md) — producing bootable media + the `make bootpart` path.
- [Anatomy of the root floppy](anatomy-root-adf.md) — the UFS miniroot installer the boot kernel hands off to.
- [Anatomy of the patch floppy](anatomy-patch-adf.md) — the self-extracting patch disk (kernel 2.1c).
- [Adding drivers to a boot disk](adding-drivers-to-boot-disk.md) — getting a custom kernel onto bootable media.
- [Kernel architecture](../how-it-works/kernel-architecture.md) — the monolithic SVR4 kernel + HAT/MMU layer referenced in the strings.

## Sources

- `amix_21_boot.adf` analysis via [`tools/inspect-adf.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/inspect-adf.sh) — bootblock hex dump, `DOS\0` magic + checksum, bootstrap/kernel strings, `xdftool` "Invalid Root Block @880", binwalk false-positive "JBOOT" hits (reproduced locally; SHA-256 `0d8af1c0…65272`, see `sources/CHECKSUMS.txt`).
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §3 ("What the real boot.adf contains") and §10 ("boot.adf").
- amigaunix.com Downloads (image source): <https://www.amigaunix.com/doku.php/downloads>
- Internet Archive, *Commodore Amiga Operating Systems — AMIX*: <https://archive.org/details/commodore-amiga-operating-systems-amix>
