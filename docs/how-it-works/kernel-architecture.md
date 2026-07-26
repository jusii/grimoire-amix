---
title: Kernel Architecture
summary: Monolithic SVR4 kernel — relinked from /usr/sys object libraries, kernel.c switch tables, 68030 MMU/HAT, STREAMS/TLI/sockets, init/runlevels.
status: draft
---

# Kernel Architecture

Amix runs a **monolithic AT&T System V Release 4 (SVR4) kernel** ✅. There are **no loadable modules**: every driver is statically linked into the kernel, and adding hardware means relinking the kernel image and rebooting ✅. The kernel ships not as full source but as a set of **compiled object libraries under `/usr/sys`**, which you relink into the running kernel (`/unix`) ✅. The one source file you always edit is **`kernel.c`** (the device switch and interrupt tables) ✅.

This page covers the kernel's shape: how it is built and relinked, the switch-table model at a high level, the 68030 MMU/HAT memory layer, the SVR4 networking stack (STREAMS/TLI/sockets), and the system-management surface (`sysadm`, `init`/`inittab`/run levels, virtual consoles). For the full device-driver programming model — `cdevsw`/`bdevsw` field layouts, entry-point naming, the worked `par.c` example — see [the device-driver model](../drivers/driver-model.md). For the exact relink-and-install commands, see [building and installing the kernel](../drivers/kernel-build.md).

## Monolithic, statically linked

Everything that talks to hardware lives in one kernel binary ✅:

- **No dynamically loadable kernel modules.** SVR4 elsewhere grew `modload`-style facilities, but on Amix drivers are compiled in. To gain (or remove) a driver you edit `kernel.c`, relink, and reboot ✅.
- **Drivers are statically linked.** Each driver contributes object code (its `.o`, often with source) that gets linked into the kernel image ✅.
- **Keep the old `/unix`.** Because a bad driver can make the kernel unbootable, the standard procedure is to keep the previous `/unix` (or a known-good boot partition) as a fallback before installing a new one ✅.

This is the same picture the [Ditto driver paper](../reference/bibliography.md) describes for 1990, and the modern community driver repos confirm it still holds for 2.1 ✅.

## The kernel as object libraries in /usr/sys

Amix does **not** ship a complete kernel source tree. Instead ✅:

- The kernel is delivered as **pre-compiled object libraries in `/usr/sys`**. Some `.o` files arrive with source; others are object-only ✅.
- You **relink** these objects (plus any driver objects you add) to produce a new kernel image, then install it as `/unix` ✅.
- The configuration file **`kernel.c`** *is* provided in source — it is the table that wires drivers into the kernel (see below) ✅.

The build directory layout and makefiles live under `/usr/sys` (e.g. `amiga/driver/`, `amiga/console/`, `master.d/`). The mechanical recipe — `make` in `/usr/sys`, copy the image to `/stand`, `make bootpart`, reboot — is documented on [the kernel-build page](../drivers/kernel-build.md), so it is not repeated here.

### Kernel image name: rdbunix vs relocunix

The relinked kernel image has been called by two names over the system's life 🟡:

| Era | Image name | Source |
|---|---|---|
| 1990 (Ditto paper) | `rdbunix` | Ditto paper ✅ |
| 2.1 / modern repos | `relocunix` | community repos ✅ |

Treat this as a **historical rename** of the same artifact; verify which name your version uses before scripting around it 🟡. On a 2.1 system the modern repos build `relocunix`, copy it to `/stand`, then run `make bootpart KERNEL=relocunix` to write the boot partition ✅.

## kernel.c and the switch tables (high level)

The kernel is **table-driven**. `kernel.c` (under `master.d/`) holds the tables that map hardware and system events to driver code ✅:

- **`cdevsw[]`** — the character-device switch, indexed by **major number**. Each slot is a `struct cdevsw` of entry-point function pointers (`open`, `close`, `read`, `write`, `ioctl`, …) ✅.
- **`bdevsw[]`** — the block-device switch, also indexed by major number; its core entry point is `strategy()` ✅.
- **`int2_tbl[]`** — level-2 autovector **interrupt** handlers (e.g. `parintr`, `a2090intr`, `a2091intr`); a **level-6** table exists too ✅.
- **`init_tbl[]`** (also seen as `io_init[]`) — one-shot **boot-time init** functions (e.g. `parinit`, `coinit`) ✅.

