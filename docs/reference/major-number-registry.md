---
title: Major-Number Registry
summary: Every known cdevsw/bdevsw/vfssw/AutoConfig claim across the Amix community trees, so you can pick a genuinely free slot.
status: draft
---

# Major-Number Registry

**Pick a character major in 51–67 or 69.** Everything below 51 is either stock, claimed by a
community driver, or a trap; 70 and above does not exist without editing the array bounds. That one
sentence is the whole answer — the rest of this page is the evidence, the other three namespaces
nobody tracks, and the two collisions that already exist in the wild.

Amix has **no authority that allocates device numbers**. A driver "registers" by occupying an index
in `cdevsw[]` or `bdevsw[]` in `master.d/kernel.c` and rebuilding the kernel ✅. Every community
project picks its own slot and hopes; `zz9000-amix`'s own INSTALL.md tells the reader to *"Confirm
that it is free in your own `cdevsw[]`"* ✅, and `va2000-amix` does not mention conflicts at all ✅.
This page is the shared artifact that gap calls for. It is **descriptive, not binding** — no kernel
enforces it. It is offered so that two drivers built by two people can be linked into one kernel.

For what a major/minor *is* and how the switch tables work, see [the Amix device-driver
model](../drivers/driver-model.md). For the SCSI minor-number encoding and the card list, see
[Device & card reference](device-list.md).

## 1. Character majors — `cdevsw[]`

The stock table has **70 entries, indices 0–69** ✅. `CDEVSIZE` is
`sizeof(cdevsw)/sizeof(cdevsw[0])`, so **a major ≥ 70 requires extending the array** — no community
driver has done this, and doing so changes `cdevcnt`, which other code reads. Treat 69 as the
ceiling.

Transcribed byte-exact from `usr/sys/master.d/kernel.c` in two independent trees ✅: the published
`isoriano1968/hydra-amix` tree @ `dcb7d24`, and this project's own relink tree. A full `diff`
between the two shows **five hunks, all of them hydra** — so both trees agree on every other row ✅.

| Major | Occupant | Class | Status |
|---|---|---|---|
| 0 | `console` | stock | occupied ✅ |
| 1 | `prf` | stock | occupied ✅ |
| 2 | `tty` (`sy`) | stock | occupied ✅ |
| 3 | `mem` | stock | occupied ✅ |
| 4 | `bb` | stock | occupied ✅ |
| 5 | `sl` (streamtab `slinfo`) | stock | occupied ✅ |
| 6 | `amiga` | stock | occupied ✅ |
| **7** | `/*7=win?*/` — labelled, no functions | stock | ⚠ **do not use** — reserved marker ✅ |
| 8 | `xt` | stock | occupied ✅ |
| 9 | `sxt` | stock | occupied ✅ |
| 10 | `screen` | stock | occupied ✅ |
| 11 | `scsi` — `gsioctl` raw-CDB passthrough (`/dev/scsi`) | stock | occupied ✅ |
| 12 | `machid` | stock | occupied ✅ |
| 13 | `ql` | stock | occupied ✅ |
| 14 | `pts` | stock | occupied ✅ |
| 15 | `ptmx` | stock | occupied ✅ |
| 16 | `ct` — tape | stock | occupied ✅ |
| 17 | `fd` — floppy (char) | stock | occupied ✅ |
| **18** | **`aen`** — A2065 LANCE STREAMS/DLPI (`&aeninfo`) | stock | occupied ✅ — **note:** unrelated to *block* 18 (`dd`) |
| 19 | `sld` — SLIP DLPI | stock | occupied ✅ |
| 20 | `loop` | stock | occupied ✅ |
| 21 | `par` — parallel (`/dev/par`) | stock | occupied ✅ |
| 22 | `tiga` — A2410 | stock | occupied ✅ |
| 23 | `timod` | stock | occupied ✅ |
| 24 | `tirdwr` | stock | occupied ✅ |
| 25 | `log` | stock | occupied ✅ |
| 26 | `sp` | stock | occupied ✅ |
| 27 | `clone` | stock | occupied ✅ |
| 28 | `ticots` | stock | occupied ✅ |
| 29 | `ticotsord` | stock | occupied ✅ |
| 30 | `ticlts` | stock | occupied ✅ |
| 31 | `res` | stock | occupied ✅ |
| 32 | `ip` | stock | occupied ✅ |
| 33 | `tcp` | stock | occupied ✅ |
| 34 | `udp` | stock | occupied ✅ |
| 35 | `rawip` | stock | occupied ✅ |
| 36 | `icmp` | stock | occupied ✅ |
| 37 | `arp` | stock | occupied ✅ |
| **38** | `/*38=fd*/` — **labelled but all-`ND`** | stock | ⚠ avoid — reserved-looking, functionally empty ✅ |
| **39** | `/*39=hd*/` — **labelled but all-`ND`** | stock | ⚠ avoid — same ✅ |
| 40 | `dd` — SCSI raw/char disk | stock | occupied ✅ |
| 41 | `ben` | stock | occupied ✅ |
| 42 | — | — | free ✅ |
| 43 | — | — | free ✅ |
| **44** | `rkd` — only under `KERNEL_DEBUGGER` | stock | ⚠ **avoid** — empty in a normal build, occupied in a debugger build ✅ |
| **45** | `kdebug` — only under `KERNEL_DEBUGGER` | stock | ⚠ **avoid** — same ✅ |
| 46 | `audio` | stock | occupied ✅ |
| **47** | **`mx`** (stock contrib) ⚔ **`hydra`** (community) | — | ⚔ **COLLISION** — see §2.1 ✅ |
| **48** | `random` (isoriano1968 dev tree, unpublished) — **vacated by `z3660eth` 2026-07-30** | — | 🟡 dev-tree prose only; collision resolved — see §2.2 |
| **49** | **`zz9000`** (isoriano1968) | community | claimed ✅ |
| 50 | `sad` — STREAMS administrative driver | stock | occupied ✅ |
| **51** | **`z3660eth`/`zen0`** (this family) — renumbered from 48, 2026-07-30 | community | claimed ✅ — **live in shipped kernels: `mknod /dev/zen0 c 51 0` verified on real hardware 2026-09-09** (A4000 + Z3660, kernel `68060-260828-50`, `zen0` up at 0 % packet loss). The "48 until the next kernel rebuild" caveat is now discharged |
| **52–67** | — | — | ✅ **FREE** — verified row-by-row in two trees; **take a slot here** |
| **68** | **`va2000`** (asokero) | community | claimed ✅ |
| **69** | — | — | ✅ **FREE** — the last slot in the array |
| 70+ | *does not exist* | — | 🚫 requires extending `cdevsw[]` ✅ |

