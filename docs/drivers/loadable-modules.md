---
title: Loadable Kernel Modules (amigaux 1.1, in development)
summary: The loadable-module system the amigaux project is building for its 1.1 release — own boot loader, module core, kbootset generations, the ABI kit and kabi rule, module classes, the static floor, the kernel facts a module author needs (interrupt levels, kmem budget, board windows, DMA), and what is proven where as of 2026-10-29.
status: draft
---

# Loadable Kernel Modules (amigaux 1.1, in development)

**Stock Amix 2.1 and every kernel of the amigaux 1.0 release are monolithic: nothing loads into a
running kernel** ✅ ([kernel architecture](../how-it-works/kernel-architecture.md#loadable-modules)).
The amigaux project is building a loadable-module system for its **1.1** release, on both CPU lines
and on every install medium. Its code is public in the [`amigaux/amix`](https://github.com/amigaux/amix)
monorepo, under `kernel/dlm` (the loader, the module core, the composer and the ABI kit) and
`kernel/modules` (generic modules) ✅. As of **2026-10-29** it runs end to end in emulation on both
lines and on real 68060 hardware, and **nothing of it is released**: no module, module kernel or
loader is in the public package catalog ✅. Interfaces are versioned (below) but can still change
before 1.1.

If you are writing a driver for a released Amix today, use the static model:
[the driver model](driver-model.md) and [building the kernel](kernel-build.md). This page is for
anyone who wants to build a module against the kit, or who needs the kernel facts the module work
established (they hold for static drivers too).

## Status on 2026-10-29

| What | Where it stands | Tag |
|---|---|---|
| Code | `kernel/dlm`: `loader/` (boot1, boot2), `core/` (a patch queue over the upstream core), `kbootset/`, `modtools/`, `abi/` (the kit sources), host tests; `kernel/modules`: `monsw`, `ramdisk` | ✅ |
| Emulation (Amiberry), both lines | module boots and root-on-a-module boots, the CD boot, the floppy pair, the network-install medium, the RAM-disk installer, upgrade and rollback | ✅ first-party record |
| Real hardware, 68060 line | A4000 + Z3660 (68LC060 and full 68060): network modules polled and interrupt-driven, RTG with the monitor switch, root on the Z3660's SCSI, on an A4092, on Gayle IDE; the A4000T's onboard 53C710 as a root controller | ✅ first-party record |
| Real hardware, 68030 line | no real 68030 Amiga tested yet; the only "030" metal rows are a Z3660 in its 68030-emulation mode | 🔴 open |
| Release | 1.1 only; the package catalog at `pkg.amigaux.org` has no kernel-space entries | ✅ |

## The parts

| Part | What it is |
|---|---|
| **boot1, boot2** | The project's own boot loaders, written from scratch, replacing the stock bootstrap on 1.1 media. boot2 reads a *generation manifest*, loads the kernel and the root-class modules as separate files, reads disks, floppies and 2048-byte CD blocks, and offers a boot menu with a rollback key and a safe mode ✅ |
| **Module core** | A patch queue on the MIT-licensed DLM ("dynamically loadable modules") core by kdedon, from the [ashnazag](https://github.com/kdedon/ashnazag) project (one SVR4 kernel for 68k Mac, Atari and Amiga). The queue adds pre-root loading, ABI identity, match keys, disk-controller and filesystem registration, interrupt attachment and a halt pass ✅. The queue's base is upstream `b736c59` (2026-10-14) or later; that project's earlier commits are GPL-2.0 ✅ |
| **kbootset** | The composer, a userland program. It builds a *generation* (kernel + root modules + manifest + module store) from the installed packages, writes it to the boot slice behind fail-closed checks with read-back, keeps the previous generation and the pristine install generation, rolls back, and marks a generation good only after a full multi-user boot ✅ (spec; proven in emulation) |
| **ABI kit** | Per kernel line: the headers, the list of kernel names a module may import (the DDI), the major registry, the module tools (`mkmod`, `modfix`, `modcheck.py`), a make fragment and a sample module. A host-side artefact: nothing in it runs on Amix ✅ |
| **kinfo** | A read-only identity device on the static floor (character major 53): CPU line, kabi, generation, boot and root disk, board set, loader record ✅ (spec) |

## Two kernel lines, one kabi rule

Modules are built per **kernel line**: `k30` (68030, 2 KiB pages) and `k46` (68040/68060, 4 KiB pages)
✅. The 68040 and 68060 kernels of the module line differ in one byte (a CPU stamp), so k46 is one ABI
for both CPUs ✅ (measured: `kernel/dlm/docs/measurements/2026-10-26-m-reg1-m-abi1.md`). One module
source gives one object per line, shipped as two packages (`<name>-k30`, `<name>-k46`) ✅.

Each kernel carries a **kabi** tag, `k30.1.N` / `k46.1.N` ✅:

| Minor | Adds |
|---|---|
| 1.0 | the first DDI |
| 1.1 | `sd_register` on both lines, `root_defer` on k46 |
| 1.2 | `iodone`, `ramdisk_image`, `vfs_register`, `root_defer` on k30, the DMA calls, the filesystem helpers |
| 1.3 | what the Paula audio module needs (`AllocMem`, `FreeMem`, `displaytype`, `paula_busy`, `audio_nopen`); only a kernel whose cut patches the stock audio driver exports it |

A module's tag is the highest minor among the names it imports, never below the kit's `KABI_MIN`
(1.2 at present), and it loads on a kernel of that minor or later ✅. The kit's `abi.txt` fingerprint
covers the DDI's **data** names with their sizes and the structure layouts a module shares with the
kernel; adding a function name changes the minor, not the fingerprint ✅ (`kernel/dlm/abi/README.md`).

## Module classes

| Class | Loaded | Typical member |
|---|---|---|
| `root` | placed in memory by boot2 and linked by the core **before the root is mounted** | root disk controllers (Z3660 SCSI, A4091/A4092, Gayle IDE, the A4000T onboard 53C710), root filesystems (ufs, s5, cdfs), the RAM disk |
| `boot` | after the root is mounted, from the generation's store, checked by SHA-256 | network drivers (z3660eth), anything needed every boot |
| `demand` | at the first open of one of its majors, or before a module that names it in `depend` | the monitor switch (`monsw`) |

✅ (`kernel/dlm/docs/abi/writing-a-module.md` §3). The core loads only modules listed in the booted
generation's manifest, each checked by SHA-256, unless the boot menu's development load is on ✅.

### The static floor and safe mode

What stays linked into every kernel, on both lines alike ✅ (`kernel/dlm/docs/spec/70-static-floor.md`):
the base kernel (VM, processes, STREAMS, the non-root pseudo-filesystems, the inet stack), the console
and serial port, the floppy driver, floating-point support (the 68040/68060 FPE), the stock WD33C93
host adapters (A3000 onboard SCSI, A2091/A2090) with the `sd`/`dd` disk layer, the A2065 ethernet,
the QIC tape driver, `kinfo` and the module core. Everything else is a module, and a floor member is
never also shipped as a module.

**Safe mode** = the floor kernel + the root controller's module + the root filesystem's module, and
nothing else; the kernel learns it is in safe mode from boot2's loader record ✅. A stock-controller
box needs only its root filesystem module. Safe mode has no network unless the administrator marks the
network module `safe` in `/etc/conf/modreg.local.d` ✅ (spec).

## Writing a module — the short form

The full guide is `kernel/dlm/docs/abi/writing-a-module.md` in amix; the kit's `sample/hello` is the
template. You need the pinned [gcc-cross-amix](toolchain.md) (`m68k-cbm-sysv4-gcc` 2.7.2.3) on `PATH`,
the kit for the line (`make kit` in `kernel/dlm`), and Python 3 ✅. **Kernel space is never built with
GCC 14** ✅ — see [the toolchain page](toolchain.md).

```c
#include "sys/types.h"
#include "sys/moddefs.h"
#include "sys/amixddi.h"

extern int printf();

static int
hello_load(params)
	char *params;		/* "name=value ..." from the manifest, or 0 */
{
	printf("hello: loaded\n");
	return 0;		/* or ENXIO: no hardware, the module is not kept */
}

static int
hello_unload()
{
	printf("hello: goodbye\n");
	return 0;
}

MOD_MISC_WRAPPER(hello, hello_load, hello_unload, "the ABI kit's sample module");
```

A `Master` file beside it gives the `.moddata` keys (`$modtype`, `$class`, `$majors`, `$match`,
`$rank`, `$fs`, `$depend`, `$unload`, `$param`, `$desc`) and the definition line; a `Makefile` sets
`KIT`, `MODULE`, `OBJS` and includes `$(KIT)/mk/module.mk`. `make` gives `build/<line>/mod.d/<name>`,
checked by `modfix` and `modcheck.py`, which make the same refusals the core makes at load time ✅.
`kabi` and `cc` come from the kit; never write them yourself ✅.

What changes from a static driver ✅ (`writing-a-module.md` §4):

- `_load` does the init work (find, map, set up the board) and returns `ENXIO` with nothing left
  behind if there is no board; `_unload` undoes everything; `_halt` stops a board that can interrupt or
  write memory.
- No `cdevsw` edit, no `init_tbl` entry, no `parinit` wrapper: majors come from `.moddata`, and each
  major must be registered to the module's name in the kit's `registry/majors`.
- Interrupts go through `intr_attach`; polled stays the default.
- The console goes through `cons_hook_set`, never `conputc`.

## Kernel facts a module (or any driver) author needs

These were measured or read from the kernels during the module work. They are properties of the
stock kernels and the 040/060 port, so they bind static drivers as much as modules.

### Interrupt levels

- In these kernels **no `spl` masks level 6**: `spl5`–`spl7` stop at level 4 (the kernels run with
  fast interrupts) ✅ (disassembly; `kernel/dlm/docs/abi/ddi.md`). A level-6 handler therefore calls
  **no** kernel function: it acknowledges, masks and flags, and the work runs at level 4 or below ✅.
- **A STREAMS open runs at level 4** (the stock `qattach` raises the SR to `0x2400`), so a level-2
  interrupt stays pending until the open returns. A self-test inside an open that waits for its own
  level-2 interrupt with a spin never sees it: wait with a one-tick `timeout`/`sleep` round, or test
  at load time ✅ (disassembly and emulator).
- A root-class module's `_load` runs in the **root pass**: process 0, level 7, the clock stopped; it
  may not sleep, arm a timeout or read a file ✅.

### Kernel memory: what a module can get

The kernel heap's large requests share the **fixed 4 MiB kernel map** with `page[]` and the u-areas —
the same arena behind the [RAM ceiling](../how-it-works/ram-ceiling.md) — so the more RAM a box has,
the less kmem is left ✅. Measured in emulation on the module kernels ✅
(`kernel/dlm/docs/measurements/2026-10-26-u1.md`, `2026-10-26-u4.md`):

| When | k46 at 128 MB | k30 at 64 MB |
|---|---|---|
| Root pass, largest single `KM_NOSLEEP` | 2 MiB | 1 MiB (2 MiB fails) |
| After multi-user, largest single `KM_NOSLEEP` | 256 KiB (512 KiB fails) | 512 KiB (1 MiB fails) |
| After multi-user, total in 64 KiB pieces | about 320 KiB | about 640 KiB |
| `KM_SLEEP` one step above the `KM_NOSLEEP` limit | **never returns** | **never returns** |

A `KM_SLEEP` request that the map cannot satisfy sleeps for ever and the box does not shut down
cleanly ✅. The rules that follow, enforced by the kit: a module's image is at most 256 KiB and its file
under 256 KiB; each kmem request is at most 256 KiB; every `KM_NOSLEEP` result is checked for 0; a
module whose load needs more than about 160 KiB belongs in boot class, not demand class ✅. No metal
number exists for these figures yet 🔴.

#### At 32 MB the whole allocator is small ✅ {#kmem-at-32-mb}

On a 32 MB box after multi-user,
draining the allocator with `KM_NOSLEEP` pieces from 1 MiB down to 16 bytes, until even 16 bytes
fails, yields about **2.36 MB on k46** (2 364 800 – 2 365 696 bytes) and **1.57 MB on k30**
(1 564 288 – 1 567 296 bytes), repeatable within a few KB (emulated A4000 + Z3660, two kernels per
line). A demand-class CD filesystem (cdfs 1.1.0-2) keeps 85–94 KB of that after `umount` and
187–198 KB while mounted with a 1 MiB file read, about 4–6 % and 8–12 % of the allocator ✅.

**A small `KM_SLEEP` is no safer than a large one** ✅. On an empty allocator a 4096-byte
`KM_SLEEP` request sleeps until memory is freed, and it can miss that wakeup and sleep on long after
memory is back (seen once in four runs; why is not known 🔴) ([the kmem allocator](../how-it-works/kernel-architecture.md#kmem-empty)). So code
that runs in a user's process at first use (an open, a mount, a first exec) asks `KM_NOSLEEP` and
fails with `ENOMEM`, whatever the size: the first-use rule of the driver-to-module contract
(`kernel/dlm/docs/contracts/C3-6-driver-to-module.md` §1.1).

### Board windows and DMA

- **Below `VSECT1` (0x40000000) the kernels map physical addresses one to one**: a board window
  there is reachable at `phystokv(phys)`, the identity, with nothing to map ✅ (`ddi.md`; both kits'
  `<sys/amixddi.h>`). The two lines do it differently ✅. On k30 the TT registers are off and a
  section-0 early-termination descriptor in the MMU root table maps the span
  ([the identity map](zorro-autoconfig.md#the-identity-map)). On k46 it is the transparent-translation
  register DTT0, and DTT1 maps `0x80000000`–`0xFFFFFFFF` the same way; only the band
  `0x40000000`–`0x7FFFFFFF` needs a page mapping
  ([the 040/060 user address space](../how-it-works/68040-68060-status.md#k46-tt-user-access)).
- Above it, `sptalloc(npages, mode, pfn, 0)` maps the pages from the same fixed 4 MiB `sptmap`; on a
  box with much RAM a large run may not be left. Map only what you need ✅. On k46, `dev_kvmap(phys,
  nbytes, cm, flags)` maps a device window at a cache class (0x40 non-cacheable serialised, for
  registers; 0x60 non-cacheable) ✅.
- **The k46 kernel heap is not identity-mapped** (a heap address in the `0x402…` range sits at a
  high physical address), so never hand a bus master the address of kmem or of the module's own
  memory ✅. From kabi 1.2 the DDI has DMA calls: `dma_alloc` (at most 64 KiB, 16-aligned, reachable by
  a Zorro III master; on k46 a heap block through its cache-inhibited DTT0 alias), `dma_prepare`,
  `dma_complete`, `dma_addr` (on k30 it may return a bounce buffer, or 0 meaning "do not arm") and
  `dma_free` ✅ (`ddi.md`, DMA section).

### Smaller traps

- **`HZ` is 60 on both lines** ✅: the stock `sys/param.h` takes the clock from the CIA-A timer
  (`CLOCK 1`), so it is 60 ticks a second on PAL and NTSC machines alike. In emulation `lbolt`
  advanced about 1250 ticks in about 21 s, and a `timeout(…, 20 * HZ)` fired after 1201–1202 ticks.
- **The kernel `printf` has no `l` modifier**: it takes `%s %d %u %x %o %c` only ✅ (`ddi.md`).
- `<sys/systm.h>` declares `cputype` as a `short`, but the kernels define a `long`: read it through
  the kit's `DDI_CPUTYPE` ✅.
- The module core takes the six system-call slots **64–69**, which are `nosys` in the shipped kernels
  ✅ (`core/upstream/NOTES.md`).
- A stock header's tentative definition (`int ifnet;`) becomes a private copy in your module; the
  checker warns about every COMMON symbol ✅.

## Majors in the module registry

The kit's `registry/majors` is the 1.1 allocation; the core refuses a module whose majors are not
registered to it ✅. It agrees with the [major-number registry](../reference/major-number-registry.md):

| Major | Module |
|---|---|
| c 49 | `z3660rtg` (the Z3660 RTG target of the zz9000 driver) |
| c 51 | `z3660eth` |
| c 52 | `monsw`, the monitor switch |
| c 53 | `kinfo` (static floor) |
| c 54 | `paula` (the static Paula driver's 53 is `kinfo`'s in 1.1) |
| b 20 | `ramdisk` (replaces the stock `ram` driver's row) |

## The two example modules

| Module | Class | What it shows |
|---|---|---|
| [`monsw`](https://github.com/amigaux/amix/tree/master/kernel/modules/monsw) | demand, `c:52` | A card-independent monitor switch (CIA-B PRA bits 4 and 2) with a kernel API for RTG drivers (`monsw_register`, `monsw_set`, `monsw_lastclose`) and `/dev/monsw` ioctls. The same source still builds the static object the 040/060 port links ✅ |
| [`ramdisk`](https://github.com/amigaux/amix/tree/master/kernel/modules/ramdisk) | root, `b:20` | Unit 0 is the miniroot image boot2 placed at the top of the largest fast-memory region (below `VSECT1`, so reached by identity with nothing mapped); units 1 and 2 are scratch disks allocated in ≤ 256 KiB `KM_NOSLEEP` pieces at first open ✅ |

The stock Amix 2.1 RAM disk (`ram`, block major 20, three kmem-backed units of 128 KiB, 512 KiB and
2 MiB) cannot present an image loaded before the kernel started, which is why the module kernels drop
it for `ramdisk` ✅ (`kernel/modules/ramdisk/README.md`).

## See also

- [Kernel architecture](../how-it-works/kernel-architecture.md#loadable-modules) — the monolithic stock model.
- [The RAM ceiling](../how-it-works/ram-ceiling.md) — the fixed 4 MiB kernel arena behind the kmem budget.
- [Toolchain](toolchain.md) — gcc-cross-amix for kernel space, gcc14-cross-amix for userland.
- [Major-number registry](../reference/major-number-registry.md).
- [Composing multi-driver kernels](kernel-composition.md) — the static-kernel answer the module system replaces in 1.1.

## Sources

- The **identity map on each line** ✅ — k30: the first-party measurement of the TT registers and the root table on a running kernel (see [Zorro AutoConfig](zorro-autoconfig.md#the-identity-map)); k46: the port's `KNOWN-ISSUES.md` (DTT0 over `0x00000000`–`0x3FFFFFFF`, DTT1 over `0x80000000`–`0xFFFFFFFF`, the band between them page-mapped; [`amigaux/amix-040-060-port`](https://github.com/amigaux/amix-040-060-port) `k46-module`); `VSECT1` and `phystokv` from both kits' `<sys/amixddi.h>`.
- [`amigaux/amix`](https://github.com/amigaux/amix) @ `95bf2f3` (2026-10-29), public ✅:
  `kernel/dlm/README.md`; `kernel/dlm/abi/README.md` (kit contents, kabi minors, `abi.txt`);
  `kernel/dlm/abi/registry/majors`; `kernel/dlm/docs/abi/writing-a-module.md` (§1–§9);
  `kernel/dlm/docs/abi/ddi.md` (contexts, the level-6 rule, memory, `VSECT1`, the DMA section);
  `kernel/dlm/docs/spec/00-overview.md` and `70-static-floor.md`;
  `kernel/dlm/docs/measurements/2026-10-26-u1.md`, `2026-10-26-u4.md` (kmem),
  `2026-10-26-m-reg1-m-abi1.md` (one k46 ABI; free syscall slots); `kernel/dlm/core/upstream.pin` and
  `core/upstream/NOTES.md` (the adopted core, its licence and base commit);
  `kernel/modules/README.md`, `monsw/README.md`, `ramdisk/README.md`.
- The kernel-module campaign (first-party record, 2026-10-25 to 2026-10-29) ✅: the emulator rows on
  both lines and the metal rows on two A4000-class machines with a Z3660 (68LC060 and 68060), the
  STREAMS-open level read from the stock `qattach`, the k46 heap mapping read from the port. Bench
  hosts and run numbers are project bookkeeping and are not reproduced here.
- The **allocator at 32 MB, small `KM_SLEEP` and `HZ`** (first-party record, 2026-11-01) ✅ (🟡/🔴
  where tagged): the amix `kernel/dlm` low-memory runs on the 1.1 module kernels of both lines
  (emulated A4000 + Z3660, 32 MB, multi-user), with a test module that drains the allocator and
  frees it from a 20 s `timeout`: [`amigaux/amix`](https://github.com/amigaux/amix)
  `kernel/dlm/tests/bench/lowmem/` and `kernel/dlm/tests/bench/README.md` ("Low memory at first
  use", `53624e5`, on `master`); `kernel/dlm/docs/contracts/C3-6-driver-to-module.md` §1.1; `HZ` from
  the stock `usr/include/sys/param.h` in [`amigaux/amix-system`](https://github.com/amigaux/amix-system/blob/7cba961/usr/include/sys/param.h).
- The public package catalog, `http://pkg.amigaux.org/catalog`, read 2026-10-29: catalog format 1,
  41 rows, no kernel-space block ✅.
