---
title: "Case Study: Z3660 piscsi SCSI driver (z3660.c)"
summary: How a native SVR4 block driver was written for the Z3660 accelerator's onboard "SCSI" — which is not a SCSI chip at all but the PiStorm piscsi register mailbox ported to the card's Zynq ARM — giving Amix a root disk that booted multiuser, byte-perfect, on real hardware from the first try.
status: draft
---

# Case Study: Z3660 piscsi SCSI driver (z3660.c)

This is the **SCSI sibling of the [Z3660 ethernet driver (`zen0`)](z3660-ethernet-driver.md)**: a
native Amix block driver for the *same* Z3660 combo board, talking the *same* firmware-mailbox style
of register protocol — but for disk I/O instead of frames. Where the ethernet work gave Amix full
TCP/IP over the card, this work gives Amix a **bootable root disk** on it: a real **Amiga 4000 +
Z3660** boots Amix **multiuser with the piscsi disk as root**, and every transfer was byte-perfect
**from the first real-hardware boot** ✅. It is also the third Zorro III data point in these docs,
alongside the [A4091 / 53C710 SCSI driver](a4091-53c710-driver.md) (the *other* SCSI sibling) and the
ethernet driver.

The work is **first-party and reproduced on real hardware** — the driver was written for this
project and run on a physical A4000 + Z3660 in 2026-06. Unless noted, every claim here is **✅
Verified** (driver source we wrote, or a result reproduced live on the hardware); items resting on
firmware-side assertion or community lore are tagged 🟡 inline and carried verbatim from the source
brief per the repo's [confidence-tag policy](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md).
The source is the **amix-z3660scsi** project at commit `8ea1605` — `src/z3660.c`,
`src/kernel-patches/sd.c`, `driver.conf`, `NOTES.md`, `README.md` — plus firmware-side facts owned by
the [Z3660 firmware repo](z3660-ethernet-driver.md#what-the-z3660-and-z3660eth-are).

> **One-line summary.** The Z3660's onboard "SCSI" is **not a SCSI chip** — it is the PiStorm
> `piscsi` mailbox ported to the card's Zynq ARM. The Amix driver pokes ~5 registers per I/O and the
> transfer completes synchronously, with no interrupt and no bus-phase management. It was **correct
> from the first real-hardware boot**; the only failure ever seen was a firmware-emulator bug, not a
> driver bug. ✅

## What the Z3660 "SCSI" actually is

The **Z3660** is a 68030/68060-class **Zorro III accelerator** built around a Xilinx **Zynq-7000**
SoC, whose firmware emulates the 68k *and* drives the card's real peripherals (see
[the ethernet case study](z3660-ethernet-driver.md#what-the-z3660-and-z3660eth-are) for the board in
full). Its "SCSI" is one of those peripherals — and the key realization that made the driver simple:

**It is not a SCSI controller.** There is **no 53C710, no SCRIPTS, no DSA, no bus-phase management,
and no interrupt- or poll-based completion** ✅. It is a tiny **synchronous MMIO register mailbox** —
the **PiStorm `piscsi`** interface ported to the Z3660's Zynq ARM. A disk I/O is **~5 register
pokes**; the ARM intercepts the bus cycle and performs the whole transfer before the triggering write
returns. That makes it **substantially lower-risk to port than the [A4091 53C710 driver](a4091-53c710-driver.md)**:
no SCRIPTS program, no live phase dispatch, no completion bookkeeping — just a mailbox and a bounce
buffer ✅.

> **Source.** The driver header `src/z3660.c:4-8` states this verbatim; the **empty `z3660intr()`
> stub** (`z3660.c:379-381`) plus the **synchronous `timeout()` / `z3660done`** completion path
> (`z3660.c:246-250,374`) corroborate "no IRQ", and the lower-risk rationale is in `NOTES.md`
> (§"Why this is lower-risk") and `README.md:8-10` ✅.

> 🟡 **Leftover scaffolding.** Some `siop_softc` / `a4091`-flavoured symbol names survive in the
> sources. Per the project's notes these are vestigial **AmigaOS device / boot-ROM scaffolding** from
> the upstream `shanshe/Z3660` `z3660_scsi.h` (which lived in a now-removed vendored `repo/` clone),
> not anything the Amix driver uses — but this is asserted in `NOTES.md`, **not** re-verifiable from
> the committed repo. Carried 🟡.

## The piscsi command-register protocol

All registers are **32-bit big-endian MMIO at `board_base + 0x2000 + cmd`** (the piscsi page is at
offset `PISCSI_OFFSET = 0x2000`, distinct from the ethernet mailbox at `+0x000`) ✅.

### Registers the driver uses

| Name | Offset | Dir | Meaning |
|---|---|---|---|
| `P_WRITE` | `0x00` | W | command register: a write **= unit number** triggers a WRITE (and completes it) |
| `P_READ` | `0x04` | W | command register: a write **= unit number** triggers a READ (and completes it) |
| `P_DRVTYPE` | `0x0C` | R | drive type; returns strictly **0 or 1** — also the presence probe (see below) |
| `P_BLOCKS` | `0x10` | R | block count (read-only; **writing it is a deliberate debug lever** — see 🟡 below) |
| `P_READ_ADDR1` | `0x20` | W | **READ:** block number (LBA) |
| `P_READ_ADDR2` | `0x24` | W | **READ:** byte length |
| `P_READ_ADDR3` | `0x28` | W | **READ:** buffer address |
| `P_WRITE_ADDR1` | `0x240` | W | **WRITE:** block number (LBA) |
| `P_WRITE_ADDR2` | `0x244` | W | **WRITE:** byte length |
| `P_WRITE_ADDR3` | `0x248` | W | **WRITE:** buffer address |
| `P_DRVNUMX` | `0x90` | W | select unit |
| `P_USED_DMA` | `0x9C` | R | nonzero after a READ if the firmware DMAed into the bounce window |
| `P_BLOCKSIZE0` | `0x200` | R | per-unit block size, indexed `+ unit*4` |
| `P_BLOCKS0` | `0x220` | R | per-unit block count, indexed `+ unit*4` |

### The per-I/O sequence ✅

1. Write `P_DRVNUMX` (`0x90`) = unit.
2. Write the **direction's address triple** = block number, byte length, buffer address. The two
   directions use **different registers**: a READ writes `P_READ_ADDR1/2/3` (`0x20`/`0x24`/`0x28`); a
   WRITE writes `P_WRITE_ADDR1/2/3` (`0x240`/`0x244`/`0x248`).
3. Write the **command register** — `P_WRITE` (`0x00`) or `P_READ` (`0x04`) — **with value = unit**.

That **single command-register write is both trigger and completion**: the Zynq ARM intercepts the
Zorro III bus cycle and finishes the whole transfer before the write returns — **no poll, no IRQ** ✅.
This is why the driver's interrupt handler is an empty stub and completion is just the next
instruction.

### The mandatory bounce buffer ✅

All Amix RAM lives **below `0x08000000`** (`BOUNCE_THRESH`), so the transfer path **always bounces**
through a firmware-visible buffer at `board_base + 0x80000` (`BOUNCE_OFFSET`):

- **WRITE** — the driver `bcopy`s the data into the bounce window *before* issuing `P_WRITE`.
- **READ** — after `P_READ` returns, the driver checks `P_USED_DMA` (`0x9C`) and `bcopy`s the bounce
  window back into the caller's buffer.

Transfers are chunked to `MAXXFER = 65536` (≤ 64 KB per command) ✅.

### Geometry and synthesized commands ✅

Disk geometry comes from `P_DRVTYPE` (`0x0C`) plus the **per-unit** registers `P_BLOCKSIZE0`
(`0x200`) and `P_BLOCKS0` (`0x220`), each indexed `+ unit*4`. Only the data path talks to hardware:
`READ`/`WRITE` 6 and 10 route to `z3660_rw`, while **`INQUIRY`, `READ_CAPACITY`, `TEST_UNIT_READY`
and `MODE_SENSE` are synthesized in software** inside `z3660queue` — the firmware exposes a block
device, not a SCSI target, so the SCSI command surface the Amix `sd` stack expects is faked above the
mailbox. Multi-byte SCSI fields are written **byte-wise big-endian**, which is also 68030
alignment-safe ✅.

> **Source.** `src/z3660.c`: `PISCSI_OFFSET` `0x2000`; `P_WRITE`/`P_READ` `0x00`/`0x04` (defs :68-69,
> triggered by `WRLONG(P_WRITE,unit)`:220 / `WRLONG(P_READ,unit)`:225); `P_DRVNUMX` `0x90` (:75,
> written :278); the **two** address triples — `P_READ_ADDR1/2/3` `0x20`/`0x24`/`0x28` (defs :72-74,
> written :222-224) and `P_WRITE_ADDR1/2/3` `0x240`/`0x244`/`0x248` (defs :77-79, written :217-219);
> `P_USED_DMA` `0x9C`; `BOUNCE_OFFSET` `0x80000` / `BOUNCE_THRESH` `0x08000000` (bcopy :215-228);
> `MAXXFER` `65536` (:64,206-211); per-unit `P_BLOCKSIZE0` `0x200` / `P_BLOCKS0` `0x220` (:181,191);
> synthesized CDBs (:286-335) ✅.

> 🟡 **Firmware superset.** The upstream firmware names the chunk constant `PISCSI_MAX_BLOCK_SIZE`
> and exposes a separate `READBYTES`/`WRITEBYTES` (`0x88`/`0x8C`) command family that the Amix driver
> **does not** use. (Firmware-side detail, owned by the Z3660 firmware repo.)

## Board identity and window placement

Both Z3660 drivers (this one and the [ethernet](z3660-ethernet-driver.md)) probe the **same
AutoConfig identity** — manufacturer `0x144B`, product `0x01` → **`0x144B0001`**, the Z3 RTG + piscsi
combo window ✅. The firmware exposes other products on the same manufacturer:

| Product | What it is | Usable for Amix piscsi? |
|---|---|---|
| `0x01` (`0x144B0001`) | Z3 RTG + piscsi combo window — what the driver probes | ✅ yes |
| `0x03` | Z2 RTG + SCSI combo (advertises a 64 KB window) | ❌ no — see below |
| `0x02` | Z3 fast RAM | n/a |

With `autoconfig_rtg NO` the combo window **never enters the AutoConfig chain** — it sits at a
**fixed base `0x10000000`** (`Z3660_FIXED`) ✅. The driver **`sptalloc`-maps** both the register
window and the bounce buffer into kernel VA (`z3660.c:139-142`) — the **same `sptalloc` primitive the
[A4091 driver](a4091-53c710-driver.md#the-zorro-iii-obstacle-and-the-sptalloc-solution) uses** ✅. The
meaningful difference from the A4091 is therefore **not** how the board is reached (both page-map their
windows) but the bus protocol on the far side of the mapping — a synchronous register mailbox here, a
53C710 SCRIPTS engine there. (The fixed base does fall inside the 68030's TT0 range documented for the
[A4091's TT-gap analysis](a4091-53c710-driver.md#the-zorro-iii-obstacle-and-the-sptalloc-solution),
so here the mapping is a clean convenience rather than being *forced* by the A4091's unmapped
`0x40000000–0x7FFFFFFF` gap — but the board is mapped either way.)

> **The Z2 variant is unusable for Amix piscsi.** Its base is `0xE90000`; add the mandatory bounce
> offset `0x80000` and you land at `0xF10000`, which the firmware/emulator decodes as **extended-ROM
> space** (extended Kickstart at `0xF00000`). Because all Amix RAM is below `0x08000000` the firmware
> *always* bounces, so on the Z2 window the bounce buffer points at ROM space and the path **can never
> move data** ✅.

> **Source.** Driver constants confirmed in `src/z3660.c` (`Z3660_PROD` `0x144B0001`:58,
> `Z3660_FIXED` `0x10000000`:59, `BOUNCE_OFFSET`/`BOUNCE_THRESH`) ✅. The firmware-side taxonomy
> (products `0x03`/`0x02`, base `0xE90000`, the `cpu_emulator.cpp` ext-ROM decode, the serial
> `[Core1] Autoconfig RTG to 0x1000` print) is from `NOTES.md` §"Real-hardware findings (2026-06-12)",
> verified against the deployed firmware repo (branch `amix-main`; the earlier `amix-boot` branch was
> rebased into it) + live boots; **firmware specifics are owned by the Z3660 firmware repo**.

## Detection: the silent-hang trap and multi-method detect

The single most important integration lesson. Amix 2.1's `bootinfo.autocon[]` table **misses the
board** — both with `autoconfig_rtg NO` (expected: the window is at a fixed base, not in the
AutoConfig chain) **and** with `YES` (Kickstart configures it at `0x40000000` but the 2.1 table still
misses it) ✅. With an `sd.c` that registers controllers **only** via `autocon()`, `z3660queue` never
runs — so the kernel prints its banner and then goes **silent**: no panic, no I/O, just a dead box.
This was the original silent hang ✅.

**Fix — register the card by more than one method** ✅, in order:

1. `autocon()` — the normal path (works when the table is right).
2. An **AGA-gated probe of the fixed base `0x10000000`**, accepted only if `P_DRVTYPE` reads a valid
   `0`/`1` (so an absent board can't false-positive). The AGA gate is the same `VPOSR >= 0x22` Alice
   check the [A4091 driver](a4091-53c710-driver.md) uses.
3. A **`driver.conf` `probe=` fallback hook** (`probe=z3660present`) the build's `sd.c` template calls
   when the autocon table misses the board.

This multi-method detect is **what carried the real-hardware boot past the silent banner** ✅.

> **Source.** `src/z3660.c` `z3660map` (autocon → AGA gate `VPOSR>=0x22` → fixed-base `DRVTYPE`
> probe, :131-155) and the exported `z3660present()` (:163-171), wired via `driver.conf:5`
> `probe=z3660present`; causal chain in `NOTES.md`:173-179; the boot-past-silence in `NOTES.md`:204 ✅.

> **Where the `probe=` hook is consumed.** The `probe=` *dispatch* lives in the **amix-kerntools**
> `sd.c` **template**, not in this repo's committed `src/kernel-patches/sd.c` (which only adds the
> `scsicard[]` row). See [kerntools' build contract](a4091-53c710-driver.md#the-card-registry-in-sdc).

### `P_DRVTYPE` as a safe presence probe ✅

`P_DRVTYPE` (`0x0C`) returns **strictly 0 or 1**, which makes it a safe presence test for a board
AutoConfig never enumerated: the driver reads it and **rejects any `t > 1` as open bus** (an absent
board reads back garbage outside `{0,1}`). The driver is also defensive about geometry — a reported
**block size of `0` is coerced to `512`** ✅. (`z3660map` :148-153, `z3660_blocksize` :182.)

## Kernel integration

Unlike the ethernet driver — a STREAMS char driver wired into `cdevsw[]` at major 48 — the piscsi
driver is a **block disk driver that plugs into the existing Amix SCSI stack**, exactly like the
[A4091](a4091-53c710-driver.md#the-card-registry-in-sdc). It registers a **queue function in `sd.c`'s
`scsicard[]` registry**, keyed by AutoConfig product id, and the disk then appears under the stock
**block major 18 / char major 40** SCSI device numbering ✅.

The machine-readable form is `driver.conf`, consumed by **amix-kerntools** to generate the on-box
`sd.c`:

```text
# <product-number>  <queue-func>  "<hardware name>"  <source under src/>  [probe=<func>]
0x144B0001  z3660queue  "Z3660 SCSI"  z3660.c  probe=z3660present
```

The `probe=z3660present` field is the fallback detect hook described above — the one piece that lives
in the kerntools template rather than this repo. With the card registered, the piscsi disk is reached
through the normal SCSI `/dev` names; on the real box the **root disk is `/dev/rdsk/c6d0s1`** (SCSI
target 6, the disk-ID-6 convention, card 0). See [the device list](../reference/device-list.md#card-index-when-both-an-a3000-scsi-and-an-a4091-are-present)
for how the card index and `cN` are computed.

## ★ Works on real hardware — and the bug that wasn't the driver

### It booted multiuser, byte-perfect, first try ✅

On a physical **A4000 + Z3660**, the driver carried **100% of boot I/O byte-perfect** and brought the
box to a stable **multiuser** process tree, with `fsck` running on the piscsi root disk
`/dev/rdsk/c6d0s1` — roughly **100+ reads/writes per boot, every completion clean** ✅. The driver was
**correct from the first real-hardware boot**.

> **Source.** Live boots 2026-06-12/13 on a real A4000 + Z3660 — `NOTES.md` §"2026-06-13 ~08:00:
> RESOLVED" (:269-296) and §"Overnight 2026-06-12/13" (:204-208); `CLAUDE.md` status line ✅. Spot
> checks confirmed the **page-in first-longs** of `/sbin/init` and `libc.so.1` matched file content,
> alongside the aggregate "every transfer byte-correct".

### The "boots then hangs" was the emulator core, not the SCSI driver ✅

Before the clean boot above, the box appeared to **boot and then hang** — and the obvious suspect was
the new disk driver. It was not. The apparent hang was the firmware **68k emulator core faulting while
demand-paging the driver's own text back in** — two MMU **format-`$B`** exception-frame bugs (a SIGILL
on instruction-fetch-fault resume, then a SIGSEGV on mid-instruction replay state). `init` died at
libc `_rt_boot+0`. Once the emulator was fixed, the driver booted clean and byte-perfect — confirming
it had been correct all along ✅. (The emulator-side mechanism, and a later fix generation, are
documented on [Emulation Fidelity](../how-it-works/emulation-fidelity.md#68030-bus-error-frame-semantics-demand-paging);
this page keeps only the driver-vs-emulator triage angle.)

**The reusable lesson is the driver-vs-emulator triage method**: combine **kernel-side serial
instrumentation** with **core-dump analysis** (`adb` / capstone disassembly) to *prove* the transfers
were byte-perfect and isolate the fault to the emulator rather than the driver. On an emulated 68k
where the "CPU" is itself software, "the machine hung" does not imply "your driver hung." (This is
recorded as a gotcha on [the quirks checklist](../how-it-works/quirks.md).)

> **Source & ownership.** `NOTES.md` §"banner-hang root cause is the EMU core, not SCSI" (:199-228)
> and §"RESOLVED" (:269-296) ✅. The **mechanism and fix are firmware-owned** — the Z3660 firmware
> repo (branch `amix-main`), commits `3069e22` (ifetch-fault resume, the SIGILL) and `0b42cb8`
> (mid-instruction frame state, the SIGSEGV). *(These are the live successors of the earlier
> `amix-boot`-branch commits once cited here as `c8b9398` / `e3f9440`, which no longer exist after that
> branch was rebased away; `0b42cb8`'s own body names `c8b9398` as its predecessor.)* A **later,
> distinct** pair — `7ff5774` + `acdfe15` — subsequently fixed a multi-fault-continuation frame
> corruption that surfaced as an intermittent under-load `User BUS ERROR`, not this boot-time hang.
> They are cited here by name + commit only, as the SCSI project's conclusion plus the triage method;
> the full mechanism lives on [Emulation Fidelity](../how-it-works/emulation-fidelity.md).

## 🟡 Firmware-side debug lever and hazard

Two firmware-side behaviours are useful to driver authors on this board. Both are **🟡** — asserted
from real-hardware sessions in `NOTES.md` §"Free 68k→serial debug channel" (:180-189), with **no
firmware file+symbol citation and no recorded standalone reproduction**; the firmware that emits them
lives in the Z3660 firmware repo. (The register offsets themselves — `P_BLOCKS` `0x10`, per-unit
`P_BLOCKS0` `0x220` — *are* confirmed in `src/z3660.c` ✅.)

- **A free 68k→serial breadcrumb.** Writing the **read-only** `P_BLOCKS` register makes the Zynq ARM
  unconditionally print `WARN: Write to read only register …(addr: value)` on its serial console — a
  zero-cost way to emit a tagged value from 68k code to the host serial log during bring-up. (It is a
  *technique*, not an implemented driver macro.) 🟡
- **A divide-by-zero hazard.** **Never read `P_BLOCKS0 + unit*4` of an *unmapped* drive** — the ARM
  divides by that unit's `block_size` (which is `0` for an absent drive), causing a **Zynq
  divide-by-zero**. This is *why* the driver gates on `P_DRVTYPE ∈ {0,1}` before touching per-unit
  registers. 🟡

## Status

| Claim | Status |
|---|---|
| piscsi block driver reads/writes; Amix boots **multiuser with root on the piscsi disk** | ✅ real-hardware (A4000 + Z3660, 2026-06-12/13) |
| Every boot transfer byte-perfect; correct from the first real-hardware boot | ✅ real-hardware |
| Multi-method detect (autocon → AGA-gated fixed-base probe → `probe=` hook) clears the silent hang | ✅ real-hardware |
| Z2 RTG+SCSI combo (`product 0x03`) variant | ❌ unusable (bounce window decodes to ROM space) ✅ |
| Firmware serial-breadcrumb lever + unmapped-drive divide-by-zero hazard | 🟡 asserted (no firmware citation / standalone repro) |
| The pre-fix "hang" | ✅ proven to be a firmware-emulator bug, **not** the driver |

## See also

- [Z3660 ethernet driver (`zen0`)](z3660-ethernet-driver.md) — the network sibling on the **same**
  combo board and firmware-mailbox model; the board, the Zynq SoC, and the `0x144B0001` identity are
  described there in full.
- [A4091 / 53C710 SCSI driver](a4091-53c710-driver.md) — the *other* SCSI sibling and a true Zorro III
  53C710 controller; contrast its SCRIPTS/DSA complexity and the `sptalloc` TT-gap mapping with this
  driver's ~5-poke mailbox.
- [The Amix device-driver model](driver-model.md) — block vs char vs STREAMS; the `sd.c`/`scsicard[]`
  SCSI-stack path this driver registers into.
- [Building & installing a kernel](kernel-build.md) — the `make` → `relocunix` → `make bootpart` flow
  and the D245 clean-gate the on-box build depends on.
- [Device & card list](../reference/device-list.md#scsi-host-adapters) — the SCSI block/char majors,
  the `scsicard[]` registry, and the card/target/slice minor scheme behind `c6d0s1`.
- [The boot process](../how-it-works/boot-process.md) — booting Amix with **root on a non-stock SCSI
  controller** and the rootdev ↔ card-index numbering.
- [Emulation Fidelity](../how-it-works/emulation-fidelity.md) — the emulator-side 68030
  bus-error-frame mechanism behind the "boots then hangs" (and the later under-load `BUS ERROR`), and
  the SCSI INT2-latency bootstrap gotcha.
- [Quirks](../how-it-works/quirks.md) — the un-enumerated-board silent-hang and the
  driver-vs-emulator triage gotchas in the checklist.

## Sources

- **Driver source we wrote** (primary, ✅): the **amix-z3660scsi** project at commit `8ea1605` —
  `src/z3660.c` (the piscsi mailbox driver: `PISCSI_OFFSET 0x2000`, `P_WRITE`/`P_READ`, `P_DRVNUMX`,
  the separate READ/WRITE address triples `P_READ_ADDR1/2/3` `0x20`/`0x24`/`0x28` and
  `P_WRITE_ADDR1/2/3` `0x240`/`0x244`/`0x248`, `P_USED_DMA`, `BOUNCE_OFFSET`/`BOUNCE_THRESH`,
  `MAXXFER 65536`, per-unit `P_BLOCKSIZE0`/`P_BLOCKS0`, the `sptalloc`-mapped register window + bounce
  buffer (`:139-142`), synthesized `INQUIRY`/`READ_CAPACITY`/`TEST_UNIT_READY`/`MODE_SENSE`,
  `z3660map` multi-method detect, `z3660present`, the empty `z3660intr` stub, synchronous
  `timeout()`/`z3660done` completion), `src/kernel-patches/sd.c` (the `scsicard[]` row), `driver.conf`
  (the `0x144B0001 z3660queue "Z3660 SCSI" z3660.c probe=z3660present` SCSI stanza), `NOTES.md`,
  `README.md`.
- **Real-hardware results reproduced live** (2026-06-12/13, A4000 + Z3660, ✅): Amix booting multiuser
  with root on `/dev/rdsk/c6d0s1`, ~100+ byte-perfect reads/writes per boot, `fsck` on the piscsi root,
  page-in spot checks of `/sbin/init` and `libc.so.1` (`NOTES.md` real-hardware sections).
- **Firmware-side facts** (F4 product taxonomy + fixed-base/ext-ROM decode, the 🟡 serial-breadcrumb
  lever and divide-by-zero hazard, the emulator format-`$B` fixes): the **Z3660 firmware repo**, branch
  `amix-main` — the boot-time demand-paging frame fixes `3069e22` (SIGILL) and `0b42cb8` (SIGSEGV), the
  live successors of the dead `amix-boot` hashes `c8b9398` / `e3f9440`, plus the later
  multi-fault-continuation pair `7ff5774` / `acdfe15`. **Owned by the Z3660 firmware repo, cited not
  reproduced**; see [Emulation Fidelity](../how-it-works/emulation-fidelity.md) for the full mechanism.
- **Magic numbers** (✅): AutoConfig product id `0x144B0001`; fixed combo base `0x10000000`; piscsi
  page offset `0x2000`; bounce offset `0x80000`; bounce threshold `0x08000000`; `MAXXFER 65536`; root
  disk `/dev/rdsk/c6d0s1` (SCSI target 6, block major 18 / char major 40).
- Delta verified against [`llms-full.txt`](https://github.com/Jusii/grimoire-amix/blob/master/llms-full.txt):
  grimoire documents the Z3660 *ethernet* (`zen0`) and A4091 *53C710* drivers; this page adds the
  previously-undocumented Z3660 *piscsi SCSI* driver.
