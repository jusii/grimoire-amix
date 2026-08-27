---
title: Toolchain & Packaging
summary: Native on-box cc/GCC builds plus a Linux-hosted cross-toolchain (gcc-cross-amix — binutils 2.8.1 + GCC 2.7.2.3, m68k-cbm-sysv4), elf2brel, and SVR4 packaging (pkgmk/pkgtrans/pkgadd, AmixBP).
status: draft
---

# Toolchain & Packaging

Amix builds software two ways. **On the box**: the bundled AT&T SVR4 `cc` (the kernel's reference compiler) or a community **GCC 2.7.2.3** (installable as a pkg from [amigaunix.com](https://amigaunix.com)), with GNU `make` and GAS, then relink `/unix` ✅ — this is how the existing drivers ([Hydra](case-studies/hydra.md), [VA2000](case-studies/va2000.md)) are built. **On Linux**: as of 2026-06 a public, reproducible *cross*-toolchain exists — [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix), a GCC 2.7.2.3 retargeted to `m68k-cbm-sysv4` — that compiles Amix userland binaries and kernel/driver objects on a modern host (you supply your own licensed Amix sysroot) ✅. Finished software is shipped as SVR4 packages built with `pkgproto`/`pkgmk`/`pkgtrans` and installed with `pkgadd` ✅; the large community bundle is **AmixBP**, with a `zoo`+`cpio` fallback ✅.

Two important caveats colour everything below. The Amix `/bin/sh` is **pre-POSIX**, which breaks many modern build scripts ✅. And the cross-toolchain still needs a **user-supplied licensed Amix sysroot** (headers/libs/startup objects are not redistributable), and its **C++/`g++` support is not finished yet** 🟡 — C is fully working.

This page is the toolchain companion to [building and relinking the kernel](kernel-build.md) and to [writing a STREAMS driver](writing-a-streams-driver.md) (the worked native build example). For the underlying driver model see [the Amix device-driver model](driver-model.md).

## Native compilers on the box

Amix ships with a working C development environment ✅. The reference compiler is the **AT&T SVR4 `cc`**, used for the kernel itself and for simple drivers ✅. A copy of **GCC** is also bundled ✅.

| Tool | Version / location | Notes | Tag |
|---|---|---|---|
| AT&T SVR4 `cc` | system default | Reference compiler for kernel + simple drivers | ✅ |
| Bundled GCC (legacy) | **`gcc 1.4.2`** at **`/usr/public/bin/gcc`** | Old; prefer a newer GCC where one is installed | ✅ |
| Community GCC | **2.7.2.3** (native Amix build; installable **pkg on amigaunix.com**) | The compiler the Hydra driver builds with, on-box; select via `CC` | ✅ |
| GNU `make` | **3.80** | The make used by the driver makefiles | 🟡 |
| GAS (GNU assembler) | bundled | Assembler backing GCC | 🟡 |
| `perl` | **5.005_4** | Available in some installs | 🟡 |

**Prefer the newer compiler.** The `gcc` on `PATH` may be the ancient `1.4.2` at `/usr/public/bin/gcc` ✅. When a newer GCC (e.g. 2.7.2.3) is installed, point the build at it explicitly rather than relying on `PATH` order:

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

The native compiler is **GCC 2.7.2.3** (or the AT&T `cc`), available as a pkg on amigaunix.com ✅.

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

- **Components:** GNU **binutils 2.8.1** + **GCC 2.7.2.3** (the same GCC version Amix runs natively), downloaded from the GNU archive and built with `-std=gnu89` (the 1990s configure tests and sources predate C99). The installed cross driver is **`m68k-cbm-sysv4-gcc`** — our earlier docs called it `m68k-amix-gcc`, a placeholder; the real binary is the triple-prefixed one ✅.
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
offsets/widths. As of `gcc-cross-amix` `d0a4045` the wrapper's `fix_asm` auto-repairs `#` → `&`
**inside bit-field braces** for all eight bit-field mnemonics, gated on the *encoding* by
`make test-bitfield` (offset/width read back out of the extension word). The repair is deliberately
narrow: `#APP`/`#NO_APP` and every other `#` on the line are untouched, so **all other hand-written
immediates remain the author's responsibility** — `moveq #1,%d0` in an `__asm__` block is still
silently eaten. When importing any third-party m68k asm or inline asm: grep the code fields for `#`,
rewrite to `&`, and verify the encoding, not the build's exit status ✅.

### The wrapper's `-c foo.s` with no `-o` silently destroys the source ✅

A destructive trap in the cross **wrapper's** `.s` path (present in the shipped wrapper as of
2026-07; a wrapper fix is queued in the `gcc-cross-amix` repo ✅):

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
`-o`** — under the wrapper such a rule eats its own source ✅. Until the fixed wrapper ships, the
defence is one line:

```make
.s.o:
	$(CC) $(CFLAGS) -c $< -o $@
```

With an explicit `-o` the wrapper's `.s` path is correct ✅. `.c` compiles are not exposed — the
wrapper's compile path always names its output ✅. Keep assembly sources under version control
regardless: a trap that exits 0 is only ever caught after the fact.

### The stock shared-libc `getpwnam()` first-call SIGSEGV — and the static-link sidestep ✅

