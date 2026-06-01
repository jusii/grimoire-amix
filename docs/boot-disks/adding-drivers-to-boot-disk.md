---
title: Adding Drivers to a Custom Boot Disk
summary: Strategies for shipping extra hardware drivers in a custom boot/install disk — what works today and what is still an open reverse-engineering problem.
status: draft
---

# Adding Drivers to a Custom Boot Disk

If you want an extra hardware driver available on an Amix machine, **there are two completely
different surfaces** and they are not equally tractable:

1. **The on-HD boot partition** — *well understood.* You relink the driver into the kernel via
   `/usr/sys` and write the result into the boot partition with `make bootpart`. This is the normal,
   supported path and it works today. ✅
2. **The boot/install *floppy* (`boot.adf`)** — *not fully reverse-engineered.* The kernel on that
   floppy is **compressed and checksummed inside a raw bootstrap image with no AmigaDOS
   filesystem**, so regenerating a custom boot floppy with your driver baked in is an open problem.
   🔴

Because of that asymmetry, the realistic way to *ship* an add-on driver to other users is **not** a
modified boot floppy at all. It is a **self-extracting add-on disk** modeled on the real Amix 2.1
patch disk: a small `/sbin/sh` header followed by a cpio archive that drops your driver `.o` and an
installer onto a running system, then relinks the kernel. That model is described below and is what
[`tools/build-custom-bootdisk.sh`](../../tools/build-custom-bootdisk.sh) implements.

This page is the strategy/decision page. For the mechanics it points to:

- [Building & installing a kernel](../drivers/kernel-build.md) — the `/usr/sys` relink + `make bootpart`.
- [Anatomy of the boot ADF](anatomy-boot-adf.md) — why the floppy is hard.
- [Anatomy of the patch ADF](anatomy-patch-adf.md) — the self-extracting model we copy.
- [The build pipeline](build-pipeline.md) — end-to-end tooling.

## Why "boot disk" is two different problems

Amix boots from one of two places ✅:

- **A SCSI hard disk** with an Amiga [Rigid Disk Block (RDB)](../how-it-works/filesystems-and-disks.md)
  layout that includes a dedicated **2 MB boot/bootstrap partition** (`BOOTSIZE=2` MB →
  `BOOTLEN = BOOTSIZE*2048` blocks, from the root.adf install scripts). ✅
- **A boot floppy** (`boot.adf`) used for installation and recovery. ✅

The Superkickstart ROM boots from SCSI HD by default, or from a boot floppy in DF0; right-clicking
at power-on loads AmigaOS instead ✅. See the [boot process](../how-it-works/boot-process.md) page
for the full chain.

The HD boot partition and the boot floppy carry *the same kind of payload* — a compressed,
checksummed kernel plus a 68k bootstrap — but the HD path has a **supported tool to rewrite it**
(`make bootpart`) and the floppy path does not. That is the entire reason this page exists.

## Surface (a): the on-HD boot partition — supported, do this

This is just the normal kernel rebuild. A driver in Amix is **statically linked into a monolithic
kernel; there are no loadable modules** ✅, so "adding a driver to the boot partition" means
"relink the kernel and write it to the boot partition."

The full procedure is [Building & installing a kernel](../drivers/kernel-build.md); the short
version, run on a live 2.1 system as root ✅:

```sh
cd /usr/sys
# 1. put your driver .o in its subdir, add it to that subdir's Makefile,
#    and register it in master.d/kernel.c (cdevsw[]/bdevsw[], int2_tbl[], io_init[]).
# 2. clean stale objects, then relink
rm -f amiga/config/unix.o master.d/exp unix     # avoid linking a stale kernel
make                                            # -> relocunix
# 3. install the new kernel AND rewrite the boot partition
cp relocunix /stand
make bootpart KERNEL=relocunix
# 4. create the device node, then reboot
mknod /dev/<name> c <major> <minor>
shutdown -i6
```

Notes that matter for getting it right:

- The kernel image is called **`relocunix`** on 2.1 systems and in the modern repos; the 1990 Ditto
  paper calls the equivalent image **`rdbunix`** — a historical rename, so match what your version
  produces. 🟡
- `make bootpart KERNEL=relocunix` is what actually **writes the boot partition** from the staged
  kernel ✅. This is the step that makes the driver "live in the boot disk."
- **Always keep the old `/unix` / boot kernel as a fallback** — a bad relink can leave the machine
  unbootable; the paper makes this explicit ✅.
- Amix `/bin/sh` is **pre-POSIX** (no `$(...)`, no `grep -q`) ✅ — if you script the `kernel.c`
  edits, use backticks and `>/dev/null`. This is a real install-script gotcha from the VA2000 work.

For a complete worked patch set that does exactly this — patching `amiga/driver/Makefile`,
`master.d/kernel.c`, then `make install` / `cp relocunix /stand` / `make bootpart` — see the
[VA2000 framebuffer case study](../drivers/case-studies/va2000.md) ✅. For a STREAMS/network driver
the link step differs (cross-compiled ELF converted with `elf2brel`, then `make oldboot`); see the
[Hydra network-driver case study](../drivers/case-studies/hydra.md) ✅.

