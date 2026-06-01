---
title: The Boot-Disk Tooling Pipeline
summary: What the tools/ scripts do — inspect, extract a kernel, rebuild a bootable floppy, unpack a miniroot, build an add-on disk, plus the prerequisites they need.
status: draft
---

# The Boot-Disk Tooling Pipeline

This page documents the scripts under `tools/` in this repository that work with Amix floppy images:
`inspect-adf.sh`, `extract-kernel.sh`, `build-bootfloppy.sh`, `unpack-root.sh`,
`build-custom-bootdisk.sh`, and `gen-llms-full.sh`. They cover analysis (inspect, unpack), the
now-solved [boot-floppy decode/rebuild](reverse-engineering-boot-adf.md) (extract a kernel, build a
bootable floppy), add-on-disk packaging, and LLM-corpus regeneration. **Every tool that touches a disk
image operates on a *user-supplied* image — none of them ship, contain, or require a copy of the
proprietary Amix media.** ✅

If you just want the end-to-end "I have a driver, how do I get it onto a disk" story, read
[adding drivers to a boot disk](adding-drivers-to-boot-disk.md) first; this page is the reference for
the underlying tooling.

> **Licensing — read this first.** The boot/root/patch ADFs and the driver PDF are proprietary
> Commodore material (abandonware, **not** licensed for redistribution). **Never commit them.** They
> are `.gitignore`d. Obtain them yourself from [amigaunix.com](https://www.amigaunix.com/doku.php/home)
> or archive.org, verify against `sources/CHECKSUMS.txt`, then point the tools at your local copy. The
> tools never bundle media; they read whatever path you give them. ✅

## At a glance

| Script | Status | What it does | Mutates input? | Writes to |
|---|---|---|---|---|
| `inspect-adf.sh` | ✅ done | Classify boot/root/patch; dump bootblock, embedded objects (ELF/cpio/tar), installer/bootstrap strings | No (read-only) | stdout |
| `extract-kernel.sh` | ✅ done | Decompress the `compress`/LZW kernel out of a `boot.adf` → m68k ELF (trimmed via ELF header) | No (read-only) | `<out>.elf` |
| `build-bootfloppy.sh` | ✅ boots in Amiberry | Build a **bootable** `boot.adf` = donor bootblock+bootstrap + `compress -b16` of your kernel + patched `IBLK`; self-tests via the descriptor | No (reads donor + kernel, writes new image) | `--out <image.adf>` |
| `unpack-root.sh` | ✅ done (carve-based) | Carve embedded objects out of a UFS miniroot; dump installer script text | No (read-only) | `tools/_work/<image>/` |
| `build-custom-bootdisk.sh` | ✅ host-verified · 🟡 not Amix-tested | Build a *self-extracting add-on* disk (1 KB `/sbin/sh` header + cpio payload), modeled on the real patch disk | No (reads a payload **dir**, writes a new image) | `--out <image.adf>` |
| `gen-llms-full.sh` | ✅ done | Concatenate all `docs/` pages into `llms-full.txt` | n/a | `llms-full.txt` |

`tools/_work/` is gitignored, so extraction scratch never ends up in a commit. ✅

## Required tools

The scripts prefer richer tools when present and degrade gracefully, but for full output you want:

| Tool | Used by | Why |
|---|---|---|
| `binwalk` | inspect, unpack | Find embedded ELF / cpio / tar / gzip signatures and their offsets |
| `xdftool` (from **amitools**) | inspect | Attempt an AmigaDOS directory listing (expected to *fail* on boot/root disks — see below) |
| `sha256sum` | inspect | Print the image checksum so you can match `sources/CHECKSUMS.txt` |
| `cpio` (newc) **or** `bsdtar` | build-custom-bootdisk, unpack | Build / list the SVR4 ASCII (newc) cpio archive |
| `gzip` / `zcat` / `uncompress` | extract-kernel, build-bootfloppy | Decode the Unix `compress` (`.Z`, LZW) kernel stream |
| `compress` (or `ncompress`) | build-bootfloppy | Pack a kernel ELF back into `.Z` (`-b 16`, block mode) |
| `od` (GNU) | extract-kernel, build-bootfloppy | Locate the `.Z` magic and read ELF size fields |
| `python3` | build-bootfloppy | Patch the `IBLK` descriptor (length/size/checksum) + descriptor-driven self-test |
| `dd`, `strings`, `xxd`, `wc`, `tar` | all | Carving, hex dumps, string scans, size math |

The authoritative, install-by-platform list lives in `tools/requirements.md` — consult it for exact
package names. If `binwalk` is missing, `inspect-adf.sh` falls back to grepping for the ELF magic
`7f454c46` by hand; `unpack-root.sh` hard-requires `binwalk` and exits with status `3` without it. ✅

## `inspect-adf.sh` — classify and structurally inspect a disk image

`inspect-adf.sh` is the entry point. It is **read-only** (it never modifies the image) and works on all
three install-set disk types. It detects the type from the first 12 bytes plus a UFS fingerprint, then
prints type-specific detail. ✅

```sh
tools/inspect-adf.sh sources/floppy/amix_21_boot.adf
```

### How it classifies

| Disk type | Detection rule | Source |
|---|---|---|
| **boot** | First bytes `44 4f 53` = `DOS` → AmigaDOS bootblock | head hex `444f53*` |
| **patch** | First bytes `23 21` = `#!` → shell-script header | head hex `2321*` |
| **root** | No bootblock; `strings` contains `lost+found` (UFS fingerprint) | string scan |

These map directly to the brief's findings: the boot disk is an OFS bootblock (`DOS\0`) + compressed
kernel with **no AmigaDOS filesystem**, the root disk is a zeroed-boot-area UFS miniroot, and the patch
disk starts with a `#!/sbin/sh` self-extracting header. ✅ See
[boot.adf anatomy](anatomy-boot-adf.md), [root.adf anatomy](anatomy-root-adf.md), and
[patch.adf anatomy](anatomy-patch-adf.md) for the full decode of each.

### Output shape

The script prints a fixed sequence of rule-separated sections. A boot-disk run produces, in order:

```text
== Amix ADF inspector ==
file : sources/floppy/amix_21_boot.adf
size : 901120 bytes
       (901120 = standard 880 KB Amiga DD floppy)
sha256: <64 hex chars — compare to sources/CHECKSUMS.txt>
------------------------------------------------------------------------
detected disk type : boot
  -> bootable AmigaDOS bootblock; expect a compressed kernel payload, no AmigaDOS FS
------------------------------------------------------------------------
[bootblock] first 64 bytes:
<xxd hex+ASCII dump>
[bootblock] DOS type id: 444f5300 (expect 444f5300 = 'DOS\0', OFS bootblock)
[boot] kernel/bootstrap strings of interest:
    Decompression failed!
    Kernel may have been corrupted.
    Load boot volume %d
    WARNING! Kernel decompression overrun.
    WARNING! Kernel file checksum mismatch.
    ...
------------------------------------------------------------------------
[xdftool] attempting AmigaDOS directory listing (expected to fail for boot/root):
    <xdftool error, e.g. "Invalid Root Block @880">
------------------------------------------------------------------------
[binwalk] embedded object signatures (first 30):
    <binwalk table; on boot.adf mostly noise / false-positive hits — kernel is compressed>
------------------------------------------------------------------------
done.
```

Notes that match the brief:

- **`xdftool list` is *expected* to fail** on boot and root disks — there is no AmigaDOS filesystem to
  list. On boot.adf it reports `Invalid Root Block @880`; on root.adf, `Invalid Boot Block @0`. A clean
  listing would mean you handed it the wrong kind of image. ✅
- On **boot.adf**, binwalk reports only noise / false-positive `JBOOT` hits because it doesn't flag a
  `.Z` stream — but the kernel **is** a standard Unix `compress` (LZW) stream at `0x2800`; decode it with
  `extract-kernel.sh`. See [the RE writeup](reverse-engineering-boot-adf.md). ✅
- On **root.adf**, the `[root]` section greps for the installer/tape-pipeline strings
  (`/dev/rmt`, `cpio`, `amixpkg`, `BOOTSIZE`, `/dev/dsk`, `mkfs`, `fsck`, `ufs`, `viper`). ✅
- On **patch.adf**, the `[patch]` section prints the leading ~1 KB `/sbin/sh` bootstrap and the cpio
  member names (`var/patch/...`). ✅

**Exit status:** `0` success, `2` usage error (no image given), `3` if the file is unreadable. ✅

## `extract-kernel.sh` — pull the kernel out of a boot floppy ✅

`extract-kernel.sh` decodes the [boot floppy's `compress`/LZW kernel](reverse-engineering-boot-adf.md)
into a plain m68k ELF. It finds the `1f 9d` (`.Z`) magic after the bootstrap, decompresses to EOF, and
trims the result to the true ELF size (`e_shoff + e_shnum*e_shentsize`). Read-only on input.

```sh
tools/extract-kernel.sh amix_2.1_boot.adf unix.elf
#   compressed kernel (.Z) found at offset 0x2800
#   wrote unix.elf
#     ELF: 32-bit MSB m68k; size 1171200 bytes (0x11df00)  [e_shoff=0x11de60 e_shnum=4]
```

**Requires:** `dd`, `od` (GNU), and one of `gzip` / `zcat` / `uncompress`.

## `build-bootfloppy.sh` — rebuild a bootable floppy with your kernel ✅🟡

`build-bootfloppy.sh` produces a **bootable** `boot.adf` carrying your own kernel, by reusing a donor
floppy's bootblock+bootstrap (first `0x2800` bytes, copied verbatim so the bootblock checksum stays
valid) and replacing the compressed kernel with `compress -b16` of your ELF.

```sh
tools/build-bootfloppy.sh --donor amix_2.1_boot.adf --kernel unix.elf --out custom_boot.adf
#   donor bootblock+bootstrap: 0x0..0x2800 (10240 bytes)
#   kernel ... -> compress -b16 = ... bytes
#   self-test: floppy decompresses to the IDENTICAL kernel ✅
```

It **rewrites the bootstrap's `IBLK` descriptor** (`0x2600`: compressed length, decompressed size, and
checksum = folded byte-sum of the `.Z`) to match your stream — so the boot has no overrun and no
checksum warning — then **self-tests** by decompressing per the patched descriptor and comparing to your
kernel. Your kernel must fit *compressed* in `880 KB − 0x2800`. ✅ **verified booting in Amiberry**
(rebuilt floppy reaches the original's root-disk prompt). (Leaving `IBLK` stale causes
`WARNING! Kernel decompression overrun.`; the tool avoids that.)

