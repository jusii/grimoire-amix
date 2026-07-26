---
title: What Amix Is
summary: Amix in one page — SVR4/3B2 lineage, what it is and is not, and the version timeline.
status: draft
---

# What Amix Is

**Amix is Commodore's port of AT&T UNIX System V Release 4 (SVR4) to the Motorola 68030 Amiga.** ✅
The kernel platform string is `m68k-cbm-sysv4`. It is a *monolithic* SVR4 system that treats the
Amiga as a generic 68030 Unix workstation: **no AmigaOS compatibility layer**, and it does **not** use
the Amiga custom chips (Agnus / Denise / Paula). ✅ If you know SVR4 on any other 68k or 3B2 machine,
you already know most of Amix.

This page is the one-screen orientation. For the deeper mechanics, follow the cross-links to
[hardware](hardware.md), the [boot process](boot-process.md), the
[kernel architecture](kernel-architecture.md), and the full
[version reference](../reference/versions.md). For end-user history and install media, the
authoritative community resource is [amigaunix.com](https://www.amigaunix.com/doku.php/home).

## Lineage: ported from the AT&T 3B2 codebase

Amix was a **direct port of AT&T's 3B2 (WE32x00) SVR4 codebase**, not an evolution of a pre-existing
68k Unix. 🟡 (amigaunix.com states this but hedges — "it appears that … 3B2 codebase"; corroborated by
EAB/datagubbe, but no primary citation.) Commodore chose the 3B2 source for licensing-cost reasons rather than starting from a
native m68k tree, which is why several defaults (for example the System V `s5` filesystem default —
see [filesystems and disks](filesystems-and-disks.md)) look like 3B2 inheritances 🟡 (exact rationale
unconfirmed). The port was led
by **Michael Ditto**, "Unix Systems Software Architect" at Commodore from 1988 to 1991. ✅
Contemporaries describe the effort as "quick and dirty." ✅

The opening line of [Ditto's own driver paper](../reference/bibliography.md) calls Amix
*"a direct port of the AT&T Unix System V operating system … essentially identical to … System V
Release 4."* ✅ That paper — *Writing Amix Device Drivers*, presented at the **1990 European Amiga
Developer's Conference** — is the single most authoritative primary source on how the system is built,
and it grounds the [driver model](../drivers/driver-model.md).

🟡 Sun Microsystems twice explored OEM-selling the A3000UX as an entry-level workstation; both deals
fell through.

## What Amix is — and what it is not

**Amix is:**

- ✅ A monolithic SVR4 Unix for the 68020/68030 Amiga, identified as `m68k-cbm-sysv4`.
- ✅ A standards-era SVR4: **STREAMS** networking, **TLI** plus BSD sockets, POSIX.1, `init` /
  `/etc/inittab` / run levels, virtual consoles on **Alt+F1..F8**, and SVR4 packaging
  (`pkgadd` / `pkgmk` / `pkgtrans`). See [kernel architecture](kernel-architecture.md).
- ✅ A real workstation OS with X11, TCP/IP, and NFS — see [networking](networking.md) and
  [X11 and the desktop](x11-and-desktop.md).

**Amix is not:**

- ✅ **Not** AmigaOS-compatible. There is no Amiga binary compatibility, no AmigaDOS, no Workbench.
  Dual-boot between Amix and AmigaOS is handled at the ROM level (the "Superkickstart" bootstrap),
  not by any in-OS shim — see the [boot process](boot-process.md).
- ✅ **Not** a user of the Amiga custom chipset. Graphics, sound, and timing go through generic Unix
  paths, not Agnus/Denise/Paula. (There is no audio support at all. 🟡)
- ✅ **Not** loadable-module based. Drivers are statically linked into the kernel; adding one means
  editing `kernel.c` and relinking `/unix`. See the [driver model](../drivers/driver-model.md).
- ✅ **Not** runnable on every Amiga. It needs a 68020/68030 **with a real MMU** and a hardware FPU,
  tops out at **16 MB of Fast RAM**, supports **Zorro II only**, and does **not** run on the
  68040/68060 (so the A4000 cannot officially run it). The hard limits are detailed on the
  [hardware](hardware.md) page and the [quirks](quirks.md) checklist; the 040/060 situation has
  [its own status page](68040-68060-status.md).

## History at a glance

- 🟡 **First public demo:** Uniforum, Dallas, **January 1988**, on an A2500UX — at that point still
  SVR3, not SVR4. (The 1988 Uniforum Dallas demo is documented; the *machine* and *month* are
  community-reported, not in primary sources.)
- ✅ **Commercial window:** roughly **1991–1992**.
- ✅ **Support ended 1993.** Commodore filed for bankruptcy in April 1994.

The SVR4 product line proper begins with the 1991 releases and ends with the **2.1** retail release of
February 1992 🟡 (the *month* is community-reported — sources confirm only the year), after which only an unofficial patch series continued. The full timeline is below; the
[versions reference](../reference/versions.md) carries the per-release detail.

## Version matrix

The releases, with confidence tags carried straight from the research brief:

| Version | Date | Notes | Tag |
|---|---|---|---|
| SVR3.x precursors | 1988–89 | A2500UX demos (68020 → 68030); proprietary windowing, not yet SVR4 | 🟡 |
| 1.1 | 1991 | First widely-referenced SVR4 release; mono X reported "slow as molasses" | 🟡 |
| 2.0 / 2.01 / 2.03 | 1991 | Color X via the A2410; archive.org carries 2.01 and 2.03 installers | 🟡 |
| **2.1** | **Feb 1992** 🟡 | **Last retail release** ✅ (month community-reported). Ships pre-formatted man pages only (nroff sources dropped) | ✅ |
| 2.1 patch 2a → kernel **2.1c** | post-1992 | Unofficial but considered definitive; inet / NFS / Y2K fixes | ✅ |

**Notes on the matrix:**

- ✅ The locally analysed install media is **2.1**. The boot, root, and patch floppies are named
  `amix_21_boot.adf`, `amix_21_root.adf`, and `amix_21_patch.adf`; see their anatomies under
  [boot-disks](../boot-disks/anatomy-boot-adf.md) and the
  [install walkthrough](../getting-started/install-walkthrough.md).
- ✅ The **patch disk** self-identifies as *"Patch Disks 1 and 2 for International, USA-Only, 2-user,
  and Unlimited-User Amiga UNIX System V Release 4.0 Version 2.1."* It greps the live `uname -v` for
  `^2\.1.* 08004..$` before applying, which is why the patch path lands on kernel **2.1c**. See the
  [patch disk anatomy](../boot-disks/anatomy-patch-adf.md).

**Two things that do *not* exist (do not propagate the lore):**

- 🔴 **"Amix 2.2" does not exist** in any primary source. It is most likely confusion with kernel
  **2.1c**. Do not cite a 2.2 release.
- 🔴 The "2.1c, 1994" date seen on some wiki pages is almost certainly wrong — support ended in 1993.

## Where to go next

- New to the system and want it running? Start with [emulation under WinUAE](../getting-started/emulation-winuae.md)
  and the [install walkthrough](../getting-started/install-walkthrough.md).
- Want the machine and the limits? See [hardware](hardware.md).
- Want to understand the kernel and write a driver? See [kernel architecture](kernel-architecture.md)
  and the [driver model](../drivers/driver-model.md).
- Hit something strange? The [quirks](quirks.md) page is the catalogue of gotchas.

## See also

- [Hardware and requirements](hardware.md) — CPU/MMU/FPU rules, the 16 MB ceiling, Zorro II only.
- [How Amix boots](boot-process.md) — Superkickstart, the bootstrap, and the compressed kernel.
- [Kernel architecture](kernel-architecture.md) — monolithic SVR4, STREAMS, static drivers.
- [Versions reference](../reference/versions.md) — the per-release detail behind the matrix above.
- [Glossary](glossary.md) — SVR4, STREAMS, RDB, Zorro, and other jargon.
- [amigaunix.com — history](https://www.amigaunix.com/doku.php/history) — community history and lore.

## Sources

- Research brief §1 (identity, lineage, history; version matrix) — `sources/research-brief.md`.
- Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference
  (opening line on direct-port lineage) — see [bibliography](../reference/bibliography.md).
- `amix_21_patch.adf` analysis via `tools/inspect-adf.sh` (the `Version 2.1` self-identification and
  the `^2\.1.* 08004..$` `uname -v` check).
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) and its
  [history page](https://www.amigaunix.com/doku.php/history) (community-reported timeline; 🟡 items).
- en.wikipedia.org/wiki/Amiga_Unix and /wiki/Amiga_3000UX (background; corroborating the demo and
  commercial dates).
