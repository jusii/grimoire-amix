---
title: Writing a Character Driver (par.c walkthrough)
summary: The Ditto paper's parallel-port driver, entry point by entry point, with the kernel APIs it exercises and a pointer to a modern char/mmap example.
status: draft
---

# Writing a Character Driver (par.c walkthrough)

The canonical Amix character driver is **`par.c`**, the Amiga parallel-port driver printed in full at the end of Michael Ditto's *Writing Amix Device Drivers* (1990 European Amiga Developer's Conference). It is small (317 lines), output-only (a Centronics printer interface), and it exercises **most of the entry points and kernel APIs a real character driver needs**: `open`/`close`/`read`/`write`/`ioctl`/`poll`, a level-2 interrupt routine, the `timeout()` machinery, `sleep()`/`wakeup()` flow control, a clist output queue, and `pollwakeup()`. This page walks the driver entry point by entry point and names the API behind each one ✅.

This page is **uniformly ✅** (primary source: the Ditto paper, pp. 8–22) except where a tag says otherwise. For the conceptual model behind switch tables and major/minor numbers, read [the Amix device-driver model](driver-model.md) first; for how `par.c` gets linked into a kernel, see [building and installing a kernel](kernel-build.md). For a *modern* character driver that also implements `mmap`, jump to [the VA2000 framebuffer case study](case-studies/va2000.md).

