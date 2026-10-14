---
title: Composing Multi-Driver Kernels
summary: Why Amix kernels are built one-per-root-storage-family instead of one universal all-drivers image — the SDCARDS/rootdev constraints, the driver admission checklist, and how finished kernels reach users.
status: draft
---

# Composing multi-driver kernels

Stock Amix has **no loadable kernel modules** — every driver is statically linked into the one
monolithic kernel image ✅ (see [Kernel architecture](../how-it-works/kernel-architecture.md), which
also notes [one third-party exception](../how-it-works/kernel-architecture.md#loadable-modules)).
So as the modern driver family grows (A4091, Z3660 SCSI/ethernet, cdfs, the community framebuffer
and net drivers), the obvious question is: **why not link them all into one universal kernel that
boots everything?**

Short answer: **you can — but only up to a point, and the point is storage.** Network, framebuffer
and filesystem drivers stack essentially without limit (each is just a `cdevsw[]`/`vfssw[]` slot with
no boot-time coupling). SCSI host adapters are different: the stock kernel caps them at **two**, picks
the *root* controller by **board-address sort order**, and compiles the root device in — so every
extra storage driver in one image is a way to lose the root disk. The working convention that fell
out of the A4091 and Z3660 projects is therefore **one kernel per root-storage family**, each folding
in all *admitted* non-storage drivers, with minimal single-purpose kernels for install media. This
page records the constraints, the convention, and the checklist a driver must pass before it is
admitted into a shared kernel.

## What limits a "universal" kernel

### Two SCSI controllers, ever — and it's baked into the minor numbers ✅

The `sd.c` selector registers detected controllers into a fixed table `queue[SDCARDS]` with
`SDCARDS = 2` — and that 2 is not just an array size. The `/dev` minor-number encoding itself has a
**one-bit card field** (verified against `amiga/alien/sd.h` on 2.1c ✅):

```c
#define SDCARDS         2                    /* only two SCSI cards: queue[0], queue[1] */
#define sdunit(dev)     ((dev) >> 0 & 07)    /* SCSI target id   0-7 */
#define sdcard(dev)     ((dev) >> 3 & 01)    /* card index -- only 0 or 1 */
#define sdpart(dev)     ((dev) >> 4 & 07)    /* slice / partition 0-7 */
```

A third detected controller is **silently dropped** with only a console message — `insert()`'s
overflow branch prints `sd: too many controllers` and discards the board ✅. Which two survive is
decided by *detection order* (the `scsicard[]` row order, then any direct-probe fallbacks), after
which the two survivors are index-sorted by base address. See
[the exact minor decode](../reference/device-list.md#exact-minor-decode-and-the-cn-computation)
in the device reference.

### Card 0 is decided by an address sort, and the root device is compiled in ✅

`sd.c init()` inserts detected controllers **sorted ascending by board base address**: the
lowest-addressed controller becomes card 0. The root device (`ROOTDEV`, typically `c6d0s1`) is
**compiled into the kernel** and decodes to **card 0** — so whichever controller wins the address
sort *is* the root controller, like it or not. Worse, the stock miniroot installer only scans
`c0…c7` (card-0 device names): a controller shifted to card 1 (`c8…c14`) is **invisible to the
installer** ✅.

This is not a theoretical hazard — it is exactly how both "phantom card" incidents broke boot:

- **The phantom A3000**: stock `autocon()` hard-faked an A3000 internal SCSI at `0xDD0000` whenever
  the kernel was loaded above `0x07000000` ([quirks §57](../how-it-works/quirks.md#57-loader-placement-a3000-scsi)), whether or not the hardware existed. On an A4000+A4091 the phantom claimed card 0,
  shoved the real A4091 to card 1, and the compiled-in root device pointed at nothing →
  `vfs_mountroot` panic ✅. Fixed by a chipset-gated probe — see
  [the A4091 case study](a4091-53c710-driver.md) and
  [Zorro AUTOCONFIG](zorro-autoconfig.md).
- **The phantom Z3660**: the Z3660 driver's fallback probe reads a **fixed base** (`0x10000000`);
  under Amiberry, unmapped addresses read as zero, which the probe took as a live board → phantom
  card 0, A4091 shifted to card 1, install disk invisible ✅.

Both phantoms surfaced as emulator open-bus artifacts (real hardware reads differ ✅) — **with one
real-hardware exception**: on an **A4000T** the phantom-A3000's `0xDD0000` is the machine's **onboard
NCR 53C710**, so stock `autocon()` hands the A3000 WD33C93 driver a real, different chip as card 0
(`c0`). On an A4000T with a Z3660, a kernel without the chipset-gated probe **hangs during boot**:
the stock `a3091` pokes `$DD0041`/`$DD0043` inside the uninitialised 710 window, nothing terminates
that local-I/O bus cycle (the Z3660 has no cycle timeout of its own), and the CPU waits on it forever
🟡 (measured on one A4000T + Z3660, 2 of 2 cold boots, 2026-09-28). A4000T kernels must carry the
chipset-gated fix; see [the Z3660 SCSI detection note](z3660-scsi-driver.md#detection-the-silent-hang-trap-and-multi-method-detect).
The structural lesson stands: **every storage driver added to a shared kernel multiplies the ways card 0 can be
stolen from the root controller.**

### Every absent-hardware probe path is boot-correctness surface

A driver in a shared kernel runs its detection logic on **every machine the kernel boots, including
all the machines that don't have the hardware**. Probes keyed on a Zorro AutoConfig product ID
(`autocon()`) are safe by construction — no board, no match ✅. Probes that touch **fixed addresses**
(the A3000's `0xDD0000`, the Z3660's `0x10000000`) must be explicitly gated (chipset check,
multi-register anti-alias readback) or they will false-positive on open bus ✅. The two phantom
postmortems above are the canonical examples of getting this wrong.

### Size: irrelevant to RAM, real for floppies — and DMA reach

Driver code is tens of KB against tens of MB of Fast RAM (16–64 MB on the 030 line depending on kernel and RAM layout, 128 MB on
the 040/060 kernels) — RAM footprint is a non-issue. Two
size effects *are* real:

- **The boot-floppy budget.** A floppy-boot kernel must fit *compressed* in roughly 868 KB
  (880 KB ADF minus the boot area) 🟡; the current single-HBA install kernel already leaves only
  ~160 KB of compressed headroom ✅. Universal kernels and boot floppies do not mix. See
  [Adding drivers to a custom boot disk](../boot-disks/adding-drivers-to-boot-disk.md).
- **The moved-buffer trap.** Growing the kernel moves static buffers. Adding ~64 KB (cdfs) once
  moved the RDB read buffer and produced a deterministic mountroot panic on the A3000 onboard SCSI
  with the stock `a3091` driver ✅. It is **not** a size threshold and **not** a DMA reach limit (a
  larger patched kernel boots; the emulated super-DMAC is 32-bit) — the cause is open, a stale data
  cache being the leading hypothesis 🔴. Fixed by the `a3091` chip-RAM bounce patch, but any large
  size delta on A3000-class hardware deserves a boot test. See
  [Building & installing a kernel](kernel-build.md).

### Licensing: kernel binaries (history, and the 2026-09-23 outcome)

Every Amix kernel links the stock Commodore object libraries under `/usr/sys` — so **every built
kernel image is Commodore-derived**, no matter whose drivers it carries ✅. *History (until
2026-09-23):* this project therefore held that a built kernel could not be published, and that a
"universal public install medium" was impossible on licensing grounds alone; the publishable artifact
was the **recipe** (driver source, build instructions, configuration — the va2000/hydra/zz9000
pattern), and each licensed Amix owner linked their own kernel. **Since 2026-09-23** that licensing
bar is lifted — Amiga Corporation's approval and the project owner's ruling, see
[`AGENTS.md` §5](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md#5-respect-the-licensing-boundary) — so publishing a kernel or an install medium is now a per-release owner
decision, not a licensing impossibility. The recipe-first pattern remains how the community
driver repos publish.

### The root card and the linked driver set are ONE decision ✅

A card stamp cannot rescue a kernel that does not have the matching driver linked: restamping root
to card 1 in a kernel whose controller registry holds only the stock rows indexes an **empty** slot,
and adding the driver without widening the registry's row-count bound leaves the added row never
scanned — the bound and the table it names are locked together ✅. And a relink pass that takes a
base kernel as an argument **inherits that base's root-storage family silently** — so the check
belongs at link time, reading **the artifact, never the build recipe**: decode the compiled-in root
device, resolve the registry and its row bound through the relocations that name them, assert
coherence, and let a build that knows its target rig declare what it requires (this queue function,
this card), failing closed on a base of the wrong family ✅. A build log that records what an
artifact hashes to, but not which controller it will mount root through, has not recorded the thing
a deploy decision turns on.

## The family-kernel convention

Recommended practice (guidance, not a fact claim about stock Amix):

**Build one installed-system kernel per *root-storage family* — not per driver, and not one
universal image.** A family is "the controller the compiled-in root device lives on". A family
kernel can fold in all *admitted* non-storage drivers, because those stack safely. For example, a
kernel that roots on an A4091 (with the fixed a3091/a2091 stock rows) can also carry cdfs; a kernel
that roots on the Z3660 piscsi mailbox (z3660scsi) can also carry z3660eth and cdfs.

> **Every** family kernel whose root device hangs off the A3000 onboard SCSI carries the patched
> `a3091.c`/`a2091.c` stock rows — it is not a property of the A4091 family. See
> [the bounce patch](kernel-build.md#the-a3000-onboard-scsi-dma-bounce-patch-nearly-every-kernel-needs-it) ✅.

- **Keep install kernels minimal**: source medium + target disk (+ net where the install needs it)
  + cdfs, nothing else. At install time an extra driver is pure probe risk with zero benefit.
- **Finished kernels can reach users as prebuilt whole-kernel packages** (`/stand/unix` +
  `/stand/boot2.boot` in an SVR4 package), made bootable by a separate boot-slice reframe step —
  the machine boots from the raw `UNI\0` slice, never `/stand/unix` directly ✅
  (see [How Amix boots](../how-it-works/boot-process.md)). "Installing a driver" therefore means
  *installing the family kernel package whose mix includes it*, then reframing.
- **On-box relinking is the stock-authentic alternative** — Amix ships `/usr/sys` as a relink kit
  and community drivers install that way ✅ — but it is only trustworthy **on real hardware**: under
  emulation the native `ld` intermittently corrupts its output (the D245 boot-breaker,
  emulation-only ✅; see [Building & installing a kernel](kernel-build.md)).



## The driver admission checklist

Before a driver is admitted into a shared family kernel, it must pass all five gates:

1. **Absent-hardware probe safety.** The probe must be proven safe on machines *without* the
   hardware, under both emulation open-bus behavior and real bus behavior. AutoConfig-ID probes
   pass by construction; fixed-address probes need a chipset gate and/or a multi-register
   anti-alias readback (the phantom-A3000 fix is the reference design ✅).
2. **No card-0 displacement.** A storage driver gets no `scsicard[]` row in a family kernel unless
   it provably cannot displace that family's root controller from card 0 (register only on positive
   identification; remember `SDCARDS = 2` and the address sort).
3. **Major number registered.** The driver's `cdevsw[]`/`bdevsw[]` major must be recorded
   collision-free in the [major-number registry](../reference/major-number-registry.md) — community trees have
   already collided on major 48 ✅.
4. **Size delta checked.** Against the A3000-class moved-buffer hazard (above) for installed-system kernels,
   and against the compressed floppy budget for any kernel that ships on a boot floppy.
5. **Boot-chain gates re-derived.** The kernel package's identity locks (kernel checksum, boot2
   loader identity) regenerated, and the result proven by an actual cold-boot cycle through the
   backup → install → reframe → reboot flow.

## Lifting the two-card limit: findings (desk analysis, 2026-07)

Two paths out of the storage constraints were costed (analysis, not implemented):

- **Bumping `SDCARDS` to 3–4 is invasive.** The card field in the minor number is one bit ✅, wedged
  between target (bits 0–2) and slice (bits 4–6), and all eight slices are in use — so a wider card
  field must either move above bit 6 (splitting the card index across non-adjacent bits) or re-lay-out
  the whole minor byte. Either way, **existing `/dev` nodes, `/etc/vfstab` entries, the `cN = card*8 +
  target` naming rule, and the installer's scan loops are all exposed to the change** — a
  userland-visible divergence from stock, unjustified while no supported machine carries three HBAs.
- **Root-by-identity is the cheap unlock.** Today the root controller is "whoever wins the address
  sort". Instead, the kernel build could bake a *root product ID* alongside `ROOTDEV` (the `sd.c` used
  in modern multi-driver kernels is already generated from a template, so this diverges no further
  from stock), and `init()` would pin the board matching that product ID to `queue[0]`, filling the
  other slot in address order. No minor-encoding change, no `/dev` fallout — and the entire
  phantom-card class stops being able to steal the root disk (a phantom could still waste the
  *second* slot). Limitations: still at most two registered controllers, and the installer still only
  scans card 0's names.

Neither is committed work; the family-kernel convention above deliberately avoids needing either.

## See also

- [The Amix device-driver model](driver-model.md) — switch tables, majors, how a driver plugs in.
- [Building & installing a kernel](kernel-build.md) — the relink kit, the D245 clean-gate, `make bootpart`.
- [Device & card reference](../reference/device-list.md) — the minor decode and the major-number registry.
- [Zorro AUTOCONFIG](zorro-autoconfig.md) — `autocon()`, board IDs, the phantom-A3000 story.
- [The A4091 case study](a4091-53c710-driver.md) — the universal two-machine kernel that proved gated probes work.
- [How Amix boots](../how-it-works/boot-process.md) — why `pkgadd` alone never changes the running kernel.

## Sources

- The **2026-09-29 stock-kernel RAM-layout measurement** ✅ — on the emulated bench the same 64 MB A3000 motherboard bank boots a kernel that probes for the A3000 SCSI and stops the pinned stock kernel at `s5mountroot VOP_OPEN error 6` (no card 0), symbolised against the stock `autocon()` load-address guess ([quirks §57](../how-it-works/quirks.md#57-loader-placement-a3000-scsi)).
- The **super-DMAC reach refutation** (2026-10-02) ✅ — the `64119` row of the kernel table on [building a kernel](kernel-build.md) (stock `a3091`, RDB buffer above `0x07000000`, boots) and Amiberry's `src/a2091.cpp` (the A3000 super-DMAC initialised with the 24-bit DMA mask off; `dma24bit` applies only to the add-on cards), read in the Amiberry source. The stale-cache explanation is a hypothesis 🔴.
- `amiga/alien/sd.h` macros (`SDCARDS`, `sdunit`/`sdcard`/`sdpart`), reproduced locally on Amix 2.1c ✅; the generated `sd.c` selector (`scsicard[]`, `init()`/`insert()` address-sorted registration, the `sd: too many controllers` overflow branch) as templated in the kernel build harness (first-party record, 2026-06-10).
- The A4091-on-Amix project — `NOTES.md` (phantom-A3000 root cause + chipset-gated probe fix; the anti-alias WD33C93 readback; the universal A3000/A4000 kernel) and `README.md`.
- The amix-kerntools project — [`README.md`](https://github.com/jusii/amix-kerntools/blob/master/README.md) (the D245 clean-gate, emulation-only); the install-kernel mixes, the A4091-only bench install kernel and the phantom-Z3660 card-shift note (first-party record, 2026-08-27) and the KERNBENCH/KERNZ3660 whole-kernel package contract (first-party record, 2026-08-19).
- The amix-installng project — `payload/updbootpart` + `docs/installer.md` (the gated backup → pkgadd → reframe → cold-boot kernel-upgrade flow, proven on A3000+A4091).
- [Building & installing a kernel](kernel-build.md) sources — the cdfs size-delta / super-DMAC mountroot panic (its reach explanation refuted 2026-10-02) ✅ and the relink-kit workflow.
- [Device & card reference](../reference/device-list.md) sources — stock and community major assignments, the cross-tree major-48 collision ✅.
- Floppy budget: [Adding drivers to a custom boot disk](../boot-disks/adding-drivers-to-boot-disk.md) (compressed-kernel budget 🟡) and the `fd0unix` headroom measurement (first-party record, 2026-08-16) ✅.
- The **A4000T `$DD0000` reading** (first-party record, 2026-09-24): the shipped 060 kernel's unstripped `autocon()` disassembly plus the stock `support.c`/`sd.c`/`a3091.c` — the load-address phantom at `0xDD0000` sorting as card 0; on an A4000T that window is the onboard NCR 53C710. The boot hang of a kernel without the chipset-gated probe on an A4000T + Z3660 (2 of 2 cold boots; first-party record, 2026-09-28) and the unterminated local-I/O cycle behind it (the Z3660 CPLD waits for `DSACK`/`AVEC`/`BERR` with no timeout): amix-a4091 [`docs/A4000T-ONBOARD-710.md`](https://github.com/jusii/amix-a4091/blob/master/docs/A4000T-ONBOARD-710.md) §2 🟡.