**Requires:** `dd`, `od`, `compress` (or `ncompress`), and `gzip`/`zcat` (for the self-test).

## `unpack-root.sh` — carve the UFS miniroot

`unpack-root.sh` extracts the high-value content from a root/miniroot disk. It is read-only on input and
writes everything under `tools/_work/<image-basename>/` (gitignored). ✅

```sh
tools/unpack-root.sh sources/floppy/amix_21_root.adf
# -> tools/_work/amix_21_root/{binwalk.txt, strings.txt, tar_*.tar, tar_*/}
```

### Dependency caveat — why this *carves* instead of mounting

Amix's root disk body is an **SVR4, big-endian, m68k UFS filesystem**. Linux's in-tree `ufs` driver
**generally cannot mount it** (wrong endianness / SVR4 variant). So this script does **not** try to mount
the image — it does a pragmatic carve instead: ✅

1. Run `binwalk` to enumerate embedded objects (offsets saved to `binwalk.txt`).
2. For each reported **POSIX tar archive**, `dd` from its offset to EOF into `tar_<n>_at_<off>.tar`, then
   let `tar` extract what it can (tar stops at its own end-of-archive marker).
3. Dump the installer / shell-script text (`strings -n 8` → `strings.txt`) and grep the lines that
   matter: `#!/(bin|sbin)/sh`, `/dev/rmt`, `/dev/dsk`, `amixpkg`, `BOOTSIZE`, `SWAPPART`, `mkfs`,
   `fsck`, `ufs`, `viper_kludge`, `partition`.

