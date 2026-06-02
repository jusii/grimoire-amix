---
title: X11 RTG Graphics Drivers
summary: Retargetable graphics on Amix — the Xrtg X11R5 server architecture layered over a kernel framebuffer driver such as /dev/va2000.
status: draft
---

# X11 RTG Graphics Drivers

**Retargetable graphics (RTG)** on Amix means running an X server against a generic linear-framebuffer
graphics board instead of the historical built-in mono display or the A2410 TIGA color path. The modern
reproduction route is the `Xrtg` X11R5 server from [`asokero/xrtg-amix`](https://github.com/asokero/xrtg-amix),
which drives the MNT **VA2000** Zorro II card through a kernel character driver at `/dev/va2000` ✅. It runs in
**TrueColor RGB565** at resolutions from **640×480 up to 1920×1080**, using the card's hardware blitter for
fills and copies and a software cursor ✅.

This page explains the RTG concept, walks the full layered stack from X clients down to the framebuffer,
shows how the server is built with `imake` and a custom `config/amix.cf`, and describes how mouse and keyboard
input reach the server through the AMIX screen manager. RTG on Amix is a **two-part build**: you need the
[`va2000` kernel driver](case-studies/va2000.md) working *first*, then the `Xrtg` server on top of it ✅.

> **Confidence note.** Everything specific to `Xrtg`/`va2000` on this page is ✅ — it comes from the
> repository source and READMEs (brief §6). Historical X11 context (X11R4 vs R5, OpenLook, TIGA) is
> covered in [X11 & the Desktop](../how-it-works/x11-and-desktop.md) and is mostly 🟡; this page is the
> driver-development view of the modern RTG path.

## What "RTG" means here

On a stock Amix system the X server talks to one of two display back-ends:

- the **built-in mono framebuffer** (the "slow as molasses" mono X path 🟡), or
- the **A2410 "Lowell"** color board (TMS34010, 1024×768) via a **TIGA** server started with
  `olinit -- -tiga` 🟡.

Both are baked into specific server binaries. **Retargetable graphics** instead targets a *generic* linear
framebuffer exposed by the kernel as a memory-mappable character device. Any Zorro II RTG card that presents
a linear framebuffer window can be supported by writing (a) a small kernel framebuffer driver and (b) a
matching RTG back-end inside the X server. On Amix today that pairing is the [`va2000`](case-studies/va2000.md)
driver plus the `Xrtg` server ✅.

Because Amix's memory-mapping layer cannot address Zorro III space, **RTG cards must be Zorro II / linear-mode
only** ✅ — the same constraint that applies to all Amix graphics expansion (see
[Hardware](../how-it-works/hardware.md)).

## The layered stack

`Xrtg` is structured as a conventional X11 sample-server with an Amix-specific **DDX** (Device-Dependent X)
layer, which in turn talks to an RTG abstraction layer, which talks to the kernel framebuffer driver. From the
application down to the hardware ✅ (brief §6, `xrtg-amix` source tree):

```text
X clients (xterm, olwm, …)          ← X11 protocol over a socket
        │
        ▼
Xrtg  (X11R5 sample server core)    ← DIX: dispatch, resources, protocol
        │
        ▼
AMIX DDX        ddx/amix/           ← screen init, input, colormap, GC ops
        │
        ▼
RTG layer       ddx/amix/rtg/       ← generic framebuffer / blitter abstraction
        │
        ▼
VA2000 back-end ddx/amix/rtg/va2000/ ← card-specific: RGB565, blitter regs
        │
        ▼
/dev/va2000     (char major 68, minor 0)   ← mmap()'d framebuffer + regs
        │
        ▼
MNT VA2000 hardware (4 MB Zorro II window)
```

Mapping the source directories to layers ✅:

| Layer | Source location | Responsibility |
|---|---|---|
| Server core (DIX) | X11R5 sample server | Protocol dispatch, resource DB, request handling |
| AMIX DDX | `ddx/amix/` | Screen open/close, input, colormaps, drawing primitives |
| RTG layer | `ddx/amix/rtg/` | Generic linear-framebuffer + blitter abstraction (card-agnostic) |
| VA2000 back-end | `ddx/amix/rtg/va2000/` | VA2000 specifics: RGB565 visual, hardware blitter fills/copies |
| Kernel driver | `/dev/va2000` (char major 68) | `mmap()` of the framebuffer and register window |

The split between `ddx/amix/rtg/` (generic) and `ddx/amix/rtg/va2000/` (card-specific) is the part that makes
this *retargetable*: porting `Xrtg` to a different linear-framebuffer card means writing a new back-end under
`ddx/amix/rtg/`, not touching the DDX or server core ✅.

### Visual and resolutions

- **Visual:** TrueColor, **RGB565** (5 bits red, 6 green, 5 blue; 16 bits/pixel) ✅.
- **Resolutions:** 640×480 through **1920×1080** ✅. (Note the VA2000 *kernel* driver itself advertises
  800×600 / 1024×768 / 1280×720 at 16-bit ✅ — see the [VA2000 case study](case-studies/va2000.md); `Xrtg`
  exposes the framebuffer modes the driver provides.)
- **Acceleration:** the VA2000's **hardware blitter** is used for solid fills and screen-to-screen copies; the
  pointer is a **software cursor** composited by the server ✅.

## Prerequisite: the va2000 kernel driver

`Xrtg` has nothing to draw on until the kernel exposes the framebuffer. **Build and install the
[`va2000` framebuffer driver](case-studies/va2000.md) first**, then verify the device node exists ✅:

```sh
ls -l /dev/va2000
# crw-r--r--   1 root   ...   68,  0 ...  /dev/va2000   (char major 68, minor 0)
```

If the node is missing, create it (the va2000 install does this for you) ✅:

```sh
mknod /dev/va2000 c 68 0
```

The driver is a single-file char driver (`cc va2000.c`) that is statically linked into a rebuilt kernel
(`relocunix`) — Amix has **no loadable modules**, so this requires a kernel relink and reboot. See the
[VA2000 case study](case-studies/va2000.md) and [Kernel build & install](kernel-build.md) for the full
procedure ✅. `Xrtg` then `mmap()`s `/dev/va2000` to reach both the framebuffer and the card's blitter/control
registers ✅.

## Building Xrtg with imake

`Xrtg` is built as part of an **X11R5** source tree using the standard X11 **`imake`** build system, with a
custom platform-configuration file `config/amix.cf` that teaches `imake` about Amix's SVR4 quirks ✅
(brief §6). Two settings in `amix.cf` matter most:

| `amix.cf` setting | Value | Why ✅ |
|---|---|---|
| `BuildPex` | `NO` | PEX (the PHIGS 3D extension) is not built — keeps the server minimal and avoids unported code |
| SVR4 library rules | (custom) | Amix's SVR4 archiver/`ranlib` behavior differs from BSD; the lib rules are adjusted to avoid `ranlib`-related build failures |

The general shape of an `imake`-based X build is ✅ (standard X11R5 procedure; consult the repo README for the
exact invocation):

```sh
# 1. Put config/amix.cf in the tree's config/ dir (selected as the platform .cf)
# 2. Generate the top-level Makefile from the Imakefiles:
xmkmf -a
# or, in some trees:
make Makefiles

# 3. Build dependencies, then the world:
make depend
make
```

> **Note.** `Xrtg` reuses the X11R5 sample-server core, so the build pulls in a large X11R5 tree. The Amix-
> specific work lives under `ddx/amix/`; `config/amix.cf` is what makes that tree compile and link under
> Amix SVR4 rather than on a generic Unix. Always treat the repo README as the authoritative build recipe ✅.

For the native compilers and SVR4 toolchain caveats (the bundled AT&T `cc`, GCC up to 2.7.2.3, GNU `make`
3.80), see the [toolchain reference](toolchain.md) ✅/🟡.

### Licensing of the build

The **new** `Xrtg` Amix code is **MIT-licensed**; the surrounding **X11R5** code retains the original **X
Consortium** terms ✅. Building it also requires a licensed Amix system for the SVR4 headers and libraries —
the proprietary Amix distribution is not redistributable (see [licensing](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md)).

## Input: the AMIX screen manager

Mouse and keyboard input do **not** come through the framebuffer device. `Xrtg` gets input from the Amix
**screen manager** — the same console/screen subsystem the kernel uses for virtual consoles. The DDX layer
opens a screen and activates it for input via ✅ (brief §6):

- **`OpenScreen()`** — open an Amix screen (the screen-manager handle the server draws/receives input on), and
- the **`SIOCACTIVATE`** ioctl — make that screen the active/foreground screen so it receives keyboard and
  mouse events.

This ties the RTG server into Amix's existing screen-switching model. The same `console`/`screen` subsystem is
what the [`va2000` driver patches](case-studies/va2000.md) when it registers an **RTG screen type** in
`amiga/console/{scrdev.c,c0.c,screen.c}` ✅ — i.e. the kernel side teaches the screen manager that an RTG
framebuffer screen exists, and `Xrtg` then drives it through `OpenScreen()` / `SIOCACTIVATE`.

> **Keymap quirk.** The historical Amix X servers have a well-known keymap oddity (y/z swapped, `/` = SHIFT-8)
> 🟡 — see [X11 & the Desktop](../how-it-works/x11-and-desktop.md). Whether the RTG path inherits it depends
> on the keymap the screen manager hands the server; treat it as 🟡 until verified on the RTG stack.

## Bringing it up (end to end)

The high-level path to a working RTG X session ✅ (composed from the va2000 and xrtg repo procedures):

1. Build and install the [`va2000` kernel driver](case-studies/va2000.md); relink `relocunix`, write the boot
   partition (`make bootpart KERNEL=relocunix`), reboot. Confirm `/dev/va2000` (char major 68, minor 0).
2. Build `Xrtg` from the X11R5 tree with `config/amix.cf` (`imake` → `make`).
3. Install the `Xrtg` binary and start it; X clients then connect over the normal X protocol socket.

Once `Xrtg` is up you run an ordinary X session against it — e.g. an `xterm` and a window manager. For the
historical desktop environment (OpenLook `olwm`/`olwsm`, `tvtwm`, the X11R5 font-path gotcha), see
[X11 & the Desktop](../how-it-works/x11-and-desktop.md) 🟡.

## See also
- [`xrtg-amix` case study](case-studies/xrtg.md) — deep dive on the `Xrtg` server repo.
- [`va2000` case study](case-studies/va2000.md) — the kernel framebuffer driver `Xrtg` requires.
- [X11 & the Desktop](../how-it-works/x11-and-desktop.md) — historical X11R4/R5, OpenLook, A2410 TIGA, quirks.
- [The Amix driver model](driver-model.md) — `cdevsw[]`, char vs block, statically-linked drivers.
- [Writing a char driver](writing-a-char-driver.md) — the char-driver pattern the va2000 framebuffer follows.
- [Kernel build & install](kernel-build.md) — relinking `relocunix` and writing the boot partition.
- [Toolchain](toolchain.md) — the native SVR4 `cc`/GCC and cross-build notes.

## Sources
- Research brief [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §6 (`asokero/xrtg-amix` and `asokero/va2000-amix` repo facts) and §11 (X11 / RTG path).
- [`asokero/xrtg-amix`](https://github.com/asokero/xrtg-amix) — README and source tree (`ddx/amix/`, `ddx/amix/rtg/`, `ddx/amix/rtg/va2000/`, `config/amix.cf`); X11R5 / `imake` build; `BuildPex=NO`; `OpenScreen()` / `SIOCACTIVATE` input; TrueColor RGB565; MIT (new code) + X Consortium (X11R5) licensing.
- [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix) — README and source; `/dev/va2000` char major 68 minor 0; RTG screen type patched into `amiga/console/{scrdev.c,c0.c,screen.c}`; `relocunix` relink + `make bootpart`.
- amigaunix.com — historical X11 context cross-referenced in [X11 & the Desktop](../how-it-works/x11-and-desktop.md) (🟡 community-reported).
