---
title: "Case Study: Z3660 ethernet driver (zen0)"
summary: How a native SVR4 STREAMS/DLPI ethernet driver (zen0) was written for the Z3660 accelerator's onboard Zynq ethernet, giving Amix full bidirectional TCP/IP on real hardware — talking the firmware's frame mailbox, not emulating a NIC, and dodging an INT6 interrupt storm with polled RX.
status: draft
---

# Case Study: Z3660 ethernet driver (zen0)

This is the **network analogue of the [A4091 / 53C710 SCSI driver](a4091-53c710-driver.md)**: a
brand-new native driver for a board Amix was never meant to support, written, built, deployed and
**validated end-to-end on real hardware**. Where the A4091 work got Amix to boot with root on a
Zorro III SCSI controller, this work gives Amix **full bidirectional TCP/IP over the Z3660
accelerator's onboard ethernet**, as the interface **`zen0`**. It pulls together the
[STREAMS driver model](writing-a-streams-driver.md), [the kernel build](kernel-build.md) and the
[networking stack](../how-it-works/networking.md) — applied at once to a real combo board.

The work is **first-party and reproduced on real hardware** — written, built, deployed and run on a
physical **Amiga 4000 + Z3660** during 2026-06. Unless noted, every claim here is **✅ Verified**
(driver source we wrote, firmware source we read, or a result reproduced live on the hardware);
inferences and unconfirmed items are tagged 🟡 inline, carried verbatim from the source brief per the
repo's [confidence-tag policy](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md). The
source is the **amix-z3660net** project — `src/z3660eth.{c,h}`, `driver.conf`, `userland/S99zen` — the
sibling **amix-z3660** SCSI project's `ETHERNET-SCOPING.md`, and the Z3660 firmware source.

> **One-line summary.** Amix now has full TCP/IP over a native SVR4 STREAMS/DLPI driver (`zen0`) for
> the Z3660's onboard ethernet — **not NIC emulation**. The only real-hardware blocker turned out to
> be an interrupt storm, fixed driver-side with **no firmware change**. ✅

## What the Z3660 and `z3660eth` are

The **Z3660** is a 68030/68060-class **Zorro III accelerator** built around a Xilinx **Zynq-7000**
SoC ✅. The Zynq PS runs firmware (`Z3660.bin`, loaded by `BOOT.bin`) that emulates the 68k *and*
drives the card's real peripherals — including the card's **Zynq Gigabit Ethernet MAC (GEM)** via the
Xilinx `XEmacPs` driver. Ethernet, audio and USB all hang off a **piscsi**-style register/mailbox
interface in the card's RTG register page ✅.

`z3660eth` is a **native Commodore Amiga Unix (Amix, SVR4.0, m68k 68030) STREAMS/DLPI ethernet
driver** for that onboard GEM ✅. It is the network counterpart of the `amix-z3660` SCSI driver
(`z3660.c`) for the same combo board.

**It is not NIC emulation.** The firmware already moves whole ethernet frames between the 68k guest
and the Zynq GEM — it does this for AmigaOS through the SANA-II `Z3660Net.device`. `z3660eth` speaks
that **same firmware mailbox** (a small MMIO register protocol over the Zorro III window) and presents
it to Amix as a **DLPI Style-1 connectionless ethernet provider**, brought up with the stock `slink` +
`ifconfig` STREAMS plumbing as interface **`zen0`** ✅. Contrast the [hydra-amix driver](case-studies/hydra.md),
which programs a real DP8390/NE2000 chip directly; here the chip-level work lives in the card's
firmware and the driver talks to it over a register protocol.

| Property | Value | Tag |
|---|---|---|
| Driver tag / interface | `zen` → **`zen0`** | ✅ |
| `cdevsw` major | **48** (the free `nostr` slot on the stock / A4091 kernel) | ✅ |
| Board AutoConfig id | **`0x144B0001`** | ✅ |
| Fixed combo base (AGA fallback) | **`0x10000000`** | ✅ |
| Station MAC observed on the wire | `00:80:51:01:02:03` | ✅ |
| Example IP | `192.168.2.39` (the build box keeps `.38`) | ✅ |
| DLPI style / limits | Style-1; `Z3660ETH_MAXDEV = 5` SAP streams, `Z3660ETH_MAXBOARDS = 1`, MTU 1500 | ✅ |

