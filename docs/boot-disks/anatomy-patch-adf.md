---
title: Anatomy of the Patch Floppy
summary: The self-extracting patch disk — a /sbin/sh header followed by a single SVR4 cpio archive that an apply script unpacks with bundled lha.
status: draft
---

# Anatomy of the Patch Floppy

The Amix **patch floppy** (`amix_21_patch.adf`) is not a filesystem disk at all — it is a
**self-extracting hybrid**: the first 1024 bytes are a `/sbin/sh` script, and everything after byte
1024 is a single SVR4 ASCII **cpio** archive ✅. You apply it by running the floppy image *as a shell
script*: the header bootstraps itself, `dd`s past its own first kilobyte, pipes the rest through
`cpio` to drop files into `/var/patch/`, decompresses them, and `exec`s the bundled
`/var/patch/apply` script. `apply` then uses a bundled copy of `lha` to unpack the real payload
(`archive.lha`) according to three list files.

This page decodes that structure byte-for-byte (reproduced locally with
[`tools/inspect-adf.sh`](../../tools/inspect-adf.sh) and a small cpio walker), then explains the
`apply` + `lha` + list mechanism. It is the closest thing Amix has to a worked example of a custom
add-on disk, so it doubles as the reference model for
[adding your own drivers to a boot/patch disk](adding-drivers-to-boot-disk.md).

> **What this disk is.** Our copy self-identifies as *"Patch Disks 1 and 2 for International,
> USA-Only, 2-user, and Unlimited-User Amiga UNIX System V Release 4.0 Version 2.1"* ✅ — i.e. the
> patch that takes a stock 2.1 system to **2.1p2a / kernel 2.1c** (inet/NFS/Y2K fixes), widely
> considered the definitive build. See the [version matrix](../reference/versions.md) for where this
> sits in the release history.

## At a glance

| Region | Offset | Contents | Tag |
|---|---|---|---|
| Header script | `0x000`–`0x3FF` (bytes 0–1023) | `/sbin/sh` bootstrap, "1024 CHARACTERS MAX" | ✅ |
| cpio archive | `0x400` → end | one SVR4 ASCII cpio (`070701`/`newc`) stream | ✅ |
| Image size | — | 901120 bytes (standard 880 KB Amiga DD floppy) | ✅ |

The header is deliberately padded/capped to exactly **1 KB** so the bootstrap can `dd … iseek=1`
(skip exactly one 1024-byte block) and feed the rest straight into `cpio`. That 1 KB ceiling is why
the file's own first comment is `# THIS FILE 1024 CHARACTERS MAX` ✅.

There is **no AmigaDOS bootblock and no AmigaDOS filesystem** on this disk — unlike the
[boot floppy](anatomy-boot-adf.md) it is not bootable. It is data that the running Amix system
consumes. `tools/inspect-adf.sh` classifies it as `patch` purely from the first two bytes being `#!`
(`0x2321`) ✅.

## The 1 KB header script

Bytes 0–1023 are an ordinary Bourne-shell script (`#!/sbin/sh` ✅). Reproduced verbatim from our
image (`dd if=amix_21_patch.adf bs=1 count=1024 | strings`):

```sh
#!/sbin/sh
# THIS FILE 1024 CHARACTERS MAX
echo "This contains Patch Disks 1 and 2 for International, USA-Only,
2-user, and Unlimited-User Amiga UNIX System V Release 4.0 Version 2.1.
Checking..."
# Floppy reading is slow without flopd.  Second flopd won't start.
# New /etc/sysinit is proper remedy.  Start flopd now so we can patch:
/usr/bin/setpgrp /usr/amiga/etc/flopd < /dev/null > /dev/null 2>&1 &
sleep 10  # REQUIRED!
if [ "`uname -v | grep '^2\.1.* 08004..$'`" = "" ] ; then
	echo "
Your hard disk contains: `uname -svrm`
USE THIS PATCH DISK AT YOUR OWN RISK.
exit."
	exit
fi
if [ "`/usr/bin/id`" != "uid=0(root) gid=0(root)" ] ; then
	echo "Please try again as root.
exit."
	exit
fi
echo "
	Pre-loading $0 into /var/patch/..."
rm -f /var/patch/archive.*
QUIETDD=y dd if="$0" bs=1k iseek=1 2>/dev/null | \
(cd /; QUIETCPIO=y cpio -icdmuv)
uncompress -f /var/patch/*.Z
sync
sync
exec /var/patch/apply
exit # REQUIRED!
```

Step by step, what the header does:

1. **Print the banner** and the version string the disk claims to patch ✅.
2. **Start `flopd`** in its own process group via `setpgrp`. Comment: *"Floppy reading is slow
   without flopd. Second flopd won't start."* ✅ `flopd` is the Amix floppy daemon at
   `/usr/amiga/etc/flopd`; without it, raw floppy reads are painfully slow, so the patch starts one
   before the big `dd`.
3. **`sleep 10  # REQUIRED!`** — give `flopd` time to come up before reading the disk ✅. The
   `# REQUIRED!` comment is the original author's, not ours.
