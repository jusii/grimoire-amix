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

### What it actually is — `ld`'s write path corrupts the output ~70% of the time ✅

✅ The real fault is an **intermittent corruption introduced when `ld` writes the linked kernel to
disk**. About **70% of `make` runs** shift **one ~8 KB block of the output by 8 bytes**, at a
random offset. If that shift lands in `.symtab` or `.rela.*`, the boot relocator chokes → `D245`:

| Where the 8-byte shift lands | Effect at boot |
|---|---|
| `.symtab` | a reloc-referenced symbol gets a garbage `st_shndx` → `symvaddr` COMPLAIN → **D245** ✅ |
| `.rela.*` | garbage relocation type/offset → `relocsection` COMPLAIN → **D245** ✅ |
| `.text` / `.data` | wrong code/data, **no D245** — boots but is subtly broken / may wild-branch ✅ |

✅ It is **code-independent**. The same source relinked 10× gave **3 byte-identical clean** builds
(all `sum -r` = the same value) and **7 corrupt** builds, each with a *different* `sum`. Copying the
*same* file with `cp`, `dd`, or FTP is **always clean**, which localises the corruption to `ld`'s
own write path (emulated-disk or SVR4 `ld` buffer interaction).

🟡 The **root layer is unconfirmed** — whether it originates in the emulated disk write, the SVR4
`ld` buffering, or their interaction is not yet pinned down, and this has not been observed on real
hardware. Keep it 🟡: it is reproduced in emulation but the underlying mechanism is inferred.

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
| [`tools/relsim.py`](https://github.com/Jusii/grimoire-amix/blob/master/tools/relsim.py) | host-side reimplementation of the boot relocator `rel()` | **full offline `D245` oracle** — checks `.symtab` **and** relocation records ✅ |

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
