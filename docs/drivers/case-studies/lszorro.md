---
title: "Case Study: lszorro-amix"
summary: A userspace lspci-style scanner that walks the Zorro II AutoConfig chain by mmap-ing /dev/mem.
status: draft
---

# Case Study: lszorro-amix

`lszorro-amix` is a small userspace utility for Amix that lists the
[Zorro II](../../how-it-works/glossary.md) expansion boards plugged into the machine — the Amiga
equivalent of `lspci`. ✅ It is a single native C file you compile on the box itself, it needs root
because it reads physical memory through `/dev/mem`, and it works by decoding the same
[AutoConfig](../zorro-autoconfig.md) data the kernel reads at reset. Unlike the kernel, it runs entirely
in userspace and touches no driver code, which makes it the easiest way to confirm *what hardware Amix
can actually see* before you start writing a driver for it.

Repo: <https://github.com/asokero/lszorro-amix>. ✅ Like the other modern case studies, it targets
**Amix 2.1p2a on an Amiga 3000 (68030), Zorro II only.**

## What it is for

Before you write or debug a [device driver](../driver-model.md), you need to answer one question: does
the board even show up on the bus, and with what manufacturer/product IDs? `lszorro` answers exactly
that from userspace, with no kernel rebuild and no `mknod`. ✅

It is also a teaching artifact: it implements the full AutoConfig nibble-decode in plain C, so you can
read one file and understand the wire format the kernel's `autocon()` discovery relies on. See
[Zorro AutoConfig](../zorro-autoconfig.md) for the protocol itself; this page focuses on how `lszorro`
reads it from a running Amix system.

## Build and run

✅ It is a single source file compiled with the native compiler:

```sh
cc lszorro.c -o lszorro
```

This uses the system [`cc`](../toolchain.md) — no cross-toolchain, no kernel headers, no relink. Run it
as **root**, because it opens `/dev/mem`:

```sh
./lszorro
```

**Note:** `/dev/mem` is the character device that exposes physical memory; opening it requires
`uid=0(root)`. ✅ A non-root run fails at `open()`.

## How it works

### 1. Open physical memory and mmap small windows

✅ `lszorro` opens **`/dev/mem`** and uses `mmap()` to map **128-byte (`0x80`) windows** onto candidate
board base addresses. Each Zorro II AutoConfig register area is 256 bytes of address space carrying the
board's ID nibbles, so a small window per slot is enough to read the fingerprint without mapping whole
multi-megabyte board apertures.

Mapping in small windows (rather than one giant mapping) keeps the tool cheap and avoids faulting on
address ranges that have no board behind them.

### 2. Scan the AutoConfig address ranges

✅ It scans the two regions where Zorro II boards land:

| Region | Address range | Typical contents |
|---|---|---|
| I/O / config slots | `0xE90000`–`0xEFFFFF` | register-window ("I/O") boards |
| Zorro II memory | `0x200000`–`0x9FFFFF` | memory-mapped boards (framebuffers, RAM apertures) |

These are the standard Zorro II spaces; boards are placed there by the Amiga AUTOCONFIG mechanism at
reset, and Amix inherits those assignments (Zorro II only — there is **no Zorro III** support in Amix
✅; see [Hardware](../../how-it-works/hardware.md)).

### 3. Decode the AutoConfig nibble format

✅ The AutoConfig ID is not stored as plain bytes. `lszorro` decodes the Zorro nibble encoding:

- Each logical byte is split across the address space as **two nibbles**, read from separate offsets.
- The **upper nibble** appears on data lines **D15–D12**.
- **Most fields are stored in ones-complement** (bit-inverted) and must be inverted back before use.

Getting this decode right is the whole trick — the same decode the kernel does internally. The page on
[Zorro AutoConfig](../zorro-autoconfig.md) gives the field-by-field layout (ER_Type, manufacturer,
product, board size, serial); `lszorro` is a concrete, readable reference implementation of it.

