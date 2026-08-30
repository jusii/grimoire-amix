---
title: "Load averages: uptime and w do not report the machine's load"
summary: Two independent stock defects — a reader that resolves a COMMON symbol to garbage without an error, and a kernel count that omits the on-CPU process — make Amix load averages structurally wrong since 1992; how to read the real value today.
status: draft
---

# Load averages: `uptime` and `w` do not report the machine's load

**On Amix, the number `uptime` and `w` print is unrelated to the kernel's own load average** ✅. Its
flavour — a permanently flat `0.00, 0.00, 0.00`, or values in the hundreds of thousands — depends
only on what happens to sit at the address they mistakenly read. **A flat `0.00` is not an idle
machine; it is the same defect wearing a more convincing disguise.** Anyone who has ever concluded
"this Amix box is idle" from `uptime` has concluded nothing at all.

Both halves below reproduce on the **shipped stock 2.1 kernel** — these are properties of Amix as
Commodore released it, measured on a stock 68030 machine in a controlled 40-minute, 78-sample run
with the run queue independently tracked by `ps -el` throughout ✅.

## Defect 1 — the reader: `nlist(3)` succeeds and hands back a non-address ✅

`avenrun`, the kernel's three load accumulators, is a C tentative definition — an ELF `SHN_COMMON`
symbol — and `/stand/unix` is an `ET_REL` relocatable object, so the symbol **has no address in the
file**: `nlist(3)` returns *success* with the symbol's **alignment** (4) as its value, and the
reader prints whatever pointer-shaped memory lives at address 4 on that boot. The same box produced
**both** wrongness flavours at once: `uptime` printed `0.00` in all 78 samples while a direct read
of address 4 rendered as `458759.84 / 63495.78 / 63498.61`. This is the
[COMMON-symbol trap](../drivers/kernel-reverse-engineering.md#the-common-symbol-trap-nlist-succeeds-and-lies)
in its natural habitat; the reader half is **Amix's own addition** (stock SVR4's `w` prints no load
average at all) ✅.

## Defect 2 — the kernel: the load count omits the on-CPU process, so it reads exactly N−1 ✅

Fix the reader and the number is *still* wrong. The accounting that produces the runnable count
classifies every process by scheduling state and **omits the state meaning "currently executing on
a processor"** — on a uniprocessor, exactly one process whenever the machine is busy. Measured as a
prediction test: 1 spinner → **0.00**, 2 → **1.00**, 3 → **1.99**, with `ps` confirming the run
queue moved 2→5 in step. This half is **inherited from the SVR4 lineage**, not introduced by the
port ✅ (stated as behaviour; the ancestral source is proprietary and is not quoted).

Everything either side of the two defects is healthy ✅: given a correct count, the averaging is
textbook — right time constants, right decay ordering (1-min crosses below 5-min below 15-min),
`FSCALE = 256`. Only the input count and the reader are wrong.

## Reading the real value today, with no fix ✅

```sh
echo 'avenrun/3X' | adb -k /stand/unix /dev/mem     # divide each by 256
```

