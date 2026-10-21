---
title: "Z3660 ethernet: the card's frame path, its config keys, and what each OS gets"
summary: How a received frame travels from the Z3660's Zynq GEM through the firmware's descriptor ring and backlog to the Amiga driver, the five z3660cfg.txt ethernet keys, the MAC-write ring-offset trap, how to read the card's counters, and measured Amix and AmigaOS throughput with each fix.
status: draft
---

# Z3660 ethernet: the card's frame path, its config keys, and what each OS gets

The Z3660's onboard ethernet is a Zynq **Gigabit Ethernet MAC (GEM)** driven by the card's ARM
firmware. The 68k side never touches the MAC. It reads finished frames out of a firmware backlog and
writes frames into a staging window, through a small register mailbox. Amix reaches it with the
[`z3660eth` driver (`zen0`)](../drivers/z3660-ethernet-driver.md). AmigaOS reaches it with the
SANA-II `Z3660Net.device`. This page covers the firmware half of that path, which both OSes share,
and the numbers measured on it in October 2026.

> **One-line summary.** In October 2026 an Amix push into a Z3660 ran at **25–30 KB/s** and the pull
> at about **600 KB/s**. The card was not the cause: the stock Amix kernel discards the fourth
> segment of every burst ([quirk 75](quirks.md#75-tcp-lower-read-queue-4k)). With that kernel fix,
> the driver's back-pressure and the firmware's receive ring, both directions now run at
> **340–370 KB/s** push and **560–650 KB/s** pull. On AmigaOS the levers were the device driver's
> receive loop and a firmware ring bug, and PrismNet now pushes **363–374 KB/s** and pulls about
> **1.4 MB/s** ✅.

## The receive path, end to end ✅

```text
wire → PHY (RGMII, on the Zynq's own pins) → GEM
     → receive descriptor(s)          one in 1.0 / upstream 1.03 beta 21; a ring of 16 in PR #33
     → receive ISR copies the frame into the backlog (2048-byte slots, 4-byte header: length, serial)
     → main loop raises the Amiga interrupt ("nag") while frames wait
     → 68k driver reads the slot, then writes ETH_RX to release it
```

- **Descriptors.** The released firmware (the fork's 1.0, and upstream's own 1.03 beta 21) gives the
  GEM a **single receive descriptor** (`RXBD_CNT 1`). A frame that arrives while that descriptor is
  still held is dropped in the MAC. The receive ISR plus its copy takes about 26 µs, against 121 µs
  for a full frame at 100 Mbit, so one descriptor loses frames only when the ISR is held off. The
  ring in [PR #33](https://github.com/shanshe/Z3660/pull/33) (build flag `ETH_RXRING`, default 16;
  `0` builds the old single descriptor) gives the GEM 16 descriptors, and the ISR drains every
  completed one in order ✅.
- **The backlog is not a ring.** Frames fill slots 0, 1, 2… of a round. The round restarts at slot 0
  only when the 68k has caught up. A **full backlog discards every frame not yet fetched**, not only
  the newest. The `eth_taildrop` key changes that (below) ✅.
- **The backlog's size bug.** The source declares `FRAME_MAX_BACKLOG 64`, but the backlog region in
  `memorymap.h` is 64 KiB, which is 32 slots of 2048 bytes. Slots 32–47 overwrite the outgoing frame
  and slots 48–63 the receive DMA buffers. With one descriptor the MAC dropped frames before the
  backlog grew that far. With a ring and an AmigaOS driver that falls behind, it does grow that far
  (measured 2026-10-20). PR #33 caps the backlog at 32 slots with a compile-time size check ✅.
- **The Amiga interrupt.** The receive ISR only fills the backlog. The interrupt to the Amiga is
  raised by the firmware's main loop after **1500 passes with frames waiting**, about **0.9–1 ms on a
  real 68060**, and it stays set until the driver acknowledges it. A driver that takes one frame per
  interrupt therefore drains about **one frame per millisecond** ✅. Amix does not use this interrupt
  at all: `z3660eth` disables it and polls ([the INT6 storm](../drivers/z3660-ethernet-driver.md#the-int6-interrupt-storm-the-real-hardware-blocker)).

## The MAC-write ring-offset trap ✅ {#mac-write-ring-offset}

Changing the station MAC address goes through `ethernet_update_mac_address()`, which in the released
firmware does `XEmacPs_Stop`, `XEmacPs_SetMacAddress`, `XEmacPs_Start`. **`XEmacPs_Start` rewrites
the GEM's receive and transmit queue base registers (`RXQBASE`, `TXQBASE`) to the first
descriptor**, while the firmware's software ring keeps its own head. With one descriptor the two
cannot disagree. With a ring they do if any frame arrived before the MAC write, and on a LAN there
is always broadcast traffic.

AmigaOS's `Z3660Net.device` writes the MAC when it opens, so on a ring build the receive ring came up
**offset for the whole boot** on six of seven AmigaOS boots. The signature:

- idle ping round trips of **seconds** (worst 6.8 s) instead of under a millisecond;
- one handler entry draining a dozen descriptors at once, then nothing for seconds;
- under load, GEM **resource errors** (the MAC laps into descriptors still in use);
- the interrupt controller showing nothing pending or masked: the interrupts were raised and taken,
  but the handler looked at an empty descriptor each time.

The fix in PR #33 writes the MAC registers in place (`LADDR1L`, then `LADDR1H`) without stopping and
restarting the GEM. After it, three of three cold boots were clean: idle ping about 0.7 ms, no
resource errors, and AmigaOS pushes of 305–315 KB/s on AmiTCP_NG. Amix never hit the trap, because
`z3660eth` reads the MAC once at probe and never writes it.

## Transmit ✅

- The trigger is synchronous: the 68k writes the frame length to the TX register, and its bus cycle
  is held until the firmware returns. In the released firmware the wait for transmit-done sleeps in
  fixed `usleep(100)` steps. On a real 68060 that holds the CPU's register cycle about **92 µs per
  transmitted frame**, of which about 70 µs is sleep after the GEM has already finished. The
  `eth_tx_poll` key polls the send count against the ARM's global timer instead, with the same 1.1 ms
  worst-case bound. That cuts the held cycle to about **22 µs** per frame (measured average; the
  firmware's own wait drops from about 80 to 11 µs).
- On Amix the 68k-side cost per full 1514-byte frame was measured at about 730 µs, in roughly equal
  thirds. About 255 µs goes to building a flat frame from the DLPI message, about 221 µs to copying
  it into the card's window (about 6.9 MB/s over the bridge), and about 188 µs to the trigger. The
  receive copy runs at about 7.5 MB/s (188–208 µs per frame). Those numbers come from profiling
  builds on the 1.0 firmware, before `eth_tx_poll`.

## Link speed ✅

The boot menu's own network stack (the bundled lwIP driver) links at **gigabit**. The OS-time
firmware then takes over the PHY and, in the released firmware, **advertises 10/100 only**. The
link re-forms at 100 Mbit full duplex a few seconds after power-on, so a switch's port display may
show the menu phase rather than the running state. No recorded reason exists for withdrawing gigabit.
The RGMII path works at 1000 on the card as strapped: the menu and the OS-time `eth_adv1000` image
both ran gigabit with byte-exact transfers. At 1000 the measured transmit time of a full frame (DMA plus
wire) drops from 136 µs to about 29 µs. The key stays **default off** until it has more running hours, and so far it has one
clean acceptance row 🟡.

## The ethernet keys in `z3660cfg.txt` ✅ {#config-keys}

PR #33 adds five keys. They are read from `z3660cfg.txt` at boot, and an absent line keeps the
default, so an existing config file needs no change.

| Key | Default | What it does |
|---|---|---|
| `eth_reraise` | `YES` | When the Amiga releases a frame and more remain, raise the ethernet interrupt again at once instead of waiting for the next nag (~1 ms). Helps any driver that takes one frame per interrupt. |
| `eth_rxkick` | `YES` | When a frame lands in an **empty** backlog, the next main-loop pass raises the interrupt instead of waiting the full nag. Cuts up to ~0.9 ms off the first frame of every burst. |
| `eth_taildrop` | `YES` | A frame that finds the backlog full is dropped alone. The frames already queued stay. Without it a full backlog loses every unfetched frame. |
| `eth_tx_poll` | `YES` | Transmit wait polls the send count instead of sleeping in 100 µs steps: the 68060's held cycle drops from ~92 to ~22 µs per frame. |
| `eth_adv1000` | `NO` | The OS-time PHY setup also advertises 1000BASE-T. Autonegotiation then picks the speed, and the GEM speed and clocks follow the resolved link. |

The receive ring itself is a build flag (`ETH_RXRING`, default 16 in PR #33), not a config key. The
keys were measured together: `eth_reraise`, `eth_rxkick` and `eth_taildrop` as one "keys on" set
(table below), and `eth_tx_poll` on its own. Every one helped or was neutral on both AmigaOS stacks
and on Amix. Measured 2026-10-21, single runs per cell ✅.

## Reading the card's counters: where a lost frame went ✅ {#reading-the-counters}

The GEM's statistics registers answer "did the card lose it?", and nothing else in the box can.
They need care:

- **"Frames received" counts only frames copied to memory** (Zynq-7000 TRM UG585, the GEM
  statistics registers). A frame the MAC accepted but could not copy is a **resource error** (no free
  descriptor, or the bus not granted in time) or an **overrun** (packet buffer full). If both are
  zero and the frame count equals what the switch sent, the card delivered everything, and the loss
  is above it.
- **With one descriptor the resource-error counter ticks once per frame** and is not a loss counter.
  The receive-status "buffer not available" bit likewise sets dozens of times per transfer without
  loss. Only on a ring build do both mean what they say.
- **The firmware's own counters** report backlog-full events and frames lost to them, and the
  driver's counters report frames delivered. When MAC frames = firmware frames = driver frames and
  the transfer still retransmits, the loss is inside the OS. On Amix, that was the 4 KB TCP queue.

A packet capture on the sender can mislead here. With the stock Amix kernel the lost frames are the
**fourth and later frames of every back-to-back train**, about 1 ms after the previous send. That
looks exactly like a receiver going blind after three frames. Raw-frame bursts with no TCP on top
(every train length, every gap, with the 68060 running or halted) lost nothing. The timing pattern
was the box's own 60 Hz drain, not the wire. Count the MAC's frames against the capture before
blaming the card.

## Measured: Amix ✅ {#measured-amix}

4 MiB FTP transfers, 100 Mbit, real 68060, Amix 2.1-line kernels from the 040/060 port's driver line,
2026-10-19 to 2026-10-21. "Push" is host → box. Every transfer was byte-exact.

| Kernel's TCP lower queue | `z3660eth` receive | Firmware | Push KB/s | Retransmissions | Pull KB/s |
|---|---|---|---|---|---|
| stock, 4096 B | published (frees on refusal) | 1.0, one descriptor | 22–31 | 319–392 | 570–600 |
| stock, 4096 B | back-pressure | 1.0 | 25–31 | 348–375 | 629–649 |
| patched, 16384 B | published | 1.0 | 120–126 | 109–119 | ~575 |
| patched, 16384 B | back-pressure | 1.0 | 227–334 | 10–46 | 570–640 |
| patched, 16384 B | back-pressure | ring of 16 | 314–352 | 3–8 | 570–650 |
| patched, 16384 B | back-pressure | PR #33 build, keys at defaults | **338–372** | 0–1 | 560–640 |

- **The kernel fix is the big lever** (×4–13): see [the 4 KB TCP queue](networking.md#tcp-lower-read-queue).
- **The driver's back-pressure** (hold the frame in the firmware slot when IP cannot take it, and
  resume from the read service procedure) removes the driver's own loss below IP. It matters only
  once the kernel fix is in. It is first-party work, not yet in the published `amix-z3660net`
  ([the driver's service model](../drivers/z3660-ethernet-driver.md#receive-service-model)).
- **The ring** removes the remaining MAC-level drops of the single descriptor.
- **Gigabit** (`eth_adv1000 YES`) was measured only on the stock-kernel stack: push 59.7 KB/s against
  29.0 at 100 Mbit, the pull 675 KB/s. It halves a loss that lives in the kernel, so it is no
  substitute for the kernel fix.
- **The next ceiling** is the driver's **60 Hz receive poll**. Frames and the acknowledgements they
  trigger wait up to a tick (about 11 ms on average), so the push settles at about half the pull 🟡.
  Interrupt-driven receive in `z3660eth` is the lever. It is on the 1.1 list, behind the reason its
  interrupt handler was unregistered.

## Measured: AmigaOS, and the two stacks compared ✅ {#measured-amigaos}

Same card class, real 68060, 100 Mbit, 4 MiB FTP (PrismNet's `ftpd` on both stacks), 2026-10-21.
Every image carried the 16-descriptor ring and the MAC-write fix. "Keys on" = `eth_reraise`,
`eth_rxkick` and `eth_taildrop`. Single runs per cell, all transfers complete and byte-exact, GEM
resource errors 0 in every run.

| Stack | Keys | `Z3660Net.device` | Push KB/s | Retransmissions | Pull KB/s |
|---|---|---|---|---|---|
| PrismNet | off | 1.4 (one frame per wake) | 62 | 561 | 80 |
| PrismNet | on | 1.4 | 157 | 374 | 319 |
| PrismNet | off | 1.5 (drain-all) | 288 | 355 | 1428 |
| PrismNet | **on** | **1.5** | **374** | **177** | **1424** |
| AmiTCP_NG | off | 1.4 | 307 | 487 | 922 |
| AmiTCP_NG | on | 1.4 | 303 | 475 | 959 |
| AmiTCP_NG | off | 1.5 | 325 | 477 | 207 (one outlier) |
| AmiTCP_NG | on | 1.5 | 305 | 453 | 963 |

On the PR #33 build with default keys and driver 1.5, PrismNet pushed **363 KB/s** and pulled
**1436 KB/s**. With `eth_adv1000 YES` (gigabit) it pushed 354 and pulled **1604 KB/s**.

- **`Z3660Net.device` 1.4 takes one frame per interrupt** and then waits for the next interrupt. It
  never checks whether more frames are queued. With the ~1 ms nag that drains about a frame per
  millisecond, fills the backlog and loses frames to it. **1.5 drains until the slot serial repeats**
  (at most 256 frames per wake). That is
  [PR #32](https://github.com/shanshe/Z3660/pull/32), and it is the lever for PrismNet: push 62 → 288,
  pull 80 → 1428.
- **The keys are not made moot by the driver fix.** On top of 1.5 they take the PrismNet push from
  288 to 374 and halve the retransmissions.
- **AmiTCP_NG sits at 300–325 KB/s push whatever the card or the driver does.** Its retransmissions
  all come from the backlog filling, so the limit is above the device: the stack itself takes about
  230 frames a second 🟡 (a reading of its counters; nothing in AmiTCP_NG was traced).
- **Before the ring fixes** (released firmware, one descriptor), AmiTCP_NG pushed about 333–344 KB/s
  and PrismNet 50–139 KB/s, both with 200–400 retransmissions per 4 MiB. AmigaOS lost frames at
  about the rate Amix did but recovered faster, so it never collapsed to Amix's 25 KB/s 🟡 (ranges
  from the AmigaOS bench's own notes).

**Amix against AmigaOS on the same card:** after the fixes the push is about equal (Amix 338–372,
PrismNet 363–374, AmiTCP_NG ~300). The pull is not: PrismNet pulls about 1.4 MB/s against Amix's
~600 KB/s. Amix's figure fits its measured transmit time of about 2.4 ms per full frame end to end,
a third of it in the driver (above) 🟡.

## Upstream status

Both changes are open pull requests against upstream `shanshe/Z3660` as of 2026-10-21:
[#32](https://github.com/shanshe/Z3660/pull/32) (`Z3660Net.device` 1.5, the drain loop) and
[#33](https://github.com/shanshe/Z3660/pull/33) (the 16-descriptor ring, the MAC write without a GEM
restart, and the five keys). Until they are merged, the released firmware and driver behave as
described under "released" above. The single-descriptor drop, the whole-backlog discard and the
one-frame-per-wake drain are upstream behaviour, not something the Amix-interop fork introduced.
Upstream's own 1.03 beta 21 image measured squarely inside the fork's 1.0 band.

## See also

- [Case study: Z3660 ethernet driver (`zen0`)](../drivers/z3660-ethernet-driver.md): the mailbox
  registers, the frame windows, the INT6 storm and the receive service model.
- [Networking](networking.md#tcp-lower-read-queue): the stock kernel's 4 KB TCP queue, which affects
  every network card on Amix, not just this one.
- [Quirks §75](quirks.md#75-tcp-lower-read-queue-4k): the same fact as a one-line triage rule.
- [Z3660 board timings](z3660-timings.md): the card's CPLD clock rows, a different layer of the same
  card.
- [Real hardware](../getting-started/real-hardware.md): the rest of `z3660cfg.txt` and the preset
  overlay.

## Sources

- **Upstream pull requests** (public, ✅): [shanshe/Z3660 #33](https://github.com/shanshe/Z3660/pull/33)
  (branch `upstream-eth-rxring` on <https://github.com/jusii/Z3660-amix>, commits `4f5d43e` the
  receive ring and the 32-slot backlog cap, `00999fc` the in-place MAC write, `b7ca029` the five
  `z3660cfg.txt` keys) and [shanshe/Z3660 #32](https://github.com/shanshe/Z3660/pull/32) (branch
  `upstream-z3660net-drain`, `Z3660Net.device` 1.5). Key names, defaults and semantics are from
  `src/config_file.h` (`CFG_ETH_DEFAULT_*`), `src/config_file.c` and the key comment block in
  `src/ethernet.c` on that branch.
- **Firmware source** (✅): upstream `shanshe/Z3660` `main` (1.03 beta 21) and the fork's
  `release-1.0`: `src/ethernet.c` (`RXBD_CNT 1`, `FRAME_MAX_BACKLOG 64`, the 10/100-only
  advertisement, `XEmacPs_Start` in the MAC-update path), `src/memorymap.h` (the 64 KiB backlog
  region), `src/rtg/rtg.c` (`ethernet_thread`'s nag counter, `ETH_BACKLOG_NAG_COUNTER_MAX_060`).
- **Zynq-7000 SoC Technical Reference Manual, UG585 v1.7**, chapter 16 (Gigabit Ethernet Controller:
  receive/transmit buffer descriptor queues, `rx_qbase` `0x18`, `tx_qbase` `0x1C`, `spec_addr1_bot`
  `0x88`, `spec_addr1_top` `0x8C`) and appendix B (the statistics registers: "frames received"
  counts frames copied to memory) ✅.
- **The October 2026 frame-path profile** (first-party record, 2026-10-19 to 2026-10-21) ✅: stamped
  driver and firmware builds (flag off = byte-identical), the transmit breakdown, the GEM and firmware
  counters around every transfer, raw-frame burst probes with the 68060 running and halted, the
  receive-descriptor probe that caught the ring offset, the keys × driver × stack matrix, and the
  acceptance rows on two A4000-class machines. Hosts, cards and image checksums are project
  bookkeeping and are not reproduced here.
- The AmigaOS release-firmware ranges (🟡) are from the AmigaOS bench's own notes of the same week,
  relayed rather than re-measured for this page.