### 4. Resolve IDs against a 461-entry database

✅ A raw `(manufacturer, product)` pair is just numbers. `lszorro` ships a **461-entry ID database
imported from the Linux kernel's Zorro device list**, so it can print human-readable manufacturer and
board names instead of bare hex. This is the same provenance as the IDs Linux/m68k uses, which makes
cross-referencing community hardware lists straightforward.

### 5. Fingerprint register-only boards

✅ Some boards advertise only a register window with no AutoConfig ROM database entry that fully
identifies them. `lszorro` can still recognize specific ones — for example the **MNT VA2000 RTG card**
(see [the VA2000 driver case study](va2000.md)) — by **fingerprinting the registers** rather than
relying solely on a database name match. So a board you are about to write a driver for can be confirmed
present even when the generic ID table is unhelpful.

## What it cannot see

✅ **`lszorro` cannot list RAM expansion boards or accelerator/CPU boards that present no AutoConfig
ROM.** AutoConfig is how a board announces itself in the scanned config space; hardware that doesn't
participate in AutoConfig (plain Fast RAM apertures, many accelerators) simply isn't visible to this
scan. If a board is missing from `lszorro` output, that is the first thing to check — absence here does
*not* mean the board is broken, only that it has no AutoConfig presence to enumerate.

This is a limitation of the AutoConfig protocol itself, not of the tool. To reason about RAM and CPU
limits instead, see [Hardware](../../how-it-works/hardware.md) (the kernel's 16 MB Fast RAM ceiling and
the 68020/68030-with-MMU requirement ✅).

## Why it matters for driver work

- **Pre-flight check.** Run `lszorro` to confirm a target board enumerates and to read its real
  manufacturer/product IDs before hardcoding them in a driver's `autocon()` call. The VA2000, for
  instance, enumerates as AutoConfig **mfr `0x6D6E`, product `0x01`** ✅ — exactly the values its driver
  expects.
- **No kernel risk.** Because it lives entirely in userspace and never modifies `kernel.c` or relinks
  `/unix`, you can iterate on hardware identification without the reboot-and-pray loop of kernel driver
  development described in [the driver model](../driver-model.md).
- **Readable AutoConfig reference.** The decode is the canonical worked example for the nibble format if
  you need to do the same parse inside a kernel probe routine.

## See also

- [Zorro AutoConfig](../zorro-autoconfig.md) — the protocol `lszorro` decodes (field layout, nibble encoding).
- [Case Study: va2000-amix](va2000.md) — the register-only RTG board `lszorro` can fingerprint.
- [The Amix driver model](../driver-model.md) — `cdevsw`/`bdevsw`, `autocon()`, and the kernel-rebuild loop `lszorro` lets you avoid.
- [Hardware](../../how-it-works/hardware.md) — Zorro II-only limit and why RAM/accelerator boards are invisible to AutoConfig scans.
- [Device list](../../reference/device-list.md) — major/minor numbers and `/dev` nodes referenced across the driver docs.

## Sources

- Research brief §6 (`asokero/lszorro-amix` — userspace Zorro II scanner): single-file native `cc`
  build, `/dev/mem` + `mmap()` `0x80` windows, scan ranges `0xE90000`–`0xEFFFFF` and
  `0x200000`–`0x9FFFFF`, AutoConfig nibble decode (upper nibble D15–D12, ones-complement fields),
  461-entry ID DB imported from the Linux kernel Zorro list, register-only fingerprinting (e.g. VA2000),
  and the RAM/accelerator-board blind spot.
- Research brief §2 (Hardware): Zorro II only / no Zorro III; 16 MB Fast RAM ceiling.
- Research brief §6 (`asokero/va2000-amix`): VA2000 AutoConfig mfr `0x6D6E`, product `0x01`.
- Repository: <https://github.com/asokero/lszorro-amix>.