The kernel knows a device only by its **major** (which driver) and **minor** (which sub-device) number — never by the `/dev` name ✅. Adding a driver therefore means adding `extern` declarations plus a switch-table slot (and, if the device interrupts or needs boot init, an interrupt/init-table entry) in `kernel.c`, then relinking ✅.

That is deliberately the *shape* of the model here. The exact `struct cdevsw`/`struct bdevsw` field lists, the `nodev`/`notty`/`nostr`/`nullflag` stub conventions, the driver-tag naming rule, and real major numbers (e.g. SCSI disk block major 18, parallel char major 21) all live on [the device-driver model page](../drivers/driver-model.md) ✅.

**Note:** the full original `master.d/kernel.c` has not been publicly archived; the table schema above is reconstructed from the Ditto paper plus the modern driver repos 🔴 (for the table *shape*; the individual slots used by shipped/added drivers are ✅ where a repo or the paper cites them).

## 68030 MMU and the HAT layer

Amix uses the **full 68030 MMU** through SVR4's **HAT (Hardware Address Translation)** layer ✅ — the machine-dependent code that maps virtual addresses to physical pages and isolates user from kernel space. A real MMU is mandatory: a 68000, or an MMU-less 68EC020/68EC030, **cannot run Amix** ✅. A `68881`/`68882` FPU is also required (no soft-float) ✅.

Evidence the HAT layer is live in the shipped kernel: the install bootstrap on `amix_21_boot.adf` contains the SVR4 HAT panic string `hat_vtokp_prot: user addr in kernel space` ✅ (from `amix_21_boot.adf` analysis via `tools/inspect-adf.sh`).

Two hard memory facts follow from this layer ✅:

- **16 MB Fast RAM ceiling**, hard-coded in the kernel. Exceeding it **mis-maps the SCSI drive** ✅. (A separate, far-higher limit on total *describable* RAM fails silently — see [the RAM ceiling](ram-ceiling.md).)
- **No Zorro III.** The memory-mapping layer cannot address Zorro III space, and that source was never shipped, so it cannot be community-fixed — Amix is **Zorro II only** ✅.

The processor cutoff is set by this same MMU dependency: the kernel **predates the 68040 MMU**, so there is **no 68040/68060 support**, and an **A4000 cannot officially run Amix** ✅. For the full hardware envelope see [hardware and requirements](hardware.md); for why these limits bite in practice see [quirks](quirks.md); for the current 040/060 situation see [Amix on 68040 and 68060](68040-68060-status.md).

### The kmem allocator — what a driver can assume ✅

The layout of the kernel heap allocator was recovered by full disassembly of `kmem_alloc`/`kmem_free`/`kmem_allocbpool`/`sptalloc`/`segkmem_alloc`/`page_get` in the shipped kernel ✅. It is worth knowing for any driver-debugging, and one property of it is a load-bearing **DMA hazard**:

| Request size | Served from | Alignment / physical layout |
|---|---|---|
| ≤ 256 B | small buddy pool (classes 16..256) | pools carved from 4096-aligned 8-page regions |
| 257 .. 4096 B | big buddy pool (classes 512..4096) | same 4096-aligned 8-page regions |
| > 4096 B | `sptalloc` whole pages (VA = pfn << 11) | **page-aligned, but physically SCATTERED** |

