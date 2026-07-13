---
title: The Amix Device-Driver Model
summary: User vs kernel interface, major/minor numbers, and the cdevsw/bdevsw switch tables.
status: draft
---

# The Amix Device-Driver Model

In Amix, a device is just a file in `/dev` carrying two numbers — a **major** (which driver) and a **minor** (which sub-device). The kernel never looks at the name; it indexes a per-class **switch table** by the major number to find the driver's entry points. Everything else in this page is the elaboration of that one idea ✅. The authoritative source is Michael Ditto's *Writing Amix Device Drivers* (1990 European Amiga Developer's Conference), §5 of the [research brief](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md), and it is the conceptual core for the rest of the drivers pillar.

This page is **uniformly ✅** except where a tag says otherwise. The core model's primary source is the Ditto paper; the later [HBA/DMA driver contract](#the-amix-hbadma-driver-contract-real-hardware) and [in-kernel filesystem](#writing-an-in-kernel-filesystem-the-svr4-vfs_mount-contract) sections are first-party, real-hardware-verified findings (amix-z3660scsi / amix-cdfs) cited inline.

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

**STREAMS** drivers are a distinct third category — technically a special character driver whose `cdevsw[]` entry points at a `streamtab` (the `d_str` field) instead of `nostr` ✅. STREAMS is the SVR4 mechanism for layered, message-based I/O and is how Amix does **networking** (TCP/IP, DLPI). A STREAMS network driver implements a `put` routine (e.g. `hydrawput`) rather than `read`/`write`, and is brought up with `slink` rather than opened directly (Amix is SVR4.0 and has no `ifconfig … plumb`). The full treatment is in [Writing a STREAMS driver](writing-a-streams-driver.md); the worked example is the [Hydra DLPI driver](case-studies/hydra.md), which registers at **`cdevsw` slot 47** (`hya`) ✅. For the networking stack itself see [Networking](../how-it-works/networking.md).

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

## The Amix HBA/DMA driver contract (real hardware)

Everything above is the 1990 Ditto-paper model. This section adds the parts of the contract that the paper never spells out but that **bite hard on real hardware** — recovered by bringing up the native [Z3660 piscsi SCSI driver](z3660-scsi-driver.md) and the [cdfs](../how-it-works/filesystems-and-disks.md) in-kernel filesystem on a physical A4000 + Z3660, and by disassembling the stock Amix kernel. Each item below cost real silent corruption or a wild-jump panic. They are all **✅** (fix commit + real-hardware reproduction, or stock-kernel disassembly) and they **generalize to any HBA/DMA driver on this platform**, the a4091 included.

### Completion runs in the caller's context, iteratively — never from a callout ✅

The SVR4 block layer hands your queue routine a `struct sdcom` (command + buffer + the `cp->intr` completion callback). Two facts about its lifetime and context are non-negotiable:

1. **The `sdcom` may live on the *caller's stack*.** ✅ Callers are allowed to allocate it as a local — the cdfs media backend does exactly this (`struct sdcom` inside a stack-local request struct). So a driver that **defers completion to a clock callout** (`timeout(done, cp)`) reads `cp->intr` from a *dead* stack frame once the caller returns, and jumps through reclaimed memory — kernel corruption and a wild-jump panic (seen the moment `mount -F cdfs` touched the CD). **Rule: complete the command before your queue routine returns**, or the caller must explicitly guarantee the `sdcom` outlives the completion — and nothing in the interface says it does. The a4091 driver was immune only because it already completes inline. ✅
2. **…but a *bare* inline `(*cp->intr)(cp)` blows the kernel stack**, because disk completion **re-issues the next I/O** (`ihandle → startio → sdqueue → your queue routine`), so a naive recursive completion burns **one stack frame per chunk** and dies on the first big multi-chunk burst (~100 I/Os into boot on real hardware). ✅ The working shape is **synchronous but *iterative*: a driver-owned completion FIFO plus a `completing` guard**, so the first caller drains the queue in a loop and re-entrant completions are *enqueued*, not recursed. A silent, kmem-readable FIFO-overflow counter is cheap insurance and must stay 0. ✅

*(This is exactly the correction the Z3660 piscsi driver landed after its first cut deferred completion to `timeout()`; see [that page](z3660-scsi-driver.md#the-per-io-sequence).)*

### `sdcom.addr` is already a physical (bus) address ✅

The buffer address in `sdcom.addr` is **physical by contract — the caller has already run it through `vtop()`** before handing it over (both `dd.c` and the cdfs media backend do). A driver that "helpfully" adds its own `vtop()` **double-translates** and corrupts the transfer. ✅ It is an attractive wrong turn because the field is named `addr` and the rest of the kernel is virtual-addressed. (Related: raw/`physio` I/O never hands a driver a *user* VA either — `dd.c → breakup() → amiga_dma_pageio()` stages through a 2 KB kernel buffer — so a raw readback is trustworthy for verifying a write.) ✅

### The spl / callout-IPL contract: spl2 sections are sound; an unguarded mailbox is not ✅

Amix **callouts dispatch at IPL4** (`SR 0x2400`), which at first suggests every `sdspl`-guarded (**spl2**) critical section in the SCSI path is unsound against a callout-driven completion. It is **not**: the *only* thing that triggers a callout is the **level-2 CIA-A clock**, so masking at spl2 genuinely blocks it, and the stock `sdspl` (spl2) sections are correct. ✅ The real exposure is a driver's **own hardware mailbox transaction** carrying *no* spl masking — bracket the whole transaction (the Z3660 driver uses **spl6**, with permanent silent nest counters that must read 0). Platform quirk from the same disassembly: **spl5/spl6/spl7 all emit the same `_spl4` (`SR 0x2400`)** on this kernel. ✅

### The DMA-alignment contract: a `vtop()`'d buffer must NOT cross a page boundary ✅

**On Amix, a DMA target handed through `vtop()` is valid for exactly ONE page** (`NBPP = 2048`, `sys/immu.h`) — because **large kmem allocations are virtually contiguous but physically *scattered*.** ✅ A `kmem_alloc` above 4096 bytes goes through `sptalloc → segkmem_alloc`, which pops **arbitrary frames** off `page_freelist` and maps them at consecutive *virtual* addresses with **no physical adjacency**. So `vtop()` translates only the first page; the moment a single DMA transfer crosses the page boundary, its tail bytes land in the **physically-next frame — owned by someone else.**

This is a **wild-write** bug, and its two traps are what make it nearly invisible ✅:

- **An allocator header silently destroys alignment.** A portable allocator wrapper that prepends an 8-byte length header (SVR4 `kmem_free` needs the original size) shifts every "page-sized" buffer **8 bytes off page alignment** — so cdfs's 2048-byte sector buffers sat 8 bytes into a page and every sector DMA spilled its last 8 bytes into the next frame. The spilled bytes were the CD sector's zero padding, so the signature was **"a short run of zeros at the start of an innocent page"**: it zeroed `/usr/sbin/umount`'s 16-byte ELF ident **on disk** (buffer-cache page → `fsflush`) and scribbled libc's resident pages. (It also rounds a 2056-byte request into the 4096 buddy class — a size no stock consumer uses.)
- **Byte-correct *reads* prove nothing about wild *writes*.** Bulk file reads verified byte-identical against the source ISO throughout the hunt, because they happened to use a *different*, accidentally page-aligned buffer; only misaligned metadata/mount-time reads did the damage, and the bytes they lost were padding nobody compares. The reliable detector was a **canary soak**: `sum -r` a set of resident binaries (`libc.so.1`, `sh`, `init`, `mount`, `umount`, `ls`, `sum`, `df`) before and after N mount/umount cycles and diff. That one-liner caught in a single cycle what two theories missed (15/15 clean after the fix vs corruption by cycle 2–10 before). ✅

**Fix pattern:** page-align every DMA target (sector == page ⇒ one buffer = exactly one frame), bounce unaligned targets, never DMA into a stack buffer, and add a **permanent kernel-side guard that refuses any request with `(va & (NBPP-1)) + nbyte > NBPP` via `cmn_err`** instead of corrupting memory. ✅ For the allocator internals behind this (why >4096 is scattered, the buddy pools, the freelist-link corruption signature) see [Kernel architecture → the kmem allocator](../how-it-works/kernel-architecture.md#the-kmem-allocator-what-a-driver-can-assume). *(This is the deeper root cause of the "in-kernel SCSI DMA corrupts multi-sector transfers" gotcha noted under [kernel-build](kernel-build.md#gotcha-in-kernel-scsi-dma-corrupts-transfers-larger-than-one-2048-byte-block): a transfer that stays inside one aligned page is one physical frame and is safe.)*

## Writing an in-kernel filesystem: the SVR4 VFS_MOUNT contract ✅

A new in-kernel filesystem (cdfs was the first non-stock one) must honor a `mount(2)` contract that hands it a `struct vfs` full of **recycled garbage**, with several "obvious" moves being wrong ✅ (all from disassembling `mount(2)`/`dounmount`/`vfs_add`/`s5mount`/`prmount`/`fdmount`/`getudev` and diffing cdfs against the stock filesystems):

- **`mount(2)` does not zero the `vfs`, and it takes the lock *before* dispatching.** It `kmem_alloc`s the 48-byte `struct vfs` (not zeroed), inlines its own `VFS_INIT`, then calls `vfs_lock()` (setting `VFS_MLOCK` in `vfs_flag`) **before** dispatching your `VFS_MOUNT`. A filesystem that calls `VFS_INIT()` inside its own mount op therefore **wipes the kernel's own lock bit** — only ever **OR** into `vfs_flag`, never assign it. ✅
- **`vfs_dev`, `vfs_fsid`, `vfs_bcount` arrive as heap garbage and must be set** (stock s5 sets all three). A garbage `vfs_dev` leaks to userland via `statvfs` and can falsely match in `vfs_devsearch()` (used by `umount(2)`, `bdevbsize`, NFS `getvfs`). ✅
- **The device-less convention is *not* `vfs_dev = 0`.** `prinit`/`fdinit` latch a unique major from **`getudev()`** once at init and stamp `makedevice(udev, 0)` per mount. ✅
- **`vfs_add` clears `VFS_RDONLY` unless the caller passed `MS_RDONLY`.** A read-only filesystem that merely sets the flag itself will be believed **writable** — gate the mount on `MS_RDONLY` (return `EROFS`) or the kernel's state lies. ✅

And two userland-side halves of the same contract:

- **`mount(2)` silently *stacks* mounts on an already-mounted directory** — its only busy check is `v_vfsmountedhere` on the vnode `lookupname` returns, but for a mounted-on dir `lookupname` *traverses into* the mounted filesystem whose root has that flag clear. So a second identical `mount` returns 0 and stacks, and `umount` then pops one layer and returns 0 while the media "is still there" — a perfect imitation of a broken umount. Guard it in your own mount op (`v_count > 1` or `VROOT` → `EBUSY`), exactly as `prmount`/`fdmount` do. ✅ This one is on the [quirks checklist](../how-it-works/quirks.md#19-mount2-silently-stacks-mounts-a-fake-broken-umount) too.
- **`/etc/mnttab` is userland-maintained, and `umount(1M)` unmounts by the SPECIAL field.** The kernel never writes `mnttab`; the per-fstype helper `/usr/lib/fs/<fstype>/mount` does (and **without that binary the fstype cannot be mounted at all** — SVR4 `mount(1M)` execs it). Because `umount(1M)` locates the mount by the entry's **special** field, a device-less filesystem must record its **mount point** as the special (`/proc`/`/dev/fd` set the precedent, e.g. `/proc /proc proc rw …`); recording a `<card>,<unit>` spec instead makes `umount` silently fail while deleting the entry. Trade-off to document: `mnttab` then no longer records *which* unit is mounted. Append the line with a single `O_APPEND` write, and **never fail the mount because bookkeeping failed** (warn, exit 0). ✅

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
- **The HBA/DMA driver contract** (the "real hardware" section) — **amix-z3660scsi** @ `2a463b8`: `a5af58a`
  (`sdcom` stack-lifetime → synchronous in-context *iterative* completion via a driver-owned FIFO +
  `completing` guard; a callout deferral read a dead-stack `cp->intr`), `908f40a` (spl6 mailbox bracket
  + nest counters), the `sdcom.addr`-is-physical / no-double-`vtop()` rule (source-verified across
  `dd.c:240` and the cdfs media backend), and the callout-IPL verdict (callouts dispatch at IPL4 but
  only the level-2 CIA-A clock triggers them, so spl2 sections are sound; `spl5/6/7` all emit `_spl4`)
  from stock-kernel disassembly; repo `NOTES.md` §"two load-bearing contracts". Validated on a real
  A4000 + Z3660 (T2.P3, 2026-07-10 → 07-12). ✅
- **The DMA-alignment contract + the VFS_MOUNT / mnttab contract** — **amix-cdfs** @ `31e8c3b`:
  `fa9db1a`+`31e8c3b` (page-align DMA targets + a permanent `(va & (NBPP-1)) + nbyte > NBPP` guard;
  `NBPP = 2048` from `sys/immu.h`; >4096 kmem is physically scattered so `vtop()` is valid for one page
  — the 8-byte allocator header shifted sector buffers off-page and wild-wrote the next frame),
  `0fcf308` (VFS_MOUNT contract: don't `VFS_INIT` over the kernel's lock bit; set `vfs_dev`/`fsid`/`bcount`;
  `getudev()` for device-less; `vfs_add` clears `VFS_RDONLY`), `844c2ed` (anti-stacking + `getudev`),
  `6f727b1`+`d3beca7` (`platform/amix/mount.c` userland helper + `mnttab` special-field semantics);
  `tests/unit/test_remount.c`. Stock-kernel disassembly (symbol-bearing relocatable kernel, period
  m68k binutils). Live on a real A4000 + Z3660 (2026-07-12 → 07-13): canary soak 15/15 byte-identical
  post-fix vs corruption by cycle 2–10 pre-fix (the `/usr/sbin/umount` ELF-ident zeroing incident);
  mount-stacking reproduction; `mnttab` special-field A/B test. ✅
- amigaunix.com — historical and end-user reference: <https://www.amigaunix.com/doku.php/home>
