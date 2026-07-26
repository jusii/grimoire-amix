---
title: Building & Installing a Kernel
summary: The /usr/sys object libraries, editing kernel.c, running make to produce relocunix, and writing it to the boot partition.
status: draft
---

# Building & Installing a Kernel

Amix has a **monolithic SVR4 kernel with no loadable modules** ✅ — every driver is statically
linked in. To add a driver (or change anything kernel-level), you drop an object file into the
`/usr/sys` tree, register it in the kernel switch tables, **relink** the kernel with `make`, copy
the result to `/stand`, and **write it into the boot partition** with `make bootpart`. Then reboot.

The short version, on a live 2.1 system, is:

```sh
# 1. add your driver .o to its subdir Makefile, edit master.d/kernel.c (see below)
# 2. clean stale objects, then relink
rm -f amiga/config/unix.o master.d/exp unix    # remove stale objects
make                                            # -> relocunix
# 3. install the new kernel and write the boot partition
cp relocunix /stand
make bootpart KERNEL=relocunix
# 4. create the device node and reboot
mknod /dev/<name> c <major> <minor>
shutdown -i6
```

This page is the mechanical build-and-install procedure. For *what* a driver is and the table
schema you edit, read the [driver model overview](driver-model.md) first. For a complete real
patch set used as the running example here, see the
[VA2000 framebuffer case study](case-studies/va2000.md).

## The `/usr/sys` tree

The kernel is **not** shipped as one big source tree you compile from scratch. It ships as
**precompiled object libraries under `/usr/sys`** ✅, and you relink them with your additions.
**Some `.o` files come with source, others are object-only** ✅ — you cannot rebuild the
object-only ones, only link against them.

What *is* in source and meant to be edited:

- **`master.d/kernel.c`** — the kernel configuration file holding the device **switch tables**
  (`cdevsw[]` / `bdevsw[]`), the interrupt tables (`int2_tbl[]`, plus a level-6 table), and the
  boot-time init table (`init_tbl[]` / `io_init[]`). Provided in source ✅. (Ditto paper,
  "Adding a device driver.")
- **per-subdirectory Makefiles** — e.g. `amiga/driver/Makefile`, that link the object files in
  each subtree into the kernel. You add your driver's `.o` to the relevant one. ✅

> **Note:** The exact subdirectory names below come from the modern repos (the VA2000 patch set),
> not the 1990 paper, so treat the *layout* as ✅ for 2.1 systems and the *general procedure* as
> the paper's ✅ spec.

Relevant subtrees seen in the VA2000 patch set (Amix 2.1) ✅:

| Path | Role |
|---|---|
| `master.d/kernel.c` | switch tables + extern decls + init table |
| `amiga/driver/Makefile` | links driver objects (add your `.o` here) |
| `amiga/console/scrdev.c`, `c0.c`, `screen.c` | console / screen-device sources (RTG example) |
| `amiga/config/unix.o` | a generated object — **delete before relinking** (see below) |
| `master.d/exp` | a generated symbol/export file — **delete before relinking** |
| `unix` | the previous link output — **delete before relinking** |
| `/stand` | where the bootable kernel image is staged |

## Step 1 — add your driver object to a subdir Makefile

Compile your driver natively (a single-file char driver builds with the SVR4 `cc`, e.g.
`cc va2000.c` ✅ for the VA2000), then add the resulting `.o` to the Makefile in the subtree it
lives in. For the VA2000 the install script patches `amiga/driver/Makefile` to add `va2000.o` ✅.

Keep the driver source in the tree too, so the object can be rebuilt later — the paper recommends
placing **the driver `.o` and ideally its source** in a subdir under `/usr/sys` and adding it to
that directory's makefile ✅.

STREAMS drivers like Hydra build natively too — `make` in the driver dir, then `make force` to
relink (`elf2brel` converts the kernel to boot format as part of that); see the
[Hydra network-driver case study](case-studies/hydra.md) and
[writing a STREAMS driver](writing-a-streams-driver.md). The rest of this page covers the
**native** path.

## Step 2 — edit `master.d/kernel.c` (the switch tables)

Register the driver in the table(s) it belongs to. The switch tables are **indexed by major
number** ✅ — the slot you put your entry points in *is* the device's major number.

What you typically add, in order (the VA2000 patch does exactly this) ✅:

1. **`extern` declarations** for your entry points, near the top.
2. A **`cdevsw[]` slot** (character driver) — for the VA2000, **slot 68** ✅ — wiring
   `open/close/read/write/ioctl/mmap/poll`, with `nodev`/`notty`/`nostr`/`nullflag` for the
   entry points you don't implement.
