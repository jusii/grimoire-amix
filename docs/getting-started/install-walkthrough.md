---
title: Installing Amix (Emulation-First Walkthrough)
summary: End-to-end install of Amix 2.1 — boot/root floppies, the UFS miniroot, RDB partitioning, streaming the distribution from a SCSI tape, building and writing the boot partition, first boot, and applying the patch disk to reach 2.1c (with Y2K fix).
status: draft
---

# Installing Amix (Emulation-First Walkthrough)

This page walks the **complete Amix 2.1 install**, from the two install floppies through partitioning,
streaming the distribution off a SCSI tape, building the kernel into the boot partition, first boot,
and finally applying the patch disk to reach kernel **2.1c (2.1p2a)**. The flow below is reconstructed
from the actual scripts on the install floppies ✅ — every step maps to something the installer really does.

**Before you start:** stand up an emulator first. This page assumes a working virtual A3000 with the
correct CPU/MMU/FPU and two SCSI targets (a disk on ID 6, a tape on ID 4). Set that up with the
[WinUAE setup guide](emulation-winuae.md) (the reference target) or the
[FS-UAE setup guide](emulation-fs-uae.md), or [Amiberry 8.x](emulation-amiberry.md) — which also emulates
the A3000 SCSI disk + tape Amix needs. There is no working QEMU recipe 🟡. For period-correct **real hardware** instead of emulation,
see [installing on real hardware](real-hardware.md).

