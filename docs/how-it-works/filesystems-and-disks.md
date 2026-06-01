---
title: Filesystems & Disk Layout
summary: RDB partitions, UFS vs s5, and how /dev disk device names map to SCSI addresses.
status: draft
---

# Filesystems & Disk Layout

Amix stores everything on a single SCSI hard disk that **must** sit at **SCSI ID 6** ✅, partitioned with the Amiga **Rigid Disk Block (RDB)** scheme ✅ — the same on-disk partition table AmigaOS uses, which is what lets the Superkickstart ROM find and boot the disk. The installer carves out four partitions by default (root, swap, a 2 MB boot/bootstrap partition, and data) ✅. You choose a filesystem at install time: **s5** (System V; the default but discouraged) or **UFS** (Berkeley Fast File System; recommended, and what the install scripts actually default to) ✅. Disk device names like `/dev/dsk/c0d0s1` are not arbitrary — the **minor number encodes the SCSI address, LUN, and partition**, and the **major number selects the driver** (block major **18** for the SCSI disk, block major **16** for the floppy) ✅.

If you just want the major/minor cheat sheet, jump to [Device name → SCSI address mapping](#device-name-scsi-address-mapping) or the [device list reference](../reference/device-list.md). For how the disk gets booted in the first place, see the [boot process](boot-process.md).

## The RDB partition scheme

Amix does not invent its own partition table — it reuses the Amiga **Rigid Disk Block (RDB)** ✅, the partition descriptor block written near the start of the drive that AmigaOS and its expansion ROMs understand. This is deliberate: power-on goes Superkickstart ROM → SCSI HD, and the ROM bootstrap can locate the boot partition through the RDB ✅. (See [the boot process](boot-process.md) for the full chain.)

Practical consequences of the RDB choice:

- The drive that holds Amix is addressed as a "UNIX rdb" — the installer probes for "a suitable UNIX rdb" before partitioning ✅.
- Under emulation you present the disk as an **RDB-type hardfile** (e.g. `hard_drive_0_type = rdb` in [FS-UAE](../getting-started/emulation-fs-uae.md), an RDB hardfile in [WinUAE](../getting-started/emulation-winuae.md)) ✅.
- 🔴 The **exact RDB partition type IDs** Amix assigns to its boot / swap / UFS partitions are not documented in any source we hold. Treat any specific type-ID claim as unverified.

**Note:** Because the SCSI disk ID is hard-coded to 6 ✅, every install lives at the same address. Likewise the tape used to load the distribution is hard-coded to **SCSI ID 4** ✅. See [Quirks](quirks.md) for the full list of hard-coded addresses.

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
| **UFS** | Berkeley Fast File System (FFS) | Not the menu default, but the **scripts default `ANS="ufs"`** | **Recommended** | ✅ |
| **s5** | System V filesystem | The historical/menu **default** | **Discouraged** | ✅ |

The recommendation is unambiguous in practice: the install scripts on the root floppy set the answer variable `ANS="ufs"` as their effective default ✅, and community consensus is that everyone uses UFS.

Why does **s5** linger as a nominal default at all? 🟡 The most plausible explanation is **lineage**: Amix was a direct port of AT&T's **3B2 (WE32x00) SVR4 codebase** ✅, where the System V filesystem was the native default, and that default carried over even though UFS is the better choice on this hardware. The 3B2-lineage rationale is **community-reported, not primary-verified** 🟡 — see the [quirks page](quirks.md).

**Recommendation:** choose **UFS** when the installer asks. UFS is also what the miniroot itself uses — the root floppy *is* a UFS filesystem (it carries `lost+found` and `fsck` strings) ✅, so the installer environment runs on UFS before your disk is even partitioned.

### Filesystem mechanics

- UFS gives you the Berkeley FFS semantics SVR4 administrators expect (`fsck`, `mount`, the usual block/fragment layout) ✅.
- The standard SVR4 toolset is present: `fsck`, `dd`, and `cpio` all appear as m68k ELF binaries inside the root miniroot ✅, used during install and available afterward.
- s5 is the older System V filesystem with smaller block sizes and weaker crash recovery than FFS; it is functional but offers no advantage here.

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

Because the install disk is hard-wired to SCSI ID 6, real install paths look like `/dev/dsk/c6d0s<part>` (the `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` line above resolves to `c6` at install time) ✅.

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
- [Hardware & requirements](hardware.md) — why the SCSI IDs and the 16 MB RAM ceiling are fixed.
- [Install walkthrough](../getting-started/install-walkthrough.md) — partitioning and filesystem choice in context.
- [Quirks](quirks.md) — the hard-coded SCSI-ID-6 disk / ID-4 tape constraints and other gotchas.

## Sources

- `sources/research-brief.md` §3 (boot process & disk layout), §5 (device-driver model / `/dev` major-minor), §9 (installation flow), §10 (root.adf anatomy), §13 (open questions #5, #8).
- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — `ls -l /dev` example (`/dev/dsk/c0d0s1` block major 18 minor 1; `/dev/fd0` block major 16; `/dev/console` char major 0).
- `amix_21_root.adf` analysis via `tools/inspect-adf.sh` — install scripts: `BOOTSIZE=2`, `BOOTLEN=BOOTSIZE*2048`, `BREAKPT=120`, `ANS="ufs"`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`, `dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`; UFS miniroot (`lost+found`, `fsck` strings).
- amigaunix.com (installation / requirements pages) — UFS-recommended consensus, ~1 GB partition guidance, SCSI ID 6 disk / ID 4 tape.
