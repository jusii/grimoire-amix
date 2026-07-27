---
title: Filesystems & Disk Layout
summary: RDB partitions, UFS vs s5, and how /dev disk device names map to SCSI addresses.
status: draft
---

# Filesystems & Disk Layout

Amix stores everything on a single SCSI hard disk — **ID 6 by convention** (the installer prompts for the disk target; ID 6 is simply what every manual and emulator assumes, and it gets baked into the device names once installed — see the note below) 🟡, partitioned with the Amiga **Rigid Disk Block (RDB)** scheme ✅ — the same on-disk partition table AmigaOS uses, which is what lets the Superkickstart ROM find and boot the disk. The installer carves out four partitions by default (root, swap, a 2 MB boot/bootstrap partition, and data) ✅. You choose a filesystem at install time: **s5** (System V; the default but discouraged) or **UFS** (Berkeley Fast File System; recommended, and what the install scripts actually default to) ✅. Disk device names like `/dev/dsk/c0d0s1` are not arbitrary — the **minor number encodes the SCSI address, LUN, and partition**, and the **major number selects the driver** (block major **18** for the SCSI disk, block major **16** for the floppy) ✅.

If you just want the major/minor cheat sheet, jump to [Device name → SCSI address mapping](#device-name-scsi-address-mapping) or the [device list reference](../reference/device-list.md). For how the disk gets booted in the first place, see the [boot process](boot-process.md).

## The RDB partition scheme

Amix does not invent its own partition table — it reuses the Amiga **Rigid Disk Block (RDB)** ✅, the partition descriptor block written near the start of the drive that AmigaOS and its expansion ROMs understand. This is deliberate: power-on goes Superkickstart ROM → SCSI HD, and the ROM bootstrap can locate the boot partition through the RDB ✅. (See [the boot process](boot-process.md) for the full chain.)

Practical consequences of the RDB choice:

- The drive that holds Amix is addressed as a "UNIX rdb" — the installer probes for "a suitable UNIX rdb" before partitioning ✅.
- Under emulation you present the disk as an **RDB-type hardfile** (e.g. `hard_drive_0_type = rdb` in [FS-UAE](../getting-started/emulation-fs-uae.md), an RDB hardfile in [WinUAE](../getting-started/emulation-winuae.md)) ✅.
- The **exact RDB partition type IDs** are read from the installer script ✅: boot **`0x554e4900`** (`UNI\0`), UNIX root **`0x554e4901`** (`UNI\1`), swap **`0x72657376`** (`resv`), stamped with `/etc/rdb -F`. Kickstart 2.04's boot-priority algorithm *requires* the bootable partition to be `0x554e4900`. See the [root floppy anatomy](../boot-disks/anatomy-root-adf.md#rdb-partition-type-tags).

**Note:** The disk's SCSI ID is **baked into its device names** at install time — at the conventional ID 6 every path is `c6d0s…` — so although the installer accepts other targets, the ID is then fixed *in `/etc/vfstab`* (the SVR4 mount table) and the boot partition, and can't be changed without editing those 🟡. The tape, by contrast, is genuinely hard-wired to **SCSI ID 4** (`/dev/rmt/4h`) ✅. See [hardware](hardware.md#scsi-target-ids) and [Quirks](quirks.md).

## Default partition layout

The installer either computes "obvious" partition sizes or asks you, then lays down four regions ✅:

| Partition | Purpose | Sizing rule | Tag |
|---|---|---|---|
| Root (`/`) | The system filesystem | Remainder / user choice | ✅ |
| Swap | Paging space | Larger when the disk exceeds `BREAKPT=120` MB | ✅ |
| Boot / bootstrap | Holds the bootable kernel image; written by `make bootpart` | `BOOTSIZE=2` (MB) → `BOOTLEN = BOOTSIZE * 2048` blocks | ✅ |
| Data | User / extra data | User choice | ✅ |

The boot-partition sizing is straight from the root-floppy install scripts: `BOOTSIZE=2` megabytes, converted to `BOOTLEN = BOOTSIZE*2048` disk blocks ✅. The swap-vs-disk-size threshold is the script's `BREAKPT=120` MB cutoff ✅.

The same scripts compute the boot partition's device node from the SCSI ID and a boot-partition index:

```sh
# from amix_21_root.adf install scripts (inspect-adf.sh)
BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}
```

That is, the boot partition is `/dev/dsk/c<SCSI-id>d0s<partition>` ✅ — exactly the `c d s` naming decoded [below](#device-name-scsi-address-mapping). With the disk at ID 6, `${SCSI}` is 6.

🟡 Community guidance is to **keep individual partitions at roughly 1 GB or smaller**; larger partitions are reported to cause trouble. There is no primary source pinning down the precise limit, so treat the exact number as community lore.

## UFS vs s5: which filesystem

You pick the filesystem type during installation ✅. Two choices ship:

| Type | What it is | Status at install | Use it? | Tag |
|---|---|---|---|---|
| **UFS** | Berkeley Fast File System (FFS) | **Not** the default — must be typed explicitly | **Recommended** 🟡 | ✅ |
| **s5** | System V filesystem | The default, in the prompt **and** in the scripts | Required on some ROMs | ✅ |

**CORRECTION (2026-07-19).** This page previously stated ✅ that the install scripts "default `ANS="ufs"`". That is **wrong**, and the error mattered: [the walkthrough](../getting-started/install-walkthrough.md) told readers to *accept the default* in order to get UFS, which would have produced an **s5** root instead. Measured directly from `sources/floppy/amix_21_root.adf` ✅:

```sh
readask "What file system type is the root partition? [s5] "
case $ask in
""|"s5")  ANS="s5" ;;                          # empty input -> s5
"ufs")    ANS="ufs"; ROOT_OPT="$UFS_OPT" ;;    # only when typed explicitly
esac
```

`ANS="ufs"` does appear in the script, but as a **case branch reached only when the user types `ufs`** — not as a default. The image contains **0 occurrences of `[ufs]` and 2 of `[s5]`** ✅. There is also a sibling branch `ROOT_FSYS="s5"  # Johann ROM can only boot s5 filesystem`, so on some ROM/controller combinations s5 is not just the default but the only bootable root 🟡.

The UFS *recommendation* still stands on community consensus 🟡 — but it requires typing `ufs`, and it may not be available for the root filesystem on every machine.

Why does **s5** linger as a nominal default at all? 🟡 The most plausible explanation is **lineage**: Amix was a direct port of AT&T's **3B2 (WE32x00) SVR4 codebase** 🟡 (community-reported — amigaunix.com hedges "it appears that"), where the System V filesystem was the native default, and that default carried over even though UFS is the better choice on this hardware. The 3B2-lineage rationale is **community-reported, not primary-verified** 🟡 — see the [quirks page](quirks.md).

**Recommendation:** choose **UFS** when the installer asks. UFS is also what the miniroot itself uses — the root floppy *is* a UFS filesystem (it carries `lost+found` and `fsck` strings) ✅, so the installer environment runs on UFS before your disk is even partitioned.

### Filesystem mechanics

- UFS gives you the Berkeley FFS semantics SVR4 administrators expect (`fsck`, `mount`, the usual block/fragment layout) ✅.
- The standard SVR4 toolset is present: `fsck`, `dd`, and `cpio` all appear as m68k ELF binaries inside the root miniroot ✅, used during install and available afterward.
- s5 is the older System V filesystem with smaller block sizes and weaker crash recovery than FFS; it is functional but offers no advantage here.
- **s5 truncates filenames at 14 characters (`DIRSIZ=14`), silently** ✅ — no error, the name just shortens (e.g. a file written as `bootslice.manifest` reads back as `bootslice.mani`, and two long names can collide into one). This bites any s5-hosted tooling/payload tree — for example a custom install-payload slice — so keep every filename on an s5 volume ≤ 14 chars. UFS is unaffected.
- **Host-side surgery on an installed disk image: the on-disk root is UFS, and it loop-mounts on Linux** ✅. An installed Amix root partition is SVR4 **big-endian** UFS, so a modern Linux host can read it directly, read-only, with `mount -t ufs -o ro,loop,offset=<partition-start-bytes>,ufstype=sun <image> <mnt>` (the `ufstype=sun` variant is the one that matches). This is how you extract or verify files from a captured `.hdf` without booting it — note the s5 reader used for *miniroot/floppy* media does **not** apply to an installed root.

## Mounting a CD: the read-only `cdfs` optical filesystem

`s5` and UFS are the on-disk *root* choices; for **CD-ROM** media Amix adds a third, mount-only filesystem — `cdfs`, an in-kernel **read-only** optical filesystem ported from the AmigaOS `ODFileSystem` (`reinauer/ODFileSystem`) that understands **ISO9660, Rock Ridge, Joliet, and UDF** ✅. It is not part of the stock distribution; you add it to the kernel like any other filesystem (a `vfssw[]` row plus a relink — see below) ✅. On the Amiberry-A4091 bench a `cdfs`-enabled **Amix 2.1c** kernel mounts and reads a genuine CD **byte-for-byte**: `ls -la /cdrom` lists every Rock Ridge entry with correct names, sizes and dates (including UTF-8 `café.txt`, `long filename with spaces.txt`, a `MixedCase.Txt`, a symlink, and a 3-level `deep/subdir/nested.txt`), `cat` returns the correct bytes, and the on-box SysV `sum` matches the host `sum -s` exactly (e.g. `SHORT.TXT` → `538 1`, `twentychars.dat` → `1060 1`) ✅.

### Mounting a CD

`cdfs` is a real SVR4 fstype, so you mount it with `mount -F cdfs`. Like `s5` and `bfs` it needs a **per-fstype user helper** at `/usr/lib/fs/cdfs/mount` — a small ELF binary that the generic `mount(1M)` execs, which just issues `mount(spec, dir, MS_DATA|MS_RDONLY, "cdfs", 0, 0)` ✅. If that helper is missing, `mount(1M)` refuses with **`operation not applicable to FSType cdfs`** — note this is *not* `errno 22` ✅.

The mount **spec is not a `/dev` path.** `cdfs` takes a `"<card><sep><unit>"` string that names the SCSI drive directly — e.g. `"1,3"` is a4091 **card 1, unit 3** (an A3000 onboard controller is **card 0**); `cdfs` parses the string itself ✅. This deliberately sidesteps the [`/dev/dsk/cXdYsZ` naming below](#device-name-scsi-address-mapping) — there is no disk-slice node for the CD, the card/unit pair is the whole address.

```sh
# once: compile the per-fstype helper (a minimal mount(2) caller) into place
cc -o /usr/lib/fs/cdfs/mount <helper>.c
# then mount a CD by "card,unit" — NOT /dev/dsk/...
mount -F cdfs 1,3 /cdrom
ls -la /cdrom
```

### Confirming `cdfs` is live in the booted kernel

`mount -F cdfs` returning **`errno 22` (`EINVAL`)** almost always means `cdfs` is *not* in the running kernel — the classic SVR4 ghost: the kernel was patched on disk but never relinked-and-rebooted, or the wrong kernel is booted ✅. `cdfs` registers exactly like the built-in filesystems: a static `vfssw[]` row whose `cdfsinit` hook `vfsinit` calls automatically at boot, so injecting the row and relinking is sufficient to register it ✅. Confirm live registration with `sysfs(GETFSIND, "cdfs")` — **≥ 1** means registered (it is `12` on the bench kernel), **`-1`** means absent from this boot ✅. The disassembly-backed mechanism (why `22` is unambiguous here, `vfs_getvfssw`, the numeric-vs-string fstype dispatch) is documented on the [kernel reverse-engineering page](../drivers/kernel-reverse-engineering.md).

### Kernel prerequisites

Any kernel that **roots through the A3000 onboard SCSI** — which is every emulated bench box, whatever add-on HBA it also carries — needs the **`a3091.c` super-DMAC chip-mem DMA bounce patch**, or it panics `s5mountroot VOP_OPEN error 6` before it can mount root ✅. This is **not** specific to `cdfs` and **not** specific to the a4091: the panic is not size-triggered (a patched kernel with a larger loaded image boots fine), and the patch lives in the `amix-a4091` repo only because that project wrote it ✅. A machine that roots through a different controller — the real A4000 + Z3660, for instance — links `a3091` but never sends the root read through it, so it is indifferent ✅. The separate GSIO `scsi.c.patch` (which grows the iobuf from 1 KB to 64 KB) is only needed by the *userspace* `/dev/scsi` path — the in-kernel `cdfs` read path goes through `sdqueue` and does not need it ✅. See [Building & installing a kernel](../drivers/kernel-build.md#the-a3000-onboard-scsi-dma-bounce-patch--nearly-every-kernel-needs-it) for the mechanism, the measured refutation of the size story, and the relink/install/reboot cycle.

## Device name → SCSI address mapping

Under Unix a device is just a file in `/dev` with a **major** number (which driver) and a **minor** number (which sub-device); the kernel keys off the numbers, not the filename ✅. Amix follows the SVR4 controller/disk/slice naming for SCSI disks.

### Disk nodes: `/dev/dsk/cXdYsZ` and `/dev/rdsk/...`

The block disk driver is **major 18** — the SCSI hard-disk driver ✅. A name like `/dev/dsk/c0d0s1` decodes as ✅:

| Field | Meaning | Encoded in |
|---|---|---|
| `c0` | controller / **SCSI address 0** | minor number |
| `d0` | drive / **LUN 0** | minor number |
| `s1` | **slice/partition 1** | minor number |

The Ditto driver paper's own `ls -l /dev` shows `/dev/dsk/c0d0s1` as **block major 18, minor 1**, where minor 1 means "SCSI addr 0, LUN 0, partition 1" ✅. In other words the **minor number packs the SCSI address, LUN, and partition number together** ✅ — there is no separate field; the driver decodes the minor on each access.

Because the install disk is conventionally at SCSI ID 6, real install paths look like `/dev/dsk/c6d0s<part>` (the `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` line above resolves to whatever target you pick — `c6` at the conventional ID 6) ✅.

- `/dev/dsk/...` is the **block** interface (buffered, used for filesystems via `mount`).
- `/dev/rdsk/...` is the matching **character/raw** interface (unbuffered, used by `fsck`, `dd`, partition tools) — standard SVR4 convention.

### Floppy nodes: `/dev/fd0`

The floppy drive is the **block driver at major 16** ✅ (`/dev/fd0`, from the paper's `/dev` listing). This is the AmigaDOS-format floppy device the install kernel reads; the boot/root/patch images you write to a real or emulated `DF0:` are read through it.

### Tape nodes: `/dev/rmt/4h`

The distribution is streamed from a QIC tape at **SCSI ID 4** ✅. The install scripts read `/dev/rmt/4h` (and the no-rewind `/dev/rmt/4hn`) ✅ — here the leading `4` in the path is the **tape's SCSI ID**, mirroring the hard-coded ID-4 tape requirement. Install pulls the archive with:

```sh
# distribution load from tape (amix_21_root.adf install scripts)
dd if=/dev/rmt/4hn bs=256k | cpio -imdcu
```

A `... | zcat | cpio` variant handles compressed streams ✅. See the [install walkthrough](../getting-started/install-walkthrough.md) for the full flow, including tape-free alternatives.

### Quick major/minor reference

| Node | Class | Major | Notes | Tag |
|---|---|---|---|---|
| `/dev/dsk/cXdYsZ` | block | **18** | SCSI hard disk; minor encodes addr/LUN/partition | ✅ |
| `/dev/rdsk/cXdYsZ` | char | (raw disk) | unbuffered peer of the above | ✅ |
| `/dev/fd0` | block | **16** | floppy drive | ✅ |
| `/dev/rmt/4h` | char | (tape) | QIC tape; leading digit = SCSI ID 4 | ✅ |
| `/dev/console` | char | 0 (minor 0) | system console (for contrast) | ✅ |

For a fuller catalogue of device nodes and major numbers across the system, see the [device list reference](../reference/device-list.md).

## See also

- [The boot process](boot-process.md) — how the Superkickstart ROM finds the RDB boot partition and decompresses the kernel.
- [Device list](../reference/device-list.md) — the full table of `/dev` nodes and major numbers.
- [Hardware & requirements](hardware.md) — the SCSI target IDs and the 16 MB RAM ceiling.
- [Install walkthrough](../getting-started/install-walkthrough.md) — partitioning and filesystem choice in context.
- [Quirks](quirks.md) — the SCSI-ID constraints (tape hard-coded at ID 4, disk ID 6 by convention) and other gotchas.
- [Kernel reverse-engineering](../drivers/kernel-reverse-engineering.md) — the `vfssw[]` registration and the `mount -F cdfs` → `EINVAL(22)` "not in the booted kernel" diagnosis behind the `cdfs` section above.

## Sources

- `sources/research-brief.md` §3 (boot process & disk layout), §5 (device-driver model / `/dev` major-minor), §9 (installation flow), §10 (root.adf anatomy), §13 (open questions #5, #8).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — `ls -l /dev` example (`/dev/dsk/c0d0s1` block major 18 minor 1; `/dev/fd0` block major 16; `/dev/console` char major 0).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — install scripts: `BOOTSIZE=2`, `BOOTLEN=BOOTSIZE*2048`, `BREAKPT=120`, `ANS="ufs"`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`, `dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`; UFS miniroot (`lost+found`, `fsck` strings).
- amigaunix.com (installation / requirements pages) — UFS-recommended consensus, ~1 GB partition guidance, SCSI ID 6 disk / ID 4 tape.
- amix-cdfs in-kernel mount verification — firsthand Amiberry-A4091 bench, Amix 2.1c (2026-07-10): `mount -F cdfs 1,3 /cdrom` reads a Rock Ridge test CD byte-for-byte (`ls -la` of all 7 RR entries with correct names/sizes/dates; `cat` correct; on-box SysV `sum` == host `sum -s`, `SHORT.TXT 538 1`, `twentychars.dat 1060 1`); per-fstype ELF helper `/usr/lib/fs/cdfs/mount` (missing → "operation not applicable to FSType cdfs", not errno 22); card/unit spec `"1,3"` (a4091 card 1 unit 3; A3000 onboard = card 0), not a `/dev` path; `sysfs(GETFSIND,"cdfs")` liveness (12 live / -1 absent); a4091 `a3091.c` super-DMAC boot patch required (else `s5mountroot VOP_OPEN error 6`); GSIO `scsi.c.patch` needed only by the userspace `/dev/scsi` path, not the in-kernel `sdqueue` path ✅.
- `cdfs` = a port of the AmigaOS `ODFileSystem` (`reinauer/ODFileSystem`), read-only ISO9660 / Rock Ridge / Joliet / UDF; the fstype registration mechanism (`vfssw[]` row + `cdfsinit` via `vfsinit`, `vfs_getvfssw`, and the `EINVAL(22)` dispatch) is cross-documented on `docs/drivers/kernel-reverse-engineering.md`.
- The **Installer-NG** Waves 5–6 field campaign (amix-installng @ `7106f1b`, amix-packagemanager @ `4539ad2`), 2026-07-22/24 — a blank-disk→bootable-install effort that root-caused these platform behaviours on the Amiberry bench and the real A4000+Z3660 (acceptance-run captures, s5/UFS state reads, and the on-metal digest attestation) ✅ (🟡 where tagged).
- The **amix-kerntools** `a3091` bounce root cause @ `05d0d78` (`docs/a3091-bounce-boot-patch.md`),
  2026-07-26 ✅ — scope correction to the line above: the A3000 chip-mem DMA bounce is required by
  every kernel that roots through the A3000 onboard SCSI, not by a4091/cdfs kernels specifically, and
  the `s5mountroot VOP_OPEN error 6` panic is **not** size-triggered (four-kernel section-size table;
  a 652-byte-larger patched kernel boots).
