---
title: "Emulation Fidelity: what an emulator must get right to boot Amix"
summary: Amix's demand-paging boot and A3000 SCSI bootstrap lean on 68030 bus-error-frame and interrupt-latency behaviour an emulator can get subtly wrong — passing every AmigaOS test yet failing Amix, sometimes silently.
status: draft
---

# Emulation Fidelity: what an emulator must get right to boot Amix

Amix leans on the raw **68030** harder than almost any other classic-Amiga operating system. It uses the full **MMU** for SVR4 demand paging (the HAT layer — see [kernel architecture](kernel-architecture.md)), and it drives its A3000-mainboard SCSI controller from an **INT2** interrupt during the earliest kernel bootstrap. Because it ignores the Amiga custom chips and treats the machine as a generic 68030 Unix workstation, an emulator can pass every AmigaOS compatibility test and still fail to boot Amix — and the failure is often **silent** (no panic, no message), or an **intermittent** crash that only appears under load.

This page collects the emulator-core behaviours Amix depends on, distilled from bringing Amix up on a **software 68030+MMU CPU** (see [where this was discovered](#where-this-was-discovered)). They are **emulator-agnostic**: they apply to any emulator — [WinUAE](../getting-started/emulation-winuae.md) (the reference target, which added MMU emulation in 2.6.0), FS-UAE, Amiberry, or a from-scratch 68030 core — that wants to run Amix's demand-paging boot. This is the *why the CPU core must be faithful* companion to the per-emulator *set-these-knobs* guides.

The findings here are **first-party** (from the Z3660 firmware project, real-hardware verified) and the emulator fixes are **owned by that firmware repo** — they are cited by commit, not reproduced here (the same [ownership discipline](../drivers/z3660-scsi-driver.md#the-boots-then-hangs-was-the-emulator-core-not-the-scsi-driver) the Z3660 driver pages use).

## 68030 bus-error-frame semantics (demand paging) ✅

**The requirement: an emulator must build and resume the 68030 bus-error exception frame faithfully, or Amix's demand-paging path corrupts the resumed process.** ✅

Amix pages user text and stack in on demand. When a memory access faults on a not-yet-resident page, the 68030 stacks a **format-`$B`** (long) or **format-`$A`** (short) bus-error frame, the kernel's vfault handler maps the page, and an **`RTE`** resumes the faulted instruction *mid-flight* — often part-way through a non-idempotent instruction (a `MOVEM` register list, a `(An)+`/`-(An)` update, a read-modify-write). Getting that stack-and-resume wrong does not cause a clean error; it silently resumes the process at the **wrong PC, in the wrong mode, or with the wrong opcode**. In practice the emulator core needed **two generations of fixes**, both in the same `m68k_do_rte_mmu030` / format-`$B` subsystem.

### First generation — the boot-time first-fault death ✅

The initial bugs stopped Amix before it ever reached a login prompt:

1. **`SIGILL` on the instruction-fetch-fault resume.** The simplified format-`$B` frame builder never set the "fault occurred during opcode prefetch" sentinel and stacked a stale opcode in the frame's opcode slot. After the handler mapped the page and `RTE`d, the refetch gate never fired, the stale instruction (the return-to-user `RTE` itself, `0x4E73`) was re-dispatched in user mode, and `init` died `SIGILL` at libc `_rt_boot+0`. Fixed by Z3660 commit **`3069e22`** ("mmu030: fix demand-paged ifetch resume — restore the prefetch-fault sentinel in frame `$B`"). ✅
2. **`SIGSEGV` on the mid-instruction replay state.** With the sentinel fixed, `init` ran through many demand-paged text faults but died `SIGSEGV` on a later fault that landed *part-way through* a non-idempotent instruction, because the format-`$B` replay state was not stored. Fixed by porting the full WinUAE 4.4.0 format-`$B` frame storage — Z3660 commit **`0b42cb8`** ("mmu030: port full WinUAE format-`$B` frame-storage (fix mid-instruction-restart `SIGSEGV`)"). ✅

> **Citation note.** These two commits are the current (branch `amix-main`) identities of a fix earlier carried on the now-deleted `amix-boot` branch as `c8b9398` / `e3f9440`. Those old hashes **no longer exist** in the repository; `0b42cb8`'s own commit body still names "After `c8b9398` fixed the opcode-prefetch resume (`SIGILL`)…", which is what pins `c8b9398` → `3069e22` and `e3f9440` → `0b42cb8`. Earlier grimoire pages that cited the dead hashes have been corrected. ✅

### Second generation — multi-fault continuation under load ✅

A distinct, **later** pair of fixes (two weeks after the first) hardened the case where an instruction being resumed *from its own bus-error frame* **faults a second time** — for example a function-prologue `MOVEM.L <regs>,-(SP)` growing the user stack across a page that is itself not yet resident, or the still-unmappable page hit during the `RTE`'s own "retry faulted access" step. On that re-fault the emulator rebuilt the new frame from a **stale outer-loop snapshot** — the PC/opcode of the kernel trap-return epilogue (`~0x0800129C`, opcode `0x4E73`) — instead of the resumed user instruction. The result: a format-`$B` frame carrying a **kernel PC** (a wild user PC, observed as a constant `0x5C000000`) and a format-`$A` frame whose opcode had flipped a user `clr.b` (`0x4218`) to the `RTE`'s `0x4E73`. The next `RTE` then resumed the user process at a kernel address **in user mode**, the next fetch landed in unmapped user space, and the guest reported an intermittent **`User BUS ERROR at <pc> … FAULT:6`**, frequently followed by a panic — killing userland tools such as `cron` and `in.telnetd` under sustained fork/exec load (reproducible with a telnet-connect storm). ✅

The fix is to rebuild the frame from the **resumed instruction's** identity:

- **`7ff5774`** ("emu: fix 030 MMU multi-fault continuation corrupting the bus-error frame PC") — re-snapshot the instruction-start PC (`mmu030_insn_start_pc` / `regs.instruction_pc`) at the *inner-loop continuation* point, so a re-fault frames the resumed instruction's own PC (a no-op for the common same-PC sub-access continue). The behavioural change lands in `newcpu.cpp`. ✅
- **`acdfe15`** ("emu: fix 030 MMU in-RTE retry-access rebuilding a mis-attributed bus-error frame") — its declared residual: just before the in-`RTE` retry-access, re-point `mmu030_insn_start_pc = pc` and `regs.opcode = regs.irc = mmu030_opcode` to the resumed instruction, in `cpummu030.cpp`. ✅

> **Symptom framing.** The second-generation bug presents as an *intermittent, noisy* `User BUS ERROR` **after** the system is already at multiuser — not as a silent boot-time hang. (The silent post-banner stall was the *first*-generation death above, and the pre-banner SCSI bootstrap hang is [a separate issue](#scsi-int2-interrupt-latency-a3000-mainboard-bootstrap).) After both pairs land, Amix boots to a stable multiuser login shell (HDMI console **and** telnet root login), the emulator's host-side MMU harness passes 64/64 with a two-fault-continuation regression test, and a **27-reboot multi-hour soak** under concurrent fork/exec load ran clean. ✅ One rare bus-error-frame `SR`-flip under *extreme* sustained paging load remains tracked but did not recur across that soak. 🟡

### The general requirement ✅

Any emulator running Amix's demand-paging boot must implement 68030 **format-`$B`/`$A` bus-error frames** faithfully: the correct fault PC, the prefetch-fault sentinel, the mid-instruction replay state for non-idempotent instructions, and — the subtle one — **correct re-attribution when a resumed instruction re-faults**. UAE-derived cores historically diverge here, which is why the fixes above trace back to porting WinUAE's frame handling. If a 68030 core boots AmigaOS perfectly but Amix dies at `_rt_boot`, `SIGSEGV`s early in `init`, or throws intermittent wild-PC `BUS ERROR`s under load, this is the first place to look. ✅

## SCSI INT2 interrupt latency (A3000-mainboard bootstrap) 🟡

**The requirement: an emulator that batches instructions between interrupt-service polls must keep SCSI INT2 latency low through the kernel bootstrap.** ✅ (mechanism) / 🟡 (the exact boundary)

Amix's **A3000-mainboard SCSI** bootstrap is interrupt-driven on Amiga **INT2** (level 2) during the earliest kernel startup, *before* the banner. An emulator that, for throughput, executes several guest instructions between checks of the incoming interrupt line raises the worst-case **INT2-detection latency** to roughly that batch size — and if the batch is too coarse, the SCSI bootstrap is starved of timely service and **hangs before the banner**. 🟡 (This is a pre-banner bootstrap stall, distinct from the [demand-paging faults above](#68030-bus-error-frame-semantics-demand-paging).)

This behaviour is exposed by a firmware knob, **`service_cadence N`** ✅:

> Disambiguation: `service_cadence` is a **software** poll-cadence knob of the firmware's device
> emulation. The Z3660's *hardware* clock generation — CPLD timing rows, VCO/PCLK/phase — is a
> different layer with different failure modes, covered on [Z3660 board timings](z3660-timings.md).

> **Scope: it exists only in the emulated-CPU run loop.** ✅ The knob throttles the *software* 68k
> emulator's interrupt-service poll, so on a board running a **real** 68060 with the emulator bypassed
> there is no instruction batching to tune and the setting does nothing at all. A boot-reliability
> problem on real silicon is a clock-tree or bus-timing problem, not a cadence one — do not spend a
> session on this knob there.

- `N` = the number of emulated instructions run between calls to the emulator's interrupt-service poll (`check_uae_int_request()`), i.e. the emulator batches `N` instructions between the poll that detects the Amiga IPL/INT2 line. **Default 1** (poll every instruction); values below 1 are clamped to 1. ✅
- It is settable at boot in `z3660cfg.txt` and per-preset config (Z3660 commit **`e0e17d5`**), and cyclable at runtime `1→2→…→64→1` from the serial `SERV` console (commit `f7bbdb0`). ✅
- Raising it trades interrupt latency for CPU throughput — measured on a real A4000 + Z3660 (Amix 2.1, Dhrystone 2.1) at up to ~**1.3× CPU** from cadence 1→64, with disk I/O essentially flat and a knee around 8. ✅

The **Amix-safe boundary**: cadence **2 and 4 boot** cleanly; cadence **8 hangs** the A3000-SCSI bootstrap. 🟡 So the recommendation is `service_cadence 4` at boot — capturing most of the speed-up — and raising it to 8 only *after* Amix is up, via the `SERV` menu. 🟡

> **Confidence.** The knob, its default, the clamp, and the batched-poll semantics are **code-grounded** ✅. The **INT2-latency attribution** and the exact **4-boots / 8-hangs** boundary rest on the author's hardware sweep (recorded in the firmware's own docs and shipped config, and consistent with the SCSI path being level-2 interrupt-driven), not on a root-caused defect or a committed test artifact — carried **🟡**. Note the knob's own introducing commit (`e0e17d5`) was initially *more* conservative ("any cadence > 1 hangs before MMU-enable; keep the Amix preset at the default"); the "4 is safe" result is the later, refined finding, and **no shipped preset actually bakes in a non-default cadence** — the `4` is a recommendation. 🟡

## DMA cache coherence across the two emulator cores ✅

Fidelity is not only about the CPU core. On the Z3660 the emulator runs on a **two-core (AMP) ARM** SoC: **core0** runs the firmware (SD-card I/O and the emulated piscsi mailbox), **core1** runs the 68k CPU emulator that *is* the guest's processor, and the two cores share DDR behind a PL310 L2 cache. Guest disk/CD reads are performed by core0 **DMAing SD-card data straight into the guest's RAM buffer** and then handing control back to core1. That producer/consumer handoff across two separate caches is a second class of emulator-fidelity bug — invisible to any single-core correctness test, and it cost **silent data corruption on real hardware** twice. ✅

### Both DMA endpoints need cache maintenance, not just the core that owns the transfer

**The requirement: on a DMA handoff split across two cores, *each* core must maintain the caches it can fill.** A fix on only one side looks correct and still corrupts.

- **The producer (core0, which owns the DMA).** The SD controller DMAs to DRAM *below* the L2, so a **read** needs the range **invalidated before** the transfer and a **write** needs it **cleaned/flushed before** the transfer. The stock `XSdPs_ReadPolled` invalidated only *after* the transfer, so a dirty L2 line written back *during* the multi-millisecond transfer landed in DRAM on top of the freshly-DMAed bytes — observed as a UFS superblock read returning stale guest memory. The write path had **no** cache maintenance at all and deterministically wrote stale DRAM to disk, physically corrupting the SD image's UFS superblock (proven: a TFTP GET read the same garbage back off the card). Fixed with `Xil_DCacheInvalidateRange` before direct reads and `Xil_DCacheFlushRange` before direct writes — Z3660 `e37bb43`. ✅
- **The consumer (core1, the guest CPU) — the subtle one.** A parked ARM core is still live: while core1 spun in `while(shared->write_scsi==1){NOP;}` waiting for core0 to finish, it **speculatively refilled its own L1D** with lines covering the DMA target, so after the transfer the guest read a mix of fresh DRAM and stale cache. Nothing invalidated core1's L1 *after* the DMA landed. With CD reads going direct-DMA into kernel heap buffers, the guest SVR4 kmem daemon panicked on a wild freelist pointer (a stale line on a kmem pool page — vector-2 bus error, fault addr `0x4AFC000C`), and a second run silently corrupted the root filesystem (`WARNING: ufs_readdir: bad dir, inumber = 35340`; files recovered into `/lost+found`) — **two failures out of two under load**. Fixed by having core1 stash the READ descriptor as the guest programs it (ADDR2 = byte length, ADDR3 = DMA target) and call `Xil_L1DCacheInvalidateRange(addr,len)` after the completion spin, for READ commands only — Z3660 `0a4c064`. ✅

The two are the **same bug class seen from opposite ends**. The producer-side fix (`e37bb43`) passed code review — "the invalidate is unconditional and covers the full byte length, so reads are coherent" — and was *still* wrong, because the consumer core had its own L1 that the DMA-owning core's `Xil_*CacheRange` calls do not speak for. The reusable heuristic: **a cache-maintenance call on the DMA-owning core covers only that core's caches; every other core that can fill a line over the DMA target must maintain it itself.** 🟡 (This general rule is generalized from the two concrete fixes above, not independently re-derived on other hardware — carried 🟡.)

After the consumer-side fix the same workloads produced **zero panics, zero corruption, and a full CD read suite byte-identical to the source ISO** (7/7 files `cmp`-verified host-side). ✅ This is the emulator-side counterpart of the driver-side [direct-vs-bounce gate contract](../drivers/z3660-scsi-driver.md#the-mandatory-bounce-buffer): both the firmware and the driver must agree on **who copies** and on **when the caches are coherent**, or data silently rots at the handoff.

## Desktop-emulator infidelity: the kernel-relink corruption, root-caused and fixed ✅

The fidelity concerns above are about emulators *on the real hardware path*. The desktop bench
emulator (Amiberry) had its own long-known infidelity: **relinking the Amix kernel under emulation
corrupted the output most of the time**. It was measured in 2026-07 (**85% of rounds at 8 MB**),
then **root-caused on 2026-07-26 — and it is a 68030 MMU defect in the emulator, not a linker or
disk problem.** Full mechanism and damage signature on the [kernel build
page](../drivers/kernel-build.md#the-d245-boot-breaker--an-intermittent-ld-corruption); the short
version, because it generalises to any emulator running a demand-paging guest:

- The bus-fault format-`$B` frame packs `mmu030_state[2]` and `wb3_status` into one 16-bit word;
  the `RTE` restored the **whole word** into `mmu030_state[2]`, so an in-`RTE` re-fault built its
  frame over a **stale** write-back status and undid an `(An)+` side effect **twice** — a silent
  4-byte address-register rewind, mid-copy, no exception ✅.
- Every event hit the guest kernel's `MOVES.L (A0)+` **copyin** loop, so the victim was the
  kernel's copy of the linker's `write()` buffer. **`ld` was innocent throughout** ✅.
- Fixed by masking the restore to its real 8-bit width (both `RTE` variants): 55–59% → **0/39**
  with paging traffic unchanged. The defect existed in **upstream WinUAE** too and was reported
  there; the maintainer's own fix is equivalent and measured 40/40 clean ✅.

Three properties remain worth carrying, independent of the fix:

- The rate was **configuration-dependent** — 85% at 8 MB motherboard RAM, pooled **0/354** on a
  16 MB config — and **measurement suppressed it** (adding I/O around each link drove 85% → 28%).
  Never quote an emulation-corruption rate without its memory config and capture mode ✅.
- Corrupt kernels kept the symbol table **clean** (`nm -h -u` caught **0 of 21** captured
  corruptions; `checkunix` 7, relocation analysis 15, **byte-diff 21/21**). Symbol-level gates are
  not sufficient; byte-diff against a known-good link is the only complete oracle ✅.
- **This class of bug is emulation-only and silent**: real hardware links deterministically, the
  guest's own checkers see nothing, and the guest survives enormous numbers of malformed fault
  frames without complaint (~142k in-`RTE` re-faults per measured run). An emulated OS that
  "mostly works" can still be quietly corrupting data under paging pressure ✅.


## The cycle-exact core: a correct emulator default that Amix does not survive ✅

**Not every emulator-side Amix death is an emulator defect. A hand-written UAE-family config that
simply never mentions cycle-exactness selects the *cycle-exact* 68030 core — and an Amix guest dies on
it at PID 1** ✅. Omission is not neutral here: it is a choice, and it is the wrong one.

The failure is a good imitation of a guest, driver or memory-map bug. The kernel boots normally —
banner, device configuration, root mounted — and then:

```text
NOTICE: User BUS ERROR at E0001770, PC:C100F35E FAULT:6 PID:1 CMD:/sbin/init
```

That signature was on record for a day as a suspected interaction between a rig's extra RAM at
`0x08000000` and an accelerator board, with a memory bisect proposed as the next move. It is neither ✅.

### Why omission selects it ✅

In Amiberry, `default_prefs()` (`src/cfgfile.cpp`) initialises **all three** cycle-exact flags `true`:

```c
p->cpu_cycle_exact = true;
p->cpu_memory_cycle_exact = true;
p->blitter_cycle_exact = true;
```

and nothing in the plain config-load path lowers them ✅. `buildin_default_prefs()` *does* clear all
three, but it is reached only via `built_in_prefs()`, which the parser calls only for a `quickstart=`
line. `target_default_options()` also clears them — but **only when the host's `amiberry.conf` sets
`default_disable_cycle_exact`**, which itself defaults to `false`. So **the effective default is
host-dependent**: the same `.uae` can select different CPU cores on two machines ✅. That is a second,
independent reason to pin the key rather than trust any default — and it is why a config can be
"verified working" on one host and kill the guest on another.

### `cycle_exact=false` is the one key that clears all three ✅

The parser reads four non-equivalent keys; picking the wrong one leaves the trap half-armed ✅:

| Key | Effect |
|---|---|
| `cpu_cycle_exact` | sets `cpu_cycle_exact`, copies it to `cpu_memory_cycle_exact`; leaves the blitter flag alone |
| `blitter_cycle_exact` | sets only the blitter flag — **does not touch the CPU flags** |
| `cpu_memory_cycle_exact` | when false, also forces `blitter_cycle_exact` and `cpu_cycle_exact` false |
| **`cycle_exact`** | parsed against `{ "false", "memory", "true" }` — **`false` clears all three in one line** |

So `cycle_exact=false` is what to pin; `blitter_cycle_exact=false` alone would leave the cycle-exact
CPU core enabled and fix nothing ✅. The file is parsed top-to-bottom and the last matching key wins,
which is why a GUI-saved config emits `cycle_exact` *after* the other three — its trailing
`cycle_exact` is the authoritative one ✅.

### The pre-boot host-log tell — check this first, every time ✅

There is a reliable read-out **before the guest boots at all**. Every Amix config here disables sound
(`sound_output=none` / `produce_sound=0`), and on that combination `fixup_prefs()` (`src/main.cpp`)
prints, right after the config-load line and *before* `KS ver =`:

```text
Cycle-exact mode requires at least Disabled but emulated sound setting.
```

That line is emitted **only** when `cpu_memory_cycle_exact` survived config load, so on a
sound-disabled Amix config it is a direct read-out of whether the trap is armed ✅. Across 16 host logs
from the session that found this it discriminates perfectly: present in **all 6** runs whose config
omitted the key, absent in **all 10** that pinned `cycle_exact=false` — including all three logs of
the memory bisect that was the dead end. The line naming the real cause was in the host log the whole
time ✅.

A quieter second consequence, worth knowing whenever a config seems to be ignored: `fixup_prefs()`
also forces **`cpu_compatible = true`** whenever `cpu_memory_cycle_exact` is set — so a config asking
for `cpu_compatible=false` (which Amix wants) silently does not get it ✅.

### Why it stayed hidden, and the rule ✅

A GUI-saved config always writes all four keys, so every config derived from the GUI or from a golden
image already carries `cycle_exact=false` — the default had never been exercised. A hand-written
config does not, and the omission **does not appear in a config diff against a GUI-saved file as a
changed value** — only as one absent key among ~138 other absent keys ✅.

> **The rule: a hand-written `.uae` is guilty until proven otherwise.** Derive from a GUI-saved or
> known-good config when you can; when you must hand-write one, pin `cycle_exact=false` explicitly
> with a DO-NOT-REMOVE comment naming the trap ✅.

Two boundaries on this finding, stated so nobody over-reads it:

- **It is not an emulator defect.** The emulator implements what the config asked for. Changing
  `default_prefs()` would be an upstream-facing behaviour change affecting every user, and is a
  separate decision ✅.
- **Why the cycle-exact core kills Amix specifically has not been root-caused** — the ablation
  established *that* it does (10 boots, same image and same kernel throughout, including the run that
  added `cycle_exact=false` and nothing else and reached multiuser), not *why*. Treat "the cycle-exact
  68030 core is not an Amix-capable core" as a measured operational fact, not an explained one.

## The FP-disabled frame's Next PC: a metric a UAE-family bed cannot fail ✅

UAE-derived cores (Amiberry included) **decode the whole instruction — immediate operand included —
before raising the F-line exception**, and stack the emulated PC as it stands after that decode. The
stacked "Next PC" in the 68060-style FP-disabled frame is therefore *faulting PC + true length* by
construction, for every addressing mode. Real silicon does not promise that: the field is
software-maintained, and for immediate operands the hardware cannot know the length (see
[quirks §33–34](quirks.md#68060-cpu-quirks)).

Consequence: an instrument that asks "does my decoded instruction length agree with the CPU's
stacked next-PC?" reduces, on this bed, to "do two decoders agree?" — a disagreement is **not
constructible**. A zero from that instrument on the bench is true and carries no information about
silicon; the metric is metal-only. This is not an emulator bug — a fully decoded Next PC is a
legitimate value for a field the vendor's own software fills in — but it is a fidelity gap of the
useful kind: one located line of behaviour that fully explains a metal-versus-bench divergence.

**The general rule:** before registering a bench number as a pass, ask whether the bed *can* produce
a failure. A metric a bed cannot fail is not a test.

### The vector-60 gap: a bench that could not raise it at all ✅

The Next-PC field above is a fidelity gap the bed silently *passes*; the neighbouring one is a fidelity
gap the bed silently *cannot exercise*. On a 68060 the four
[unimplemented-effective-address FP forms](68040-68060-status.md#the-fpu-less-68060-lane-software-floating-point-on-real-silicon)
(extended- and packed-decimal immediates, dynamic `fmovem.x`, and `fmovem.l` immediate loads to two
or more control registers) trap not to the ordinary F-line vector 11 but to **vector 60**, with a
distinct format-$0 frame — and real 68LC060 silicon raises it for those forms every time. One
UAE-family bench emulator was found **unable to raise vector 60 at all** for an FPU-less 68060
configuration: a single boolean term in its exception-raising guard suppressed it, so a kernel's
vector-60 handler could never be exercised on that bed even though the same code path fired on every
metal boot ✅. Like the Next-PC case this is not a modelling *choice* — it is one located line of
behaviour that fully explains a metal-versus-bench divergence — and it was closed with a narrowed
guard, verified byte-for-byte not to touch any other configuration ✅. The general "any 68060
emulator" statement is 🟡 (one codebase, not a survey); the metal behaviour and this bench's gap are ✅.

## An emulated CPU can report a memory window as faulty where the real CPU reads it clean ✅ {#emulated-memory-window}

A memory-test result taken through an emulated CPU is a result about **the emulated access path**, not
only about the memory. Measured on one board, same diagnostic, same 16 MB window, the two CPU paths
disagreed completely ✅:

| | emulated 68040 path | real 68LC060 |
|---|---|---|
| whole-block address check | **fails, 4 / 4 runs** | **passes** |
| failing boundary | wandered between runs (≈8.5 / 12.5 / 16 MB) | one clean, stable boundary |
| address-error mask | a different bit set on every power cycle | empty |
| detected fast RAM | over-counted by exactly the absent 4 MB | correct |

The window really held **12 MB of working RAM with the top 4 MB unpopulated**, and the emulated path's
failures were an **access artifact** ✅. A second tell arrived free: three different mechanisms for
looking at the *same* guest addresses returned three different pictures in that session. **When a
value depends on how you looked at it, the disagreement is in the tooling.**

Four candidate mechanisms were actively contradicted before the artifact was confirmed, and the
negative results are worth recording because they were expensive ✅:

| candidate | what killed it |
|---|---|
| a discrete hardware fault | a bad joint does not move its boundary *and* change its bit set on every power cycle |
| address aliasing | two addresses inside the window demonstrably held different values at the same time |
| a host/guest address-translation leak into the emulator's own memory | its decisive test came back negative, with a positive control at a neighbouring address proving the read-out worked |
| motherboard DRAM refresh starvation | decay predicts errors clustering at the **start** of a verify pass (oldest cells first); 3 of 4 runs put them at the **end** — and unrefreshed DRAM decays in milliseconds to seconds, not minutes |

**The rule, not the verdict, is the transferable part**: run the identical test on a second CPU path
before attributing a memory failure to hardware. The diagnostic framing for a suspect accelerator is
on [Z3660 board timings](z3660-timings.md#moving-boundary).

## Blaming an emulator release needs the same image on the *old* build ✅

A guest that stops booting after an emulator upgrade looks like an emulator regression, and the
reflex is to pin the old release. **Run the identical image on the pre-upgrade build first.** In one
case an inherited disk image failed to boot on a new emulator build; the *same image copy* panicked
**identically** on the older build, exonerating the release and locating the defect in the image
lineage instead ✅.

The panic signature is worth recognising because it names the layer:

```text
s5mountroot: VOP_OPEN error 6
PANIC: vfs_mountroot: cannot mount root: errno 89
```

**`VOP_OPEN error 6` is `ENXIO`** — the root device could not be opened *at all* ✅, which is a
different fault from the `VOP_OPEN error 5` (`EIO`) variant on [the boot page](boot-process.md), where
the device opened and the read failed. In both cases `errno 89` is only the `vfssw[]` walk running
out of filesystem types to try, not a filesystem-format verdict — see
[root-filesystem selection is by probe](boot-process.md).

Two rules follow, and they apply to any bench that carries images forward:

* **An image whose provenance you cannot reconstruct is not a control.** A long-inherited image
  accumulates changes nobody recorded; when it fails, it cannot distinguish an emulator defect from
  its own history. Retire such a lineage and mint a fresh image from a known installer run rather
  than patching it.
* **The falsification is cheap** — one boot of the same bytes on the previous build — and it is the
  only step that separates "the emulator changed" from "this image was already broken".

## Where this was discovered

These findings come from running Amix on the **Z3660**, a Zorro III **68030/68060-class accelerator** built around a Xilinx **Zynq-7000** SoC, whose firmware emulates the 68k with a **UAE-4.4.0-derived software CPU (with MMU)** running on the Zynq's ARM cores. So a real **A4000 + Z3660** executes Amix on that software 68030 emulator — which is exactly why the emulator-core fidelity above is load-bearing on *real hardware*, and was verified there: Amix 2.1 cold-boots to a **multiuser root login** (confirmed on the HDMI console and over telnet, `uname -a` → `UNIX_System_V … 2.1c … m68k`), reproduced on a real A4000 + Z3660 (2026-06). ✅

The board itself, its Zynq SoC, and the two native Amix drivers written for its peripherals are covered in the case studies:

- [Z3660 piscsi SCSI driver (`z3660.c`)](../drivers/z3660-scsi-driver.md) — where the "boots then hangs" was first triaged to the **emulator core, not the driver** (the driver was carrying every disk transfer byte-perfectly). That page holds the **driver-vs-emulator triage method**; this page holds the emulator-side mechanism.
- [Z3660 ethernet driver (`zen0`)](../drivers/z3660-ethernet-driver.md) — the network sibling on the same combo board.

The lesson that "on an emulated 68k, *the machine hung* ≠ *your driver hung*" is on the [quirks checklist](quirks.md#16-on-an-emulator-the-machine-hung-your-driver-hung) as a driver-authoring gotcha; the emulator behaviours it points at are documented here.

## See also

- [How Amix boots](boot-process.md) — the compressed-kernel bootstrap and the demand-paging path these frames serve.
- [Kernel architecture](kernel-architecture.md) — the monolithic SVR4 kernel, the HAT/MMU layer, and the switch tables.
- [Hardware & requirements](hardware.md) — why the MMU and FPU are mandatory; the per-emulator config table.
- [Running Amix in WinUAE](../getting-started/emulation-winuae.md) — the reference emulator's MMU/JIT/SCSI settings (the *knobs*; this page is the *why*).
- [Z3660 piscsi SCSI driver](../drivers/z3660-scsi-driver.md) — the driver-vs-emulator triage method behind the first-generation fixes.
- [Quirks](quirks.md) — the emulator-hang and interrupt-storm gotchas as one-line checklist items.

- [Amix on Amiberry](../getting-started/emulation-amiberry.md) — the config keys, including the
  mandatory `cycle_exact=false`.

## Sources

- amix-kerntools brief `e2-relink-corruption-measured` (2026-07-21): measure-relink.sh N=20 run on the raw golden-work image, 2026-07-20.
- `sources/research-brief.md` §19 (Emulation fidelity — the 68030 bus-error-frame requirement and the SCSI INT2 / `service_cadence` finding) and §18 (the Z3660 piscsi driver, whose emulator-core triage first surfaced the frame bugs).
- **Z3660 firmware repository**, branch `amix-main` @ `703c0dc` — first-party, **cited not reproduced** (the emulator source and its fixes are owned by that repo):
  - First-generation demand-paging frame fixes: `3069e22` ("mmu030: fix demand-paged ifetch resume — restore the prefetch-fault sentinel in frame `$B`", the `SIGILL`) and `0b42cb8` ("mmu030: port full WinUAE format-`$B` frame-storage (fix mid-instruction-restart `SIGSEGV`)"). These are the live successors of the now-deleted `amix-boot` commits once cited as `c8b9398` / `e3f9440`; `0b42cb8`'s body names `c8b9398` as its predecessor, and the dead hashes are absent from the current tree. ✅
  - Second-generation multi-fault-continuation fixes: `7ff5774` ("emu: fix 030 MMU multi-fault continuation corrupting the bus-error frame PC"; behavioural change in `src/uae/newcpu.cpp`) and `acdfe15` ("emu: fix 030 MMU in-RTE retry-access rebuilding a mis-attributed bus-error frame"; `src/uae/cpummu030.cpp` — `mmu030_insn_start_pc = pc; regs.opcode = regs.irc = mmu030_opcode;` after `m68k_setpci(pc)`). Corroborated by `CHANGES.md` and the host MMU harness (60/60 → 64/64 with a two-fault-continuation regression test). ✅
  - SCSI INT2 / poll-cadence: `f7bbdb0` (the run-loop consumer + runtime `SERV`/`PERF`; `check_uae_int_request()` throttled to every `service_cadence` instructions in `src/uae/newcpu.cpp`, `do_specialties()` kept per-instruction) and `e0e17d5` ("emu perf: service_cadence config option (z3660cfg + per-preset)"; `Z3660/src/config_file.{c,h}`, default sentinel → clamp `<1 → 1`). ✅ (knob mechanics) The 4-boots / 8-hangs boundary and the INT2-latency attribution are from the firmware's `docs/AMIX.md` and shipped `z3660cfg.txt`, an author hardware sweep — 🟡.
  - Two-core DMA cache coherence (branch `amix-main`, source_commit `51038f3`): `e37bb43` (SD-controller producer-side `Xil_DCacheInvalidateRange`/`Xil_DCacheFlushRange` before direct read/write) ✅; `0a4c064` (consumer-side core1 `Xil_L1DCacheInvalidateRange` after the completion spin, READ-only — a parked Cortex-A9 still speculatively refills L1D over the DMA target) ✅. The "both endpoints must maintain their own caches" general rule generalizes those two fixes, carried 🟡. Baseline was **2/2 failures** on the unfixed firmware (kmem wild-pointer bus error at `0x4AFC000C`; then a silent root-FS `ufs_readdir` corruption); post-fix a full CD read suite came back **byte-identical, 7/7** `cmp`-verified host-side (T2.P3, real A4000 + Z3660, 2026-07-10 → 07-12). ✅
- **Live result** (first-party, ✅): Amix 2.1 cold-boots to a multiuser root login from the piscsi disk on a real A4000 + Z3660 (2026-06) — HDMI console ("The system is ready") and telnet (`uname -a` → `UNIX_System_V … 2.1c … m68k`); a 27-reboot multi-hour soak under fork/exec load ran clean (Z3660 `docs/AMIX.md`). One rare bus-error-frame `SR`-flip under extreme sustained paging load remains tracked (did not recur across the soak) — 🟡.
- First-party **accelerator acceptance pass on a real A4000D** (2026-08-31, workspace record) ✅ —
  the emulated-versus-real CPU-path disagreement over a 16 MB motherboard memory window (the emulated
  path failing 4/4 with a wandering boundary and a per-power-cycle bit set, the real 68LC060 returning
  one clean 12 MB / 4 MB split with an empty error mask), the three-different-views observation, and
  the four contradicted candidate mechanisms. Board-level signal-path documentation from that pass is
  deliberately not reproduced here.
- The **2026-08-14/15 golden-regeneration event** (workspace record) ✅ — the emulator-exoneration
  falsification: an inherited guest image that would not boot was re-run **byte-identically on the
  pre-upgrade emulator build** and panicked the same way (`s5mountroot VOP_OPEN error 6` → `PANIC:
  vfs_mountroot: cannot mount root: errno 89`), so the release was cleared and the image lineage
  retired in favour of a freshly installer-minted root. Emulator-version numbers and image
  filenames are project bookkeeping and are deliberately not reproduced here.
- First-party **68040/68060 port campaign**, FPU-less-060 software-FPE lane, real 68LC060 metal (2026-08) ✅ — the vector-60 bench-fidelity gap: a UAE-family emulator whose exception-raising guard suppressed vector 60 for an FPU-less 68060 configuration (so a kernel's vector-60 handler could not be exercised on that bed), closed by a narrowed guard verified byte-for-byte against every other configuration. The "any 68060 emulator" generalization is 🟡 (one codebase). The 68060 vector-60 architecture and instruction class are grounded on [the 040/060 status page](68040-68060-status.md#the-fpu-less-68060-lane-software-floating-point-on-real-silicon). No vendor MC68060 / FPSP text and no port source reproduced — measured behaviour paraphrased.
