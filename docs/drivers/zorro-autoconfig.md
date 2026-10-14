---
title: Zorro II AUTOCONFIG for Drivers
summary: How drivers find their board — the AUTOCONFIG protocol, the kernel autocon() helper, and userspace /dev/mem scanning.
status: draft
---

# Zorro II AUTOCONFIG for Drivers

An Amix driver does **not** hard-code where its expansion board lives. The Amiga **AUTOCONFIG** protocol assigns each Zorro II board a base address at every reset, and the driver asks the system *"where did my board land?"* at run time ✅. In the kernel that question is answered by the Amix-specific helper `autocon(pc, index, &base, &size)` ✅ (stock kernel source); from user space you answer it yourself by `mmap()`-ing `/dev/mem` and walking the AutoConfig nibble registers — exactly what the [lszorro scanner](case-studies/lszorro.md) does ✅.

Two hard limits frame everything on this page:

- **Stock drivers are Zorro II only.** Zorro III space lies outside the kernel's identity-mapped low 1 GB, so a driver that dereferences the `autocon()` base directly reaches only Zorro II boards; a driver that maps its board with `sptalloc()` reaches Zorro III as well ✅ — see [below](#zorro-iii-boards-and-the-real-zorro-ii-only-wall). See also [Hardware](../how-it-works/hardware.md).
- **AutoConfig boards only.** RAM and accelerator boards with no AutoConfig ROM are invisible to this mechanism — `lszorro` cannot see them ✅.

Grounding: this page is built from §2 and §6 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), the [Ditto driver paper](../reference/bibliography.md), and the `asokero/lszorro-amix` source. The `autocon()` signature is read from the stock kernel source, `amiga/kernel/support.c` ✅; the brief's community-tier form is kept below as history only.

## What AUTOCONFIG does, and why drivers care

AUTOCONFIG is the Amiga's plug-and-play scheme for Zorro expansion cards. At power-on / reset, the Amiga bootstrap walks the expansion bus and, for each board it finds, **assigns a base address** from the relevant address pool and tells the board to relocate there ✅. The board exposes a small read-only **configuration ROM** (the "nibble registers") describing who made it, what it is, and how much space it wants; the bus logic uses that to place it.

Because the placement happens fresh at every reset, a driver written for a fixed address would break the moment the bus topology changes (another card added, slot order changed). So the contract is:

1. The board declares a **manufacturer ID** (a.k.a. *mfr* / *vendor*) and a **product ID** in its AutoConfig ROM.
2. The system places the board and records its assigned base.
3. The driver looks the board up **by `(mfr, product)`** and gets back the base address it was assigned ✅.

Amix reads the addresses AUTOCONFIG assigned via the kernel `autocon()` interface ✅; `autocon()` itself is the Zorro II discovery path for in-kernel drivers 🟡 (brief §3, §5).

## The kernel side: `autocon()`

Amix drivers discover their board with the Amix-specific kernel call ✅ (read in the stock kernel
source, `amiga/kernel/support.c`):

```c
/* Amix-specific board discovery — stock amiga/kernel/support.c (K&R) */
int autocon(pc, index, bp, np)
long	pc;
int	index;
long	*bp;
long	*np;
```

| Argument | Meaning |
|---|---|
| `pc` | the packed id to match: manufacturer `<< 16` \| product (e.g. `0x02020054`, the A4091) |
| `index` | which matching board: `0` = the first, `1` = the second, … (stock `sd.c` `init()` passes a running count) |
| `bp` | **out:** receives the board's `cd_BoardAddr` — its assigned physical base |
| `np` | **out:** receives the board's `cd_BoardSize` |

It returns 1 when the `index`-th matching board exists and 0 otherwise ✅.

A driver typically calls `autocon()` from its `init` or `open` routine, then keeps the returned base (`*bp`) for all subsequent register access. For example, the [VA2000 framebuffer driver](case-studies/va2000.md) uses `autocon()` (alongside `uiomove()` and `copyin`/`copyout`) to locate its 4 MB Zorro II window before mapping the framebuffer ✅. The [Hydra DLPI driver](case-studies/hydra.md) layers a **three-method detect** on top — `autocon()`/bootinfo (with address validation), then a direct Zorro II I/O-slot probe, then a memory-space probe — because the bootinfo `ConfigDev` table can be corrupt on Amix 2.1p2 ✅.