**Bottom line:** if the machine already boots Amix, you do **not** need a custom floppy to add a
driver. Relink and `make bootpart`. The floppy problem below only matters for the *install/recovery*
media itself.

## Surface (b): the boot/install floppy — open RE problem 🔴

The boot floppy is genuinely hard, and we are honest about that here. From our own analysis of
`amix_21_boot.adf` (via [`tools/inspect-adf.sh`](../../tools/inspect-adf.sh)) ✅:

- It begins with a valid **AmigaDOS OFS bootblock**: bytes `44 4f 53 00` (`DOS\0`), a checksum,
  then 68k bootstrap code — enough for the Kickstart ROM to boot it. ✅
- **There is no AmigaDOS filesystem on it.** `xdftool list` fails with `Invalid Root Block @880`;
  the disk is bootblock + raw bootstrap + payload, not a mountable AmigaDOS volume. ✅
- The bootstrap **loads and decompresses a kernel with checksum verification.** The embedded strings
  prove it: `"Decompression failed!"`, `"WARNING! Kernel decompression overrun."`,
  `"WARNING! Kernel file checksum mismatch."`, `"Kernel may have been corrupted."` ✅
- `binwalk` finds **no clean ELF** in the payload, only noise / false-positive "JBOOT" hits —
  consistent with the kernel being **compressed**. ✅

So to regenerate a custom boot floppy with your driver in it, you would have to reproduce, in order,
all of:

1. The **compression format** the bootstrap expects (unknown — not a clean gzip/LZ signature that
   our tooling recognizes). 🔴
2. The **checksum algorithm and where the expected value is stored** (the bootstrap verifies a
   "kernel file checksum"; the algorithm is not documented). 🔴
3. The **on-disk layout** the bootstrap uses to find the payload (no AmigaDOS FS, so it is raw
   offsets, not files). 🔴
4. A correct **AmigaDOS OFS bootblock** with valid checksum so the ROM will boot it (this part is a
   known, documented format — the *only* easy step). ✅

Steps 1–3 are **not fully reverse-engineered**. Until they are, you cannot mechanically build a
`boot.adf` that boots your own kernel. Treat any claim that a custom Amix boot floppy "just works"
as 🔴 unless it shows the compression + checksum recipe.

> **Note:** This is specifically about the *floppy*. The HD boot **partition** has the same payload
> shape but a supported writer (`make bootpart`) ✅, which sidesteps every problem above. Whatever
> `make bootpart` does to compress + checksum is encapsulated in the (object-only) build tooling
> that ships with Amix — we get the result without reproducing the format. That is why surface (a)
> is solved and surface (b) is not.

See [Anatomy of the boot ADF](anatomy-boot-adf.md) for the full byte-level breakdown.

## The realistic path: a self-extracting add-on disk

The right way to *distribute* a driver to other users is the **patch-disk model** ✅, not a modified
boot floppy. The real Amix 2.1 patch disk (`amix_21_patch.adf`) is a self-extracting hybrid we have
**fully decoded** ✅, and it is a clean template for an add-on/driver disk.

Its structure ✅ (full detail in [Anatomy of the patch ADF](anatomy-patch-adf.md)):

- **Offset 0:** a `#!/sbin/sh` header script, with the comment `# THIS FILE 1024 CHARACTERS MAX` —
  i.e. the header is constrained to the **first 1 KB**.
- **After byte 1024:** a single **SVR4 ASCII cpio (`070701`) archive** of the payload (the patch
  ships `var/patch/…` members, including an `apply` script and an LHA payload).

The header script's core is the self-extraction idiom ✅:

```sh
QUIETDD=y dd if="$0" bs=1k iseek=1 2>/dev/null | (cd /; QUIETCPIO=y cpio -icdmuv)
uncompress -f /var/patch/*.Z
exec /var/patch/apply
```

It reads its **own image** (`$0`), skips the 1 KB header (`iseek=1` at `bs=1k`), and pipes the rest
into `cpio` to extract the payload into the filesystem, then runs the bundled installer. The real
patch disk also gates on identity and version before doing anything ✅: it requires `uid=0(root)`
and greps the live `uname -v` for `^2\.1.* 08004..$` (else it prints "USE AT YOUR OWN RISK").

**To ship a driver this way**, your payload's installer does the surface-(a) work: drop the driver
`.o` into `/usr/sys`, patch the Makefile and `master.d/kernel.c`, relink, `make bootpart`, `mknod`,
and tell the user to reboot. The disk is just a delivery vehicle; the actual install is the kernel
relink described above.

### Recommended workflow today

1. Build and **test the driver the manual way first** — relink it into a live system's boot
   partition per [Building & installing a kernel](../drivers/kernel-build.md). Do not automate
   anything you have not done by hand once.
2. Author an **installer script** that performs those exact steps non-interactively. Keep it
   **pre-POSIX-shell-safe** (backticks, no `$(...)`, no `grep -q`) ✅ and keep the on-disk header
   under **1024 bytes** ✅.
3. Lay out a **payload directory** whose contents extract under `/` (e.g. `var/addon/install` for
   the installer, plus your driver source/`.o`).