3. A **`bdevsw[]` slot** instead, if it's a block driver (core entry `strategy()`).
4. An **interrupt-table** entry in `int2_tbl[]` if the device raises a level-2 autovector
   interrupt (e.g. alongside `parintr`, `a2090intr`, `a2091intr`) ✅.
5. An **init-table** entry in `init_tbl[]` / `io_init[]` if the driver needs one-shot boot-time
   init — for the VA2000, `va2000init` is added to `io_init[]` ✅.

> **Warning (ordering):** the `extern` declarations **must precede `io_init[]`** in `kernel.c`, or
> the build fails ✅ (VA2000 gotcha).

> **Warning (pre-POSIX shell):** if you script these edits, remember Amix `/bin/sh` is
> **pre-POSIX** — **no `$(...)` command substitution and no `grep -q`** ✅. Use backticks and
> redirect to `/dev/null` instead. This bites anyone porting a modern install script.

See the [driver model overview](driver-model.md) for the full `cdevsw`/`bdevsw` struct layout and
the meaning of `nodev`/`notty`/`nostr`/`nullflag`.

## Step 3 — clean stale objects, then `make`

Always remove the generated artifacts of the previous link before relinking, or you can link a
stale kernel ✅:

```sh
rm -f amiga/config/unix.o master.d/exp unix
```

Then relink:

```sh
make
```

A successful `make` produces the bootable kernel image. **The name has changed across versions** 🟡:

- The **1990 Ditto paper calls the kernel image `rdbunix`** ✅.
- **Modern 2.1 systems and the repos call it `relocunix`** ✅ — a historical rename.

