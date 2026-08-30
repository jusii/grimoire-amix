---
title: "Z3660 board timings: CPLD clock rows are per-unit and per-clock"
summary: The accelerator's hardware clock generation — why a timing row validated on one card guarantees nothing on another, why phase values do not transfer between clock rows even on the same card, and how to diagnose "config mismatch or failing card".
status: draft
---

# Z3660 board timings: CPLD clock rows are per-unit and per-clock

This page is about the Z3660's **hardware clock generation** — the CPLD-driven PCLK/BCLK/CPUCLK
divider and phase rows. It is *not* about `service_cadence`, the firmware's software poll-cadence
knob, which lives on [emulation fidelity](emulation-fidelity.md#scsi-int2-interrupt-latency-a3000-mainboard-bootstrap)
and fails in entirely different ways. If you are tuning boot reliability, know which layer you are in.

**A standing safety rule for everything below: no hand-crafted or interpolated timing values.** If
the evidence calls for a value not already validated somewhere, that is a decision for the board's
owner — not for a tool, a script, or an agent.

## A timing row is never "known good" — only "known good on this card at this clock" ✅

Z3660 CPLD timing rows do **not** transfer between physical units. Two cards of the same board
revision, running the same CPLD version, the same firmware, the same SoM and the same CPU, can
differ in whether a given row boots at all. This has been measured in both directions: a row one
card ran reliably for eight consecutive boots failed on a second card nine boots out of nine, with
every other variable held fixed and the applied clock block verified digit-for-digit from the
firmware's own readback — so "the wrong row got loaded" is excluded, and the single changed variable
is the base card itself.

## Phase values do not transfer between clock rows, even on the same card ✅

Sharing a VCO frequency is **not** sufficient for two rows to share phase values. Phase degrees at
the same VCO look directly comparable in real time units, and they are not: if the rows generate
different PCLK, the CPU-side timing relationship differs even when the motherboard clocks land
identically. Tested deliberately — proven motherboard phases transplanted from a working row into a
lower-clock row of the *same card*, same VCO — and refuted 0-for-3: all three boots reached a
display and then never touched the disk at all.

**A method note that came out of that test: a screen is not a boot.** A flat default-palette display
is a display that opened and a disk that was never touched. Score boot attempts on **disk I/O**,
never on "the screen looks up".

## Community rows are per-config starting points, not validated settings 🟡

Across a chart of Z3660 owners' working configurations, **every owner runs different phase values**
(the motherboard-side pairs alone spread across roughly 140–220° on one leg and 230–320° on the
other), across differing board revisions, CPLD versions, operating modes (real-CPU vs JIT-emulated)
and CPU clocks. Two traps follow:

* **Your own chart row may not validate the configuration you actually run** — a row recorded for
  one operating mode at one clock says nothing about the same card in a different mode at a
  different clock.
* **A single matching row is not a control** — one owner's "works for me" (with caveats of their
  own) is a candidate to try, not a baseline to measure a fault against.

The reframe matters beyond tuning: independent owners all needing different phases is external
corroboration that **per-unit variation on these cards is normal, not a symptom**. "My card needs
different timings" is an expected property of the platform, not a fault report.

## The derived-clock law, and the one hard edge ✅

The clock tree is a single VCO with per-output dividers: `VCO = 200 MHz × multiplier / divider`, and
each output clock is `VCO / its own divider`. The hard edge is the **motherboard interface: exactly
25.000 MHz, never above it.**

The interaction that is easy to get wrong: a "dividers only, leave the VCO alone" tuning method
works **only** where `VCO / 25` is an integer. Where it is not (e.g. a VCO of 1120 → 44.8), no
integer divider can hit the motherboard edge, and reaching the target CPU clock requires moving the
VCO itself — a separately ratified class of edit, not a continuation of the same method.

**The reproducibility rule:** keep a durable, hashed copy of the ratified row off the card. A card's
tuning is a physical fact about that unit; if the SD is lost or reflashed, an unrecorded row is gone
and the validation must be redone from scratch.

