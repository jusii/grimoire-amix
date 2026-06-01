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
# The bootstrap LZW-decompresses the kernel and verifies a 16-bit folded checksum.
# A mismatch is NON-FATAL: it prints "WARNING! Kernel file checksum mismatch." and
# boots anyway. So a custom kernel boots even without recomputing the checksum
# (you just see that warning). The donor's bootblock checksum is preserved because
# we copy the first ZOFF bytes verbatim.
#
# Usage:
#   tools/build-bootfloppy.sh --donor <orig.adf> --kernel <unix.elf> --out <new.adf>
#
# Requires: dd, od, compress (or ncompress), and gzip/zcat (for the self-test).
# Operates on USER-SUPPLIED images; we ship no proprietary media.
#
# STATUS: layout + compression + non-fatal-checksum are verified by analysis and a
# host-side round-trip self-test. NOT yet booted on real Amix — verify in WinUAE/FS-UAE. 🟡

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
dd if="$donor" of="$out" bs=1 count="$zoff" 2>/dev/null
cat "$tmpz" >> "$out"
cur=$(wc -c <"$out")
dd if=/dev/zero bs=1 count=$((SIZE-cur)) >> "$out" 2>/dev/null
printf 'wrote %s (%d bytes)\n' "$out" "$(wc -c <"$out")"

# 5. self-test: does our floppy decompress back to the EXACT kernel we put in?
dd if="$out" bs=1 skip="$zoff" 2>/dev/null | decomp > "$tmpz.out" 2>/dev/null || true
# truncate to kernel size for compare
ksz=$(wc -c <"$kern")
dd if="$tmpz.out" of="$tmpz.cmp" bs=1 count="$ksz" 2>/dev/null
if cmp -s "$kern" "$tmpz.cmp"; then
  echo "self-test: floppy decompresses to the IDENTICAL kernel ✅"
else
  echo "self-test: FAILED — decompressed kernel differs ❌" >&2; rm -f "$tmpz.out" "$tmpz.cmp"; exit 6
fi
rm -f "$tmpz.out" "$tmpz.cmp"
echo "🟡 Untested on real Amix — boot it in WinUAE/FS-UAE. If the kernel differs from the donor's,"
echo "   expect a harmless 'WARNING! Kernel file checksum mismatch.' at boot (non-fatal)."
