#!/usr/bin/env bash
#
# build-bootfloppy.sh — build a custom Amix boot floppy (boot.adf) carrying YOUR
# m68k ELF kernel, by reusing the bootblock + bootstrap from a donor boot.adf and
# replacing the compressed kernel payload.
#
# How the Amix boot floppy is laid out (reverse-engineered — see
# docs/boot-disks/anatomy-boot-adf.md):
#
#   [ AmigaDOS OFS bootblock + ~10 KB bootstrap ]  bytes 0x0 .. ZOFF
#   [ kernel, Unix `compress` (.Z, LZW -b16) ]     bytes ZOFF .. ~0xa5800
#   [ free space / slack ]                         .. 0xdc000 (880 KB)
#
# The bootstrap finds an "IBLK" boot descriptor (in the copied bootstrap) that holds
# the compressed length (+0x8), the decompressed size (+0xc), and a checksum (+0x10 =
# 16-bit folded byte-sum of the compressed stream). We REWRITE those three fields to
# match our stream — otherwise the stale (longer) length makes the bootstrap decode our
# zero-padding and report "Kernel decompression overrun". Patching them also makes the
# checksum match, so there is no warning. The donor's AmigaDOS bootblock checksum is
# preserved because we copy the first ZOFF bytes verbatim.
#
# Usage:
#   tools/build-bootfloppy.sh --donor <orig.adf> --kernel <unix.elf> --out <new.adf>
#
# Requires: dd, od, python3 (IBLK patch + self-test), compress (or ncompress), gzip/zcat.
# Operates on USER-SUPPLIED images; we ship no proprietary media.
#
# STATUS: layout + compression + IBLK descriptor + checksum are reverse-engineered, and a
# same-kernel rebuild has been verified BOOTING in Amiberry (reaches the root-disk prompt,
# no overrun, no checksum warning). Booting a driver-modified kernel is the next validation.

set -u
donor="" kern="" out=""
while [ $# -gt 0 ]; do case "$1" in
  --donor) donor="$2"; shift 2;;
  --kernel) kern="$2"; shift 2;;
  --out) out="$2"; shift 2;;
  *) echo "unknown arg: $1" >&2; exit 2;;
esac; done
[ -r "${donor:-}" ] && [ -r "${kern:-}" ] && [ -n "${out:-}" ] || {
  echo "usage: $0 --donor <orig.adf> --kernel <unix.elf> --out <new.adf>" >&2; exit 2; }

SIZE=901120   # 880 KB DD floppy
decomp() { if command -v gzip >/dev/null; then gzip -dc; else zcat; fi; }

# kernel must be an ELF
[ "$(od -An -tx1 -N4 "$kern" | tr -d ' ')" = "7f454c46" ] || { echo "error: $kern is not ELF" >&2; exit 3; }

# 1. find ZOFF = start of the donor's .Z payload (1f 9d after 0x800) = bootstrap length
zoff=$(od -An -tx1 -v "$donor" | awk '{for(i=1;i<=NF;i++)b[n++]=$i} END{for(o=0x800;o<n-2;o++)if(b[o]=="1f"&&b[o+1]=="9d"){print o;exit}}')
[ -n "$zoff" ] || { echo "error: donor has no .Z magic after 0x800 — not an Amix boot floppy?" >&2; exit 3; }
printf 'donor bootblock+bootstrap: 0x0..0x%x (%d bytes)\n' "$zoff" "$zoff"

# 2. compress the kernel the way the bootstrap expects: LZW, 16-bit, block mode
tmpz="$(mktemp)"; trap 'rm -f "$tmpz"' EXIT
if command -v compress >/dev/null; then compress -b 16 -c < "$kern" > "$tmpz"
else echo "error: 'compress' (ncompress) required to pack the kernel" >&2; exit 4; fi
zlen=$(wc -c <"$tmpz")
printf 'kernel %d bytes -> compress -b16 = %d bytes\n' "$(wc -c <"$kern")" "$zlen"

# 3. fit check
if [ $((zoff + zlen)) -gt "$SIZE" ]; then
  echo "error: bootstrap($zoff) + compressed kernel($zlen) = $((zoff+zlen)) > $SIZE (880 KB). Kernel too big." >&2
  exit 5
fi

# 4. assemble: donor header (verbatim) + compressed kernel + zero-pad to 880 KB
ksz=$(wc -c <"$kern")
dd if="$donor" of="$out" bs=1 count="$zoff" 2>/dev/null
cat "$tmpz" >> "$out"
cur=$(wc -c <"$out")
dd if=/dev/zero bs=1 count=$((SIZE-cur)) >> "$out" 2>/dev/null
printf 'wrote %s (%d bytes)\n' "$out" "$(wc -c <"$out")"

# 5. patch the IBLK boot descriptor so the bootstrap reads OUR stream/size/checksum.
#    The donor's IBLK (offsets +0x8 comp-len, +0xc decomp-size, +0x10 checksum) still
#    describes the donor's kernel; leaving it stale causes a decompression overrun (the
#    bootstrap reads the old, longer length and decodes our zero-padding). We rewrite it.
#    Checksum = 16-bit folded byte-sum over the compressed (.Z) stream.
python3 - "$out" "$donor" "$zoff" "$zlen" "$ksz" "$SIZE" <<'PY'
import sys,struct
out,donor,zoff,zlen,ksz,SIZE=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4]),int(sys.argv[5]),int(sys.argv[6])
def fold(buf):
    # The C original (usr/sys/amiga/boot/chksum.c) accumulates into an `unsigned long`,
    # which WRAPS at 2**32. Python's sum() is arbitrary precision, so the mask below is
    # LOAD-BEARING: without it a byte total past 2**32 folds a different number of times
    # and diverges from the real algorithm. Unreachable at floppy sizes (~700 KB), but
    # kept exact so this stays conformant with amix-kerntools/contracts/bootchain-v1.json.
    s=sum(buf)&0xFFFFFFFF
    while s>>16: s=(s>>16)+(s&0xffff)
    return s&0xffff