So on a 2.1 system you are producing `relocunix`. (The repos run `make install` and treat the
output as `relocunix`; the VA2000 script does `make install` → `relocunix` ✅.) If you are on an
earlier release, verify which name your tree emits 🟡 — see the
[open question on the kernel-image name](#known-pitfalls).

## Step 4 — install the kernel and write the boot partition

The kernel that actually boots lives in the **boot/bootstrap partition** (a ~2 MB partition the
installer creates, `BOOTSIZE=2` MB ✅), not just on the filesystem. Two steps:

```sh
cp relocunix /stand
make bootpart KERNEL=relocunix
```

- `cp relocunix /stand` stages the new image where the boot tooling expects it ✅.
- `make bootpart KERNEL=relocunix` **writes the kernel into the boot partition** so the
  Superkickstart bootstrap can load it on next power-on ✅.

This matches the install-time flow: the installer builds/patches the kernel, then runs
`make bootpart KERNEL=relocunix` to write the boot partition ✅ (reconstructed from the root.adf
install scripts). For how the bootstrap then finds and decompresses that kernel, see the
[boot process](../how-it-works/boot-process.md).

> **Always keep the old `/unix` as a fallback** ✅. The paper's procedure explicitly says to
> retain the previous kernel so you can boot it if your new one panics. Don't overwrite your only
> known-good kernel. (Note the distinction: `/unix` is the on-disk kernel file; the *bootable*
> copy is what `make bootpart` writes — preserve a working one of each.)

## Step 5 — create the device node

A driver does nothing until there's a `/dev` node with the matching major/minor. The kernel keys
only on the **numbers**, not the name ✅:

```sh
mknod /dev/<name> c <major> <minor>     # character device
mknod /dev/<name> b <major> <minor>     # block device
```

Concrete, from the VA2000 patch set ✅:

```sh
mknod /dev/va2000 c 68 0
```

`c` = character, `b` = block; the major must equal the `cdevsw[]`/`bdevsw[]` slot you edited in
Step 2. (Reference major numbers: the SCSI hard-disk block driver is **major 18**, the parallel
port char driver is **major 21**, the floppy block driver is **major 16** ✅; see the
[device list](../reference/device-list.md).)

## Step 6 — reboot

```sh
shutdown -i6
```

`shutdown -i6` brings the system to run level 6 (reboot) ✅. On the way back up the Superkickstart
ROM loads the kernel you wrote into the boot partition. If it panics, reboot and select your
retained fallback kernel.

## Worked example — the VA2000 6-file patch set ✅

The [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix) char framebuffer driver is the
cleanest concrete instance of everything above. Its install script patches **six kernel files** and
then runs the build/install/reboot sequence:

| # | File patched | Change |
|---|---|---|
| 1 | `amiga/driver/Makefile` | add `va2000.o` |
| 2 | `amiga/console/scrdev.c` | RTG screen type |
| 3 | `amiga/console/c0.c` | RTG screen type |
| 4 | `amiga/console/screen.c` | RTG screen type |
| 5 | `master.d/kernel.c` | `extern` decls + `cdevsw[]` slot **68** + `va2000init` in `io_init[]` |
| 6 | *(node, not a file)* | `mknod /dev/va2000 c 68 0` |

Then, end to end ✅:

```sh
# (build the driver object first)
cc va2000.c

# clean + relink
rm -f amiga/config/unix.o master.d/exp unix
make install                       # -> relocunix

# create the device node
mknod /dev/va2000 c 68 0

# write the boot partition and reboot
cp relocunix /stand
make bootpart KERNEL=relocunix
shutdown -i6
```

The driver itself uses `autocon()` for Zorro II board discovery, `uiomove()`, and
`copyin()/copyout()` ✅. The full annotated walk-through is in the
[VA2000 case study](case-studies/va2000.md); for adding the same kind of driver to an *install
floppy* instead of a live disk, see
[adding drivers to a boot disk](../boot-disks/adding-drivers-to-boot-disk.md).

## Known pitfalls

- **Stale objects.** Forgetting `rm -f amiga/config/unix.o master.d/exp unix` can relink an old
  kernel ✅.
- **`extern` ordering.** Declarations must come before `io_init[]` in `kernel.c` ✅.
- **Pre-POSIX `/bin/sh`.** No `$(...)`, no `grep -q` in build/install scripts ✅.
- **Kernel-image name.** `rdbunix` (1990 paper) vs `relocunix` (2.1 / repos) — a historical
  rename; verify which your tree emits 🟡.
- **No fallback.** If you overwrite your only working kernel and the new one panics, you have to
  reinstall. Keep the old `/unix` ✅.
- **Object-only files.** You can't rebuild the object-only `.o`s in `/usr/sys`; you can only link
  against them ✅. Anything that needs *their* source can't be changed by the community.
- **Boot-partition vs filesystem.** A kernel sitting on the filesystem is not enough; it must be
  written into the boot partition with `make bootpart` to actually boot ✅.

## The "D245 boot-breaker" — an intermittent `ld` corruption

This is a **load-bearing gotcha for anyone relinking the Amix kernel**, not just A4091 work. It was
first-party reproduced locally on Amix 2.1c under Amiberry. If you ever see a kernel Guru at boot
with `D245 4C41`, this section is the answer.

### What it is *not* (a corrected misconception) 🔴

🔴 Kernels that grew past a certain size Guru'd at boot with `D245 4C41`, and the cause was twice
mis-attributed: first to the SCSI driver's **completion poll loop**, then to the **bootstrap
relocator** misbehaving. **Both were wrong.** The constant `0xD2454C41` decodes as
`"RELA" | AT_DeadEnd` — it is the **bootstrap relocator's own `Alert()`** in `amiga/boot/rel.c`,
fired when `rel()` is handed a **corrupt kernel image** to relocate. So `D245` is a *symptom of a
bad kernel binary*, not a bug in the relocator or in any driver. ✅

The longword breaks down as: `0x52454C41` = ASCII `"RELA"`; setting bit 31 (`AT_DeadEnd`, the
"unrecoverable" flag exec ORs into a deadly alert) yields `0xD2454C41`, displayed as `D245 4C41` in
the Guru requester. ✅

### What it actually is — an emulator MMU defect, **not** `ld` ✅ (root-caused 2026-07-26)

🔴 **Superseded attribution.** This page previously said the corruption was introduced "when `ld`
writes the linked kernel to disk". That was wrong, and so was every variant of it: **`ld` is
innocent** and computes correct output every time. The corruption is injected by the *emulator*,
inside the guest kernel's copy loop, while the guest is demand-paging.

✅ **The mechanism.** On the 68030, a bus-fault format-`$B` stack frame packs two unrelated fields
into the 16-bit word at frame offset `0x34`: `mmu030_state[2]` in the low byte and the write-back
status `wb3_status` in the high byte. The emulator's `RTE` extracted `wb3_status` correctly but
restored the **whole word** into `mmu030_state[2]`. When the `RTE`'s own retry access faulted
again — routine under heavy paging, rare otherwise — the next frame was built carrying the
**stale** `wb3_status`, so an `(An)+` post-increment side effect that had already been undone was
undone a **second** time: a silent 4-byte rewind of an address register, mid-copy, with no
exception raised.

Every observed event landed at one guest PC: the Amix kernel's `MOVES.L (A0)+` **copyin** loop. So
what actually happened is that the *kernel's copy of `ld`'s `write()` buffer* was rewound — which
is why the damage looks like a linker bug, why `cp`/`dd`/FTP of the same bytes are always clean
(no paging pressure, no faults), and why real hardware never shows it.

✅ **What the damage looks like** (this supersedes the "~8 KB block shifted by 8 bytes" description,
which was one small-delta member of a wider family): every damaged region is a **byte-exact
displaced copy of content from earlier in the same file**. Per-region displacements measured
12–9012 bytes, always a multiple of 4, **never** a multiple of the guest page size (2048 B), and
constant across page boundaries — which is precisely what excludes every page-granular explanation
(lost dirty page, wrong swap slot, stale frame, recycled buffer). Damage begins at file offset
≡ `0x19f`–`0x1a4` (mod 2048) and ends on an 8192 boundary.

✅ **The rate is configuration-dependent, and quoting one number is a mistake.** At `a3000mem_size=8`
it reproduces at **85%** of relinks; on the standing **16 MB** bench config the same measurement
pooled **0/354** (95% upper bound 0.84%). Measurement itself suppresses it: adding I/O around each
link drove the observed rate 85% → 45% → 35% → 28%. Always state the capture mode with the rate.

✅ **Fixed.** Masking the restore to the field's real 8-bit width (both `RTE` variants) takes the
8 MB corruption rate from 55–59% on matched controls to **0/39**, with the fault/paging traffic
unchanged — i.e. it removes the damage, not the workload. The defect was present in upstream WinUAE
as well as Amiberry; it was reported upstream and the maintainer's own fix (masking the local
immediately after the two halves are separated) compiles to byte-identical code and measured
**40/40 clean**.

