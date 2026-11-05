---
title: Toolchain & Packaging
summary: Native on-box cc/GCC builds plus two Linux-hosted cross-toolchains — gcc-cross-amix (binutils 2.8.1 + GCC 2.7.2.3, m68k-cbm-sysv4) for kernel space and gcc14-cross-amix (GCC 14.2, m68k-elf with AMIX's return convention and -malign-int) for userland — the sysroot, elf2brel, the libc porting surface, and SVR4 packaging (pkgmk/pkgtrans/pkgadd, AmixBP).
status: draft
---

# Toolchain & Packaging

Amix builds software two ways. **On the box**: the bundled AT&T SVR4 `cc` (the kernel's reference compiler) or the stock Commodore-patched **GNU GCC 1.40.5** at `/usr/public/bin/gcc` ✅, with GNU `make` and GAS, then relink `/unix` ✅ (a native **GCC 2.7.2.3** exists on some community boxes, but the "installable pkg from amigaunix.com" attribution is unsourced 🔴 — see [the compiler table](#native-compilers-on-the-box)) — this is how the existing drivers ([Hydra](case-studies/hydra.md), [VA2000](case-studies/va2000.md)) are built. **On Linux**: as of 2026-06 a public, reproducible *cross*-toolchain exists — [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix), a GCC 2.7.2.3 retargeted to `m68k-cbm-sysv4` — that compiles Amix userland binaries and kernel/driver objects on a modern host (you supply your own licensed Amix sysroot) ✅. Finished software is shipped as SVR4 packages built with `pkgproto`/`pkgmk`/`pkgtrans` and installed with `pkgadd` ✅; the large community bundle is **AmixBP**, with a `zoo`+`cpio` fallback ✅.

Two important caveats colour everything below. The Amix `/bin/sh` is **pre-POSIX**, which breaks many modern build scripts ✅. And the cross-toolchain still needs a **user-supplied licensed Amix sysroot** (the toolchain repo ships no Amix headers/libs/startup objects; until 2026-09-23 this project treated them as not redistributable — see [`AGENTS.md` §5](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md#5-respect-the-licensing-boundary) for the outcome that lifted that), and its **C++/`g++` support is not finished yet** 🟡 — C is fully working.

**Two cross compilers, two jobs (2026-10).** The amigaux project builds **kernel space** — kernels,
drivers, boot loaders, [loadable modules](loadable-modules.md) — only with GCC 2.7.2.3
(gcc-cross-amix), because that code must be object-compatible with what Amix itself was built with ✅,
and builds **userland** — packages, tools, C++ programs — with GCC 14 ([gcc14-cross-amix](#the-userland-compiler-gcc14-cross-amix-gcc-14)) ✅.
The `amigaux/amix` monorepo pins both by commit in `toolchain/` and builds them reproducibly in a
container ✅.

This page is the toolchain companion to [building and relinking the kernel](kernel-build.md) and to [writing a STREAMS driver](writing-a-streams-driver.md) (the worked native build example). For the underlying driver model see [the Amix device-driver model](driver-model.md).

## Native compilers on the box

Amix ships with a working C development environment ✅. The reference compiler is the **AT&T SVR4 `cc`**, used for the kernel itself and for simple drivers ✅. A copy of **GCC** is also bundled ✅.

| Tool | Version / location | Notes | Tag |
|---|---|---|---|
| AT&T SVR4 `cc` | system default | Reference compiler for kernel + simple drivers | ✅ |
| Bundled GCC (stock) | **`GNU GCC version 1.40.5 (68k, SGS/AT&T syntax)`**, Commodore-patched, at **`/usr/public/bin/gcc`** — what `gcc --version` prints on a stock 2.1 box, and the `CC = gcc` of `/usr/sys/Makefile` (measured 2026-09-15) | Old; the only compiler with `-fpcrel` (needed for `boot2`); rejects gcc-2 flags such as `-fno-builtin`. (Earlier versions of this page, following community notes, called it `gcc 1.4.2`.) | ✅ |
| Community GCC | **2.7.2.3** (native Amix build) | The compiler the Hydra and X11 community repos say they build with, on-box; select via `CC`. **Where to get it is unsourced** 🔴: the "installable pkg on amigaunix.com" attribution has no source found, and no public source or package for a native 2.7.2.3 build is known | 🔴 |
| GNU `make` | **3.80** | The make used by the driver makefiles | 🟡 |
| GAS (GNU assembler) | bundled | Assembler backing GCC | 🟡 |
| `perl` | **5.005_4** | Available in some installs | 🟡 |

**Prefer the newer compiler.** The `gcc` on `PATH` may be the ancient stock `1.40.5` at `/usr/public/bin/gcc` ✅. When a newer GCC (e.g. 2.7.2.3) is installed, point the build at it explicitly rather than relying on `PATH` order:

```sh
# Override the compiler for a single make invocation
make CC=/usr/local/bin/gcc        # path to the newer GCC you installed
# or, for the AT&T reference compiler used by the kernel:
make CC=cc
```

This `CC=` override is the same lever the driver case studies use — see the [STREAMS driver build](writing-a-streams-driver.md) and the per-makefile detail in [building the kernel](kernel-build.md).

**Debugger status is unconfirmed.** Whether a symbolic debugger (`sdb`, `dbx`, or `adb`) is present and usable on Amix has **not** been verified from a primary source 🔴. Do not assume one is available; plan to debug drivers via panic messages, `printf`-style kernel prints, and a known-good fallback `/unix` (see [kernel build](kernel-build.md)).

## The pre-POSIX /bin/sh caveat

The Amix `/bin/sh` predates POSIX shell syntax ✅. In practice this breaks build scripts and `configure` runs that assume a modern Bourne shell. Two failures show up constantly in the driver work ✅:

- **No `$(...)` command substitution** — use backticks `` `...` `` instead.
- **No `grep -q`** — redirect to `/dev/null` and test `$?` instead.

```sh
# Modern (fails on Amix /bin/sh):
ver=$(uname -r)
if grep -q hya /etc/something; then ...

# Amix-compatible:
ver=`uname -r`
if grep hya /etc/something >/dev/null 2>&1; then ...
```

If a tool insists on a POSIX shell, run it under `ksh` (the default *login* shell on Amix is `ksh`, with `sh`/`csh`/`tcsh` also present) ✅ rather than `/bin/sh`. This is the same gotcha documented for the VA2000 driver's install script in the [VA2000 case study](case-studies/va2000.md).

## Building drivers: native on-box, and the gcc-cross-amix cross-toolchain

There are now **two** working paths. The modern Amix drivers are built **natively on the box**: the [Hydra STREAMS driver](case-studies/hydra.md)'s `Makefile` invokes the on-box compiler (`cc` / `ld -r`) — `make` produces a relocatable object (`exp`), then `cd /usr/sys && make force` relinks the kernel ✅. **And as of 2026-06 there is also a public, reproducible *cross*-toolchain** — [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix) — that builds a Linux-hosted GCC targeting `m68k-cbm-sysv4`, so you can compile Amix userland binaries *and* kernel/driver objects on a modern host (see [Cross-compiling with gcc-cross-amix](#cross-compiling-on-linux-the-gcc-cross-amix-toolchain) below) ✅. That **resolves the long-standing "no public cross-toolchain recipe" gap.** Native is still the simplest path for a one-off driver; the cross-toolchain is the edit-on-a-modern-host option.

### The target triple

Configure the cross GCC for the Amix platform triple ✅:

| Field | Value | Tag |
|---|---|---|
| Canonical triple | **`m68k-cbm-sysv4`** | ✅ |
| What autodetect yields | `m68k-unknown-sysv4` (set `cbm` explicitly) | ✅ |

The `cbm` (Commodore) vendor field matches the kernel platform string `m68k-cbm-sysv4` used throughout Amix ✅. If you let `config.guess`/autodetect pick the vendor it will say `unknown`; override it.

### Kernel-driver build flags

The Hydra `Makefile` compiles with these kernel flags, using the **native** on-box compiler — no cross-compiler override ✅:

```sh
# Native on-box build (the Makefile's own flags).
make        # CFLAGS = -O -D_KERNEL -DSVR40 -DSVR4 ; links 'exp' via ld -r
```

- `-D_KERNEL` selects the in-kernel headers/macros (not the user-space ABI).
- `-DSVR40` / `-DSVR4` select the SVR4 / SVR4.0 code paths.
- `-O` is the optimisation level the repos build at.

The native compiler the community repos target is **GCC 2.7.2.3** (or the AT&T `cc`) ✅; a stock box has only GNU GCC 1.40.5 and `cc`, and the "pkg on amigaunix.com" source for 2.7.2.3 is unsourced 🔴 (see [the compiler table](#native-compilers-on-the-box)).

### ELF → boot format: elf2brel

The compiler emits **ELF** objects (m68k, SVR4) ✅. Amix's kernel boot path does not consume raw ELF directly; the kernel build converts the linked image to the **Amix boot ("brel") format** (`e_type=0xff00`, ET_LOPROC) with the **`elf2brel`** tool that lives in the kernel source tree's **`boot/`** (a.k.a. `stand/`) directory ✅. In the *native* on-box build this conversion runs automatically as part of `make force` (below); for a **cross** build it becomes an explicit step (see the host-side port below):

```text
native cc / GCC 2.7.2.3  →  ELF kernel image
       │
   elf2brel (in boot/)         # ELF → Amix boot ("brel") format
       │
   make force                  # relink + write the bootable kernel
```

```sh
# The Hydra driver's documented native build (source-only; needs a licensed Amix):
cd /usr/sys/amiga/driver/hydra && make     # build the driver object 'exp'
cd /usr/sys && make force                  # relink the kernel (elf2brel runs in the boot step)
```

Note the kernel image name: modern 2.1 systems and the community repos call the relinked kernel **`relocunix`** (the 1990 Ditto paper called the equivalent image `rdbunix` — a historical rename; verify per version 🟡). The boot-partition write step is covered in [building and relinking the kernel](kernel-build.md), and the Hydra specifics in the [Hydra case study](case-studies/hydra.md).

**Host-side `elf2brel` (2026-07-05):** `elf2brel` is a portable ELF filter, so it can also run as a **cross step** — `amix-kerntools/tools/elf2brel.py` is an endian-explicit Python port of `amiga/boot/elf2brel.c` that converts a **cross-built** `ld -r` kernel (from `gcc-cross-amix`) to the brel form on the host, no Amix box needed (it fuses `.text/.rodata/.data/.bss` into one section, folds the `.rela.*` tables into the compact `.rel.boot` table the boot loader consumes, and drops the symtab). This matters for **boot floppies**: framing a *raw* cross-linked ET_REL (`e_type=0x1`) Guru's with `D245 4C41` at relocation — so a cross-built kernel must pass through `elf2brel` (→ `unix.brel`, `e_type=0xff00`) before [`build-bootfloppy.sh`](../boot-disks/adding-drivers-to-boot-disk.md). ✅ (verified live under WinUAE)

### Cross-compiling on Linux: the gcc-cross-amix toolchain ✅

The cross path is now **public and reproducible**: **[`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix)** is a `Makefile` that bootstraps a Linux-hosted toolchain for `m68k-cbm-sysv4` ✅. (This resolves the gap our earlier notes flagged as open 🔴.)

- **Components:** GNU **binutils 2.8.1** + **GCC 2.7.2.3** (the version the community native builds use; the stock box compiler is GCC 1.40.5), downloaded from the GNU archive and built with `-std=gnu89` (the 1990s configure tests and sources predate C99). The installed cross driver is **`m68k-cbm-sysv4-gcc`** — our earlier docs called it `m68k-amix-gcc`, a placeholder; the real binary is the triple-prefixed one ✅.
- **The one thing you must supply: a licensed Amix sysroot.** The repo deliberately ships **no** Amix headers/libraries/startup objects (the licensing boundary). You point it at your own Amix tree — `make all AMIX_ROOT=/path/to/usr-amix` — and its `sysroot` target copies `usr/include`, `usr/lib` (`libc.so.1`, `ld.so.1`), `usr/ccs/lib` (`crt1.o`/`crti.o`/`crtn.o`), and `usr/sys` into the toolchain ✅.
- **Status (2026-06):** the C compiler, GNU `as`, and GNU `ld` all work, and a **dynamically-linked Amix C executable links and runs on real Amix** ✅. **C++ / `g++` is not complete yet** 🟡.

```sh
make all AMIX_ROOT=/path/to/usr-amix      # build binutils+gcc, populate the sysroot, install the wrapper
. build/env.sh
m68k-cbm-sysv4-gcc hello.c -o hello        # -> ELF 32-bit MSB executable, m68k 68020, SYSV, dynamically linked
```

For a **kernel/driver object** (compile on Linux, link natively on the Amiga), the repo's `test-random` target cross-compiles a real Amix driver source to a relocatable object ✅:

```sh
make test-random AMIX_ROOT=/path/to/usr-amix CPUFLAGS=-m68030
#   -> build/test/random.o : ELF 32-bit MSB relocatable M68000  (resembles native AMIX driver objects)
```

The wrapper compiles via `-S` → an `.lcomm` assembly fix-up → `as -m68020`, working around quirks of the old GCC's output ✅. So you can now develop a driver (e.g. the [A4091](a4091-53c710-driver.md) or a new NIC) on a modern host and do only the final relink on Amix — though the native on-box build (above) remains the simplest path for a single driver. This was open gap #1 in §13 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), now closed.

**68060 targets.** GCC 2.7.2.3 has no `-m68060`; compile code for a 68060 with `-m68040` ✅. At
every optimisation level and `-m680x0` flag it emits the 64-bit `mulu.l`/`muls.l` form, which the
68060 does not implement, for every divide or modulo by a constant ✅. The [`jusii/gcc-cross-amix`](https://github.com/jusii/gcc-cross-amix) fork's
wrapper expands that form into 16×16 `mulu.w` sequences by default and installs
`m68k-cbm-sysv4-scan060`, which reports any 68060-unimplemented instruction in objects, archives or
executables (`AMIX_SCAN060=1` runs it on every compile) ✅; neither is in the upstream repo linked
above yet. The 1.0 68060 kernels emulate the 64-bit multiply and divide forms, so on them the
expansion saves slow emulation rather than a killed process 🟡
(the 1.0 release notes, not public).

**Which commit the project builds with.** `amigaux/amix` pins `jusii/gcc-cross-amix` at `8949028`
(`toolchain/gcc-cross-amix.pin`, 2026-10-29), the fork's `main` with the 64-bit multiply expansion and
`scan060` ✅. The fork's wrapper fixes (`-c` without `-o`, `-lNAME` resolved by name so `DT_NEEDED` is
right, `volatile`/`const` kept under `-traditional`, `-d<X>` kept off `ld` plus a read-only sysroot
guard) were merged upstream as [isoriano1968/gcc-cross-amix #7](https://github.com/isoriano1968/gcc-cross-amix/pull/7)
on 2026-10-19 ✅; the 64-bit multiply expansion and `scan060` are still fork-only.

### The sysroot: patch level matters ✅ {#the-sysroot-patch-level-matters}

Both cross compilers need an Amix sysroot (`usr/include`, `usr/lib`, `usr/ccs/lib`, and for kernel work
`usr/sys`). Which Amix it comes from is not neutral, because **patch 2a changes three headers and
`make`** ([the patch floppy](../boot-disks/anatomy-patch-adf.md#what-patch-2a-changes-in-usrinclude-and-usrccs)):
`sys/types.h` and `sys/socket.h` each get a missing comment-close fixed, `patchlevel.h` is new
(`PATCHLEVEL 2a`), and `usr/ccs/bin/make` is replaced ✅. Nothing else under `usr/include` differs ✅.

A sysroot in common use for kernel work turned out to be **mixed**: its `usr/sys` is the installed
2.1c tree (byte-identical to an installed 2.1p2a system, including the files the patch replaces), but
its `usr/include` and `make` are the pre-patch versions ✅; how the mix arose is undocumented 🟡. A
module kit built against a cleanly installed 2.1c `/usr` differed from one built against that mixed
sysroot only in those three headers (measured on both kernel lines, 2026-10-29) ✅. Build against one
installed 2.1c `/usr`, and record which. The project's reference sysroot is the `usr/` tree of the
public [`amigaux/amix-system`](https://github.com/amigaux/amix-system) repository, AMIX 2.1c at patch
level 2a as installed, listed by sha256 in `amigaux/amix` `system/MANIFEST.sha256` ✅.

### The assembler-fixup family: .swbeg, fcmp — and the tdivs divide-with-remainder bug ✅

The wrapper's `fix_asm` pass exists because GCC 2.7.2.3 emits **SGS-dialect** assembly that GNU
`as` 2.8.1 either drops or, worse, silently mis-encodes. Three members of the family are now
known, and the third was the most consequential ✅:

1. **`.swbeg &N`** — GNU as parses it but emits zero bytes, while gcc's switch dispatch assumes
   the SGS assembler's 4-byte word before each jump table — every switch case entered 4 bytes
   late. Rewritten to an explicit 4-byte filler ✅.
2. **`fcmp`** — FPU compare spelling differences, rewritten ✅.
3. **`tdivs.l`/`tdivu.l <ea>,Dr:Dq`** (discovered 2026-07-20) — gcc's SGS spellings for the
   68020 **32-bit-dividend divide-with-remainder** (`divsl.l`/`divul.l`). GNU as 2.8.1 assembled
   them with the ext-word SIZE bit (0x0400) **set**, producing the *64-bit-dividend* form: the
   remainder register was consumed as the high dividend word. Consequence: **every
   variable-divisor `%` in cross-built code returned garbage at ANY optimization level**, and
   variable `/` was wrong at -O0 (on-box measurements: `351 % 151` → −2147408448;
   `351 / 151` → 351, the 68030 leaving operands unchanged on quotient overflow). Constant and
   power-of-two divisors were never affected (gcc lowers them without tdivs). The fix rewrites
   the spellings to `divsl.l`/`divul.l` (SIZE=0), with a `test-divmod` regression target proven
   FAIL-before/PASS-after ✅. The DImode `libgcc.a` helpers (`__udivdi3` and friends) were all
   affected — every divide in them is compiler-generated — and were rebuilt; the fix was
   **confirmed on the real A4000+Z3660** with a userland exerciser (2026-07-21) ✅. See
   [kernel build](kernel-build.md) for the blast-radius map and
   [package management](../how-it-works/package-management.md) for the crash this solved.

**`fix_asm` runs only when you compile *through* the wrapper — `-S` bypasses every repair** ✅.
`m68k-cbm-sysv4-gcc` is a shell wrapper: it runs the real `gcc.real -S`, post-processes the emitted
SGS-syntax assembly through `fix_asm`, and only then assembles. That post-process happens **only when
the wrapper reaches the assembly stage internally**. If a caller passes **`-S`** to the wrapper, it
is detected and the wrapper `exec`s straight to `gcc.real` with **zero fixups applied** — silently
losing all of the repairs above. The most dangerous one to lose is the **`fcmp` FP-compare
operand-order reversal** (`SGS_CMP_ORDER`): for an FP-register-vs-FP-register comparison this does not
fail to assemble — it assembles to a *different, valid* encoding with the **operands swapped**, so
`a > b` between two doubles silently evaluates as `b > a`, with no diagnostic at any stage ✅. The `fcmp` defect itself is fixed and gated
(`make test-fcmp`), but the **general bypass property remains true of the wrapper as designed**: any
build system that compiles to `.s` and assembles separately, resolves to `gcc.real` directly, or
drives `as` itself inherits none of the wrapper's repairs ✅. This is the same silent-mis-encode
family as the `#`-as-comment scrub and the `tdivs` bug below, and the rule that covers all of them is
the same: **verify the encoding (`objdump -d`), never the exit status** ✅.

### The SGS/SVR4 assembler dialect: `&` is the immediate prefix — and `#` is a comment ✅

The toolchain's GNU `as` (binutils 2.8.1) is configured for the **SVR4/SGS m68k target**, not the
plain-ELF/MIT dialect that `m68k-elf-as` and most modern m68k references speak. Two characters carry
the whole difference ✅:

| | SGS/SVR4 (`m68k-cbm-sysv4` `as`) | plain-ELF (`m68k-elf-as`) |
|---|---|---|
| Immediate prefix | **`&`** | `#` |
| `#` means | **start of a comment** | immediate prefix |

This is the dialect gcc 2.7.2.3's own output speaks (`moveq &0,%d0`, `link.w %fp,&0`) — and why the
wrapper's `.swbeg &N` fixup above is spelled with `&`. It bites when you feed the toolchain
**assembly written for a plain-ELF assembler** (a reference listing, another retro port, a modern
m68k codebase): every `#` immediate starts a comment, the rest of the operand field vanishes before
parsing, and gas rejects the line with ✅

```text
operands mismatch -- statement `movew ' ignored
```

**Note the empty operand field — that is the signature.** The diagnostic never names the cause: the
operands were not wrong, they were *eaten as a comment* before the parser saw them. A wall of
`operands mismatch … ignored` errors with blank operands on imported m68k assembly means exactly
this, and the fix is the **one-character substitution `#` → `&`** on the code field of each affected
line ✅.

**The mechanism, and why the scrub reaches end of line** ✅: `#` is in gas's `line_comment_chars` for
this target (`gas/config/tc-m68k.c`), and the comment scrubber runs **before** the m68k operand
parser — so the operand is not misparsed, it is *gone*, together with everything after it on the
line: a second operand, a trailing comment, all of it.

**The carrier is inline asm in C, not just imported `.s` files** ✅: gcc 2.7.2.3 copies an `__asm__`
template into its output **verbatim**, so Motorola-syntax immediates inside a `.c` file reach the
assembler unchanged and hit the scrub exactly as an imported `.s` file would. A project with no `.s`
files is not exempt.

**And the failure can be silent** ✅ — this is the dangerous half, and the diagnostic above is the
*lucky* outcome. If what survives the scrub is itself a valid instruction, gas assembles **that**,
with no diagnostic of any kind: `nop #junk here` assembles to a bare `nop` (`4e71`), exit 0. What
you wrote is not what ran. This is the same silence class as the `tdivs` mis-encode above — the
toolchain has a *family* of silent mis-encodes, and the rule that covers all of them is: **verify
the encoding (`objdump -d`), never the exit status.**

The rest of the MIT dialect largely assembles unchanged — MIT addressing syntax (`%a0@(8)`),
joined-size mnemonics (`movel`, `moveal`), branch size suffixes (`bras`, `beql`), and the FPU/PMMU
instructions (`fsave`, `fmovemx`, `pmove`, `pflusha`) were probed individually and pass as-is ✅. In
practice the dialect wall is the immediate/comment characters.

**Bit-field operands are the documented exception** ✅ (this narrows an earlier version of this
section, which listed `bfffo` among the pass-as-is constructs — true of the *mnemonic* and the
register operand form, not of the Motorola-immediate operand form):

| Written | Result |
|---|---|
| `bfffo %d3{#0:#32},%d2` | destroyed — comment scrub (`Missing operand` + `operands mismatch`) |
| `{0:32}` — bare literals | assembles correctly |
| `{BOFF:WID}` — bare symbols | `Bad expression` / `parse error` |
| `{&0:&32}` / `{&BOFF:&WID}` | assembles correctly, literals **and** symbols |

`&` is the only universally-correct repair — bare numbers work for literals and fail for symbolic
offsets/widths. As of `gcc-cross-amix` `ef7c86e` the wrapper's `fix_asm` auto-repairs `#` → `&`
**inside bit-field braces** for all eight bit-field mnemonics, gated on the *encoding* by
`make test-bitfield` (offset/width read back out of the extension word). The repair is deliberately
narrow: `#APP`/`#NO_APP` and every other `#` on the line are untouched, so **all other hand-written
immediates remain the author's responsibility** — `moveq #1,%d0` in an `__asm__` block is still
silently eaten. When importing any third-party m68k asm or inline asm: grep the code fields for `#`,
rewrite to `&`, and verify the encoding, not the build's exit status ✅.

### The wrapper's `-c foo.s` with no `-o` silently destroys the source ✅

A destructive trap in the cross **wrapper's** `.s` path (present in the shipped wrapper as of
2026-07 ✅; fixed in the [`jusii/gcc-cross-amix`](https://github.com/jusii/gcc-cross-amix) fork by
`1bfffbd`, 2026-09-15, gated by `make test-objdir`, and merged upstream with
[isoriano1968/gcc-cross-amix #7](https://github.com/isoriano1968/gcc-cross-amix/pull/7) on 2026-10-19 ✅):

```sh
m68k-cbm-sysv4-gcc -c foo.s     # no -o — DO NOT: this destroys foo.s
```

**silently overwrites `foo.s` with a 441-byte empty relocatable object and exits 0** — the source is
gone, there is no diagnostic, and the build looks green ✅. The chain: the wrapper classifies only
`*.c` arguments as sources, so a bare `.s` falls through as an "object" and the wrapper's compile
output name stays empty; it execs the real gcc with a zero-length `-o` argument; gcc 2.7.2.3's `.s`
spec drops that zero-length argument when it builds the `as` command line, so `as` is left holding
`-o foo.s` and **no input file** — it assembles empty stdin and writes the result over your source ✅
(the same 441-byte object falls out of `as -m68020 -o t.s </dev/null` directly). The wrapper's own
refusing-to-overwrite guard compares the input against the (empty) output name, so it never fires.

Where you meet it: **`.s.o` Makefile rules in the old SVR4 idiom — `$(CC) $(CFLAGS) -c $<` with no
`-o`** — under the upstream wrapper or an older install such a rule eats its own source ✅. There
the defence is one line, and an explicit `-o` remains good practice everywhere:

```make
.s.o:
	$(CC) $(CFLAGS) -c $< -o $@
```

With an explicit `-o` the wrapper's `.s` path is correct ✅. `.c` compiles are not exposed — the
wrapper's compile path always names its output ✅. Keep assembly sources under version control
regardless: a trap that exits 0 is only ever caught after the fact.

### The stock shared-libc `getpwnam()` first-call SIGSEGV — and the static-link sidestep ✅

A separate porting hazard lives in the stock **shared `libc.so.1`**, not in the toolchain: the **first `getpwnam()` call** of a process crashes inside libc's passwd-record handling (a record expand routed through the `_libc_malloc` allocator-redirect pointers), while the symmetric group path (`getgrnam`) survives — the asymmetry is entirely inside libc and not debuggable off-box. Interposition was ruled out (libc calls its internal helpers via non-preemptible `bsrl`). The **working sidestep**, used in every binary of the ported pkg toolchain: link them **statically** and let the executable *define* `getpwnam`/`getpwuid`/`getgrnam`/`getgrgid` as small direct `/etc/passwd`/`/etc/group` parsers — an executable's own global symbols win over shared-library exports at static link time, so every internal caller is preempted uniformly. One consequence worth knowing: this only protects code you can relink (it cannot reach the stock **dynamically-linked** daemons — which were never the victims of this particular defect anyway; a daemon crashing at boot is far more likely the [colon-less-`TZ` bug](../how-it-works/quirks.md)).

## The userland compiler: gcc14-cross-amix (GCC 14) ✅ {#the-userland-compiler-gcc14-cross-amix-gcc-14}

[`asokero/gcc14-cross-amix`](https://github.com/asokero/gcc14-cross-amix) (Antti Sokero, MIT) builds
a **GCC 14.2.0 / binutils 2.43.1** cross compiler for Amix, with working C++ (templates, RTTI,
exceptions, a hosted libstdc++), C99 and later, and a compat runtime (`libamixc99`) for the C-library
pieces SVR4.0 predates ✅. It is for **application software only** — its own README rules out the kernel,
device drivers and anything that must be object-compatible with what Amix was built with ✅. Since
2026-10 it is the amigaux project's userland compiler (packages, the package tools, the box tools,
the installer's userland); the package line was switched after a rebuild-and-compare of its packages
on a 68030 and a 68060 (byte-equal behaviour, 42/42 checks) ✅ (first-party record).

### Why `m68k-elf`, and the one ABI difference ✅

GCC dropped every m68k SVR4 target, so the toolchain configures the generic **`m68k-elf`** target and
adds Amix's knowledge in a specs file, one target header and the compat layer ✅. (Debian's
`m68k-linux-gnu` compiler cannot be used: its `libgcc_eh` needs a dynamic loader's
`_dl_find_object` and pthreads; an `elf` target builds the registry unwinder instead ✅.)

Measured against Amix's libc and period-compiler output, the plain m68k ELF ABI is Amix's **except
where a function returns its value** ✅:

| Return | Amix (AT&T `cc`, GCC 2.7.2.3) | plain GCC 14 `m68k-elf` |
|---|---|---|
| pointer | in **`%a0` and `%d0`**; the caller reads `%a0` | `%d0` only |
| struct or union, any size | **in memory**, through the caller's buffer at `%a0` | 1/2/4/8-byte aggregates in `%d0`/`%d1` |
| floating point | `%fp0` (68881) | `%fp0` |

Both mismatches broke real code: a period-compiled program calling a GCC 14 library read a stale
`%a0` (`zlibVersion()` printed garbage, then SIGSEGV), and GCC 14 code calling libc's `div()`/`ldiv()`
read `%d0:%d1` while libc wrote the `div_t` through `%a0` ✅. The fix is `toolchain/amix-abi.h`
(`FUNCTION_VALUE` → `m68k_function_value`, as the m68k Linux and NetBSD targets use, and
`DEFAULT_PCC_STRUCT_RETURN`), upstream commit `78a337a` (2026-10-27); the build refuses a compiler
without it ✅. **Rebuild every GCC 14 archive built before that change** ✅.

### `-malign-int` is ABI, not tuning ✅

Amix's `cc` aligns `int` and pointer members to 4 bytes and rounds a struct to its widest member;
m68k GCC rounds to 2 ✅. The tripwire is stdio: `stdout` is `&__iob[1]`, and `sizeof(FILE)` is **16**
under Amix's compiler but 14 under GCC without `-malign-int`, so a GCC call site addresses
`stdout`/`stderr` 2 and 4 bytes into the wrong `FILE` — `printf` works, `fprintf(stderr, …)` writes
nothing or kills the process ✅. The toolchain's specs add `-malign-int` to every compile ✅.

### What the specs and flags do

- **Link:** `--dynamic-linker /usr/lib/libc.so.1 -Ttext-segment=0x80000000 --hash-style=sysv -z norelro
  --build-id=none` — executables are dynamic, with libc itself as the runtime linker, and Amix's loader
  ignores the extra `PT_GNU_STACK` header ✅.
- **Start files:** `crt1.o crti.o crtbegin.o` plus `amix_init.o`, which walks `.init_array`; the 1991
  `crt1` does not know it, and without it **no C++ static constructor runs, silently** ✅.
- **Libraries:** `-lamixc99 -lc`. `-lc` resolves to `usr/ccs/lib/libc.so`, which is an `ar` archive
  with static members (`data.o` owns `__iob`), not the shared `libc.so.1` ✅. libgcc, libstdc++ and
  libamixc99 are static ✅. Sockets link dynamically by bare name; an X client needs
  `-lX11 -lsocket -lnsl` ✅.
- **CPU of the runtime — which build you have matters.** Upstream `main` (as of `58130fe`,
  2026-10-29) builds libgcc and libstdc++ `--with-cpu=68060`, which keeps them off the 64-bit integer
  forms the 68060 lacks but makes them use the **68040/68060-only FPU forms** (`fsmove`, `fdmove`,
  `fsadd`, …): 491 such instructions in that `libgcc.a` and 123 in `libstdc++.a`, so code that reaches
  them (`__floatundidf`, `unordered_map` rehashing) dies with **SIGSYS on a 68030 with a 68881/68882**
  ✅ (measured on an upstream build, 2026-10-29). **Upstream `main` is therefore not 68881-safe.** The
  amigaux project builds the runtime `--with-cpu=m68020-60` instead (the `m` matters: the 68020 set
  and the 68881 FPU, tuned for the range), which is safe on both; that build is not public yet
  (2026-10-29) ✅. `-m68060` remains available for code that only ever runs on a 68060.
- **`-mno-strict-align`** is upstream's default from `e8b6997` (2026-10-27); the build the amigaux
  packages use predates it and passes the flag explicitly ✅. On a 68LC060 at 80 MHz it measured
  Dhrystone 1.60× the strict build and 1.43× GCC 2.7.2.3 ✅ (first-party record); on a 68040 it needs
  a port kernel that handles misaligned accesses across a page boundary, not yet measured on 68040
  metal 🔴.
- **Predefines:** `-D__amix__ -D__amix -Damix`; implicit *function* declarations stay errors (only
  implicit `int` is relaxed) ✅. Defining `SVR4` as well sends some autoconf code (make's
  `getloadavg`) down a kmem route; the project's package line leaves it out ✅.

### Checking for the 68060: `check-68060-safe.py` ✅

The 68060 dropped the 64-bit `mul`/`div` forms, and libgcc's 64-bit divide compiled for a 68020 uses
them; without an integer-support handler in the kernel, any 64-bit division *by a variable* kills the
process ✅. `tools/check-68060-safe.py` decodes instruction **encodings** (objdump names `divul`/`divull`
backwards) and flags the 64-bit forms; it reads ELF files, archives and listings, and reports a
disassembly that lost sync at a label as untrustworthy rather than clean ✅. The project's build adds a
`--68881` mode that also flags the 040/060-only FPU forms, which upstream's checker does not look for
(as of `58130fe`) ✅ — so a runtime upstream's checker passes can still trap on a 68030 + 68881. `cas2` traps on the 68060 at any alignment; GCC 14 does not emit it ✅.

### Known defects and workarounds

| Defect | Effect | Workaround | Tag |
|---|---|---|---|
| libc's printf family and `ll` | `%lld` prints the high word and puts every later argument 4 bytes out of step; `%llo` the same, so a value under 4 GiB prints as 0 | `libamixc99`'s `snprintf`/`vsnprintf` are correct; **`fprintf` is not replaced** | 🔴 open |
| Vendor 1991 `libX11.a` and siblings | malformed `sh_link` on `.rela` sections; modern `ld` silently drops the relocations and the program jumps to 0 (ld 2.8.1 tolerated it) | run `tools/fix-x-libraries.sh` (repaired copies) before linking X | ✅ |
| Headers without C++ linkage guards; K&R `static` prototypes in `sys/stat.h` and others | C++ cannot include them as shipped | generated wrappers and `make-kandr-fixes.py` | ✅ |
| `gettimeofday` undeclared in `sys/time.h`, `select` in `sys/select.h`; no `FP_*`, `ENOTSUP`, `fsblkcnt_t`, `__cxa_atexit` | build errors | compat headers; `__cxa_atexit` from the compat layer | ✅ |
| `setenv`, `mkstemp` | no provider in libc or `libamixc99` | shim per port | ✅ |
| `long double` I/O (`%Lf`) | mis-steps in libc's `sscanf` and the compat formatter | avoid | 🟡 |
| Hard float | FP code needs a 68881/2 or an 040/060 FPU (an LC part relies on the kernel's FPE); `libamixc99`'s `vsnprintf` saves `%fp2`, so even an integer-only `snprintf` executes an FPU instruction | — | ✅ |

## The porting surface: libc and library gaps modern C assumes ✅

Getting a compiler to emit correct code (above) is only half of porting modern software to Amix; the
other half is that **stock Amix's libc and system libraries are a 1990–1992 SVR4 surface**, and much
of what current C takes for granted is simply absent. These are the measured gaps that most often
block a port — all from direct sysroot inspection (file presence, `md5`, `nm` symbol resolution,
header reads) ✅. They compound with the [implicit-declaration behaviour](#the-implicit-declaration-bomb)
of GCC 2.7.2.3, which turns several of them from a build error into a silent runtime bomb.

### curses = termcap = termlib is one archive, exposing both APIs — link `-lcurses` ✅

In the Amix sysroot, `libcurses.a`, `libtermcap.a` and `libtermlib.a` are **byte-identical** (same
`md5`) and export **both** the terminfo API (`setupterm`, `tigetstr`, `tparm`, `newterm`, …) **and**
the full BSD termcap API (`tgetent`, `tgetnum`, `tgetflag`, `tgetstr`, `tgoto`, `tputs`) from the one
archive — an intentional SVR4 design (`curs_termcap(3CURSES)`), not an accident of the install ✅.
`libcurses` is a **static archive only** (no `libcurses.so`), and **no `*ncurses*` file exists
anywhere in the sysroot** ✅. Practical policy: **link `-lcurses`** and that resolves the
termcap/terminfo/curses dependency for `screen`, `less`, `vim`, a `top`-class monitor, and their
kin at once — **no ncurses port is needed as a prerequisite** for that class of tool. The genuine
gap is ncurses-*only* APIs (wide-char `cchar_t`, mouse support, `use_default_colors`): a tool that
hard-requires those needs ncurses ported first, a separate and harder question ✅.

### No POSIX `regcomp`/`regexec` anywhere on the box ✅

Amix's libc and system libraries provide **no POSIX regular-expression API at all** — no
`regcomp`/`regexec`/`regfree` ✅. What exists instead is the older SVR4 `<regexp.h>` interface
(`compile`/`step`/`advance`) and the separate `libgen` `regcmp`/`regex`. This hard-blocks any tool
whose portability story assumes POSIX regex is always present (e.g. GNU `file`, GNU `nano`) unless it
bundles its own regex engine — which is, independently, the single strongest portability predictor on
this platform ✅.

### `strcasecmp` exists only in the networking libraries, declared in no header ✅

`strcasecmp` is **not in libc** at all — it lives only inside the networking libraries
(`libsocket.a`/`libnsl.a`/`libresolv.a`, varying by measurement pass), and **no header on the system
declares it** ✅. A build that calls it gets an implicit K&R declaration (assumed `int`-returning),
which is harmless *for this particular signature* but is exactly the trap class the next item shows is
**not** always harmless. Treat it as absent and shim it ✅.

### The implicit-declaration bomb: missing `snprintf`/`vsnprintf`/`getpagesize`, silently miscompiled {#the-implicit-declaration-bomb}

None of `snprintf`, `vsnprintf` or `getpagesize` exist in Amix's shared libc (`libc.so.1`), and
`snprintf` is not even **declared** in the sysroot's `stdio.h` ✅ — almost certainly the single most
common blocker for modern C, since `snprintf` is ubiquitous. The danger is not "missing symbol, build
fails": the cross compiler is **GCC 2.7.2.3**, whose K&R semantics treat an undeclared call as
returning `int` and **compile it anyway with no error** — so a call to an absent, non-`int`-returning
function (or one taking a `double`) silently produces **wrong values at runtime** rather than a
link/compile failure ✅. Observed concretely: an undeclared `atof` call read the wrong argument value,
because implicit-declaration rules mishandle parameter passing for a function assumed to return `int`.

> **House rule:** build with `-Wall` and treat **every implicit-declaration warning as a hard
> error** — on this toolchain it is a runtime-corruption warning, not a style nit ✅.

The wider absent surface, corroborated by an independent build-matrix survey, also includes
`setenv`, `mkstemp`, `usleep`, `nanosleep`, `getaddrinfo`, `random`/`srandom`, `daemon`, `getrusage`,
`fnmatch`, `glob`, and header gaps for `stdint.h`/`inttypes.h`/`stdbool.h`/`strings.h`/`wchar.h` and
`ssize_t` ✅. (The same-family stock-libc `getpwnam()` first-call crash and its static-link sidestep
are [above](#the-stock-shared-libc-getpwnam-first-call-sigsegv-and-the-static-link-sidestep).)

### `sigaltstack` is there; `vfork` is not in the shared libc ✅

- **`sigaltstack` exists**: `libc.so.1` exports `sigaltstack` (weak) and `_sigaltstack`, `SYS_sigaltstack`
  is 97, `<signal.h>` declares it and `<sys/signal.h>` has `stack_t` and `SA_ONSTACK`, `SA_RESETHAND`,
  `SA_SIGINFO`, `SA_NODEFER` ✅ (presence read from the sysroot with `nm` and the headers); its runtime
  behaviour has not been exercised 🟡.
- **`vfork` is not in `libc.so.1`.** It exists only as a static member of the `usr/ccs/lib/libc.so`
  archive, so autoconf finds it and a cross `configure` guesses it works ✅. The project's ports pin
  `ac_cv_func_vfork=no` and use `fork`, which is proven on the box ✅. That static `vfork` is a true
  vfork: the child shares the parent's memory ✅, and a child that calls `signal`, `sigset` or
  `sigaction` rewrites the parent's libc handler table, so the parent dies of `SIGBUS` at its next
  delivery of that signal ([quirk 98](../how-it-works/quirks.md#98-vfork-child-signal-table)). In a
  vfork child call only `exec*()` and `_exit()`.
- **Imake turns vfork on for SVR4** ✅: X11R6.3's `Imake.tmpl` gives `HasVFork YES` to every platform
  not declared `SystemV`, and a cf file that defines only `SystemV4` gets `-DHAS_VFORK` (`xinit`,
  `xdmshell`, `xmh`). Say `#define HasVFork NO`. An audit of the amix packages (2026-11-02) found
  make, diffutils and pkgtools mapping `vfork` to `fork`, Dropbear built with `DROPBEAR_VFORK 0`,
  Python's `_posixsubprocess` using vfork only on Linux, and the static `vsyslog` as the one vfork
  left in built binaries.

### More gaps and traps from the 2026-10 ports ✅

- **`putenv()` a writable buffer, never a literal:** the shared libc parses `TZ` in place, so a
  literal (read-only under GCC 14) crashes the next time conversion ([quirk 89](../how-it-works/quirks.md#89-tz-parsed-in-place)).
- **Absent:** `settimeofday` (only `stime`), `dirfd()`, the `S_ISLNK` macro (`S_IFLNK` is defined),
  `mkstemp`, `asprintf`, `statfs` (use `statvfs`; its `f_basetype` names the filesystem type).
- **Exported by `libc.so.1` but declared by no header:** `fchmod`, `getrlimit`/`setrlimit` —
  declare them yourself, or the implicit declaration applies.
- **Static only:** `getmntent` and `getutxent` exist only as members of the `usr/ccs/lib/libc.so`
  archive, not in `libc.so.1`.
- **Cross `configure`:** putting `-include <decls.h>` into `CFLAGS` breaks autoconf's `char f();`
  function probes, so functions that exist read as absent. Keep such includes on the `make` line only.
- **Never `chmod` a bound `AF_UNIX` socket path:** it is a mode-000 FIFO, and after `chmod` every
  `connect()` fails `ENOTSOCK` ([networking](../how-it-works/networking.md#af-unix-socket-path)).
- Shell scripts: stock `sed` drops an unterminated last line ([quirk 88](../how-it-works/quirks.md#88-sed-drops-unterminated-line)).
- **`ftruncate` exists but can panic the box** (stock 2.1c and any kernel without the `kzero` fix): shrinking a big file to an unaligned EOF in its old
  last block takes a kernel bus error. Truncate to the block boundary, then write the tail back;
  `ftruncate` is a weak symbol in the static libc, so a strong replacement in the program overrides
  it for every caller (coreutils `dd`/`cp`, GNU tar `--delete`) ([quirk 90](../how-it-works/quirks.md#90-ftruncate-shrink-panics)).
  The aligned cut also avoids a second defect: after an unaligned shrink to an earlier block, a
  sparse regrow can read the old bytes back ([quirk 91](../how-it-works/quirks.md#91-shrink-regrow-stale-data)).
- **`%lld` also hides in formats built at run time** ✅: coreutils `stat -c %s` and the `stat -f`
  counts printed 0 because `stat.c` assembles its format with `strcat(…, PRIdMAX)`, which is `"lld"`
  when `intmax_t` is `long long`, and libc's printf reads `%lld` as 32 bits (the printf `ll` defect
  above). `od -t d8/u8/x8` builds formats the same way. A check that scans string literals for `ll`
  cannot see these; grep the sources for `PRIdMAX`/`PRIuMAX`/`PRIxMAX` too, and use `%ld`/`%lu` where
  the values fit a long.
- **`%llo` reads one word too** ✅: Heirloom tar built without its fix formats each size with
  `sprintf(size, "%11.11llo", (long long)st_size)`, and through the stock libc every member's size
  came out 0 on 68030 and 68060 systems, so its archives extract as empty files. The printf reads one
  32-bit word, the high half on this big-endian CPU. The amix package gate's `ll`-printf check caught
  it at build time; the port formats through `libamixc99`'s `snprintf`.
- **A non-blocking TCP `connect()` needs `O_NDELAY`, not `O_NONBLOCK`:** under `O_NONBLOCK` it fails
  with `EAGAIN` and reports nothing, even for a refused port ([networking](../how-it-works/networking.md#nonblocking-connect)).
- **`gethostbyname()` does not take a dotted quad:** parse IPv4 literals with `inet_addr()` first
  ([networking](../how-it-works/networking.md#gethostbyname-no-dotted-quad)).
- **`/usr/bin/rsh` is the BSD remote shell** (setuid root, 15452 bytes), not the restricted shell ✅.
- **The unprivileged account is `nobody`, uid and gid 60001; there is no `nogroup`** ✅ — a configure
  that probes the build host's `/etc/group` picks the wrong group name.

### Pseudo-terminals: `/dev/ptmx`, and where to push `ldterm` ✅ {#svr4-ptys}

Amix ptys are SVR4 STREAMS ptys ✅. `/dev/ptmx` is `crw-rw-rw- root root 27, 15`: the
clone driver (major 27) opening the `ptmx` major 15; the slaves are `/dev/pts/N`, major 14 (the 1.1
disks, 68030 and 68060). `grantpt`, `unlockpt` and `ptsname` are in `libc.so.1` (weak, with
strong `_` aliases) but no sysroot header declares them, so GCC 14 needs your own prototypes;
`/usr/lib/pt_chmod` is present. An autoconf `configure` skips its `/dev/ptmx` test when
cross-compiling, so define the pty choice yourself (Dropbear: `USE_DEV_PTMX`).

Measured with GCC 14 probes on the 1.1 disks in emulation (68030 and 68060 kernels) ✅:

- **Push `ptem`, `ldterm` and `ttcompat` in the process that will own the session.** If a session
  leader with no controlling tty pushes them on the slave, the pty becomes *its* controlling tty,
  even with the slave opened `O_NOCTTY`. Its forked child's `setsid()` and `open(slave)` then get no
  controlling tty (`open("/dev/tty")` fails `ENXIO`: no job control, no `^C`), and the master sees no
  EOF when the child exits. If the child pushes the modules after its own `setsid()`, as SVR4's
  `telnetd` does, its `/dev/tty` opens and the master reads 0 at exit. A parent that is not a
  session leader may push without harm. A server that forks a session leader per connection
  (`sshd`-style) must push in the session's child.
- **The master has no line discipline.** `tcgetattr` on it fails, and `ioctl(master, TIOCSWINSZ)`
  fails `EINVAL` until `ptem` is on the slave (then it returns 0 and `stty -a` on the slave shows the
  rows and columns). Set terminal modes and the window size on the slave. `ldterm`'s defaults are
  `intr` DEL, `quit` `^|`, `erase` `^h`, `kill` `^x`, speed 300, so a session whose modes are never
  set takes Backspace (DEL on a modern terminal) as interrupt.

### The stock math library: `libm.a` ✅ {#stock-libm}

Stock Amix ships its math library **only as an archive**, `/usr/ccs/lib/libm.a` (40 members, plus a
profiled copy in `libp/`); there is no shared `libm`. GCC 14 code links it and gets correct `double`
returns ✅ (measured: 357 results over 19 functions on an emulated stock 2.1c 68030, 2026-10-30; the
probe's positive `sqrt` rows turned out to be GCC's inline `fsqrt`, not libm — see below).

**It is software math on basic 6888x arithmetic** ✅ (`objdump` of every member): no `fsin`, `fcos`,
`fetox`, `flogn`, `fatan` or `ftan` anywhere. It does use two instructions the 040/060 FPUs lack in
hardware: **`fmovecr`** (the constant ROM; 21 sites, unimplemented on both the 68040 and the 68060)
and **`fintrz`** (16 sites, unimplemented on the 68040, implemented on the 68060). Per function, from
link maps of one-call programs ✅:

| Function | Members linked | 040/060 traps |
|---|---|---|
| `sin`, `cos`, `tan` | `reduce.o`, `sin.o` | `fintrz` ×3 |
| `atan`, `atan2` | `atan.o` | `fintrz` ×1, `fmovecr` ×1 |
| `exp`; `sinh`, `cosh`, `tanh` (pull `exp.o`) | `exp.o` | `fintrz` ×1 |
| `pow` | `pow.o`, `rem.o` | `fintrz` ×4, `fmovecr` ×1 |
| `fmod` | `rem.o` | `fintrz` ×1 |
| `log`, `log10`, `sqrt`, `floor`, `ceil`, `asin`, `acos` | — | none |
| `hypot`, `erf`, `gamma`, `j0`, `j1` | — | `fmovecr` |

So on a 68060 with its FPU only `pow`, `atan`, `atan2`, `hypot`, `erf`, `gamma` and the Bessel
functions reach the unimplemented-instruction trap; on a 68040 most of the library does. The
040/060 kernel's FPSP handles them: the same program's 357 results on an emulated 68040 (with the
emulator trapping the 040's unimplemented instructions) are **bit-identical** to the 68030's ✅. No
libm-level run on a 68060 yet 🟡. On FPU-less parts there is no usable floating point yet (see
[the 040/060 status](../how-it-works/68040-68060-status.md#what-the-port-reports-working)) ✅.

**Accuracy:** within 1 ulp of the correctly rounded result on every function tested ✅ — worst
`atan2` 0.745, `tan` 0.721, `tanh` 0.717, `sin` 0.63, `cosh` 0.625, `pow` 0.565 ulp; `floor`, `ceil`
and `fmod` exact. Not always correctly rounded: `pow(2, 0.5)` is `0x3ff6a09e667f3bcc`, one ulp below
`sqrt(2)`'s `…bcd` ✅.

**`sqrt`: libm's or the FPU's ✅.** A GCC 14 program that calls `sqrt()` directly does not call libm:
GCC emits one 68881 `fsqrt`, which is correctly rounded and implemented in hardware on the 040/060
too (no FPSP trap). A call through a function pointer (as perl makes it) reaches libm's `sqrt`, which
is within 1 ulp but **not correctly rounded**: `sqrt(2)` = `0x3ff6a09e667f3bcc` (0.56 ulp; correctly
rounded is `…bcd`), `sqrt(10)` 0.57 ulp, `sqrt(0.7)` 0.63 ulp — deterministic, the same bits whatever
`%fp0`/`%fp1` and the stack held beforehand. So the two routes can differ in the last bit. `sin`,
`log`, `exp` and `atan` are likewise independent of leftover FP registers ✅.

**FP state at start ✅:** `FPCR` is `0x00000000` when a process starts (round to nearest, extended
precision, no exception traps enabled), and the stock `fpsetmask(0)` that perl calls at startup
rewrites only the exception-enable byte.

**Errors are SVID, not IEEE** ✅: domain errors set `errno` to `EDOM` (33), the default `matherr()`
prints one line to stderr (`log: DOMAIN error`, `log: SING error`, `pow: DOMAIN error`, …), and the
return values are SVID's rather than NaN or infinity — `log(0)` and `log(-1)` → `-HUGE`
(−3.40282e38), `sqrt(-1)` → 0, `pow(0, -1)` → 0, `pow(-2, 0.5)` → 0, `fmod(1, 0)` → 1, `asin(2)` → 0.
A program that defines its own `matherr()` (the SVID hook) changes this. Code that tests `isnan()`
after a bad call sees none.

**Do not swap in musl's math as is** 🟡: musl 1.2.5's `src/math` built with GCC 14 for this target
gave `floor(1.0) = 0`, `ceil(2.0) = 1` and `sin(10) = −24.5`. Its round-to-integer trick assumes
`double` evaluation, and the 68881's extended-precision registers defeat it even with
`-fexcess-precision=standard` (one build measured, not investigated further).

### Cross-build traps that are not Amix's fault ✅

- **help2man pages come out empty.** Patch a source file that a man page is generated from and `make`
  tries to regenerate the page; in a cross build `help2man` cannot run the target binary, and
  autoconf's `missing` script then leaves the page **empty and exits 0** (GNU diffutils 2.8.1's
  `diff.1` and `sdiff.1` came out 0 bytes) ✅. Touch the tarball's pages after `configure`, and refuse
  empty payload files when packaging.
- **GNU diffutils 2.8.1 `sdiff -o`** treats the diff child's normal "files differ" exit (1) as a
  failure, so every completed interactive merge of differing files ends with "subsidiary program
  failed" and exit 2, although the merged file is correct ✅ (measured on the box). An upstream defect,
  fixed in diffutils 2.9 (`check_child_status`); backport it.

### SVR4 `/proc` is 37 `PIOC*` ioctls, not Linux-style text files ✅

Unlike Linux, Amix's `/proc/<pid>` is **a single file you `open()` and drive with `ioctl()`** — there
is no `/proc/<pid>/stat`, no `/proc/meminfo`, nothing to text-parse ✅. The sysroot's `sys/procfs.h`
defines **37 `PIOC*` ioctl codes** (`PIOCSTATUS`, `PIOCPSINFO` for `ps`-style info via `prpsinfo_t`,
`PIOCNMAP`/`PIOCMAP` for memory mappings, `PIOCCRED`, …). Consequence: a tool like `htop`, whose
entire data-collection layer is written against Linux `/proc` text files, is **not portable as
written — it is a rewrite** against the `PIOCPSINFO`/`prpsinfo_t` structures, not a patch; prefer a
small native tool over patching a large foreign one ✅. (A `top`-class monitor is tractable this way:
`sys/procfs.h` + `nlist()`, no `libkvm`.)

> **Corpus caution:** the `PIOC*` hits elsewhere in this grimoire are a **different, unrelated
> device** — a parallel-port driver's private ioctl namespace (`PIOCSETCTL`/`PIOCGETCTL` for printer
> handshake lines), which shares the `PIOC` prefix by convention only. Do not confuse it with the
> procfs ioctl family here ✅.

## SVR4 packaging

Amix uses the standard **SVR4 `pkgadd` packaging family** to bundle and install software ✅. The full lifecycle is: describe the payload with `pkgproto`, build a package with `pkgmk`, optionally bundle it into a single transferable datastream with `pkgtrans`, and install with `pkgadd` ✅.

### The pkg tools

| Tool | Role | Tag |
|---|---|---|
| `pkgproto` | Generate a **prototype** file (the manifest of files/dirs/perms) from a built tree | ✅ |
| `pkgmk` | Build a package from the prototype + a `pkginfo` file | ✅ |
| `pkgtrans` | Translate a directory-format package into a single datastream file (for transfer) | ✅ |
| `pkgadd` | Install a package onto the system | ✅ |

A minimal build-and-install loop looks like:

```sh
# 1. Stage your built files under a root, then generate a prototype
pkgproto /staging=/ > prototype        # see symlink gotcha below
# 2. Add the 'i pkginfo' line and any install scripts to prototype, then build
pkgmk -o -r /staging                   # builds into the spool dir
# 3. Bundle to a single datastream for transfer
pkgtrans -s /var/spool/pkg /tmp/MYpkg.pkg MYpkg
# 4. Install
pkgadd -d /tmp/MYpkg.pkg MYpkg
```

**`pkgproto` symlink gotcha** 🟡: `pkgproto` is reported to **omit symbolic links** from the generated prototype, so symlinks silently vanish from packages built straight from its output 🟡. Add the missing `s`-type (symlink) lines to the prototype by hand before running `pkgmk`. The prototype line format is `s none <link>=<target>`.

### How the installer itself uses packaging

The Amix install path is package-driven ✅. The `root.adf` install scripts wrap the pkg machinery with **`amixpkg`** (e.g. `amixpkg -i -m -d -r /mnt -y standard`) and stream the distribution from tape (`dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`) ✅. The `amixpkg` wrapper is widely reported to be flaky/"broken" 🟡, but the underlying `pkgadd`/`pkgmk`/`pkgtrans` tools are the standard SVR4 ones. The installation flow is detailed in §9 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md); see also the [installation walkthrough](../getting-started/install-walkthrough.md).

### AmixBP and the zoo+cpio fallback

For getting *additional* software onto a running system, two community distribution forms dominate ✅:

- **AmixBP** — Michael Parson's bundle of **40+ re-bundled `.pkg` packages**, hosted on **amigaunix.com/downloads** ✅. This is the practical "package repository" for Amix add-ons in the *download-a-bundle* sense — distinct from the machine-readable catalog+client repository format documented on [the package repository page](../how-it-works/package-repository.md). (Do not redistribute the packages here; point users to amigaunix.com.)
- **`zoo`-compressed `cpio`** — an alternative archive form used to ship software when a full `.pkg` isn't available ✅. Unpack with the on-box `zoo` and `cpio`.

The patch disk uses a related (but distinct) self-extracting mechanism — a 1 KB shell header, an SVR4 ASCII `cpio` (`070701`) archive, and a bundled `lha` unpacking `archive.lha` — documented in the [patch ADF anatomy](../boot-disks/anatomy-patch-adf.md). That is the model to study if you want to build a custom self-extracting add-on disk.

## End-to-end: which path do I use?

| You are… | Use | Toolchain |
|---|---|---|
| Building a single-file char driver | On-box native | `cc driver.c` (or newer GCC via `CC=`) ✅ |
| Building a STREAMS / kernel driver | On-box native | `make` in the driver dir, then `make force` to relink ✅ |
| Editing driver or kernel-module source on a modern host | Linux cross | `gcc-cross-amix` → `m68k-cbm-sysv4-gcc` (needs an Amix sysroot) ✅; never GCC 14 for kernel space ✅ |
| Porting modern C, C99 or C++ userland | Linux cross | `gcc14-cross-amix` → `m68k-elf-gcc`/`g++` with the Amix specs ([above](#the-userland-compiler-gcc14-cross-amix-gcc-14)) ✅ |
| Shipping userland software you compiled | SVR4 packaging | `pkgproto` → `pkgmk` → `pkgtrans` → `pkgadd` ✅ |
| Installing community add-ons | AmixBP / `zoo`+`cpio` | `pkgadd` / `zoo`+`cpio` ✅ |
| Rebuilding `/unix` after adding a driver | On-box or cross | see [kernel build](kernel-build.md) ✅ |

## See also

- [Building & Relinking the Kernel](kernel-build.md) — the `make` → `relocunix` → `make bootpart` flow the compilers feed into.
- [Writing a STREAMS Driver](writing-a-streams-driver.md) — the worked native build example.
- [Hydra Case Study](case-studies/hydra.md) — the real STREAMS driver built natively on Amix (`make` / `make force`).
- [VA2000 Case Study](case-studies/va2000.md) — a native single-file `cc` build and the pre-POSIX `/bin/sh` gotcha.
- [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix) — the Linux-hosted cross-toolchain bootstrap (`make all AMIX_ROOT=…`); the project builds from the [`jusii/gcc-cross-amix`](https://github.com/jusii/gcc-cross-amix) fork.
- [`asokero/gcc14-cross-amix`](https://github.com/asokero/gcc14-cross-amix) — the GCC 14 userland cross compiler; its `docs/TOOLCHAIN.md` records every measurement behind the flags above.
- [Loadable kernel modules](loadable-modules.md) — kernel-space code built with gcc-cross-amix against the ABI kit.
- [The Amix Device-Driver Model](driver-model.md) — major/minor numbers and the `cdevsw`/`bdevsw` tables drivers plug into.
- [Versions](../reference/versions.md) — version matrix (GCC 2.7.2.3 built under 2.03; `rdbunix`→`relocunix` rename).

## Sources
- The **`AF_UNIX` `chmod` trap** (first-party record, 2026-10-30) ✅ — see the matching Sources entry on [the networking page](../how-it-works/networking.md#af-unix-socket-path).
- amix-kerntools brief `tdivs-cross-assembler-miscompile` (2026-07-21): gcc-cross-amix `984192a` fix_asm rewrite + test-divmod; on-box measurements; metal confirmation 2026-07-21.
- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §7 (Toolchain & packaging), §6 (modern driver repos — Hydra **native** build, GCC 2.7.2.3 — the brief's "from amigaunix.com" attribution is 🔴, unsourced), §11 (userland shells), and §13 (open gaps #1, #3).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (kernel build flow; `rdbunix` historical name).
- The **stock native compiler**, measured on a stock Amix 2.1 install (2026-09-15/16) ✅: `gcc --version` prints `GNU GCC version 1.40.5 (68k, SGS/AT&T syntax)` (`/usr/public/bin/gcc`, `/usr/sys/Makefile` `CC = gcc`); it alone has `-fpcrel` and it rejects `-fno-builtin`. No copy of a native GCC 2.7.2.3 package or source for the "amigaunix.com pkg" attribution has been found — hence 🔴 on that attribution.
- `isoriano1968/hydra-amix` repo (the **native** `make` / `make force` build, `CFLAGS="-O -D_KERNEL -DSVR40 -DSVR4"`, `elf2brel` in `boot/`, native GCC 2.7.2.3 — origin unsourced 🔴, not an amigaunix.com pkg as far as any source shows): <https://github.com/isoriano1968/hydra-amix>
- `isoriano1968/gcc-cross-amix` repo (the Linux-hosted cross-toolchain: `Makefile` + `amix-gcc-wrapper.sh`; binutils 2.8.1 + GCC 2.7.2.3, target `m68k-cbm-sysv4`, user-supplied sysroot; `make all`/`test-hello`/`test-random`; C works, C++ WIP): <https://github.com/isoriano1968/gcc-cross-amix>
- `asokero/va2000-amix` repo (native `cc va2000.c`; pre-POSIX `/bin/sh` gotchas — no `$(...)`, no `grep -q`): <https://github.com/asokero/va2000-amix>
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` (install uses `amixpkg`/`cpio`/`dd` from tape).
- amigaunix.com — *downloads* page (AmixBP, Michael Parson) and *more_software* / *tips-tricks*: <https://www.amigaunix.com/doku.php/home>
- SVR4 packaging tools (`pkgproto`, `pkgmk`, `pkgtrans`, `pkgadd`) — standard AT&T System V Release 4 documentation.
- The Installer-NG (not public) and [amix-packagemanager](https://github.com/jusii/amix-packagemanager) work (first-party record, 2026-07-22/24) — platform behaviours root-caused under Amiberry and on a real A4000 + Z3660 (s5/UFS state reads, on-metal digest checks) ✅ (🟡 where tagged).
- The [`jusii/gcc-cross-amix`](https://github.com/jusii/gcc-cross-amix) fork (`main`): `2ab2b22` (the wrapper's 64-bit multiply expansion and `m68k-cbm-sysv4-scan060`), `80b6d67` and the README's "68060 Integer Code" section (no `-m68060`; use `-m68040`), all 2026-10-05; `1bfffbd` (the `-c` with no `-o` fix, `make test-objdir`) and `7036952` (its README scope), 2026-09-15. The `-c` fix reached the `isoriano1968` upstream with #7 (merged 2026-10-19); the 64-bit multiply expansion and `scan060` are not upstream yet. `ef7c86e` (the bit-field `#` → `&` repair) is in both. The 68060 kernels' integer emulation: the Installer-NG 1.0 release notes (not public; draft) 🟡.
- First-party cross-toolchain findings (2026-07-27): SGS-dialect probes of the installed `m68k-cbm-sysv4` binutils-2.8.1 `as` (the `#`-as-comment failure reproduced; per-construct MIT-syntax compatibility probes) and the wrapper `-c foo.s` source-destruction defect (minimally reproduced three times; cause chain pinned by tracing the wrapper; empty-stdin control via `as -m68020 -o t.s </dev/null`).
- The **amix-packages** porting campaign — `PORTING.md` and a corroborating ports-roadmap research pass (2026-08-28), all from direct Amix-sysroot inspection ✅: the byte-identical `libcurses.a`/`libtermcap.a`/`libtermlib.a` archive exporting both APIs and the "link `-lcurses`" policy (§3.4); no POSIX `regcomp`/`regexec`, only SVR4 `<regexp.h>` + libgen `regcmp`; `strcasecmp` present only in the networking libs and declared in no header (§3.1); `snprintf`/`vsnprintf`/`getpagesize` absent from `libc.so.1` (and `snprintf` undeclared in `stdio.h`) with the GCC 2.7.2.3 implicit-declaration miscompile (the reproduced `atof` case) and the wider absent-symbol list (§3.1); the SVR4 `/proc` 37-`PIOC*`-ioctl model vs. Linux text files, with the parallel-port-`PIOC*` disambiguation (§3.2); and the `fix_asm`-only-through-the-wrapper property — `-S` bypasses every fixup, including the silent `fcmp` operand-order reversal (§2.2). No proprietary SVR4 headers or source reproduced — symbol/header **presence and behaviour** observed live, paraphrased.
- [`asokero/gcc14-cross-amix`](https://github.com/asokero/gcc14-cross-amix) `main` (public) ✅: `README.md` (scope, "not for the kernel", the X-library repair, the 68060 trap, the sysroot), `LICENSE` (MIT, Antti Sokero), `docs/TOOLCHAIN.md` §1–§15 (the ELF and linker facts, §4 the return-value table, §6 why not `m68k-linux-gnu`, §9 the 68060, §11 the libc gaps, §15 `.init_array`) and its sections "-malign-int is the ABI" and "Linking the 1991 libX11.a"; `toolchain/install-specs.sh` (the specs); `toolchain/amix-abi.h` and commit `78a337a` (the return convention, 2026-10-27); `e8b6997` (`-mno-strict-align` default); `8a4cd12` (`cas2`); `tools/check-68060-safe.py`.
- [`amigaux/amix`](https://github.com/amigaux/amix) @ `95bf2f3`: `toolchain/README.md` and the two `.pin` files (the split, the container, `TOOLCHAIN.sha256`), `system/README.md` (the reference sysroot) ✅.
- The gcc14 evaluation and the package-line switch (first-party record, 2026-10-25 to 2026-10-29): probes on the host, an emulated 68030 and a 68060 with FPU; packages rebuilt and compared on a 68030 and a 68060; the return-ABI defect found and re-measured; the `-mno-strict-align` Dhrystone row on a real 68LC060 ✅.
- The project's system-files inventory (first-party record, 2026-10-29) ✅: the patch disk's `replace.list`/`modify.list`/`changes`, compared with `/usr` read from a cleanly installed 2.1c system and with the kernel-work sysroot; the kit rebuilt both ways on both lines.
- The amix-packages diffutils 2.8.1 port (first-party record, 2026-10-29) ✅: `recipes/diffutils/build.sh` and `recipes/make/build.sh` (the `vfork` pin), the emulated 68030 rows (the `sdiff -o` exit, the empty help2man pages), `nm` and header reads of the sysroot (`sigaltstack`).
- [isoriano1968/gcc-cross-amix #7](https://github.com/isoriano1968/gcc-cross-amix/pull/7) (the wrapper fixes, opened 2026-10-13, merged 2026-10-19 as `959c17f`; state read with `gh` on 2026-10-29) ✅.
- The upstream-runtime FPU check (first-party record, 2026-10-29) ✅: an upstream `58130fe` build checked with the project's `check-68060-safe.py --68881` (68060-safe for integer forms; 614 FPU instructions in 040/060-only forms across libgcc and libstdc++); upstream's `README.md` ("defaults to `--with-cpu=68060`") and `toolchain/build-cross.sh` at that commit.
- The bzip2 1.0.8 and coreutils 5.2.1 ports (first-party record, 2026-10-29) ✅: sysroot reads (`nm` of `libc.so.1` and the `libc.so` archive, the headers) and the emulated 68030 runs behind the gaps list, the `TZ` crash and the `configure` trap.
- The rsync 3.1.3 port (first-party record, 2026-10-30) ✅: the `ftruncate` probe rows and the `truss` of `gethostbyname()` on an emulated stock 2.1c (details in quirk 90 and on the networking page); `ls -l` of `/usr/bin/rsh` and the `nobody` entries of `/etc/passwd` and `/etc/group` read on the box; [amix-packages](https://github.com/jusii/amix-packages) `e7ac916` (`recipes/rsync/`).
- The stock `libm.a` measurements (first-party record, 2026-10-30) ✅ — the `sqrt` correction from follow-up probes calling libm's `sqrt` through a function pointer with `%fp0`/`%fp1` and the stack preloaded, `objdump` of the first probe's `main` (one inline `fsqrt`, re-read for this page), and an `FPCR`/`fpsetmask` read; ulps recomputed for this page: `ar t` and `objdump -d` of the sysroot's `/usr/ccs/lib/libm.a` (21 `fmovecr`, 16 `fintrz`, no transcendental instructions; counts re-read for this page), link maps of one-call programs, and a GCC 14 test program (19 functions, raw IEEE bits) run on an emulated stock 2.1c 68030 and an emulated 68040 on the 040/060 kernel line with unimplemented-instruction trapping on, the outputs equal; ulps against `mpmath` at 200 bits; a musl 1.2.5 `src/math` build of the same program (amix-packages).
- The coreutils 5.2.1-3 and gtar 1.14-7 rebuilds (first-party record, 2026-10-30) ✅: the `stat -c %s` and `stat -f` rows on the box, `stat.c`'s run-time format assembly, `nm` of `truncate.o` in the static libc archive (`_ftruncate` T, `ftruncate` W); [amix-packages](https://github.com/jusii/amix-packages) `97bbcf1` (patch 09, the `ftruncate` replacement), `cad15e4`, `cbd8c25`.
- The Heirloom tar and Dropbear ports (first-party record, 2026-11-01/02) ✅: the `%llo` size fields written as 0 by an unpatched Heirloom tar build on 68030 and 68060 systems in emulation, caught by the package gate's `ll`-printf check ([`amigaux/amix`](https://github.com/amigaux/amix) `userland/packages/heirloom-tar`, `b07d4cb`, on `master`); the pty probes (session leader and child pushes, `tcgetattr` and `TIOCSWINSZ` on the master, `ls -l` of the nodes, `nm -D` of the sysroot `libc.so.1`) on the 1.1 disks booted on 68030 and 68060 kernels in emulation, behind Dropbear's patch 05 (`userland/packages/dropbear`, `51ba153`, on `master`).
- The **static `vfork` and the X11R6.3 Imake trap** (first-party record, 2026-11-02) ✅: the `xinit` cores on a real A4000D and the stock `libc.so.1` disassembly behind [quirk 98](../how-it-works/quirks.md#98-vfork-child-signal-table); `Imake.tmpl`; the package audit and the x11r63 fix ([`amigaux/amix`](https://github.com/amigaux/amix) `userland/packages/x11r6.3`, `c3abeff`, `443fe46`, on `master`).
