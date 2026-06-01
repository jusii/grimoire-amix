# Amix-docs

Developer- and LLM-oriented documentation for **Amiga Unix (Amix)** — Commodore's port of AT&T
System V Release 4 (SVR4) to 68030 Amigas (the A3000UX and A2500UX).

It covers three things the existing community wiki doesn't:

1. **How Amix actually works** — kernel architecture, the boot path, hardware constraints.
2. **How to develop software and device drivers for it** — grounded in Michael Ditto's 1990 driver
   paper and the modern `va2000` / `xrtg` / `lszorro` / `hydra` driver repos.
3. **How to build custom boot/install disks with extra hardware drivers** — reverse-engineered from
   the real 2.1 boot/root/patch floppies, with reproducible tooling.

This is an **independent** resource that **cross-links** to
[amigaunix.com](https://www.amigaunix.com/doku.php/home) (the established wiki for end-user, install,
and historical material). We go deeper on development.

## Built for humans *and* LLMs

The docs are plain Markdown so they render on GitHub and ingest cleanly into AI agents. Conventions:

- **One topic per file**, stable headings, exact commands and device numbers over vague prose.
- **Inline source-confidence tags** — ✅ verified · 🟡 community-reported · 🔴 unverified/disputed —
  because a lot of Amix lore is wrong, and an obscure system deserves traceable claims.
- **`llms.txt`** (curated index) and **`llms-full.txt`** (whole corpus in one file) for agents.
- **`sources/research-brief.md`** is the single grounding source of truth (facts + citations).
- **`AGENTS.md`** is the contributor contract (human and AI).

## Layout

```
docs/            the documentation (start at docs/index.md)
  how-it-works/  what Amix is, hardware, boot, kernel, filesystems, networking, X11, quirks
  getting-started/ emulation (WinUAE/FS-UAE), install walkthrough, real hardware, first login
  drivers/       driver model, kernel build, char & STREAMS drivers, toolchain, case studies
  boot-disks/    boot/root/patch floppy anatomy + building custom driver disks
  reference/     versions, device list, command cheat sheet, bibliography
  contributing/  style guide, writing for LLMs
tools/           reproducible scripts: inspect-adf, unpack-root, build-custom-bootdisk, gen-llms-full
sources/         primary materials (gitignored binaries) + research-brief.md + checksums + provenance
llms.txt         curated LLM index
AGENTS.md        contributor contract
```

## Quick start

```sh
# Read the map
$EDITOR docs/index.md          # or just browse on GitHub

# Inspect a (user-supplied) Amix floppy image
tools/inspect-adf.sh path/to/amix_2.1_boot.adf

# Regenerate the LLM full-corpus file after editing docs
tools/gen-llms-full.sh
```

## Status

Early but substantive. Most pages are `status: draft` (machine-authored from the research brief, then
fact-checked against it); they will move to `status: reviewed` as humans verify them — ideally against
real hardware and emulators. Contributions and corrections welcome; see
[`AGENTS.md`](AGENTS.md) and [`docs/contributing/style-guide.md`](docs/contributing/style-guide.md).

## Licensing

Documentation and tooling in this repo are original work. The Amix operating system, its install media
(ADFs/HDFs/tapes), and Commodore's scanned manuals are **proprietary Commodore-Amiga material** —
widely treated as abandonware but not licensed for redistribution. We do **not** ship those files; we
cite and analyze them, and the tooling operates on **user-supplied** images. See
[`sources/NOTES.md`](sources/NOTES.md).
