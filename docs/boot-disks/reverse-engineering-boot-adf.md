---
title: Reverse-Engineering the Boot Floppy
summary: How the Amix boot.adf kernel container was decoded — layout, the Unix-compress kernel, the non-fatal checksum — and how to rebuild a custom bootable floppy.
status: reviewed
---

# Reverse-Engineering the Boot Floppy

The Amix install/boot floppy (`boot.adf`) was, in this project's first draft, an open problem: its kernel
was "compressed and checksummed in a raw bootstrap with no AmigaDOS filesystem," format unknown. **That
is now solved.** This page documents the analysis, the evidence, and the practical upshot: you can build
a custom bootable Amix floppy carrying your own kernel.

All findings here were produced by analysing a real `amix_21_boot.adf` (SHA-256 in
[`../../sources/CHECKSUMS.txt`](../../sources/CHECKSUMS.txt)) with `tools/inspect-adf.sh`, entropy
mapping, LZW decompression, and capstone M68K disassembly of the bootstrap. They are reproducible with
the tools in [`../../tools/`](../../tools/) on your own copy of the image.

## TL;DR

- The kernel is stored as a **standard Unix `compress` (`.Z`, LZW, 16-bit, block mode)** stream at file
  offset **`0x2800`**. ✅ It decompresses to a **1,171,200-byte m68k ELF** kernel.
- The "kernel file checksum" is a **16-bit folded ones-complement sum**, and a mismatch is
  **non-fatal — the bootstrap prints a warning and boots anyway.** ✅
- Therefore a custom bootable floppy = **`[donor bootblock+bootstrap] + [compress -b16 your-kernel.elf] + [zero pad to 880 KB]`**, built by [`build-bootfloppy.sh`](../../tools/build-bootfloppy.sh). ✅ host-verified; 🟡 not yet booted on real Amix.

## Disk layout (880 KB / 901,120-byte image) ✅

| Range | Size | Contents |
|---|---|---|
| `0x000000`–`0x000400` | 1 KB | **AmigaDOS OFS bootblock** — `44 4f 53 00` (`DOS\0`) + checksum + start of bootstrap. The bootblock checksum **verifies to 0** (valid), so the Kickstart ROM boots it. |
| `0x000400`–`0x002800` | ~9 KB | **Secondary bootstrap** — a4-relative compiled C using exec/DOS libraries; contains the LZW decompressor and the boot messages. |
| `0x002800`–≈`0xa5c00` | ~668 KB | **Kernel**, as a Unix `compress` `.Z` stream (`1f 9d`, flags `0x90`). Decompresses to a 1,171,200-byte ELF. |
| ≈`0xa5c00`–`0x0dc000` | ~220 KB | **Slack / free space** — fragments of the same kernel plus ~30% zeros. Not used by boot. |

There is **no AmigaDOS filesystem** on the disk: `xdftool list` fails with `Invalid Root Block @880`.
The disk is bootblock + raw bootstrap + raw payload, located by offset, not by file.

## Step 1 — find the structure (entropy + magic)

An entropy map (1 KB blocks) shows a low-entropy bootstrap (`0x0`–`0x2800`), then a long high-entropy
region (compressed), then a lower-entropy tail (uncompressed slack). A magic-byte scan finds the Unix
`compress` signature exactly at the bootstrap/payload boundary:

```text
offset 0x2800:  1f 9d 90 ...
                ^^^^^      = compress(.Z) magic
                      ^^   = 0x90 = block-mode (bit7) + 16-bit maxbits (0x10)
```

This was the key clue: `1f 9d` is **not** a custom format — it is `compress(1)`, ubiquitous on SVR4.

## Step 2 — decompress the kernel ✅

Feeding the bytes from `0x2800` to any standard `.Z` decoder yields an ELF:

```sh
dd if=amix_2.1_boot.adf bs=1 skip=$((0x2800)) | gzip -dc | head -c4 | xxd
# 00000000: 7f45 4c46                                .ELF
file <(dd if=amix_2.1_boot.adf bs=1 skip=$((0x2800)) | gzip -dc)
#   ELF 32-bit MSB processor-specific, Motorola m68k, 68020, version 1 (SYSV)
```

The real ELF size is recovered from its own header (`e_shoff + e_shnum*e_shentsize` =
`0x11de60 + 4*0x28` = **1,171,200**), which is how [`extract-kernel.sh`](../../tools/extract-kernel.sh)
trims the trailing slack. Use it directly:

```sh
tools/extract-kernel.sh amix_2.1_boot.adf unix.elf
```

## Step 3 — confirm the decompressor in the bootstrap

Disassembling the bootstrap (capstone, M68K, big-endian) shows the canonical `compress` reader, which
removes any doubt that this is standard LZW:

- A `rmask[]` table — `00 01 03 07 0f 1f 3f 7f ff` — written into the work struct at `$840(a2)`
  (the exact bit-mask table from `compress.c`).
