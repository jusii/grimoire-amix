---
title: "Case Study: xrtg-amix"
summary: An X11R5 server (Xrtg) that drives the MNT VA2000 via the kernel framebuffer driver.
status: draft
---

# Case Study: xrtg-amix

[`asokero/xrtg-amix`](https://github.com/asokero/xrtg-amix) is an **X11R5 X server** for Amix — its server binary is `Xrtg` — that renders into the MNT **VA2000** retargetable-graphics (RTG) card through the kernel framebuffer device `/dev/va2000` ✅. It runs **TrueColor RGB565** at resolutions from 640×480 up to **1920×1080**, uses the card's hardware blitter for fills and copies, and draws a software cursor ✅. It targets Amix **2.1p2a** on an Amiga 3000 / 68030 / Zorro II, and it **requires the [`va2000-amix` framebuffer driver](va2000.md) to be in the kernel first** — `Xrtg` is a userspace consumer of `/dev/va2000`, not a driver itself ✅.

This page is the development-side companion to [X11 & the desktop](../../how-it-works/x11-and-desktop.md) (the user-facing X overview) and [X11 / RTG driver development](../x11-rtg-drivers.md) (the general DDX/RTG layering). The facts here are **uniformly ✅** (from the repo README/source, via [research brief §6](../../../sources/research-brief.md)) except where a tag says otherwise.

## What Xrtg is, in one sentence

`Xrtg` is a sample-server build of the X Consortium **X11R5** sources whose **device-dependent layer (DDX)** has been retargeted to write pixels into the Amix VA2000 framebuffer instead of a stock workstation frame buffer ✅. Everything below is the consequence of that one design choice: an R5 server, an Amix-specific DDX, and a hard dependency on the underlying char driver.

## At a glance

| Property | Value | Tag |
|---|---|---|
| Repo | [`github.com/asokero/xrtg-amix`](https://github.com/asokero/xrtg-amix) | ✅ |
| Server binary | `Xrtg` | ✅ |
| X release | **X11R5** (X Consortium sources) | ✅ |
| Visual class | **TrueColor**, pixel format **RGB565** (16-bit) | ✅ |
| Resolutions | 640×480 → **1920×1080** | ✅ |
| Acceleration | hardware **blitter** fills/copies; **software** cursor | ✅ |
| Underlying device | `/dev/va2000` (char **major 68 minor 0**) | ✅ |
| Hard dependency | [`va2000-amix` driver](va2000.md) installed in the kernel | ✅ |
| Build system | X11R5 **imake** + custom `config/amix.cf` | ✅ |
| Target platform | Amix **2.1p2a**, A3000 / 68030, Zorro II | ✅ |
| Distribution | **source-only** (links against a licensed Amix SVR4 env) | ✅ |
| License (new code) | **MIT** | ✅ |
| License (X11R5 portions) | original **X Consortium** terms | ✅ |

## Display capabilities

- **Color.** `Xrtg` exports a single **TrueColor** visual in **RGB565** — 5 bits red, 6 bits green, 5 bits blue, 16 bits per pixel ✅. This matches the VA2000 driver's 16-bit modes; the framebuffer driver itself advertises 800×600 / 1024×768 / 1280×720 @ 16-bit, while the X server's modeline range extends from 640×480 up to **1920×1080** ✅. (Reconcile the two ranges per your card configuration; the driver page documents the driver-side modes — see the [`va2000-amix` case study](va2000.md).)
- **Acceleration.** Fills and block copies (the CopyArea / fill-rectangle hot paths) are pushed to the VA2000's **hardware blitter** ✅. The mouse pointer is a **software cursor** — drawn by the server into the framebuffer, not a hardware sprite ✅.

## The DDX layering

`Xrtg` keeps the stock X11R5 device-independent core (DIX) and replaces only the **DDX** (device-dependent X) layer. The Amix DDX is itself split into a generic AMIX layer, an RTG abstraction, and a card-specific VA2000 backend, so the path from an X client down to a pixel is ✅:

```text
X clients
   │  (X protocol over the transport)
   ▼
Xrtg                         # X11R5 server: DIX + Amix DDX
   ▼
AMIX DDX        ddx/amix/        # Amix-specific device-dependent layer
   ▼
RTG layer       ddx/amix/rtg/    # retargetable-graphics abstraction
   ▼
VA2000 backend  ddx/amix/rtg/va2000/   # card-specific blitter + framebuffer access
   ▼
/dev/va2000     (char major 68 minor 0)   # the kernel framebuffer driver
```

The split mirrors the general RTG model described in [X11 / RTG driver development](../x11-rtg-drivers.md): the **RTG layer** is the seam where a *different* framebuffer card could be slotted in under the same DDX, while `ddx/amix/rtg/va2000/` is the only part that knows about the VA2000's registers, blitter, and 4 MB Zorro II window ✅.

## Input: the AMIX screen manager

Keyboard and mouse do **not** come up through the X server's usual hardware probing. Instead `Xrtg` talks to the **AMIX screen manager** — the same kernel-side console/screen mechanism the VA2000 driver registers an RTG screen type with ✅. The DDX:

- calls **`OpenScreen()`** to attach to a managed screen, and
- issues the **`SIOCACTIVATE`** ioctl to make that screen the active input target ✅.

This is why `Xrtg` depends on the VA2000 driver having patched the Amix console (`amiga/console/{scrdev.c,c0.c,screen.c}`) to register an RTG screen type — that patch is what gives the screen manager something for `OpenScreen()` to attach to. See the [`va2000-amix` case study](va2000.md) for the console-side patches and [The Amix device-driver model](../driver-model.md) for how the screen type fits the char-driver model.

## Building it: imake + amix.cf

`Xrtg` is built with the X11R5 **imake** configuration system, using a custom site-config file `config/amix.cf` that adapts the R5 build to the Amix SVR4 environment ✅. Two settings are load-bearing:

- **`BuildPex = NO`** — disables building **PEX** (the PHIGS 3-D extension), which is not wanted on Amix ✅.
- **SVR4 library rules** chosen to **avoid `ranlib` issues** — the SVR4 `ar`/library toolchain does not behave like the BSD one imake assumes, so the lib-build rules are overridden in `amix.cf` ✅.

The toolchain underneath is the native Amix compiler / a community-built GCC; for cross-building and the broader picture see [the toolchain page](../toolchain.md). Because the server links against a **licensed Amix SVR4** environment (its X11R5 libs, headers, and the `/dev/va2000` interface), the repo ships **source only** — you supply the Amix side ✅.

A typical imake-driven build follows the standard R5 shape (consult the repo README for the exact target names) ✅:

```sh
# In the xrtg-amix source tree, with config/amix.cf in the imake config path:
xmkmf -a          # generate Makefiles from the Imakefiles (uses amix.cf)
make World        # or the repo's documented build target
```

## Bringing it up

Once the [VA2000 driver](va2000.md) is in the kernel and the node exists, starting the server is ordinary X ✅:

```sh
# 1. Confirm the framebuffer device the server will open:
ls -l /dev/va2000          # expect: crw-...  68,  0

# 2. Start the RTG X server, then a window manager of your choice:
Xrtg &
olwm &                     # or twm, tvtwm, etc.
```

`Xrtg` is a drop-in `X`-protocol server, so any X11 window manager and client work over it. For the desktop side (OpenLook `olwm`/`olwsm`, the Xol font path, keyboard quirks) see [X11 & the desktop](../../how-it-works/x11-and-desktop.md).

## Why this stack instead of the historical X?

The original Amix color X path is the **A2410** "Lowell" TIGA board driven by `olinit -- -tiga`, and the mono path is "slow as molasses" 🟡 (see [X11 & the desktop](../../how-it-works/x11-and-desktop.md)). The `va2000` + `Xrtg` pair is the modern, reproducible alternative: a Zorro II RTG card, a single-file kernel driver, and a retargeted R5 server with blitter acceleration ✅. It is the project's centerpiece graphics example, alongside its sibling driver.

## Licensing

- **New code** written for `xrtg-amix` is **MIT-licensed** ✅.
- The **X11R5** portions retain their original **X Consortium** license terms ✅.
- The repository is **source-only** by necessity: building and running it requires a **licensed Amix SVR4** system (its X11R5 libraries/headers and the proprietary kernel interface to `/dev/va2000`) ✅. Do not expect a redistributable binary. See [AGENTS.md §5](../../../AGENTS.md) on the Amix licensing boundary — the Amix media and environment are proprietary Commodore material; obtain them via [amigaunix.com](https://www.amigaunix.com/doku.php/home) / [archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix).

## See also

- [`va2000-amix` case study](va2000.md) — the char framebuffer driver (`/dev/va2000`, char major 68) that `Xrtg` requires.
- [X11 / RTG driver development](../x11-rtg-drivers.md) — the general DDX → RTG → card layering this server is an instance of.
- [X11 & the desktop](../../how-it-works/x11-and-desktop.md) — the user-facing X overview, historical A2410/TIGA path, and OpenLook desktop.
- [The Amix device-driver model](../driver-model.md) — major/minor numbers, the char-driver model, and the screen type the screen manager uses.
- [The Amix toolchain](../toolchain.md) — native vs cross compilers for building Amix software.
- [`lszorro-amix` case study](lszorro.md) — userspace tool for inspecting the Zorro II board the VA2000 lives on.

## Sources

- [`sources/research-brief.md`](../../../sources/research-brief.md) §6 — `asokero/xrtg-amix`: `Xrtg` X11R5 server, TrueColor RGB565 640×480 → 1920×1080, hardware blitter fills/copies + software cursor, DDX layering (`ddx/amix/` → RTG → `ddx/amix/rtg/va2000/` → `/dev/va2000`), input via the AMIX screen manager (`OpenScreen()`, `SIOCACTIVATE`), imake build with `config/amix.cf` (`BuildPex=NO`, SVR4 lib rules avoiding ranlib issues), dependency on the va2000 driver, MIT + X Consortium licensing.
- [`sources/research-brief.md`](../../../sources/research-brief.md) §6 — `asokero/va2000-amix`: `/dev/va2000` char major 68 minor 0, 16-bit modes, console screen-type patches the screen manager relies on.
- [`asokero/xrtg-amix`](https://github.com/asokero/xrtg-amix) — the X11R5 `Xrtg` server source (DDX `ddx/amix/`, RTG layer, VA2000 backend, `config/amix.cf`).
- [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix) — the framebuffer driver the server sits on.
- [amigaunix.com — X11](https://www.amigaunix.com/doku.php/x11) — community reference for the historical X stack the RTG path replaces (🟡).
