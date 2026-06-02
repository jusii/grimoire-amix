---
title: grimoire-amix
summary: Map of the Amix documentation — how Amix works, developing for it, and custom boot disks.
status: reviewed
---

# grimoire-amix

Documentation for **Amiga Unix (Amix)** — Commodore's port of AT&T System V Release 4 (SVR4) to
68030 Amigas. Written for **both humans and LLM agents**: every page is plain Markdown with stable
headings, exact commands, and inline source-confidence tags (✅ verified · 🟡 community-reported ·
🔴 unverified/disputed).

> **New here?** Read [What Amix Is](how-it-works/overview.md), then jump to
> [Running Amix in WinUAE](getting-started/emulation-winuae.md) to get a system booting.
>
> **An AI agent?** Start from [`../llms.txt`](../llms.txt) or the whole-corpus
> [`../llms-full.txt`](../llms-full.txt); the grounding facts live in
> [`../sources/research-brief.md`](../sources/research-brief.md); the rules are in
> [`../AGENTS.md`](../AGENTS.md).

## Reading paths

**I want to run Amix** → [Hardware](how-it-works/hardware.md) →
[WinUAE](getting-started/emulation-winuae.md) / [FS-UAE](getting-started/emulation-fs-uae.md) →
[Install walkthrough](getting-started/install-walkthrough.md) →
[First login](getting-started/first-login-and-tour.md).

**I want Amix on my network** → [Putting Amix on your real LAN](getting-started/networking-on-the-lan.md)
(Amiberry A2065 → TAP + proxy-ARP; static IP, DNS, internet, persistent).

**I want to write a driver** → [Driver model](drivers/driver-model.md) →
[Kernel build](drivers/kernel-build.md) →
[Char driver (par.c)](drivers/writing-a-char-driver.md) or
[STREAMS driver (hydra)](drivers/writing-a-streams-driver.md) →
[Toolchain](drivers/toolchain.md) → the [case studies](drivers/case-studies/va2000.md).

**I want to ship drivers to users** → [Boot floppy anatomy](boot-disks/anatomy-boot-adf.md) →
[Reverse-engineering the boot floppy](boot-disks/reverse-engineering-boot-adf.md) →
[Adding drivers to a custom boot disk](boot-disks/adding-drivers-to-boot-disk.md) →
[Tooling pipeline](boot-disks/build-pipeline.md).

## Sections

### How Amix works
[Overview](how-it-works/overview.md) ·
[Hardware](how-it-works/hardware.md) ·
[Boot process](how-it-works/boot-process.md) ·
[Kernel architecture](how-it-works/kernel-architecture.md) ·
[Filesystems & disks](how-it-works/filesystems-and-disks.md) ·
[Networking](how-it-works/networking.md) ·
[X11 & desktop](how-it-works/x11-and-desktop.md) ·
[Quirks](how-it-works/quirks.md) ·
[Glossary](how-it-works/glossary.md)

### Getting started (emulation-first)
[WinUAE](getting-started/emulation-winuae.md) ·
[FS-UAE](getting-started/emulation-fs-uae.md) ·
[Amiberry status](getting-started/emulation-amiberry.md) ·
[On your real LAN (Amiberry)](getting-started/networking-on-the-lan.md) ·
[Install walkthrough](getting-started/install-walkthrough.md) ·
[Real hardware](getting-started/real-hardware.md) ·
[First login & tour](getting-started/first-login-and-tour.md)

### Driver & software development
[Driver model](drivers/driver-model.md) ·
[Kernel build](drivers/kernel-build.md) ·
[Char driver](drivers/writing-a-char-driver.md) ·
[STREAMS driver](drivers/writing-a-streams-driver.md) ·
[Zorro AUTOCONFIG](drivers/zorro-autoconfig.md) ·
[X11 RTG drivers](drivers/x11-rtg-drivers.md) ·
[Toolchain](drivers/toolchain.md) ·
Case studies: [va2000](drivers/case-studies/va2000.md) ·
[xrtg](drivers/case-studies/xrtg.md) ·
[lszorro](drivers/case-studies/lszorro.md) ·
[hydra](drivers/case-studies/hydra.md)

### Custom boot & install disks
[Boot floppy](boot-disks/anatomy-boot-adf.md) ·
[Root floppy](boot-disks/anatomy-root-adf.md) ·
[Patch floppy](boot-disks/anatomy-patch-adf.md) ·
[Reverse-engineering the boot floppy](boot-disks/reverse-engineering-boot-adf.md) ·
[Adding drivers](boot-disks/adding-drivers-to-boot-disk.md) ·
[Tooling pipeline](boot-disks/build-pipeline.md)

### Reference
[Versions](reference/versions.md) ·
[Device & card list](reference/device-list.md) ·
[Command cheat sheet](reference/commands-cheatsheet.md) ·
[Bibliography](reference/bibliography.md)

### Contributing
[Style guide](contributing/style-guide.md) ·
[Writing for LLMs](contributing/writing-for-llms.md)

## Sources
- [`../sources/research-brief.md`](../sources/research-brief.md) (grounding synthesis with citations)
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) (cross-linked community wiki)