Every row from `/*51*/` to `/*69*/` reads literally
`ND,ND,ND,ND,ND,ND,ND,ND,ND,ND,notty,nostr,nullflag,` in the published community tree ✅ — slots 48,
49 and 68 are the same empty filler there, because those drivers live in *other* authors' trees.

## 2. The two live collisions

### 2.1 Major 47 — `mx` vs `hydra` ⚔

**Amix 2.1 ships a driver that already claims 47.** `/usr/sys/amiga/alien/contrib/mx/` is in the
stock distribution (present in two independently obtained trees, files dated 1992-03-21) ✅. It is
the **Palomax MAX-125** IBM-style serial adapter driver — up to 8 extra serial ports — by an author
tagged `jck`. Its `kernel.c.mx` says, verbatim ✅:

```c
/* placed in struct cdevsw cdevsw[] = {	 at major 47 */

ND,ND,ND,ND,ND,ND,ND,ND,ND,ND,notty,&mxinfo,nullflag,	/* 47 jck MAX-125 */
```

The modern [hydra AmigaNet driver](../drivers/case-studies/hydra.md) also takes 47 ✅.

**If you have installed the MAX-125 driver from your own Amix media, adding hydra will silently
overwrite it** (or fail to link, depending on which extern wins). `mx` additionally claims an
`int2_tbl[]` ISR (`mxtxintr`) and an `io_poll[]` entry (`mxpoll`) ✅ — so the collision is not only
in `cdevsw[]`.

This is the oldest conflict in the ecosystem and predates every modern driver by three decades.
Neither side knows about the other.

> The other stock contrib item, `contrib/viper.sh` (Archive Viper 2150S tape support, Frank J.
> Edwards, 1991, GPL), **claims no major** — it only adds `ctioctl` to the existing `/*16=ct*/`
> row ✅. Recorded here so it need not be re-checked.

### 2.2 Major 48 — `z3660eth` vs `random` — resolved 2026-07-30

This family's [`z3660eth` driver](../drivers/z3660-ethernet-driver.md) occupied char **48**, tag
`zen`, interface `zen0` ✅ — chosen in 2026-06 because 48 is a free `nostr` row on the stock and
A4091 kernels, and burned into real-hardware-proven kernels and shipped `/dev/zen0` nodes.

Against it, `zz9000-amix`'s `integration/kernel.c.txt` states ✅:

