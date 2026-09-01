---
title: Zorro II AUTOCONFIG for Drivers
summary: How drivers find their board — the AUTOCONFIG protocol, the kernel autocon() helper, and userspace /dev/mem scanning.
status: draft
---

# Zorro II AUTOCONFIG for Drivers

An Amix driver does **not** hard-code where its expansion board lives. The Amiga **AUTOCONFIG** protocol assigns each Zorro II board a base address at every reset, and the driver asks the system *"where did my board land?"* at run time ✅. In the kernel that question is answered by the Amix-specific helper `autocon(product_id, dev, &board, &dummy)` 🟡; from user space you answer it yourself by `mmap()`-ing `/dev/mem` and walking the AutoConfig nibble registers — exactly what the [lszorro scanner](case-studies/lszorro.md) does ✅.

Two hard limits frame everything on this page:

- **Zorro II only.** Amix's memory-mapping layer cannot address Zorro III space, and that source was never shipped, so it can't be community-fixed ✅. See [Hardware](../how-it-works/hardware.md).
- **AutoConfig boards only.** RAM and accelerator boards with no AutoConfig ROM are invisible to this mechanism — `lszorro` cannot see them ✅.

Grounding: this page is built from §2 and §6 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), the [Ditto driver paper](../reference/bibliography.md), and the `asokero/lszorro-amix` source. The `autocon()` signature is **repo-confirmed but community-tier** 🟡 — do not treat it as primary-verified.

## What AUTOCONFIG does, and why drivers care

AUTOCONFIG is the Amiga's plug-and-play scheme for Zorro expansion cards. At power-on / reset, the Amiga bootstrap walks the expansion bus and, for each board it finds, **assigns a base address** from the relevant address pool and tells the board to relocate there ✅. The board exposes a small read-only **configuration ROM** (the "nibble registers") describing who made it, what it is, and how much space it wants; the bus logic uses that to place it.

Because the placement happens fresh at every reset, a driver written for a fixed address would break the moment the bus topology changes (another card added, slot order changed). So the contract is:

1. The board declares a **manufacturer ID** (a.k.a. *mfr* / *vendor*) and a **product ID** in its AutoConfig ROM.
2. The system places the board and records its assigned base.
3. The driver looks the board up **by `(mfr, product)`** and gets back the base address it was assigned ✅.

Amix reads the addresses AUTOCONFIG assigned via the kernel `autocon()` interface ✅; `autocon()` itself is the Zorro II discovery path for in-kernel drivers 🟡 (brief §3, §5).

## The kernel side: `autocon()`

Amix drivers discover their board with the Amix-specific kernel call 🟡 (repo-confirmed, not primary-verified):

```c
/* Amix-specific Zorro II board discovery — signature per modern repos */
int autocon(int product_id, int dev, caddr_t *board, int *dummy);
```

| Argument | Meaning |
|---|---|
| `product_id` | the board's AutoConfig product ID to match |
| `dev` | the device / unit being brought up |
| `&board` | **out:** receives the assigned Zorro II base address (kernel-mapped) |
| `&dummy` | **out:** an extra value the call fills in (e.g. a fallback / placeholder slot) |

A driver typically calls `autocon()` from its `init` or `open` routine, then keeps the returned `board` pointer for all subsequent register access. For example, the [VA2000 framebuffer driver](case-studies/va2000.md) uses `autocon()` (alongside `uiomove()` and `copyin`/`copyout`) to locate its 4 MB Zorro II window before mapping the framebuffer ✅. The [Hydra DLPI driver](case-studies/hydra.md) layers a **three-method detect** on top — `autocon()`/bootinfo (with address validation), then a direct Zorro II I/O-slot probe, then a memory-space probe — because the bootinfo `ConfigDev` table can be corrupt on Amix 2.1p2 ✅.

