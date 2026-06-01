---
title: How Amix Boots
summary: Superkickstart -> AmigaDOS bootblock -> compressed checksummed kernel; the RDB partition layout and the 2 MB boot partition.
status: draft
---

# How Amix Boots

Amix boots in two distinct worlds glued together at the very front of the disk. At power-on the **"Superkickstart 1.4"** bootstrap ROM decides whether to bring up AmigaOS or Amix; if it goes the Amix way it runs an **AmigaDOS-style bootblock** that contains a 68k bootstrap, which in turn **loads and decompresses a checksummed Unix kernel** into RAM and hands control to it ✅. The kernel and everything else live in a normal Unix partition layout that is wrapped in the Amiga **Rigid Disk Block (RDB)** scheme, including a small **2 MB boot partition** whose only job is to hold the kernel image where the bootstrap can find it ✅.

This page traces that path end to end — ROM, bootblock, kernel decompression, the on-disk RDB layout, how the kernel is built and written to the boot partition, and what our own analysis of `amix_21_boot.adf` actually shows. For the byte-level dissection of the boot floppy see [the boot.adf anatomy page](../boot-disks/anatomy-boot-adf.md); for partition/filesystem detail see [filesystems and disks](filesystems-and-disks.md); for how a fresh kernel gets built and installed see [kernel build and install](../drivers/kernel-build.md).

## The short version

1. **Power-on → Superkickstart 1.4 ROM.** Default action boots Amix from the SCSI hard disk (or a boot floppy in DF0). Hold the **right mouse button** at power-on to load the AmigaOS Kickstart instead ✅.
2. **Bootblock → 68k bootstrap.** The first sectors of the boot device are a valid AmigaDOS **OFS bootblock** (`DOS\0` + checksum + 68k code) so the ROM is willing to boot them ✅.
3. **Bootstrap loads + decompresses the kernel.** It reads the compressed kernel image, verifies its checksum, decompresses it into RAM, and jumps in. Failure paths print messages like `Kernel file checksum mismatch.` ✅.
4. **Kernel comes up** using the [68030 MMU / HAT layer](kernel-architecture.md), mounts root, and runs `init`.

