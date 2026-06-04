---
title: Toolchain & Packaging
summary: Native on-box cc/GCC builds (the m68k-amix-gcc cross path has no public recipe and isn't needed), elf2brel, and SVR4 packaging (pkgmk/pkgtrans/pkgadd, AmixBP).
status: draft
---

# Toolchain & Packaging

Amix builds software **on the box**: the bundled AT&T SVR4 `cc` (the kernel's reference compiler) or a community **GCC 2.7.2.3** (installable as a pkg from [amigaunix.com](https://amigaunix.com)), with GNU `make` and GAS, then relink `/unix` ✅. This is how the real drivers are actually built — the [Hydra STREAMS driver](case-studies/hydra.md) and the [VA2000 framebuffer](case-studies/va2000.md) both compile **natively, with no cross-compiler** ✅. A *cross* path (`m68k-amix-gcc`, a GCC retargeted to `m68k-cbm-sysv4`, emitting ELF converted with `elf2brel`) is conceivable but has **no public build recipe** 🔴 — and is not needed, because the native build works. Finished software is shipped as SVR4 packages built with `pkgproto`/`pkgmk`/`pkgtrans` and installed with `pkgadd` ✅; the large community bundle is **AmixBP**, with a `zoo`+`cpio` fallback ✅.

Two important caveats colour everything below. The Amix `/bin/sh` is **pre-POSIX**, which breaks many modern build scripts ✅. And the `m68k-amix-gcc` *cross*-compiler has **no public, reproducible build recipe** 🔴 — but that gap is **not on the critical path**, since drivers build natively on the box.

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

## The native kernel-driver build (and the m68k-amix-gcc cross gap)

The modern Amix drivers are built **natively on the box**, not cross-compiled. The [Hydra STREAMS driver](case-studies/hydra.md)'s `Makefile` invokes the on-box compiler (`cc` / `ld -r`): `make` produces a relocatable object (`exp`), then `cd /usr/sys && make force` relinks the kernel with it ✅. A cross-compiler retargeted to Amix (**`m68k-amix-gcc`**, vendor triple `m68k-cbm-sysv4`) is conceivable for editing driver source on a modern host, but **no public recipe to build it exists** 🔴 (see below) — so in practice you build inside the emulator or on real hardware.

### The target triple

Configure the cross GCC for the Amix platform triple ✅:

| Field | Value | Tag |
|---|---|---|
| Canonical triple | **`m68k-cbm-sysv4`** | ✅ |
| What autodetect yields | `m68k-unknown-sysv4` (set `cbm` explicitly) | ✅ |

The `cbm` (Commodore) vendor field matches the kernel platform string `m68k-cbm-sysv4` used throughout Amix ✅. If you let `config.guess`/autodetect pick the vendor it will say `unknown`; override it.

### Kernel-driver build flags

The Hydra `Makefile` compiles with these kernel flags, using the **native** on-box compiler — no `CC=m68k-amix-gcc` override ✅:

```sh
# Native on-box build (the Makefile's own flags).
make        # CFLAGS = -O -D_KERNEL -DSVR40 -DSVR4 ; links 'exp' via ld -r
```

- `-D_KERNEL` selects the in-kernel headers/macros (not the user-space ABI).
- `-DSVR40` / `-DSVR4` select the SVR4 / SVR4.0 code paths.
- `-O` is the optimisation level the repos build at.

The native compiler is **GCC 2.7.2.3** (or the AT&T `cc`), available as a pkg on amigaunix.com ✅.

### ELF → boot format: elf2brel

The compiler emits **ELF** objects (m68k, SVR4) ✅. Amix's kernel boot path does not consume raw ELF directly; the kernel build converts the linked image to the **Amix boot ("brel") format** with the **`elf2brel`** tool that lives in the kernel source tree's **`boot/`** (a.k.a. `stand/`) directory ✅. This conversion is part of the on-box kernel relink, not a separate cross step:

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

### Open gap: no public cross-toolchain build recipe 🔴

**There is no public, reproducible recipe to build `m68k-amix-gcc` from source** 🔴. A cross GCC would need the **licensed Amix SVR4 headers and C library** as a sysroot, which cannot be redistributed. But this is **not a blocker**: the driver repos do **not** use a cross-compiler — they build **natively** on a licensed Amix install. They are source-only because that licensed install (its kernel headers/libs) is what you must supply, not because of any cross toolchain ✅.

Practical consequences:

- You cannot reconstruct `m68k-amix-gcc` purely from open materials today 🔴 — but you don't need to.
- The actual build path is **on the box** (in the emulator or on real hardware) with native `cc`/GCC 2.7.2.3 (see [native compilers](#native-compilers-on-the-box)). Single-file drivers like the [VA2000 framebuffer driver](case-studies/va2000.md) build with `cc va2000.c`; the [Hydra STREAMS driver](case-studies/hydra.md) builds with `make` + `make force` ✅.
- If you do have a licensed Amix install, you can extract its headers/libs to form a sysroot, but the exact configure/build invocation for the cross GCC is **not documented** in any source we hold 🔴.

This is tracked as open gap #1 in §13 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md).

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

- **AmixBP** — Michael Parson's bundle of **40+ re-bundled `.pkg` packages**, hosted on **amigaunix.com/downloads** ✅. This is the practical "package repository" for Amix add-ons. (Do not redistribute the packages here; point users to amigaunix.com.)
- **`zoo`-compressed `cpio`** — an alternative archive form used to ship software when a full `.pkg` isn't available ✅. Unpack with the on-box `zoo` and `cpio`.

The patch disk uses a related (but distinct) self-extracting mechanism — a 1 KB shell header, an SVR4 ASCII `cpio` (`070701`) archive, and a bundled `lha` unpacking `archive.lha` — documented in the [patch ADF anatomy](../boot-disks/anatomy-patch-adf.md). That is the model to study if you want to build a custom self-extracting add-on disk.

## End-to-end: which path do I use?

| You are… | Use | Toolchain |
|---|---|---|
| Building a single-file char driver | On-box native | `cc driver.c` (or newer GCC via `CC=`) ✅ |
| Building a STREAMS / kernel driver | On-box native | `make` in the driver dir, then `make force` to relink ✅ |
| Shipping userland software you compiled | SVR4 packaging | `pkgproto` → `pkgmk` → `pkgtrans` → `pkgadd` ✅ |
| Installing community add-ons | AmixBP / `zoo`+`cpio` | `pkgadd` / `zoo`+`cpio` ✅ |
| Rebuilding `/unix` after adding a driver | On-box or cross | see [kernel build](kernel-build.md) ✅ |

## See also

- [Building & Relinking the Kernel](kernel-build.md) — the `make` → `relocunix` → `make bootpart` flow the compilers feed into.
- [Writing a STREAMS Driver](writing-a-streams-driver.md) — the worked native build example.
- [Hydra Case Study](case-studies/hydra.md) — the real STREAMS driver built natively on Amix (`make` / `make force`).
- [VA2000 Case Study](case-studies/va2000.md) — a native single-file `cc` build and the pre-POSIX `/bin/sh` gotcha.
- [The Amix Device-Driver Model](driver-model.md) — major/minor numbers and the `cdevsw`/`bdevsw` tables drivers plug into.
- [Versions](../reference/versions.md) — version matrix (GCC 2.7.2.3 built under 2.03; `rdbunix`→`relocunix` rename).

## Sources

- [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §7 (Toolchain & packaging), §6 (modern driver repos — Hydra **native** build, GCC 2.7.2.3 from amigaunix.com), §11 (userland shells), and §13 (open gaps #1, #3).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (kernel build flow; `rdbunix` historical name).
- `isoriano1968/hydra-amix` repo (the **native** `make` / `make force` build, `CFLAGS="-O -D_KERNEL -DSVR40 -DSVR4"`, `elf2brel` in `boot/`, native GCC 2.7.2.3 from amigaunix.com): <https://github.com/isoriano1968/hydra-amix>
- `asokero/va2000-amix` repo (native `cc va2000.c`; pre-POSIX `/bin/sh` gotchas — no `$(...)`, no `grep -q`): <https://github.com/asokero/va2000-amix>
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` (install uses `amixpkg`/`cpio`/`dd` from tape).
- amigaunix.com — *downloads* page (AmixBP, Michael Parson) and *more_software* / *tips-tricks*: <https://www.amigaunix.com/doku.php/home>
- SVR4 packaging tools (`pkgproto`, `pkgmk`, `pkgtrans`, `pkgadd`) — standard AT&T System V Release 4 documentation.
