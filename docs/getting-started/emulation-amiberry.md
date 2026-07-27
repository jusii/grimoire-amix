---
title: Amix on Amiberry
summary: Amiberry 8.x fully runs and installs Amix — its A3000 on-board SCSI emulates a disk at ID 6 and a tape at ID 4 (the two devices the installer needs), plus real A2065 networking.
status: draft
---

# Amix on Amiberry

**Amiberry 8.x is a full Amix target — you can both install *and* run Amix on it.** ✅ Amiberry's
A3000 on-board SCSI controller emulates a hard disk at **SCSI ID 6** and a **tape at SCSI ID 4** — the
two devices the Amix kernel and installer require. First-hand on Amiberry **8.1.6** (2026-06): an
installed Amix 2.1 boots to login from the A3000 SCSI hardfile ✅, and the GUI's *Hard drives / CD*
page shows both devices mounted — **`A3000 SCSI:6 → HDF`** and **`A3000 SCSI:4 → TAPE`** — with a
dedicated **"Add Tape Drive…"** button ✅.

This **supersedes** the long-standing "Amix can't install on Amiberry" status: the feature request
[BlitterStudio/amiberry #1376](https://github.com/BlitterStudio/amiberry/issues/1376) ("Add A3000 SCSI
controller and tape support for Amiga UNIX") has been **implemented** in current Amiberry. Older 5.7.x
/ 7.x builds genuinely lacked it (and reportedly crashed with an A3000 config); **use 8.x**. 🟡 (older
versions)

## What works (Amiberry 8.1.6)

| Capability | Status | Tag |
|---|---|---|
| Boot floppy / install kernel loads | Yes | ✅ |
| A3000 SCSI **disk** at ID 6 (`scsi6_a3000`, RDB hardfile) | Yes | ✅ (GUI + booted) |
| A3000 SCSI **tape** at ID 4 (`scsi4_a3000`) | Yes — "Add Tape Drive…" in the GUI | ✅ (GUI) |
| Full **tape install** completes | Yes — confirmed by a live from-tape install | ✅ |
| Run a **pre-installed** Amix | Yes — boots to login from the HDF | ✅ (first-hand) |
| Real **A2065 networking** (LAN host) | Yes — TAP/PCAP backend in 8.x | ✅ ([LAN guide](networking-on-the-lan.md)) |

## The storage IDs that matter (and how to set them)

Amix has firm expectations about its storage hardware:

- The **tape must be at SCSI ID 4** — the install scripts hard-reference the literal `/dev/rmt/4h` and
  look nowhere else. The **disk is ID 6 by convention** ✅/🟡: the installer prompts for the disk
  target and builds `BPART=/dev/dsk/c${SCSI}d0s${BOOTPART}` from it, so use 6 (it's baked into the
  device names once installed). See [root.adf anatomy](../boot-disks/anatomy-root-adf.md) and
  [filesystems & disks](../how-it-works/filesystems-and-disks.md).
- The standard install **streams the distribution from the tape at ID 4** ✅
  (`dd if=/dev/rmt/4hn bs=256k | cpio -imdcu`).

In Amiberry, set these in the machine `.uae` (or via **Hard drives/CD → Add Hardfile / Add Tape Drive**):

```ini
scsi_a3000=true
hardfile2=rw,DH0:/path/to/Amix.hdf,32,1,2,512,0,,scsi6_a3000
uaehf1=tape0,rw,:/path/to/amix_21_tape.zip,0,0,0,512,0,,scsi4_a3000,SCSI1
```

## Minimum machine config

Same as any Amix target ✅ — and the CPU/MMU settings are mandatory or it won't boot:

- **68030 with MMU on** (`cpu_model=68030`, `mmu_model=68030`) + a **68881/68882 FPU**
- **JIT off** (`cachesize=0`) and **"More compatible" off** (`cpu_compatible=false`)
- **Cycle-exact off — `cycle_exact=false`, pinned explicitly.** Omitting the key does **not** leave
  it neutral: Amiberry's `default_prefs()` starts all three cycle-exact flags `true`, so a
  hand-written config selects the cycle-exact 68030 core and Amix dies at PID 1 with
  `NOTICE: User BUS ERROR at … PID:1 CMD:/sbin/init` ✅. It also silently overrides the
  `cpu_compatible=false` above. See [the cycle-exact
  trap](../how-it-works/emulation-fidelity.md#the-cycle-exact-core-a-correct-emulator-default-that-amix-does-not-survive).
- **4–16 MB Fast RAM** (16 MB hard ceiling) and an **A3000 Kickstart 2.04** ROM
- `scsi_a3000=true`

> ⚠️ **A hand-written `.uae` is guilty until proven otherwise.** The effective cycle-exact default is
> **host-dependent** — `target_default_options()` clears the flags only when the *host's*
> `amiberry.conf` sets `default_disable_cycle_exact`, which itself defaults to `false` ✅. The same
> config file can therefore boot on one machine and kill `/sbin/init` on another. Pin the key; don't
> rely on the default. There is a pre-boot tell in the host log: with sound disabled, the line
> `Cycle-exact mode requires at least Disabled but emulated sound setting.` appears **if and only if**
> the cycle-exact core survived config load ✅ — grep for it before blaming the guest.

See [hardware & requirements](../how-it-works/hardware.md) and the [WinUAE config table](emulation-winuae.md)
for the shared requirement list.

## Networking

Amiberry 8.x added a real **A2065** Ethernet backend (TAP / PCAP), so an Amiberry-hosted Amix can be a
genuine host on your LAN — static IP, gateway, DNS, internet. Full verified recipe:
**[Putting Amix on your real LAN](networking-on-the-lan.md)**.

## Running an A4091 under Amiberry

Amiberry 8.x can also emulate the **A4091** — Commodore's Zorro III SCSI-2 host adapter built on the
NCR/Symbios 53C710 — which Amix did not originally support. Pairing it with the
[native 53C710 driver](../drivers/a4091-53c710-driver.md) lets Amix detect, use, and even **boot root
from** an A4091 disk. ✅ (reproduced locally in Amiberry on Amix 2.1c)

Expose the card with **`a4091_rom_file=`** pointing at the A4091 **autoboot ROM**
(`amiga-boot-a4091.rom`, from the [`a4091-software`](https://github.com/A4091/a4091-software) repo) plus
one or more `scsiN_a4091` hardfiles. A disk attached at **target 6** (`scsi6_a4091`) becomes a
**`c6d0s1`-class** device **when the A4091 is the only SCSI card** (card index 0) ✅:

```ini
a4091_rom_file=scsi/amiga-boot-a4091.rom
hardfile2=rw,DH0:/path/to/Amix-a4091.hdf,32,1,2,512,0,,scsi6_a4091
uaehf0=hdf,rw,DH0:/path/to/Amix-a4091.hdf,32,1,2,512,0,,scsi6_a4091
```

> The product id the driver matches is **`0x02020054`** (Commodore `0x0202`, product `0x54`); the board
> AutoConfigs at physical base **`0x40000000`** ✅. See the
> [A4091/53C710 driver page](../drivers/a4091-53c710-driver.md) for the device-numbering scheme (when both
> an A3000 SCSI and an A4091 are present, the A4091 sorts to card 1 and its disk shows up as
> `c8d0s0`-class).

> **Gotcha — don't put the install CD on a _sole_-A4091 rig.** 🟡 With the A4091 as the **only** SCSI
> controller (card 0), mounting a `cdfs` CD at `0,3` reliably **hangs the kernel in an uninterruptible
> SCSI wait** under Amiberry — neither Ctrl-C nor re-inserting the CD recovers it (it looks like a
> boot-time unit-attention that the `cdfs` raw-SCSI path never clears). An **A3000-SCSI-plus-A4091**
> profile, with the CD reached at `1,3`, never hits it. 🟡 because the fault isn't yet attributed
> (Amiberry's A4091 CD emulation vs the a4091 driver's unit-attention handling) and it is untested on
> real hardware — but the operational rule is solid: on a two-controller rig keep the disk on the A3000
> SCSI and the CD on the A4091; on a single-A4091 rig, avoid `cdfs` CD media.

> **Licensing.** The Amix HDFs **and** the A4091 ROM (`amiga-boot-a4091.rom`) are **not committed** to
> this repo — supply your own. Get the A4091 autoboot ROM from the
> [`a4091-software`](https://github.com/A4091/a4091-software) project (it ships the ROM image and the
> `ncr53cxxx` SCRIPTS assembler), and your Amix disk image from your own install or
> [amigaunix.com](https://www.amigaunix.com/doku.php/home).

### The Kickstart matrix that matters

Which machine profile + Kickstart combination boots is **not** about Amix itself — it's about whether the
ROM supports the chipset. ✅

| Machine profile | `chipset=` | Kickstart ROM | Amix boots? |
|---|---|---|---|
| A3000 | `ecs` | KS 2.04 (A3000) **or** KS 3.x | ✅ yes |
| A4000 | `aga` | KS 2.04 | ❌ **white screen** — KS 2.04 has no AGA support |
| A4000 | `aga` | **KS 3.0 (A4000)** r39.106, **or** KS 3.1 A4000 | ✅ yes |

So for an **A4000/A4091** profile use `chipset=aga` **plus an A4000 3.x ROM** (KS 3.0 r39.106 or KS 3.1).
The earlier "Amix won't run on AGA / white screen" belief was a Kickstart limitation, **not** an Amix one
— with an A4000 3.x ROM, Amix boots on AGA and its console works. (KS 3.0 also runs on the A3000, so one
KS *version* spans both machines.) 🔴/✅

The project's working configs (in the A4091 repo; ROM/HDF paths point at user-supplied images):

| Config file | Machine | Purpose |
|---|---|---|
| `amix-a4091-boot.uae` | A3000, `chipset=ecs`, KS 2.04, A3000 SCSI off | A4091-only boot (root on the A4091) |
| `amix-a4091-boot-aga.uae` | A4000, `chipset=aga`, KS 3.0 r39.106 | A4000/AGA + A4091 boot |
| `amix-dbg.uae` | A3000, `chipset=ecs`, `scsi_a3000=true` | A3000 root (`scsi6_a3000`) **+** A4091 as a second card (`scsi0_a4091`) — the build/diagnostic environment |


> **Not in Amiberry: the Z3660.** Upstream Amiberry emulates the A3000 SCSI, the A4091 and the A2065,
> but **not** the Z3660 accelerator. A downstream fork adds a Z3660 board emulation (piscsi mailbox,
> disk and CD units) used to exercise the [Z3660 piscsi driver](../drivers/z3660-scsi-driver.md#exercising-this-driver-without-the-board)
> without the physical card; it is not part of any released build. Don't go looking for a
> `z3660=` key in 8.x ✅.

## Headless / LLM-driven Amiberry

For automation — CI, AFK agents, or an LLM driving the Amix console without a visible window — Amiberry can
run fully headless. There are two complementary pieces: a way to **run and drive** the emulator with no
real display, and a way to **screenshot** it that survives Wayland. (This recipe also underpins the
[LAN networking guide](networking-on-the-lan.md), which uses it to bring up `aen0` over the console.)

### Run + drive under Xvfb

Start a virtual X server, launch Amiberry into it under software rendering **with a controlling TTY**, then
drive the Amiga console with `xdotool`: ✅

```sh
# 1. virtual display
Xvfb :77 -screen 0 1280x1024x24 -nolisten tcp &

# 2. launch Amiberry into it. `script -qfc … /dev/null` gives it a controlling TTY
#    (Amiberry misbehaves without one); software rendering avoids needing a GPU.
DISPLAY=:77 SDL_RENDER_DRIVER=software \
    script -qfc "amiberry -f /path/to/amix-a4091-boot.uae" /dev/null &

# 3. find the Amiberry window id, then type / press keys into it
WID=$(DISPLAY=:77 xdotool search --name Amiberry | head -1)
DISPLAY=:77 xdotool windowfocus "$WID"          # focus BEFORE every XTEST burst
DISPLAY=:77 xdotool type --window "$WID" 'root'
DISPLAY=:77 xdotool key   --window "$WID" Return

# 4. screenshot the whole virtual root
DISPLAY=:77 import -window root /tmp/amix.png
```

> **Gotchas.** ✅
> - **Controlling TTY required.** Launch Amiberry through `script -qfc "…" /dev/null` (or another PTY
>   wrapper). Started bare under `Xvfb` it can refuse to run or behave oddly.
> - **Focus before XTEST.** Run `xdotool windowfocus <id>` immediately before each `type`/`key` burst.
>   Synthetic key events go to the focused window, and focus can drift — unfocused bursts silently land
>   nowhere.

### Screenshot via the IPC socket (Wayland-proof)

Under Wayland/GNOME the usual capture tools (`grim`, `gnome-screenshot`, the Shell D-Bus screenshot API)
are blocked, so `import -window root` is not available outside an X server. Instead ask Amiberry itself to
render the shot through its **IPC socket** — this works regardless of display server.
[`tools/amishot.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/amishot.sh) sends the
protocol command to the socket: ✅

```sh
tools/amishot.sh /tmp/shots/amix.png      # -> "OK  /tmp/shots/amix.png"
```

It connects to **`/run/user/<uid>/amiberry.sock`** and sends `SCREENSHOT\t<abspath>\n` (tab-separated,
absolute path); Amiberry replies `OK\t<path>` or `ERROR\t<msg>`. The path must be absolute — the wrapper
absolutises a relative argument and `mkdir -p`s its directory before sending.

## See also
- [`tools/amix-amiberry.uae`](https://github.com/Jusii/grimoire-amix/blob/master/tools/amix-amiberry.uae) — a complete, ready-to-edit working Amiberry config (A3000 / KS 2.04 / 68030+MMU / SCSI disk@6 + tape@4 / A2065).
- [Install walkthrough](install-walkthrough.md) — the end-to-end tape install (works on Amiberry 8.x, WinUAE, and FS-UAE).
- [Amix on WinUAE](emulation-winuae.md) / [Amix on FS-UAE](emulation-fs-uae.md) — the other UAE-family targets.
- [Hardware & requirements](../how-it-works/hardware.md) — why the SCSI IDs and RAM ceiling are fixed.
- [The Amix RAM ceiling](../how-it-works/ram-ceiling.md) — the separate total-describable-RAM limit (debug windows, Zorro III RAM) and its silent failure.
- [Putting Amix on your real LAN](networking-on-the-lan.md) — A2065 networking on Amiberry.
- [The A4091 / 53C710 SCSI driver](../drivers/a4091-53c710-driver.md) — the native driver that makes the emulated A4091 usable (and bootable) under Amix.

## Sources
- First-hand, 2026-06, Amiberry **8.1.6**: an installed Amix 2.1 boots to login from the `scsi6_a3000` hardfile; the GUI *Hard drives/CD* page shows `A3000 SCSI:6 → HDF` and `A3000 SCSI:4 → TAPE` mounted (RW) with an "Add Tape Drive…" button; a full from-tape install completes on Amiberry 8.1.6 (confirmed first-hand, 2026-06). Working config: `scsi_a3000=true`, `hardfile2=…,scsi6_a3000`, `uaehf1=tape0,…,scsi4_a3000`.
- [BlitterStudio/amiberry #1376](https://github.com/BlitterStudio/amiberry/issues/1376) — "Add A3000 SCSI controller and tape support for amix" (the requested support is present in 8.x).
- Research brief §2 (tape ID 4 hard-coded; disk ID 6 by convention) and §9 (`dd … /dev/rmt/4hn | cpio` install flow).
- [BlitterStudio/amiberry](https://github.com/BlitterStudio/amiberry) project repository.
- The A4091-on-Amix project — `NOTES.md` §9 (A4091-in-Amiberry config + the A3000(ECS)/A4000(AGA) Kickstart matrix) and §10 (the `amishot` IPC-socket screenshot tool), reproduced locally ✅. Config files `amix-a4091-boot.uae`, `amix-a4091-boot-aga.uae`, `amix-dbg.uae`; A4091 product id `0x02020054` verified in `src/a4091-blk.c`. Screenshot wrapper: [`tools/amishot.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/amishot.sh).
- [A4091/a4091-software](https://github.com/A4091/a4091-software) — the A4091 autoboot ROM (`amiga-boot-a4091.rom`) and the `ncr53cxxx` SCRIPTS assembler.
- The **Installer-NG** Waves 5–6 field campaign (amix-installng @ `7106f1b`, amix-packagemanager @ `4539ad2`), 2026-07-22/24 — a blank-disk→bootable-install effort that root-caused these platform behaviours on the Amiberry bench and the real A4000+Z3660 (acceptance-run captures, s5/UFS state reads, and the on-metal digest attestation) ✅ (🟡 where tagged).
- The **amiberry** workspace fork, `docs/amix-guest-cycle-exact.md` @ `aa077b0`, 2026-07-26 ✅ — the
  `default_prefs()` initialisation (`src/cfgfile.cpp`), the four non-equivalent config keys and why only
  `cycle_exact` clears all three flags, the host-dependent `default_disable_cycle_exact` path
  (`src/osdep/amiberry.cpp` / `src/include/options.h`), the `fixup_prefs()` host-log tell and its
  `cpu_compatible = true` side effect (`src/main.cpp`), and the 16-log discrimination (present in 6/6
  omitting runs, absent in 10/10 pinning runs).
- The **amix-kerntools** piscsi-rig ablation @ `33ab7c3` (`docs/piscsi-rig.md` §3, first landed
  `c1cd679`), 2026-07-26 ✅ — 10 boots, same image and same kernel throughout, isolating
  `cycle_exact` as the single variable (R14: the hand-written config plus `cycle_exact=false` and
  nothing else reaches multiuser); supersedes two earlier runs that had been attributed to a
  RAM/board interaction.