`autocon()` is part of the same Amix DDI/DKI surface a driver draws on (`copyin`/`copyout`, `uiomove`, `sleep`/`wakeup`, `spl2`/`splx`, …); see [Key kernel APIs in the driver model](driver-model.md#key-kernel-apis-the-driver-side).

**Note:** the four-argument shape above comes from the modern community repos, not from the Ditto paper, which predates them. Carry it as 🟡 and verify against your kernel headers before relying on the exact argument order.

## Zorro III boards and the real "Zorro II only" wall

🔴 **"Zorro II only" is imprecise about `autocon()` itself.** `autocon()` searches the same `bootinfo.autocon[NAUTO]` table for *any* AutoConfig board and returns the assigned base for a matched product id — **including Zorro III boards** ✅ (first-party, from the A4091-on-Amix project; `autocon()` in `amiga/kernel/support.c`). The match is purely on `(er_Manufacturer, er_Product)`; nothing in the table search rejects a Zorro III address. So a Zorro III board *does* AutoConfigure and `autocon()` *does* hand back its base.

🔴 **The actual wall is that Zorro III space falls outside the kernel's identity map, not `autocon()`.**

### How the low 1 GB is really mapped {#the-identity-map}

**AMIX does not use the 68030's Transparent-Translation registers at all** ✅. On a running kernel both TT registers read **E = 0 (disabled)** — the boot path zeroes them — and the identity mapping of the low **1 GB** (`0x00000000`–`0x3FFFFFFF`) is produced by the MMU instead: a **section-0 early-termination page descriptor in the root table**, which maps that whole span 1:1 without a second-level table ✅ (measured on a running kernel, 2026-08 RAM campaign). Everything at or below `0x3FFFFFFF` is therefore directly dereferenceable from kernel code; **`0x40000000`–`0x7FFFFFFF` is not mapped at all** ✅.

> **Correction (2026-08-14).** This page — and roughly ten others across this site — previously attributed that identity map to `tt0 = 0x003F0143` / `tt1 = 0x807F0143`, values that do appear in `amiga/ml/ttrap.s`. The constants are in the source; the running kernel does not use them. **Every conclusion is unchanged** — a Zorro II board is still directly dereferenceable, a Zorro III board at `0x40000000` still is not, and `sptalloc()` is still the way across — only the mechanism differs ✅. Pages that discuss the boundary now say *"inside the identity-mapped low 1 GB"* and *"the unmapped region above the identity map"* and link here.

A **Zorro II** board (≤ 24-bit, e.g. the A3000 internal SCSI at `0xDD0000`) lives inside the identity-mapped low 1 GB, so a stock WD33C93 driver can dereference the `autocon()` base directly ✅. A **Zorro III** board such as the A4091 (physical base `0x40000000`) lands in the **unmapped region above it** — `autocon()` returns the right address, but the CPU cannot reach it without a page mapping ✅. Extending the identity map upward is unsafe regardless of how it is built: `amiga/ml/syms.s` places the page-mapped u-area at `0x40000000`.

The fix is the kernel primitive **`sptalloc(npages, prot, pfn, flag)`**, which page-table-maps physical pages into kernel VA ✅. A Zorro III driver takes the `autocon()` base and `sptalloc`-maps it before any register access:

```c
extern caddr_t sptalloc();
acfg = (volatile uchar *)sptalloc(1, PG_V, phystopfn((paddr_t)base), 0);              /* board base  */
siop = (volatile uchar *)sptalloc(1, PG_V, phystopfn((paddr_t)base + 0x00800000), 0); /* chip regs   */
```

See [the A4091/53C710 driver](a4091-53c710-driver.md) for the full Zorro III bring-up (this is exactly how the A4091 SCSI host adapter, product id `0x02020054`, is made addressable from Amix).

## `autocon()` and the phantom A3000 internal SCSI

🔴 **What was hardcoded, and why it mis-orders cards.** The A3000 internal SCSI (Commodore DMAC + WD33C93 at `0xDD0000`) is **not** an AutoConfig board, so it never appears in `bootinfo.autocon[]`. Historically, `autocon()` in `amiga/kernel/support.c` faked one in: whenever RAM extended past 7 MB it returned a **phantom A3000 SCSI at `0xDD0000` regardless of whether the hardware exists** ✅ (first-party). The original special case:

```c
if (index==0 && end > (char *)0x07000000 && (pc==0x0202F003)) { *bp = 0xdd0000; return 1; }
```

On a machine *without* the A3000 SCSI (or a real A4000, which has none) this phantom still claims `queue[0]` (card 0) and shoves the next SCSI card to card 1. That mis-orders the SCSI card table — and because the compiled-in root device decodes to card 0, the kernel sends the root read to non-existent hardware. (For the boot-time consequences and the panic chain it produces, see [the boot process](../how-it-works/boot-process.md).)

## Chipset-gated WD33C93 auto-detection (the fix)

✅ **What it actually does now** (first-party, from the A4091-on-Amix project — full source in `src/kernel-patches/support.c`). The phantom is replaced with a **chipset gate + a WD33C93 write/readback probe**, so the A3000 SCSI is registered only when it is genuinely present:

```c
if (index==0 && (pc==0x0202F003)) {                 /* A3000 internal SCSI: not an AutoConfig board */
    int a3kscsi = 0;
    unsigned short vposr = *(volatile unsigned short *)0xDFF004;   /* custom chip, always present, bus-safe */
    if ((((int)vposr >> 8) & 0x7F) < 0x22) {        /* ECS/OCS Agnus (<0x22) = A3000-class; AGA Alice (>=0x22) = A4000 */
        volatile unsigned char *sasr = (unsigned char *)0xDD0041;  /* WD33C93 SASR */
        volatile unsigned char *scmd = (unsigned char *)0xDD0043;  /* WD33C93 SCMD */
        *sasr = 0x02; *scmd = 0x55;                                /* reg 0x02 <- 0x55 */
        *sasr = 0x03; *scmd = 0xAA;                                /* reg 0x03 <- 0xAA, same data port */
        *sasr = 0x02;                                              /* re-select reg 0x02 */
        if (*scmd == 0x55) {           /* open bus would alias this read to the LAST write, 0xAA */
            *sasr = 0x03;
            if (*scmd == 0xAA) a3kscsi = 1;   /* both registers distinct => a real WD33C93 */
        }
    }
    if (a3kscsi) { *bp = 0xdd0000; return 1; }       /* present -> register */
    /* absent -> fall through; autocon returns 0; sd.c never registers it */
}
```

How the two steps work ✅:

- **Chipset gate (the safety mechanism).** Read **VPOSR (`0xDFF004`)** — a custom-chip register that is *always* present and bus-safe to read on any Amiga. The identification field is **bits 8–14** (mask the toggling LOF bit at bit 15, i.e. `(vposr >> 8) & 0x7F`): **< 0x22 = ECS/OCS Agnus** (A3000-class), **≥ 0x22 = AGA Alice** (A4000). On AGA the whole block is **skipped**, so the kernel *never reads* `0xDD0000` — eliminating any bus-fault at an address that does not decode on an A4000.
- **WD33C93 probe (on A3000-class only).** A **two-register anti-alias** write/readback through the
  chip's indirect `SASR`/`SCMD` ports (`0xDD0041`/`0xDD0043`): write `0x55` into register `0x02` and
  `0xAA` into register `0x03` — both through the *same* data port — then read both back. Open bus
  that echoes the last write would return `0xAA` for the register-`0x02` read, so the probe only
  passes when two genuinely distinct registers hold their own values: a real WD33C93. The board at
  `0xDD0000` is registered only then.

🟡 **Emulation caveat (carry honestly).** An earlier **single-register** form of this probe
false-positived on Amiberry: its *open bus* at `0xDD0000` echoes writes, so a write/readback against
one register succeeds with no WD33C93 attached (`scsi_a3000=false`). The current two-register form
above was designed to defeat exactly that aliasing — an echo-last-write bus fails the register-`0x02`
readback ✅ (by construction). Whether it has been re-measured against Amiberry's open bus is not
recorded 🟡; the **chipset gate** remains what makes the A4000/AGA case correct and safe regardless.

## The Zorro II ID nibble encoding

To match a board you must read its AutoConfig ROM, and that ROM is laid out in a deliberately awkward **nibble format**. Understanding it is what lets [lszorro](case-studies/lszorro.md) (and any userspace probe) decode `(mfr, product)` correctly ✅.

The encoding rules, as used by `lszorro` ✅:

- **Two nibbles per logical byte.** Each logical configuration byte is split across **two** physical addresses (a high-nibble slot and a low-nibble slot).
- **Upper nibble lives in D15–D12.** The meaningful nibble is read from the **top** four data-bus bits of the 16-bit word at that offset, not the low bits.
- **Most fields are stored ones-complement (inverted).** After extracting a nibble you must invert it to recover the true value — with the conventional exception that the very first register pair is *not* inverted (so software can tell it is reading a real AutoConfig ROM and which way is up). Treat "most fields are ones-complement" as the working rule and special-case the leading bytes per the standard Zorro layout ✅.

In other words: to read one configuration byte you read two 16-bit words, take bits D15–D12 of each, combine high-nibble and low-nibble, and (for inverted fields) take the ones-complement. From the reconstructed bytes you obtain the **manufacturer ID**, the **product ID**, the board's **size/type flags**, and any optional serial / boot-ROM fields.

This is purely a property of Zorro II AutoConfig ROMs — Amix imposes nothing extra. `lszorro` matches the decoded `(mfr, product)` against a **461-entry ID database** lifted from the Linux kernel Zorro list to print human-readable names ✅.

## The userspace side: scanning via `/dev/mem`

You do not need a kernel driver to enumerate boards. `lszorro` runs entirely in user space by memory-mapping physical address space through `/dev/mem` ✅:

```sh
# Build natively on Amix (single source file)
cc lszorro.c -o lszorro

# Must run as root: /dev/mem is privileged
./lszorro
```

The mechanism ✅:

1. **Open `/dev/mem`** (requires root — it is raw physical memory).
2. **`mmap()` a small window** — 128 bytes (`0x80`) — over each candidate board slot.
3. **Walk both Zorro II address pools** (table below), reading the AutoConfig nibble registers at each slot.
4. **Decode** each populated slot's `(mfr, product)` per the [nibble encoding](#the-zorro-ii-id-nibble-encoding) above and look it up in the ID database.

### Zorro II address ranges to scan

These are the physical ranges `lszorro` walks ✅:

| Pool | Address range | Notes |
|---|---|---|
| **I/O space** | `0xE90000`–`0xEFFFFF` | Zorro II expansion *I/O* board area |
| **Memory space** | `0x200000`–`0x9FFFFF` | Zorro II expansion *memory* board area |

Map a `0x80`-byte window at each slot, read the configuration registers, and move on. Boards that present only registers (no AutoConfig ROM in the usual place) can still be **fingerprinted** — `lszorro` detects register-only boards such as the VA2000 by their signature ✅. What it **cannot** see are boards with no AutoConfig presence at all, i.e. **RAM and accelerator boards** ✅.

**Warning:** `/dev/mem` is unmediated physical memory. Reading the AutoConfig pools is safe; writing anywhere through `/dev/mem` can corrupt the running system. Keep probes read-only.

## Worked example: lszorro end to end

`lszorro` is the canonical worked example for everything above — an `lspci`-style enumerator for Amix ✅. The full pipeline:

1. **Open** `/dev/mem` as root.
2. **Iterate** the I/O pool `0xE90000`–`0xEFFFFF` and the memory pool `0x200000`–`0x9FFFFF`, `mmap()`-ing a `0x80`-byte window per slot.
3. **Read** the AutoConfig nibble registers at each slot: two nibbles per byte, upper nibble in D15–D12, ones-complement on most fields.
4. **Decode** `(mfr, product)`, size and type; **fingerprint** register-only boards (e.g. the VA2000).
5. **Resolve** names against the 461-entry Linux-derived Zorro ID database and print a board-per-line listing.

Concrete IDs you will see decoded (all ✅ from the repos):

| Board | mfr (vendor) | product | What the driver does with it |
|---|---|---|---|
| **MNT VA2000** | `0x6D6E` | `0x01` | 4 MB Zorro II window; framebuffer driver maps regs `0x000000`–`0x00FFFF`, FB `0x010000`–`0x3FFFFF` (see [VA2000 case study](case-studies/va2000.md)) |
| **Hydra AmigaNet** | `2121` (`0x0849`) | `1` (`0x0001`) | combined AutoConfig ID `0x08490001`; STREAMS/DLPI net driver `hya` (see [Hydra case study](case-studies/hydra.md)) |

So `autocon()` (in-kernel) and `lszorro` (userspace) are two readers of the **same** AutoConfig data: the kernel helper hands a driver its assigned base by product ID; the scanner walks the pools itself to list everything. If you are bringing up a new board, run `lszorro` first to confirm the board AutoConfigured and to read its real `(mfr, product)`, then wire those numbers into your driver's `autocon()` call and its [`cdevsw[]`/`bdevsw[]` slot](driver-model.md#the-kernel-level-view-switch-tables-in-kernelc).

## See also

- [The A4091/53C710 driver](a4091-53c710-driver.md) — a Zorro III board brought up over the unmapped region above the identity map with `sptalloc()`; the auto-detection consumer of `autocon()`.
## The phantom on a real A4000: a fabricated entry whose every I/O is fatal ✅

On real A4000 metal the fabricated card-0 entry is worse than a mis-ordering. Nothing decodes
`0xDD0000` on an A4000, so nothing drives DSACK, and the first register access takes a **bus error
inside the stock driver's initialisation** — that routine is shaped as *"panic unless a board was
found at exactly the A3000 built-in address"* followed by a register write, and it establishes no
mapping, so on this machine it is fatal **whenever it is called** ✅ (first-party, observed and
decoded on metal, 2026-08). The only defence is never to issue I/O to that card: a kernel whose
compiled-in root device names card 1 never enters the routine at all, which is why the same kernel
can be fully green on a bench (where something answers *and decodes* at `0xDD0000`) and structurally
unbootable on this metal ✅.

**Card ordering is fragile in both directions.** On an uncured kernel the Z3660-class second
controller is card 1 *only because* the phantom holds card 0 ✅. Suppress the phantom — this page's
cure, or any config in which `autocon()` stops fabricating the entry — and the second controller
**renumbers to card 0**, so every root/swap stamp naming card 1 stops resolving. This is measured,
not hypothetical: on the same physical A4000, a kernel carrying the cure roots through **card 0**
while an uncured one must be stamped to **card 1** ✅. Adopting the cure into an existing kernel
lineage is therefore a **migration** (re-stamp every image's root/swap), not a drop-in patch.

**Which kernels carry the cure** ✅ (audited 2026-08-27): the A4091 project (its origin), the
install-media builder (unconditionally, with build gates), and the on-box kernel builders. A kernel
produced by **relinking a stock binary** structurally cannot take it — the cure is a source patch,
and no C source is in that path — so such kernels avoid card 0 by stamping root/swap to card 1
instead, with a link-time gate that decodes the artifact's compiled-in root family and refuses a
mismatch for the target rig. The state is coherent: the cure where source is compiled, the stamp
plus gate where it is not.

**A method note from the metal root-cause** ✅: the failing and the working kernel differed by *one
byte* in a megabyte of text — the controller registry's row-count bound — plus an appended driver
and a two-byte root restamp. A byte-compare that finds exactly one difference has not told you what
that byte does; **decode the byte before concluding anything** (see [quirks §37](../how-it-works/quirks.md#37-a-one-byte-binary-diff-is-not-understood-until-the-byte-is-decoded-)).

- [The boot process](../how-it-works/boot-process.md) — how the phantom-A3000 mis-ordering produced the root-mount panic, and the fixed card numbering.
- [The Amix device-driver model](driver-model.md) — switch tables, major/minor, and where `autocon()` sits in the API surface.
- [Case study: lszorro userspace Zorro scanner](case-studies/lszorro.md) — the full worked implementation.
- [Hardware and requirements](../how-it-works/hardware.md) — Zorro II vs Zorro III, supported expansion boards.
- [Case study: VA2000 framebuffer driver](case-studies/va2000.md) — `autocon()` in a real char driver.
- [Case study: Hydra DLPI network driver](case-studies/hydra.md) — `autocon()` plus a three-method board-detect (validated bootinfo + direct probes).
- [Building and installing a kernel](kernel-build.md) — relinking after you add a board's driver.

## Sources

- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §2 (Zorro II only; no Zorro III mapping; supported expansion), §3 (AUTOCONFIG assigns Zorro II addresses at reset; `autocon()` consumed by the kernel), §5 (`autocon(product_id, dev, &board, &dummy)` 🟡 repo-confirmed; driver API surface), §6 (lszorro mechanism, ranges, nibble encoding, ID database; VA2000 and Hydra AutoConfig IDs).
- `asokero/lszorro-amix` repo — `/dev/mem` `mmap()` scan, `0x80`-byte windows, I/O `0xE90000`–`0xEFFFFF` / mem `0x200000`–`0x9FFFFF`, AutoConfig nibble decode, 461-entry ID DB, register-only fingerprinting: <https://github.com/asokero/lszorro-amix>
- `asokero/va2000-amix` repo — VA2000 AutoConfig mfr `0x6D6E` product `0x01`, 4 MB Zorro II window, `autocon()` usage: <https://github.com/asokero/va2000-amix>
- `isoriano1968/hydra-amix` repo — Hydra AutoConfig ID `0x08490001` (2121/1), `autocon()` plus three-way detect: <https://github.com/isoriano1968/hydra-amix>
- The A4091-on-Amix project — `NOTES.md` §2, §6, §7 (reproduced locally ✅; Zorro III above the identity map, `sptalloc()`, phantom-A3000, chipset-gated WD33C93 detection) and `src/`/`tools/`.
- `src/kernel-patches/support.c` — the full `autocon()` with the chipset-gated WD33C93 auto-detection replacing the phantom-A3000 special case (A4091 product id `0x02020054`). The TT-register constants `tt0=0x003F0143` / `tt1=0x807F0143` also read from `amiga/ml/ttrap.s` there are **not** what the running kernel uses — see the 2026-08-14 correction above.
- The **2026-08-12/14 RAM campaign** (workspace record): AMIX zeroes the 68030 TT registers (E = 0) and the low-1 GB identity map is a section-0 early-termination page descriptor in the MMU root table, measured on a running kernel ✅ — the correction to the TT0 mechanism carried across this site.
- a4091.device open-source project: <https://github.com/A4091/a4091-software> (A4091 ROM + `ncr53cxxx` SCRIPTS assembler).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — driver model and kernel API context (see [bibliography](../reference/bibliography.md)).
- amigaunix.com — historical and hardware reference: <https://www.amigaunix.com/doku.php/home>