> **Licensing note.** `par.c` is reproduced and quoted here only in short excerpts for documentation, from the publicly circulated Ditto paper. The full driver listing is in that paper; the Amix distribution itself ships the stock driver sources under `/usr/sys`. Do not redistribute the disk images or the PDF — point readers to [amigaunix.com](https://www.amigaunix.com/doku.php/home) and archive.org instead.

## What par.c does

`par.c` drives `/dev/par` — **character major 21**, output-only Centronics ✅. Its job, in the paper's words:

- Accept data bytes from a user process via `write()` and queue them for the parallel port.
- Send queued bytes as long as the port's status lines say the device is ready.
- Provide **flow control** by putting the writer to sleep when the output queue is full.
- Let a process select, via `ioctl()`, which status lines decide "ready" (the `PIOCSETCTL`/`PIOCGETCTL` commands).

The driver's own header comment lists what it deliberately does *not* show ✅:

```c
/*
 * par.c : Amiga parallel port driver for Amix.
 *
 * This is a generic driver for the Amiga parallel port, appropriate
 * for use with a Centronics printer interface.  Only output is supported.
 *
 * Deficiencies of this example:
 *    It does not demonstrate autoconfiguration, multiple minor numbers,
 *    or streams or block interfaces.
 */
```

For autoconfiguration see [Zorro II autoconfig for drivers](zorro-autoconfig.md); for the STREAMS path see [writing a STREAMS driver](writing-a-streams-driver.md); for block drivers see [the driver model](driver-model.md#block-vs-character-semantics).

## Headers, macros, and state

`par.c` includes the standard DDI/DKI headers plus three Amix-specific ones ✅ (lines 13–23):

```c
#include "sys/types.h"
#include "sys/param.h"
#include "sys/poll.h"
#include "sys/uio.h"
#include "sys/file.h"
#include "sys/errno.h"
#include "sys/sysmacros.h"
#include "sys/inline.h"
#include "clist.c"      /* Support for clist functions */
#include "amigahr.h"    /* Various bits of Amiga hardware */
#include "par.h"        /* Declarations for this particular driver */
```

The driver-private state is a handful of file-scope `static`s ✅ (lines 36–72). The two that matter most:

```c
/* This is the cpu priority level for all parallel-related processing */
#define splpar()    spl2()

static int parflags;            /* Various flags */
#define P_INPUT     0x01        /* Open for input mode (unsupported) */
#define P_OUTPUT    0x02        /* Open for output mode */
#define P_OPEN      0x03        /* NZ if the device is open */
#define P_OUTSLP    0x08        /* Sleeping because outq is full */
#define P_FLUSHING  0x10        /* Sleeping until queue is empty */
#define P_OUTPEND   0x20        /* Output character is pending */
#define P_OUTERR    0x80        /* An output character timed out */

static struct pollhead parpollist;   /* list of all pollers to wake up */
static short control_bits = C_SEL|C_POUT|C_BUSY;  /* status lines to examine */

static struct clist par_outq;        /* Output queue */
#define PAR_LOWAT   100
#define PAR_HIWAT   400

#define PAROPRI     29               /* sleep() priority */

#define PARTIMEOUT  (HZ*60)          /* 60s: no ack -> I/O Error */
#define TRYAGAIN    (HZ*1)           /* 1s:  lines deasserted, retry */
static int timeout_id;
static unsigned char currentbyte;    /* byte being output, for retry */
```

Three things to notice:

- **`splpar()` is just `spl2()`** ✅ — the driver runs the parallel port off the **level-2 (INT2) autovector**, so it masks at SPL 2 whenever it touches shared state. See [`spl2()/splx()`](#interrupt-masking-spl2--splx).
- The **output queue is a `clist`** (`par_outq`), with high/low watermarks (`PAR_HIWAT` = 400, `PAR_LOWAT` = 100) used for flow control ✅.
- `parflags` is a bitfield of driver states; the interrupt routine and the syscall routines coordinate purely through it (under `splpar()`).

## The init function: parinit()

`parinit()` is the **boot-time init function** — it is named in `init_tbl[]` in `kernel.c`, so the kernel calls it once at startup ✅ (lines 75–82). Its only job is to make the port quiet so it does not interrupt the system or dribble random bytes to whatever is plugged in until someone actually opens the device:

```c
void parinit()
{
    ACIAB->ddra &= 3;            /* Set PSEL, PPOUT & PBUSY to input */
    ACIAA->ddrb = 0;             /* Set all 8 data bits to input */
    ACIAA->icr = ICR_CLR|ICR_FLG;/* Disable "Flag" Interrupt */
}
```

`ACIAA`/`ACIAB` are the Amiga 8520 CIA chips; `ICR_FLG` (`0x10`) is the parallel "FLAG" interrupt bit ✅. This is the only entry point that touches `init_tbl[]`; the rest are wired into `cdevsw[21]` or `int2_tbl[]` (see [the driver model's `*_tbl` arrays](driver-model.md#the-_tbl-arrays)).

## open: paropen()

`paropen(devp, flags, type, cr)` is called by the `open(2)` system call ✅ (lines 85–114). The arguments are the standard SVR4 character-`open` set: `devp` points at the device number (split with `getmajor()`/`getminor()`), `flags` is the open bit-mask, `type` says how it is being opened, and `cr` is the caller's credentials (already permission-checked by the kernel, so the driver ignores it). Key logic:

```c
int paropen(devp, flags, type, cr)
dev_t *devp;
int flags;
int type;
struct cred *cr;
{
    int s;

    if (getminor(*devp) > 0)
        return ENODEV;          /* no "second parallel port" */

    /* Only output is supported for now */
    if (flags & FREAD)
        return EIO;

    if (!(parflags & P_OPEN)) {
        s = splpar();
        ACIAB->ddra &= 3;       /* Set PSEL, PPOUT & PBUSY to input */
        ACIAA->ddrb = 0xff;     /* Set all 8 data bits to output */
        ACIAA->icr = ICR_SET|ICR_FLG; /* Enable "Flag" Interrupt */
        AMIGA->intena = ASET|I_PORTS; /* Just in case it was disabled */
        parflags = P_OUTPUT;    /* Indicate that device is open */
        splx(s);
    }
    return 0;
}
```

Lessons the paper draws out ✅:

- **Validate the minor number.** `par.c` only has sub-device 0, so any `getminor() > 0` returns **`ENODEV`** ("No such device or address"). A richer driver would decode the minor into modes or units here.
- **Reject unsupported access modes.** Output-only means `O_RDONLY`/`O_RDWR` (i.e. `FREAD` set) returns **`EIO`**.
- **Only initialize the hardware on the first open.** If the device is already open (`P_OPEN` set), don't re-poke registers — that could corrupt an in-flight transfer.
- **A zero return means success.** Any nonzero return aborts the open and is handed to user space as `errno`.

## close: parclose()

`parclose(dev, flags, type, cr)` is the most instructive routine in the driver because it shows **how to block in the kernel correctly** ✅ (lines 117–145):

```c
int parclose(dev, flags, type, cr)
dev_t dev; int flags; int type; struct cred *cr;
{
    int s = splpar();

    /* wait for output to drain */
    while (parflags & P_OUTPEND) {
        parflags |= P_FLUSHING;
        if (sleep(&par_outq, PAROPRI|PCATCH)) {
            /* Interrupted: abort and flush all output */
            untimeout(timeout_id);
            parflags &= ~P_OUTPEND;
            while (getc(&par_outq) != -1)
                ;
        }
    }
    parflags = 0;
    splx(s);

    ACIAB->ddra &= 3;            /* idle the port again */
    ACIAA->ddrb = 0;
    ACIAA->icr = ICR_CLR|ICR_FLG;
    return 0;
}
```

What to take away ✅:

- **`splpar()` around the shared state, then sleep inside it.** The driver raises to SPL 2, then loops while output is still pending. Crucially, **the interrupt level is automatically restored while `sleep()` is blocked** and re-raised on wakeup — so holding `splpar()` across `sleep()` is correct, not a deadlock.
- **`sleep(chan, pri)` blocks; `wakeup(chan)` releases.** Here the channel is `&par_outq` (the address is just a token both sides agree on) and the priority is `PAROPRI` (29). The interrupt routine signals "queue drained" with `wakeup(&par_outq)`.
- **`PCATCH` lets the user interrupt the sleep.** Passing `PAROPRI|PCATCH` means a `^C` (signal) makes `sleep()` return nonzero instead of hanging the close. The driver then cleans up: `untimeout()` cancels the pending timeout and `getc(&par_outq)` drains the queue to `-1` (empty). **Without `PCATCH`, a signal would abort the process *and* the close routine, leaving the driver's `static` state inconsistent** — the paper calls this out explicitly.

## read: parread()

Read is **not implemented** because the port is output-only ✅ (lines 148–156). It is still listed so the entry point is non-null, and it just returns an error:

```c
int parread(dev, uiop, cr)
dev_t dev; struct uio *uiop; struct cred *cr;
{
    /* Not implemented */
    return EINVAL;
}
```

In practice this code never runs, because `paropen()` already rejects any open with `FREAD`. (In the [`cdevsw[]` slot](driver-model.md#naming-convention-prefix-every-entry-point) you could equally point `d_read` at the stock `nodev` stub; `par.c` supplies its own `EINVAL` version instead.)

## write: parwrite()

`parwrite(dev, uiop, cr)` is the heart of the driver ✅ (lines 159–190). The `uiop` argument is a `uio` struct describing the user's buffer; the driver pulls bytes out of it one at a time with **`uwritec()`** and either hands each byte straight to the hardware or queues it:

```c
int parwrite(dev, uiop, cr)
dev_t dev; struct uio *uiop; struct cred *cr;
{
    int s;
    register int c;

    s = splpar();

    while ((c = uwritec(uiop)) != -1) {
        while (!(parflags & P_OUTERR) &&
               par_outq.c_cc > PAR_HIWAT) {
            parflags |= P_OUTSLP;
            sleep(&par_outq, PAROPRI);
        }
        if (parflags & P_OUTERR) {
            parflags &= ~P_OUTERR;
            splx(s);
            return EIO;
        }
        if (!(parflags & P_OUTPEND))
            parstart(c);
        else
            if (putc(c, &par_outq) == -1)
                return ENOSPC;
    }

    splx(s);
    return 0;
}
```

The teaching points ✅:

- **`uwritec(uiop)` returns the next user byte, or `-1` at end / on fault.** It hides `copyin()` and the `uio` bookkeeping. (If a fault occurs mid-transfer, the residual count in the `uio` is left non-zero, which signals the error to the caller.)
- **Flow control via the high watermark.** While the clist holds more than `PAR_HIWAT` (400) characters, the writer marks `P_OUTSLP` and `sleep()`s on `&par_outq`. **Re-check the condition after every wakeup** — the paper stresses you must not assume the reason you slept is gone just because `sleep()` returned.
- **Report deferred errors.** A byte that timed out earlier is reported here by checking `P_OUTERR` and returning **`EIO`** — there is no other place to surface it to the user.
- **Fast path vs queue.** If nothing is currently being clocked out (`!P_OUTPEND`), the byte is handed straight to [`parstart()`](#the-engine-room-parstart-and-partimeout); otherwise it is queued with **`putc(c, &par_outq)`**, which returns `-1` (→ **`ENOSPC`**) only if the kernel cannot grow the clist (out of memory).

## ioctl: parioctl()

`parioctl(dev, cmd, arg, mode, cr, rvalp)` implements the two device-specific commands ✅ (lines 193–214). `cmd` selects the operation; `arg` is the user's argument; `rvalp` points where the driver stores a return value for the caller:

```c
int parioctl(dev, cmd, arg, mode, cr, rvalp)
dev_t dev; int cmd, arg; int mode; struct cred *cr; int *rvalp;
{
    switch (cmd) {
    case PIOCGETCTL:
        *rvalp = control_bits;
        break;
    case PIOCSETCTL:
        control_bits = arg & (C_SEL|C_POUT|C_BUSY);
        break;
    default:
        /* Unknown ioctl */
        return EINVAL;
    }
    return 0;
}
```

- **`PIOCGETCTL`** returns the current handshake-line mask in `*rvalp`.
- **`PIOCSETCTL`** sets it, masking `arg` down to the three meaningful bits **`C_SEL | C_POUT | C_BUSY`** (the SELECT, PAPER-OUT, and BUSY status lines). A zero bit means "ignore that line when deciding readiness."
- **Any other `cmd` returns `EINVAL`.** The `PIOC*` commands were invented for this device, but a driver is free to interpret standard `<termios.h>` commands here too — it is entirely the driver writer's choice which `ioctl`s to support.

> **Naming wrinkle (read carefully).** The driver *source* uses the symbols `C_SEL`, `C_POUT`, `C_BUSY`, while the **`par(7A)` man page** documents the same bits as **`PC_SEL`, `PC_POUT`, `PC_BUSY`** ✅. Treat them as the same three handshake lines under two spellings (the `PC_` form is the public/`<sys/par.h>` name; the `C_` form is what the listing in the paper compiles against). See [the man page section](#the-par7a-man-page) below.

## poll: parpoll()

`parpoll(dev, events, anyyet, reventsp, phpp)` implements `poll(2)` support ✅ (lines 217–256). A polling driver's job is **not** to sleep (it doesn't know what else the caller is polling) — it just reports whether *this* device is ready right now, and, if not, hands the kernel the address of its `pollhead` so it can be woken later:

```c
int parpoll(dev, events, anyyet, reventsp, phpp)
dev_t dev; short events; int anyyet; short *reventsp; struct pollhead **phpp;
{
    register short retevents = 0;
    register int s = splpar();

    /* Read not implemented; always ready */
    retevents |= (events & (POLLIN|POLLRDNORM));

    /* For output, only ready if queue has room */
    if ((parflags & P_OUTERR) || par_outq.c_cc <= PAR_HIWAT)
        retevents |= (events & (POLLWRNORM|POLLOUT));

    *reventsp = retevents;
    if (retevents) {
        splx(s);
        return 0;
    }

    /*
     * If poll() has not found any events yet, set up event cell
     * to wake up the poll if a requested event occurs ...
     */
    if (!anyyet)
        *phpp = &parpollist;

    splx(s);
    return 0;
}
```

- Unsupported (input) events are reported **ready** so a caller that tries to read gets an immediate error rather than hanging.
- Output events (`POLLWRNORM|POLLOUT`) are ready only when the queue has room (`c_cc <= PAR_HIWAT`) or an error is pending.
- If nothing is ready *and* the caller has not already matched on another fd (`!anyyet`), the driver publishes `&parpollist` via `*phpp`. The kernel remembers it; the interrupt routine later calls [`pollwakeup()`](#interrupt-routine-parintr) on that same `parpollist` to wake the poll.

## Interrupt routine: parintr()

`parintr()` is named in **`int2_tbl[]`** in `kernel.c`, so it runs on the Amiga **level-2 (INT2) autovector** when the parallel port's FLAG line interrupts ✅ (lines 259–284). It takes no arguments and returns nothing; an interrupt *is* the acknowledgement that the last byte was accepted. Its two jobs: clock out the next queued byte, and wake anyone waiting for room or for the queue to empty.

```c
void parintr()
{
    if (parflags & P_OUTPEND) {
        untimeout(timeout_id);          /* ack arrived: cancel timeout */
        if (par_outq.c_cc)
            parstart(getc(&par_outq));  /* send next queued byte */
        else
            parflags &= ~P_OUTPEND;     /* idle */

        if (par_outq.c_cc <= PAR_LOWAT) {
            if ((parflags & P_OUTSLP) ||
                ((parflags & P_FLUSHING) && !par_outq.c_cc)) {
                parflags &= ~(P_OUTSLP|P_FLUSHING);
                wakeup(&par_outq);
            }
            pollwakeup(&parpollist, POLLWRNORM);
            pollwakeup(&parpollist, POLLOUT);
        }
    }
}
```

Key points ✅:

- **The interrupt is the ack.** Receiving it means the device took the previous byte, so the routine cancels the pending timeout with **`untimeout(timeout_id)`** and pulls the next byte off the clist with **`getc(&par_outq)`**, feeding it to `parstart()`.
- **Wake the right sleepers, only when needed.** When the queue drops to the low watermark, processes blocked in `write()` (`P_OUTSLP`) are released; a process blocked in `close()` (`P_FLUSHING`) is released **only once the queue is fully empty**. The single `wakeup(&par_outq)` covers both.
- **`pollwakeup(&parpollist, ...)` notifies pollers.** Two calls, one per writable event code (`POLLWRNORM`, `POLLOUT`), tell any `poll()` waiters the device is now writable.
- **Be defensive.** The routine may be entered with nothing to do (a shared interrupt line, a stray strobe, a cable being unplugged), so it guards everything on `P_OUTPEND` and simply returns when there is no work.

## The engine room: parstart() and partimeout()

These two `static` helpers are not switch-table entry points; they are the driver's private "start one byte / handle a stuck byte" pair ✅.

**`parstart(ch)`** (lines 304–317) tries to push one byte to the hardware, arming a timeout either way:

```c
static void parstart(ch)
unsigned char ch;
{
    currentbyte = ch;
    parflags |= P_OUTPEND;

    if ((ACIAB->pra ^ C_SEL) & control_bits)
        /* device NOT ready: retry after TRYAGAIN ticks */
        timeout_id = timeout(parstart, currentbyte, TRYAGAIN);
    else {
        ACIAA->prb = ch;        /* poke the byte to the data port */
        timeout_id = timeout(partimeout, 0, PARTIMEOUT);
    }
}
```

- It saves the byte in `currentbyte` so it can be **re-sent after a timeout**, and sets `P_OUTPEND`.
- It tests the status lines (`ACIAB->pra`, masked by `control_bits`). If the device claims it is **not** ready, it does nothing now but arms **`timeout(parstart, currentbyte, TRYAGAIN)`** — a one-second retry. If it **is** ready, it writes the byte to `ACIAA->prb` and arms **`timeout(partimeout, 0, PARTIMEOUT)`** — a 60-second deadline for the acknowledging interrupt.

**`partimeout()`** (lines 287–301) is what the kernel clock routine calls if that 60-second deadline expires without an interrupt ✅ — i.e. the ack never came. If communication is healthy this **never runs**, because `parintr()` cancels the timeout on every ack:

```c
static void partimeout()
{
    if (!((ACIAB->pra ^ C_SEL) & control_bits)) {
        parflags |= P_OUTERR;   /* flag the error for parwrite() */
        /* Wake up anyone who's sleeping so they notice the error */
        if (parflags & (P_FLUSHING|P_OUTSLP)) {
            parflags &= ~(P_FLUSHING|P_OUTSLP);
            wakeup(&par_outq);
        }
        pollwakeup(&parpollist, POLLWRNORM);
        pollwakeup(&parpollist, POLLOUT);
    }
    parstart(currentbyte);      /* give the byte a second chance */
}
```

- If the status lines say the device *is* ready (so it should have acked but didn't), something is wrong: set **`P_OUTERR`**, then wake sleepers and pollers so they observe the error — there is no return value at timeout time, so the error must be flagged for the *next* `write()`/`close()`/`poll()` to report.
- Either way it re-issues `parstart(currentbyte)`, giving the stuck byte another attempt.

This `start → arm timeout → interrupt cancels timeout → start next` loop is the standard pattern for an interrupt-driven character driver; a DMA block driver uses the analogous `strategy()`/interrupt pair (see [block vs character semantics](driver-model.md#block-vs-character-semantics)).

## Kernel APIs used, at a glance

Everything `par.c` leans on is part of the SVR4 DDI/DKI surface (plus the clist helpers) ✅:

| API | Used in | Purpose |
|---|---|---|
| `getminor(*devp)` | `paropen` | extract the minor number from a `dev_t` |
| `uwritec(uiop)` | `parwrite` | pull the next user byte from a `uio` (returns `-1` at end/fault); wraps `copyin()` |
| `getc()` / `putc()` | `parwrite`, `parintr`, `parclose` | dequeue / enqueue a byte on a **clist** (`putc` → `-1` = `ENOSPC`) |
| `sleep(chan, pri[\|PCATCH])` | `parwrite`, `parclose` | block the caller on a channel; `PCATCH` makes it signal-interruptible |
| `wakeup(chan)` | `parintr`, `partimeout` | release everyone sleeping on `chan` |
| `timeout(fn, arg, ticks)` | `parstart` | schedule `fn(arg)` after `ticks`; returns an id |
| `untimeout(id)` | `parintr`, `parclose` | cancel a pending `timeout()` |
| `spl2()` / `splx(s)` | everywhere | raise to / restore from the level-2 interrupt priority (`splpar()` == `spl2()`) |
| `pollwakeup(php, event)` | `parintr`, `partimeout` | wake `poll()` waiters registered on a `pollhead` |

`copyin()`/`copyout()` themselves don't appear directly in `par.c` because `uwritec()` and the clist do the user/kernel copying; a driver doing a custom `ioctl` payload, or an `mmap` driver, would call them explicitly — as the [VA2000 case study](case-studies/va2000.md) does. The full API matrix lives in [the driver model](driver-model.md#key-kernel-apis-the-driver-side).

## The par(7A) man page

The paper closes the example with the device's manual page, `par(7A)` (p. 22). The user-facing contract is short ✅:

- **`/dev/par`** is the Amiga parallel port — "a superset of a Centronics standard printer port," but this driver supports **only normal Centronics output**.
- **The device must be opened with `O_WRONLY`.** Input is not supported (matching `paropen()` returning `EIO` on `FREAD`).
- It is a completely **raw** interface — no data translation is done on I/O.
- The `BUSY`, `SEL`, `POUT`, and `ACK` input status lines are normally used for handshaking on output; the first three (`BUSY`, `SEL`, `POUT`) can be individually set to be ignored.
- **`PIOCSETCTL`** sets which lines are used for handshaking; the setting persists across closes and reopens. `arg` is the logical OR of any of **`PC_SEL`, `PC_POUT`, `PC_BUSY`**; a zero bit ignores that line. (The man page lists `PC_*`; the source compiles `C_*` — same bits, see the [ioctl wrinkle](#ioctl-parioctl) above.) **`PIOCGETCTL`** reads back the current handshake-line mask ✅.

A minimal user program against this contract ✅:

```c
#include <sys/types.h>
#include <sys/par.h>
#include <fcntl.h>

int fd = open("/dev/par", O_WRONLY);   /* O_WRONLY is mandatory */

/* Ignore the SEL line; require POUT and BUSY for handshaking */
ioctl(fd, PIOCSETCTL, PC_POUT | PC_BUSY);

write(fd, "Hello, printer\n", 15);
close(fd);                              /* blocks until the queue drains */
```

To create the node (the paper's final step in [adding a driver](driver-model.md#adding-a-driver-the-table-workflow)): `mknod /dev/par c 21 0` ✅.

## From par.c to a modern driver: the VA2000

`par.c` deliberately skips three things its own header lists: **autoconfiguration, multiple minor numbers, and `mmap`/STREAMS** ✅. The community **VA2000 framebuffer driver** is the natural "next example" because it fills the biggest gap — it is a character driver that also implements **`mmap`** so X11 can map the framebuffer directly:

- Device **`/dev/va2000`**, **character major 68** minor 0 ✅.
- Single-file native build (`cc va2000.c`), patched into six kernel files including a `cdevsw[]` slot 68 and a `va2000init` entry in `io_init[]` ✅.
- Uses **`autocon()`** for Zorro II board discovery (the autoconfiguration `par.c` skips), plus **`uiomove()`** and explicit **`copyin()`/`copyout()`** ✅.

Read the full mechanics — kernel-file patches, the `make install` / `make bootpart KERNEL=relocunix` cycle, and the pre-POSIX `/bin/sh` gotchas — in [the VA2000 framebuffer case study](case-studies/va2000.md). For the X11 server that maps it, see [the Xrtg case study](case-studies/xrtg.md) and [X11 RTG drivers](x11-rtg-drivers.md).

## See also

- [The Amix device-driver model](driver-model.md) — switch tables, major/minor numbers, the `*_tbl` arrays, and the `nodev`/`notty`/`nostr`/`nullflag` stubs.
- [Building and installing a kernel](kernel-build.md) — how `par.c` gets compiled and linked into `/unix`.
- [Writing a STREAMS driver](writing-a-streams-driver.md) — the third driver kind, for networking (the path `par.c` skips).
- [Zorro II autoconfig for drivers](zorro-autoconfig.md) — `autocon()` / AUTOCONFIG board discovery.
- [Case study: VA2000 framebuffer (char major 68)](case-studies/va2000.md) — a modern char driver with `mmap`.
- [Device list reference](../reference/device-list.md) — known major/minor numbers, including `/dev/par` (major 21).
- [The toolchain](toolchain.md) — native on-box `cc`/GCC builds, and the (separate) `m68k-amix-gcc` cross-compiler gap.

## Sources

- Ditto, Michael. *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference — pp. 8–22: the line-by-line driver narrative (pp. 8–12), the full `par.c` listing (pp. 13–19, lines 1–317), the references (pp. 20–21), and the `par(7A)` man page (p. 22). All code excerpts on this page are quoted from that listing.
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §5 (device-driver model; the `par.c` worked example as the canonical char-driver teaching case) and §6 (VA2000 modern char/`mmap` driver facts).
- `asokero/va2000-amix` repo (char major 68, `/dev/va2000`, `mmap`, `autocon()`/`uiomove()`/`copyin`/`copyout`): <https://github.com/asokero/va2000-amix>
- amigaunix.com — historical and end-user reference for Amix and its media: <https://www.amigaunix.com/doku.php/home>