- A `getcode` routine that reads the header and checks the first two bytes are `0x1f`, `0x9d`
  (around file offset `0x1782`).

## Step 4 — the checksum (and why it doesn't stop you) ✅

After decompression the bootstrap verifies a checksum. The relevant code (file offsets):

```text
0bcc: move.l $c(a2),d2        ; d2 = 32-bit accumulator
0bd0: lsr.l  #16,d2           ; d2 = acc >> 16
0bd4: move.l $c(a0),d0
0bd8: andi.l #$ffff,d0        ; d0 = acc & 0xffff
0bde: add.l  d0,d2            ; fold: hi + lo
0bec: move.l d2,d0 ; lsr #16  ; fold again -> 16-bit value
0bf8: add.l  d2,d0
0c0e: move.l $c(a0),d1
0c12: cmp.l  $10(a3),d1       ; compare to EXPECTED (a disk descriptor field)
0c16: beq.w  $c48             ; equal -> continue
0c1a: ...print "WARNING! Kernel file checksum mismatch. / Expected %x, found %x."
0c48: ...                     ; <-- the mismatch path FALLS THROUGH to here (== the match path)
```

So the checksum is a **16-bit folded ones-complement sum**, compared against an *expected* value carried
in a disk descriptor. **Crucially, the mismatch branch only prints a warning and falls through to the
same continuation (`0x0c48`) as the success path** — a checksum mismatch is **non-fatal**. A custom
kernel boots even with a "wrong" checksum; you just see the warning.

🟡 **Still open:** the exact byte-range summed and the on-disk location of the *expected* value are not
pinned (candidate folds of the kernel and of the `.Z` did not match a value stored in the bootstrap).
Pinning them would let a rebuilt floppy boot with no warning at all. This is a nice-to-have, not a blocker.

## Step 5 — rebuild and round-trip ✅

Re-compressing the extracted kernel with standard `compress -b 16` produces a `.Z` that decompresses to
the **byte-identical** kernel (the encoder differs from the original by a handful of bytes, but `.Z`
decoding is canonical, so the bootstrap will accept it). [`build-bootfloppy.sh`](../../tools/build-bootfloppy.sh)
assembles a complete image and self-tests it:

```sh
# pull the kernel, (optionally relink it with your driver), then rebuild a floppy:
tools/extract-kernel.sh   amix_2.1_boot.adf  unix.elf
tools/build-bootfloppy.sh --donor amix_2.1_boot.adf --kernel unix.elf --out custom_boot.adf
#   donor bootblock+bootstrap: 0x0..0x2800 (10240 bytes)
#   kernel ... -> compress -b16 = ... bytes
#   self-test: floppy decompresses to the IDENTICAL kernel ✅
```

The donor's first `0x2800` bytes are copied **verbatim**, so the AmigaDOS bootblock checksum stays valid.

## What this unlocks — and the honest caveats

- ✅ **Extract** the kernel from any `boot.adf` → ELF.
- ✅ **Rebuild** a bootable floppy from a donor bootstrap + any (same-size-or-smaller) kernel ELF; the
  whole pipeline round-trips on the host.
- ✅ Custom **kernels boot despite the checksum** (cosmetic warning only).
- 🟡 **Not yet booted on real Amix.** Verify any rebuilt floppy in
  [WinUAE](../getting-started/emulation-winuae.md) / [FS-UAE](../getting-started/emulation-fs-uae.md)
  before trusting it. The kernel must still fit (compressed) in `880 KB − 0x2800`.
- 🟡 To boot with **no** checksum warning, the summed range + expected-value location need pinning
  (see Step 4). Dynamic analysis under an emulator is the obvious next step.

For the broader "add a driver to a boot disk" decision (this vs. relinking the on-HD boot partition),
see [Adding Drivers to a Custom Boot Disk](adding-drivers-to-boot-disk.md).

## See also
- [Anatomy of the Boot Floppy](anatomy-boot-adf.md) — the byte-level breakdown this page is built on.
- [Adding Drivers to a Custom Boot Disk](adding-drivers-to-boot-disk.md) — the two delivery surfaces.
- [The Boot-Disk Tooling Pipeline](build-pipeline.md) — all the `tools/` scripts.
- [Building & installing a kernel](../drivers/kernel-build.md) — producing the kernel you compress.

## Sources
- Primary analysis of `amix_21_boot.adf` (2026-06): `tools/inspect-adf.sh`, entropy mapping, `gzip`/`zcat`
  LZW decompression, capstone M68K disassembly; round-trip via `tools/extract-kernel.sh` +
  `tools/build-bootfloppy.sh`. Recorded in the research brief §3, §10, §13 — [`../../sources/research-brief.md`](../../sources/research-brief.md).
- Unix `compress`/`.Z` LZW format (magic `1f 9d`, flags byte = block-mode | maxbits).
- ELF32 header fields for size recovery (`e_shoff`, `e_shnum`, `e_shentsize`).