The **ELF installer binaries are left in place** — they are reported by offset (search `binwalk.txt` for
`Motorola 68020`) rather than extracted, because they are not in a self-contained archive container. For a
true UFS file tree, use a UFS-aware tool on a *copy* of the image (a *BSD host, or a commercial UFS reader).
✅ This matches the brief's root.adf decode: the first m68k ELF sits at offset `0x6800`, more ELF binaries
(cpio, fsck, dd, amixpkg, …) follow, interleaved with `/bin/sh` scripts, and a POSIX tar member appears at
`0x17180`. ✅

**Requires:** `binwalk` (hard requirement, exit `3` if absent), `dd`, `strings`; optional `tar` to unpack
carved members. If the `lost+found` fingerprint is missing it prints a warning but continues. ✅

## `build-custom-bootdisk.sh` — SCAFFOLD for an add-on disk

`build-custom-bootdisk.sh` builds a **self-extracting "add-on" floppy image** that ships extra files
(typically a driver plus an install script) to an Amix user. It mirrors the mechanism of the real
[Amix 2.1 patch disk](anatomy-patch-adf.md): a small `/sbin/sh` header in the first 1 KB, followed by an
SVR4 ASCII (newc) cpio archive of your payload. On Amix the header script skips its own 1 KB and pipes the
trailing cpio into the filesystem, then runs your installer. 🟡

