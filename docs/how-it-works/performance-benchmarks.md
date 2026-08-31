# Performance benchmarks — Dhrystone, disk I/O & thermals

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
| **A4000D + Z3660 (ours)** | real 68LC060, FPE, no FPU | 80 MHz | **70,257.6** | 878 | ours (2026-08-26; reproduced **exactly** 2026-08-31 on a different kernel) |
| **A4000D + Z3660 (ours)** | real 68LC060, FPE, no FPU | 100 MHz | **87,976.5** | 880 | ours (2026-08-31, spread 0) |

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
- Dhrystone is **linear in PCLK** on this part at ≈875 ± 7 Dhry/MHz (measured, below); the small 867→880
  rise with clock is timer quantisation (`hz=60` — fewer ticks per run at speed), not a real effect.

### Ours across clocks — real 68LC060, 2026-08-31 campaign

FP-free `dhry` (sha256 `41f6755a…` — the fieldkit's shipped `dhry` dies `SIGSYS` on this FPU-less part),
500,000 passes, 3 runs per row, multiuser verified by telnet `uname`/`who -r` before every row.

| MHz | Dhrystones/s (3 runs) | spread | Dhry/MHz | boot reliability |
|-----|----------------------|--------|----------|------------------|
| 50  | 43,227.7 / 43,352.6 / 43,352.6 | 0.29 % | 867.1 | booted every time |
| 70 ⚠ | 61,224.5 / 61,224.5 / 61,099.8 | 0.20 % | 874.6 | **NOT reliable — see below** |
| 80  | 70,257.6 / 70,257.6 / 70,093.5 | 0.23 % | 878.2 | booted every time |
| 100 | 87,976.5 / 87,976.5 / 87,976.5 | **0** | 879.8 | booted every time |

- The 80 row reproduces the 2026-08-26 first-68060-Dhrystone **exactly** (70,257.6) — on a *different
  kernel* than that row, i.e. cross-kernel repeatability.
- 70 runs a 20 MHz bus (the others 25) yet sits on the same Dhry/MHz line — bus frequency barely affects
  a cache-resident integer loop.

> ⚠ **70 MHz is not a dependable clock on current evidence** (2026-08-31): boots **2/2** from a pristine
> disk after a full power-cycle, but **0/4** when switched via the firmware console (`CCF`) from another
> halted clock on the worked disk. Failure = kernel loads then hangs pre-root-mount. The two candidate
> causes (disk state vs firmware/PLL reprogramming state) are confounded — every success had both a fresh
> image *and* a fresh power-cycle. Its Dhrystone numbers are valid for the boots that succeeded; they are
> not evidence the clock is dependable. 50/80/100 booted every time asked.

## Disk I/O — SD card through piscsi (A4000D + Z3660, 2026-08-31)

The "disk" on our box is the Z3660's **piscsi-backed `.hdf` image on the Zynq's SD card**, not a real
hard drive. Sequential, 64 KB blocks, 8 MB extent; read = the raw root slice `/dev/rdsk/ced0s1`, write =
a scratch *file* (never a raw device). Values in KB/s; repeats shown where taken.

| MHz | seq read | seq write |
|-----|----------|-----------|
| 50  | 1,706.7 | 1,428.8 · 1,498.5 |
| 70  | 2,056.6 | 1,768.1 · 1,840.9 |
| 80  | 2,296.8 · 2,329.5 | 1,827.2 · 1,981.9 · 1,927.5 |
| 100 | 2,614.5 · 2,628.4 | 2,100.5 · 2,174.9 · 2,174.9 |

- **Both directions scale with CPU clock** → the path is CPU/driver-bound, not media-bound; the SD card
  is not the limit at these rates (~2.6 MB/s read @ 100 MHz).
- Small-block reference (80 MHz): sequential **512 B** reads = 409.6 KB/s — latency-bound, ~5.6× worse
  per byte than 64 KB blocks.
- Measurement note: the *first* write into a freshly created file pays allocation/metadata cost (one
  early 100 MHz write read 851.9 KB/s and did not replicate — withdrawn; always repeat writes).

## Thermals — real 68LC060 under load (A4000D + Z3660, 2026-08-31)

First thermal characterisation of our 68LC060, read from the Z3660's own CPU thermistor
(LTC2990 path; THERM calibration at firmware defaults 800.0/27.0, so absolute values are
approximate but self-consistent across all runs quoted here). Cooler state: a new
heatsink + fan **merely resting on the CPU — no thermal paste, not clamped**. Ambient 22 °C.
Load = the sustained mixed Dhrystone + disk-I/O soak loop.

| clock | idle | load plateau (mean) | band | Δ load−idle |
|-------|------|---------------------|------|-------------|
| 80 MHz  | 50.1 °C | **53.8 °C** | 52.4–54.9 | +3.7 |
| 100 MHz | 52.9 °C | **57.5 °C** | 55.6–58.9 | +4.6 |

- Peak ever observed **58.9 °C**, against a 70 °C abort threshold. The part reaches its load
  band within ~5 min (80) / ≤4 min (100); the band oscillates ±0.9 °C with workload phase.
- Slope for this cooler: load ≈ **0.19 °C/MHz**, idle ≈ 0.14 °C/MHz — two points, an
  interpolation, not a demonstrated law.
- **No thermal throttling on this part, demonstrated:** at 100 MHz, 56 of 176 Dhrystone runs
  came in at or *above* the 87,976.5 reference (4 above it — a throttling part cannot beat
  its own reference), and the slower timer-tick buckets split exactly evenly between the
  first and second halves of the 38 min load at both clocks: OS scheduling noise, no thermal
  trend.
- Only prior data is the 2026-08-28 old-cooling record (53.2–56.4 °C at 80 MHz, still
  climbing, lighter load, ambient unrecorded): the new cooler is better in direction, but the
  comparison is uncontrolled. The controlled reference is this run vs the future
  **properly-mounted** cooler re-run, whose protocol is pinned in the results file.

Full write-up: workspace `tmp/2026-08-31-thermal/RESULTS-THERMAL-2026-08-31.md`.

## Open items
- **Mounted-cooler thermal re-run** — repeat the pinned 80+100 soak protocol after the
  cooler is pasted/clamped; THERM calibration must stay at 800.0/27.0 for comparability.
- **70 MHz boot-reliability confound** — needs one designed experiment: `CCF 70` on a worked disk *after*
  a power-cycle, and on a pristine disk *without* one.
- **60 MHz** — no working clock config found (2026-08-30 campaign, full negative matrix); untried lead:
  duty cycles.
- Full campaign write-ups: the 2026-08-30 clock campaign and 2026-08-31 benchmark results files
  (workspace `tmp/`, station logs alongside).