`adb -k` reproduces the boot loader's COMMON placement — with two load-bearing conditions: the
namelist must be **the kernel actually running**, and when the running kernel exists in **no file**
(loaded from a raw slice), `adb -k /stand/unix` fails *silently* with plausible zeros — replay the
loader's allocation host-side instead. Both conditions, the ten-second COMMON tells, and the
fallbacks are on the
[reverse-engineering page](../drivers/kernel-reverse-engineering.md#the-common-symbol-trap-nlist-succeeds-and-lies).
`crash(1M)` does not work here (`process slot out of bounds`) ✅.

The blast radius is every `nlist`-based consumer of a COMMON kernel symbol — `uptime` and `w`
confirmed; anything else reading `avenrun` the same way is equally affected and equally silent 🟡.
The fix, if anyone wants it, is cheap on both halves: resolve through the running image in the
reader, add the missing state to the kernel's accounting switch. Neither has been attempted ✅.

## The same silent-miss on real hardware: the kernel *load base* moves with the accelerator card ✅

The defect above is a *plausible-but-wrong number read from an address that isn't what you think it
is*. The same class recurs one level down, at the kernel's **load base** — the address the kernel
image itself is loaded at (a load *address*, not to be confused with the load *average* the rest of
this page is about). Any host-side tool that computes a runtime kernel address as `load_base +
offset` — to read a counter, a symbol, or a magic word out of `/dev/mem` — inherits exactly the
COMMON-symbol trap's failure signature if it pins the wrong base: an `adb`/`/dev/mem` read at the
wrong address returns a *plausible* number rather than an error ✅.

**On an Amiga running Amix from a raw-slice-loaded kernel, the load base is set by the accelerator
card's fast-RAM, not by the machine — so it moves when the CPU card changes** ✅. A kernel loaded
into an accelerator's 32 MB fast-RAM region loads at that region's base: a **68060 Mercury** card
places it at **`0x08000000`**; swapping to an **A3640/68040** moves it to **`0x07000000`** — a 16 MiB
shift. Every runtime address computed off the old base is then wrong by that amount, silently. The
load base is therefore not a constant to hardcode; it is an input to **verify** ✅.

**The remedy that works: a fail-closed magic-word gate** ✅. The port kernel's counter blocks carry
magic words (`fpe_magic` = `"FPE!"` `0x46504521`, `f60_magic` = `"FP60"`, and siblings `fpc_magic` /
`fpi_magic` / `fpe_abort_magic`). Before trusting any derived address, read the anchor magic at its
*computed* address and compare it against the value the ELF artifact actually holds (read from the
artifact, never a hardcoded table). A mismatch means the base is wrong — **refuse loudly** and try
the other candidate; probing `{0x08000000, 0x07000000}` and keeping the base whose magic reads back
correct turns a silent megabyte-off read into a caught, named error. This is implemented and verified
in `amix-kerntools/tools/comaddr.py` (commit `4cc29cc`): `--load-base` with the fail-closed gate (a
deliberate wrong base is refused, exit 3, naming the base to try; `--discover` picks the correct
candidate), a host-static 18-case selftest — the box read is an input, so the check is
offline-testable ✅. The magic words themselves are the [software-FPE lane](68040-68060-status.md#the-fpu-less-68060-lane-software-floating-point-on-real-silicon)'s
counter anchors; reported firsthand from real hardware, where a 68060→68040 card swap moved the base
and the magic-word check caught it on the first read ✅.

The through-line with [Defect 1](#defect-1-the-reader-nlist3-succeeds-and-hands-back-a-non-address)
and the [COMMON-symbol trap](../drivers/kernel-reverse-engineering.md#the-common-symbol-trap-nlist-succeeds-and-lies):
a wrong-but-plausible number from an address that moved is only ever caught by *validating the read
against something the target must independently satisfy* — a magic word here, the running kernel's
own namelist there.

## See also

- [Kernel reverse-engineering](../drivers/kernel-reverse-engineering.md) — the COMMON-symbol law and
  the load-bias trap, kept distinct.
- [Quirks §38](quirks.md) — the checklist row.
- [Amix on 68040/68060](68040-68060-status.md#the-fpu-less-68060-lane-software-floating-point-on-real-silicon)
  — the software-FPE lane whose counter magic words anchor the load-base gate.

## Sources

- First-party load-average measurement — a stock Amix 2.1 68030 machine, a controlled 40-minute,
  78-sample run with the run queue independently tracked by `ps -el` throughout ✅: `nlist(3)`
  resolving `avenrun` (a `SHN_COMMON` symbol in the `ET_REL` `/stand/unix`) to its alignment (4) and
  succeeding; the flat `0.00` vs. six-digit-garbage duality read at address 4; the N−1 on-CPU-omission
  prediction test (1 spinner → 0.00, 2 → 1.00, 3 → 1.99); and the healthy averaging either side
  (`FSCALE = 256`, correct decay ordering). The reader half is Amix's own addition (stock SVR4 `w`
  prints no load average); the count half is inherited from the SVR4 lineage (behaviour only, source
  not quoted).
- First-party **68040/68060 port campaign** + `amix-kerntools` — the kernel-load-base finding ✅: a
  raw-slice-loaded kernel loads at the accelerator's fast-RAM base (68060 Mercury `0x08000000`,
  A3640/68040 `0x07000000`), so it moves on a card swap and a pinned base silently reads the wrong
  memory (the same silent-miss class as a stale COMMON address); the fail-closed magic-word gate
  (`fpe_magic`/`f60_magic`/…, read from the ELF artifact) as the remedy, implemented and verified in
  `amix-kerntools/tools/comaddr.py` @ `4cc29cc` (host-static 18-case selftest; `--load-base` /
  `--discover`), corroborated firsthand on real hardware by a 68060→68040 card swap the check caught
  on the first read.