A separate porting hazard lives in the stock **shared `libc.so.1`**, not in the toolchain: the **first `getpwnam()` call** of a process crashes inside libc's passwd-record handling (a record expand routed through the `_libc_malloc` allocator-redirect pointers), while the symmetric group path (`getgrnam`) survives — the asymmetry is entirely inside libc and not debuggable off-box. Interposition was ruled out (libc calls its internal helpers via non-preemptible `bsrl`). The **working sidestep**, used in every binary of the ported pkg toolchain: link them **statically** and let the executable *define* `getpwnam`/`getpwuid`/`getgrnam`/`getgrgid` as small direct `/etc/passwd`/`/etc/group` parsers — an executable's own global symbols win over shared-library exports at static link time, so every internal caller is preempted uniformly. Two consequences worth knowing: this only protects code you can relink (it cannot reach the stock **dynamically-linked** daemons — which were never the victims of this particular defect anyway; a daemon crashing at boot is far more likely the [colon-less-`TZ` bug](../how-it-works/quirks.md)), and it is one more reason the install-media engine ships static.

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
| Editing driver/userland source on a modern host | Linux cross | `gcc-cross-amix` → `m68k-cbm-sysv4-gcc` (needs your own Amix sysroot) ✅; C only, C++ WIP 🟡 |
| Shipping userland software you compiled | SVR4 packaging | `pkgproto` → `pkgmk` → `pkgtrans` → `pkgadd` ✅ |
| Installing community add-ons | AmixBP / `zoo`+`cpio` | `pkgadd` / `zoo`+`cpio` ✅ |
| Rebuilding `/unix` after adding a driver | On-box or cross | see [kernel build](kernel-build.md) ✅ |

## See also

- [Building & Relinking the Kernel](kernel-build.md) — the `make` → `relocunix` → `make bootpart` flow the compilers feed into.
- [Writing a STREAMS Driver](writing-a-streams-driver.md) — the worked native build example.
- [Hydra Case Study](case-studies/hydra.md) — the real STREAMS driver built natively on Amix (`make` / `make force`).
- [VA2000 Case Study](case-studies/va2000.md) — a native single-file `cc` build and the pre-POSIX `/bin/sh` gotcha.
- [`isoriano1968/gcc-cross-amix`](https://github.com/isoriano1968/gcc-cross-amix) — the Linux-hosted cross-toolchain bootstrap (`make all AMIX_ROOT=…`).
- [The Amix Device-Driver Model](driver-model.md) — major/minor numbers and the `cdevsw`/`bdevsw` tables drivers plug into.
- [Versions](../reference/versions.md) — version matrix (GCC 2.7.2.3 built under 2.03; `rdbunix`→`relocunix` rename).

## Sources

- amix-kerntools brief `tdivs-cross-assembler-miscompile` (2026-07-21): gcc-cross-amix `984192a` fix_asm rewrite + test-divmod; on-box measurements; metal confirmation 2026-07-21.
- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §7 (Toolchain & packaging), §6 (modern driver repos — Hydra **native** build, GCC 2.7.2.3 from amigaunix.com), §11 (userland shells), and §13 (open gaps #1, #3).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (kernel build flow; `rdbunix` historical name).
- `isoriano1968/hydra-amix` repo (the **native** `make` / `make force` build, `CFLAGS="-O -D_KERNEL -DSVR40 -DSVR4"`, `elf2brel` in `boot/`, native GCC 2.7.2.3 from amigaunix.com): <https://github.com/isoriano1968/hydra-amix>
- `isoriano1968/gcc-cross-amix` repo (the Linux-hosted cross-toolchain: `Makefile` + `amix-gcc-wrapper.sh`; binutils 2.8.1 + GCC 2.7.2.3, target `m68k-cbm-sysv4`, user-supplied sysroot; `make all`/`test-hello`/`test-random`; C works, C++ WIP): <https://github.com/isoriano1968/gcc-cross-amix>
- `asokero/va2000-amix` repo (native `cc va2000.c`; pre-POSIX `/bin/sh` gotchas — no `$(...)`, no `grep -q`): <https://github.com/asokero/va2000-amix>
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` (install uses `amixpkg`/`cpio`/`dd` from tape).
- amigaunix.com — *downloads* page (AmixBP, Michael Parson) and *more_software* / *tips-tricks*: <https://www.amigaunix.com/doku.php/home>
- SVR4 packaging tools (`pkgproto`, `pkgmk`, `pkgtrans`, `pkgadd`) — standard AT&T System V Release 4 documentation.
- The **Installer-NG** Waves 5–6 field campaign (amix-installng @ `7106f1b`, amix-packagemanager @ `4539ad2`), 2026-07-22/24 — a blank-disk→bootable-install effort that root-caused these platform behaviours on the Amiberry bench and the real A4000+Z3660 (acceptance-run captures, s5/UFS state reads, and the on-metal digest attestation) ✅ (🟡 where tagged).
- First-party cross-toolchain findings (2026-07-27): SGS-dialect probes of the installed `m68k-cbm-sysv4` binutils-2.8.1 `as` (the `#`-as-comment failure reproduced; per-construct MIT-syntax compatibility probes) and the wrapper `-c foo.s` source-destruction defect (minimally reproduced three times; cause chain pinned by tracing the wrapper; empty-stdin control via `as -m68020 -o t.s </dev/null`).