✅ **What was ruled out along the way**, each by measurement rather than argument: the emulator's
disk stack (every guest write replayed byte-exactly and every logged read returned disk truth, at
both 8 and 16 MB), `ld`'s inputs (byte-identical between a clean and a corrupt round), and the
MMU's own fault-resume machinery and descriptor `M`-bit handling.

### The fix — build until the checksum is stable ✅

✅ A clean `ld` output is **byte-deterministic**; each corruption is **random and unique**.
Therefore **a checksum (`sum -r`) that *recurs* is the deterministic clean kernel.**
[`tools/build-clean-kernel.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-clean-kernel.sh)
(runs **on** the Amix box) relinks (link-only, no install) until a `sum -r` value repeats, then
confirms with [`tools/checkunix.c`](https://github.com/Jusii/grimoire-amix/blob/master/tools/checkunix.c),
leaving a verified-clean `relocunix`:

```sh
sh /root/build-clean-kernel.sh    # exit 0 = clean relocunix ready; 1 = could not stabilize in 25 builds
```

> **Never `make install` an unverified kernel.** A corrupt kernel written to the boot partition will
> brick the boot disk (see the safety rule on the [boot process](../how-it-works/boot-process.md)
> page). Always clean-gate first, and install onto a backup/throwaway disk. ✅

Two complementary detectors exist:

| Detector | What it checks | Trade-off |
|---|---|---|
| [`tools/checkunix.c`](https://github.com/Jusii/grimoire-amix/blob/master/tools/checkunix.c) | native big-endian `.symtab` integrity (flags out-of-range `st_shndx`) | **fast**, runs on the box, but **symtab-only** — misses `.rela`/`.text` shifts ✅ |
| [`tools/relsim.py`](https://github.com/Jusii/grimoire-amix/blob/master/tools/relsim.py) | host-side reimplementation of the boot relocator `rel()` | checks `.symtab` **and** relocation records — a **kernel-record** oracle ✅ |

**Scope correction (2026-07-16) ✅:** `relsim.py` (and the native `reltest`) validate the boot
relocator's *source semantics against the kernel's records* — they are **kernel-record oracles,
NOT will-this-disk-boot oracles**. The on-disk `boot2` loader is a free variable outside their
scope: a relsim-green kernel still D245s under a name-based boot2 (see [the two boot2
lineages](../how-it-works/boot-process.md#the-two-boot2-lineages-and-the-d245rela-trap)).
Disk-level assurance needs a **boot-chain check**: the build pipeline laminates the proven
flags-based boot2 into `/stand/boot2.boot` before the bootpart rebuild and fail-closes on
`bootchain-verify.py` (RDB walk → `UNI\0` slice → `boot1@+0x000`, `IBLK@+0x400`,
`boot2@+0x600` sha check, `IBLK@+0x2600`, kernel ELF@`+0x2800`; `ib_chksum` = folded 16-bit
SVR4 sum). The first golden gated this way validated 5/5 on the real A4000+Z3660 (2026-07-15) ✅.

**Measured rate (2026-07-20) ✅:** a fixed-N measurement on a RAW (non-VHD) disk image put the
emulated relink-corruption rate at **85% (17/20 rounds)** — confirming the historical ~70%
figure and refuting the hypothesis that dynamic-VHD block-remapping explained it. Every
linked-but-corrupt round kept `nm -h -u` **empty**: the ~8 KB block-shift never perturbs the
symbol table, so **sum-recurrence is the load-bearing arm** of the gate for SCSI/combined
kernels (the nm-empty arm covers the larger cdfs kernel's distinct silent-symbol-drop mode).
One round in 20 was the separate intermittent `ld` "Unresolved Symbol" nolink mode, which the
gate's retry already handles ✅. (That 85% is the **8 MB** figure; see the configuration
dependence above.)

**Oracle coverage, scored against 21 real captured corruptions (2026-07-25) ✅.** This is the
number that matters when choosing a gate, and it is uncomfortable:

| Oracle | Caught |
|---|---|
| `nm -h -u` (undefined symbols) | **0 / 21** |
| `checkunix` (symtab `st_shndx`) | 7 / 21 |
| `relsim` / relocation-record analysis | 15 / 21 |
| **byte-diff against a known-good link** | **21 / 21** |

**A symbolic two-arm bar (`nm` + `checkunix`) passes 14 of those 21** — it would have declared
two-thirds of them STABLE. Adding a relocation-record arm takes that to **6**. It does not take it
to zero, because a pure `.text`-content displacement is invisible to every symbolic check.
**Byte-diff against a reference link is the only complete oracle** (and where a gate can use it,
`sum -r` recurrence also scores 21/21 — every corrupt link had a unique checksum — which is why
that arm stays load-bearing on the kernels where it converges). Read a green symbolic gate as "not
corrupt in any way visible from here", never as "byte-correct".

Note also that `relsim`-class tools must **fail closed**: a kernel whose section-header table is
damaged (the dominant shape — the table is the last ~400 bytes of `relocunix` and gets overwritten
wholesale) can crash the analyser rather than being reported as corrupt.

### Who is exposed to a cross-toolchain bug — the build-model boundary ✅

When the cross toolchain's **tdivs divide-with-remainder mis-assembly** was found (see
[toolchain](toolchain.md#the-assembler-fixup-family-swbeg-fcmp--and-the-tdivs-divide-with-remainder-bug)),
the blast radius was bounded by the build model, and the boundary is worth recording ✅:

- The **kernel objects and all native drivers never carried the bug** — the harness is a
  source-push + compile-on-box model; the box's own SGS `as` assembles them.
- Only **host cross-built artifacts** were exposed: the SVR4 pkg engine, the cross `libgcc.a`
  that a cdfs-carrying kernel links for its 64-bit soft-arithmetic
  (`__udivdi3`/`__umoddi3`/`__lshrdi3`), and the cdfs kernel `exp` relocatable.
- A plain SCSI / SCSI+net kernel links **zero** cross artifacts and was end-to-end clean.

The practical consequence closed a long-open metal mystery: the kernel's `__udivdi3` returning
an internal normalization intermediate on real hardware (garbage `st_blocks` from cdfs) was the
mis-assembled 64-bit-dividend form inside the old cross `libgcc.a`. After the toolchain fix and
a libgcc/exp rebuild + kernel relink, the same machine + same disc read every value correctly,
and a userland exerciser statically carrying the rebuilt `__udivdi3` passed on metal with the
exact dividends that used to fail (2026-07-21) ✅. Standing style rule stays: prefer shifts to
64-bit division in Amix kernel code — now as a speed/robustness preference, not a correctness
workaround ✅.

Build `checkunix` natively (`cc -O -o checkunix checkunix.c`) and run it on the box; run `relsim.py`
on the host against a **pulled** kernel ELF:

```sh
# on the host, against a kernel pulled off the box:
python3 tools/relsim.py relocunix
```

### Build-system corollary — `make` does not reliably recompile a changed `.c` ✅

✅ Plain `cd /usr/sys; make` does **not** reliably pick up an edited source file: the per-subsystem
`exp` prelink chain has **incomplete dependencies**, so a changed `.c` (or a changed `/stand/CONFIG`)
is silently ignored. After editing, for example, `amiga/kernel/support.c`, you must `rm` the stale
`.o` **and** the subsystem `exp` **and** `amiga/exp` before `make`:

```sh
cd /usr/sys
rm amiga/kernel/support.o amiga/kernel/exp amiga/exp     # stale .o + subsystem exp + top-level exp
make
```

Then **confirm the change took effect by the kernel `sum` changing** — if `sum -r relocunix` is
unchanged, your edit was not compiled in. ✅

Two more SVR4-box gotchas that bite build scripts ✅:

- **`/tmp` is wiped on reboot** — keep build scripts and saved checksums in `/root`, not `/tmp`.
- **SVR4 `grep` has no `\|` alternation** — use separate `grep` invocations instead of one
  alternation pattern. (This is in addition to the pre-POSIX `/bin/sh` limits noted above.)

## Building an a4091 (or a4091 + cdfs) kernel — two required kernel patches

Building a working **a4091** kernel — and, above all, an a4091 **+ cdfs** kernel — needs **two**
`amix-a4091` kernel patches, both under `src/kernel-patches/` ✅:

- **`scsi.c.patch`** enlarges the userspace `/dev/scsi` **GSIO** bounce iobuf to **64 KB** ✅. The
  GSIO path bounces every transfer through this iobuf — which is why userspace `/dev/scsi` reads can
  be multi-sector even though the *in-kernel* SCSI path cannot (see the DMA gotcha below).
- **`a3091.c.patch`** (commit `e70c1d7`; `patch -p0` on `amiga/alien/a3091.c`) adds a high-address
  DMA **bounce** to the A3000 onboard SCSI **super-DMAC** (WD33C93 at `0xDD0000`) ✅. Stock
  `startdma()` set `device->sac = cp->addr` — the caller's 32-bit buffer address — **directly, with
  no bounce**, unlike the A2091-card sibling `a2091.c`, which bounces any buffer ≥ `0x1000000`
  (16 MB) through `AllocMem(cp->tc, MEMF_CHIP)` (copy-out before a write, copy-back after a read,
  freed in `stopdma`). The patch ports that same chip-mem bounce into `a3091.c`.

### The `s5mountroot VOP_OPEN error 6` panic — why a *bigger* kernel stops booting

Without `a3091.c.patch`, adding the in-kernel **cdfs** filesystem (~64 KB of kernel) is by itself
enough to break the boot with ✅:

```
s5mountroot VOP_OPEN error 6
PANIC vfs_mountroot errno 30
```

The trigger is **size/layout, not a cdfs code bug** ✅. Growing the kernel pushes `getrdb()`'s static
RDB buffer (the `union block` in `sdpart.c`) up to a higher address, **past the super-DMAC's reach**;
the boot root-device read then DMAs to an address the super-DMAC can't hit and **returns all-zeros**,
so `sdopen()` fails `ENXIO` → `s5mountroot VOP_OPEN error 6`. Proof it is size-driven: a
section-matched, code-**inert** cdfs stub of the same size panics identically, and the a4091-only
"golden" kernel (same `scsi.c.patch`, no cdfs) boots fine ✅.

**Savestate-diff root cause** ✅: comparing an Amiberry savestate of the *booting* golden kernel
against the *panicking* cdfs kernel, the same RDB buffer held a valid `RDSK`/`PART` block named
`UNIX_Root` in the golden kernel but was **all-zeros** in the cdfs kernel (now at a higher VA —
~`0x078F…` vs ~`0x078E…`), while `queue[0].f` (the registered card's dispatch function) was
**populated in both**. So the card is registered (autoconfig is fine) — the **DMA read itself** is
what fails. With `a3091.c.patch` the a4091 + cdfs kernel boots both **warm and cold** and mounts a CD
byte-exact ✅.

Unlike the **D245 boot-breaker** (a *random* `ld` write corruption, covered above), this failure is
**deterministic and genuinely size-triggered**.

> **Distinct from the error-*5* panic.** This is `VOP_OPEN error 6` (`ENXIO` — a super-DMAC
> high-address DMA failure). The `s5mountroot VOP_OPEN error 5` (`EIO`) seen on an A4091-only machine
> was a *different* fault — the "phantom A3000" device-**dispatch** bug, where the root read went to a
> non-existent internal SCSI — see the [boot process](../how-it-works/boot-process.md) and the
> [`autocon()` phantom-A3000 special case](zorro-autoconfig.md). Don't conflate them.

🔴 **Open:** the exact reach limit of the super-DMAC is uncharacterized. The `≥ 0x1000000` (16 MB)
threshold is `a2091`'s proven-safe cutoff, not a measured `a3091` boundary — and the failing buffer
sat around VA `0x078F0000`, well above 16 MB, so a plain 24-bit-address story is incomplete. Treat the
bounce as a safe over-approximation pending real-hardware measurement.

## Two kernel gotchas that bite any module (found porting cdfs)

Both were hit while porting cdfs, but both are **general** — any kernel module doing the same thing is
exposed ✅.

### Gotcha: the kernel's `bzero` under-clears a region larger than ~1 KB ✅

Zeroing a buffer larger than **~1 KB** with the SVR4 kernel's `bzero` — or with a `memset` that
delegates its `c == 0` case to `bzero` — leaves the **tail uncleared** (stale garbage) on this m68k
build ✅. It bit cdfs **twice** from a single ~1.1 KB struct clear: an uncleared `has_child_link`
clobbered a filesystem node's extent (empty/garbage root), and an uncleared `is_relocated` made the
ISO directory walk skip every child (empty directory). **Fix:** a `memset` that clears with its own
**byte loop** (amix-cdfs `ad09035`). **Any module relying on `bzero`/`memset` to clear a > 1 KB buffer
is exposed** — audit for it. (Working theory: a size/alignment/`int`-truncation bug in `bzero` around
~1 KB.)

### Gotcha: in-kernel SCSI DMA corrupts transfers larger than one 2048-byte block ✅

On this board an **in-kernel** SCSI transfer (`struct sdcom` + `sdqueue()`) of **more than one CD
sector (2048 B)** comes back as **kernel text / garbage** and can **wedge the box**; **single-block
(2048 B) transfers are reliable** (PVD, mount reads, and RDB reads are all single-block and fine) ✅.
cdfs's block-cache read-ahead issued one 16 KB (8-sector) DMA → garbage → empty/garbage directory +
hang; the fix **caps the media transfer to one sector** and lets the chunk loop split multi-sector
requests (amix-cdfs `a5c6915`). This is the **same DMA-limitation family** as the `a3091` super-DMAC
high-address bounce above.

The **userspace** `/dev/scsi` **GSIO** path is *not* affected — it bounces through the 64 KB iobuf
(`scsi.c.patch`) and *does* do multi-sector reads; this limit is specific to the in-kernel `sdqueue`
path ✅. 🔴 **Open:** the real HBA/DMA limit is uncharacterized, so the one-sector cap can't yet be
raised.

> The concrete in-kernel cdfs fixes for both gotchas above live in the **amix-cdfs** repo — the
> byte-loop `memset` (`ad09035`) and the one-sector DMA cap (`a5c6915`).

### `make install` does not update `/stand/unix` — copy it yourself ✅

A successful `cd /usr/sys; make install` prints `installed. Old kernel kept as /stand/OLDunix` but
was observed to leave **`/stand/unix` still holding the *previous* kernel** ✅ — confirmed by
`sum -r`: `/usr/sys/relocunix` was the freshly-built image (checksum 44416) while `/stand/unix` was
still the old one (38553). Because the Amiga bootstrap boots the **boot-partition image written from
`/stand/unix`**, rebooting at that point silently re-boots the **old** kernel and any "verified on the
new kernel" result is worthless. Do the copy explicitly and rebuild the bootpart, then re-check:

```sh
cp /usr/sys/relocunix /stand/unix
cd /stand; make            # (or: cd /usr/sys; make bootpart KERNEL=relocunix)
sum -r /stand/unix         # must now match sum -r /usr/sys/relocunix
```

This is the same hazard the [D245 clean-gate](#the-fix-build-until-the-checksum-is-stable) guards
against, one step later in the pipeline: there `sum -r` proves the *link* is clean; here it proves the
image you're about to boot is the one you just built. ✅

### Verify which kernel actually booted 🟡

Warm reboot (`shutdown -i6`) was intermittently a **no-op** in one bench session — the box stayed
multiuser on the **old** kernel — while **cold boot** (Amiberry down/up, which reloads the boot
partition) was reliable 🟡. Always identity-check *which* kernel actually booted (a version marker, or
`sysfs(GETFSIND, …)`) before trusting a test result.

## See also

- [Driver model overview](driver-model.md) — what `cdevsw`/`bdevsw`, majors/minors, and the
  switch tables are.
- [VA2000 framebuffer case study](case-studies/va2000.md) — the full 6-file patch set in detail.
- [Adding drivers to a boot disk](../boot-disks/adding-drivers-to-boot-disk.md) — same idea, but
  baked into install media.
- [Writing a STREAMS driver](writing-a-streams-driver.md) and the
  [Hydra case study](case-studies/hydra.md) — the native on-box build (`make` / `make force`) for a STREAMS driver.
- [Boot process](../how-it-works/boot-process.md) — how the bootstrap loads the kernel you wrote.

## Sources

- amix-kerntools briefs `boot2-d245-trap` (2026-07-16), `e2-relink-corruption-measured` + `tdivs-cross-assembler-miscompile` (2026-07-21): relsim scope correction, bootchain-verify gate, measured 85% relink corruption, tdivs blast-radius map, __udivdi3 metal closure (kernel 10842→00961, validate-metal ALL GREEN 2026-07-21).
- Ditto, *Writing Amix Device Drivers*, **1990 European Amiga Developer's Conference** (project PDF;
  see [bibliography](../reference/bibliography.md)) — `/usr/sys` object libraries, `kernel.c`
  switch tables, the "Adding a device driver" procedure, `rdbunix` image name, keep-old-`/unix`
  rule.
- [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix) README/install script — the
  6-file patch set, `mknod /dev/va2000 c 68 0`, `rm -f amiga/config/unix.o master.d/exp unix`,
  `make install` → `relocunix`, `cp relocunix /stand`, `make bootpart KERNEL=relocunix`, the
  `extern`-before-`io_init[]` and pre-POSIX `/bin/sh` gotchas.
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — install-time
  `make bootpart KERNEL=relocunix`, `BOOTSIZE=2` MB boot partition, `shutdown -i6`.
- Master research brief §3 (boot process / kernel install flow), §4 (kernel architecture),
  §5 (driver model / "Adding a driver"), §6 (VA2000 patch set), §13 (open questions:
  `rdbunix`/`relocunix` rename).
- The A4091-on-Amix project — `NOTES.md` §17–§18 (the `D245` boot-breaker: relocator `Alert()`
  mechanism, the intermittent ~70% `ld`-write corruption, the build-until-stable gate; reproduced
  locally ✅) and the handoff brief §5/§10, plus `src/`/`tools/`.
- [`tools/build-clean-kernel.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/build-clean-kernel.sh)
  — the relink-until-`sum -r`-recurs clean-gate that dodges the `D245` corruption.
