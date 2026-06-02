---
title: Bibliography & Sources
summary: Primary and secondary sources behind this documentation.
status: draft
---

# Bibliography & Sources

This page is the master source list behind grimoire-amix. It splits into **primary sources** (the Ditto
driver paper, the three install floppies we analyse locally, the four modern driver repos, AT&T's
SVR4 documentation, and the scanned Commodore manuals on archive.org) and **community / reference
sources** (amigaunix.com, encyclopedias, blogs, Usenet, emulator issue trackers, and the emulator
docs). Every `docs/` page ends with its own `## Sources` list citing the specific items below; this
page is where those citations resolve.

The hierarchy we apply everywhere, per the [contributor contract](../../AGENTS.md): **primary manuals
/ the Ditto driver paper / the real disk images and repo source > archived Usenet
(comp.unix.amiga) > forum lore.** Confidence tags (✅ verified, 🟡 community-reported,
🔴 unverified/disputed) are carried from the research brief into every page; this page is mostly a
catalogue, so it is lightly tagged.

**Licensing note (read before downloading anything).** ✅ The Amix distribution, the boot/root/patch
floppy images, the hardfiles, tape images, and the scanned manuals are **proprietary Commodore
material**, treated as abandonware but **not licensed for redistribution**. We never commit them to
this repository (they are `.gitignore`d) and we never tell you to. We refer to them by name and
checksum and point you at [amigaunix.com](https://www.amigaunix.com/doku.php/home) and
[archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix) to obtain them
yourself. All tooling in this repo operates on **user-supplied** images.

## Primary sources

These are the top of the source-of-truth hierarchy. When a primary source and forum lore disagree,
the primary source wins.

### The Ditto driver paper

- **Michael Ditto, *Writing Amix Device Drivers*** — presented at the **1990 European Amiga
  Developer's Conference**. ✅ This is the authoritative driver specification, written by the Amix
  porter himself ("Unix Systems Software Architect" at Commodore, 1988–1991). It grounds the
  [driver model](../drivers/driver-model.md), the [char-driver walkthrough](../drivers/writing-a-char-driver.md),
  and the [STREAMS-driver walkthrough](../drivers/writing-a-streams-driver.md).
- **Citation caveat ✅:** cite it as the **1990 European Amiga Developer's Conference** — the page
  headers in the PDF read exactly that. The local PDF *filename* says "North American," which is
  inaccurate; do not propagate it.
- **Edition caveat ✅:** the scan has **22 unique pages; pages 23–44 are a duplicate re-scan** of the
  same content. The `par(7A)` man page (the worked char-driver example) is on **p. 22**. Cite specific
  page numbers from the first 22-page run (e.g. "Ditto paper p. 22").
- Held locally as `sources/pdf/Writing Amix Device Drivers …(2).pdf`. **Not redistributable** — obtain
  via amigaunix.com / archive.org. SHA-256 in `sources/CHECKSUMS.txt`.

### The three install floppies (our local analysis)

The differentiator of this project: we inspect the real Amix 2.1 install media with
`tools/inspect-adf.sh <image>` and ground the [boot-disk anatomy](../boot-disks/anatomy-boot-adf.md)
pages on byte-level findings rather than lore. All three are **proprietary, gitignored, and obtained
by the reader** — checksums live in `sources/CHECKSUMS.txt`.

| Image (gitignored) | What it is | Grounds |
|---|---|---|
| `amix_21_boot.adf` | ✅ AmigaDOS OFS bootblock + Amix secondary bootstrap + compressed install kernel | [anatomy-boot-adf](../boot-disks/anatomy-boot-adf.md) |
| `amix_21_root.adf` | ✅ UFS miniroot: installer ELF (m68k) binaries + install shell scripts | [anatomy-root-adf](../boot-disks/anatomy-root-adf.md), [install walkthrough](../getting-started/install-walkthrough.md) |
| `amix_21_patch.adf` | ✅ Self-extracting "Patch Disks 1 & 2" for Amix SVR4 2.1 (→ kernel 2.1c) | [anatomy-patch-adf](../boot-disks/anatomy-patch-adf.md) |

Cite local analysis in the form **"`amix_21_root.adf` analysis via `tools/inspect-adf.sh`"** so any
reader can reproduce the finding against their own copy. The deeper unpack of the root miniroot uses
`tools/unpack-root.sh`.

### The four modern driver repositories

All four are recent, AI-assisted hobby drivers targeting **Amix 2.1p2a on an Amiga 3000 / 68030 /
Zorro II**. ✅ Their READMEs and source ground the [driver case studies](../drivers/case-studies/va2000.md)
and much of the [driver model](../drivers/driver-model.md). All are source-only (building them needs a
licensed Amix install and headers).

| Repository | What it is | Case study |
|---|---|---|
| <https://github.com/asokero/va2000-amix> | ✅ Char framebuffer driver for the MNT VA2000 RTG card (`/dev/va2000`, char major 68) | [va2000](../drivers/case-studies/va2000.md) |
| <https://github.com/asokero/xrtg-amix> | ✅ X11R5 server (`Xrtg`) for the VA2000 (needs the va2000 driver) | [xrtg](../drivers/case-studies/xrtg.md) |
| <https://github.com/asokero/lszorro-amix> | ✅ Userspace `lspci`-style Zorro II scanner | [lszorro](../drivers/case-studies/lszorro.md) |
| <https://github.com/isoriano1968/hydra-amix> | ✅ STREAMS/DLPI network driver for the Hydra AmigaNet card (`cdevsw` slot 47, `hya`) | [hydra](../drivers/case-studies/hydra.md) |

🟡 An earlier research note claimed "asokero handle not found / isoriano1968 only does AmigaOS Mesa."
That note is **wrong** — these four repos exist and are the project's centerpiece examples.
🔴 No public, reproducible build recipe for the `m68k-amix-gcc` cross-compiler was found; it appears
to be a private build needing Amix SVR4 headers/libs. See the [toolchain](../drivers/toolchain.md) page,
which flags this as an open gap.

### AT&T SVR4 documentation

Because Amix is "essentially identical to System V Release 4," the generic AT&T SVR4 manuals are
authoritative for everything the Ditto paper does not cover specifically. ✅

- **AT&T SVR4 *DDI/DKI Reference Manual*** (Device Driver Interface / Driver–Kernel Interface) — the
  reference for kernel APIs Amix drivers call (`copyin`/`copyout`, `uiomove`, `sleep`/`wakeup`,
  `timeout`/`untimeout`, the `cdevsw`/`bdevsw` switch structures, and so on).
- **AT&T SVR4 *Streams Programmer's Guide*** and ***Network Programmer's Guide*** — the references for
  STREAMS and TLI, which ground the [STREAMS-driver walkthrough](../drivers/writing-a-streams-driver.md)
  and [networking](../how-it-works/networking.md).
- **Books the Ditto paper cites as background:** Egan & Teixeira, *Writing a UNIX Device Driver*
  (Wiley, 1988); Bach, *The Design of the UNIX Operating System* (1986); Kernighan & Pike, *The UNIX
  Programming Environment* (1984).
- 🔴 **No Amix-specific *Programmer's Guide* or *Driver Reference* has been found archived.** Use the
  generic SVR4 DDI/DKI plus the Ditto paper; do not cite an "Amix Driver Reference" that does not exist.

### Scanned Commodore manuals (archive.org)

✅ The official end-user manuals, scanned and hosted on the Internet Archive (proprietary;
view/download from archive.org, do not redistribute through this repo):

- **The 1990 Commodore manual set:** *Installing Amiga UNIX*, *Using Amiga UNIX*, and *Learning Amiga
  UNIX*.
- The Amix collection on the Internet Archive:
  <https://archive.org/details/commodore-amiga-operating-systems-amix>
- **amigaunix.com *V2.1 Addendum* PDF** — the 2.1-specific addendum to the manual set, hosted on
  amigaunix.com.

## Community & reference sources

These are credible but, per the hierarchy, rank below the primary sources. Most claims grounded only
here carry a 🟡 tag in the docs.

### amigaunix.com (the authoritative community resource)

amigaunix.com is a DokuWiki and the most authoritative community resource for end-user, historical,
and install-media material. grimoire-amix **cross-links** to it rather than duplicating it — we go deeper
on development. The pages we cite:

- Home / portal — <https://www.amigaunix.com/doku.php/home>
- History — <https://www.amigaunix.com/doku.php/history>
- Requirements — <https://www.amigaunix.com/doku.php/requirements>
- Installation — <https://www.amigaunix.com/doku.php/installation>
- Networking — <https://www.amigaunix.com/doku.php/networking>
- X11 — <https://www.amigaunix.com/doku.php/x11>
- More software — <https://www.amigaunix.com/doku.php/more_software>
- Tips & tricks — <https://www.amigaunix.com/doku.php/tips-tricks>
- Patch disk — <https://www.amigaunix.com/doku.php/patch-disk>
- Y2K / DST — <https://www.amigaunix.com/doku.php/y2k-dst>
- A2232 serial — <https://www.amigaunix.com/doku.php/a2232>
- Tape creation — <https://www.amigaunix.com/doku.php/tape-creation>
- Dual boot — <https://www.amigaunix.com/doku.php/dual-boot>
- File transfers — <https://www.amigaunix.com/doku.php/file-transfers>
- Boxed (the retail product) — <https://www.amigaunix.com/doku.php/boxed>
- Downloads (AmixBP, V2.1 Addendum) — <https://www.amigaunix.com/doku.php/downloads>
- vi editor — <https://www.amigaunix.com/doku.php/vi-editor>

🟡 Where amigaunix.com conflicts with a less authoritative community source — for example the
X11R4-vs-R5 "default" question — we follow amigaunix.com (it says R4 is the default) and flag the
conflict. See [X11 and the desktop](../how-it-works/x11-and-desktop.md).

### Encyclopedias

- **Wikipedia — Amiga Unix:** <https://en.wikipedia.org/wiki/Amiga_Unix> 🟡
- **Wikipedia — Amiga 3000UX:** <https://en.wikipedia.org/wiki/Amiga_3000UX> 🟡
- **HandWiki — Software:Amiga_Unix:** <https://handwiki.org/wiki/Software:Amiga_Unix> 🟡

🔴 Some wiki pages assert an "Amix 2.2" release and a "2.1c, 1994" date. Both are almost certainly
wrong: 2.2 does not appear in any primary source (likely confusion with kernel 2.1c), and support
ended in 1993. See the [versions reference](versions.md).

### Articles & blogs

- **OS News** coverage (Feb 2026) — osnews.com 🟡
- **datagubbe.se — Amix** — <https://datagubbe.se/amix/> 🟡 (the "quick and dirty," 3B2-lineage
  characterisation)
