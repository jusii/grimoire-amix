---
title: The Amix Device-Driver Model
summary: User vs kernel interface, major/minor numbers, and the cdevsw/bdevsw switch tables.
status: draft
---

# The Amix Device-Driver Model

In Amix, a device is just a file in `/dev` carrying two numbers — a **major** (which driver) and a **minor** (which sub-device). The kernel never looks at the name; it indexes a per-class **switch table** by the major number to find the driver's entry points. Everything else in this page is the elaboration of that one idea ✅. The authoritative source is Michael Ditto's *Writing Amix Device Drivers* (1990 European Amiga Developer's Conference), §5 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), and it is the conceptual core for the rest of the drivers pillar.

This page is **uniformly ✅** (primary source: the Ditto paper) except where a tag says otherwise.

## The user-level view: /dev nodes, major + minor

To user space a device is a special file. Two pieces of metadata matter:

- The **major number** selects the driver.
- The **minor number** selects the sub-device *within* that driver (a SCSI address, a partition, a port, a mode).

The kernel resolves an I/O on a `/dev` node purely through these numbers — it does **not** care what the file is called. You can `mknod` the same major/minor under any name and it behaves identically ✅. Extract the parts in the kernel with `major()`/`getmajor()` and `minor()`/`getminor()` (see [Key kernel APIs](#key-kernel-apis-the-driver-side)).

Devices come in two visible classes (plus a third, STREAMS, described [below](#streams-the-third-kind)):

| Class | `ls -l` flag | Purpose | Driver core |
|---|---|---|---|
| **Block** | `b` | Filesystem / random-access storage; buffered through the block cache | `strategy()` |
| **Character** | `c` | General byte I/O — terminals, printers, raw devices | `read()` / `write()` |

### Example /dev listing

The Ditto paper's worked `ls -l /dev` excerpt establishes the canonical numbers ✅:

```text
crw--w--w-   1 root  ...   0,  0  /dev/console      # char  major 0  minor 0
brw-------   1 root  ...  16,  ?  /dev/fd0          # block major 16 (floppy)
brw-------   1 root  ...  18,  1  /dev/dsk/c0d0s1   # block major 18 (SCSI disk)
crw-rw-rw-   1 root  ...  21,  0  /dev/par          # char  major 21 (parallel port)
```

Reading those rows:

- **`/dev/console`** — character device, **major 0, minor 0**. The system console.
- **`/dev/fd0`** — **block major 16**, the floppy driver.
- **`/dev/dsk/c0d0s1`** — **block major 18**, the SCSI hard-disk driver. The minor `1` encodes SCSI address 0, LUN 0, partition 1. (Recall the Amix SCSI layout: the tape is fixed at **ID 4**, and the boot disk is **ID 6** by convention — see [Quirks](../how-it-works/quirks.md).) ✅
- **`/dev/par`** — **character major 21**, the Amiga parallel port (output-only Centronics). This is the paper's teaching driver; see [Writing a character driver](writing-a-char-driver.md). ✅

For a fuller table of stock and community device numbers, see the [device list](../reference/device-list.md).

## The kernel-level view: switch tables in kernel.c

The kernel side is **table-driven**. The configuration file [`master.d/kernel.c`](kernel-build.md) — shipped *in source* even though most of the kernel is object-only ✅ — declares arrays of driver entry points. The major number is literally the **index** into the matching array.

A driver is added by editing these tables and relinking the kernel; there are **no loadable modules** in Amix — every driver is statically linked into `/unix` ✅. The full build cycle lives in [Building and installing a kernel](kernel-build.md).

### The switch structs (from conf.h)

The shapes below are reproduced from the Ditto paper (§5 of the brief) ✅. They are the SVR4 `cdevsw`/`bdevsw` structures as Amix uses them.

```c
/* Character device switch — struct cdevsw, from conf.h */
struct cdevsw {
    int (*d_open)();    int (*d_close)();   int (*d_read)();   int (*d_write)();
    int (*d_ioctl)();   int (*d_mmap)();    int (*d_segmap)(); int (*d_poll)();
    int (*d_xpoll)();   int (*d_xhalt)();
    struct tty       *d_ttys;   /* tty struct array, or notty   */
    struct streamtab *d_str;    /* STREAMS table,    or nostr   */
    int              *d_flag;   /* driver flags,     or nullflag*/
};

/* Block device switch — struct bdevsw */
struct bdevsw {
    int (*d_open)();    int (*d_close)();   int (*d_strategy)(); int (*d_print)();
    int (*d_size)();    int (*d_xpoll)();   int (*d_xhalt)();
    int *d_flag;
};
```

Note what distinguishes the two: the character switch has the byte-stream and memory-mapping methods (`d_read`, `d_write`, `d_mmap`, `d_segmap`, `d_poll`) plus the tty/STREAMS hooks; the block switch instead has **`d_strategy`** (the queue-and-return I/O engine), **`d_size`**, and **`d_print`**.

### The *_tbl arrays

`kernel.c` wires drivers into the kernel through several parallel arrays ✅:

| Array | Indexed by | Holds | Example entries |
|---|---|---|---|
| `cdevsw[]` | char **major** | one `struct cdevsw` per char driver | console (0), `par` (21), `hya` (47) |
| `bdevsw[]` | block **major** | one `struct bdevsw` per block driver | `fd` (16), SCSI disk (18) |
| `int2_tbl[]` | — | level-2 (INT2) **autovector** interrupt handlers | `parintr`, `a2090intr`, `a2091intr`, … |
| `int6` table | — | level-6 autovector interrupt handlers | (exists; entries version-specific) |
| `init_tbl[]` | — | one-shot **boot-time init** functions | `parinit`, `coinit`, … |

So a typical char driver touches three of these: a `cdevsw[]` slot at its major, an `int2_tbl[]` entry if it takes a level-2 interrupt, and an `init_tbl[]` entry if it needs boot-time setup. The parallel driver, for instance, contributes `cdevsw[21]`, `parintr` to `int2_tbl[]`, and `parinit` to `init_tbl[]` ✅.

> **Note:** the exact array name for boot-time init varies between sources — the paper uses `init_tbl[]`; the modern [VA2000 case study](case-studies/va2000.md) patches an `io_init[]` array in its `kernel.c` ✅. Treat them as the same concept (a list of init functions called once at boot). The full original `master.d/kernel.c` is **not** publicly archived, so the precise schema is inferred from the paper plus the community repos 🔴.

### Placeholder entry points: nodev, notty, nostr, nullflag

A driver rarely implements every method in its switch struct. Instead of leaving a function pointer null (which would crash on a call), Amix fills unused slots with standard stubs ✅:

| Stub | Goes in | Behaviour |
|---|---|---|
| `nodev` | any unimplemented entry-point pointer (`d_open`, `d_ioctl`, …) | returns **`ENODEV`** ("No such device") |
| `notty` | `d_ttys` of a char driver that is not a terminal | no tty array |
| `nostr` | `d_str` of a char driver that is not a STREAMS driver | no `streamtab` |
| `nullflag` | `d_flag` when the driver declares no flags | empty flag value |

A purely output-only printer, for example, sets `d_read = nodev`, `d_ttys = notty`, `d_str = nostr` and leaves only `d_open`/`d_close`/`d_write`/`d_ioctl`/`d_poll` real ✅.

## Naming convention: prefix every entry point

Amix drivers follow a strict naming convention so that the switch-table entries read self-documentingly: **prefix every entry point with a short driver tag** ✅.

- `par` → `paropen`, `parclose`, `parread`, `parwrite`, `parioctl`, `parpoll`, plus `parintr` (interrupt) and `parinit` (boot init).
- `dd` (a disk driver) → `ddopen`, `ddclose`, `ddstrategy`, `ddprint`, `ddsize`.
- `hya` (the Hydra STREAMS net driver) → `hydraopen`, `hydrawput`, `hydraintr`. ✅ (see the [Hydra case study](case-studies/hydra.md))

A `cdevsw[]` slot for `par` therefore looks roughly like:

```c
/* cdevsw[21] — the parallel port */
{ paropen, parclose, nodev /*read*/, parwrite,
  parioctl, nodev /*mmap*/, nodev /*segmap*/, parpoll,
  nodev, nodev, notty, nostr, nullflag },
```

## Block vs character semantics

The two driver classes differ in how they move data ✅:

- **Block driver.** Its core is **`strategy()`**: it accepts a buffer request, queues the I/O, and **returns immediately**; the actual transfer typically uses **DMA** and completes later via an **interrupt**. It also supplies `print()` (error reporting) and `size()`. The block layer sits under the buffer cache and the filesystems, so block devices are what you `mount`. See [Filesystems and disks](../how-it-works/filesystems-and-disks.md).
- **Character driver.** Its core is **`read()`/`write()`**, optionally `ioctl()`, `mmap()`/`segmap()`, and `poll()`. Character I/O is synchronous from the caller's perspective and is the general-purpose path for terminals, printers, raw disks, and framebuffers (e.g. the [VA2000 RTG framebuffer](case-studies/va2000.md) is char major 68 ✅).

### STREAMS: the third kind

**STREAMS** drivers are a distinct third category — technically a special character driver whose `cdevsw[]` entry points at a `streamtab` (the `d_str` field) instead of `nostr` ✅. STREAMS is the SVR4 mechanism for layered, message-based I/O and is how Amix does **networking** (TCP/IP, DLPI). A STREAMS network driver implements a `put` routine (e.g. `hydrawput`) rather than `read`/`write`, and is brought up with `ifconfig <iface> plumb` rather than opened directly. The full treatment is in [Writing a STREAMS driver](writing-a-streams-driver.md); the worked example is the [Hydra DLPI driver](case-studies/hydra.md), which registers at **`cdevsw` slot 47** (`hya`) ✅. For the networking stack itself see [Networking](../how-it-works/networking.md).

## Key kernel APIs (the driver side)

The Ditto paper's `par.c` exercises the standard SVR4 DDI/DKI surface that an Amix driver draws on ✅:

| API | Purpose |
|---|---|
| `major()` / `minor()` / `getmajor()` / `getminor()` | extract device-number fields |
| `copyin()` / `copyout()` | move data across the user/kernel boundary |
| `uiomove()` / `uwritec()` | move data via a `uio` struct |
| `getc()` / `putc()` | clist (character-list) queue operations |
| `sleep(chan, pri[\|PCATCH])` / `wakeup(chan)` | block and wake a process |
| `timeout()` / `untimeout()` | schedule / cancel a deferred callback |
| `spl2()` / `splx()` | raise / restore interrupt priority level (`splpar()` == `spl2()`) |
| `pollwakeup()` | notify `poll()` waiters of an event |
| `autocon(product_id, dev, &board, &dummy)` | **Amix-specific** Zorro II board discovery 🟡 (repo-confirmed) |

`autocon()` ties into the Amiga **AUTOCONFIG** mechanism that assigns Zorro II board addresses at reset; see [Zorro II autoconfig for drivers](zorro-autoconfig.md). Note Amix supports **Zorro II only** — there is no Zorro III mapping ✅.

## Adding a driver: the table workflow

The paper's end-to-end procedure ties the whole model together ✅. Full mechanics (file edits, relink, boot-partition write) are in [Building and installing a kernel](kernel-build.md); the conceptual steps are:

1. Place the driver `.o` (ideally with source) in a subdirectory under `/usr/sys` and add it to that directory's makefile.
2. Edit `master.d/kernel.c`: add the `cdevsw[]`/`bdevsw[]` slot at your chosen major, plus any `int2_tbl[]` / `init_tbl[]` entries.
3. `make` in `/usr/sys` to link a new kernel (called **`rdbunix`** in the 1990 paper, **`relocunix`** on modern 2.1 systems — a historical rename 🟡).
4. Install it (copy to `/unix`, or write it to a boot partition / floppy) and reboot. **Keep the old `/unix`** as a fallback ✅.
5. `mknod /dev/<name> c|b <major> <minor>` to create the device node.

## See also

- [Building and installing a kernel](kernel-build.md) — the relink/boot-partition cycle behind step 3–4 above.
- [Writing a character driver](writing-a-char-driver.md) — the `par` driver as a full worked example.
- [Writing a STREAMS driver](writing-a-streams-driver.md) — the third driver kind, for networking.
- [Zorro II autoconfig for drivers](zorro-autoconfig.md) — `autocon()` and AUTOCONFIG board discovery.
- [Device list reference](../reference/device-list.md) — known major/minor numbers.
- [Case study: VA2000 framebuffer (char major 68)](case-studies/va2000.md) and [Hydra STREAMS net driver (cdevsw 47)](case-studies/hydra.md).

## Sources

- Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference (the project's authoritative driver paper) — §5; `cdevsw`/`bdevsw` from `conf.h`; the `ls -l /dev` example; `par.c` worked driver and `par(7A)` man page (p.22).
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §5 (device-driver model), §4 (kernel architecture: monolithic, no loadable modules, `kernel.c` in source), §2 (SCSI ID hard-coding, Zorro II only).
- `asokero/va2000-amix` repo (`io_init[]` / `cdevsw[]` slot 68 patches): <https://github.com/asokero/va2000-amix>
- `isoriano1968/hydra-amix` repo (`hya` at `cdevsw` slot 47, `hydraopen`/`hydrawput`/`hydraintr`): <https://github.com/isoriano1968/hydra-amix>
- amigaunix.com — historical and end-user reference: <https://www.amigaunix.com/doku.php/home>