- [`tools/checkunix.c`](https://github.com/Jusii/grimoire-amix/blob/master/tools/checkunix.c)
  — native big-endian `.symtab` integrity detector (`0x52454C41 | AT_DeadEnd` == `D245`; build with
  `cc -O -o checkunix checkunix.c`).
- [`tools/relsim.py`](https://github.com/Jusii/grimoire-amix/blob/master/tools/relsim.py)
  — host-side reimplementation of the boot relocator `rel()`; the full offline `D245` oracle
  (symtab **and** relocation records).
- a4091.device open-source project: <https://github.com/A4091/a4091-software> (A4091 ROM + SCRIPTS
  assembler), referenced by the A4091-on-Amix work.
- amix-a4091 kernel patches `src/kernel-patches/scsi.c.patch` (userspace `/dev/scsi` GSIO bounce iobuf
  → 64 KB) and `src/kernel-patches/a3091.c.patch` (commit `e70c1d7`) — the A3000 super-DMAC
  high-address chip-mem DMA bounce for buffers ≥ `0x1000000`, ported from the `a2091.c` sibling;
  evidence = source + Amiberry-savestate differential.
- The `s5mountroot VOP_OPEN error 6` / `PANIC vfs_mountroot errno 30` boot panic and its size/layout
  root cause — cdfs (~64 KB) grows the kernel, pushing `getrdb()`'s `union block` RDB buffer
  (`sdpart.c`) past the super-DMAC's reach; savestate diff shows a valid `UNIX_Root` `RDSK`/`PART`
  block in the booting golden kernel vs all-zeros in the panicking cdfs kernel, with `queue[0].f`
  populated in both (amix-a4091 CD-ROM-effort handoff, 2026-07-10).
- amix-cdfs `ad09035` — byte-loop `memset` replacing the SVR4 kernel `bzero` that under-clears a
  > ~1 KB region (tail left as garbage); it bit cdfs twice from one ~1.1 KB struct clear
  (`has_child_link`, `is_relocated`).
- amix-cdfs `a5c6915` — caps the in-kernel SCSI (`struct sdcom` + `sdqueue()`) media transfer to one
  2048-byte sector; a multi-sector in-kernel DMA returns kernel text / wedges the box, while the
  userspace `/dev/scsi` GSIO path (64 KB iobuf) is unaffected (Amix kernel-RE + gotchas handoff,
  CD-ROM effort, 2026-07-10).
- Bench caveat (2026-07-10): warm reboot (`shutdown -i6`) was intermittently a no-op (box stayed on
  the old kernel); cold boot reloads the boot partition reliably — always identity-check which kernel
  actually booted.
- The **amix-kerntools** bench forensics @ `8a76775` — `cd /usr/sys; make install` prints "installed"
  yet leaves `/stand/unix` holding the previous kernel (proven by `sum -r`: `relocunix` 44416 vs
  `/stand/unix` 38553); copy `relocunix` to `/stand/unix` explicitly and rebuild the bootpart, then
  re-check `sum -r /stand/unix`. Real A4000 + Z3660, 2026-07-12 ✅. Same brief also confirms SVR4
  `grep` has no `\|` alternation (already noted above under build-script gotchas).