> **Licensing:** the boot/root/patch floppies and the distribution are proprietary Commodore material
> (abandonware, not licensed for redistribution). This guide never asks you to commit or share them.
> Obtain the images yourself from [amigaunix.com](https://www.amigaunix.com/doku.php/home) /
> archive.org. Verify them against `sources/CHECKSUMS.txt` before use.

## The three floppies and what each does

Amix 2.1 installs from three 880 KB Amiga floppy images. Their internals are documented in detail on
the [boot disk anatomy](../boot-disks/anatomy-boot-adf.md),
[root disk anatomy](../boot-disks/anatomy-root-adf.md), and
[patch disk anatomy](../boot-disks/anatomy-patch-adf.md) pages; the short version:

| Floppy | Role | Contents (✅) |
|---|---|---|
| `amix_21_boot.adf` | Bootstrap | AmigaDOS OFS bootblock (`DOS\0` + checksum + 68k bootstrap) → loads and **decompresses a checksummed install kernel**. No AmigaDOS filesystem on the disk. |
| `amix_21_root.adf` | Miniroot | A **UFS miniroot** image: the installer ELF binaries (cpio, fsck, dd, amixpkg, …), the `/bin/sh` install scripts, and `viper.README`. |
| `amix_21_patch.adf` | Patch | Self-extracting "Patch Disks 1 & 2" → brings 2.1 up to **2.1p2a / kernel 2.1c**. |

The distribution itself (the actual OS packages) does **not** live on a floppy — it streams from a
**SCSI tape at ID 4** (see [Stage 4](#stage-4-stream-the-distribution-from-tape-scsi-id-4)).

## Prerequisites checklist

These are hard constraints baked into the kernel and the install scripts ✅. Get them wrong and the
install will not complete.

- **CPU:** 68020 or 68030 with a **real MMU** (not 68EC020/030) **plus** a 68881/68882 FPU. No soft-float.
- **Emulator:** MMU **ON**, JIT **OFF** (JIT causes kernel panics), FPU 68882. See the
  [WinUAE config table](emulation-winuae.md).
- **SCSI hard disk on ID 6** — the conventional disk target (the installer prompts for it; ID 6 is the
  default everything assumes, and the ID is baked into the device names once installed). The installer's
  `BPART` derives from `/dev/dsk/c${SCSI}d0s${BOOTPART}` ✅.
- **SCSI tape on ID 4** — the distribution device is `/dev/rmt/4h` ✅.
- **Fast RAM:** 4 MB minimum, **16 MB maximum** — the kernel hard-codes the ceiling, and exceeding it
  mis-maps the SCSI drive ✅. Set the emulator's Fast RAM to ≤ 16 MB. (Total *describable* RAM has its
  own, silent limit far above this — [the RAM ceiling](../how-it-works/ram-ceiling.md).)
- **Disk image size:** roughly 450–900 MB is the usual range for the ID 6 hardfile 🟡; keep individual
  partitions ≲ 1 GB 🟡.

## Stage 0 — wire up the virtual disks

In your emulator, attach:

- a writable RDB hardfile on **SCSI ID 6** (this becomes the system disk);
- a **tape image** on **SCSI ID 4** holding the distribution as a cpio stream;
- `amix_21_boot.adf` in **DF0**.

The exact knobs differ per emulator — for WinUAE map ID 6 to the hardfile and ID 4 to the tape image
([WinUAE table](emulation-winuae.md)); for FS-UAE use `hard_drive_0_controller = scsi6` and
`hard_drive_0_type = rdb` ([FS-UAE snippet](emulation-fs-uae.md)).

**Tape-free alternative 🟡:** if you cannot present a tape, the community documents `dd`-ing a cpio
distribution image onto the swap area (or another partition) from Linux/AmigaDOS and extracting it
with `cpio` directly — discussed on comp.unix.amiga. That bypasses [Stage 4](#stage-4-stream-the-distribution-from-tape-scsi-id-4)'s
tape read but is fiddlier; the tape path below is the documented default.

## Stage 1 — boot the install kernel

Power on with `amix_21_boot.adf` in DF0. The Superkickstart ROM reads the OFS bootblock, runs the 68k
bootstrap, which then **loads and decompresses the install kernel**, verifying its checksum ✅. You may
see bootstrap messages like `Load boot volume %d`; failures surface as `Decompression failed!` or
`WARNING! Kernel file checksum mismatch.` (these strings are embedded in the bootstrap ✅).

The install kernel is **NFS/RPC-capable** — it carries a full RPC client string table — which is what
lets a networked install pull packages, though the tape path is what we use here.

## Stage 2 — mount the UFS miniroot

When prompted, insert `amix_21_root.adf`. Its body is a **UFS filesystem** (you can see `lost+found`
and `fsck` strings in the image ✅), and it mounts as the **miniroot**. The installer — a set of m68k
ELF binaries plus `/bin/sh` scripts living on that miniroot — now takes over.

**Note:** the Amix `/bin/sh` is **pre-POSIX** ✅ — no `$(...)` command substitution, no `grep -q`.
This matters if you ever read or edit the install scripts: they use backticks and explicit redirection.

## Stage 3 — partition the disk (RDB)

The installer inspects the ID 6 disk's **Rigid Disk Block (RDB)** scheme, looks for a "suitable UNIX
rdb," and either computes "obvious" partition choices or asks you ✅. The default layout it builds:

| Partition | Purpose | Sizing rule (from the root.adf scripts ✅) |
|---|---|---|
| `/` (root) | Root filesystem | Remainder / user choice |
| swap | Paging | Larger when the disk is bigger than `BREAKPT=120` MB |
| boot/bootstrap | Holds the bootable kernel | `BOOTSIZE=2` MB → `BOOTLEN = BOOTSIZE * 2048` blocks |
| data | Additional storage | User choice |

Filesystem type is asked per filesystem. The choices are **`s5`** (System V — likely a 3B2-lineage
holdover) and **`ufs`** (Berkeley FFS — **recommended** 🟡, on community consensus). **The scripts
default to `s5`, not `ufs` ✅ — so do NOT just press RETURN if you want UFS; you must type `ufs`
explicitly.** The root partition prompt is:

```sh
readask "What file system type is the root partition? [s5] "
case $ask in
""|"s5")  ANS="s5" ;;                          # empty input -> s5
"ufs")    ANS="ufs"; ROOT_OPT="$UFS_OPT" ;;    # only when typed explicitly
esac
```

There is **no `[ufs]` prompt anywhere in `amix_21_root.adf`** (0 occurrences of `[ufs]`, 2 of `[s5]`)
✅. Note also the sibling branch `ROOT_FSYS="s5"  # Johann ROM can only boot s5 filesystem`, so on
some ROM/controller combinations s5 is not merely the default but the only bootable choice 🟡.

> **Why these numbers matter:** `BOOTSIZE=2` and the ID-6/ID-4 wiring are not cosmetic — `make bootpart`
> in [Stage 5](#stage-5-build-the-kernel-and-write-the-boot-partition) writes the kernel into exactly
> this 2 MB boot partition, and the distribution read in [Stage 4](#stage-4-stream-the-distribution-from-tape-scsi-id-4)
> targets `/dev/rmt/4h`. The exact RDB partition **type IDs** Amix stamps (boot vs swap vs UFS) are not
> publicly documented 🔴.

## Stage 4 — stream the distribution from tape (SCSI ID 4)

With the target partitions created and mounted under `/mnt`, the installer streams the distribution off
the tape. The core command (driven by `amixpkg -b/-i -r /mnt`) is ✅:

```sh
dd if=/dev/rmt/4hn bs=256k | cpio -imdcu
```

`/dev/rmt/4hn` is the **n**o-rewind, **h**igh-density tape at SCSI ID 4; `bs=256k` is the block size;
`cpio -imdcu` extracts (`-i`) in copy-in mode, preserving modification times (`-m`), creating
directories (`-d`), copying unconditionally (`-u`), with a portable header (`-c`). Some package members
arrive compressed, handled by a `zcat` variant of the same pipe ✅:

```sh
dd if=/dev/rmt/4hn bs=256k | zcat | cpio -imdcu
```

The package install is orchestrated by `amixpkg`. The root.adf scripts invoke it as ✅:

```sh
amixpkg -i -m -d -r /mnt -y standard
```

That installs (`-i`) the `standard` package set, **m**oving/**d**eleting per the package's directives,
**r**ooted at `/mnt`, answering **y**es non-interactively. (`amixpkg` is widely reported to be flaky
🟡; the scripted invocation above is the reliable path, and it is what the installer itself uses.)

### Non-standard tape drives — `viper_kludge`

If your tape drive is an **Archive Viper 2150S** (a common period substitute), the standard Amix tape
driver mis-handles it. The root.adf ships **`viper_kludge`** by Frank "Crash" Edwards ✅ — it patches
kernel memory at install time so the non-standard drive works (see `viper.README` on the miniroot).

> **Warning:** `viper_kludge` is **incompatible** with the standard A3070 and with Caliper/Wangtek/
> Sankyo drives — its own README explicitly warns not to use it with those ✅. Only apply it for the
> drives it names. In emulation you generally present a standard A3070-style tape, so you will **not**
> need `viper_kludge` — leave it alone.

## Stage 5 — build the kernel and write the boot partition

After the files land on disk, you build the runnable kernel and write it into the 2 MB boot partition ✅.

The kernel sources/objects live in `/usr/sys`; you build there with `make`, producing the kernel image
(modern 2.1 systems call it **`relocunix`**; the 1990 Ditto paper called the equivalent image
`rdbunix` — a historical rename 🟡). Then write it to the boot partition:

```sh
make bootpart KERNEL=relocunix
```

`make bootpart` copies the kernel into the `BOOTSIZE=2` MB boot partition created in
[Stage 3](#stage-3-partition-the-disk-rdb) so the Superkickstart ROM can boot it directly from the SCSI
disk on next power-on. (The general kernel build/relink flow — `/usr/sys`, editing `master.d/kernel.c`,
`make install`, copying to `/stand`, then `make bootpart` — is covered in depth on the
[kernel build page](../drivers/kernel-build.md).)

Then shut down and reboot:

```sh
shutdown -i6
```

Remove the floppy so the machine boots from the SCSI disk (ID 6).

## Stage 6 — first boot and finish with `amixadm`

The machine now boots `relocunix` from the boot partition. Complete the post-install configuration with
the admin tool **`amixadm`** ✅, which walks you through:

- **nodename** (hostname) and **domain**;
- **time zone**;
- the **date** — set a date **≤ 1999** ✅ (the kernel caps the date at 1999; see the
  [Y2K step](#stage-8-y2k-make-the-clock-work-past-1999) for the fix);
- the **root password**;
- **X11** configuration.

> **Default password lore 🟡:** community sources report a default post-install login password of
> `wasp`. Change it immediately via `amixadm` / `passwd`.

After this, you have a running Amix 2.1. For a guided look around your new system — virtual consoles
(Alt+F1..F8), the default `ksh`, and starting X — see the
[first login and tour](first-login-and-tour.md) page.

## Stage 7 — apply the patch disk (→ 2.1p2a / kernel 2.1c)

The retail 2.1 is not the end state. The **patch disk** brings it to **2.1p2a / kernel 2.1c**, the
release widely considered definitive (it carries the inet/NFS and Y2K fixes) ✅. Our `patch.adf`
self-identifies as *"Patch Disks 1 and 2 for International, USA-Only, 2-user, and Unlimited-User Amiga
UNIX System V Release 4.0 Version 2.1."* ✅

The patch disk is a **self-extracting hybrid** ✅: the first 1 KB is a `#!/sbin/sh` bootstrap script,
and everything after byte 1024 is a single SVR4 ASCII cpio (`070701`) archive whose payload is an
LHA-compressed `archive.lha`. To apply it, run the patch image's bootstrap as a root shell script on
the running system. Internally that script (paraphrased from the decoded header ✅):

```sh
# starts flopd, sleeps 10s (REQUIRED), verifies you are root,
# and checks that `uname -v` matches ^2\.1.* 08004..$  (else "USE AT YOUR OWN RISK")
QUIETDD=y dd if="$0" bs=1k iseek=1 2>/dev/null | (cd /; QUIETCPIO=y cpio -icdmuv)
uncompress -f /var/patch/*.Z
exec /var/patch/apply
```

`apply` then uses the bundled `lha` to unpack `archive.lha`, honoring the patch's
`replace.list` / `modify.list` / `delete.list` plus `changes`/`preload`. The full mechanism is dissected
on the [patch disk anatomy](../boot-disks/anatomy-patch-adf.md) page.

> **Version-check guard:** the patch refuses to run unless `uname -v` already matches
> `^2\.1.* 08004..$` ✅. If it prints "USE AT YOUR OWN RISK," you are not on a clean 2.1 — stop and
> recheck your install rather than forcing it.

After the patch completes and you reboot, `uname` should reflect the patched **2.1c** kernel.

## Stage 8 — Y2K: make the clock work past 1999

Stock 2.1 has a **Y2K problem** ✅: a `setclk` `%02d` year-formatting bug plus a **kernel date cap at
1999** ✅. That is why [Stage 6](#stage-6-first-boot-and-finish-with-amixadm) told you to set a date
≤ 1999. The patch disk includes a **Y2K-fixed `setclk`** ✅; once you are on 2.1c, use the patched
`setclk` to set the real (post-1999) date. The community Y2K/DST notes on
[amigaunix.com](https://www.amigaunix.com/doku.php/home) cover the corner cases.

## Recap: the install in one screen

```text
1. DF0 = boot.adf            → bootstrap loads & decompresses the install kernel
2. insert root.adf           → UFS miniroot mounts; installer runs
3. partition the ID 6 disk   → BOOTSIZE=2 MB boot part, swap (BREAKPT=120), FS=ufs
4. tape @ SCSI ID 4:         dd if=/dev/rmt/4hn bs=256k | cpio -imdcu
                             amixpkg -i -m -d -r /mnt -y standard
                             (viper_kludge only for nonstandard tape drives)
5. make bootpart KERNEL=relocunix ; shutdown -i6 ; remove floppy
6. first boot → amixadm: nodename/domain/tz/date(≤1999)/root pw/X11
7. apply patch disk          → 2.1p2a / kernel 2.1c
8. Y2K: patched setclk        → real date past 1999
```

## See also

- [WinUAE emulator setup](emulation-winuae.md) — the reference config (MMU on, JIT off, SCSI ID 6/4).
- [FS-UAE emulator setup](emulation-fs-uae.md) — verified A3000 snippet.
- [Installing on real hardware](real-hardware.md) — A3000UX / A2500UX specifics.
- [First login and tour](first-login-and-tour.md) — what to do after the install finishes.
- [Root disk anatomy](../boot-disks/anatomy-root-adf.md) — the UFS miniroot and install scripts in detail.
- [Boot disk anatomy](../boot-disks/anatomy-boot-adf.md) — the bootblock and compressed install kernel.
- [Patch disk anatomy](../boot-disks/anatomy-patch-adf.md) — how the self-extracting patch works.
- [Kernel build](../drivers/kernel-build.md) — `/usr/sys`, `make bootpart`, and relinking `/unix`.
- [Quirks checklist](../how-it-works/quirks.md) — the Y2K, SCSI-ID, and RAM-ceiling gotchas in one place.

## Sources

- `sources/research-brief.md` §9 (installation flow) and §10 (boot/root/patch disk anatomy) — the
  primary grounding for every stage on this page.
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — partition logic (`BOOTSIZE=2`,
  `BREAKPT=120`, `ANS="ufs"`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`), the tape pipe
  (`dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`), `amixpkg -i -m -d -r /mnt -y standard`, and `viper.README`.
- `amix_21_boot.adf` analysis via `tools/inspect-adf.sh` — OFS bootblock, compressed checksummed install
  kernel, embedded bootstrap/NFS-RPC strings.
- `amix_21_patch.adf` analysis via `tools/inspect-adf.sh` — the 1 KB `#!/sbin/sh` bootstrap, the
  `uname -v` `^2\.1.* 08004..$` guard, the `070701` cpio + `archive.lha` payload, and the self-identifying
  "Patch Disks 1 and 2 … Version 2.1" string.
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — kernel build flow
  (`/usr/sys` → `make` → boot partition; `rdbunix`/`relocunix` naming).
- [amigaunix.com](https://www.amigaunix.com/doku.php/home) — installation, patch-disk, and Y2K/DST notes;
  default-password lore (🟡 community-reported).
- comp.unix.amiga (archived) — tape-free install discussion (🟡).
