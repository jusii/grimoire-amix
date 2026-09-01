---
title: "Package Management: the stock SVR4 pkg system on Amix"
summary: How Amix's stock SVR4 packaging works on disk — the /var/sadm contents database, the contents(4) record grammar, directory vs datastream media, how pkgadd mutates the DB, and a space-in-a-pathname defect that breaks pkgrm and pkginfo on the shipped image.
status: draft
---

# Package Management: the stock SVR4 pkg system on Amix

Amix ships the **standard AT&T SVR4 packaging system** — `pkgadd`, `pkgrm`, `pkginfo`, `pkgmk`, `pkgtrans`, and friends — driving a master installed-object database under `/var/sadm`. If you have used SVR4 (or Solaris) packaging, almost everything here is familiar; this page documents the parts that are **Amix-specific or that bite on the shipped 2.1 image**: the exact on-disk layout, the [`contents(4)`](#the-contents4-database) record grammar, the two package media formats, how `pkgadd` mutates the database, and — importantly — a **data-corruption defect on the stock image that breaks `pkgrm` and `pkginfo -l` out of the box** ([F7 below](#the-space-in-a-pathname-defect)).

For the *command* quick-reference (which tools exist, their flags, the `amixpkg` install wrapper), see the [command cheat sheet](../reference/commands-cheatsheet.md#packages-svr4-pkg). This page is the *internals*: what those commands read and write. For the **remote** side — how a network package repository is laid out, the catalog grammar, and the `apkg` client that consumes it — see [the package repository format](package-repository.md).

Everything here was **reproduced firsthand on a clean Amix 2.1c image** (`uname -a` → `UNIX_System_V … 4.0 2.1c 0800430 … m68k`) under WinUAE, driven over telnet/ftp, on 2026-07-01. Unless tagged otherwise every claim is **✅ Verified** (observed live on the running system); items resting on community distribution practice are tagged 🟡.

## The installed toolset (and three notable absences) ✅

The shipped system carries the standard SVR4 build and install tools, but **not** the full set — three are missing:

- **`/usr/bin`:** `pkginfo`, `pkgmk`, `pkgproto`, `pkgparam`, `pkgtrans`.
- **`/usr/sbin`:** `pkgadd`, `pkgrm`, `pkgchk`, `installf` (the three privileged ones — `pkgadd`, `pkgrm`, `installf` — are mode `r-x------`, **root-only**).
- **Absent:** `pkgask`, `removef`, and `amixpkg` are **not on the installed system** at all. Notably `installf` ships **without its partner `removef`**, and `amixpkg` — the install-time wrapper everyone remembers — lives only on the install media, not the running box ([see below](#amixpkg-the-install-media-front-end)).

There are also **no `pkg*` man pages** installed: the Amix man tree is Amiga-reorganised (`man1A`, `man1X`, `man3A`, `man5A`, `man6`, …) with **no `man1m`/`man4`**, so the conventional SVR4 `pkgadd(1M)` / `contents(4)` pages are simply not present. ✅

This list belongs on the [command cheat sheet](../reference/commands-cheatsheet.md#packages-svr4-pkg); it is repeated here because the absences (`removef`, `amixpkg`) explain some of the system's rough edges.

## The `/var/sadm` layout ✅

The SVR4 package administration state lives under `/var/sadm`:

| Path | What it is |
|---|---|
| `/var/sadm/install/contents` | The **master installed-object database** — every file, directory, symlink, and device node on the system, one line each, tagged with its owning package(s). On this image ~**2.3 MB / 28,645 lines**. |
| `/var/sadm/install/admin/default` | The `admin(4)` installation-policy file `pkgadd` consults (defaults: `mail=`, `conflict=quit`, etc.). |
| `/var/sadm/pkg/<PKG>/` | Per-package directory: `pkginfo` (the package's metadata) + `install/` (its scripts, if any) + `save/` (files saved for rollback). |

Two things surprise people:

- **The `contents` DB is world-writable** — mode `rw-rw-rw-` on the stock image. ✅ That is a genuine (and security-relevant) property of the shipped system, not a typo; the master package database can be rewritten by any user.
- **There is no per-package `pkgmap` in the installed database.** The `pkgmap` manifest exists only in the *package media* ([below](#package-media-directory-vs-datastream)); once installed, the authoritative record of *which files a package owns* is the **trailing package-name field of each `contents` line**. To list a package's files you effectively `grep` its name in `contents` — which is exactly what `pkginfo -l` / `pkgchk` do internally (and exactly what the [F7 defect](#the-space-in-a-pathname-defect) breaks).

On this image **31 packages** are installed; all carry `ARCH=Amiga`, `CATEGORY=system`, and — notably — **no `VERSION` field**. ✅

## The `contents(4)` database ✅

`contents` is **whitespace-delimited, one line per pathname**, and the **trailing field(s) name the owning package(s)**. The field layout depends on the object's **ftype** (first token after the path):

| ftype | Record shape | Example |
|---|---|---|
| `f` (file) | `path f class mode owner group size cksum modtime pkg` | `/usr/bin/ls f none 0555 bin bin 13824 51698 690829200 core` |
| `d` (directory) | `path d class mode owner group pkg` | |
| `s` (symlink) | `path=target s class pkg` | `/bin=/usr/bin s none core` |
| `c` / `b` (char/block device) | `path c|b class major minor mode owner group pkg` | |

A bookkeeping comment near the top records the **last writer**: `# Last modified by <amixpkg|pkgadd> for <PKG> package`. ✅ That single line is how we know [`amixpkg` was the original populator](#amixpkg-the-install-media-front-end) even though it isn't installed.

Because the format has **no quoting**, a pathname is assumed to contain no whitespace — an assumption the stock image violates, with consequences ([F7](#the-space-in-a-pathname-defect)).

## Package media: directory vs datastream ✅

A package exists in one of two on-disk forms — the same two SVR4 defines:

### Directory format (what `pkgmk` emits, what `pkgadd -d <dir>` reads)

```text
<PKG>/
  pkgmap     # the manifest: a header line ": <nparts> <nblocks>", then one line per object:
             #   <part> <ftype> <class> <path> <mode> <owner> <group> [size cksum mtime]
  pkginfo    # package metadata (pkgmk stamps PSTAMP=<host><YYMMDDhhmmss>, CLASSES=none)
  root/      # payload installed at absolute paths
  reloc/     # payload installed relative to a base (relocatable) — if any
```

### Datastream format (`.pkg`, what `pkgtrans` produces)

A single file — the form **AmixBP and amigaunix.com distribute** 🟡 — with an ASCII header followed by cpio archives:

```text
# PaCkAgE DaTaStReAm
<PKG> <nparts> <nblocks>
# end of header
<cpio archive(s) in SVR4 070701 "portable ASCII" / newc format,
 carrying pkginfo, pkgmap, then the payload>
```

> **The `cksum` field is a folded 32-bit byte sum, not a CRC** ✅. SVR4's `pkgmap` checksum simply adds
> up the file's bytes into a 32-bit accumulator and folds the result — it is the same family as
> `sum(1)`, not `cksum(1)`'s CRC-32, and it detects damage rather than resisting it. Anything
> reimplementing `pkgmk`/`pkgadd` has to reproduce that arithmetic exactly or every line of the
> manifest mismatches.

The cpio member format is **SVR4 `070701` (portable ASCII, a.k.a. "newc")** ✅ — the same family the [patch disk](../boot-disks/anatomy-patch-adf.md) and the tape-install stream use. You can convert a directory package to a datastream with `pkgtrans <srcdir> <dest.pkg> <PKG>`, and `pkgadd -d <dest.pkg> <PKG>` installs it.

## How `pkgadd` mutates the database ✅

Installing a package is a **database edit plus a file copy**. On `pkgadd`:

1. Each object line is **inserted into `contents` in sorted pathname position** — *not appended* — so `contents` stays lexically ordered by path.
2. The inserted line's trailing field is **tagged with the package name**.
3. `/var/sadm/pkg/<PKG>/{pkginfo,install,save}` is created.
4. The payload is installed to its target paths.
5. The `# Last modified by …` marker is rewritten to `pkgadd`.

`pkgrm` reverses this: it parses `contents`, removes the package's objects, and rewrites the DB — which is why a **`contents` file it cannot parse stops removal dead** ([F7](#the-space-in-a-pathname-defect)). ✅

## Stock packages are pure payloads ✅

Every package installed on the stock image is a **plain file payload** — no logic:

- The per-package `install/` directory is **empty**: no `preinstall`, `postinstall`, `request`, `checkinstall`, or class-action scripts. ✅
- `CLASSES=none`, and there is **no `depend` file** — so the stock system declares **no formal inter-package dependencies**. ✅
- The **only** non-`pkginfo` files anywhere in `/var/sadm/pkg/*/` are saved `sysadm` menu-interface `.mi` files under `save/intf_install/` for a handful of system packages (`bnu`, `lp`, `nsu`, `face`, `sysadm`) — the one place a non-`none` class (`intf_install`, tied to `OAMBASE=/usr/sadm/sysadm`) shows up. ✅

Practically: the stock Amix distribution behaves as a set of independent file bundles, not a dependency graph. That is why the install can drive everything in one `amixpkg … standard` pass without ordering constraints.

## ⚠ The space-in-a-pathname defect {#the-space-in-a-pathname-defect}

**On the stock image, `pkgrm <anything>` and `pkginfo -l <anything>` fail out of the box** ✅ — both abort with:

```text
ERROR: bad read of contents file
  pathname=/usr/x11r5/fonts/server/MacFS/TrueType
  problem=unknown ftype
```

**Root cause:** one `contents` record describes a file whose name **contains a space** — an X11R5 font file `TrueType Fonts`:

```text
/usr/x11r5/fonts/server/MacFS/TrueType Fonts f none 0444 x sys 525157 64049 679609720 X11R5 X11R5
```

Since [`contents(4)`](#the-contents4-database) is whitespace-delimited with **no quoting**, the parser ends the pathname at the space, then reads the next token — `Fonts` — as the **ftype**, which is not a valid ftype (`f`/`d`/`s`/`c`/`b`/…), so every tool that does a *full* parse of `contents` aborts with `problem=unknown ftype`. (The record is doubly malformed: it even ends with a duplicated `X11R5 X11R5` package field.) ✅

**It is the sole blocker.** Deleting that one line makes `pkgrm` succeed and cleanly reverse an install, and `pkginfo -l` then works. ✅ (This was proven by reproducing the abort, locating the record with `grep -n`, removing the line, and re-running both tools successfully.)

This is a strong candidate for the historical **"`amixpkg`/package tools are broken"** reputation ([quirks checklist](quirks.md)): on the shipped image, package **removal and detailed query are broken by a single corrupt data record**, independent of the tools themselves. The `contents` DB being [world-writable](#the-varsadm-layout) means the fix (delete the offending line) is trivially applicable — but so was the original corruption.

> **Fixing it.** Back up `/var/sadm/install/contents`, then delete the single malformed line (identify it with `grep -n 'TrueType Fonts' /var/sadm/install/contents`). After that, `pkgrm` and `pkginfo -l` behave normally. ✅

## ⚠ The `pkgadd -R` altroot crash — a toolchain bug, not a pkgtools bug ✅

A modern port of the heirloom SVR4 pkgtools to Amix hit a **silent, 100%-reproducible SIGSEGV in
`pkgadd -R <altroot>`** (alternate-root installs — the core code path of any from-media
installer). Two findings generalize beyond that port ✅:

- **The "silent, no core" was an illusion**: the 1 MB core lands **inside the `-R` root** at
  `<root>/var/sadm/install/core` — where nobody looks. On-box `adb` on that core named the real
  crash site (`nhash.c`'s name-cache `HASH()` returning garbage → a negative bucket index → a
  wild store in `add_cache`).
- **The root cause was the cross-assembler**, not the SVR4 code: the tdivs divide-with-remainder
  mis-encoding (see [the toolchain fixup family](../drivers/toolchain.md#the-assembler-fixup-family-swbeg-fcmp--and-the-tdivs-divide-with-remainder-bug))
  made `hv % hsz` — a perfectly valid C expression — return garbage at every optimization
  level. Forcing suspect files to `-O0` never could have helped, and didn't. With the toolchain
  fixed and the engine rebuilt, plain empty-root `pkgadd -R` runs clean (4/4, zero cores) on
  the same box that cored 4/4 before ✅.

The lesson for anyone porting period software with a period cross-toolchain: when a crash
reproduces on the box but not under host sanitizers, **suspect the toolchain's generated code
before the source** — and check inside the altroot for the core.

## ⚠ `pkgadd -R` needs a `/` line in `/etc/mnttab` — or it mis-identifies the root ✅

SVR4 `libinst`'s `get_mntinfo()` sorts the mount table by mount-point-name length and **asserts the shortest entry is exactly `/`**. On a normally-booted system `/` is always listed, so this never fires — but it bites hard in a **minimal installer environment**. A from-media installer miniroot whose `mount(2)` wrapper writes no `/etc/mnttab` entry (and whose boot never registers `/`) can end up with a mnttab that lists only the source medium — e.g. just the `cdfs` `/cdrom` line. Then `get_mntinfo()` picks `/cdrom` as "root", and `pkgadd -R` aborts with **`identified </cdrom> as root file system instead of </>`**, installing nothing. A `/mnt` line does *not* satisfy the check — only a genuine `/` entry does. The fix is either engine-side (synthesize the `/` row when the table lacks it — safe because a real system always has it) or one line before the install: `echo "/dev/root / s5 rw 0" >> /etc/mnttab`. This is the **consumer** counterpart to the mnttab contract on the [driver-model page](../drivers/driver-model.md#writing-an-in-kernel-filesystem-the-svr4-vfs_mount-contract) (which is userland-maintained and helper-written): `mnttab` being *sparse* is what breaks the pkg tools.

## `amixpkg`: the install-media front-end {#amixpkg-the-install-media-front-end}

`amixpkg` is **not present on the installed system** (`/usr/sbin`, `/usr/bin`, `/sbin` — absent) ✅, yet the `contents` database names it as its **original writer** (`# Last modified by amixpkg for X11r5src package`) ✅. The reconciliation: `amixpkg` is the **install-media (root.adf) front-end** that populates `/var/sadm` during installation, via the *same* database machinery as `pkgadd` — it is the installer's package driver, not a general-purpose installed command. The [install walkthrough](../getting-started/install-walkthrough.md) drives the whole distribution install through it (`amixpkg -i -m -d … -r /mnt -y standard`).

Its **"widely reported broken" reputation** 🟡 is, at minimum, **consistent with the [F7 corruption](#the-space-in-a-pathname-defect)**: a stock system on which `pkgrm`/`pkginfo -l` abort will *look* like a broken package system regardless of which front-end you use. The corrected framing for grimoire: `amixpkg` is an **install-time wrapper that isn't on the running system**, and the concrete, reproducible breakage on the stock image is the `contents` data defect — not (necessarily) a bug in `amixpkg` or `pkgadd` themselves. ✅ (absence + writer marker) / 🟡 (the "broken" reputation and the exact root.adf invocation).

## See also

- [Command cheat sheet — Packages](../reference/commands-cheatsheet.md#packages-svr4-pkg) — the `pkg*` tools, flags, and the `amixpkg` install wrapper at a glance.
- [Toolchain & packaging](../drivers/toolchain.md) — building and packaging software for Amix (the `pkgproto`/`pkgmk`/`pkgtrans` build side).
- [Quirks](quirks.md) — the stock-image `contents` corruption and the `amixpkg` reputation as checklist items.
- [Anatomy of the patch floppy](../boot-disks/anatomy-patch-adf.md) — the other place SVR4 `070701` cpio shows up on Amix.
- [Install walkthrough](../getting-started/install-walkthrough.md) — where `amixpkg … standard` lays the distribution down.
- [amigaunix.com — more_software](https://www.amigaunix.com/doku.php/more_software) and **AmixBP** (`amixbp.sourceforge.net`) — the community `.pkg` collection and distribution practice (🟡).

## Sources

- amix-kerntools brief `tdivs-cross-assembler-miscompile` (2026-07-21): the pkgadd -R altroot SIGSEGV root cause (adb on the in-altroot core; nhash HASH), engine rebuilt + re-verified 4/4 on the bench box 2026-07-20/21.
- **Firsthand, reproduced live** (✅): a clean **Amix 2.1c** image (`UNIX_System_V … 4.0 2.1c 0800430 … m68k`) under WinUAE, driven over telnet/ftp, 2026-07-01 (the **amix-packagemanager** project; command transcripts retained there). Specifically: `ls -l /usr/{bin,sbin}/pkg*` + the `No such file or directory` for `pkgask`/`removef`/`amixpkg` (F1); `ls -laR /var/sadm`, `/var/sadm/install/admin/default`, `pkginfo -x`, `/var/sadm/pkg/*/pkginfo` (F2); `head`/`grep` of `/var/sadm/install/contents` (F3); an on-box throwaway package built with `pkgmk`/`pkgtrans` and its `pkgmap` + `.pkg` header dissected with `od -c` (F4); a before/after `diff` of `contents` across a controlled `pkgadd` (F5); `find /var/sadm/pkg -type f` showing only `pkginfo` + `*.mi` (F6); the `pkgrm`/`pkginfo -l` abort, the offending `contents` record, and its removal-and-retry (F7); the `# Last modified by amixpkg …` marker with `amixpkg` absent from the filesystem (F8).
- The **2026-08-12/14 RAM campaign proof reports** (workspace record) ✅ — the SVR4 `pkgmap`
  checksum is a folded 32-bit byte sum (the `sum(1)` family), not a CRC, established while
  reproducing the manifest arithmetic outside the stock tooling.
- **`sources/research-brief.md` §20** (the stock SVR4 pkg-system internals, media formats, DB mutation, and the F7 `contents` corruption) — the grounding for this page, carrying the tags above.
- **Community distribution practice** (🟡): [amigaunix.com `more_software`](https://www.amigaunix.com/doku.php/more_software) (`.pkg` / cpio / `tar.zoo` distribution) and Michael Parson's **AmixBP** ([amixbp.sourceforge.net](https://amixbp.sourceforge.net), SourceForge group 263433) — the datastream-`.pkg` distribution channel.
- **Licensing:** no proprietary `pkg*` source or media reproduced; this page documents runtime behaviour and on-disk **data-record** layout observed live. The single malformed `contents` record in the F7 section is cited as **factual defect data** (interoperability / bug documentation), not vendored source (per [AGENTS.md §5](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md)).
- The **Installer-NG** Waves 5–6 field campaign (amix-installng @ `7106f1b`, amix-packagemanager @ `4539ad2`), 2026-07-22/24 — a blank-disk→bootable-install effort that root-caused these platform behaviours on the Amiberry bench and the real A4000+Z3660 (acceptance-run captures, s5/UFS state reads, and the on-metal digest attestation) ✅ (🟡 where tagged).
