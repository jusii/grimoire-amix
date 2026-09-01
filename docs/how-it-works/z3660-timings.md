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

**Confirmed a second time, on a second pair of cards** ✅. A tuned **80 MHz** row from a tracker of
known-good owner configurations — same host model (A4000D), same CPU class (68LC060), same nominal
clock, phases and dividers copied verbatim — was applied to a different physical card and *confirmed
applied* by reading the firmware's own serial printout. 80 MHz still failed. Of that tracker row's
whole clock table only the **50 MHz** row worked on the receiving card. Re-tuning 80 MHz for it would
be a fresh phase campaign, not a file copy. The law now rests on two independent card pairs measured
in opposite directions.

## A fresh card arrives untuned — it ships the *stock* clock table ✅

The per-unit law has a blunt practical consequence for anyone handed a card: **the tuned rows live on
the card, not in the firmware.** A newly built card, or one whose storage has been reflashed, carries
the **stock** clock table; the hand-fitted rows a tuning campaign produced exist only as a timings
file on the unit they were fitted to.

With the stock table and a **real 68060**, the failure is early, specific, and looks nothing like an
operating-system problem ✅:

* the firmware reaches its `060 starting now` handover and then there is **no SCSI activity at all** —
  not a slow disk or a failed read: the CPU never issues a single request;
* the Amiga puts up a **diagnostic colour screen** from the Kickstart ROM's own early self-test —
  **green = a chip-RAM error, blue = a custom-chip error**;
* with some Kickstart ROM choices it **reset-loops** instead (one card logged 174 consecutive resets).

This is the Kickstart-era chipset/RAM initialisation failing on marginal bus timing, *before* any OS
is involved, so nothing on the Amix side can fix or work around it. **Restore the card's own tuned
table first; debug anything else afterwards.** It is also the reason the *reproducibility rule* below
is not bureaucracy: an unrecorded row is a card that no longer boots.

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

### The ARM co-processor runs 27% over its printed rating — but is not the cause *here* ✅

Independent of the 68060-side clock: the accelerator's onboard **ARM co-processor** (which runs the
firmware, the SD-card I/O and the emulated storage mailbox the 68060 talks to) is configured at
**1100 MHz**, while the firmware's own boot printout states this chip's silicon is rated for a
maximum of **866.667 MHz** — the applied clock is **~27% above the card's own stated maximum**, and
has been throughout this investigation (not a side effect of the CPU-clock experiments) ✅. Bringing
the ARM clock down to the firmware's in-spec default (666.667 MHz), tested with the 50 MHz CPU clock
both alone and combined with the phase fix, **changed nothing** — still 0 successful boots ✅. So the
out-of-spec ARM clock is a real, independently worth-fixing reliability concern for this card, but it
is **not** what causes the 50 MHz CPU-clock failure.

