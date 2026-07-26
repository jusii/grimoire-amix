---
title: The Amix RAM Ceiling
summary: Why Amix cannot describe much more than ~128 MB of RAM, what the failure looks like (a silent wild write from address 0, not a panic), and how much memory to actually present in emulation and on metal.
status: draft
---

# The Amix RAM Ceiling

**Give an Amix guest too much memory and it does not complain — it dies silently before the console
exists.** ✅ The kernel's `page_init()` allocates one ~60-byte `page` record per physical page frame
out of the kernel virtual map, **never checks the allocation for NULL**, and on failure walks that
60-byte stride from **physical address 0** instead: straight across chip RAM, Zorro II I/O space,
the CIAs and the custom chipset. There is no panic, no Guru, and **no console output at all** ✅.

Two limits live on this page, and they are **not the same limit**:

| Limit | Value | What goes wrong past it | Tag |
|---|---|---|---|
| **Fast RAM configuration ceiling** | **16 MB** | The SCSI drive is mis-mapped — presents as a disk fault | ✅ |
| **Total describable RAM** | **≈128 MB (computed)** | `page_init()` wild-writes from address 0 — total silence | ✅ mechanism / 🔴 exact figure |

Set your emulator, your accelerator and your memory map to the **16 MB Fast RAM** rule and neither
one can bite you. The rest of this page is for when something has already handed the guest more
memory than you meant to — a debug/DDR window, a Zorro III RAM board, an accelerator's onboard
memory — and you are staring at a machine that produces nothing.

## The short version