- **VirtuallyFun** (Jan 2013) — <https://virtuallyfun.com/2013/01/13/amix/> 🟡
- **ode2commies.blogspot.com** (2024) 🟡

### Usenet & forums (archived)

Per the hierarchy, archived **comp.unix.amiga** ranks above general forum lore.

- **comp.unix.amiga** — the period Usenet group, via Google Groups and narkive archives 🟡 (tape-free
  install procedures, networking workarounds, contemporary user reports).
- **English Amiga Board (EAB)** threads — 🟡 (the 3B2-codebase discussion, hardware lore).

### Emulator issue trackers & documentation

These ground the [getting-started / emulation](../getting-started/emulation-winuae.md) pages.

- **WinUAE** documentation — the reference emulation target; MMU emulation since 2.6.0 (2013). ✅ that
  MMU/FPU on and JIT off are required; several config values are 🟡. See
  [emulation under WinUAE](../getting-started/emulation-winuae.md).
- **FS-UAE** documentation — verified by amigaunix.com against FS-UAE 3.1.66 🟡. See
  [emulation under FS-UAE](../getting-started/emulation-fs-uae.md).
- **Amiberry issue #1376** — <https://github.com/BlitterStudio/amiberry/issues/1376> 🟡 — Amix
  currently does not boot under Amiberry (missing A3000 SCSI + tape emulation); the issue was
  closed-as-enhancement. Documented as "not currently working" in
  [emulation under Amiberry](../getting-started/emulation-amiberry.md).