## The firmware mailbox: the protocol contract

All register offsets are **board-base-relative, 32-bit big-endian MMIO**, living in the RTG register
page at `board_base + 0x000` (piscsi is at `+0x2000`) ✅. Every offset was verified against the Z3660
driver headers (`z3660_regs.h`) and the firmware register enum/dispatcher (`rtg/zzregs.h`,
`rtg/rtg.c`); the in-repo source of truth is `src/z3660eth.h` ✅.

### Registers

| Name | Offset | Dir | Meaning |
|---|---|---|---|
| `ZZ_CONFIG` | `0x104` | W | `1` = enable INT6 delivery, `0` = disable, `24` (`8\|16`) = ack/clear ETH |
| `ZZ_ETH_TX` | `0x190` | W / R | **W** byte-length = trigger TX (synchronous, ~1 ms); **R** = TX result |
| `ZZ_ETH_RX` | `0x194` | W | write (any value) = advance / free the current RX slot |
| `ZZ_ETH_MAC_HI` | `0x198` | R/W | MAC bytes [0..1] = `(b0<<8)\|b1` |
| `ZZ_ETH_MAC_LO` | `0x19C` | R/W | MAC bytes [2..5]; a **write** triggers the GEM `SetMac` |
| `ZZ_ETH_RX_ADDR` | `0x1A4` | R | board-relative byte offset of the current RX slot |
| `ZZ_INT_STATUS` | `0x1A8` | R | pending bits: ETH = `1`, AUDIO = `2`, USB = `4` |

On the firmware side (`rtg/rtg.c`) these dispatch to `REG_ZZ_CONFIG` (~line 1150), `REG_ZZ_ETH_TX` →
`ethernet_send_frame()` (~1609), and `REG_ZZ_ETH_RX` → `ethernet_receive_frame()` (~1613) ✅.

### Frame windows

The frame buffers are real DDR reached through the Zorro III window, at fixed board-relative offsets
(from the firmware `memorymap.h`) ✅. Note the board base is `0x10000000`, so these windows land
**inside the 68030's TT0 range** (< `0x40000000`) and are directly mappable — this is *not* the
[A4091's unmapped TT-gap](a4091-53c710-driver.md) case; `sptalloc` here is simply a clean way to map
the full 128 KB region:

- **RX backlog ring** — `0x07ED0000`, 32 slots × 2048 bytes = 64 KB.
- **TX staging frame** — `0x07EE0000`, one frame.
- **GEM RX frame** — `0x07EF0000`.
- **Per-slot stride** — 2048 bytes; **per-slot header** — 4 bytes: `[0..1] = length`,
  `[2..3] = serial` (a monotonic frame serial used as the drain sentinel). The ethernet payload
  follows the 4-byte header.

> 🟡 **Latent firmware bug (documented, mitigated, not the cause of any observed failure).** The
> firmware constant `FRAME_MAX_BACKLOG` is **64** while only **32** real slots exist before the TX
> window — a 64-deep backlog would overrun the ring. The driver mitigates by **eager-draining** every
> poll tick *and* by **mapping the full 64-slot / 128 KB range**, so any `ZZ_ETH_RX_ADDR` value the
> firmware returns is always mapped memory. No overrun was observed in practice.

### TX / RX mechanics and the FCS boundary

- **TX** ✅ — copy the frame (min-padded to 60 bytes) into the TX window, then write the byte length to
  `ZZ_ETH_TX`. The trigger is **synchronous (~1 ms) with no completion IRQ**; reading `ZZ_ETH_TX` back
  returns the result code (`res = 0` = OK, observed on the wire). The single shared TX window is
  serialized by `info->tx_busy`; the ~1 ms trigger is **not** held at raised spl.
- **RX** ✅ — drained by re-reading `ZZ_ETH_RX_ADDR`, comparing each slot's serial header against
  `info->last_serial` to find fresh frames, delivering each up the stream, and strobing `ZZ_ETH_RX` to
  free the slot. The drain loop is **bounded** (≤ 256 iterations per call) so a runaway firmware can't
  wedge the kernel.
- **FCS / minimum-length boundary** ✅ — the firmware delivers the raw `XEmacPs_BdGetLength` and does
  **not** strip the FCS (there is no `FCS_STRIP` option). So the driver pads TX up to the 60-byte
  minimum and **does not** subtract `ETH_CRC_LEN` from the RX length — it must *not* inherit the stock
  `aen` driver's `-4`. (Same 60-vs-64 CRC boundary as the [hydra RX min-frame gotcha](case-studies/hydra.md#what-made-it-work),
  handled the other way round: hydra's DP8390 reports a length that *includes* the CRC, so it accounts
  for the 4 bytes; the Z3660 firmware hands back the raw length, so the driver must *not* subtract
  `ETH_CRC_LEN`. Both honour the 60-byte post-CRC minimum.)

