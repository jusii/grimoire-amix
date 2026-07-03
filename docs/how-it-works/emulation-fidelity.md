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

- `N` = the number of emulated instructions run between calls to the emulator's interrupt-service poll (`check_uae_int_request()`), i.e. the emulator batches `N` instructions between the poll that detects the Amiga IPL/INT2 line. **Default 1** (poll every instruction); values below 1 are clamped to 1. ✅
- It is settable at boot in `z3660cfg.txt` and per-preset config (Z3660 commit **`e0e17d5`**), and cyclable at runtime `1→2→…→64→1` from the serial `SERV` console (commit `f7bbdb0`). ✅
- Raising it trades interrupt latency for CPU throughput — measured on a real A4000 + Z3660 (Amix 2.1, Dhrystone 2.1) at up to ~**1.3× CPU** from cadence 1→64, with disk I/O essentially flat and a knee around 8. ✅

The **Amix-safe boundary**: cadence **2 and 4 boot** cleanly; cadence **8 hangs** the A3000-SCSI bootstrap. 🟡 So the recommendation is `service_cadence 4` at boot — capturing most of the speed-up — and raising it to 8 only *after* Amix is up, via the `SERV` menu. 🟡

> **Confidence.** The knob, its default, the clamp, and the batched-poll semantics are **code-grounded** ✅. The **INT2-latency attribution** and the exact **4-boots / 8-hangs** boundary rest on the author's hardware sweep (recorded in the firmware's own docs and shipped config, and consistent with the SCSI path being level-2 interrupt-driven), not on a root-caused defect or a committed test artifact — carried **🟡**. Note the knob's own introducing commit (`e0e17d5`) was initially *more* conservative ("any cadence > 1 hangs before MMU-enable; keep the Amix preset at the default"); the "4 is safe" result is the later, refined finding, and **no shipped preset actually bakes in a non-default cadence** — the `4` is a recommendation. 🟡

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

## Sources

- `sources/research-brief.md` §19 (Emulation fidelity — the 68030 bus-error-frame requirement and the SCSI INT2 / `service_cadence` finding) and §18 (the Z3660 piscsi driver, whose emulator-core triage first surfaced the frame bugs).
- **Z3660 firmware repository**, branch `amix-main` @ `703c0dc` — first-party, **cited not reproduced** (the emulator source and its fixes are owned by that repo):
  - First-generation demand-paging frame fixes: `3069e22` ("mmu030: fix demand-paged ifetch resume — restore the prefetch-fault sentinel in frame `$B`", the `SIGILL`) and `0b42cb8` ("mmu030: port full WinUAE format-`$B` frame-storage (fix mid-instruction-restart `SIGSEGV`)"). These are the live successors of the now-deleted `amix-boot` commits once cited as `c8b9398` / `e3f9440`; `0b42cb8`'s body names `c8b9398` as its predecessor, and the dead hashes are absent from the current tree. ✅
  - Second-generation multi-fault-continuation fixes: `7ff5774` ("emu: fix 030 MMU multi-fault continuation corrupting the bus-error frame PC"; behavioural change in `src/uae/newcpu.cpp`) and `acdfe15` ("emu: fix 030 MMU in-RTE retry-access rebuilding a mis-attributed bus-error frame"; `src/uae/cpummu030.cpp` — `mmu030_insn_start_pc = pc; regs.opcode = regs.irc = mmu030_opcode;` after `m68k_setpci(pc)`). Corroborated by `CHANGES.md` and the host MMU harness (60/60 → 64/64 with a two-fault-continuation regression test). ✅
  - SCSI INT2 / poll-cadence: `f7bbdb0` (the run-loop consumer + runtime `SERV`/`PERF`; `check_uae_int_request()` throttled to every `service_cadence` instructions in `src/uae/newcpu.cpp`, `do_specialties()` kept per-instruction) and `e0e17d5` ("emu perf: service_cadence config option (z3660cfg + per-preset)"; `Z3660/src/config_file.{c,h}`, default sentinel → clamp `<1 → 1`). ✅ (knob mechanics) The 4-boots / 8-hangs boundary and the INT2-latency attribution are from the firmware's `docs/AMIX.md` and shipped `z3660cfg.txt`, an author hardware sweep — 🟡.
- **Live result** (first-party, ✅): Amix 2.1 cold-boots to a multiuser root login from the piscsi disk on a real A4000 + Z3660 (2026-06) — HDMI console ("The system is ready") and telnet (`uname -a` → `UNIX_System_V … 2.1c … m68k`); a 27-reboot multi-hour soak under fork/exec load ran clean (Z3660 `docs/AMIX.md`). One rare bus-error-frame `SR`-flip under extreme sustained paging load remains tracked (did not recur across the soak) — 🟡.