- `kmem_alloc` returns **≥ 16-aligned** pointers. A "returned" pointer that is `0 mod 2048` but not `8 mod 16` relative to its wrapper cannot have come from the allocator — a handy alignment argument when a theory needs disproving. ✅
- **`kmem_free` writes `[next][prev]` freelist links into a freed chunk's first 8 bytes**, so use-after-free / wild-free corruption characteristically shows **pointer-shaped values at a block's head**. ✅
- **The DMA hazard (the important one):** a `> 4096`-byte allocation is virtually contiguous but **physically scattered** — `segkmem_alloc` pops arbitrary frames off `page_freelist` and maps them at consecutive virtual addresses with no physical adjacency. So `vtop()` on such a buffer is valid for **exactly one page** (`NBPP = 2048`), and any single DMA transfer that crosses a page boundary lands its tail in a **different, unrelated physical frame**. This is the mechanism behind the cdfs wild-write corruption; the driver-side rule (page-align every DMA target, guard `(va & (NBPP-1)) + nbyte > NBPP`) is on [the driver model → DMA-alignment contract](../drivers/driver-model.md#the-dma-alignment-contract-a-vtopd-buffer-must-not-cross-a-page-boundary). ✅

## SVR4 networking: STREAMS, TLI, sockets

Networking is built on the standard SVR4 stack ✅:

- **STREAMS** is the underlying I/O framework for the TCP/IP and network drivers ✅. STREAMS drivers are a distinct third driver class (a character driver carrying a `streamtab`) — used for networking; see [the device-driver model](../drivers/driver-model.md) and the [Hydra STREAMS/DLPI driver case study](../drivers/case-studies/hydra.md) ✅.
- **TLI** (Transport Layer Interface) **and BSD sockets** are both available as programming APIs over that stack ✅.
- The kernel is **POSIX.1**-conformant ✅.

At the user level the native Ethernet device is `aen0` (the A2065 LANCE driver) ✅. Static IP only (no DHCP) 🟡; DNS is off by default (resolves via `/etc/hosts`) and must be enabled explicitly 🟡. The networking specifics — enabling DNS, default routes, NFS, SLIP — are covered on [the networking page](networking.md), not here.

## System management surface

Amix exposes the usual SVR4 administration model ✅:

- **`sysadm`** is the menu-driven admin tool; Amix also ships an **`amixadm`** wrapper used to finish post-install configuration (nodename, domain, timezone, date, root password, X11) ✅.
- **`init` + `/etc/inittab` + run levels** govern system state and what starts at each level ✅. Shutting down to reboot is `shutdown -i6` (run level 6) ✅; a kernel install is followed by exactly that ✅.
- **Virtual consoles** are switched with **Alt+F1 … Alt+F8** ✅.
- **Packaging** uses the SVR4 tools `pkgadd` / `pkgmk` / `pkgtrans` (plus `pkgproto`) ✅. The Amix-specific **`amixpkg`** wrapper is widely reported as flaky/"broken" 🟡, yet the installer itself drives package installation through it, e.g. `amixpkg -i -m -d -r /mnt -y standard` ✅. See [the toolchain page](../drivers/toolchain.md) for packaging detail.

One userland gotcha worth flagging at the kernel/system level: Amix's `/bin/sh` is **pre-POSIX** — no `$(...)` command substitution, no `grep -q` ✅. This bites kernel-rebuild scripts and is documented on [quirks](quirks.md).

## See also

- [How it works — overview](overview.md) — where the kernel sits in the whole system.
- [The device-driver model](../drivers/driver-model.md) — `cdevsw`/`bdevsw` internals, major/minor numbers, entry-point naming.
- [Building and installing the kernel](../drivers/kernel-build.md) — the exact relink, `make bootpart`, and reboot recipe.
- [Hardware and requirements](hardware.md) — MMU/FPU/RAM/Zorro envelope.
- [Quirks](quirks.md) — the 16 MB ceiling, no-Zorro-III, pre-POSIX `/bin/sh`, and friends.
- [Glossary](glossary.md) — HAT, STREAMS, TLI, run level, major/minor.

## Sources

- `sources/research-brief.md` §4 (Kernel architecture) and §5 (Device-driver model, high level), with §2 (hardware limits) and §11 (networking/userland) for cross-references.
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (the driver paper) — kernel as object libraries in `/usr/sys`, `kernel.c` switch tables, `rdbunix` image, add-a-driver procedure.
- `amix_21_boot.adf` analysis via `tools/inspect-adf.sh` — embedded `hat_vtokp_prot: user addr in kernel space` HAT/MMU panic string.
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — installer use of `amixpkg -i -m -d -r /mnt -y standard` and `shutdown -i6`.
- Modern community driver repos confirming the 2.1 build/relink model and the `relocunix` image name: `github.com/asokero/va2000-amix`, `github.com/isoriano1968/hydra-amix`.
- AT&T SVR4 *DDI/DKI Reference Manual* and *STREAMS Programmer's Guide* (the standard SVR4 substrate cited by the Ditto paper).
- The kmem-allocator map (buddy pools / `sptalloc` whole-page scatter; `vtop()` valid for one page; freelist links in a freed chunk's first 8 bytes) — full disassembly of `kmem_alloc`/`kmem_free`/`kmem_allocbpool`/`sptalloc`/`segkmem_alloc`/`page_get` in the shipped kernel, and the DMA-scatter corruption reproduced on a real A4000 + Z3660, from the **amix-cdfs** port @ `31e8c3b` (`NBPP = 2048` per `sys/immu.h`). ✅ See [the driver model DMA-alignment contract](../drivers/driver-model.md#the-dma-alignment-contract-a-vtopd-buffer-must-not-cross-a-page-boundary).
