---
title: Version Matrix
summary: Every Amix release and patch level with dates and confidence tags, plus the versions that do not exist.
status: draft
---

# Version Matrix

This page is the canonical answer to "which Amix version is *which*". Amix shipped as a short series
of releases between 1988 and 1992, and the development line effectively ends at one community patch
on top of the last retail release. Two version strings that circulate online — **"2.2"** and
**"2.1c, 1994"** — are *not real* and are flagged 🔴 below so you do not trust them.

The single number that matters in practice today: the last retail release is **2.1** ✅ (**February 1992** — the *month* is community-reported 🟡; sources confirm only the year),
and the de-facto "final" state of the system is **2.1 patch 2a**, whose patched kernel reports itself
as **2.1c** ✅. Almost everything written for modern emulation and the modern driver repos targets
exactly this **2.1p2a / kernel 2.1c** combination.

## The matrix

| Version | Date | Lineage / what it is | Notes | Tag |
|---|---|---|---|---|
| SVR3.x precursors | 1988–89 | AT&T System V **Release 3** | A2500UX demos; CPU stepped 68020 → 68030; proprietary windowing (pre-X) | 🟡 |
| 1.1 | 1991 | SVR4 | First widely-referenced **SVR4** release; mono X reported "slow as molasses" | 🟡 |
| 2.0 / 2.01 / 2.03 | 1991 | SVR4 | Color X via the A2410 graphics card; archive.org carries the 2.01 and 2.03 installers | 🟡 |
| **2.1** | **Feb 1992** 🟡 | SVR4 | **Last retail release.** Ships **pre-formatted man pages only** — the `nroff` man sources were dropped | ✅ (installer exists locally; month 🟡) |
| 2.1 patch 2a → kernel **2.1c** | post-1992 | SVR4 patch on 2.1 | Unofficial but treated as definitive; inet/NFS/Y2K fixes. Our `patch.adf` *is* this patch | ✅ (the patch ADF exists locally) |
| "2.2" | — | — | **Does not exist** in any primary source; almost certainly confusion with 2.1c | 🔴 |
| "2.1c, 1994" (gunkies) | — | — | The **1994 date is almost certainly wrong** — support ended in 1993 | 🔴 |

> The Ditto driver paper predates the 2.x line: its page headers read **"1990 European Amiga
> Developer's Conference"** ✅. Where it differs from 2.1 (notably the kernel-image name, below) it is
> documenting an earlier build.

## SVR4 vs the SVR3 precursors ✅/🟡

Amix as people mean it today is the **SVR4** line (1.1 and the 2.x releases). The 1988–89 machines —
demoed as the A2500UX, first shown publicly at **Uniforum, Dallas, January 1988** 🟡 (amigaunix.com
places the demo at "the 1988 Uniforum Conference in Dallas" but does not pin the *machine* or *month*
— those are community-reported) — ran AT&T
**System V Release 3** with a *proprietary* windowing system, not X11. ✅ Treat "SVR3 Amix" and
"SVR4 Amix" as two different products that share a name. The whole SVR4 codebase was a direct port of
AT&T's **3B2 (WE32x00) SVR4** source 🟡 (community-reported; amigaunix.com hedges "it appears that"), which is why so much of the system behaves like a generic
3B2-lineage SVR4 box rather than anything Amiga-specific. See
[what Amix is](../how-it-works/overview.md) for the lineage in full.

## 2.1 — the last retail release ✅

**Amix 2.1 is the last release Commodore sold** ✅ — February 1992, though the *month* is community-reported 🟡. It is the version every current
guide assumes, because its install media (boot / root / patch floppies) are the set that survived and
gets emulated. One concrete, frequently-tripped-over change in 2.1: the distribution carries
**pre-formatted man pages only** — the `nroff`/`troff` man *sources* were removed to save space ✅, so
you cannot regenerate or easily edit the manuals on a stock 2.1 system.