## Driver architecture

`src/z3660eth.c` is a ~1034-line STREAMS/DLPI skeleton adapted from the stock Amix `aen` (LANCE) and
`hydra` drivers, with the chip layer replaced by the Z3660 mailbox ✅.

### Function map (all in `src/z3660eth.c`)

| Function | Role |
|---|---|
| `z3660eth_map()` | `sptalloc` + map the register page and the 64-slot frame region; fills `board_base`/`regs`/`frame`/`txwin`/`paddress`. Returns `ENXIO` when no Z3660 GEM is present |
| `z3660eth_autoconfig()` | discovery: `autocon(0x144B0001)`, else (AGA only) the fixed combo base `0x10000000`, verified via the firmware MAC register |
| `z3660eth_initialize()` | writes `ZZ_CONFIG`, primes `last_serial`, starts the RX poll callout |
| `z3660ethopen` / `z3660ethclose` | lazy-open: autoconfig on first `open` (like `aen`) |
| `z3660ethwput` / `z3660ethwsrv` | STREAMS write put / service |
| `z3660ethxmit()` | TX path: pad, copy to `txwin`, optional cache push, write `ZZ_ETH_TX` |
| `z3660eth_drain()` | the bounded RX drain (serial sentinel + `ZZ_ETH_RX` strobe) |
| `z3660eth_poll()` | the `timeout()` callout that calls `z3660eth_drain` each tick |
| `z3660eth_tx_drain()` | TX-side completion bookkeeping |
| `z3660ethintr()` | **future** interrupt entry point (not wired into `int2_tbl` yet) |
| `z3660ethproto()` | DLPI primitive dispatch (bind / unbind / attach / unitdata / …) |
| `toss_packet_up_stream()` | deliver a received frame up the matching SAP stream |
| `z3660ethioctl()` | the `zen.c` presence / status ioctls |
| `z3660ethinit()` | driver init |

### Key design decisions

