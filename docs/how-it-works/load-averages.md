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

## See also

- [Kernel reverse-engineering](../drivers/kernel-reverse-engineering.md) — the COMMON-symbol law and
  the load-bias trap, kept distinct.
- [Quirks §38](quirks.md) — the checklist row.
