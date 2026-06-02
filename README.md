# Amix-docs

Developer- and LLM-oriented documentation for **Amiga Unix (Amix)** — Commodore's port of AT&T
System V Release 4 (SVR4) to 68030 Amigas (the A3000UX and A2500UX).

> ⚠️ **AI-assisted — verify before trusting.** This documentation was created with heavy use of LLM
> tools; much of it is machine-authored and **not all of it has been proofread or tested on real
> hardware.** Don't take everything here as fact. Pages carry confidence tags (✅ verified ·
> 🟡 community-reported · 🔴 unverified) and cite their sources — check against those before relying on
> anything. Corrections welcome.

It covers three things the existing community wiki doesn't:

1. **How Amix actually works** — kernel architecture, the boot path, hardware constraints.
2. **How to develop software and device drivers for it** — grounded in Michael Ditto's 1990 driver
   paper and the modern `va2000` / `xrtg` / `lszorro` / `hydra` driver repos.
3. **How to build custom boot/install disks with extra hardware drivers** — reverse-engineered from
   the real 2.1 boot/root/patch floppies, with reproducible tooling.

This is an **independent** resource that **cross-links** to
[amigaunix.com](https://www.amigaunix.com/doku.php/home) (the established wiki for end-user, install,
and historical material). We go deeper on development.

**Start here → [docs/index.md](docs/index.md)** — the full map, with reading paths for running Amix,
writing drivers, and building boot disks. A few entry points:
[How Amix boots](docs/how-it-works/boot-process.md) ·
[Kernel architecture](docs/how-it-works/kernel-architecture.md) ·
[The driver model](docs/drivers/driver-model.md) ·
[Reverse-engineering the boot floppy](docs/boot-disks/reverse-engineering-boot-adf.md) ·
[Putting Amix on your real LAN](docs/getting-started/networking-on-the-lan.md).

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
  getting-started/ emulation (WinUAE/FS-UAE/Amiberry), putting Amix on your LAN, install walkthrough, real hardware, first login
  drivers/       driver model, kernel build, char & STREAMS drivers, toolchain, case studies
  boot-disks/    boot/root/patch floppy anatomy + building custom driver disks
  reference/     versions, device list, command cheat sheet, bibliography
  contributing/  style guide, writing for LLMs
tools/           reproducible scripts: inspect-adf, extract-kernel, build-bootfloppy, unpack-root, build-custom-bootdisk, gen-llms-full; host-net/ (put Amix on your LAN)
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

## License

The documentation and tooling in this repo are original work, released under the
**[MIT License](LICENSE)**.

The Amix operating system, its install media (ADFs/HDFs/tapes), and Commodore's scanned manuals are
**proprietary Commodore-Amiga material** — widely treated as abandonware but not licensed for
redistribution. They are **not** included here; the tooling operates on **user-supplied** images, and
we only cite and analyze them. Download them yourself from
[amigaunix.com → Downloads](https://www.amigaunix.com/doku.php/downloads) or the
[Internet Archive](https://archive.org/details/commodore-amiga-operating-systems-amix), and verify
against [`sources/CHECKSUMS.txt`](sources/CHECKSUMS.txt). See [`sources/NOTES.md`](sources/NOTES.md)
for full provenance.