- **Lazy-open + polled RX → no `int2_tbl` / `init_tbl` edit.** ✅ The driver autoconfigs on the first
  `open` and services RX from a **clock-level `timeout()` poll callout** (period
  `Z3660ETH_POLL_TICKS = 1`). This is *why a GEM-less build box boots cleanly and `open()` simply
  returns `ENXIO`* — there is no boot-time probe that can panic. It is a deliberately different choice
  from hydra's "probe at boot (`init_tbl`/`hydrainit`), full-init on open" split — see
  [Writing a STREAMS driver](writing-a-streams-driver.md#init-split-probe-at-boot-full-init-on-open).
- **No `spl6()` / `splx()`.** ✅ Those primitives **do not exist in Amix SVR4.0** — they are a
  BSD/hydra idiom. The stock `aen` driver and `z3660.c` do **zero** explicit interrupt masking, so in
  `z3660eth.h` they are no-ops: `#define splz3660eth() 0` and `#define splx(s) ((void)(s))`.
  Referencing the nonexistent symbols had left them **undefined in the kernel link**, which the
  `nm -u` clean-gate (below) rejects — a real build-breaker we hit and fixed.
- **DLPI Style-1**, up to `Z3660ETH_MAXDEV = 5` SAP streams per board, `Z3660ETH_MAXBOARDS = 1`,
  MTU 1500 ✅.

## Kernel integration

A STREAMS network driver is **not** registered in `sd.c`'s `scsicard[]` table (that is the SCSI-stack
path the [A4091 driver](a4091-53c710-driver.md#the-card-registry-in-sdc) uses) — it is wired directly
into `master.d/kernel.c`'s `cdevsw[]` and built in its own `amiga/driver/<dir>/` subtree. Three edits
plus the subtree ✅:

1. **`/usr/sys/amiga/driver/z3660eth/`** — `z3660eth.c`, `z3660eth.h`, `z3660ethuser.h`, `Makefile`.
2. **`master.d/kernel.c`:** add `extern struct streamtab z3660ethinfo;` after the stock `aeninfo`, then
   claim cdevsw slot **48** (verify it is still the empty `/*48*/ … notty,nostr,…` row) by replacing
   `nostr` with `&z3660ethinfo`.
3. **`amiga/driver/Makefile`:** add `z3660eth/exp` to `OBJ` and a `z3660eth/exp:` build rule.

The machine-readable form is `driver.conf`, consumed by the `build-net-kernel.sh` tool in the
**amix-kerntools** project ✅:

```text
net  z3660eth  z3660eth.c  z3660ethinfo  48  zen  "Z3660 Ethernet"
```

Create the node and bring the interface up. As on [hydra](case-studies/hydra.md), Amix is SVR4.0 so
there is **no `ifconfig plumb`** — you link the stream in with `slink`, then `ifconfig` ✅:

```sh
mknod /dev/zen0 c 48 0
slink                                                       # ensure the base inet streams are linked
slink addaen /dev/zen0 zen0                                 # STREAMS multiplexor link
ifconfig zen0 192.168.2.39 netmask 255.255.255.0 up -trailers
route add default 192.168.2.1 1                             # trailing 1 = the (required) metric
```

## ★ The INT6 interrupt storm — *the* real-hardware blocker

The single most important lesson of the project ✅. On the **WinUAE build box** (no Z3660 GEM) the
whole integration and build path worked — the kernel boots, `z3660eth` registers at cdevsw 48, and
`open(/dev/zen0)` returns `ENXIO` with **no panic**. But on the real A4000 + Z3660:

**Symptom.** The kernel booted with the driver and reached `login:`, but the moment the interface was
brought up the box **hard-locked** (caps-lock LED dead = the 68k is hung hard, not merely busy). ✅

**Root cause** (diagnosed from the firmware serial `[PC]` heartbeat + `nm` of `relocunix`): the
firmware raises **Amiga INT6 (EXTER)** on *every* received frame — `rtg/rtg.c` sets
`interrupt_enabled_ethernet` from `ZZ_CONFIG` bit 0 (~line 1166), and the RX path calls
`amiga_interrupt_set(AMIGA_INTERRUPT_ETH)` (~line 336). **Amix has no level-6 ethernet interrupt handler** — its
`p6int` / `aciabintr` chain runs but never acks the eth source, so the LAN's normal **ARP broadcast
traffic storms INT6 and instantly hard-locks the machine** ✅. (Exactly the INT6 risk the scoping doc
had flagged in Phase 0.)

**Fix** (commit `b06cf45`): the driver writes **`ZZ_CONFIG_DISABLE` (0)** instead of
`ZZ_CONFIG_ENABLE` (1), so the firmware never raises INT6. RX is unaffected — the firmware still fills
the backlog ring regardless of the interrupt-enable flag (`ethernet.c` only gates a *debug print* on
it), so the **bounded poll/drain callout keeps working**. **No firmware change was needed** ✅.

> The lesson generalizes: *the firmware's interrupt model assumed an AmigaOS handler that Amix does
> not provide; the safe path is polled RX with the firmware interrupt explicitly disabled.* This is
> recorded as a gotcha on [the quirks checklist](../how-it-works/quirks.md).

## Other bugs that mattered

- **`spl6`/`splx` + `rico.h`-isms (Phase-1 build-breakers, commit `84c9a4f`).** ✅ Besides the
  nonexistent `spl6`/`splx` symbols (above), a STREAMS driver must spell out `unsigned char/long/short`
  — **not** `uchar`/`ulong`/`ushort`, which are `rico.h`-only (included by the SCSI driver, not this
  one). Both showed up only at kernel-link time, as undefined symbols.
- **The 030 data-cache flush — turned out *not* to be needed.** ✅ The eth DDR windows are cacheable
  (under TT0), so a stale-cache TX/RX coherency hazard was the scoping's stated *top* risk. The driver
  has an **optional** line-granular flush (`Z3660ETH_CACHE_FLUSH`, `cpushl %dc` over the TX/RX
  windows), **default OFF**. On real hardware it was **not required** — TX and RX are byte-correct with
  the flush off, confirming the 030 data cache is effectively transparent to these windows here. Left
  OFF.

  > 🟡 Caveat for a future maintainer: the flush helper uses GNU-style `asm volatile("cpushl …")`. The
  > Amix licensed K&R `cc` may not accept GNU inline-asm syntax; if the flush is ever needed it may
  > have to move to a separate `.s` file. Untested, because it was never needed.
- **Auto-bring-up race (the boot script, not the driver).** 🟡 On a *fast clean boot* the bring-up
  `slink addaen` can race ahead of the inet base STREAMS plumbing and fail to open `zen0` (observed
  once: the box reached `login:` but `zen0` never came up; cause inferred from the working manual
  bring-up, which always ran a bare `slink` first — not independently traced). The boot script now
  runs a bare `slink` first, then **retries** `slink addaen` in a loop (below).

## Build & the `nm -u` clean-gate

The kernel is built **on a networked Amix box** (the WinUAE/Amiberry build box at `192.168.2.38`).
On-box `ld` corrupts a high fraction of kernel links (the "D245" boot-breaker), so the link must be
repeated until it produces a clean kernel ✅ — the same hazard the [A4091 build](a4091-53c710-driver.md#build-install)
and [the kernel-build page](kernel-build.md) describe.

**★ The correct clean-kernel bar is `nm -u`, not `sum -r` recurrence or `checkunix`.** ✅ This was
learned the hard way (2026-06-21) and supersedes older notes:

- `relocunix` is literally `ln unix relocunix`, gated by the kernel Makefile's own test:
  `nm -h -u unix | egrep -v '(etext|edata|end)'` **must be empty** (no undefined symbols).
- A `unix` can pass `checkunix` (which only validates the `.symtab` shape) while still having
  undefined symbols — so `checkunix` alone is **insufficient**. The working gate relinks until the
  kernel is **both** `nm -u`-clean **and** `checkunix`-clean, then `ln`s it to `relocunix`. (A
  recurring `sum -r` among clean builds is gold confirmation but does not converge on this larger
  kernel and is not required.)
- Implemented in the amix-kerntools `tools/build-clean-net-kernel.sh`.

> ⚠️ **Never delete the 22 generic SVR4 `exp` blobs** (os, io, netinet, rpc, vm, …): they ship
> pre-linked with no source on the box and are not regenerable. Only the `amiga/` tree + `master.d` +
> `fs/exp` + `local/exp` are re-rolled. (Deleting them once cost a painful restore.) ✅

Other on-box build realities (✅, validated on the build box): Makefiles have **no header-dependency
tracking** — after editing a `.h`, force-recompile the dependent `.o` (or `touch` the `.c`) and verify
the `md5`; **FTP is asymmetric** on the a2065 build box — `push` (PUT) is reliable but large `pull`
(GET) is flaky, so patch `kernel.c` on the box with `ed` and use **NFS** (`nfsvers=2`) for large
pulls; and a **fresh `/usr/sys` rebuild faults at `$40000000`** unless the `amix-base` DDR memory fix
(the `wip-emulated-ram` work) is in the image — the config that boots is the xfer-memory `.uae`.

## Deploy & bring-up to the real box

The real A4000 + Z3660 has **no network until `zen0` is up** (chicken-and-egg), so deployment is
out-of-band ✅. Two paths:

1. **Kernel-only shuttle** — copy the clean `relocunix` to the box via `transfer.hdf` (a small scratch
   Amiga hardfile on SCSI `c5d0`), stage it, `cd /stand; make`, reboot. Never re-image the root.
2. **Full-image / firmware deploy (no-console)** — the Z3660 ARM firmware console has a **TFTP
   server**. Power-cycle into the ARM console (spam `C` at power-on), `P` to start TFTP at
   `192.168.2.29`, `PUT` the artifact, `R` to reboot: path **`0:`** (FAT32) holds `Z3660.bin` (the
   firmware, ~12.3 MB, ~21 s TFTP; built with `cd <your Z3660 checkout> && ./docker/run.sh make
   bootbin` → `…/Alfa/sd_card/BOOT.BIN`, incremental control-core builds in seconds); path **`1:`**
   (exFAT) holds `hdf/Amix.hdf` (the full root image, ~629 MB, ~20 min TFTP). The host↔box TFTP host is
   the laptop wired directly to the Z3660.

> ⚠️ **Operational gotchas (✅, all hit this session).** Whatever switches power to the box, verify the
> **serial has actually gone silent** before powering back on — a remote switch reporting success is not
> proof the machine went down, and a cut on a still-running box costs you an `fsck` on the next boot.
> Do not rely on remote video to read the Amiga console either: a video-capture path can show a solid
> black frame while the machine is perfectly alive. Detect state from the **firmware serial `[PC]`
> heartbeat** (pinned PC = hung; varying = alive) and, once `zen0` is up, over **telnet/ftp**. Keep the
> serial stream logged to a file — a bring-up is reconstructed from the log, not from the screen.

### Boot auto-bring-up — `/etc/rc2.d/S99zen`

The amix-z3660net repo ships `userland/S99zen` (installed as `/etc/rc2.d/S99zen`). It is
**backgrounded** so a datapath problem can never hang the boot (the box still reaches `login:`), and
**hardened** for the bring-up race above ✅:

```sh
#!/bin/sh
# S99zen -- bring up zen0 at boot, backgrounded; cdevsw major 48.
[ -c /dev/zen0 ] || mknod /dev/zen0 c 48 0
(
  sleep 5
  /usr/sbin/slink                       # ensure the base inet streams are linked
  i=0
  while [ $i -lt 20 ]; do
    /usr/sbin/slink addaen /dev/zen0 zen0 && break
    sleep 3
    i=`expr $i + 1`
  done
  /usr/sbin/ifconfig zen0 192.168.2.39 netmask 255.255.255.0 up -trailers
  /usr/sbin/route add default 192.168.2.1 1
  /usr/sbin/ifconfig zen0
) > /tmp/zen-bringup.log 2>&1 &
```

> ⚠️ `zen0` only comes up after the **full** boot completes (including an `fsck` + reboot if the SD
> image is dirty). Do **not** conclude "broken" from an early serial check — give it the whole boot. ✅

## Status — ✅ works on real hardware (2026-06-21)

Validated on a real **A4000 + Z3660**, all reproduced live ✅:

| Test | Result |
|---|---|
| `ifconfig zen0` | `flags=23<UP,BROADCAST,NOTRAILERS>`, inet `192.168.2.39`, mask `ffffff00` |
| Inbound flood ping (laptop → `.39`, 40 pkts @ 50 ms) | **40/40 received, 0% loss** (~3–19 ms RTT) |
| Outbound: box → laptop (`ping 192.168.2.66`) | `192.168.2.66 is alive` |
| Outbound: box → gateway (`ping 192.168.2.1`) | `192.168.2.1 is alive` |
| `netstat -in` for `zen0` | **Ierrs = 0  Oerrs = 0  Collis = 0** (e.g. 895 Ipkts / 376 Opkts) |
| Remote login (`telnet` / `ftp` over `zen0`) | works (drove the box entirely over the network) |
| Sustained FTP throughput | **~185 KiB/s**, stable across 3 consecutive ~3.4 MB transfers |

> 🟡 **Throughput note.** ~185 KiB/s (≈1.5 Mbit/s) is the measured FTP rate — a working baseline, not
> a tuned result; the performance side is considered still flaky and not worth chasing yet. The
> interface itself reports **zero** errors/collisions even under flood load.

## Known issues & open questions

- 🟡 **Boot reliability is gated by unrelated boot panics, not the driver.** The Amix root is a
  non-journaled UFS; a cold power-cut can corrupt it and boot-time `fsck` is effectively broken (a
  separate known issue), so a dirty root can panic before reaching the bring-up. When the boot is
  clean, networking comes up. Always prefer **clean shutdowns** (`shutdown -i0`; verify the network
  drops, i.e. the FS unmounted) before power-cycling.
- 🟡 **Auto-bring-up race** — mitigated by the hardened `S99zen`, not yet stress-tested across many
  cold boots.
- ✅ **Interrupt-driven RX is future work.** RX is polled today. A true ISR path (`z3660ethintr()`
  wired into `int2_tbl[]`) needs a level-6 hook the firmware's INT6 model doesn't safely give Amix; it
  is gated on a board-mod. The polled callout is correct and measured to work; interrupt RX would
  mainly help latency/CPU.
- ✅ **Cache flush left OFF**; revisit only if a future board/firmware revision changes the
  cacheability of the eth windows.
- 🟡 **The in-repo amix-z3660net docs lag the real-hardware state.** The lower `## Status` block of
  `README.md` and the `## Real-world build notes` in `BUILD.md` still describe the pre-real-hardware
  state and the superseded `sum -r` clean-gate; the authoritative facts are the ones on this page (the
  `nm -u` gate and the real-hardware status).

## See also

- [Z3660 piscsi SCSI driver](z3660-scsi-driver.md) — the **SCSI sibling on the same Z3660 combo
  board**: the same firmware-mailbox style of register protocol, applied to disk I/O — it boots Amix
  multiuser with root on real hardware.
- [A4091 / 53C710 SCSI driver](a4091-53c710-driver.md) — a separate Zorro III SCSI card (a real
  53C710); the D245 clean-gate and Zorro III bring-up context this builds on.
- [Writing a STREAMS driver](writing-a-streams-driver.md) — the third driver kind; `zen0` is a second
  worked example (polled RX, firmware mailbox) alongside hydra (INT2, DP8390).
- [Hydra DLPI case study](case-studies/hydra.md) — the other modern Amix net driver; the mirror-image
  60-vs-64 CRC boundary lives there.
- [Networking](../how-it-works/networking.md) — the SVR4 STREAMS TCP/IP stack `zen0` joins; static IP,
  DNS off by default, the `route` metric.
- [Emulation Fidelity](../how-it-works/emulation-fidelity.md) — the 68030 bus-error-frame and SCSI
  INT2-latency requirements of the **same Z3660 UAE-derived emulator** this driver runs on.
- [Building and installing a kernel](kernel-build.md) — the relink → `relocunix` cycle and the D245
  clean-gate this driver's build depends on.
- [Device & card list](../reference/device-list.md) — the `cdevsw` major 48 / `zen` assignment.
- [Quirks](../how-it-works/quirks.md) — the firmware-INT6/polled-RX gotcha in the checklist.

## Sources

- **Driver source we wrote** (primary, ✅): the **amix-z3660net** project (git, branch `master`) —
  `src/z3660eth.c` (~1034 lines), `src/z3660eth.h` (register map, frame-window layout, the `spl`
  no-ops), `src/z3660ethuser.h`, `src/Makefile`, `driver.conf` (the `net z3660eth … 48 zen` stanza),
  `userland/S99zen` (boot auto-bring-up), `userland/{bringup.sh,network-config.zen,zen.c}`,
  `README.md`, `BUILD.md`; commits `f04d283` (initial STREAMS/DLPI driver), `2d26315` (on-box
  integration scripts), `84c9a4f` (fix `spl6`/`splx` + `rico.h`-isms — Phase-1 gate), `b06cf45`
  (**do not enable firmware INT6** — the storm fix), `029ee9b` (validated on real HW; hardened
  `S99zen` + README real-HW status).
- **Firmware source we read** (primary, ✅): the Z3660 firmware
  `Z-TURN/vitis_ide/Z3660/src/` — `rtg/rtg.c` (`REG_ZZ_CONFIG` / `REG_ZZ_ETH_TX` / `REG_ZZ_ETH_RX`
  dispatch, the INT6 raise), `ethernet.c`, `memorymap.h`, `rtg/zzregs.h`.
- **Design / scoping** (primary, ✅): the **amix-z3660** SCSI project's `ETHERNET-SCOPING.md` (the
  protocol contract, cache-coherency analysis, the INT6 risk, the phased plan).
- **Real-hardware results reproduced live** (2026-06-21, A4000 + Z3660, ✅): `ifconfig zen0`,
  `netstat -in`, laptop↔box `ping` / `ftp`, and firmware serial `[ETHCFG]` / `[ETHTX]` debug
  breadcrumbs (a temporary `rtg.c` build, since reverted).
- **Kernel build tooling** (✅): the **amix-kerntools** project — `tools/build-clean-net-kernel.sh`
  (the `nm -u` clean-gate), `tools/build-net-kernel.sh` (consumes `driver.conf`).
- Magic numbers (✅): cdevsw major **48**; board autocon `0x144B0001`; fixed combo base `0x10000000`;
  iface `zen0` @ `192.168.2.39`; build box `192.168.2.38`; TFTP `192.168.2.29`; station MAC
  `00:80:51:01:02:03`.