## A measured clock envelope: one A4000D card, 80 MHz the only stable rung ✅

The per-unit law above is abstract until you sweep one card. This section is that sweep — a specific
Z3660 in an **A4000D**, socketed **MC68LC060 rev 4** (no FPU), in real-CPU mode. **Every result
below is a fact about this one board's silicon at each clock, not a property of every Z3660** — the
same caveat the first two laws make in general.

**Descending from the card's working 80 MHz row, none of the lower `cpufreq` presets is usable** ✅:

| Preset | Outcome on this card | Failure mode |
|---|---|---|
| **80 MHz** | boots to multiuser SVR4 login on **every** cold power-on across both sessions | — (the working row) |
| **70 MHz** | marginal — **1 boot in 3** reached multiuser | the other two: **kernel-image checksum mismatch** reported by the Amix boot loader itself (it detected corrupt data, did not merely hang) |
| **60 MHz** | dead — **0 of 3** | the 68LC060 never begins executing: black video console, no Kickstart, nothing |
| **50 MHz** | dead — **0 of 11** across both sessions | scattered early: device-not-found, corrupted boot-partition read, one console reaching the full kernel banner before its telnet daemon failed to stay up; after a targeted timing fix, a repeating **"User BUS ERROR" in `/sbin/init` (PID 1)** |

### The failure tracks the realised bus clock, not the nominal "CPU MHz" label ✅

