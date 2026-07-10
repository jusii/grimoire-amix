---
title: Reverse-engineering the prebuilt kernel
summary: Recovering Amix kernel internals with no source — disassembling the shipped /usr/sys/*/exp objects and reading globals from an emulator savestate — worked through the mount(2) fstype-dispatch path.
status: draft
---

# Reverse-engineering the prebuilt kernel

Large parts of the Amix kernel ship as **prebuilt relocatable objects with no `.c` source** — the VFS
layer, the syscall trap, the mount path. When you need to know exactly what one of these does (and the
in-guest debuggers can't help), the reliable route is to **disassemble the shipped objects on the host**
and, for runtime state, **read a running kernel out of an emulator savestate**. Everything on this page
was **reproduced locally** ✅ — disassembly of the objects in `~/opt/amix-cross/.../sysroot/usr/sys`
with the cross `objdump`, cross-checked against a live kernel image and against an on-box test.

## Why: the kernel ships as objects, not source

Amix builds the kernel from per-directory **linked export objects**, one `exp` per subsystem, not from a
flat pile of `.c` files (see [Kernel architecture → the kernel as object libraries](../how-it-works/kernel-architecture.md#the-kernel-as-object-libraries-in-usrsys)) ✅. The Commodore-authored core — `os/`, `fs/` — is present only as those objects; there is **no `os/vfs.c` / `os/trap.c` in `/usr/sys`** to read. But the objects are ordinary m68k COFF/relocatable files, so they disassemble cleanly, **with symbols and relocations** — which means `jsr` targets show up by name. That makes the disassembly readable as pseudo-source.

## Step 1 — find which `exp` defines a symbol

The staged kernel tree lives under the cross sysroot; use the cross binutils (never the host's) ✅:

```sh
SYS=~/opt/amix-cross/m68k-cbm-sysv4/sysroot/usr/sys
NM=~/opt/amix-cross/bin/m68k-cbm-sysv4-nm

# which object defines `mount`, `vfs_getvfssw`, `vfsinit`, `vfssw`?
for f in $(find "$SYS" -name exp -o -name '*.exp'); do
  m=$("$NM" "$f" 2>/dev/null | grep -iwE '_?mount|_?vfs_getvfssw|_?vfsinit|_?vfssw')
  [ -n "$m" ] && echo "### ${f#$SYS/}" && echo "$m"
done
```

For the mount path this points at two objects ✅:

| Symbol | Object | Offset |
|---|---|---|
| `mount` (the syscall) | `fs/fs.exp` | `0x1814` |
| `vfs_getvfssw` | `fs/fs.exp` | `0x2370` |
| `vfsinit` | `fs/fs.exp` | `0x2446` |
| `sysent` (syscall table) | `os/exp` | `0x6f8` |
| `systrap` (trap dispatcher) | `os/exp` | `0x1eaf6` |

## Step 2 — disassemble with relocations

`objdump -dr` interleaves the relocation records, so every external call is annotated with its target
symbol ✅:

```sh
OD=~/opt/amix-cross/bin/m68k-cbm-sysv4-objdump
"$OD" -dr "$SYS/fs/fs.exp" > fs_exp_dis.txt      # whole object
# extract one function (mount @0x1814 → next label):
awk '/^0*1814 <mount>:/{f=1} f{ if(/^0*1814/){print;next}
     if(/^[0-9a-f]+ <[^>]+>:/){exit} print }' fs_exp_dis.txt
```

The `R_68K_32 lookupname` / `R_68K_32 vfs_getvfssw` reloc lines under each `jsr` tell you what is being
called without any guessing. This is what makes a source-free object tractable.

The same reloc-annotated disassembly reaches well past the VFS/mount functions tabled above. The in-kernel **SCSI path** was cracked the same way — `sdopen` (the `sd` disk driver's open entry) and `getrdb` (the RDB / Rigid Disk Block parser) — reading their `jsr` targets by name straight out of their `exp` objects ✅. Any source-free subsystem, core *or* driver, is fair game.

## Step 3 — read a *running* kernel from a savestate

The on-guest debuggers are unreliable here: `adb -k /stand/unix /dev/kmem` reads garbage because the
**relocated runtime kernel does not match the `/stand/unix` namelist** (constants like `nfstype` read as
0), and `crash` errors out on `/dev/mem` ✅. The dependable path is a host-side memory dump.

Take an emulator snapshot (Amiberry: the `SAVESTATE` IPC verb) and pull globals out of the RAM chunk.
On an A3000-fastmem machine the kernel lives in the **`A3K1` chunk, identity-mapped at physical base
`0x07800000`** (runtime VA = `0x07800000 + chunk_offset`) ✅. The `.uss` chunk format is
`name(4) + len(4 BE) + flags(4 BE) + [uclen(4 BE) if compressed] + zlib data`. Find a table by an
unambiguous anchor (e.g. the `"BADVFS"` string that heads `vfssw[]`) and walk it:

```python
import zlib, struct
d = open("amix.uss","rb").read()
j = d.find(b"A3K1")
ram = zlib.decompressobj().decompress(d[j+16:])[:struct.unpack(">I", d[j+12:j+16])[0]]
BASE = 0x07800000
W = lambda o: struct.unpack(">I", ram[o:o+4])[0]      # runtime VA = BASE + o
```

This recovered the live `vfssw[]` (each row `{char *vsw_name; int (*vsw_init)(); struct vfsops *vsw_vfsops; long vsw_flag}`, 16 bytes) and the `int nfstype` immediately after it ✅ — see the worked example below.

### Grabbing the snapshot — the two-arg `SAVESTATE` IPC

Amiberry's `SAVESTATE` verb takes **two** arguments — a statefile *and* a configfile. Called with one it errors and saves nothing ✅:

```sh
printf 'SAVESTATE\t/tmp/x.uss\t/tmp/x.cfg\n' \
  | socat - UNIX-CONNECT:/run/user/<uid>/amiberry.sock
```

It works even at a kernel **panic screen**, so you can snapshot a wedged kernel and read *why* it wedged ✅. A bench scanner, `scan_a3k1.py`, automates pulling the `A3K1` chunk and resolving globals out of the resulting `.uss` ✅.

### Locating a global by symbol — `nm` values are *section-relative*

Step 3's walk above found `vfssw[]` by a string anchor (`"BADVFS"`). When a global has no such anchor, resolve it by symbol with the cross `nm` on the **linked kernel image** `/usr/sys/relocunix` — but its values are **section-relative, not absolute** ✅. The kernel loads **packed** as `text | data | bss` at base `0x07800000`, so the byte offset of a symbol into the `A3K1` chunk is:

| Symbol's section | Byte offset into `A3K1` |
|---|---|
| **bss** | `text_size + data_size + nmval` |
| **data** | `text_size + nmval` |

with `text_size` / `data_size` read from `size /usr/sys/relocunix` (cross `size`). Taking the raw `nmval` as the offset — the naïve reading — lands you in kernel **code**, not the variable ✅.

Validated at the computed offsets: `scsicard[]` shows the `0xc0de0001` / `0xc0de0002` product codes and the global `block` shows the `UNIX_Root` `PART` record ✅.

## Worked example — how `mount(2)` and fstype registration actually work

Disassembling the three `fs.exp` functions above yields the complete, source-accurate picture ✅:

**Registration is a compile-time table + an init sweep.** Filesystems live in `vfssw[]` (built from
`master.d/filesys.c`); `nfstype` is its length. At boot, `vfsinit` loops `for (i=1; i<nfstype; i++)` and
calls **`vsw_init(&vfssw[i], i)`** for each row — so a filesystem's init hook (e.g. `s5init`, `cdfsinit`)
runs automatically once its row is in the table. Adding a row and relinking is *sufficient* to register a
new FS; there is no separate init-call list to edit ✅. (This resolves a long-standing "how does the
kernel call the fs inits" question — it is `vfsinit`, and it is right there in `fs.exp`.)

**`mount(2)` never looks at the special/spec argument.** The syscall (`fs.exp:0x1814`) resolves the
*mount point* via `lookupname`, then selects the fstype, then dispatches — it forwards the `spec`
untouched to the filesystem's own `VFS_MOUNT`. The fstype selection uses a **pointer-vs-integer
heuristic** ✅:

```c
if ((u_int)uap->fstype < 256) {           /* old SVR3 numeric fstype index */
    if (fstype == 0 || fstype >= nfstype) return EINVAL;   /* <-- errno 22 */
    vfsops = vfssw[fstype].vsw_vfsops;
} else {                                   /* modern string fstype, e.g. "cdfs" */
    copyinstr(uap->fstype, fsname, ...);
    if ((vswp = vfs_getvfssw(fsname)) == NULL) return EINVAL;  /* <-- errno 22 */
    vfsops = vswp->vsw_vfsops;
}
```

`vfs_getvfssw` (`fs.exp:0x2370`) is a plain `for (i=1; i<nfstype; i++) strcmp(name, vfssw[i].vsw_name)`
scan of the same table. The **per-FSType user helpers** `/usr/lib/fs/<fs>/mount` — which the generic
`mount(1M)` execs — always pass the fstype **string** (`mount(spec, dir, MS_DATA|MS_RDONLY, "cdfs", 0, 0)`),
so real mounts take the string branch ✅.

**The trap returns the syscall value verbatim.** `systrap` (`os/exp:0x1eaf6`) stores the syscall's
return straight into the user register (`movel ...,%a5@(4)`) with **no `& 0xFF` mask and no max-errno
clamp** — only `EFBIG`/`EINTR` get special handling ✅. So a filesystem's `VFS_MOUNT` return reaches
`errno` unchanged; there is no hidden remapping to hunt for. (Amix's highest defined errno is ~151;
`EINVAL` is 22.)

## The payoff — an `errno 22` from `mount -F <fs>` means "not live in the booted kernel"

Putting the disassembly together gives a sharp diagnostic ✅. For a **string** mount of a filesystem on
a normal directory, the *only* pre-dispatch `EINVAL(22)` reachable is **`vfs_getvfssw(name) == NULL`** —
i.e. the fstype's row is **not in the running kernel's `vfssw[]`**. Every other 22 site is dead for that
call (the numeric-index check needs an integer fstype; `VNOMOUNT` is only ever set on `/proc` vnodes, not
s5/ufs directories; `lookupname` of an existing dir returns 0/`ENOENT`/`ENOTDIR`, never 22).

So when a freshly-built in-kernel filesystem returns `errno 22` from `mount -F <fs> ... /mnt`, it is
almost always the classic SVR4 trap: the kernel was **patched on disk but not relinked-and-rebooted**, or
the wrong kernel is booted — not a bug in the filesystem's mount code. Confirm live registration directly
with `sysfs(GETFSIND, "<fs>")` (from `<sys/fstyp.h>`: `GETFSIND=1`, `GETNFSTYP=3`), which scans the *same*
`vfssw[]`:

```c
#include <sys/fstyp.h>
i = sysfs(GETFSIND, "cdfs");   /* >=1 → registered live; -1/errno 22 → NOT in this boot */
```

This was verified end-to-end: on a kernel **without** cdfs compiled in, `sysfs(GETFSIND,"cdfs")` returns
`-1` and the string mount returns `errno 22`; the fix is to relink the fstype into the kernel and boot
*that* image, not to touch the mount path ✅. See [Building & installing a kernel](kernel-build.md) for
the relink/install/reboot cycle and [Filesystems & disks](../how-it-works/filesystems-and-disks.md) for
the `/etc/vfstab` side.

## A throwaway-global diagnostic — the `cdfs_diag` pattern

When the console is dead but a savestate still works ([Step 3](#step-3-read-a-running-kernel-from-a-savestate)), a **throwaway global** turns the snapshot into a poor-man's `printf`. cdfs used one, `cdfs_diag`: a struct filled as a mount/read path advanced — reached-stage, `errno`, the first bytes read — then dumped afterward out of the `.uss` ✅. The trick that makes it findable in the packed image: write its **magic word** `0x0DF50001` **last**, so the populated struct is the one whose magic is set. One caveat when you scan the `A3K1` chunk for that magic — it also occurs **coincidentally inside code**, so take the **4-aligned** hit ✅.

## See also

- [Kernel architecture](../how-it-works/kernel-architecture.md) — the object-library build model these `exp` files come from.
- [Building & installing a kernel](kernel-build.md) — relinking a new object/fstype in and writing the boot partition.
- [Filesystems & disks](../how-it-works/filesystems-and-disks.md) — `/etc/vfstab`, device nodes, UFS vs s5.
- [Zorro AUTOCONFIG](zorro-autoconfig.md) — the `autocon()` / `scsicard[]` card-ordering path (also a prebuilt-object read).
- [Case study: A4091 / 53C710 SCSI](a4091-53c710-driver.md) — the driver whose CD host this method was used to debug.

## Sources

- Disassembly of the shipped kernel objects `usr/sys/fs/fs.exp` (`mount` @0x1814, `vfs_getvfssw` @0x2370, `vfsinit` @0x2446) and `usr/sys/os/exp` (`sysent` @0x6f8, `systrap` @0x1eaf6) via `m68k-cbm-sysv4-objdump -dr` / `-nm`, cross toolchain sysroot — reproduced locally ✅.
- Live `vfssw[]` / `nfstype` read from an Amiberry `SAVESTATE` (`A3K1` chunk, identity base `0x07800000`), cross-checked against the disassembly ✅.
- On-box reproduction on Amix 2.1c: `sysfs(GETFSIND,"cdfs")` and a string-form `mount(2)` probe, showing `errno 22` ⇔ fstype absent from the booted kernel's `vfssw[]` ✅.
- `<sys/mount.h>` (`MS_RDONLY=0x01`, `MS_FSS=0x02`, `MS_DATA=0x04`; `int mount(const char *, const char *, int, ...)`), `<sys/fstyp.h>` (`GETFSIND=1`, `GETFSTYP=2`, `GETNFSTYP=3`), `<sys/errno.h>` (`EINVAL=22`) from the Amix sysroot ✅.
- SVR4.0 reference behaviour cross-checked against `calmsacibis995/svr4-src` `uts/i386/fs/vfs.c` (the `mount()`/`vfs_getvfssw` ordering) — Amix is a straight SVR4.0 port ✅.
- Two-arg Amiberry `SAVESTATE` IPC (`statefile` + `configfile`; one arg saves nothing, works at a panic screen) and the `A3K1`-chunk global scanner `scan_a3k1.py` — firsthand bench, amix-cdfs CD-ROM port effort (2026-07-09/10) ✅.
- Section-relative `nm` offset model for the linked kernel image `/usr/sys/relocunix` (bss offset = `text_size + data_size + nmval`, data offset = `text_size + nmval`; sizes from `size`), validated against the `scsicard[]` `0xc0de0001`/`0xc0de0002` product codes and the `block` global's `UNIX_Root` `PART` record in the A3K1 dump — firsthand ✅.
- Same `objdump -dr` reloc-annotated method extended to the in-kernel SCSI path — `sdopen` and `getrdb` (RDB parser) traced by name out of their `exp` objects — firsthand ✅.
- cdfs's `cdfs_diag` throwaway-global diagnostic (magic `0x0DF50001` written last; scan the `A3K1` chunk for the 4-aligned hit) — firsthand from the amix-cdfs port ✅.