## The `llms.txt` convention

This repository follows the **`llms.txt`** convention — a root-level, curated, Markdown index of the
site intended for LLM consumption, proposed by **Jeremy Howard (Answer.AI), September 2024**
(<https://llmstxt.org/>). ✅ In this repo:

- `llms.txt` (repo root) is the curated LLM index; keep it in sync when you add, rename, or move a page.
- `llms-full.txt` is the concatenated full corpus, regenerated by `tools/gen-llms-full.sh` after content
  changes.

See [writing for LLMs](../contributing/writing-for-llms.md) for how this shapes page structure.

## How to cite these sources on a page

Each `docs/` page ends with a `## Sources` list pointing at the specific items above. Use these forms
so a reader (human or agent) can resolve and reproduce them:

- **Ditto paper** — `Ditto paper p. N` (page from the first 22-page run; e.g. `Ditto paper p. 22`).
- **Local image analysis** — ``amix_21_root.adf`` analysis via `tools/inspect-adf.sh` (and
  `tools/unpack-root.sh` for the deeper miniroot unpack).
- **Repos** — the full GitHub URL (e.g. `https://github.com/asokero/va2000-amix`).
- **Brief** — `research brief §N` (`sources/research-brief.md`) for the internal grounding section.
- **Community** — the full URL (amigaunix.com page, Wikipedia, blog, EAB/Usenet, emulator issue).

## See also

- [Versions reference](versions.md) — the per-release detail, including the 🔴 "2.2" / "2.1c 1994" myths.
- [Device list reference](device-list.md) — major/minor numbers cited from the Ditto paper and the repos.
- [Driver model](../drivers/driver-model.md) — the page the Ditto paper most directly grounds.
- [Boot-disk anatomy: boot.adf](../boot-disks/anatomy-boot-adf.md) — where the local image analysis lands.
- [Writing for LLMs](../contributing/writing-for-llms.md) — the `llms.txt` convention in practice.
- [AGENTS.md](../../AGENTS.md) — the grounding, tagging, and licensing contract that this list serves.

## Sources

- Research brief §14 (bibliography seed) and §0 (local primary artifacts) — `sources/research-brief.md`.
- Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (held
  locally; **not redistributable**; SHA-256 in `sources/CHECKSUMS.txt`).
- `amix_21_boot.adf`, `amix_21_root.adf`, `amix_21_patch.adf` analysis via `tools/inspect-adf.sh`
  (and `tools/unpack-root.sh`).
- The four driver repos: <https://github.com/asokero/va2000-amix>,
  <https://github.com/asokero/xrtg-amix>, <https://github.com/asokero/lszorro-amix>,
  <https://github.com/isoriano1968/hydra-amix>.
- AT&T SVR4 *DDI/DKI Reference Manual*, *Streams Programmer's Guide*, *Network Programmer's Guide*.
- Commodore manuals on archive.org: *Installing / Using / Learning Amiga UNIX* (1990) —
  <https://archive.org/details/commodore-amiga-operating-systems-amix>; amigaunix.com *V2.1 Addendum* PDF.
- amigaunix.com DokuWiki — <https://www.amigaunix.com/doku.php/home> and the page list above.
- en.wikipedia.org/wiki/Amiga_Unix; en.wikipedia.org/wiki/Amiga_3000UX; HandWiki Software:Amiga_Unix.
- osnews.com (Feb 2026); <https://datagubbe.se/amix/>; <https://virtuallyfun.com/2013/01/13/amix/>;
  ode2commies.blogspot.com (2024).
- comp.unix.amiga (Google Groups / narkive); English Amiga Board threads.
- WinUAE / FS-UAE documentation; BlitterStudio/amiberry issue #1376
  (<https://github.com/BlitterStudio/amiberry/issues/1376>).
- The `llms.txt` convention — Jeremy Howard, Answer.AI, September 2024 (<https://llmstxt.org/>).