The firmware prints its realised clock tree on every boot, and reading the values off that printout
(not the preset label) is what makes the pattern legible ✅. The structural fact: the **bus-facing
clock runs at the same 25.00 MHz at both the 50 MHz preset and the 80 MHz preset** — the two presets
that differ most in nominal "CPU MHz" share an *identical* realised bus clock — and that line only
drops below 25 MHz at the presets in between (roughly the 55–75 MHz band, stepping to values like
17.50 and 15.00 MHz). This is the axis the failures follow: 60 MHz (bus 15.00 MHz, furthest from
25.00) is deadest; 70 MHz (17.50 MHz) is marginal; 50 MHz shares 80 MHz's own 25.00 MHz bus clock and
*still* fails, downstream of the boot loader, for a different reason. The nominal MHz a preset
advertises is not the variable that predicts stability — the realised bus-side clock tree is. (This
is the [motherboard-25 MHz edge](#the-derived-clock-law-and-the-one-hard-edge) seen from the failure
side: hitting 25.00 exactly is necessary, not sufficient.)

### 50 MHz corrupts the kernel's own read path even after the phase difference is fixed ✅

Because 50 MHz shares 80 MHz's 25.00 MHz bus clock, the two rows differ only in phase-alignment
parameters. Transplanting the single largest such phase difference from the working 80 MHz row onto
the 50 MHz row (a one-parameter, same-frequency edit) measurably **narrowed** the failure — from
three scattered break points across four boots to **one reproducible break point (4 of 4)** — but did
not close it ✅. With that adjustment the boot loader reliably reads and validates the kernel image,
the kernel starts and prints a correct memory-size banner, and *then* the **first disk read the
running kernel performs on its own** (as opposed to the boot loader's reads) returns corrupted data —
traced to `/sbin/init` receiving garbage code/data and bus-error-faulting in an infinite loop. A
disk-activity trace left running ten minutes (rather than cut off early) showed the I/O pattern of a
genuinely wedged read path — long silent gaps, a handful of requests total — not a slow-but-
progressing one, ruling out "50 MHz just needs more time" ✅. Four further phase/CPU-clock candidates
were tried (five configurations total); **0 successes**, one a clear regression to a dead
black-screen boot. The card's storage media was independently exonerated three ways across two
sessions: a corrupted read returns a *different* wrong value on each attempt (a live corrupting
transfer, where damaged media would return the same bytes every time), and a full re-verification at
the known-good 80 MHz between every failing-clock experiment found every file byte-identical ✅.

### The ARM co-processor runs 27% over its printed rating — but is not the cause ✅

Independent of the 68060-side clock: the accelerator's onboard **ARM co-processor** (which runs the
firmware, the SD-card I/O and the emulated storage mailbox the 68060 talks to) is configured at
**1100 MHz**, while the firmware's own boot printout states this chip's silicon is rated for a
maximum of **866.667 MHz** — the applied clock is **~27% above the card's own stated maximum**, and
has been throughout this investigation (not a side effect of the CPU-clock experiments) ✅. Bringing
the ARM clock down to the firmware's in-spec default (666.667 MHz), tested with the 50 MHz CPU clock
both alone and combined with the phase fix, **changed nothing** — still 0 successful boots ✅. So the
out-of-spec ARM clock is a real, independently worth-fixing reliability concern for this card, but it
is **not** what causes the 50 MHz CPU-clock failure.

**The envelope, stated as a fact about this card:** the clock-frequency axis alone does not yield a
stable sub-80 MHz operating point here — every rung between the working preset and the next-lower
stable one fails, for at least two structurally different reasons (a dead CPU core at 60 MHz vs. a
corrupting kernel-era disk read path at 50 MHz), and the most promising single-parameter fix narrows
but does not close the 50 MHz failure ✅.

## Diagnosing "config mismatch or failing card" — the cheapest decisive test ✅

Boot the suspect card at **its own previously-proven operating point**:

| result | verdict |
|---|---|
| it runs | the fault is the row — a per-unit mismatch, exactly what the first law predicts when one unit's ratified row is applied to another |
| it fails at a setting this unit itself has proven | the timing explanation is dead; the fault is something the card has **acquired** |

Corollaries: an emulated-CPU boot (bypassing the real CPU) that also fails exonerates the CPU and
its socket, because bypassing the CPU is a property of the mode — but if that boot rode a different
clock row, its result says nothing about the untested row. Run the suspect card's own known-good
point before concluding anything about timings.

## No readable field identifies the physical board ✅

FPGA version, ARM IDCODE, silicon revision and speed grade, firmware image versions, CPLD usercode,
DDR speed and ARM clock all read **identical** across physically different boards — every field
names the bitstream, the part or the firmware; none names the board. Which unit a session is driving
is a **physical-custody fact** that cannot be recovered afterwards from a log. Since rows are
per-unit, a captured configuration is only interpretable if the card's identity was recorded
out-of-band at the time. **Log the card's identity by hand at the top of any metal session — a
timings file without a named unit is an unlabelled key.**

## See also

- [Emulation fidelity](emulation-fidelity.md) — the *software* cadence knob this page is not about,
  and the frame-level behaviours an emulator must honour.
- [Hardware](hardware.md) — the base machine's CPU/MMU/FPU rules.
- [Amix on 68040/68060](68040-68060-status.md) — why this card runs a 68LC060 at all, and the
  software-float lane it depends on.

## Sources

- First-party **Z3660 clock-envelope sweep** — two back-to-back real-hardware sessions on one
  specific Z3660 in an **A4000D**, socketed **MC68LC060 rev 4**, real-CPU mode (2026-08) ✅: the
  80/70/60/50 MHz `cpufreq` ladder against the working 80 MHz baseline (per-preset console evidence —
  kernel-checksum mismatch at 70, black-screen at 60, the insert-disk / `IBLK`-read-failure /
  `/sbin/init` bus-error signatures at 50), the realised clock-tree printout read at every preset
  (the 25.00 MHz bus clock shared by 50 and 80, the 17.50/15.00 MHz dip between), the targeted 50 MHz
  phase-adjustment follow-up with its ten-minute disk-activity trace, the three-way media-integrity
  cross-check, and the in-spec-ARM-clock control experiment. Hardware/firmware facts only — clock
  frequencies, boot outcomes, and register/serial signatures; no lab-infrastructure detail. **One
  card**: the results describe this board's silicon at each clock, not a guaranteed property of every
  Z3660.