- **Cap the RAM you present.** 4–16 MB of Fast RAM is the supported envelope; see
  [hardware and requirements](hardware.md#fast-ram-4-mb-minimum-16-mb-hard-ceiling). ✅
- **32 MB total is the largest value with positive boot evidence** on any rig here, and it exists
  only because one bench rig needs RAM at `0x08000000` for a DMA-threshold reason. ✅
- **528 MB is proven fatal**, in exactly the way described below. ✅
- **Nothing between 32 MB and 512 MB has ever been booted** — the ≈128 MB figure is *computed*, not
  bisected. Do not quote it as a tested boundary. 🔴
- **This is a kernel limit, not an emulator bug.** Any route that hands the guest memory reaches the
  same code — emulator RAM knobs, a Zorro III fastmem board, accelerator DDR. ✅

## What actually happens past the ceiling

Everything in this section is ✅ — it was read live out of a running emulator (see
[Provenance](#provenance-how-this-was-measured)).

The kernel sizes a `struct page` array from the total RAM the boot path reports, at **60 bytes per
page frame**, and asks the kernel virtual map for the space:

```text
528 MB of RAM
  -> 252,707 free page frames
  -> a 15,162,420-byte page[] array
  -> against ~4 MB of kernel virtual map still free
  -> rmalloc() returns NULL
  -> the result is never checked, at either level
  -> page_init(NULL, 252707, ...) runs anyway
```

`page_init()` then does what it always does — walk the array setting a bit in each record — except
the array now starts at physical address `0x00000000`:

```text
080c0208:  orib   #-128,%a0@        ; set bit 7 of this "page record"
080c020c:  addaw  #60,%a0           ; next record, 60 bytes on
080c0210:  cmpal  8129e74,%a0       ; ... until epages
080c0216:  bcsw   80c0208
```

The walk runs from `0x00000000` to `0x00E75C34`. Along the way it crosses chip RAM, **Zorro II I/O
space** (`0x00b8xxxx`), the CIAs and the custom chipset registers — writing to hardware, not memory.
The machine is dead long before console initialisation, which is why the symptom is silence. ✅

The memory *sizing* was correct throughout: measured `maxpfn` was `0x50000` (× 2048 = `0x28000000`),
the true top of RAM. The kernel knew exactly how much memory it had — **it simply could not describe
that much**. ✅

### Where ≈128 MB comes from — and why it is a bound, not a boundary

The kernel virtual map free list held **one** entry at the time of failure: 2048 pages of 2048 bytes
= 4 MB. Break-even is therefore about `2048 × 2048 ÷ 60 ≈ 69,900` describable frames ≈ **136 MB**,
and the same allocation also has to cover the page-table array — so the practical ceiling lands
around **128 MB of total RAM**. ✅ (the arithmetic; the inputs are measured)

**Treat that number as an order of magnitude, not a tested edge.** 🔴 No boot has been attempted
between 32 MB (works) and 512 MB (fatal), so the true boundary has never been bisected, and the free
map size is itself a function of how much kernel virtual space the running kernel has already spent
— a bigger kernel moves the line. The two numbers you can rely on are the measured ones: **32 MB
boots, 528 MB kills.** ✅

## Recognising it

The failure has no error message, so recognise it by shape ✅:

- **Zero guest output.** No SVR4 banner, no memory line, black screen, no serial log. It presents
  identically to a dead driver, a mis-built kernel, or missing hardware — this cost one project a
  weeks-long "early hang" investigation attributed to a SCSI driver.
- **In an emulator log** (Amiberry/WinUAE style host logging), a storm of bus-timeout messages at
  low Zorro II addresses from a single PC pair, with a constant **stride of 0x3C (60)**:

  ```text
  Gary timeout: 00b80038 0 R PC=080c0208
  Gary timeout: 00b80038 0 W PC=080c020c
  Gary timeout: 00b80074 0 R PC=080c0208     <- +0x3C
  ```

  Followed by blitter/`BEAMCON0`/"disk DMA started" noise as the walk reaches the custom chipset.
- **The arithmetic check:** the first faulting address is an exact multiple of 60 (`0x00B80038 ÷ 60
  = 200,978`), which is the fingerprint that the walk started at address 0 rather than at a real
  array. ✅

**Rule of thumb:** if an Amix guest emits *nothing at all* on a configuration you just gave more
memory to, suspect the memory before the driver, the kernel or the disk. ✅

## How much RAM to present

### In emulation

Uniformly ✅ unless tagged.

| Knob | Value | Why |
|---|---|---|
| Chip RAM | 2 MB (4 MB on the A4000-style rigs) | Standard; not counted against the Fast RAM rule |
| Fast / motherboard RAM | **16 MB, exactly** | The supported ceiling; 16 MB *exactly* is proven clean, and less than 8 MB livelocks under package-install workloads |
| A debug/DDR window (e.g. a stand-in for accelerator memory) | **32 MB** if you need one at all | The only oversized value with positive boot evidence |
| Zorro III fastmem board | avoid | It is AutoConfig RAM counted straight from the memory list, so it reaches the ceiling faster than a mapped window 🟡 |

A window that is *not* an AutoConfig RAM board can still be counted: if it lands immediately above
the machine's motherboard RAM, the A3000 Kickstart's motherboard-RAM sizer walks upward across both
and publishes them as **one contiguous region**, which Amix then believes. That is faithful ROM
behaviour, not an emulator defect ✅ — the guest simply cannot describe the result.

See the per-emulator config tables in [WinUAE](../getting-started/emulation-winuae.md),
[FS-UAE](../getting-started/emulation-fs-uae.md) and
[Amiberry](../getting-started/emulation-amiberry.md).

### On real hardware

The same kernel code runs, so the same limit applies to a real memory map ✅. In practice the
supported machines cannot reach it with motherboard RAM alone — the exposure is expansion:

- **Accelerator memory.** The Z3660's Amix-interop firmware mode hard-wires a single 16 MB window at
  compile time and maps a dummy bank above it so nothing can coalesce past the ceiling; the same
  mode disables the accelerator's large CPU-RAM board ✅. That is what a *correct* accelerator
  memory map looks like for Amix. See [real hardware](../getting-started/real-hardware.md).
- **Zorro III RAM boards.** AutoConfig RAM is counted directly, and a modern board can be far larger
  than anything Amix can describe.

### Why the folklore says "chip RAM plus 4–16 MB and nothing exotic"

Because that envelope is the one that always fits ✅. The period advice was empirical — nobody in
1992 had a memory map large enough to *reach* the `page_init()` failure, and everything at or below
16 MB Fast RAM works. The mechanism on this page is what sits underneath the folklore; it does not
replace the 16 MB rule, and it is **not** the explanation for the 16 MB rule's own failure mode
(mis-mapping the SCSI drive — a separate, older, separately-verified claim ✅).

## Provenance — how this was measured

✅ throughout, by measurement rather than by reading source (no Amix kernel source exists for this
code path — see [reverse-engineering the kernel](../drivers/kernel-reverse-engineering.md)):

1. The emulator logs each memory bank's host base address, so guest memory is addressable through
   `/proc/<pid>/mem` on the host. Guest code at the faulting PC was pulled out that way and
   disassembled with `m68k-cbm-sysv4-objdump -b binary -m m68k:68030`. **No debugger, no guest-side
   instrumentation, no emulator patch.**
2. The function was identified by the strings the compiler left beside it: `"page_init"` and
   `"vm_page.c"`, plus the assertion text `"pp >= pages && pp < epages"`.
3. Live globals at the hang: `pages = 0x00000000` (the NULL base), `epages = 0x00E75C34`
   (= 60 × 252,707), `maxpfn = 0x50000`.
4. **Discriminator:** a freshly built, leaner kernel containing a completely different driver set
   reproduces the fault byte-for-byte at the same RAM size — same first address, same 0x3C stride,
   same instruction pair, same NULL base. The driver mix is irrelevant, as it must be for a fault in
   VM initialisation.
5. **Control:** the same kernels and the same disk images boot normally — one to `vfs_mountroot`,
   one all the way to `/sbin/init`, and one to a full multiuser `login:` — once the memory window is
   bounded. Six boots, one variable at a time.

## See also

- [Hardware and requirements](hardware.md) — the 16 MB Fast RAM rule in its full context, plus the
  CPU/MMU/FPU and SCSI-ID limits.
- [Quirks and gotchas](quirks.md) — the ceiling as a one-line checklist item.
- [Kernel architecture](kernel-architecture.md) — the HAT/MMU layer this memory description feeds.
- [Emulation fidelity](emulation-fidelity.md) — the *other* class of silent Amix boot failure, where
  the emulator is at fault rather than the configuration.
- [Reverse-engineering the kernel](../drivers/kernel-reverse-engineering.md) — the technique used to
  read this mechanism out of a binary-only kernel.

## Sources

- `sources/research-brief.md` §2 (hardware envelope: 4–16 MB Fast RAM) and §4 (kernel HAT/MMU, RAM
  ceiling) — grounding for the 16 MB configuration rule.
- The **amix-kerntools** root-cause investigation, 2026-07-26 (`docs/kernel-52550-hang.md`, commit
  `7cdcdc9`): the live `/proc/<pid>/mem` read of a running guest, the `page_init()`/`rmalloc()`
  disassembly and live globals (`pages` = 0, `epages` = `0x00E75C34`, `maxpfn` = `0x50000`), the
  kernel-virtual-map free entry (2048 pages × 2048 B), the break-even arithmetic, the SCSI-only
  discriminator kernel reproducing the fault byte-for-byte, and the six-run ablation table ✅.
- The **amiberry** guest-RAM sizing note (`docs/z3660-amix-guest-ram.md`): the operational rule
  (32 MB is the only oversized value with positive boot evidence; the same cap applies to every knob
  that hands the guest memory, and a Zorro III fastmem board reaches the ceiling faster because it
  is AutoConfig RAM) ✅.
- The **amix-packagemanager** bench-RAM investigation, 2026-07-22 (Amiberry, fixed kernel `sum -r`
  42265): 16 MB-exactly proven clean (SCSI read / write-readback / double-read plus a byte-exact
  base-set tree digest) and the 8 MB memory-exhaustion livelock signature ✅.
- The **Z3660** Amix-interop firmware fork — the compile-time-fixed single 16 MB window, the dummy
  bank preventing coalescing past the ceiling, and the `amix_mode`-forces-CPU-RAM-off contract ✅.