Our local boot/root/patch floppies are the **2.1** install set (`amix_21_boot.adf`,
`amix_21_root.adf`, `amix_21_patch.adf`). They are proprietary Commodore material — do not redistribute
them; obtain them from [amigaunix.com](https://www.amigaunix.com/doku.php/home) or
[archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix). Verify any copy
against the SHA-256 values in `sources/CHECKSUMS.txt` and inspect with `tools/inspect-adf.sh <image>`.

## 2.1 patch 2a and kernel "2.1c" ✅

The practical end of the Amix line is the **2.1 patch 2a** release, applied on top of retail 2.1. ✅
After it is applied, the patched kernel identifies itself as **2.1c** — this is the same thing, named
from the kernel's point of view rather than the patch's. It bundles inet, NFS, and **Y2K** fixes and
is widely regarded as the definitive state of the system.

Our `patch.adf` *is* this patch. It self-identifies as:

> *"Patch Disks 1 and 2 for International, USA-Only, 2-user, and Unlimited-User Amiga UNIX System V
> Release 4.0 Version 2.1."* ✅

Before applying anything, the patch's header script greps the live `uname -v` and requires it to match:

```text
^2\.1.* 08004..$
```

So the patch will only install on a genuine 2.1 system ✅ — it refuses unknown versions ("USE AT YOUR
OWN RISK") and requires `uid=0(root)`. The mechanics of that self-extracting floppy (the 1 KB bootstrap
script, the `070701` cpio archive, the bundled `lha` and `apply`) are documented in detail on
[the patch floppy anatomy page](../boot-disks/anatomy-patch-adf.md).

**Why the version check matters for this matrix:** the `^2\.1` pattern is positive evidence that the
*patched* system still reports a `2.1`-prefixed version string — consistent with "2.1c" being a 2.1
sub-revision, and with there being **no separate 2.2** to match against. ✅

## Versions that do not exist 🔴

Two strings show up in secondary sources and search results. Neither is real; both are 🔴.

- **"Amix 2.2"** — 🔴 There is **no 2.2** in any primary source (no installer, no manual, no `uname`
  output). It is most likely a misremembering of **2.1c**. Do not cite a 2.2.
- **"Amix 2.1c, 1994"** (as listed on gunkies) — 🔴 The *version* 2.1c is real (it's the patch-2a
  kernel, above), but the **1994 date is almost certainly wrong**: Commodore's Amix support ended in
  **1993**, and Commodore itself went bankrupt in **April 1994** ✅. Treat the 1994 attribution as
  erroneous; 2.1c is a *post-1992* community patch, not a 1994 product.

When you encounter either string in the wild, map it back to **2.1 / 2.1 patch 2a (kernel 2.1c)** and
move on.

## Kernel-image name: `rdbunix` → `relocunix` 🟡

A naming detail that trips up anyone cross-reading the 1990 paper against modern repos: **the bootable
kernel image was renamed across versions** 🟡.

| Era / source | Kernel-image name | Where it appears |
|---|---|---|
| 1990 Ditto paper | `rdbunix` | "Adding a device driver" build step |
| 2.1 / modern repos | `relocunix` | `make bootpart KERNEL=relocunix`; the four driver repos |

On a modern 2.1 system the build/install step is, for example:

```sh
make install                      # produces relocunix
cp relocunix /stand
make bootpart KERNEL=relocunix    # writes the boot partition
```

This is **🟡 a historical rename** — same role (the relinked, boot-partition kernel image), different
filename — and it should be verified per version if you ever work with pre-2.1 media. The running
kernel itself is `/unix`; `rdbunix`/`relocunix` is the image written to the boot partition. See the
[boot process](../how-it-works/boot-process.md) and [kernel build](../drivers/kernel-build.md) pages
for how that image is produced and installed.

## How to read your own system's version

On a running system, the authoritative version string is whatever `uname` reports:

```sh
uname -v      # version string the patch greps, e.g. matches ^2\.1.* 08004..$
uname -a      # full string incl. m68k-cbm-sysv4 platform
```

The platform string is `m68k-cbm-sysv4` ✅. If `uname -v` shows a `2.1`-prefixed string ending in an
`08004..` build number, you are on retail 2.1 or its 2.1c patch level — that is the only version family
you are realistically going to meet today.

## See also
- [What Amix is](../how-it-works/overview.md) — lineage, SVR3-vs-SVR4, and the one-page timeline.
- [Patch floppy anatomy](../boot-disks/anatomy-patch-adf.md) — how the 2.1 → 2.1c patch ADF is built and applied.
- [Boot process](../how-it-works/boot-process.md) — where the `relocunix`/`rdbunix` image fits in the boot path.
- [Glossary](../how-it-works/glossary.md) — SVR4, 3B2, RDB, and other terms used above.

## Sources
- Research brief §1 (Identity / lineage / history, including the version matrix) and §13 (open
  questions / conflicts), `sources/research-brief.md`.
- `amix_21_patch.adf` analysis via `tools/inspect-adf.sh` — the patch's self-identification string and
  the `^2\.1.* 08004..$` `uname -v` guard (brief §1, §10).
- Ditto, *Writing Amix Device Drivers*, **1990 European Amiga Developer's Conference** (the local PDF)
  — `rdbunix` kernel-image name and the "Adding a device driver" build step.
- The modern driver repos for the `relocunix` name and `make bootpart KERNEL=relocunix`:
  [asokero/va2000-amix](https://github.com/asokero/va2000-amix),
  [isoriano1968/hydra-amix](https://github.com/isoriano1968/hydra-amix).
- Install media and historical/version pages: [amigaunix.com](https://www.amigaunix.com/doku.php/home);
  installers on [archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix).
- The disputed "2.1c, 1994" listing originates from the Gunkies wiki; the "2.2" string has no primary
  source (brief §1, §13).