> *"The tested development tree uses major 47 for Hydra, 48 for random, 49 for ZZ9000, and 50 for
> sad. Verify your own table before assigning major 49."*

**That is the only evidence for `48 = random` anywhere** — a prose line describing an author's
**unpublished** development tree 🟡. The *published* `hydra-amix` tree leaves 48 empty ✅.

**Resolution (2026-07-30): `z3660eth` renumbered off 48 to 51** ✅ — the lowest slot of the
verified-free 51–67/69 range — because this project's own convention (§5) says community claims
win, and a documented claim — even a weak one — is cheaper to respect than to argue with. The
renumber is **source-side**: kernels and `/dev/zen0` nodes built before the next kernel rebuild
still register and open 48 ✅. 48 now carries only the unpublished-dev-tree `random` claim 🟡.

## 3. Block majors — `bdevsw[]`

32 entries, indices 0–31 ✅ (`BDEVSIZE`).

| Major | Occupant | Status |
|---|---|---|
| 0–15 | — | free ✅ |
| 16 | `fd` — floppy | occupied ✅ |
| 17 | `hd` | occupied ✅ |
| **18** | **`dd`** — SCSI disk | occupied ✅ — **shared, see below** |
| 19 | `dummydisk` | occupied ✅ |
| 20 | `ramdisk` | occupied ✅ |
| 21–31 | — | free ✅ |

**No SCSI host adapter consumes a block major.** The [A4091](../drivers/a4091-53c710-driver.md) and
[Z3660 piscsi](../drivers/z3660-scsi-driver.md) drivers both register *inside* major 18 by adding a
row to `sd.c`'s `scsicard[]` table, keyed on AutoConfig product ID ✅. A new SCSI controller driver
should do the same — **do not take a new block major for a host adapter**. Note `SDCARDS = 2`: only
two controllers can be live at once (see [composing multi-driver
kernels](../drivers/kernel-composition.md)).

## 4. Filesystem types — `vfssw[]`

The third namespace, and the one the old registry missed entirely. Filesystems are matched **by
name** at mount time (`mount -F cdfs …`), so index drift is less dangerous than a `cdevsw`
collision — but `nfstype` is `sizeof(vfssw)/sizeof(vfssw[0])` and the row order is part of the
kernel's ABI, so it still needs recording.

| Index | Type | Status |
|---|---|---|
| 0 | `BADVFS` | stock ✅ |
| 1 | `s5` | stock ✅ |
| 2 | `ufs` | stock ✅ |
| 3 | `fifofs` | stock ✅ |
| 4 | `rfs` | stock ✅ — **conditional on `INCLUDE_RFS`** (defined in the shipped tree) |
| 5 | `xnamfs` | stock ✅ |
| 6 | `bfs` | stock ✅ |
| 7 | `proc` | stock ✅ |
| 8 | `specfs` | stock ✅ |
| 9 | `namefs` | stock ✅ |
| 10 | `fdfs` | stock ✅ |
| 11 | `nfs` | stock ✅ |
| **12** | **`cdfs`** (this family) — appended last | claimed ✅ |

> ✅ **Index resolved 2026-07-27: `cdfs` = 12.** The staged `master.d/filesys.c` defines
> `INCLUDE_RFS` **unconditionally in the file itself**, immediately above the `#ifdef` guarding the
> `rfs` row — so `rfs` (index 4) always compiles, stock rows are 0–11 (`nfs` at 11), and the
> appended `cdfs` row is **12**. No build knob ever turns `INCLUDE_RFS` off (the kerntools fstype
> staging only appends the row; it never touches the guard). Confirmed at the binary level: the
> `vfssw` tables dumped out of two independently linked kernels during the a3091 bounce
> investigation are identical row for row, cdfs last at 12
> (`amix-kerntools/docs/a3091-bounce-boot-patch.md`) ✅. The competing figure — "index 11, stock
> 0–10" in `amix-cdfs/docs/packet-c-bench-results.md` (since corrected) — was a static miscount
> that treated the `#ifdef INCLUDE_RFS` row as not compiled; excluding `rfs` yields exactly 11/0–10,
> which is how the discrepancy arose. That doc's load-bearing claim (row appended **last**, no
> index shift of stock rows) was true all along. Note the index is **load-bearing for nothing**:
> `cdfsinit()` self-locates its row by *name* at boot and records the index it finds
> (`cdfs_fstype`), and mount matches by name — by design, cdfs works at either index ✅.

New filesystems should likewise **append**, never insert — inserting renumbers every type above it.