4. **Version gate:** `uname -v | grep '^2\.1.* 08004..$'`. If that produces no output, the running
   kernel is not a 2.1 / `08004xx` build and the script prints the current `uname -svrm` plus
   *"USE THIS PATCH DISK AT YOUR OWN RISK."* and exits ✅. This is the same `^2\.1.* 08004..$`
   fingerprint recorded in the [version matrix](../reference/versions.md) ✅.
5. **Root gate:** requires `id` to read exactly `uid=0(root) gid=0(root)`, else *"Please try again
   as root."* and exit ✅.
6. **Self-extract:** `rm -f /var/patch/archive.*` clears any prior payload, then

   ```sh
   QUIETDD=y dd if="$0" bs=1k iseek=1 2>/dev/null | (cd /; QUIETCPIO=y cpio -icdmuv)
   ```

   `$0` is the patch image itself; `bs=1k iseek=1` skips the first 1024-byte block (this very header)
   and streams the cpio body to `cpio -icdmuv` from `/` — so the archive's `var/patch/...` paths land
   under `/var/patch/` ✅.
7. **Decompress:** `uncompress -f /var/patch/*.Z` expands every `compress(1)`-format member ✅.
8. **`sync; sync`** then **`exec /var/patch/apply`** — hand off to the unpacked apply script ✅.

**Note (Amix `/bin/sh` is pre-POSIX).** The header relies only on backtick command substitution and
`grep` matching — no `$(...)`, no `grep -q`. This is the same pre-POSIX shell constraint documented
for [driver build scripts](../drivers/kernel-build.md) and called out in the
[quirks list](../how-it-works/quirks.md) ✅. The `QUIETDD`/`QUIETCPIO` env vars are honored by the
Amix builds of `dd`/`cpio` to suppress their block-count chatter ✅.

## The cpio payload (after byte 1024)

From byte `0x400` onward the disk is **one SVR4 ASCII cpio stream** — the `newc` format, magic
`070701` ✅. Walking the `newc` headers of our image gives this exact member table (offsets, octal
mode, and uncompressed-stream size are read straight from each 110-byte header):

| Offset | Mode | Size (bytes) | Member | Tag |
|---|---|---|---|---|
| `0x000400` | `040500` (dir) | 0 | `var/patch/` | ✅ |
| `0x000478` | `100700` | 6291 | `var/patch/apply.Z` | ✅ |
| `0x001D8C` | `100500` | 26964 | `var/patch/lha.Z` | ✅ |
| `0x008760` | `100400` | 1223 | `var/patch/replace.list.Z` | ✅ |
| `0x008CB0` | `100500` | 932 | `var/patch/preload` | ✅ |
| `0x0090D4` | `100600` | 3508 | `var/patch/changes.Z` | ✅ |
| `0x009F0C` | `100400` | 221 | `var/patch/modify.list.Z` | ✅ |
| `0x00A074` | `100600` | **835787** | `var/patch/archive.lha` | ✅ |
| `0x0D61C4` | `100400` | 248 | `var/patch/delete.list.Z` | ✅ |
| `0x0D6344` | `000000` | 0 | `TRAILER!!!` | ✅ |

A few things worth reading off that table:

- Every member name is **relative** (`var/patch/...`, no leading `/`), which is why the header
  `cd /` before `cpio` ✅.
- All members are `compress(1)`-format (`.Z`) **except** two: `var/patch/preload` (a plain
  executable script, mode `0500`) and `var/patch/archive.lha` (already LHA-compressed, so it is not
  double-compressed) ✅. After the header's `uncompress -f /var/patch/*.Z`, the `.Z` suffixes are
  gone and `/var/patch/` holds `apply`, `lha`, `replace.list`, `preload`, `changes`,
  `modify.list`, `archive.lha`, and `delete.list`.
- `archive.lha` is the heavyweight: **~835 KB** (offset `0xCC0CB` in the brief = the member's data
  region) ✅ — it dominates the disk and carries the actual patched files.
- The stream ends with the canonical cpio `TRAILER!!!` sentinel ✅.

## How `apply` + `lha` + the lists work

After the header `exec`s `/var/patch/apply`, the bundled tools and lists drive the actual patch ✅.
The roles, inferred from the member set and their names ✅ (the precise line-by-line logic of `apply`
itself is 🟡 — it is a compressed script we describe by its inputs rather than quoting in full):

| File | Role | Tag |
|---|---|---|
| `apply` | The patch driver script the header `exec`s | ✅ |
| `lha` | Bundled LHA archiver binary used to unpack `archive.lha` | ✅ |
| `archive.lha` | The real payload — the new/patched files, LHA-compressed | ✅ |
| `replace.list` | Files to overwrite from `archive.lha` | ✅ (name); 🟡 (exact semantics) |
| `modify.list` | Files to patch/edit in place | ✅ (name); 🟡 (exact semantics) |
| `delete.list` | Files to remove from the installed system | ✅ (name); 🟡 (exact semantics) |
| `changes` | Human-readable changelog / per-change actions | ✅ (name); 🟡 (exact semantics) |
| `preload` | Pre-step run before applying (plain `0500` script) | ✅ (name); 🟡 (exact semantics) |

