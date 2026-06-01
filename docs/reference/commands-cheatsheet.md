---
title: Command Cheat Sheet
summary: The admin and developer commands you actually need on Amix, grouped for quick reference.
status: draft
---

# Command Cheat Sheet

This is a fast lookup of the commands that matter on Amiga Unix (Amix) 2.1: system
administration, package management, building/installing a kernel and drivers, networking,
clock handling, and getting data on and off the box. Each entry is a one-liner with a short
note and a confidence tag. Where a command is nuanced enough to need its own page, this sheet
links to the deep dive.

**Read this first:** Amix is **AT&T System V Release 4 (SVR4)** on the 68030 ✅, so most SVR4
admin conventions apply. But two SVR4-isms bite hard: the **`/bin/sh` is pre-POSIX** ✅ (no
`$(...)` command substitution, no `grep -q` — use backticks and `grep … >/dev/null`), and the
default shell is **ksh** ✅. Commands below assume you are `root` unless noted.

For terminology (major/minor numbers, STREAMS, `cdevsw`, RDB, etc.) see the
[glossary](../how-it-works/glossary.md). For every device node and its major/minor, see the
[device list](device-list.md). For what each version supports, see [versions](versions.md).

---

## System administration

| Command | What it does | Tag |
|---|---|---|
| `sysadm` | SVR4 menu-driven admin front-end (standard SVR4 tool) | ✅ |
| `amixadm` | Amix's post-install / admin tool — sets nodename, domain, timezone, date, root password, X11 | ✅ |
| `init <level>` | Switch run level (SVR4 `init` + `/etc/inittab`) | ✅ |
| `who -r` | Show the current run level | ✅ |
| `shutdown -i6 -g0 -y` | Reboot now (`-i6` = run level 6); use `-i0` to halt, `-iS` for single-user | ✅ |
| `telinit S` | Drop to single-user (maintenance) mode | ✅ |
| Alt+F1 .. Alt+F8 | Switch between the 8 virtual consoles | ✅ |

**Run levels (SVR4 standard) ✅.** Amix uses `init`, `/etc/inittab`, and SVR4 run levels.
`shutdown -i6` reboots; `-i0` powers down to the bootstrap; `S`/`s` is single-user. The
canonical "I changed the kernel, now reboot into it" step throughout these docs is:

```sh
shutdown -i6 -g0 -y
```

