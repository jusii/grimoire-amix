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
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — driver model and kernel API context (see [bibliography](../reference/bibliography.md)).
- amigaunix.com — historical and hardware reference: <https://www.amigaunix.com/doku.php/home>