The mechanism, in order ✅/🟡:

1. The disk **ships its own `lha`** rather than relying on one being installed ✅ — the target 2.1
   system has no guaranteed LHA tool, so the patch is self-contained.
2. `apply` runs **`preload`** first (a setup/pre-flight step), then unpacks **`archive.lha`** with the
   bundled `lha` 🟡.
3. The three **`*.list`** files tell `apply` which extracted files to **replace**, which to **modify**,
   and which to **delete** on the live system ✅ (names) / 🟡 (the exact list grammar is not
   primary-documented).
4. **`changes`** records what each step does (changelog), so the patch is auditable ✅ (name).

Because the patch can both add new files and *delete* existing ones, and because it carries its own
decompressor, it is effectively a tiny package format layered on top of cpio. The
[2.1c kernel](../reference/versions.md) and the inet/NFS/Y2K fixes arrive through `archive.lha` this
way ✅.

## Why this disk is the model for custom add-on disks

This layout is the cleanest example we have of *"ship arbitrary files to a running Amix box from a
single floppy, with no AmigaDOS filesystem and no installer"* ✅. The recipe generalizes:

1. **Cap a `/sbin/sh` header at exactly 1024 bytes** and pad to that size.
2. After the header, append a **`newc` cpio archive** whose paths are relative to where you want them
   extracted (and whose first directory member creates the staging dir).
3. In the header, `dd if="$0" bs=1k iseek=1 | (cd /; cpio -icdmuv)`, `uncompress` as needed, then
   `exec` your own apply step.
4. Bundle any tools the target can't be assumed to have (the patch bundles `lha`).
5. Keep the header **pre-POSIX-shell clean** (backticks, no `$(...)`, no `grep -q`) ✅.

For wiring *kernel drivers* into a disk that the
[Superkickstart bootstrap](../how-it-works/boot-process.md) will actually boot — as opposed to a
running-system patch like this one — follow
[Adding drivers to a boot disk](adding-drivers-to-boot-disk.md), which uses this self-extraction
pattern together with the
[`make bootpart KERNEL=relocunix`](../drivers/kernel-build.md) boot-partition step.

**Licensing.** Do not redistribute `amix_21_patch.adf`. It is proprietary Commodore material
(abandonware, not licensed) ✅. Obtain it from [amigaunix.com](https://www.amigaunix.com/) or the
[archive.org Amix collection](https://archive.org/details/commodore-amiga-operating-systems-amix);
verify against `sources/CHECKSUMS.txt`
(`674f3ac691fd032c2c79c2fe90e2cd158e3f7d6004da03c4820373c50060fdfe`).

## Reproduce this analysis

Everything above was read off a user-supplied `amix_21_patch.adf`; nothing here requires the image to
be committed. To redo it yourself:

```sh
# Classify the disk and dump the header + cpio member names
tools/inspect-adf.sh amix_21_patch.adf

# The raw 1 KB /sbin/sh header
dd if=amix_21_patch.adf bs=1 count=1024 2>/dev/null | strings -n 4

# The cpio member names (newc filenames follow the 110-byte ASCII header)
strings -n 4 amix_21_patch.adf | grep -E '^(var/patch|TRAILER)'
```

To list the cpio body the way the header would, on any Unix with GNU `cpio`:

```sh
# Skip the 1 KB header, then list (do NOT extract over a live tree casually)
dd if=amix_21_patch.adf bs=1k skip=1 2>/dev/null | cpio -itv
```

## See also

- [Anatomy of the Boot Floppy](anatomy-boot-adf.md) — the bootblock + compressed-kernel disk (this one is *not* bootable).
- [Anatomy of the Root Floppy](anatomy-root-adf.md) — the UFS miniroot installer.
- [Adding drivers to a boot disk](adding-drivers-to-boot-disk.md) — uses this self-extraction pattern for custom disks.
- [Boot-disk build pipeline](build-pipeline.md) — end-to-end tooling for assembling disks.
- [Versions](../reference/versions.md) — where 2.1p2a / kernel 2.1c fits, and the `^2\.1.* 08004..$` fingerprint.
- [Quirks](../how-it-works/quirks.md) — the pre-POSIX `/bin/sh` and Y2K context this patch addresses.

## Sources

- `amix_21_patch.adf` analysis via [`tools/inspect-adf.sh`](../../tools/inspect-adf.sh) and a `newc`-cpio header walk (offsets, modes, sizes reproduced locally) — SHA-256 `674f3ac6…0060fdfe` in `sources/CHECKSUMS.txt`.
- Master research brief, [§10 "Boot / root / patch disk anatomy"](../../sources/research-brief.md) and §1 version matrix (`^2\.1.* 08004..$` gate, 2.1p2a / kernel 2.1c).
- Verbatim 1 KB header script captured from the image (`dd … bs=1 count=1024 | strings`).
- amigaunix.com patch-disk page and the [archive.org Amix collection](https://archive.org/details/commodore-amiga-operating-systems-amix) (image provenance; not redistributed here).