`autocon()` is part of the same Amix DDI/DKI surface a driver draws on (`copyin`/`copyout`, `uiomove`, `sleep`/`wakeup`, `spl2`/`splx`, …); see [Key kernel APIs in the driver model](driver-model.md#key-kernel-apis-the-driver-side).

> ⚠ **Stock `autocon()` cannot match a manufacturer id ≥ `0x8000`** ✅. The manufacturer half of the
> id is compared after a *signed* right shift, so a high id comes back sign-extended and never
> matches; the board sits in `bootinfo.autocon[]` with the right id and no driver ever attaches. The
> A4092 (`0xC0DE0001`) was the first board to hit it; the fix is an unsigned shift. See
> [quirks §65](../how-it-works/quirks.md#65-autocon-signed-manufacturer).

**Note (history).** The research brief carried a community-tier form, `autocon(product_id, dev, &board, &dummy)` 🟡, taken from the modern community repos (the Ditto paper predates them). The stock source above supersedes it: the second argument is an instance number, not a device, and the fourth receives the board size.

## Zorro III boards and the real "Zorro II only" wall

🔴 **"Zorro II only" is imprecise about `autocon()` itself.** `autocon()` searches the same `bootinfo.autocon[NAUTO]` table for *any* AutoConfig board and returns the assigned base for a matched product id — **including Zorro III boards** ✅ (first-party, from the A4091-on-Amix project; `autocon()` in `amiga/kernel/support.c`). The match is purely on `(er_Manufacturer, er_Product)`; nothing in the table search rejects a Zorro III address. So a Zorro III board *does* AutoConfigure and `autocon()` *does* hand back its base.

🔴 **The actual wall is that Zorro III space falls outside the kernel's identity map, not `autocon()`.**

### How the low 1 GB is really mapped {#the-identity-map}

**AMIX does not use the 68030's Transparent-Translation registers at all** ✅. On a running kernel both TT registers read **E = 0 (disabled)** — the boot path zeroes them — and the identity mapping of the low **1 GB** (`0x00000000`–`0x3FFFFFFF`) is produced by the MMU instead: a **section-0 early-termination page descriptor in the root table**, which maps that whole span 1:1 without a second-level table ✅ (measured on a running kernel). Everything at or below `0x3FFFFFFF` is therefore directly dereferenceable from kernel code; **`0x40000000`–`0x7FFFFFFF` is not mapped at all** ✅.

> **Note.** `amiga/ml/ttrap.s` contains `tt0 = 0x003F0143` / `tt1 = 0x807F0143`, but the running kernel does not load them. The identity map comes from the MMU root table, as described above ✅.

A **Zorro II** board (≤ 24-bit, e.g. the A3000 internal SCSI at `0xDD0000`) lives inside the identity-mapped low 1 GB, so a stock WD33C93 driver can dereference the `autocon()` base directly ✅. A **Zorro III** board such as the A4091 (physical base `0x40000000`) lands in the **unmapped region above it** — `autocon()` returns the right address, but the CPU cannot reach it without a page mapping ✅. Extending the identity map upward is unsafe regardless of how it is built: `amiga/ml/syms.s` places the page-mapped u-area at `0x40000000`.

The fix is the kernel primitive **`sptalloc(npages, prot, pfn, flag)`**, which page-table-maps physical pages into kernel VA ✅. A Zorro III driver takes the `autocon()` base and `sptalloc`-maps it before any register access:

```c
extern caddr_t sptalloc();
acfg = (volatile uchar *)sptalloc(1, PG_V, phystopfn((paddr_t)base), 0);              /* board base  */
siop = (volatile uchar *)sptalloc(1, PG_V, phystopfn((paddr_t)base + 0x00800000), 0); /* chip regs   */
```

See [the A4091/53C710 driver](a4091-53c710-driver.md) for the full Zorro III bring-up (this is exactly how the A4091 SCSI host adapter, product id `0x02020054`, is made addressable from Amix).

## `autocon()` and the phantom A3000 internal SCSI

🔴 **What was hardcoded, and why it mis-orders cards.** The A3000 internal SCSI (Commodore DMAC + WD33C93 at `0xDD0000`) is **not** an AutoConfig board, so it never appears in `bootinfo.autocon[]`. Historically, `autocon()` in `amiga/kernel/support.c` faked one in: whenever the kernel's own end address `end` lay above `0x07000000` — i.e. wherever the loader had placed the kernel, not how much RAM there was ([quirks §57](../how-it-works/quirks.md#57-loader-placement-a3000-scsi)) — it returned a **phantom A3000 SCSI at `0xDD0000` regardless of whether the hardware exists** ✅ (first-party). The original special case:

```c
if (index==0 && end > (char *)0x07000000 && (pc==0x0202F003)) { *bp = 0xdd0000; return 1; }
```

On a machine *without* the A3000 SCSI (or a real A4000, which has none) this phantom still claims `queue[0]` (card 0) and shoves the next SCSI card to card 1. That mis-orders the SCSI card table — and because the compiled-in root device decodes to card 0, the kernel sends the root read to non-existent hardware. (For the boot-time consequences and the panic chain it produces, see [the boot process](../how-it-works/boot-process.md).)

## Chipset-gated WD33C93 auto-detection (the fix)

✅ **What it actually does now** (first-party, from the A4091-on-Amix project — full diff in `src/kernel-patches/support.c.patch`). The phantom is replaced with a **chipset gate + a WD33C93 write/readback probe**, so the A3000 SCSI is registered only when it is genuinely present:

```c
if (index==0 && (pc==0x0202F003)) {                 /* A3000 internal SCSI: not an AutoConfig board */
    int a3kscsi = 0;
    unsigned short vposr = *(volatile unsigned short *)0xDFF004;   /* custom chip, always present, bus-safe */
    if ((((int)vposr >> 8) & 0x0F) < 2) {           /* id low nibble < 2: OCS/ECS Agnus = A3000-class; >= 2: AGA Alice = A4000 */
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

- **Chipset gate (the safety mechanism).** Read **VPOSR (`0xDFF004`)** — a custom-chip register that is *always* present and bus-safe to read on any Amiga. The identification field is **bits 8–14** (mask the toggling LOF bit at bit 15, i.e. `(vposr >> 8) & 0x7F`): `0x00`/`0x10` OCS (PAL/NTSC), `0x20`/`0x30` ECS (PAL/NTSC), `0x22`/`0x23`/`0x32`/`0x33` AGA Alice. AGA is the id's **low nibble ≥ 2** — **< 2 = OCS/ECS Agnus** (A3000-class), **≥ 2 = AGA Alice** (A4000). On AGA the whole block is **skipped**, so the kernel *never reads* `0xDD0000` — eliminating any bus-fault at an address that does not decode on an A4000.
- **WD33C93 probe (on A3000-class only).** A **two-register anti-alias** write/readback through the
  chip's indirect `SASR`/`SCMD` ports (`0xDD0041`/`0xDD0043`): write `0x55` into register `0x02` and
  `0xAA` into register `0x03` — both through the *same* data port — then read both back. Open bus
  that echoes the last write would return `0xAA` for the register-`0x02` read, so the probe only
  passes when two genuinely distinct registers hold their own values: a real WD33C93. The board at
  `0xDD0000` is registered only then.

✅ **Do not gate on `id >= 0x22`.** That range test misreads an
**NTSC ECS Agnus (`0x30`)** as AGA, so on an NTSC A3000 it skips the WD33C93 probe and the
internal SCSI (with the root disk on it) never registers. The low-nibble test above avoids it (the
[Z3660 SCSI driver](z3660-scsi-driver.md)'s machine gate uses the same test); with it, an
emulated ECS-NTSC machine (id `0x30`) finds the WD33C93 as card 0. The pitfall is
[quirk §61](../how-it-works/quirks.md#61-vposr-low-nibble).

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
mapping, so on an A4000 it is fatal **whenever it is called** ✅ (first-party, observed and
decoded on metal, 2026-08). The only defence is never to issue I/O to that card: a kernel whose
compiled-in root device names card 1 never enters the routine at all, which is why the same kernel
can be fully green on a bench (where something answers *and decodes* at `0xDD0000`) and structurally
unbootable on an A4000 ✅.

> **Note — a read there can also simply hang.** On the Z3660's real 68060, a CPU **read** of
> `0xDD0000` on an A4000D never terminates: the motherboard raises no timeout bus error in local I/O
> space and the card's CPLD has no cycle timeout, so there is no fault to take ✅
> ([quirks §66](../how-it-works/quirks.md#66-local-io-read-hangs)). On the Z3660's **emulated**
> 68030/040 the emulator times out an unacknowledged Amiga read, remaps that 64 KB page to a dummy
> bank, and its UAE-derived Gary model raises a bus error for a non-range address when the emulated
> Gary's timeout-enable bit is set ✅ (from the card's firmware sources). The bus error described above
> comes from that emulated path, not from the board. Either way the rule stands: never let I/O reach
> the phantom card.

**Card ordering is fragile in both directions.** On an uncured kernel the Z3660-class second
controller is card 1 *only because* the phantom holds card 0 ✅. Suppress the phantom — this page's
cure, or any config in which `autocon()` stops fabricating the entry — and the second controller
**renumbers to card 0**, so every root/swap stamp naming card 1 stops resolving. This is measured,
not hypothetical: on the same physical A4000, a kernel carrying the cure roots through **card 0**
while an uncured one must be stamped to **card 1** ✅. Adopting the cure into an existing kernel
lineage is therefore a **migration** (re-stamp every image's root/swap), not a drop-in patch.

**A relinked stock kernel cannot take the source cure** ✅ (the cure is a patch to `autocon()`'s
C source, and relinking a stock binary compiles none), so such a kernel needs the probe injected into
the binary or its root/swap stamped to card 1 instead.

- [The boot process](../how-it-works/boot-process.md) — how the phantom-A3000 mis-ordering produced the root-mount panic, and the fixed card numbering.
- [The Amix device-driver model](driver-model.md) — switch tables, major/minor, and where `autocon()` sits in the API surface.
- [Case study: lszorro userspace Zorro scanner](case-studies/lszorro.md) — the full worked implementation.
- [Hardware and requirements](../how-it-works/hardware.md) — Zorro II vs Zorro III, supported expansion boards.
- [Case study: VA2000 framebuffer driver](case-studies/va2000.md) — `autocon()` in a real char driver.
- [Case study: Hydra DLPI network driver](case-studies/hydra.md) — `autocon()` plus a three-method board-detect (validated bootinfo + direct probes).
- [Building and installing a kernel](kernel-build.md) — relinking after you add a board's driver.

## Sources

- The **CPU-path resolution** of the 2026-08 vs 2026-10-02 `$DD0000` observations ✅ — the Z3660 emulator sources (`Z3660_emu/src/cpu_emulator.cpp` `wait_read_ack()`, `uae_emulator.cpp` `make_dummy_address_bank()`, `uae/memory.cpp` Gary non-range bus error under `gary_toenb`) and the FPGA's forwarding of local I/O to the motherboard on the real-060 path (`z3660.v`), read 2026-10-02.
- The **2026-10-02 local-I/O peek measurements**, first-party, on an A4000D with a Z3660 ✅ — a supervisor-mode, fault-catching peek tool under AmigaOS: the first read of `$DD0000` never returned; reads of Gary's `$DE0000`/`$DE0001` on the A4000D terminated (`FF`→`7F`, `7F`). The CPLD side is read from the Z3660's CPLD sources (`TERM.vhd`/`BUSTERM.vhd`: termination waits on `DSACK`/`AVEC`/`BERR`, `nTEA` only from the bus-error state, no timeout counter anywhere). The meaning of the A4000's `$DE0000`/`$DE0001` bits is unsourced 🔴.
- The **signed manufacturer compare in stock `autocon()`** ✅ — `amix-a4091` commit `06a7d96` (2026-10-02, `support.c.patch`: the unsigned shift, codegen `swap`/`ext.l` → `clr.w`/`swap`), the matching one-byte `asr.l` → `lsr.l` patch in the 68040/68060 relink tooling the same day, and an A4000D metal run that proved it (an A4092's `0xC0DE0001` handed over in `bootinfo.autocon[]` but unregistered without the fix, registered as card 1 with it).
- The **2026-09-29 stock-kernel RAM-layout measurement** ✅ — on the emulated bench the same 64 MB A3000 motherboard bank boots a kernel that probes for the A3000 SCSI and stops the pinned stock kernel at `s5mountroot VOP_OPEN error 6` (no card 0), symbolised against the stock `autocon()` load-address guess ([quirks §57](../how-it-works/quirks.md#57-loader-placement-a3000-scsi)).
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §2 (stock drivers Zorro II only — the old "no Zorro III mapping" wording corrected by this page; supported expansion), §3 (AUTOCONFIG assigns Zorro II addresses at reset; `autocon()` consumed by the kernel), §5 (`autocon(product_id, dev, &board, &dummy)` 🟡 repo-confirmed — superseded by the stock signature above; driver API surface), §6 (lszorro mechanism, ranges, nibble encoding, ID database; VA2000 and Hydra AutoConfig IDs).
- `asokero/lszorro-amix` repo — `/dev/mem` `mmap()` scan, `0x80`-byte windows, I/O `0xE90000`–`0xEFFFFF` / mem `0x200000`–`0x9FFFFF`, AutoConfig nibble decode, 461-entry ID DB, register-only fingerprinting: <https://github.com/asokero/lszorro-amix>
- `asokero/va2000-amix` repo — VA2000 AutoConfig mfr `0x6D6E` product `0x01`, 4 MB Zorro II window, `autocon()` usage: <https://github.com/asokero/va2000-amix>
- `isoriano1968/hydra-amix` repo — Hydra AutoConfig ID `0x08490001` (2121/1), `autocon()` plus three-way detect: <https://github.com/isoriano1968/hydra-amix>
- The A4091-on-Amix project, <https://github.com/jusii/amix-a4091> — README, `CHANGELOG.md` (dated entries; reproduced locally ✅: Zorro III above the identity map, `sptalloc()`, phantom-A3000, chipset-gated WD33C93 detection), `docs/A4000T-ONBOARD-710.md`, and `src/`/`tools/`.
- `src/kernel-patches/support.c.patch` — the `autocon()` diff with the chipset-gated WD33C93 auto-detection replacing the phantom-A3000 special case (A4091 product id `0x02020054`). The TT-register constants `tt0=0x003F0143` / `tt1=0x807F0143` read from `amiga/ml/ttrap.s` are **not** what the running kernel uses — see [the note above](#the-identity-map).
- The stock `autocon()` signature ✅ — the stock Amix 2.1 kernel source `amiga/kernel/support.c` (the file `support.c.patch` applies to), read first-party: `autocon(pc, index, bp, np)`, `long pc; int index; long *bp; long *np;`, `*bp = cd_BoardAddr`, `*np = cd_BoardSize`, `index` counting matching boards; the caller in stock `amiga/alien/sd.c` `init()`.
- The low-nibble VPOSR correction, 2026-09-28/29 ✅ — `amix-a4091` CHANGELOG 2026-09-29 and the current `src/kernel-patches/support.c.patch` (the id table and the `(id & 0x0F) >= 2` test), found in the review of the contributed `amix-gayle-ide` driver; the matching `amix-z3660scsi` CHANGELOG entry (2026-09-28); and amix-gayle-ide `docs/vposr-aga-gate.md` (<https://github.com/hmlio/amix-gayle-ide>; the OCS/ECS/AGA id table: bit 4 is the video standard, OCS PAL `0x00` / NTSC `0x10`).
- First-party measurement on a running kernel, 2026-08-12/14: AMIX zeroes the 68030 TT registers (E = 0) and the low-1 GB identity map is a section-0 early-termination page descriptor in the MMU root table ✅.
- a4091.device open-source project: <https://github.com/A4091/a4091-software> (A4091 ROM + `ncr53cxxx` SCRIPTS assembler).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — driver model and kernel API context (see [bibliography](../reference/bibliography.md)).
- amigaunix.com — historical and hardware reference: <https://www.amigaunix.com/doku.php/home>
