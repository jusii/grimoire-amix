---
title: First Login & a Quick Tour
summary: Logging in, virtual consoles, shells, starting X, and finding your way around a fresh Amix system.
status: draft
---

# First Login & a Quick Tour

You've finished the [install walkthrough](install-walkthrough.md) and rebooted into `/unix` (or `relocunix`) off the SCSI hard disk. This page gets you from a blank `login:` prompt to a working shell, a second virtual console, and an X session, and points at where the interesting files live.

Amix is **AT&T System V Release 4 (SVR4)** ✅ — if you've used a SunOS-era SVR4 box it will feel familiar. The Amiga-specific surprises are the **virtual-console keys**, the **pre-POSIX `/bin/sh`**, and the two very different ways to start X (mono vs. A2410 color). Each is covered below.

> All console keys, paths, and shell behavior on this page assume **Amix 2.1 / 2.1p2a** (the last retail release plus the definitive patch). Earlier SVR3.x precursors differ and are out of scope.

## Logging in

At the console you get a standard SVR4 `login:` prompt. Log in as `root` for first-time setup.

```text
Amiga UNIX System V Release 4.0

login: root
Password:
```

- The **post-install root password is reported to be `wasp`** 🟡 (community-reported; this is the value seen on pre-built emulator disk images, not something the installer hard-codes). On a system you installed yourself, the password is whatever you set during the `amixadm` finish step at the end of the [install](install-walkthrough.md#finish-with-amixadm). Change it immediately with `passwd`.
- If `wasp` doesn't work and you didn't set a password, you're looking at a fresh install that expects you to set one during `amixadm`.

```sh
passwd          # change root's password right away
```

Once logged in as `root` you're in the default shell (**ksh** — see [Shells](#shells)). The prompt is `#`; a normal user gets `$`.

## Virtual consoles (Alt+F1 .. Alt+F8)

Amix gives you **eight virtual consoles**, switched with **Alt+F1 through Alt+F8** ✅. Each is an independent `getty`/`login` session on its own `tty`, so you can be logged in several times at once without networking or a window system.

| Key | Console |
|---|---|
| Alt+F1 | first virtual console (the one you boot into) |
| Alt+F2 .. Alt+F8 | additional virtual consoles |

This is the SVR4-standard multi-console feature wired to the Amiga keyboard. It's the quickest way to keep a root shell on one console while you work as a normal user on another, or to watch logs on one screen while editing on the next.

**Note:** the X server takes over the console it starts on; switch to another `Alt+F`n console to get back to a text login while X is running.

## Shells

The default login shell is the **Korn shell, `ksh`** ✅. Amix also ships **`sh`, `csh`, and `tcsh`** ✅, so you can change a user's shell with `chsh` 🟡 or by editing `/etc/passwd`.

```sh
echo $SHELL     # whatever your login shell is
ksh             # you are almost certainly already here as root
```

### The `/bin/sh` caveat — it is pre-POSIX

This is the single most important gotcha for anyone scripting on Amix. **Amix `/bin/sh` is a pre-POSIX Bourne shell** ✅. Modern shell idioms you take for granted **do not work**:

- **No `$(...)` command substitution.** Use backticks instead.
- **No `grep -q`.** Redirect to `/dev/null` and test `$?` instead.

```sh
# WRONG on Amix /bin/sh — modern POSIX idioms:
ver=$(uname -v)
if grep -q '^2\.1' /etc/foo; then ... ; fi

# RIGHT on Amix /bin/sh — pre-POSIX equivalents:
ver=`uname -v`
if grep '^2\.1' /etc/foo >/dev/null 2>&1; then ... ; fi
```

This bites driver builders constantly: the install scripts shipped with community drivers (for example the [VA2000 framebuffer driver](../drivers/case-studies/va2000.md)) were written specifically to avoid `$(...)` and `grep -q` ✅. If you're writing a script that the kernel build or a driver install will run under `/bin/sh`, stick to backticks and explicit redirection. When you want a modern shell interactively, use `ksh`.

> The patch-disk header script also predates POSIX: it is a `#!/sbin/sh` script and uses backticks and `uname -v` matching. See the [patch ADF anatomy](../boot-disks/anatomy-patch-adf.md) for the decoded script. ✅

## Starting X

Amix has **two completely different X paths** depending on your graphics hardware. Pick the one that matches your machine. For the full picture (window managers, OpenLook, keymap quirks, RTG alternatives) see [X11 and the desktop](../how-it-works/x11-and-desktop.md).

### Mono X (built-in graphics)

On a plain A3000UX / A2500UX with no graphics card, X runs against the **built-in mono framebuffer** and the window manager is **`tvtwm`** ✅ (a virtual-desktop twm variant). Community reports describe the mono server as **"slow as molasses"** 🟡 on a 25 MHz 68030 — usable, not snappy.

The default X release is **X11R4** 🟡 (amigaunix.com, the most authoritative community source, says R4 is the default; an X11R5 upgrade is available via the *Gateway! Vol.2* CD). Start a session the SVR4 way:

```sh
xinit           # brings up X with tvtwm on the built-in mono display 🟡
```

### A2410 color X (TIGA)

If you have the **A2410 "Lowell" color graphics card** (TMS34010, 1024×768) ✅, X runs through **TIGA** with a dedicated launcher:

```sh
olinit -- -tiga          # start X on the A2410 via TIGA
olinit -- -tiga -tm 3    # ... with an alternate TIGA mode (-tm 3) 🟡
```

The window manager in the color/OpenLook world is **`olwm` / `olwsm`** ✅, which needs the **Xol** fonts on the font path. (If you upgrade to X11R5 the font path breaks and you must re-add Xol with `xset fp+ .../Xol` ✅ — detail on the [X11 page](../how-it-works/x11-and-desktop.md).)

### A third option: RTG cards

A modern alternative to both is the **RTG path** — a community X11R5 server (`Xrtg`) running on a Zorro II framebuffer card such as the MNT VA2000. That's a development effort, not a stock-disk feature; see the [Xrtg case study](../drivers/case-studies/xrtg.md) and [VA2000 driver case study](../drivers/case-studies/va2000.md).

### X keymap quirks

Whichever path you take, the X keymap has known oddities ✅/🟡: **y and z are swapped**, and **`/` is produced by SHIFT-8**. `xload` crashes, and the X11R4 server leaks memory over long sessions. Keep these in mind before you assume the keyboard is broken. Details on the [X11 page](../how-it-works/x11-and-desktop.md) and the [quirks checklist](../how-it-works/quirks.md).

## Where things live

Amix is laid out like any SVR4 system, with a few Amix-specific spots worth knowing. These are the directories you'll reach for most.

| Path | What's there | Tag |
|---|---|---|
| `/usr/sys` | The **kernel source/object tree.** Compiled object libraries, per-driver subdirs, the `master.d/kernel.c` switch-table config file, and the makefiles you run to relink `/unix`. This is where all driver and kernel work happens. | ✅ |
| `/stand` | **Standalone / bootstrap area.** You copy a freshly built kernel (`relocunix`) here, then `make bootpart KERNEL=relocunix` writes it to the boot partition. | ✅ |
| `/var/sadm` | **SVR4 software-administration database** — the package install records used by `pkgadd`/`pkginfo`. `install/contents` is the master installed-object DB; `pkg/<PKG>/` holds each package's metadata. Standard SVR4 location; where the system tracks what's installed (see [package management](../how-it-works/package-management.md)). | ✅ |
| `/dev` | Device nodes (major/minor). E.g. `/dev/console` (char 0,0), `/dev/dsk/c0d0s1` (block 18), `/dev/par` (char 21), `/dev/fd0` (block 16). | ✅ |
| `/etc/inittab` | `init` run-level config — controls the virtual consoles' `getty` lines and run levels. | ✅ |
| `/unix` | The running kernel. **Always keep the old `/unix` as a fallback** before installing a rebuilt one. | ✅ |

A typical "where's the kernel work" orientation:

```sh
ls -l /unix                  # the running kernel
ls /usr/sys                  # driver subdirs + master.d/kernel.c
ls /usr/sys/master.d         # kernel.c lives here (switch tables)
ls /stand                    # staged bootable kernels (relocunix)
pkginfo                      # what's installed (reads /var/sadm)
```

> Naming note 🟡: the kernel image is called **`rdbunix`** in the 1990 Ditto paper but **`relocunix`** on 2.1/repo-era systems — a historical rename. On a 2.1p2a box you build, you'll see `relocunix`. See the [kernel build page](../drivers/kernel-build.md).

## A first look around

A few harmless commands to confirm the system is healthy and learn its identity:

```sh
uname -a            # should report System V Release 4.0, m68k
uname -v            # version string; on 2.1p2a it matches ^2.1.* 08004..$ ✅
df -k               # mounted filesystems (your UFS / and others)
who                 # who's logged in, on which tty/console
ps -ef              # SVR4-style full process list
```

- `uname -v` matching `^2\.1.* 08004..$` is exactly the test the patch disk runs before applying ✅ — if your string matches, you're on a patchable 2.1.
- The **system date is capped at 1999** by a kernel Y2K limitation; the patched `setclk` works around it ✅. Don't be surprised if naive date-setting refuses years ≥ 2000. See the [quirks checklist](../how-it-works/quirks.md).
- Man pages on 2.1 are **pre-formatted only** (the nroff sources were dropped) ✅ — `man` works, but you can't reformat.

When you're ready to do real work, the next stops are the [commands cheat-sheet](../reference/commands-cheatsheet.md) and, if you want to build kernels or drivers, the [driver model](../drivers/driver-model.md) and [kernel build](../drivers/kernel-build.md) pages.

## See also
- [Install walkthrough](install-walkthrough.md) — how you got here
- [X11 and the desktop](../how-it-works/x11-and-desktop.md) — full X11R4/R5, OpenLook, TIGA, RTG, keymap detail
- [Commands cheat-sheet](../reference/commands-cheatsheet.md) — the SVR4/Amix command quick reference
- [Quirks checklist](../how-it-works/quirks.md) — Y2K, keymap, `/bin/sh`, and other gotchas in one place
- [Glossary](../how-it-works/glossary.md) — SVR4 / Amix jargon

## Sources
- Master research brief, §4 (kernel architecture: virtual consoles Alt+F1..F8, `/usr/sys`, `/stand`, `kernel.c`), §8 (default login password "wasp" 🟡), §11 (default shell ksh, pre-POSIX `/bin/sh`; X11R4 default, `tvtwm` mono, A2410 TIGA `olinit -- -tiga`, OpenLook `olwm`/`olwsm`, keymap y/z + `/`=SHIFT-8), §12 (Y2K date cap, `/bin/sh` pre-POSIX), §3/§9 (`/stand`, `make bootpart KERNEL=relocunix`, `rdbunix`→`relocunix` rename), §5 (`/dev` major/minor examples)
- `asokero/va2000-amix` install-script gotcha (Amix `/bin/sh` has no `$(...)`, no `grep -q`) — https://github.com/asokero/va2000-amix (brief §6)
- `amix_21_patch.adf` analysis (`#!/sbin/sh` header, `uname -v` `^2\.1.* 08004..$` match) via `tools/inspect-adf.sh` (brief §10)
- amigaunix.com DokuWiki pages: x11, networking, tips-tricks, y2k-dst — https://www.amigaunix.com/doku.php/home