On a real install, steps 2–4 read from the **2 MB boot partition** on the SCSI disk; during installation they read from the boot floppy instead, which carries a special NFS/RPC-capable install kernel (see [The install kernel](#the-install-kernel-on-bootadf)).

## Superkickstart and the dual-boot decision

Amix machines ship a special bootstrap ROM Commodore called **"Superkickstart 1.4"** ✅. It is what decides, at the very first instant of power-on, whether the machine becomes an AmigaOS box or a Unix workstation:

- **Default (no button):** boot Amix — from SCSI HD if present, otherwise from a boot floppy in DF0 ✅.
- **Right mouse button held at power-on:** load the normal AmigaOS Kickstart and boot AmigaOS ✅.

This is the canonical Amix "quirk" people remember: one machine, one button, two operating systems. It is documented as a hardware/firmware feature of the [A3000UX and A2500UX](hardware.md), not something Amix's own software does. See also the [quirks checklist](quirks.md) and [glossary entry for Superkickstart](glossary.md).

**Note:** The dual-boot choice is made before any disk is read, so it applies equally whether you intend to boot an installed system off the hard disk or a boot floppy.

## The bootblock and the 68k bootstrap

Once Superkickstart commits to Amix, it boots the boot device exactly the way AmigaOS firmware boots any floppy or RDB-bootable partition: it reads the **bootblock**, validates the `DOS` signature and checksum, and executes the 68k code that follows ✅.

What makes the Amix bootblock unusual is that **there is no AmigaDOS filesystem behind it**. The bootblock's 68k code is a self-contained secondary bootstrap; everything after it on the medium is raw bootstrap code plus the (compressed) kernel payload, not files in an AmigaDOS directory tree ✅. This is why ordinary AmigaDOS tooling can read the bootblock but not "list" the disk — see [our evidence below](#what-the-real-bootadf-actually-contains).

The bootstrap's responsibilities:

- Identify and read the boot volume (string `Load boot volume %d` ✅).
- Locate the compressed kernel image (string `unix.` ✅).
- Verify the kernel's checksum, decompress it into RAM, and transfer control.

## Kernel decompression and checksum verification

The on-medium kernel is **compressed and checksummed**; the bootstrap decompresses it at boot time rather than loading a flat executable ✅. The diagnostic strings embedded in `amix_21_boot.adf` map the failure modes one-to-one:

| Embedded string ✅ | Meaning |
|---|---|
| `Load boot volume %d` | Bootstrap is selecting/reading the boot volume |
| `Decompression failed!` | The compressed kernel could not be unpacked |
| `WARNING! Kernel decompression overrun.` | Decompressed image exceeded its expected size |
| `WARNING! Kernel file checksum mismatch.` | Stored checksum != computed checksum |
| `Kernel may have been corrupted.` | Follow-up to a checksum/decompression failure |
| `hat_vtokp_prot: user addr in kernel space` | An SVR4 **HAT/MMU** panic message (kernel is now running) |

Because the kernel is compressed, a raw scan of the boot floppy finds **no clean ELF header** — only noise and false-positive matches — which is exactly what you expect from a compressed blob rather than a stored executable ✅. The presence of the `hat_vtokp_prot` HAT panic string confirms the decompressed payload is a real SVR4 kernel using the [68030 MMU / HAT layer](kernel-architecture.md).

## On-disk layout: the RDB and the partition table

An installed Amix disk uses the Amiga **Rigid Disk Block (RDB)** partitioning scheme — the same on-disk metadata format AmigaOS uses to describe a SCSI/IDE drive's geometry and partitions ✅. Amix slots its Unix partitions into RDB partition entries so the Superkickstart ROM can find and boot them.

The installer's **default partition layout** is four partitions ✅:

| Partition | Purpose | Notes |
|---|---|---|
| `/` (root) | Root filesystem | s5 or UFS; UFS recommended, installer defaults `ANS="ufs"` ✅ |
| swap | Paging/swap | Larger when the disk is bigger than `BREAKPT=120` MB ✅ |
| **boot** | Holds the bootable kernel image | **2 MB**, fixed by `BOOTSIZE` (see below) ✅ |
| data | Remaining user space | Keep partitions ≲1 GB 🟡 |

**Warning:** The hardware addressing is rigid — the SCSI **hard disk must be ID 6** and the **tape must be ID 4**; both are hard-coded in the kernel and install scripts (e.g. `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` in the install scripts) ✅. Also keep total Fast RAM ≤ **16 MB**: the kernel hard-codes that ceiling and **>16 MB mis-maps the SCSI drive** ✅. Both are covered in [hardware](hardware.md) and the [quirks checklist](quirks.md).

🔴 The exact **RDB partition type IDs** Amix uses to tag the boot vs swap vs UFS partitions are not documented in any source we hold — treat any specific type-ID claim as unverified.

### The 2 MB boot partition and BOOTLEN

The boot partition is intentionally tiny and exists only to hold the kernel image where the bootstrap can reach it. Its size is fixed by the installer at **2 MB**, and the block count is derived from that ✅:

```sh
# From the root.adf install scripts (✅):
BOOTSIZE=2                      # boot partition size in MB
BOOTLEN=$((BOOTSIZE * 2048))    # length in 512-byte blocks => 4096 blocks
```

So `BOOTLEN = BOOTSIZE * 2048 = 4096` blocks of 512 bytes = 2 MB ✅. This is the partition that `make bootpart` writes the kernel into (next section). It is separate from the AmigaOS-readable bootblock concept on the floppy — on the hard disk, the RDB marks this partition bootable and the ROM bootstrap reads the kernel out of it.

## From kernel source to a bootable partition

Amix is a **monolithic SVR4 kernel with no loadable modules** — drivers are statically linked in — so installing a new kernel (or a kernel with an added driver) means relinking `/unix` and rewriting the boot partition ✅. The flow, from the [Ditto driver paper](../reference/bibliography.md) and the modern driver repos:

```sh
# 1. Build the kernel in the kernel source tree.
cd /usr/sys
make                        # produces the kernel image

# 2. Stage it, then write it to the 2 MB boot partition.
cp relocunix /stand
cd /stand
make bootpart KERNEL=relocunix

# 3. Reboot into the new kernel.
shutdown -i6
```

### rdbunix vs relocunix (a historical rename) 🟡

The name of the kernel image changed over the life of the project:

- The **1990 Ditto paper** calls the built kernel image **`rdbunix`** ✅ (as cited in the paper).
- **Amix 2.1 systems and the modern driver repos** call it **`relocunix`** ✅, and the `make bootpart` invocation is `make bootpart KERNEL=relocunix` ✅.

Treat this as a **historical rename** and verify per version — `rdbunix` for the 1990-era toolchain, `relocunix` for 2.1 🟡. The hydra cross-compile path uses a related `make oldboot KERNEL=…` target after converting an ELF kernel with `elf2brel`; see [kernel build and install](../drivers/kernel-build.md) and [the hydra case study](../drivers/case-studies/hydra.md).

**Note:** Always keep the old working `/unix` (or boot partition image) as a fallback before writing a freshly built kernel — a broken boot partition means a machine that won't come up ✅.

## The install kernel on boot.adf

During installation the kernel does **not** come from the hard disk's boot partition — it comes from the boot floppy (`amix_21_boot.adf`) in DF0. That floppy carries a special **NFS/RPC-capable install kernel** ✅: alongside the decompression/checksum strings, the bootstrap region contains a full **RPC/NFS client string table**, consistent with an installer that can pull the distribution over the network as well as from tape. The normal end-to-end install sequence (boot floppy → UFS miniroot on `root.adf` → tape at SCSI ID 4 → `make bootpart` → reboot) is described in [filesystems and disks](filesystems-and-disks.md) and the [install walkthrough](../getting-started/install-walkthrough.md).

## What the real boot.adf actually contains

Everything below is reproduced from our own read-only analysis of `amix_21_boot.adf` using [`tools/inspect-adf.sh`](../boot-disks/anatomy-boot-adf.md) ✅. (The ADF itself is proprietary Commodore material; obtain it from [amigaunix.com](https://www.amigaunix.com/) or archive.org — do not commit it.)

Run the inspector against your own copy:

```sh
tools/inspect-adf.sh sources/floppy/amix_21_boot.adf
```

What it reports, and what each finding means:

- **It is a valid AmigaDOS OFS bootblock.** The first bytes are `44 4f 53 00` = `DOS\0`, followed by the bootblock checksum and 68k bootstrap code — so the Superkickstart ROM is willing to boot it ✅.
- **There is no AmigaDOS filesystem.** `xdftool list` fails with `Invalid Root Block @880`, because the disk is *bootblock + raw bootstrap + payload*, not an AmigaDOS directory tree ✅.
- **The kernel is compressed and checksummed.** The embedded strings (`Decompression failed!`, `WARNING! Kernel file checksum mismatch.`, `unix.`, etc. — full table [above](#kernel-decompression-and-checksum-verification)) show the bootstrap decompresses and checksum-verifies the kernel ✅.
- **It is an NFS/RPC install kernel.** A full NFS/RPC client string table and the `hat_vtokp_prot: user addr in kernel space` HAT/MMU panic string are present ✅.
- **No clean ELF, only noise.** A binwalk scan finds no clean ELF header (only false-positive "JBOOT" hits) — exactly what a compressed kernel blob looks like ✅.

For the full byte offsets, the equivalent root/patch-disk findings, and how to read the inspector output, see [the boot.adf anatomy page](../boot-disks/anatomy-boot-adf.md).

## See also

- [Anatomy of the boot ADF](../boot-disks/anatomy-boot-adf.md) — byte-level dissection of `amix_21_boot.adf`.
- [Filesystems and disks](filesystems-and-disks.md) — RDB, s5 vs UFS, swap, and the full partition story.
- [Kernel architecture](kernel-architecture.md) — the monolithic SVR4 kernel, HAT/MMU layer, switch tables.
- [Kernel build and install](../drivers/kernel-build.md) — `make` → `relocunix` → `make bootpart` in detail.
- [Hardware and requirements](hardware.md) — Superkickstart ROM, SCSI ID 6/ID 4, the 16 MB ceiling.
- [Quirks checklist](quirks.md) — the dual-boot button and other surprises in one place.
- [Install walkthrough](../getting-started/install-walkthrough.md) — running the whole flow under emulation.

## Sources

- Research brief §3 (Boot process & disk layout) and §10 (boot.adf anatomy), `sources/research-brief.md`.
- `amix_21_boot.adf` analysis via [`tools/inspect-adf.sh`](../boot-disks/anatomy-boot-adf.md): `DOS\0` OFS bootblock, failed `xdftool list` (`Invalid Root Block @880`), kernel decompression/checksum strings, NFS/RPC string table, `hat_vtokp_prot` HAT panic string, no clean ELF.
- `amix_21_root.adf` install scripts (via `tools/inspect-adf.sh`): `BOOTSIZE=2`, `BOOTLEN=BOOTSIZE*2048`, `BREAKPT=120`, `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}`, default `ANS="ufs"`.
- Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (the `rdbunix` kernel image name; statically linked monolithic kernel; `make` in `/usr/sys`).
- Modern driver repos for the `relocunix` / `make bootpart KERNEL=relocunix` flow: <https://github.com/asokero/va2000-amix>, <https://github.com/isoriano1968/hydra-amix>.
- amigaunix.com (Superkickstart dual-boot via right mouse button, hardware requirements): <https://www.amigaunix.com/>.
