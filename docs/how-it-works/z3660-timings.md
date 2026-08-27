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