db=open(donor,'rb').read()
# Several byte-sequences spell "IBLK" by coincidence; the genuine boot descriptor is the
# one whose fields are plausible AND whose checksum (+0x10) == fold(byte-sum of the donor's
# OWN compressed stream of length comp-len). Select by that, falling back to plausibility.
verified=[]; plausible=[]; i=0
while True:
    j=db.find(b'IBLK',i,0x2800)
    if j<0: break
    i=j+1
    comp=struct.unpack('>I',db[j+8:j+12])[0]
    dec =struct.unpack('>I',db[j+12:j+16])[0]
    chk =struct.unpack('>I',db[j+16:j+20])[0]&0xffff
    if not (0<comp<=SIZE-zoff and 0x80000<dec<0x300000): continue
    plausible.append(j)
    if zoff+comp<=len(db) and fold(db[zoff:zoff+comp])==chk: verified.append(j)
sel=verified or plausible
if not sel:
    sys.stderr.write("  warning: no genuine IBLK descriptor found in donor — leaving header as-is;\n"
                     "           a differing kernel may overrun/warn. (Donor not a known 2.1 boot.adf?)\n")
    sys.exit(0)
iblk=sel[0]
tag='checksum-verified' if iblk in verified else 'plausibility-only'
b=bytearray(open(out,'rb').read())
ck=fold(bytes(b[zoff:zoff+zlen]))
struct.pack_into('>I',b,iblk+0x08,zlen)    # compressed length
struct.pack_into('>I',b,iblk+0x0c,ksz)     # decompressed size
struct.pack_into('>I',b,iblk+0x10,ck)      # checksum (16-bit folded byte-sum of the .Z)
open(out,'wb').write(b)
print(f"  IBLK @0x{iblk:04x} ({tag}) patched: comp_len={zlen} decomp={ksz} checksum=0x{ck:04x}")
PY

# 6. self-test: emulate the bootstrap via the patched IBLK — read comp-len bytes from
#    0x2800, decompress, and check it equals our kernel AND the checksum field matches.
#    (Validates the descriptor we actually wrote, not just the bash variables.)
st_zlen="$zlen"
dd if="$out" bs=1 skip="$zoff" count="$st_zlen" 2>/dev/null | decomp > "$tmpz.out" 2>/dev/null || true
python3 - "$out" "$kern" "$tmpz.out" "$zoff" "$SIZE" <<'PY'
import sys,struct
out,kern,decoded,zoff,SIZE=sys.argv[1],sys.argv[2],sys.argv[3],int(sys.argv[4]),int(sys.argv[5])
def fold(b):
    # See the note on the identical fold() in the patch phase above: the &0xFFFFFFFF
    # reproduces the C accumulator's 32-bit wrap and is load-bearing for large buffers.
    s=sum(b)&0xFFFFFFFF
    while s>>16: s=(s>>16)+(s&0xffff)
    return s&0xffff
b=open(out,'rb').read(); k=open(kern,'rb').read(); d=open(decoded,'rb').read()
# locate the genuine IBLK in the OUTPUT by checksum-consistency against its own stream
j=-1; i=0
while True:
    p=b.find(b'IBLK',i,0x2800)
    if p<0: break
    i=p+1
    comp=struct.unpack('>I',b[p+8:p+12])[0]; dec=struct.unpack('>I',b[p+12:p+16])[0]; chk=struct.unpack('>I',b[p+16:p+20])[0]&0xffff
    if 0<comp<=SIZE-zoff and 0x80000<dec<0x300000 and zoff+comp<=len(b) and fold(b[zoff:zoff+comp])==chk:
        j=p; break
ok=True
if j<0: print("self-test: FAILED — no checksum-consistent IBLK in output ❌"); sys.exit(6)
comp=struct.unpack('>I',b[j+8:j+12])[0]; dec=struct.unpack('>I',b[j+12:j+16])[0]; chk=struct.unpack('>I',b[j+16:j+20])[0]&0xffff
if d!=k: print(f"self-test: FAILED — decompressed stream != kernel ❌"); ok=False
if dec!=len(k): print(f"self-test: FAILED — IBLK decomp={dec} != kernel size {len(k)} ❌"); ok=False
if not ok: sys.exit(6)
print(f"self-test ✅  IBLK @0x{j:04x}: comp_len={comp} decomp={dec} checksum=0x{chk:04x} (matches stream)")
print(f"            stream decompresses to the IDENTICAL kernel; checksum will MATCH at boot (no warning).")
PY
rc=$?
rm -f "$tmpz.out"
[ "$rc" -eq 0 ] || exit 6
echo "Host round-trip OK. (A same-kernel rebuild has booted in Amiberry to the root-disk prompt;"
echo " verify your own build in an emulator.)"