## 5. AutoConfig product IDs

The fourth namespace. This is where *hardware* identity collides, and nobody tracks it either. The
key is `(manufacturer << 16) | product`, the argument to `autocon()` ✅.

| ID | Board | Claimed by |
|---|---|---|
| `0x02020001` | A2090 | stock ✅ |
| `0x02020003` | A2091 | stock ✅ |
| `0x0202F003` | A3000 on-board SCSI | stock ✅ |
| `0x02020054` | A4091 (Zorro III, 53C710) | A4091 project / this family ✅ |
| `0xc0de0001` | A4092 | this family ✅ |
| `0xc0de0002` | A4770 (SCSI.ME) | this family ✅ |
| `0x08490001` | Hydra AmigaNet (2121/1) | isoriano1968 ✅ |
| `0x144B0001` | Z3660 accelerator (eth + piscsi, combo base `0x10000000`) | shanshe / this family ✅ |
| `0x6D6E0001` | MNT VA2000 (mfr `0x6D6E`, product 1) | asokero ✅ |
| `0x6D6E0003` | MNT ZZ9000, **Zorro II product 3** | isoriano1968 ✅ |
| `0x6D6E0004` | MNT ZZ9000, Zorro III identity | ⚠ **detected and rejected** — Amix has no Zorro III bus support ✅ |

**No collisions today.** Two boards from the same manufacturer (`0x6D6E`, MNT) coexist because they
carry different product numbers.

## 6. The other thing that must not collide: init tables

A major is not the only slot a driver claims. Four separate boot-time tables exist in
`master.d/kernel.c`, and community drivers use **different ones** ✅:

| Table | Purpose | Used by |
|---|---|---|
| `init_tbl[]` | boot-time driver init | `hydra` (`hydrainit`) ✅, `zz9000` (`zz9000init`) ✅ |
| `io_init[]` | late I/O init | `va2000` (`va2000init`) ✅ |
| `int2_tbl[]` | level-2 autovector ISRs | stock (`aciaaintr`, `jbintr`, `a2091intr`, `a3091intr`, `aenintr`), `hydra` (`hydraintr`) ✅, `mx` (`mxtxintr`) ✅ |
| `io_poll[]` | 16.667 ms poll callbacks | stock (`qlintr`, `slpoll`), `mx` (`mxpoll`) ✅ |

Record which table your driver hooks alongside its major. `z3660eth` deliberately hooks **none** —
it autoconfigures on first `open()` and services RX from a `timeout()` callout, so a kernel built
without the hardware still boots cleanly and `open()` merely returns `ENXIO` ✅. That is the
friendliest pattern for a shared kernel and the one this project recommends.

## 7. Conventions for adding a driver

1. **Take 51–67 or 69.** Never 7, 38, 39, 44, 45 (traps), never ≥ 70 (off the end of the array).
2. **Respect existing community claims** — 47, 48, 49, 68 (48 = an unpublished dev-tree claim; this project vacated it anyway, 2026-07-30). When in doubt, the party who has *not*
   shipped hardware-proven kernels renumbers.
3. **A SCSI host adapter takes no new major** — add a `scsicard[]` row under block 18 (§3).
4. **A filesystem appends to `vfssw[]`** — never inserts (§4).
5. **Gate the slot mechanically.** Match the free row by its `/*<major>*/` comment tag and **abort
   if it is not the `nostr`/`ND` filler** — do not blind-write the row. This project's harness does
   exactly that (`FATAL: cdevsw slot N is not the free 'nostr' row`) ✅; at least one community
   installer patches by literal comment match with **no** such check, and will silently no-op if the
   row was retagged ✅.
