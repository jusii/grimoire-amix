---
title: Anatomy of the Root (miniroot) Floppy
summary: The UFS miniroot — installer ELF binaries, the partition/filesystem logic, the SCSI-tape distribution pipeline, and viper_kludge.
status: draft
---

# Anatomy of the Root (miniroot) Floppy

The Amix **root floppy** (`amix_21_root.adf`, 901,120 bytes / 880 KB) is a **UFS "miniroot"**: a small Berkeley-FFS filesystem packed with the *installer* — about 30 m68k ELF binaries (`cpio`, `fsck`, `mkfs`, `dd`, `amixpkg`, `rdb`, …), the `/bin/sh` install scripts that drive partitioning and the tape extraction, a POSIX `tar` member, and the `viper_kludge` tape work-around plus its `viper.README`. ✅ (local analysis of `amix_21_root.adf`)

Unlike the [boot floppy](anatomy-boot-adf.md), the root floppy has **no AmigaDOS bootblock** — its first sectors are zeroed and the Kickstart ROM never boots it directly. It is mounted *by* the install kernel after you swap it in. This page dissects its on-disk structure and the install logic it carries. For the end-to-end procedure, see the [install walkthrough](../getting-started/install-walkthrough.md); to understand how all three install disks are produced, see the [build pipeline](build-pipeline.md).

