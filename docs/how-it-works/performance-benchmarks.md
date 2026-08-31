# Performance benchmarks — Dhrystone & disk I/O

Living reference for Amix performance on real and emulated 68k. **Our reference machine is the
A4000D + Z3660 accelerator** (real 68LC060, no FPU → software FPE); every row marked *ours* is that
box unless stated otherwise. This page is updated as new benchmark runs land.

## Dhrystone 2.1 (Dhrystones per second)

Integer Dhrystone 2.1, one comparable binary basis across rows (the FP-free `dhry` on FPU-less parts).
Higher is faster; `per-MHz` = Dhrystones/s ÷ CPU clock (clock-independent efficiency).

| Machine | CPU / config | clock | Dhrystones/s | per-MHz | source |
|---|---|---|---|---|---|
| A3000 (baseline) | 68030, stock | 25 MHz | 5,309.7 | 212 | reference |
| **A4000D + Z3660 (ours)** | z3660 — *config to be confirmed* | — | 6,396.6 | — | ours ⚠ see note |
| A3000 + Mercury | 68040, caches OFF | 33 MHz | 5,366.7 | 163 | Antti (Mercury) |
| A3000 + Mercury | 68040, I-cache on, D-cache off | 33 MHz | 11,538.5 | 350 | Antti |
| A3000 + Mercury | 68040, I-cache + prelim D-cache | 33 MHz | 18,292.7 | 554 | Antti |
| A3000 + Mercury | 68040, I+D cache + copyback | 33 MHz | 30,050.1 | 911 | Antti |
| A3000 + Mercury | 68060, all caches + copyback | 66 MHz | 60,423.0 | 916 | Antti (Mercury) |
| **A4000D + Z3660 (ours)** | real 68LC060, FPE, no FPU | 80 MHz | **70,257.6** | 878 | ours (FPE r13, 2026-08-26) |

**Emulated (Zynq UAE soft-68k) reference, ours:** emulated 030 ≈ 4,615; emulated 040 ≈ **8,185** (final,
after the 030-MMU / emulation-speed work — was 3,818 pre-optimization).

> ⚠ **The 6,396.6 row:** this is our A4000D + Z3660, but its config isn't pinned yet. The value sits in
> 68030 / emulated territory, far below our real-68LC060 figure (70,257.6 @ 80 MHz), so it is almost
> certainly an *emulated-mode* or older measurement rather than the real-silicon FPE lane — to be confirmed
> and relabelled.

### Reading the numbers
- The Mercury 68040 @ 33 MHz cache progression (5,367 → 11,539 → 18,293 → 30,050) shows the caches are
  worth **~5.6×** end to end: instruction cache alone ~2.1×, +data cache ~1.6×, +copyback another ~1.6×.
- With full caches, Antti's 68040 and 68060 both land near **~911–916 dhry/MHz**; our real 68LC060 on the
  Z3660 is **878/MHz** — slightly lower, consistent with the LC060 + Z3660 bus.
- Scaling our 878/MHz across the confirmed clock rows: ≈ 44k @ 50, ≈ 61k @ 70, ≈ 88k @ 100 (to be measured).

## Disk I/O (HD / SD-card throughput)

*To be filled by the next benchmark run* — our latest bench measures HD and SD-card read/write throughput.

| Device / path | read | write | config | source |
|---|---|---|---|---|
| _(pending — next run)_ | | | | |

## Pending — next run (after this session's restart)
On the newly-confirmed clock rows (50 / 70 / 80 / 100 MHz, real 68LC060), collect on the A4000D + Z3660:
- **Dhrystone 2.1 per frequency** — fills the *ours* real-silicon rows above and tests the 878/MHz scaling.
- **HD + SD-card I/O throughput** — fills the disk-I/O table.

Clock rows, realizations, and the disposable-disk workflow: see the 2026-08-30 clock campaign
(`amix-z3660` / campaign results file).