**Finishing an install ✅.** After the distribution is laid down and the kernel is built,
`amixadm` walks you through the final configuration: node name, NIS/DNS domain, timezone, the
date (**set the year to 1999 or earlier on unpatched systems — see [Time and the clock](#time-and-the-clock)**),
the root password, and X11 setup. This is reconstructed from the `root.adf` install scripts (brief §9).

> **Note on the default password 🟡.** Community reports a post-install login password of
> `wasp`. Treat as community lore, not a guarantee.

See [first login and tour](../getting-started/first-login-and-tour.md) for what to do right after
the install reboots.

---

## Packages (SVR4 `pkg*`)

Amix ships the standard SVR4 packaging toolchain ✅. A package is a `datastream` or directory
of files plus a `pkginfo`/`pkgmap`; you build with `pkgmk`/`pkgtrans` and install with `pkgadd`.

| Command | What it does | Tag |
|---|---|---|
| `pkginfo` | List installed packages | ✅ |
| `pkgadd -d <device|file> [pkg]` | Install a package from a device or datastream file | ✅ |
| `pkgrm <pkg>` | Remove an installed package | ✅ |
| `pkgproto <paths> > Prototype` | Generate a prototype file from a file tree | ✅ |
| `pkgmk -o -d <dir>` | Build a package (directory format) from a `Prototype` | ✅ |
| `pkgtrans <src> <dest.pkg> <pkg>` | Convert a directory package to a single datastream file | ✅ |
| `amixpkg -i -m -d <dev> -r /mnt -y standard` | Amix install-time package wrapper (used by the installer) | 🟡 |

**Gotchas.**
- `pkgproto` **omits symbolic links** from the prototype 🟡 — add them back by hand or your
  package will be missing files.
- The `amixpkg` wrapper is **widely reported broken** for general use 🟡, even though the
  `root.adf` installer drives the whole distribution install through it
  (`amixpkg -i -m -d … -r /mnt -y standard`) ✅. Prefer the raw `pkgadd`/`pkgmk` path for your
  own packages.

**Pre-built packages 🟡.** Michael Parson's **AmixBP** is 40+ re-bundled `.pkg` files hosted on
[amigaunix.com/downloads](https://www.amigaunix.com/doku.php/downloads). An alternative
distribution form seen in the wild is a `zoo`-compressed `cpio` archive 🟡.

---

## Kernel and driver builds

Amix is a **monolithic SVR4 kernel with no loadable modules** ✅ — drivers are statically linked
in, so adding or changing a driver means **relinking the kernel and rebooting**. The kernel
source/objects live in **`/usr/sys`** ✅; the switch tables live in **`master.d/kernel.c`** ✅.

| Command | What it does | Tag |
|---|---|---|
| `cd /usr/sys` | Kernel build root (object libraries + makefiles) | ✅ |
| `make` | Relink the kernel from the configured `cdevsw[]`/`bdevsw[]` tables | ✅ |
| `make install` | Build/stage the new kernel image (`relocunix`) | ✅ |
| `cp relocunix /stand` | Copy the new kernel to `/stand` before writing the boot partition | ✅ |
| `make bootpart KERNEL=relocunix` | Write the kernel to the 2 MB boot partition | ✅ |
| `mknod /dev/<name> c <major> <minor>` | Create a **character** device node | ✅ |
| `mknod /dev/<name> b <major> <minor>` | Create a **block** device node | ✅ |

**The full driver install loop (Ditto paper procedure + va2000 repo refinements ✅):**

```sh
# 1. drop driver .o (and source) into a subdir under /usr/sys, add it to that Makefile
# 2. edit master.d/kernel.c: add cdevsw[]/bdevsw[] slot, int2_tbl[]/init_tbl[] entries, extern decls
cd /usr/sys
make                              # produces the new kernel
make install                      # stage as relocunix
cp relocunix /stand
make bootpart KERNEL=relocunix    # write the boot partition
mknod /dev/mydev c 68 0           # create the node (char major 68, minor 0 — example)
shutdown -i6 -g0 -y               # reboot into the new kernel
```

**Kernel-image name 🟡.** The 1990 Ditto paper calls the built kernel **`rdbunix`**; modern 2.1
systems and the community repos call it **`relocunix`** — treat this as a historical rename and
verify per version (brief §13.3). Some repos also expose `make oldboot KERNEL=…` as the
boot-floppy/legacy variant ✅.

**Before relinking, clean stale objects ✅** (from the va2000 driver notes) or the link picks up
old code:

```sh
rm -f amiga/config/unix.o master.d/exp unix
```

**Always keep the old `/unix` as a fallback ✅** — if the new kernel panics, you can boot the
previous one.

Deep dives: [the kernel build process](../drivers/kernel-build.md), the
[driver model](../drivers/driver-model.md), [writing a char driver](../drivers/writing-a-char-driver.md),
and [writing a STREAMS driver](../drivers/writing-a-streams-driver.md).

---

## Networking

Amix networking is **SVR4 STREAMS TCP/IP** ✅. The A2065 Ethernet interface is **`aen0`** ✅.
There is **no DHCP — static IP only** ✅, and **DNS resolution is off by default** ✅ (the system
resolves names from `/etc/hosts` until you switch it on).

| Command | What it does | Tag |
|---|---|---|
| `ifconfig aen0` | Show the A2065 Ethernet interface state | ✅ |
| `ifconfig aen0 <ip> netmask <mask> up` | Bring the interface up with a static address | ✅ |
| `ifconfig hya0 plumb` | Plumb the Hydra STREAMS NIC (lazy-init driver) | ✅ |
| `route add default <gw> 1` | Add a default route — **the trailing `1` (metric/hops) is required** | ✅ |
| `netstat -rn` | Show the routing table | ✅ |

**Default route — don't drop the metric ✅:**

```sh
route add default 192.168.0.1 1
```

The trailing `1` is the hop count/metric and is mandatory on this SVR4 `route`.

**Enabling DNS ✅** (off by default — the system uses `/etc/hosts`). The steps are:

```sh
# 1. point libsocket at the DNS-capable resolver shared library
ln -f /usr/lib/libsockdns.so /usr/lib/libsocket.so
# 2. edit /etc/netconfig so name lookups use DNS
# 3. start the name server / resolver: in.named
# 4. create /etc/resolv.conf with your nameserver(s)
```

After this, hostname lookups go through DNS instead of `/etc/hosts`.

**Other networking facts.**
- **NFS** server and client both work ✅.
- **SLIP** is buggy — you must **reboot between sessions** 🟡.
- **No PPP** 🟡.
- The Hydra NIC is a STREAMS/DLPI driver registered at `cdevsw` slot 47 (`hya`) ✅; see the
  [Hydra case study](../drivers/case-studies/hydra.md).

Deep dive: [networking](../how-it-works/networking.md). For the interface device nodes, see the
[device list](device-list.md).

---

## Time and the clock

| Command | What it does | Tag |
|---|---|---|
| `setclk` | Read/write the hardware (battery-backed) clock | ✅ |
| `date` | Show/set the system time (set via `amixadm` at install) | ✅ |

**Y2K warning ✅.** Unpatched Amix has a Y2K problem on two fronts:
- `setclk` has a **`%02d` year-formatting bug** ✅, and
- the **kernel caps the date at 1999** ✅.

So on an unpatched system, set the install date to **1999 or earlier** ✅. The community fix is
the **patch disk** (raising the system to 2.1p2a / kernel 2.1c), which ships a **Y2K-corrected
`setclk`** ✅. After applying the patch, run the patched `setclk` to set a correct post-1999 date.

See the [quirks page](../how-it-works/quirks.md) for the clock-drift and Y2K details, and the
[patch disk anatomy](../boot-disks/anatomy-patch-adf.md) for how the patch is applied.

---

## Media: tape, raw devices, and identifying the system

The distribution is streamed from **QIC tape at SCSI ID 4** ✅ — the tape device is hard-coded.
The raw, no-rewind tape node is **`/dev/rmt/4hn`** ✅ (the `n` = no rewind on close; `4h` = unit 4,
high density). The hard disk is fixed at **SCSI ID 6** ✅.

| Command | What it does | Tag |
|---|---|---|
| `uname -svrm` | Print system name, OS version, release, and machine (`m68k`) | ✅ |
| `uname -a` | Full identification line | ✅ |
| `dd if=/dev/rmt/4hn bs=256k \| cpio -imdcu` | Read the distribution from tape and extract it | ✅ |
| `dd if=/dev/rmt/4hn bs=256k \| zcat \| cpio -imdcu` | Same, for a compress(1)-compressed tape stream | ✅ |
| `cpio -icdmuv` | Extract an ASCII (`-c`) cpio archive, making dirs, preserving mtime | ✅ |

**The install-tape pipeline ✅** (from the `root.adf` scripts) reads the no-rewind raw tape and
pipes it through `cpio`:

```sh
dd if=/dev/rmt/4hn bs=256k | cpio -imdcu
# compressed variant:
dd if=/dev/rmt/4hn bs=256k | zcat | cpio -imdcu
```

`cpio` flags used here: `-i` extract, `-m` retain modification times, `-d` create directories as
needed, `-c` ASCII header format, `-u` overwrite unconditionally.

**Identifying the running system ✅.** The patch disk's own header script greps `uname -v` for the
pattern `^2\.1.* 08004..$` before it will apply ✅, so `uname` is the canonical way to check what
you're on:

```sh
uname -svrm     # e.g. m68k release/version fields used by the patch's uname -v check
```

**Non-standard tape drives 🟡/✅.** The kernel only supports specific tapes (A3070 QIC-150 and
similar). `viper_kludge` (Frank "Crash" Edwards), shipped on `root.adf` ✅, patches kernel memory
so an **Archive Viper 2150S** works — but its README **warns it is incompatible with
A3070/Caliper/Wangtek/Sankyo** drives ✅. **Tape-free installs** (write a `cpio` image to the swap
partition from Linux/AmigaDOS, then extract with `cpio`) are documented on comp.unix.amiga 🟡.

For the SCSI ID rules and other hard-coded limits, see the
[hardware page](../how-it-works/hardware.md) and the [quirks checklist](../how-it-works/quirks.md).
For the install in full, see the [install walkthrough](../getting-started/install-walkthrough.md).

---

## See also
- [Device list](device-list.md) — every `/dev` node with its major/minor number.
- [Versions](versions.md) — which release supports what; the `2.1c` / "2.2" caveats.
- [How Amix boots](../how-it-works/boot-process.md) — Superkickstart → bootstrap → kernel.
- [Kernel build](../drivers/kernel-build.md) and the [driver model](../drivers/driver-model.md).
- [Install walkthrough](../getting-started/install-walkthrough.md) and
  [first login and tour](../getting-started/first-login-and-tour.md).
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — end-user, install-media, and
  historical material (we cross-link rather than duplicate it).

## Sources
- `sources/research-brief.md` §3 (boot/kernel build, `make bootpart KERNEL=relocunix`), §4
  (run levels, virtual consoles, `pkg*`/`amixpkg`, monolithic kernel), §5 (device-driver model,
  `mknod`, major/minor, `/usr/sys`, `kernel.c`), §7 (toolchain & packaging, `pkgproto` symlink
  gotcha, AmixBP), §9 (install flow, tape `dd … | cpio` pipeline, `amixadm` finish, `viper_kludge`),
  §11 (networking: `aen0`, `route add default … 1`, DNS-enable steps, NFS/SLIP/PPP; userland shells
  and pre-POSIX `/bin/sh`), §12 (quirks: SCSI IDs, Y2K/`setclk`, DNS off by default), §13
  (`rdbunix`/`relocunix` rename caveat).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — `/dev/rmt/4hn`, `amixpkg -i -m -d -r /mnt -y standard`,
  `viper.README`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` (SCSI ID hard-coding).
- `amix_21_patch.adf` analysis via `tools/inspect-adf.sh` — `uname -v` match `^2\.1.* 08004..$`,
  Y2K-fixed `setclk`, patch-apply mechanism.
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — driver install
  procedure (`/usr/sys` → `make` → `mknod` → reboot), `cdevsw`/`bdevsw`, `rdbunix`.
- `asokero/va2000-amix` repo — `rm -f amiga/config/unix.o master.d/exp unix`, `cp relocunix /stand`,
  `make bootpart KERNEL=relocunix`, `mknod /dev/va2000 c 68 0`, pre-POSIX `/bin/sh` note.
- `isoriano1968/hydra-amix` repo — `ifconfig hya0 plumb`, `make oldboot KERNEL=…`, STREAMS `cdevsw` slot 47.
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — networking, patch-disk, y2k-dst, tape-creation, downloads pages (community-reported items above).
