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
| **A4000D + Z3660 (ours)** | **EMU 030 MMU** (Zynq-UAE soft-030) | emu | 6,396.6 | — | ours |
| **A4000D + Z3660 (ours)** | **EMU 040 MMU** (Zynq-UAE soft-040) | emu | 8,100 | — | ours |
| A3000 + Mercury | 68040, caches OFF | 33 MHz | 5,366.7 | 163 | Antti (Mercury) |
| A3000 + Mercury | 68040, I-cache on, D-cache off | 33 MHz | 11,538.5 | 350 | Antti |
| A3000 + Mercury | 68040, I-cache + prelim D-cache | 33 MHz | 18,292.7 | 554 | Antti |
| A3000 + Mercury | 68040, I+D cache + copyback | 33 MHz | 30,050.1 | 911 | Antti |
| A3000 + Mercury | 68060, all caches + copyback | 66 MHz | 60,423.0 | 916 | Antti (Mercury) |
| **A4000D + Z3660 (ours)** | real 68LC060, FPE, no FPU | 80 MHz | **70,257.6** | 878 | ours (FPE r13, 2026-08-26) |

**Both EMU rows are the Zynq's ARM-hosted soft-68k** (UAE-derived) — ARM-bound, not 68k-clock-bound, so
there's no meaningful per-MHz. Current figures: **EMU 030 MMU = 6,396.6, EMU 040 MMU = 8,100**. Earlier
pre-optimization runs were lower (an 08-18 soft-030 ≈ 4,615, an 08-21 soft-040 ≈ 3,818); the 030-MMU /
emulation-speed work brought them to the current numbers. The real-silicon FPE lane (70,257.6 @ 80 MHz) is
~11× the emulated modes — that gap is real hardware vs emulation, not a 68k-generation difference.

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
