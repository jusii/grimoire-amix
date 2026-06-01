---
title: X11 & the Desktop
summary: X11R4/R5, OpenLook, the A2410 TIGA color path, the keyboard/server quirks, and the modern RTG alternative.
status: draft
---

# X11 & the Desktop

Amix ships a stock **X Window System** as its GUI: by default **X11R4** 🟡, optionally upgraded to **X11R5** via the *Gateway! Vol.2* CD 🟡. The default window environment is **OpenLook** (`olwm`/`olwsm`); on a machine with only the built-in mono display you typically run the lighter **`tvtwm`** instead 🟡. Color X requires an **A2410** graphics board, driven through a **TIGA** server started with `olinit -- -tiga` 🟡. The historical X stack is notoriously slow and buggy ("slow as molasses" on the mono path 🟡), so the modern reproduction route is a **retargetable-graphics (RTG)** server (`Xrtg`) on top of a framebuffer driver such as the MNT [VA2000](../drivers/case-studies/va2000.md) ✅.

This page covers the historical X11 environment, how to bring up color on the A2410, the OpenLook desktop and its font-path gotcha, the well-known X quirks, and the modern RTG alternative. For driver-level detail on building an X server, see [X11 / RTG drivers](../drivers/x11-rtg-drivers.md) and the [`xrtg-amix` case study](../drivers/case-studies/xrtg.md).

