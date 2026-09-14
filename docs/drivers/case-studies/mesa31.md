---
title: "Case Study: mesa-amix (Mesa 3.1)"
summary: OpenGL on Amix — a Mesa 3.1 software-rendering bootstrap using the Xlib driver against the Xzz9000 X11R6.3 server; static libGL/GLU/glut first, no server-side GLX.
status: draft
---

# Case Study: mesa-amix (Mesa 3.1)

[`isoriano1968/mesa-amix`](https://github.com/isoriano1968/mesa-amix) is a **Mesa 3.1
software-rendering port bootstrap** for Amix, published 2026-07-03 alongside the
[X11R6.3 port](x11r63-zz9000.md) it depends on ✅. The design goal is deliberately modest: get
OpenGL rendering on Amix via **Mesa's Xlib software driver**, which renders client-side and ships
pixels over the X protocol — so it needs **no server-side GLX extension and no ZZ9000 3D
acceleration** ✅. Facts are ✅ from the repo at `78fe054` (brief §21); this is the *bootstrap*
stage — the static libraries and demos are the first milestone, not a finished GL stack.

## At a glance

| Property | Value | Tag |
|---|---|---|
| Repo | [`github.com/isoriano1968/mesa-amix`](https://github.com/isoriano1968/mesa-amix) | ✅ |
| Mesa version | **3.1** (`MesaLib-3.1` + `MesaDemos-3.1` from the official Mesa archive) | ✅ |
| Rendering | **Xlib software driver** — client-side; no GLX server extension needed | ✅ |
| Display target | [`Xzz9000`](x11r63-zz9000.md) (16-bit TrueColor), headers/libs from `/usr/x11r6` | ✅ |
| Compiler | GCC 2.7.2.3; `-O -ansi -finline-functions -DAMIX -Dm68k -DSVR4` | ✅ |
| First milestone | **static** `libGL.a` / `libGLU.a` / `libglut.a` + `xdemos`; then selected GLUT demos (`gears`, `bounce`, `glutmech`) before any shared-library work | ✅ |
| Excluded (for now) | MIT-SHM, threads, CPU assembly, DRI, server-side GLX, ZZ9000 HW accel, shared libs | ✅ |
| Distribution | overlay-only: `install.sh` fetches + SHA-256-verifies pristine Mesa 3.1 | ✅ |
| License | Mesa's own terms (upstream) · MIT (new material) · **GLUT 3.7** (`demos/GLUT-3.7-NOTICE`, for the vendored `glutmech.c`) | ✅ |

## The interesting part: Mesa 3.1 already knew about Amix

Upstream Mesa 3.1 — a 1999 release — **already contains a historical AMIX build target** ✅. The port
keeps that target name but replaces the upstream multi-platform `Make-config` **wholesale** with an
Amix-only version (`config/Make-config.amix`), because of a genuinely Amix-shaped problem: the old
Amix `make` **parses every rule in an included file**, and upstream's `Make-config` contains
malformed backslash continuations in *unrelated* platform targets that make it fail outright ✅.
Deleting the other platforms, not fixing them, is the practical cure.

The Amix target boils down to ✅:

```make
amix:
	$(MAKE) $(MFLAGS) -f Makefile.X11 targets \
	"GL_LIB = libGL.a"  "GLU_LIB = libGLU.a"  "GLUT_LIB = libglut.a" \
	"CC = gcc" \
	"CFLAGS = -O -ansi -finline-functions -DAMIX -Dm68k -DSVR4 \
		-I/usr/x11r6/xc/exports/include -I/usr/x11r6/include" \
	"XLIBS = -L/usr/x11r6/xc/exports/lib -L/usr/x11r6/lib \
		-lXmu -z nodefs -lXext -lX11 -lsocket -lnsl -lm"
```

## Preparing and building

Same overlay pattern as the sibling repos ✅ — the repo holds only the Amix delta; `install.sh`
downloads `MesaLib-3.1.tar.gz` + `MesaDemos-3.1.tar.gz` from the
[official Mesa archive](https://archive.mesa3d.org/older-versions/3.x/), verifies SHA-256 against
`SOURCES.sha256`, extracts, swaps in `Make-config.amix`, and adds `amix-build.sh`:

```sh
git clone https://github.com/isoriano1968/mesa-amix.git
cd mesa-amix
sh install.sh /export/amix/mesa3
# copy or mount /export/amix/mesa3/Mesa-3.1 as /usr/mesa3/Mesa-3.1 on Amix
```

On Amix, **static first** ✅:

```sh
cd /usr/mesa3/Mesa-3.1
sh amix-build.sh libs      # src → libGL.a (Xlib driver), src-glu → libGLU.a, src-glut → libglut.a
sh amix-build.sh xdemos    # minimal visual test clients

# run a demo against the ZZ9000 server:
DISPLAY=:1
LD_LIBRARY_PATH=/usr/x11r6/xc/exports/lib:/usr/lib
export DISPLAY LD_LIBRARY_PATH
```

Native Amix **shared** Mesa libraries (the [`ld -G -h` / `.sa` ABI](x11r63-zz9000.md#the-amix-shared-library-abi))
come only *after* the static renderer and demos are proven ✅ — the same
prove-the-simple-path-first discipline as the rest of the stack.

## Ownership split with the X11R6.3 repo

Stated explicitly in `PORTING.md` ✅: the **X11R6.3 repo owns any future server-side GLX extension**;
the Mesa repo owns the renderer, the GL/GLU/GLUT libraries, the demos, and the client-side
GLX/Xlib integration. Mesa's tree is deliberately independent of the `xc` tree
(`/usr/mesa3/Mesa-3.1` vs `/usr/x11r6`) ✅.

## State as of 2026-09-14 (HEAD `1065dcc`, 5 commits)

Three commits after the one this page was written from (`78fe054`) ✅: `b394471` adds `gears.c` and
starts its idle loop reliably on Amix; `430b174` adds GLUT demo targets (`amix-build.sh mech`) and
vendors **`glutmech.c` from GLUT 3.7** into `overlay/Mesa-3.1/demos/` with its own
`GLUT-3.7-NOTICE` — a third upstream project beside Mesa and the port's MIT material; `1065dcc` adds
`bounce.c` and its idle loop. `PORTING.md`'s sequence gained a step 5, *build selected GLUT demos*,
pushing shared libraries to step 6 ✅. The `XLIBS` line above now also carries `-lXmu -z nodefs
-lXext` ✅. No binary release or tag exists; the build is native (GCC 2.7.2.3) against X11R6.3 headers
and libraries under `/usr/x11r6` ✅. The README's *Layout* section still names the author's Windows
build-host paths — read it as a personal layout, not a convention ✅.

## See also

- [Case study: x11r6.3-amix (`Xzz9000`)](x11r63-zz9000.md) — the X server this renders to (and the shared-library ABI shared libs will need).
- [Case study: zz9000-amix](zz9000.md) — the kernel framebuffer driver at the bottom of the stack.
- [Toolchain](../toolchain.md) — GCC 2.7.2.3 and the Amix `make`/`cpp` quirks that shaped `Make-config.amix`.
- [X11 / RTG driver development](../x11-rtg-drivers.md) — where the display stack this GL rides on is explained.

## Sources

- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §21 — `isoriano1968/mesa-amix` @ `78fe054` (2026-07-03).
- [`isoriano1968/mesa-amix`](https://github.com/isoriano1968/mesa-amix) — `README.md`, `PORTING.md`, `install.sh` + `SOURCES.sha256`, `config/Make-config.amix`, `overlay/Mesa-3.1/amix-build.sh`.
- [Mesa 3.x archive](https://archive.mesa3d.org/older-versions/3.x/) — the pristine upstream sources `install.sh` fetches.