> **Licensing.** The root floppy is proprietary Commodore material (abandonware, not licensed for redistribution). Do not commit it here. Obtain it from [amigaunix.com](https://www.amigaunix.com/doku.php/home) or the Internet Archive, then run the read-only tooling below against your own copy.

Identify your copy:

```text
file  : amix_21_root.adf
size  : 901120 bytes  (901120 = standard 880 KB Amiga DD floppy)
sha256: 890da5e52f00cae74b817b42d1b94c3438f57b8c13b3d2b055e8b116a3feac56
```
✅ (`tools/inspect-adf.sh` on `amix_21_root.adf`; cross-check against `sources/CHECKSUMS.txt`)

## No bootblock — the body is a UFS filesystem

The root floppy does **not** start with the AmigaDOS `DOS\0` signature that a [boot disk](anatomy-boot-adf.md) has. The boot area is zeroed, so any AmigaDOS-FS tool refuses it: ✅

```text
$ tools/inspect-adf.sh amix_21_root.adf
detected disk type : root
  -> UFS miniroot; expect m68k ELF installer binaries + install shell scripts
[xdftool] ...
    'list' FSError: Invalid Boot Block(1):block=BootBlock:@0
```

That `Invalid Boot Block @0` is expected and *correct* — it confirms there is no AmigaDOS filesystem. The body is instead an SVR4 **UFS** (Berkeley Fast File System) image, recognisable by its UFS fingerprints: a `lost+found` directory entry and `fsck`/`mkfs` string tables embedded in the image. ✅ (`inspect-adf.sh` keys off the `lost+found` string to classify the disk; see [`tools/inspect-adf.sh`](../../tools/inspect-adf.sh) lines 59–63.)

**Note — reading the tree.** Linux's in-tree `ufs` driver generally **cannot** mount Amix's big-endian SVR4/m68k UFS, so a full file-tree traversal needs a UFS-aware reader (a *BSD host, or UFS Explorer). The bundled [`tools/unpack-root.sh`](../../tools/unpack-root.sh) does a *pragmatic carve* instead: it reports every ELF/script offset, carves the POSIX `tar` member(s), and dumps the install-script text — which is what you usually want when studying the installer. ✅

## What's inside: installer ELF binaries, scripts, and a tar member

`binwalk` finds roughly **30 m68k ELF executables** interleaved with two `/bin/sh` scripts and one POSIX `tar` member. ✅ The first object sits at offset **0x6800** (26624):

```text
DECIMAL   HEXADECIMAL   DESCRIPTION
26624     0x6800        ELF, 32-bit MSB executable, Motorola 68020, version 1 (SYSV)
26836     0x68D4        Unix path: /usr/lib/libc.so.1
29859     0x74A3        Unix path: /dev/rmt/4h
31802     0x7C3A        Unix path: /dev/rmt/4hn bs=256k|cpio -imdcu
31894     0x7C96        Unix path: /dev/rmt/4hn bs=256k | zcat | cpio -imdcu %s
...
94592     0x17180       POSIX tar archive
217088    0x35000       Executable script, shebang: "/bin/sh"
218112    0x35400       Executable script, shebang: "/bin/sh"
```
✅ (`binwalk amix_21_root.adf`)

The first-ELF header confirms the binary format used throughout the installer: ✅

```text
$ dd if=amix_21_root.adf bs=1 skip=26624 count=20 2>/dev/null | xxd
00000000: 7f45 4c46 0102 0100 0000 0000 0000 0000  .ELF............
00000010: 0002 0004                                ....
```

Decoded: `7f 45 4c 46` = ELF magic; `01` = ELFCLASS32; `02` = **ELFDATA2MSB** (big-endian); `01` = version; type `0x0002` = `ET_EXEC`; machine `0x0004` = **EM_68K**. Every installer binary references **`/usr/lib/libc.so.1`** — i.e. these are dynamically-linked SVR4 m68k executables, not static blobs. ✅

The installer binaries you can fingerprint by their embedded usage/command strings include: ✅

| Binary (referenced path) | Role in the install |
|---|---|
| `/bin/cpio` | Unpacks the distribution stream from tape |
| `fsck_s5`, `fsck_ufs` | Filesystem check, per FS type |
| `mkfs_s5`, `mkfs_ufs` | Create an s5 or UFS filesystem |
| `dd` | Reads the raw tape device (`/dev/rmt/4hn`) |
| `/etc/rdb` | Reads/writes the **Rigid Disk Block** partition table |
| `/etc/atdevs`, `/etc/ddsize` | SCSI bus scan; partition size in 512-byte blocks |
| `amixpkg` | SVR4 package install wrapper (`-b`, `-i`, …) |
| `mount` / `umount` / `swap` | Mount the new root, add swap |
| `viper_kludge` | Tape-drive kernel patch (see below) |

The two `/bin/sh` scripts at `0x35000`/`0x35400` are the **install driver** — the partition/filesystem logic dissected in the next section. Note that Amix's `/bin/sh` is **pre-POSIX** (no `$(...)`, no `grep -q`), so the scripts use back-ticks, `expr`, and `set --` throughout. ✅ (root.adf script text; the pre-POSIX `/bin/sh` limitation is corroborated by the [VA2000 driver case study](../drivers/case-studies/va2000.md).)

The `tar` member at **0x17180** is a POSIX (`ustar`) archive; carve it with `unpack-root.sh` (it stops at the archive's own end-of-archive marker) for offline inspection. ✅

## The install / partition logic

The install script computes a default partition layout, lets you override it, then writes the [Rigid Disk Block](../how-it-works/filesystems-and-disks.md) and creates filesystems. The tunables at the top of the script are exact: ✅ (root.adf script text)

```sh
BREAKPT=120     # Larger default swap when disk is over BREAKPT mb in size
LGSWAP=30       # Suggested size of swap area, mb, for "large" disks
SMSWAP=18       # Suggested size of swap area, mb, for "small" disks
MINBOOT=2       # Minimum size of bootstrap partition in megabytes
BOOTSIZE=2      # Default bootstrap partition size
UFS_OPT="-o free=2,opt=s"    # options for mkfs_ufs
```

Key behaviours encoded here:

- **Boot/bootstrap partition = 2 MB.** `BOOTSIZE=2` and `BOOTLEN=`expr $BOOTSIZE '*' 2048`` ⇒ a 2 MB partition is **4096 blocks** of 512 bytes. This is the small partition that holds the relocatable kernel the Superkickstart ROM boots. ✅
- **Swap scales with disk size.** Disks larger than `BREAKPT=120` MB get `LGSWAP=30` MB of swap; smaller disks get `SMSWAP=18` MB. ✅
- **SCSI IDs are hard-coded.** The tape is always **id 4** — the disk-selection loop explicitly rejects it: ✅

  ```sh
  if [ "$ask" = "4" ]; then
      echo "\nSCSI device 4 must be used for the tape drive"
  ```

  The install script uses a `$SCSI` variable for the disk (so the prompt accepts other ids), but the kernel and system convention hard-code the disk at **id 6** ✅ (research brief §2: "hard-coded in kernel and install scripts"). In practice, **use id 6 for the disk**; deviating from this hard-codes a mismatch between the kernel and the installed partition layout. See the [quirks page](../how-it-works/quirks.md) for the full list of hard-coded SCSI assignments.

- **Device paths are templated on the chosen SCSI id.** After partitioning, the script binds: ✅

  ```sh
  UPART=/dev/dsk/c${SCSI}d0s${ROOTPART}    # root
  SPART=/dev/dsk/c${SCSI}d0s${SWAPPART}    # swap
  BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}    # boot/bootstrap
  EPART=/dev/dsk/c${SCSI}d0s${EXTRAPART}   # optional extra
  ```

### Filesystem choice: s5 vs UFS

For each data partition the script asks: ✅

```text
Choose a file system type for this partition:

    s5:  Traditional UNIX file system
   ufs:  Berkeley file system

What file system type is this partition? [s5]
```

The **prompt shows `[s5]` as the bracketed default**, and community guidance — and the brief — recommends **UFS** in practice; the s5 default is plausibly a 3B2-lineage hold-over. 🟡 (rationale unconfirmed; note: the research brief records the script's `ANS` variable as defaulting to `"ufs"` in at least some code paths — the exact fallback may depend on partition role)

There is one hard exception the script enforces for the **root** partition: ✅

```sh
ROOT_FSYS="s5"     # Johann ROM can only boot s5 filesystem
```

After offering the s5/ufs choice for the root, the script *overrides* it back to `s5`, with the comment that the "Johann ROM" can only boot an s5 root. So even when you pick UFS elsewhere, the bootable root ends up s5 on this installer. ✅ (root.adf script text; the "Johann" name appears verbatim in the installer comment; its relationship to the Superkickstart boot ROM is 🔴 unconfirmed in the research brief — see the [boot process](../how-it-works/boot-process.md).)

### RDB partition type tags

After laying out the partitions with `/etc/rdb -a`, the script stamps each one with an SVR4/Amix partition **type tag** via `/etc/rdb -F` (this resolves brief gap #8, the previously-undocumented RDB type IDs — values read directly from the installer): ✅

```sh
/etc/rdb -p $BOOTPART -M -B -C 2 -P 2 -F 0x554e4900 $DISK   # 'UNI\0'  bootable boot partition
/etc/rdb -p $ROOTPART -m         -F 0x554e4901 $DISK        # 'UNI\1'  UNIX root
/etc/rdb -p $SWAPPART -m         -F 0x72657376 $DISK        # 'resv'   swap
```

The script's own comment is explicit about why the boot partition must be `0x554e4900`: ✅

```text
# The Kickstart 2.04 booting priority algorithms require that bootable
# UNIX partitions are filesystem type 0x554e4900.  Other types may [not boot]
```

So: boot partition type **`0x554e4900`** (ASCII `UNI\0`), UNIX root **`0x554e4901`** (`UNI\1`), swap **`0x72657376`** (`resv`). The `-B`/`-C 2`/`-P 2` flags mark the partition bootable with the boot-priority/auto-mount fields the ROM scans. ✅

### Driving the package install

Once partitions and filesystems exist and the new root is mounted at `/mnt`, the script computes how much space is available and calls `amixpkg`: ✅

```sh
amixpkg -b -v -r /mnt $OPTIONS ||                       # bootstrap pass
amixpkg -i -m -d -r /mnt -y standard -s $AVAILABLE ||   # install "standard" cluster
```

`-r /mnt` is the alternate root, `-y standard` selects the standard package cluster, and `-s $AVAILABLE` caps the install to the free blocks computed from the root partition. The `amixpkg` wrapper is widely reported as flaky, but the miniroot install path relies on it. 🟡 (`amixpkg` reliability)

## The tape distribution pipeline

The actual operating-system files do **not** live on the root floppy — they are streamed from a **QIC tape at SCSI id 4** and unpacked through `cpio`. The script defines the tape devices and the pipelines verbatim: ✅

```sh
TAPEn=/dev/rmt/4hn      # no-rewind, high-density tape node
TAPE=/dev/rmt/4h        # auto-rewind node
```

The distribution is read with `dd` and fed to `cpio`. Two variants appear, depending on whether the tape image is compressed: ✅

```sh
dd if=/dev/rmt/4hn bs=256k | cpio -imdcu          # plain cpio stream
dd if=/dev/rmt/4hn bs=256k | zcat | cpio -imdcu   # compress(1)-ed stream
```

`cpio` flags here: `-i` extract, `-m` retain modification times, `-d` create directories, `-c` ASCII header, `-u` unconditional overwrite. A `cpio -imdcuB < /dev/rmt/4hn > /dev/null` invocation also appears (the `B` = 5120-byte block size for raw tape), used to verify/seek the tape. ✅

The **device-naming convention** (`/dev/rmt/<id><density>[n]`, `n` = no-rewind) is part of the SVR4 tape model; the `4` is the hard-coded SCSI tape id. See the [device list](../reference/device-list.md) and the [quirks page](../how-it-works/quirks.md).

**Tape-free installs.** Because most emulator users have no real QIC drive, the practical path is to *present a tape image at SCSI id 4* in the emulator, or to `dd` a `cpio` image to swap from Linux/AmigaDOS and extract with `cpio`. The latter is documented on comp.unix.amiga. 🟡 See [emulation on WinUAE](../getting-started/emulation-winuae.md) for the SCSI-id-4 tape-image setup and the [install walkthrough](../getting-started/install-walkthrough.md).

## viper_kludge: the non-standard-tape work-around

The root floppy ships **`viper_kludge`** (an m68k ELF) and its **`/viper.README`**, written by **Frank "Crash" Edwards**. Its purpose is to **patch kernel memory** at install time so that tape drives the Amix kernel does *not* natively know — specifically the **Archive Viper 2150S** — can be read by `dd`/`cpio` during the install. ✅ (root.adf strings; `viper.README`)

**When you'd use it.** If the install fails with a *tape I/O error* on a non-standard drive, you press Ctrl-D until you reach the interactive `#` prompt, then run `viper_kludge` with no arguments to read its on-screen warning, and finally `viper_kludge go` to apply the patch. The `viper.README` walks through this. ✅

```text
viper_kludge          # prints the warning only; patches nothing
viper_kludge go       # actually patches /dev/mem
```

**It is dangerous — heed the built-in warnings.** Both the runtime banner and `viper.README` warn, verbatim: ✅

- *"THIS PROGRAM (viper_kludge) IS EXPERIMENTAL. BY RUNNING IT THE USER AGREES TO BEAR ALL RESPONSIBILITY FOR THE RESULTS."*
- It is **incompatible with**, and must **not** be run on systems using, the **Commodore A3070**, **Caliper**, **Wangtek**, and **Sankyo** 150 MB cartridge drives — *"It PREVENTS their use"*. ✅
- The patch lives only in RAM: *"Shutting down and rebooting removes the kernel memory patch."* So it must be re-applied per boot until a real driver is built. ✅
- For a permanent fix, the README points at *"the files in directory `/usr/sys/amiga/alien/contrib`"* to make the kernel inherently recognise the Viper — i.e. building tape support into the kernel rather than patching live memory. ✅ (cf. the kernel-rebuild flow in [kernel build & install](../drivers/kernel-build.md))

**Bottom line:** only use `viper_kludge` if you have a genuinely unsupported tape drive and the standard install has already failed on a tape error. If your drive is an A3070 or any Caliper/Wangtek/Sankyo unit, do **not** run it.

## Tooling: inspecting and unpacking the root floppy

Both scripts are read-only on the input image and operate on **your own** copy of the ADF.

**`tools/inspect-adf.sh`** — classify the disk and surface the installer / tape / partition strings: ✅

```sh
tools/inspect-adf.sh amix_21_root.adf
# detected disk type : root
# -> UFS miniroot; expect m68k ELF installer binaries + install shell scripts
# [root] installer / tape pipeline strings:
#     amixpkg -i -m -d -r /mnt -y standard -s $AVAILABLE ||
#     BOOTSIZE=2  # Default bootstrap partition size
#     BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}
#     dd if=/dev/rmt/4hn bs=256k | zcat | cpio -imdcu %s
#     ... viper_kludge ...
```

**`tools/unpack-root.sh`** — scan, carve the `tar` member(s), and dump the install-script text into `tools/_work/<image>/` (gitignored): ✅

```sh
tools/unpack-root.sh amix_21_root.adf
# == unpack-root: amix_21_root.adf -> tools/_work/amix_21_root =
# -- scanning for embedded objects (binwalk) --
# -- carving POSIX tar member(s) --
#     carved .../tar_1_at_94592.tar (from offset 94592)
# -- installer script text (high-value strings) --   (full dump in strings.txt)
```

Both require `binwalk`/`strings`; `inspect-adf.sh` additionally uses `xdftool` (from amitools) and `xxd` when present and degrades gracefully otherwise.

## See also

- [Install walkthrough](../getting-started/install-walkthrough.md) — the end-to-end procedure that uses this floppy.
- [Anatomy of the boot floppy](anatomy-boot-adf.md) — the bootable disk that loads the install kernel before you swap in the root floppy.
- [Anatomy of the patch floppy](anatomy-patch-adf.md) — the self-extracting 2.1c patch disk.
- [The build pipeline](build-pipeline.md) — how the boot/root/patch disks are produced and how to build add-on disks.
- [Filesystems and disks](../how-it-works/filesystems-and-disks.md) — RDB scheme, s5 vs UFS, partition layout.
- [Quirks](../how-it-works/quirks.md) — hard-coded SCSI ids, the 16 MB ceiling, and other landmines.

## Sources

- `amix_21_root.adf` analysis via [`tools/inspect-adf.sh`](../../tools/inspect-adf.sh) and [`tools/unpack-root.sh`](../../tools/unpack-root.sh) — `binwalk` object table (30 m68k ELF objects, first at 0x6800; `tar` member at 0x17180; `/bin/sh` scripts at 0x35000/0x35400), ELF header bytes at 0x6800 (`ELFCLASS32`, `ELFDATA2MSB`, `ET_EXEC`, `EM_68K`), and `strings` dump of the install script (BOOTSIZE/BREAKPT/LGSWAP/SMSWAP, `BPART`/`UPART`/`SPART`, s5/ufs prompt, `ROOT_FSYS="s5" # Johann ROM`, RDB `-F` type tags `0x554e4900`/`0x554e4901`/`0x72657376`, `amixpkg` invocations, `/dev/rmt/4hn` tape pipelines).
- `viper.README` and the `viper_kludge` runtime banner extracted from `amix_21_root.adf` (author Frank "Crash" Edwards; incompatibility with A3070/Caliper/Wangtek/Sankyo; RAM-only patch; pointer to `/usr/sys/amiga/alien/contrib`).
- Master research brief, §9 (installation flow) and §10 (root.adf anatomy); §2 (hard-coded SCSI ids, RAM ceiling); §13 gap #8 (RDB partition type IDs).
- SHA-256 cross-check: `sources/CHECKSUMS.txt`.
- Disk image (not redistributed here): [amigaunix.com](https://www.amigaunix.com/doku.php/home) / [archive.org Amiga UNIX](https://archive.org/details/commodore-amiga-operating-systems-amix).
