---
title: Supported Hardware & Requirements
summary: The two official machines, the mandatory 68020/030+MMU+FPU CPU, the Fast RAM envelope (4 MB up — the old "16 MB hard ceiling" is retracted), the SCSI ID 6/4 rules, Zorro II only, and which expansion cards work.
status: draft
---

# Supported Hardware & Requirements

Amix runs on exactly two officially-supported Amigas — the **A3000UX** and the **A2500UX** — and on close equivalents you assemble from the same parts. The non-negotiable requirements are a **68020 or 68030 with a real MMU**, a **68881/68882 FPU**, **at least 4 MB of Fast RAM** (how much more depends on the kernel and the RAM layout — see [below](#fast-ram-4-mb-minimum-and-the-retracted-16-mb-hard-ceiling)), and SCSI disks wired to specific target IDs (the tape's ID 4 is hard-coded; the disk's ID 6 is a strong convention — see below). **Stock** Amix has **no 68040/68060 support** (so no stock A4000), and the **stock** drivers are **Zorro II only** — Zorro III boards need a driver that maps them (see [below](#zorro-iii-stock-support-is-zorro-ii-only)). The CPU limit is a stock-kernel limit: the public [68040/68060 port](68040-68060-status.md) lifts it, and Amix has booted to login on a real 68060 in an A4000T with a Z3660 (2026-09-25). ✅ (This whole page is uniformly ✅ unless a claim is tagged otherwise.)

If you are setting up an emulator instead of real iron, jump to [the WinUAE emulation guide](../getting-started/emulation-winuae.md), which encodes all of these limits as concrete config values. For the device-node side (major/minor numbers, `/dev` paths) see [the device list](../reference/device-list.md).

## The two official machines

### A3000UX

The flagship Amix machine — an Amiga 3000 configured and badged for Unix. ✅

| Component | Spec |
|---|---|
| CPU | 68030 @ 25 MHz |
| FPU | 68882 @ 25 MHz |
| Chip RAM | 1–2 MB |
| Fast RAM | up to 8 MB (as shipped; the old "16 MB kernel ceiling" is retracted — see below) |
| SCSI | on-board (A3000 SCSI) |
| Tape | A3070 QIC-150 |
| Ethernet | A2065 |
| Graphics (optional) | **A2410** color graphics card |
| Bootstrap ROM | "Superkickstart 1.4" |
| Mouse | 3-button |

The **"Superkickstart 1.4"** bootstrap ROM is the dual-boot mechanism: hold the **right mouse button at power-on** to load an AmigaOS Kickstart instead; the default action boots Amix. ✅ See [the boot process page](boot-process.md) for what happens after the ROM hands off.

### A2500UX

An Amiga 2500 sold pre-loaded with Amix. The "UX" suffix means *shipped with Amix pre-installed* — the hardware is otherwise identical to a standard A2500. ✅

| Component | Spec |
|---|---|
| Base | A2000 chassis |
| CPU/FPU board | **A2630** (68030 @ 25 MHz + 68882) |
| SCSI controller | A2090 or A2091 |

The first public Amix demo was an A2500UX at Uniforum, Dallas, January 1988 — running SVR3 at that point. 🟡 (The 1988 Uniforum Dallas demo is documented; the specific *machine* and *month* are community-reported, not in primary sources.) Early demo hardware used a 68020 that later transitioned to the 68030. 🟡 See [the overview](overview.md) for the full lineage.

## Minimum requirements and hard limits

These are not recommendations — they are enforced by the kernel and the install scripts. Violating them produces boot freezes, panics, or silently corrupted SCSI access.

### CPU, MMU, FPU — all three mandatory

- **CPU:** 68020 or 68030. ✅
- **MMU:** a *real* MMU is required. ✅ The kernel uses a full HAT (Hardware Address Translation) layer over the 68030 MMU; there is no software-MMU fallback. A plain 68000, or the MMU-less **68EC020/68EC030** parts, **cannot run Amix**. ✅
- **FPU:** a **68881 or 68882** floating-point unit is required. ✅ There is no soft-float build.

**The 68LC060 case.** A Z3660 can carry a **68LC060** — a
68060 without the FPU ✅. That does not affect Amix: the 68040/68060 kernels emulate floating point
in the kernel (the boot prints `no fpu detected` / `fpu emulation enabled`), so stock userland runs
✅ — see [the FPU-less 68060 lane](68040-68060-status.md#the-fpu-less-68060-lane-software-floating-point-on-real-silicon).
It does affect **AmigaOS** on the same card: software built for an FPU (`-m68881`) dies with a
Line-F exception on a 68LC060 unless an FPU emulation covers it ✅ — the Z3660's own exFAT handler,
built that way, takes that exception on a 68LC060 as soon as it mounts the SD card.

**Note:** "020/030 *with* MMU" excludes the cut-down EC variants specifically — the EC chips drop the MMU (and sometimes the FPU interface), which is exactly the hardware Amix depends on.

### Fast RAM: 4 MB minimum, and the retracted "16 MB hard ceiling"

- **Minimum:** 4 MB Fast RAM. ✅
- **The "16 MB hard ceiling" had the wrong mechanism, not the wrong symptom** ✅ (corrected 2026-09-29). It is not a RAM limit: the **stock** kernel registers the A3000's internal SCSI only when the loader has placed the kernel **above `0x07000000`** ([quirks §57](quirks.md#57-loader-placement-a3000-scsi)). On an A3000 with motherboard RAM only, that is the classic **16 MB** bank at `0x07000000`; a bigger motherboard bank starts lower (64 MB sits at `0x04000000`), the kernel loads at its base, no card 0 exists and root fails to mount (`s5mountroot VOP_OPEN error 6`) — measured on the bench with the stock kernel and a 64 MB bank, 2026-09-29 ✅. Kernels that **probe** for the controller instead of guessing (the A4091 project's patched 030 kernel runs 64 MB; the 68040/68060 kernels run **128 MB** on real silicon) are not affected ✅. The other real limit is the *describable-RAM* arena on the [RAM-ceiling page](ram-ceiling.md) ✅.
- **What does limit you:** the kernel can *describe* only so much RAM — ≈64 MB on the stock 68030 kernel's fixed arena, ≈128 MB on the 4 KB-page 68060 kernels — and past that it fails silently, not with a disk error ✅. On the Z3660 the firmware's `amix_ram` knob sizes the window (default 16, bounded 128) under the emulated modes; under the real-CPU mode the 128 MB card RAM is simply there ✅.
- **Running at _exactly_ 16 MB is proven safe** ✅ (measured 2026-07-22, when 16 MB was still believed to be a ceiling). At `a3000mem_size=16, mbresmem_size=0`, SCSI read + write/readback + double-read consistency are all clean, and a full base-set install reproduces its canonical tree digest byte-for-byte. So 16 MB is a correct working configuration, and for the stock kernel on an A3000's motherboard RAM the required one ([§57](quirks.md#57-loader-placement-a3000-scsi)); 32 and 64 MB run with a kernel that probes for the controller.

**The 8 MB memory-exhaustion livelock — and its diagnosis trap.** ✅ A memory-hungry workload on an under-provisioned (8 MB) box does **not** panic — it _livelocks_: network and console input both go dead, the framebuffer freezes at whatever was last on screen, and the emulator's host CPU pegs near 100 % indefinitely. The trap is that this reads exactly like a SCSI or network hang; the actual cause is RAM. The specific trigger seen was the package tool's cache/staging path double-materializing a package (fetch → cache file, then the installer's own `TMPDIR` re-spool — a ~35 MB working set) with no headroom to page it. The verify-in-place path and a plain install fit 8 MB comfortably, so the culprit is the extra transient footprint, not the base install. **If a box wedges with a pegged host CPU and no panic, suspect memory pressure before chasing the disk or the NIC.**

In emulation this translates to "present the RAM the kernel you run can use — **16 MB** of A3000 motherboard RAM for the stock kernel, up to 64 MB for a 030 kernel that probes for the A3000 SCSI, 128 MB on the 040/060 line — and never less than 8 MB." See [the WinUAE config table](../getting-started/emulation-winuae.md).

**A second, separate limit sits far above this one: total *describable* RAM.** ✅ Past roughly
**64 MB** on a stock 68030 kernel — a bound set by a fixed 4 MiB kernel arena, not by an arithmetic
accident, and reached at ≈128 MB only by a 4 KB-page 68060 kernel — the kernel's **unchecked
`rmalloc()` in `page_init()`** wild-writes a
60-byte stride from physical address 0 and the machine dies **silently, before any console output**
— a completely different mechanism and symptom from this section's SCSI mis-mapping, reached by any
route that hands the guest too much memory (debug/DDR windows, Zorro III RAM boards, accelerator
memory). Full mechanism, detection fingerprint and per-rig RAM guidance:
**[the Amix RAM ceiling](ram-ceiling.md)**.

_Sources: amix-packagemanager bench-RAM investigation 2026-07-22 (kernel sum-r 42265; digests
independently recomputed via `tools/repo/altroot_attest.py`); the 8 MB livelock + 16 MB clean runs
reproduced on Amiberry._

### SCSI target IDs

The installer and the installed system assume specific SCSI target IDs. One is genuinely fixed; the other is a strong convention. ✅

| Device | SCSI target ID | Why |
|---|---|---|
| **Hard disk** | **ID 6** (convention) | The installer *prompts* for the disk target and builds device names from it (`c${SCSI}d0s…`); ID 6 is what every manual and emulator assumes. Not a kernel mandate — see the note below. 🟡 |
| **Tape drive** | **ID 4** (required) | The installer hard-references the literal `/dev/rmt/4h` and looks nowhere else for the tape ✅ |

Evidence is in the install media itself: `amix_21_root.adf` references the tape as the literal `/dev/rmt/4h` but computes the boot partition device from a `$SCSI` *variable* — `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` — keyed on whatever disk target you pick. ✅ (Analysis via `tools/inspect-adf.sh amix_21_root.adf`.)

This is why emulator configs pin the disk hardfile to **SCSI ID 6** and the tape image to **SCSI ID 4**. Get the *tape* wrong and the install fails; the disk will install at another ID, but ID 6 is the path of least resistance — see below. See [the WinUAE guide](../getting-started/emulation-winuae.md).

**The disk does *not* have to be at ID 6 — but don't move it after install.** The root-floppy installer prompts for the disk's SCSI target and templates every device path from it (`/dev/dsk/c${SCSI}d0s…`); it only *reserves* ID 4 for the tape. So Amix installs fine on a disk at another target, and the Superkickstart ROM still boots it (it finds the bootable disk through the **RDB partition table**, not a fixed SCSI ID). The reason everyone uses 6 — and the reason it *feels* mandatory — is that whatever target you install at gets **baked into the device names** (`c6d0s…` at ID 6), which are then written into **`/etc/vfstab`** (the SVR4 filesystem mount table — what BSD calls `fstab`) and the boot partition. Change the disk's SCSI ID *after* install and those `c6d0s…` names no longer match the hardware, so the system can't find root or swap until you edit `/etc/vfstab` (and re-point the boot partition) accordingly. 🟡 (operator-reported; mechanism confirmed against the installer's `c${SCSI}d0s…` templating and amigaunix.com, which says "preferably … ID 6" for the disk but "won't look anywhere else than SCSI4" for the tape). The **tape, by contrast, is genuinely fixed at ID 4**.

### No 68040/68060 — and therefore no A4000

The **stock** Amix kernel **predates the 68040 MMU** and has no support for it (or the later 68060). ✅ Consequently the **A4000 cannot officially run stock Amix** ✅ — its standard 68040 CPU is exactly the part the stock kernel cannot drive. This is not a missing driver you could add: the MMU model differs, and moving the limit would be a kernel port (MMU, FPU context model, and exception frames all differ by CPU family). That port now exists: since 2026-09-19 the public [68040/68060 port](68040-68060-status.md) relinks your own stock kernel to boot on a 68040, 68060 or 68LC060, and it is **metal-proven** — Amix 2.1c boots to `login:` on a real 68060 (a 68LC060 on a Z3660 in an A4000T, 060-direct, 2026-09-25) ✅. What the port does, what it needs and what it still reports open are on [Amix on 68040 and 68060](68040-68060-status.md).

> **The blocker is the 68040 CPU, not the AGA chipset.** "No A4000" is about the processor/MMU, *not* AGA. An **030-based AGA** configuration (an accelerated A4000/030, or AGA in emulation) boots Amix to the **text console** fine 🟡 — AGA is **console-only**, though: Amix's **X11** server targets the supported display hardware (the **A2410** TIGA card, or the ECS framebuffer), not AGA. So with AGA you get the console but not X. (Operator-reported, 2026-06.) "Accelerated" matters: the **stock A4000/030's CPU card carries a 68EC030** — no MMU — so it cannot run Amix at all ✅; an A4000/030 needs a card with a full 68030 + MMU (or an accelerator's 68030 mode).

#### The AGA "white screen" was a Kickstart problem, not an Amix limit

🔴/✅ **Corrected finding (A4091-on-Amix project, reproduced locally in Amiberry).** The earlier belief that "Amix won't boot on AGA — you just get a white screen" was **not** an Amix limitation. The white screen came from the **Kickstart 2.04 (A3000) ROM, which has no AGA support**. With **Kickstart 3.0 (A4000)** (r39.106) — or KS 3.1 A4000 — Amix boots on an AGA chipset fine, and its **console even works** ✅. KS 3.0 also runs on the A3000, so **one Kickstart *version* spans both machines** ✅. In other words, "Amix on AGA" needs an AGA-aware bootstrap ROM, nothing more.

⚠️ **Do not conflate this with the 68040 limit above — they are separate facts.**

- This AGA result is about the **chipset + bootstrap ROM**, and it was proven with an **030 + AGA emulation profile** (Amiberry `chipset=aga` + a 68030 CPU), **not** a real 68040 A4000 🟡.
- A **real A4000 still has a 68040**, and **stock** Amix **still cannot run that CPU** (only the [68040/68060 port](68040-68060-status.md) can) (the MMU model differs — see above). The corrected finding does **not** mean "the A4000's 68040 works." It means: *the AGA chipset is fine with Amix once the bootstrap ROM understands AGA; the processor is the only remaining wall, and for the stock kernel it is unmoved.*

🟡 **Real-hardware validation is still pending** — a physical AGA-equipped, 68030-class machine (and a physical A4000+A4091) have not yet been booted; the result is emulation-proven only. The Kickstart matrix in [Amix on Amiberry](../getting-started/emulation-amiberry.md) encodes which ROM each chipset profile needs.

### Zorro III — stock support is Zorro II only

**Stock** Amix supports **Zorro II expansion only**; out of the box it has **no Zorro III support**. ✅ The stock drivers just dereference the address `autocon()` returns, which only reaches Zorro II boards (≤ 24-bit, inside [the identity-mapped low 1 GB](../drivers/zorro-autoconfig.md#the-identity-map)), and — because that kernel source was never shipped — the *stock* card set can't be patched in place. ✅ This is **not** a hard wall for a *purpose-written* driver, though: one that maps the board explicitly (the kernel's `sptalloc()` primitive, or a window that happens to fall inside the identity map) **can** reach a Zorro III board — the [A4091 SCSI driver](../drivers/a4091-53c710-driver.md) (🟡 emulation) and the [Z3660 ethernet driver](../drivers/z3660-ethernet-driver.md) (✅ real hardware) both do. For ordinary use, assume a card must work in (or fall back to) **Zorro II** address ranges.

Board addresses are assigned at reset by the Amiga **AUTOCONFIG** mechanism, which Amix reads through the kernel's `autocon()` interface — again, **Zorro II only**. ✅ See [the Zorro autoconfig driver page](../drivers/zorro-autoconfig.md) for how drivers consume this.

## Supported expansion cards

The following cards are known to work. Entries are ✅ unless tagged 🟡 (community-reported). For the full per-device table with major/minor numbers and `/dev` paths, see [the device list](../reference/device-list.md).

### SCSI controllers

| Card | Status | Notes |
|---|---|---|
| A3000 on-board SCSI | ✅ | The reference controller (A3000UX) |
| A2090 | ✅ | A2500UX option |
| A2091 | ✅ | A2500UX option |
| GVP Series II | 🟡 | Needs a kernel rebuild + an RDB `dummy_handler` |
| **A4091** | 🟡 | Zorro III SCSI-2 (NCR/Symbios **53C710**, AutoConfig product id `0x02020054`); driven by the modern [A4091 / 53C710 driver](../drivers/a4091-53c710-driver.md) — **boots Amix with root on the A4091** (emulation-proven; real-hardware pending) |

**On a multi-controller machine, the `cXd0` disk namespace binds to the _primary_ controller only** ✅. With two HBAs present (e.g. A3000 on-board SCSI plus an A4091), a disk at ID 6 on the A3000 reads as `c6d0` while the *same* disk moved to ID 6 on the A4091 is unreachable as `c6d0` (`dd` I/O error, `fsck` "Can't open"). So an install target — and anything else you address as `cXdN` — must sit on the primary controller. Secondary HBAs are still usable, but through a different addressing path: `cdfs` reaches a CD on a second controller by **`<card>,<unit>`** (HBA-enumeration order — e.g. an A3000-plus-A4091 box mounts the A4091's CD at `1,3`), not through the `cXd0` disk names.

### Graphics

| Card | Status | Notes |
|---|---|---|
| Built-in (mono) | ✅ | Drives the monochrome X server |
| **A2410** "Lowell" | ✅ | TMS34010, 1024×768, native color support |
| Picasso II / Piccolo / Domino / etc. | 🟡 | Via *Gateway! Vol.2* CD drivers — **Zorro II / linear modes only** |

There is also a modern RTG path: the [MNT VA2000 char framebuffer driver](../drivers/case-studies/va2000.md) plus the [Xrtg X11R5 server](../drivers/case-studies/xrtg.md), both Zorro II.

### Network

| Card | Status | Notes |
|---|---|---|
| **A2065** | ✅ | Native Ethernet (LANCE); device `aen0` |
| Ariadne I | 🟡 | Via *Gateway!* drivers |
| **Hydra** AmigaNet | ✅ | Via the modern [`hydra-amix` STREAMS/DLPI driver](../drivers/case-studies/hydra.md) — **verified on real hardware (2026-06)**; "believed to be the first working Amix net driver for the card" 🟡 |

See [the networking page](networking.md) for STREAMS TCP/IP, static-IP setup, and the DNS-off-by-default quirk.

### Serial

| Card | Status | Notes |
|---|---|---|
| **A2232** | ✅ | Adds 7 extra RS-232 ports; managed with `pmadm` |

## How this affects emulation

Every limit above maps onto a specific emulator setting. WinUAE (with MMU emulation, since 2.6.0) is the reference target. The short version:

- CPU **68030**, **MMU ON**, **JIT OFF**, FPU **68882**.
- RAM **16 MB** of A3000 motherboard RAM for the stock kernel (more only with a kernel that probes for the A3000 SCSI — [§57](quirks.md#57-loader-placement-a3000-scsi)), **128 MB** on the 040/060 kernels.
- Disk hardfile at **SCSI ID 6**; tape image at **SCSI ID 4**.
- A3000 Kickstart ROM (2.04 rev 37.175 or 3.1 40.68).

The full, annotated config table lives in [the WinUAE emulation guide](../getting-started/emulation-winuae.md). FS-UAE works similarly, and **Amiberry 8.x** does too — its A3000 on-board SCSI emulates the disk (ID 6) and tape (ID 4) Amix needs (older Amiberry builds lacked this). See [Amix on Amiberry](../getting-started/emulation-amiberry.md).

## See also

- [How Amix boots](boot-process.md) — Superkickstart, the bootstrap, the dual-boot mouse button.
- [Filesystems and disks](filesystems-and-disks.md) — RDB layout, the 2 MB boot partition, s5 vs UFS.
- [Quirks](quirks.md) — the SCSI ID rules, the retracted 16 MB ceiling, stock Zorro II only, and the rest, as a checklist.
- [Device list](../reference/device-list.md) — every supported device with its major/minor numbers.
- [WinUAE emulation guide](../getting-started/emulation-winuae.md) — these limits as a config table.
- [Emulation Fidelity](emulation-fidelity.md) — what a 68030/MMU/interrupt emulator must *implement* to boot Amix, beyond the config knobs.
- [Glossary](glossary.md) — MMU, FPU, HAT, AUTOCONFIG, Zorro, RDB, STREAMS.

## Sources

- The **68LC060 and FPU-built AmigaOS software** ✅ — the Z3660 driver set's `z3660-drivers/exfat/makefile` (`-m68881`) and a first-party test on a 68LC060 (2026-10-02) in which mounting the SD with that handler raised a Line-F exception; Amix's own `no fpu detected` / `fpu emulation enabled` boot lines are on [the 040/060 page](68040-68060-status.md).
- The **A4000/030's stock CPU card** — Commodore's 68EC030 card, identified first-party 2026-10-01 ✅.
- The **2026-09-29 stock-kernel RAM-layout measurement** ✅ — on the emulated bench the same 64 MB A3000 motherboard bank boots a kernel that probes for the A3000 SCSI and stops the pinned stock kernel at `s5mountroot VOP_OPEN error 6` (no card 0), symbolised against the stock `autocon()` load-address guess ([quirks §57](quirks.md#57-loader-placement-a3000-scsi)).
- `sources/research-brief.md` §2 (Hardware & requirements) — primary grounding for this page.
- First-party A4000T metal record: Amix 2.1c reaches `login:` about 60 s after power-on on a **real 68LC060** (the FPU-less 68060) on a Z3660 in an A4000T, running 060-direct (the card's CPU boot mode, not its 68030 emulation) with 128 MB of card RAM — 2026-09-25 ✅ (the Z3660 fork's `docs/investigations/a4000t-bench-2026-09.md`, "Outcome").
- `sources/research-brief.md` §3 (boot process, AUTOCONFIG/`autocon()`, Zorro II) and §4 (kernel HAT/MMU, RAM ceiling).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — `/dev/rmt/4h` tape path and `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` confirming the SCSI ID 6 disk / ID 4 tape rules.
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — `autocon()` Zorro II board discovery; device major/minor model.
- Hardware/requirements pages on [amigaunix.com](https://www.amigaunix.com/doku.php/home) (community-reported items: GVP Series II, Picasso II/Piccolo/Domino, Ariadne I).
- Card-specific repos: [`hydra-amix`](https://github.com/isoriano1968/hydra-amix), [`va2000-amix`](https://github.com/asokero/va2000-amix), [`xrtg-amix`](https://github.com/asokero/xrtg-amix).
- The A4091-on-Amix project — `NOTES.md` §1, §7, §9 (reproduced locally in Amiberry on real Amix 2.1c ✅; real-hardware pending 🟡). A4091 product id `0x02020054`, the NCR/Symbios 53C710, and the chipset-gated (VPOSR `0xDFF004`) A3000-SCSI detection verified against `src/kernel-patches/sd.c` (the `scsicard[]` row), `src/kernel-patches/support.c` (the AGA/ECS chipset gate), and `src/a4091-wr.c` (the 53C710 driver).
- a4091.device open-source project: [github.com/A4091/a4091-software](https://github.com/A4091/a4091-software) (A4091 autoboot ROM + the `ncr53cxxx` SCRIPTS assembler).
- The **amix-packagemanager** bench-RAM investigation, 2026-07-22 (Amiberry, fixed kernel sum-r 42265): 16 MB-exactly proven clean (SCSI read/write-readback/double-read + byte-exact base-set digest, recomputed via `tools/repo/altroot_attest.py`) and the 8 MB memory-exhaustion livelock signature (pegged host CPU, no panic, all I/O dead) reproduced ✅.
- The **Installer-NG** project (amix-installng @ `7106f1b`, amix-packagemanager @ `4539ad2`), 2026-07-22/24 — blank-disk→bootable installs under Amiberry and on a real A4000 + Z3660 (install captures, s5/UFS state reads, and an on-metal digest attestation) ✅ (🟡 where tagged).