6. **Prefer probe-on-open to a boot-time `init_tbl[]` entry** where the hardware allows it (§6).
7. **Record the claim here** — the [driver admission
   checklist](../drivers/kernel-composition.md#the-driver-admission-checklist) gate 3 requires it.

## 8. Claims by project

| Project | Char | Block | Other | Verified on metal |
|---|---|---|---|---|
| [`z3660eth`](../drivers/z3660-ethernet-driver.md) (this family) | **51** (renumbered from 48, 2026-07-30 source-side; shipped kernels carry 48 until the next rebuild) | — | — | ✅ A4000 + Z3660, 2026-06 (at 48) |
| [`z3660scsi`](../drivers/z3660-scsi-driver.md) (this family) | via 40 | via **18** (`scsicard[]`, `0x144B0001`) | — | ✅ 2026-06 |
| [`a4091`](../drivers/a4091-53c710-driver.md) (this family) | via 40 | via **18** (`scsicard[]`, ×3 IDs) | — | 🟡 emulated; metal pending |
| `cdfs` (this family) | — | — | `vfssw[]` last row | ✅ 2026-07 |
| [`hydra`](../drivers/case-studies/hydra.md) (isoriano1968) | **47** ⚔ | — | `init_tbl[]`, `int2_tbl[]` | ✅ 2026-06 |
| [`zz9000`](../drivers/case-studies/zz9000.md) (isoriano1968) | **49** | — | `init_tbl[]` | ✅ |
| `random` (isoriano1968, unpublished) | **48** (uncontested since 2026-07-30) | — | — | 🟡 prose-only |
| [`va2000`](../drivers/case-studies/va2000.md) (asokero) | **68** | — | `io_init[]` | ✅ |
| `mx` MAX-125 (stock contrib, 1992) | **47** ⚔ | — | `int2_tbl[]`, `io_poll[]` | 🔴 no modern report |
| `viper` tape (stock contrib, 1991) | *none* — extends 16 | — | — | 🔴 no modern report |

## See also

- [Device & card reference](device-list.md) — the SCSI minor encoding, `dev_t` packing, and the card list.
- [The Amix device-driver model](../drivers/driver-model.md) — what `cdevsw[]`/`bdevsw[]` actually do.
- [Composing multi-driver kernels](../drivers/kernel-composition.md) — the admission checklist that requires an entry here.
- [Building and installing a kernel](../drivers/kernel-build.md) — how a slot is wired in and relinked.
- [Writing a character driver](../drivers/writing-a-char-driver.md) / [Writing a STREAMS driver](../drivers/writing-a-streams-driver.md).

## Sources

- `usr/sys/master.d/kernel.c` — `cdevsw[]` (rows 0–69) and `bdevsw[]` (rows 0–31) read byte-exact
  from two independent trees: [`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix)
  @ `dcb7d24`, and this project's relink tree. A full diff between them shows five hunks, all hydra.
- `usr/sys/master.d/filesys.c` — `vfssw[]` rows, read from this project's staged tree with `cdfs`
  appended.
- `amix-kerntools/docs/a3091-bounce-boot-patch.md` — the 2026-07-26 a3091 investigation's binary
  `vfssw` table dumps from two independently linked kernels (cdfs last, index 12) — the
  measurement that resolved the 11-vs-12 index question.
- `/usr/sys/amiga/alien/contrib/mx/{kernel.c.mx,README}` — the stock Amix 2.1 MAX-125 contrib
  driver's major-47 claim, `int2_tbl[]` and `io_poll[]` entries (present in two independently
  obtained copies of the stock tree; files dated 1992-03-21).
- `/usr/sys/amiga/alien/contrib/{README.install,viper.sh}` — the Archive Viper tape contrib
  (Frank J. Edwards, 1991); confirmed to extend char 16 rather than claim a new major.
- [`isoriano1968/zz9000-amix`](https://github.com/isoriano1968/zz9000-amix) @ `75e2449` —
  `integration/kernel.c.txt` (major 49 entry, the `47/48/49/50` dev-tree prose line), `INSTALL.md`,
  `mkdev.sh` (`mknod /dev/zz9000 c 49 0`), `integration/c1-console.txt`.
- [`asokero/va2000-amix`](https://github.com/asokero/va2000-amix) @ `fec1c68` — `KERNEL_CHANGES.md`
  (`cdevsw` slot 68, `io_init[]` entry, `mknod /dev/va2000 c 68 0`), `install-va2000-driver.sh`
  (the `/*68*/` literal-match patcher), `src/va2000.c` (`VA2000_PRODUCT = 0x6D6E0001`).
- [`isoriano1968/hydra-amix`](https://github.com/isoriano1968/hydra-amix) @ `dcb7d24` — `README.md`
  (char 47, tag `hya`, `mknod /dev/hya0 c 47 0`, AutoConfig `0x08490001`).
- This project's driver manifests — `amix-z3660net/driver.conf` (`net z3660eth … 51 zen` (48 until 2026-07-30)),
  `amix-z3660scsi/driver.conf` (`0x144B0001 z3660queue`), `amix-a4091/driver.conf`
  (`0x02020054` / `0xc0de0001` / `0xc0de0002`) — and the build harness's free-row gate
  (`build-cross-kernel.sh`, `build-net-kernel.sh`).
- Upstream-watch sweeps #1 (2026-07-26) and #2 (2026-07-27) — the cross-tree claim survey behind
  this page.