> **Confidence note.** The X11 facts here are a mix of ✅ (repo source for the RTG path) and 🟡 (amigaunix.com / forum lore for the historical R4/R5, TIGA and quirk material). The "default is R4 vs R5" question is itself a documented conflict — see [Which version of X?](#which-version-of-x) below.

## The X stack at a glance

| Layer | Historical Amix | Modern RTG reproduction |
|---|---|---|
| X server | `X` (mono) / `olinit -- -tiga` color via A2410 TIGA 🟡 | `Xrtg` (X11R5 DDX) ✅ |
| Display HW | Built-in mono framebuffer; **A2410** "Lowell" TMS34010, 1024×768 color ✅ | Zorro II RTG card, e.g. MNT VA2000 ✅ |
| Window manager | OpenLook `olwm` + `olwsm`; `tvtwm` on mono 🟡 | any (`olwm`, `twm`, …) |
| X release | X11R4 default 🟡; X11R5 via *Gateway! Vol.2* 🟡 | X11R5 (the `Xrtg` server is R5) ✅ |
| Fonts | needs the **Xol** OpenLook font set 🟡 | inherited from the X11R5 build |

## Which version of X?

- The shipped X is **X11R4** by default 🟡. amigaunix.com — the most authoritative community source — reports R4 as the default, and this is the value we carry. See the open conflict noted in `sources/research-brief.md` §13.7.
- You can upgrade to **X11R5** using the **Gateway! Vol.2** CD 🟡, which also bundles additional graphics-board drivers (Picasso II, Piccolo, Domino, etc., Zorro II / linear modes only) 🟡.
- 🔴 The "R4 vs R5 default" claim conflicts between sources. Do not state R5 as the shipped default; treat R4 as default and R5 as the documented upgrade until a primary source settles it.

**Warning:** the R5 upgrade changes the font search path and **breaks OpenLook's font lookup** — you must re-add the Xol path by hand (see [The Xol font-path fix](#the-xol-font-path-fix)) 🟡.

## Mono display: `tvtwm`

On a machine with no A2410 — i.e. only the Amiga's built-in framebuffer driving a monochrome X server — the practical window manager is **`tvtwm`** (the virtual-desktop variant of `twm`) 🟡. The mono server is functional but slow; early releases (1.1) were described as "slow as molasses" 🟡. There is no color and no acceleration on this path.

```sh
# Mono path: start X, then a lightweight WM.
# (xinit/startx will read your ~/.xinitrc; tvtwm is the typical choice.)
tvtwm &
```

## Color on the A2410 (TIGA)

Color X on real Amix hardware means the **A2410** "Lowell" graphics board: a **TMS34010** TIGA coprocessor at **1024×768** ✅. The X server talks to it through TIGA, and you bring it up with `olinit` passing server arguments after the `--` separator 🟡:

```sh
# Start the OpenLook session on the A2410 via the TIGA server:
olinit -- -tiga

# Some setups also pass a TIGA mode selector, e.g. mode 3:
olinit -- -tiga -tm 3
```

- `-tiga` selects the A2410/TIGA server backend 🟡.
- `-tm 3` is a TIGA mode argument (graphics mode/timing selector) seen in community configs 🟡; the exact mode-number meaning is not primary-verified, so treat the specific value as community lore.
- The A2410 is **Zorro II** and uses the standard Amiga AUTOCONFIG discovery the kernel reads via `autocon()` 🟡 — see [Hardware](hardware.md) and [Zorro AUTOCONFIG](../drivers/zorro-autoconfig.md). Amix cannot use **Zorro III** boards at all ✅, so any color graphics option must be a Zorro II / linear-mode card.

## The OpenLook desktop: `olwm` / `olwsm`

The default desktop environment is **OpenLook** 🟡, Sun's pre-CDE look-and-feel:

- **`olwm`** — the OpenLook Window Manager (window decoration, menus, focus).
- **`olwsm`** — the OpenLook Workspace Manager (the root-window workspace menu / session management).
- OpenLook needs its bitmap font set, conventionally installed under an **`.../Xol`** directory in the X font path 🟡. Without it, `olwm`/`olwsm` fail to find their UI fonts.

```sh
# A typical OpenLook session brings up both managers:
olwsm &
olwm &
```

### The Xol font-path fix

When you upgrade to **X11R5** (via Gateway! Vol.2), the new server's default font path no longer includes the OpenLook **Xol** fonts, so OpenLook can't start cleanly 🟡. Re-add the Xol directory to the running server's font path:

```sh
# Append the OpenLook (Xol) font directory to the X server font path.
# Substitute the real install path of the Xol fonts on your system.
xset fp+ /usr/lib/X11/fonts/Xol
xset fp rehash
```

**Note:** the exact filesystem location of the Xol fonts depends on the release/install; the `fp+` mechanism (append a directory) and the need to do it after the R5 upgrade are the load-bearing facts 🟡.

## Known X11 quirks

The historical X stack has several well-documented annoyances. These are 🟡 (amigaunix.com / forum / Usenet reports) and are also collected on the [quirks checklist](quirks.md):

- **Keyboard `y`/`z` swapped** 🟡 — the X keymap maps the Amiga keyboard such that `y` and `z` come out transposed (a German/US layout artifact). Fix with a corrected `xmodmap` keymap.
- **`/` requires SHIFT-8** 🟡 — the forward-slash isn't where the X keymap expects it; it lands on `SHIFT-8`. Also an `xmodmap` fix.
- **`xload` crashes** 🟡 — the stock system-load monitor client is unstable on Amix; avoid it.
- **X11R4 memory leaks** 🟡 — the default R4 server/clients leak memory over a long session; restarting X periodically is the practical workaround. (One more reason the R5 upgrade or the modern RTG server is preferable.)

Because these are keymap/server-level issues, the cleanest mitigation for the keyboard ones is a saved `xmodmap` file sourced from your `~/.xinitrc`:

```sh
# Example skeleton — load a corrected keymap at session start.
# Put the real keysym lines for y/z and slash in ~/.Xmodmap.
xmodmap ~/.Xmodmap
```

## The modern alternative: RTG via `Xrtg` + a framebuffer driver

Rather than fight the A2410 TIGA path or the mono server, the modern hobby route is **retargetable graphics**: a character framebuffer driver plus an X11R5 server (`Xrtg`) that renders to it ✅. This is the project's centerpiece example and is fully reproducible against Amix 2.1p2a on an A3000 / 68030 / Zorro II ✅.

The two-piece stack:

1. **`va2000`** — a char framebuffer driver for the MNT **VA2000** RTG card. Device `/dev/va2000`, **char major 68 minor 0**; modes 800×600 / 1024×768 / 1280×720 @ 16-bit ✅. See the [VA2000 case study](../drivers/case-studies/va2000.md).
2. **`Xrtg`** — an **X11R5** X server (DDX) layered over that driver: TrueColor RGB565, 640×480 up to 1920×1080, with hardware blitter fills/copies and a software cursor ✅. See the [xrtg-amix case study](../drivers/case-studies/xrtg.md).

The `Xrtg` DDX path is: `X clients → Xrtg → AMIX DDX (ddx/amix/) → RTG layer → VA2000 (ddx/amix/rtg/va2000/) → /dev/va2000` ✅. Input is wired through the AMIX screen manager (`OpenScreen()`, `SIOCACTIVATE`) ✅.

```sh
# Modern RTG path (after the va2000 driver is in the kernel and /dev/va2000 exists):
#   1. Confirm the framebuffer device node:
ls -l /dev/va2000          # expect: crw-...  68,  0
#   2. Start the RTG X server, then your window manager of choice:
Xrtg &
olwm &
```

- Build details (X11R5 `imake` with a custom `config/amix.cf`, `BuildPex=NO`, SVR4 lib rules to avoid `ranlib` issues) live in the [xrtg case study](../drivers/case-studies/xrtg.md) ✅.
- Getting the VA2000 driver into the kernel (the 6 patched kernel files, `mknod /dev/va2000 c 68 0`, `make install` → `relocunix`, `make bootpart KERNEL=relocunix`, reboot) is covered in the [VA2000 case study](../drivers/case-studies/va2000.md) and [kernel build](../drivers/kernel-build.md) ✅.
- **Licensing:** the new code is MIT-licensed; the X11R5 portions retain X Consortium terms; both repos are **source-only** because they link against a licensed Amix SVR4 environment ✅.

## See also

- [X11 / RTG driver development](../drivers/x11-rtg-drivers.md) — how the DDX/RTG layers fit together.
- [`xrtg-amix` case study](../drivers/case-studies/xrtg.md) — the X11R5 `Xrtg` server in detail.
- [`va2000-amix` case study](../drivers/case-studies/va2000.md) — the framebuffer driver `Xrtg` sits on.
- [Quirks checklist](quirks.md) — the full list of Amix gotchas, including the X keymap issues.
- [Hardware](hardware.md) — the A2410 board and Zorro II constraints.
- [Networking](networking.md) — the other big SVR4 subsystem (STREAMS TCP/IP, NFS).
- [First login and tour](../getting-started/first-login-and-tour.md) — bringing up a session after install.
- [amigaunix.com X11 page](https://www.amigaunix.com/doku.php/x11) — the upstream community reference for the historical X setup.

## Sources

- `sources/research-brief.md` §11 (Networking, X11, userland — condensed), §2 (Hardware: A2410 "Lowell" TMS34010 1024×768; Zorro II only; Gateway! Vol.2 drivers), §12 (Quirks checklist), §13.7 (R4-vs-R5 default conflict).
- `sources/research-brief.md` §6 — `asokero/xrtg-amix` and `asokero/va2000-amix` repo facts (Xrtg DDX layering, RGB565/resolutions, `/dev/va2000` char major 68, imake/amix.cf build, MIT + X Consortium licensing).
- [`asokero/xrtg-amix`](https://github.com/asokero/xrtg-amix) — X11R5 `Xrtg` server source (DDX `ddx/amix/`, RTG layer).
- [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix) — VA2000 framebuffer driver source.
- [amigaunix.com — X11](https://www.amigaunix.com/doku.php/x11) — community-reported R4/R5, TIGA, OpenLook, and keymap quirks (🟡).