```sh
tools/build-custom-bootdisk.sh \
  --payload ./mydriver-payload \
  --out     ./mydriver-addon.adf \
  --install var/addon/install      # relative path, inside the payload, to your installer
# optional: --size 901120  (default = 880 KB DD floppy)
```

The payload directory's contents are archived with paths **relative to the dir**, so on Amix they extract
under `/`. Put your installer at e.g. `var/addon/install` and pass `--install var/addon/install`. ✅

### What it produces, and how it self-tests

1. Emits a `<=1 KB` `/sbin/sh` header (it errors out if your header exceeds 1024 bytes — the real patch
   disk's own constraint, `# THIS FILE 1024 CHARACTERS MAX`). The header refuses to run unless
   `id` reports `uid=0(root)` (root check), then runs:
   ```sh
   dd if="$0" bs=1k iseek=1 2>/dev/null | (cd /; cpio -icdmuv)
   ```
   This is the same `dd … iseek=1 | cpio` skip-the-header pattern the genuine patch disk uses. ✅
2. Builds the payload into a **newc** cpio archive (via `cpio -o -H newc`, or `bsdtar --format newc`).
3. Assembles `header (padded to exactly 1 KiB) + cpio + zero-pad to --size`, erroring if the payload
   overflows the floppy.
4. **Structural self-test:** dumps the header's first lines and re-lists the cpio members with
   `dd if=<out> bs=1k skip=1 | cpio -it`, proving the archive is well-formed.

### Add-on disk vs. bootable floppy vs. boot partition

This script builds an **add-on / driver-install** disk that runs *on* an already-booted Amix — it is not
itself bootable. For the other two delivery surfaces:

- A **bootable** `boot.adf` carrying a custom kernel: use `build-bootfloppy.sh` (above) — the floppy
  format is now [reverse-engineered](reverse-engineering-boot-adf.md), so this is solved (host-verified;
  🟡 emulator-test pending).
- Putting a kernel change onto an **installed** system: relink and write the on-disk boot partition with
  `make bootpart` (run on Amix; see [kernel build](../drivers/kernel-build.md)):
  ```sh
  make install                         # produces /usr/sys/.../relocunix
  cp relocunix /stand
  make bootpart KERNEL=relocunix       # writes the 2 MB boot partition (BOOTSIZE=2 MB)
  shutdown -i6                         # reboot
  ```

See [adding drivers to a boot disk](adding-drivers-to-boot-disk.md) for the full decision tree across all
three surfaces.

**Requires:** `cpio` (newc) **or** `bsdtar`; plus `dd` and `printf`. ✅

## `gen-llms-full.sh` — regenerate the LLM corpus

`gen-llms-full.sh` concatenates every page under `docs/` — in the canonical reading order defined inside
the script (kept in sync with `docs/index.md` and `llms.txt`) — into `llms-full.txt` at the repo root, so
an LLM can ingest the whole corpus in one file. It touches no disk images. ✅

```sh
tools/gen-llms-full.sh
# -> wrote /…/llms-full.txt (<bytes> bytes, <N> pages, <M> missing)
```

Each page is wrapped with a `# FILE: <path>` banner. Missing pages are reported on stderr
(`warning: missing <f> (skipped)`) and counted, so you can see at a glance which pages still need
writing. Per the [contributor contract](../../AGENTS.md), **run this after any content change** so
`llms-full.txt` stays current — and update `llms.txt` and `docs/index.md` if you add, rename, or move a
page. ✅

## Putting it together — a typical session

```sh
# 1. Verify your local media against the published checksums (never commit the ADFs).
sha256sum sources/floppy/amix_21_*.adf      # compare to sources/CHECKSUMS.txt

# 2. Classify and inspect each disk (read-only).
tools/inspect-adf.sh sources/floppy/amix_21_boot.adf
tools/inspect-adf.sh sources/floppy/amix_21_root.adf
tools/inspect-adf.sh sources/floppy/amix_21_patch.adf

# 3. Extract the kernel from the boot floppy (-> m68k ELF).
tools/extract-kernel.sh sources/floppy/amix_21_boot.adf unix.elf

# 4. (Optional) Rebuild a bootable floppy with your kernel. 🟡 verify in an emulator
tools/build-bootfloppy.sh --donor sources/floppy/amix_21_boot.adf --kernel unix.elf --out custom_boot.adf

# 5. Carve the miniroot to study the installer scripts.
tools/unpack-root.sh sources/floppy/amix_21_root.adf

# 6. (Optional) Build a self-extracting add-on disk for your driver. 🟡 untested on real Amix
tools/build-custom-bootdisk.sh --payload ./mydriver-payload --out ./mydriver-addon.adf \
    --install var/addon/install

# 7. Regenerate the LLM corpus after editing docs.
tools/gen-llms-full.sh
```

## See also

- [Adding drivers to a boot disk](adding-drivers-to-boot-disk.md) — the decision tree this tooling serves.
- [Reverse-Engineering the Boot Floppy](reverse-engineering-boot-adf.md) — the decode behind `extract-kernel.sh` / `build-bootfloppy.sh`.
- [boot.adf anatomy](anatomy-boot-adf.md), [root.adf anatomy](anatomy-root-adf.md),
  [patch.adf anatomy](anatomy-patch-adf.md) — what each disk type contains, in detail.
- [The kernel build](../drivers/kernel-build.md) — the `make bootpart KERNEL=relocunix` boot-partition flow.
- [Driver model](../drivers/driver-model.md) — how a driver gets into `kernel.c` before any disk step.

## Sources

- `tools/inspect-adf.sh`, `tools/unpack-root.sh`, `tools/build-custom-bootdisk.sh`,
  `tools/gen-llms-full.sh` — the scripts documented here (this repo).
- `sources/research-brief.md` §0 (artifacts + checksums), §3 (boot.adf bootblock + compressed-kernel
  strings), §10 (boot/root/patch anatomy: UFS miniroot, ELF at `0x6800`, tar at `0x17180`, patch
  `dd … iseek=1 | cpio` mechanism), §9 (install / `make bootpart KERNEL=relocunix`).
- `tools/requirements.md` — authoritative, install-by-platform prerequisite list.
- ADF analyses reproduced via `tools/inspect-adf.sh` on `amix_21_{boot,root,patch}.adf`
  (user-supplied media; see `sources/CHECKSUMS.txt`).
- Media pointer: [amigaunix.com](https://www.amigaunix.com/doku.php/home) / archive.org
  (`archive.org/details/commodore-amiga-operating-systems-amix`).