4. Build the self-extracting image with
   [`tools/build-custom-bootdisk.sh`](../../tools/build-custom-bootdisk.sh):

   ```sh
   tools/build-custom-bootdisk.sh \
       --payload ./payload \
       --out my-driver-addon.adf \
       --install var/addon/install
   ```

   The tool writes the ≤1 KB `/sbin/sh` header, appends a `newc` cpio of the payload, pads to floppy
   size, and **self-tests the structure** (it lists the cpio members back via
   `dd … skip=1 | cpio -it`). ✅
5. **Verify in an emulator** before trusting it. The generated image is structure-validated on the
   host but **UNTESTED on real Amix** 🟡 — boot a known-good Amix in
   [WinUAE](../getting-started/emulation-winuae.md) or
   [FS-UAE](../getting-started/emulation-fs-uae.md) and run the disk through.

This add-on disk is **not** a boot floppy — it runs *on* an already-installed, already-booted Amix.
It deliberately avoids the compressed/checksummed kernel format entirely, which is exactly why it
works while a custom `boot.adf` does not.

### What this approach does and does not solve

| Goal | Status | How |
|---|---|---|
| Add a driver to a running system's boot partition | ✅ works | relink + `make bootpart` ([kernel-build](../drivers/kernel-build.md)) |
| Ship a driver to other users to install | ✅ works | self-extracting add-on disk (patch-disk model) |
| Make a custom **bootable/installer** floppy with your kernel | 🔴 open | needs the boot.adf compression + checksum format |
| Replace the install kernel on the floppy | 🔴 open | same blocker |

## Open reverse-engineering problems

These are the gaps that stand between us and a fully custom boot/install floppy. Carry them as 🔴:

- **boot.adf kernel compression format** — the bootstrap decompresses the kernel, but the
  compression scheme is unidentified (`binwalk` sees only noise). 🔴
- **boot.adf kernel checksum** — algorithm and the location of the stored expected value are
  undocumented; the bootstrap explicitly checks a "kernel file checksum." 🔴
- **boot.adf payload layout** — with no AmigaDOS filesystem, the bootstrap finds the kernel by raw
  offset/structure that is not yet mapped. 🔴
- **What `make bootpart` actually emits** — it clearly produces the compressed+checksummed boot
  payload, but it relies on object-only Amix build tooling; the format is consumed, not reproduced,
  by us. Documenting its output would also crack the floppy problem. 🔴
- **Exact RDB partition type IDs Amix uses** (boot vs swap vs UFS) are not documented, which matters
  if you ever script creation of a boot partition from scratch rather than letting the installer do
  it. 🔴

If you reverse-engineer any of these, that is the missing piece for a genuinely custom Amix install
floppy — please contribute it back.

## See also

- [Building & installing a kernel](../drivers/kernel-build.md) — the relink + `make bootpart` you
  automate.
- [Anatomy of the boot ADF](anatomy-boot-adf.md) — why the floppy is the hard surface.
- [Anatomy of the patch ADF](anatomy-patch-adf.md) — the self-extracting model this page copies.
- [The build pipeline](build-pipeline.md) — end-to-end disk-building tooling.
- [VA2000 framebuffer case study](../drivers/case-studies/va2000.md) — a real driver relinked into a
  boot partition.
- [Hydra network-driver case study](../drivers/case-studies/hydra.md) — a cross-compiled STREAMS
  driver (`elf2brel`, `make oldboot`).

## Sources

- `amix_21_boot.adf` analysis via [`tools/inspect-adf.sh`](../../tools/inspect-adf.sh): OFS bootblock
  (`DOS\0` + checksum), no AmigaDOS FS (`xdftool` "Invalid Root Block @880"), kernel
  decompression/checksum strings, `binwalk` finding no clean ELF — research brief §3, §10.
- `amix_21_patch.adf` analysis: 1 KB `/sbin/sh` header, `# THIS FILE 1024 CHARACTERS MAX`, the
  `dd … iseek=1 | cpio -icdmuv` self-extraction idiom, SVR4 `070701` cpio payload — research brief §10.
- Kernel install flow (`/usr/sys` relink → `relocunix`/`rdbunix` → `cp /stand` →
  `make bootpart KERNEL=relocunix` → reboot) — research brief §3, §5, §6.
- Monolithic kernel, no loadable modules; static driver linking — research brief §4, §5.
- VA2000 and Hydra driver-install procedures — research brief §6; repos
  [`github.com/asokero/va2000-amix`](https://github.com/asokero/va2000-amix),
  [`github.com/isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix).
- RDB boot partition (`BOOTSIZE=2` MB / `BOOTLEN = BOOTSIZE*2048`), pre-POSIX `/bin/sh`,
  open-questions list — research brief §3, §6, §13.
- [`tools/build-custom-bootdisk.sh`](../../tools/build-custom-bootdisk.sh) (this repo) — the
  self-extracting add-on-disk builder described above.
- End-user/historical install media: [amigaunix.com](https://www.amigaunix.com/doku.php/home) and
  the Amix images on [archive.org](https://archive.org/details/commodore-amiga-operating-systems-amix).