**Read that as scoped, not as "the overclock is harmless".** It says the ARM clock is not the cause of
*this* card's 50 MHz no-boot. On a different card the same overclock produced a failure of its own —
[the corrupt kernel read path](#arm-overclock-read-path) below.

**The envelope, stated as a fact about this card:** the clock-frequency axis alone does not yield a
stable sub-80 MHz operating point here — every rung between the working preset and the next-lower
stable one fails, for at least two structurally different reasons (a dead CPU core at 60 MHz vs. a
corrupting kernel-era disk read path at 50 MHz), and the most promising single-parameter fix narrows
but does not close the 50 MHz failure ✅.

## An out-of-spec ARM clock corrupts the 060 to Zynq kernel read path ✅ {#arm-overclock-read-path}

On a second card the out-of-spec ARM clock was **not** harmless. With `arm_frequency 1100` — again
≈27 % above the 866.667 MHz maximum the firmware prints for that part — the SVR4 boot loader reached
the disk and then stopped:

```text
WARNING! Kernel file checksum mismatch. Expected 0x0000A7D9, found 0x000054A2.
```

**The diagnostic is which half moves** ✅. `Expected` is *constant* across boots; `found` differs on
**every** boot (`0x3A7E`, `0xCC59`, `0x8A7D`, `0x54A2` across one session). A stale or wrongly stored
checksum would give a constant `found`; a value that changes each time can only come from a **corrupt
read path** — the bytes differ each time they are fetched. This is a reusable discriminator, and it
retroactively reclassifies "kernel checksum mismatch" rows in older campaign logs that were read as
image corruption.

Two eliminations came with it:

* **The storage is not the source** ✅. The firmware's own `CRC` command, run twice from the boot menu
  over the same image file, returned an identical checksum for an identical byte count — a stable,
  repeatable read. The bit errors are therefore **downstream of the SD card, in the 68060 to Zynq bus
  transfer**.
* **Lowering the ARM clock reduces but does not eliminate it** ✅. `arm_frequency 667` — the firmware's
  in-spec default — made the mismatch much rarer, and it still returned on a later cold power-on after
  three clean boots. An in-spec ARM clock is necessary, not sufficient.

**`service_cadence` is not a lever here** ✅: the firmware documents it as an **030-MMU run-loop**
knob, inert when a real CPU is running the code — see
[emulation fidelity](emulation-fidelity.md#scsi-int2-interrupt-latency-a3000-mainboard-bootstrap).

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

### A diagnostic ROM is a control that deliberately skips Kickstart ✅ {#diagrom-as-a-control}

The second cheap test at a failing clock is to boot a **diagnostic ROM** (DiagROM) instead of a
Kickstart. It exercises the CPU, the bus and memory, but it **never performs Kickstart's early
chipset/RAM initialisation** — so it splits the failure in two:

| DiagROM at the failing clock | verdict |
|---|---|
| boots and runs its tests | CPU, bus and clock tree reach that clock; the fault is in the **Kickstart-era chipset/RAM init**, which nothing on the OS side can reach |
| fails too | the fault is below the OS entirely — CPU, bus or clock tree |

Worked case ✅: a card that failed 80 MHz identically under **both** AmigaOS and Amix booted DiagROM
fine at 80 MHz on its real 68060. That narrows "this card cannot do 80" to "this card's Kickstart-era
chipset init cannot do 80" — a far smaller target, and it explains why the failure presents as an
Amiga diagnostic colour screen rather than an OS panic.

### Single-variable module swaps eliminate whole subsystems ✅

The board is two separable pieces — the **ARM/Zynq module** and the **carrier/CPLD**. Moving the
module from a card that ran 80 and 100 MHz well into the failing card, keeping that card's own
storage and confirming the applied clocks on the serial, reproduced the 80 MHz failure **identically**
✅. One variable changed, so the ARM module is eliminated, leaving the carrier/CPLD and the firmware
build on the storage as the open suspects. The completing test is the reciprocal one: put the suspect
storage into the *complete* other card — works ⇒ carrier, fails ⇒ firmware.

### A failure whose boundary moves is not a discrete hardware fault ✅ {#moving-boundary}

Two shape rules that classify a memory failure before anyone reaches for a soldering iron:

* **A discrete hardware fault does not move.** A bad joint, a failed buffer or a dead memory ball
  produces the *same* boundary and the *same* failing bits every run. A failure whose boundary **and**
  bit set change on every power cycle contradicts a discrete fault outright ✅.
* **Run the identical test on a second CPU path.** A window that fails every run under the emulated
  CPU and passes cleanly on the real socketed CPU is an artifact of the emulated access path, not a
  board defect ✅. The worked case, its table, and the four candidate mechanisms it eliminated are on
  [emulation fidelity](emulation-fidelity.md#emulated-memory-window).

Both rules earned their keep in a card acceptance pass that ended with **no defect found on either
CPU path** — the one anomaly turning out to belong to the *host machine's* motherboard memory
(a partial SIMM population), not to the accelerator ✅.

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
- First-party **second-card bring-up and acceptance campaign** (2026-08-31 / 09-01, workspace record)
  ✅ — a *different* physical Z3660 in an A4000D with a socketed MC68LC060: the stock-clock-table
  failure signature (no SCSI activity after the firmware's `060 starting now`, the green/blue Kickstart
  diagnostic colour screens, the 174-reset loop under one ROM choice); the verbatim transplant of a
  tracker's tuned 80 MHz row confirmed applied on the serial and still failing, with only the 50 MHz
  row transferring; the `arm_frequency 1100` kernel-checksum corruption with its constant-`Expected` /
  per-boot-varying-`found` discriminator and the partial improvement at 667; the twice-repeated
  firmware `CRC` over the same image file exonerating the storage; the DiagROM-boots-at-80 control
  that localises the fault to Kickstart's early chipset init; and the single-variable ARM-module swap.
  Card identities, image names and checksums are project bookkeeping and are deliberately not
  reproduced here.
