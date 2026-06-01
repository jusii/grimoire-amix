#!/usr/bin/env bash
#
# extract-kernel.sh — pull the kernel out of an Amix boot floppy (boot.adf).
#
# The Amix boot floppy stores its kernel as a standard Unix `compress` (.Z, LZW)
# stream located just after the ~10 KB bootstrap. This tool finds that stream,
# decompresses it, and truncates the result to the real ELF size — giving you the
# m68k ELF kernel image. (Reverse-engineered; see docs/boot-disks/anatomy-boot-adf.md.)
#
# Usage:   tools/extract-kernel.sh <boot.adf> [out.elf]
# Default out: <boot.adf-basename>.unix.elf  in the same dir as the input.
#
# Requires: dd, od (GNU), and one of: gzip / zcat / uncompress.  Read-only on input.

set -u
img="${1:-}"
[ -z "$img" ] || [ ! -r "$img" ] && { echo "usage: $0 <boot.adf> [out.elf]" >&2; exit 2; }
out="${2:-${img%.adf}.unix.elf}"

decomp() { if command -v gzip >/dev/null; then gzip -dc; elif command -v zcat >/dev/null; then zcat; else uncompress -c; fi; }

# 1. locate the compress (.Z) stream: first 0x1f 0x9d after the bootstrap (>=0x800).
#    grep -b on a byte pattern is awkward; scan with od+awk over a window.
zoff=$(od -An -tx1 -v "$img" | awk '
  { for(i=1;i<=NF;i++){ b[n++]=$i } }
  END{
    for(o=0x800;o<n-2;o++){
      if(b[o]=="1f" && b[o+1]=="9d"){ printf "%d\n", o; exit }
    }
  }')
if [ -z "$zoff" ]; then echo "error: no compress(.Z) magic (1f 9d) found after 0x800 — not an Amix boot floppy?" >&2; exit 3; fi
printf 'compressed kernel (.Z) found at offset 0x%x\n' "$zoff"

# 2. decompress from there to EOF (will error on trailing free-space bytes; that's fine).
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
dd if="$img" bs=1 skip="$zoff" 2>/dev/null | decomp > "$tmp" 2>/dev/null || true

# 3. sanity: ELF magic?
magic=$(od -An -tx1 -N4 "$tmp" | tr -d ' ')
if [ "$magic" != "7f454c46" ]; then echo "error: decompressed data is not ELF (got $magic)" >&2; exit 4; fi

# 4. truncate to the true ELF size = e_shoff + e_shnum*e_shentsize (ELF32 BE).
shoff=$(od -An -tu4 -j32 -N4 --endian=big "$tmp" | tr -d ' ')
shent=$(od -An -tu2 -j46 -N2 --endian=big "$tmp" | tr -d ' ')
shnum=$(od -An -tu2 -j48 -N2 --endian=big "$tmp" | tr -d ' ')
size=$(( shoff + shnum*shent ))
rawsz=$(wc -c <"$tmp")
if [ "$size" -le 0 ] || [ "$size" -gt "$rawsz" ]; then size="$rawsz"; fi
dd if="$tmp" of="$out" bs=1 count="$size" 2>/dev/null

echo "wrote $out"
printf '  ELF: 32-bit MSB m68k; size %d bytes (0x%x)  [e_shoff=0x%x e_shnum=%d]\n' "$size" "$size" "$shoff" "$shnum"
command -v file >/dev/null && file "$out" | sed 's/^/  /'
