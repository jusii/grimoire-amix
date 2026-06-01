#!/usr/bin/env bash
#
# unpack-root.sh — best-effort extraction of an Amix root/miniroot floppy
# (amix_*_root.adf). The body is an SVR4 big-endian UFS filesystem holding the
# installer (m68k ELF binaries) and install shell scripts.
#
# Full UFS tree traversal needs a UFS-aware reader; Linux's in-tree `ufs` driver
# generally CANNOT mount Amix's SVR4/m68k big-endian UFS. So this script does a
# pragmatic carve instead: it locates and extracts the embedded objects
# (POSIX tar members, and reports ELF/script offsets) and dumps the install
# scripts' text, which is what you usually want when studying the installer.
#
# Output goes to tools/_work/<image-basename>/ (gitignored). Read-only on input.
#
# Usage: tools/unpack-root.sh <root.adf>
#
# Requires: binwalk, dd, strings. Optional: tar (to unpack carved tar members).

set -u
img="${1:-}"
if [ -z "$img" ] || [ ! -r "$img" ]; then
  echo "usage: $0 <root.adf>" >&2
  exit 2
fi
command -v binwalk >/dev/null 2>&1 || { echo "error: binwalk required" >&2; exit 3; }

here="$(cd "$(dirname "$0")/.." && pwd)"
base="$(basename "$img")"
work="$here/tools/_work/${base%.adf}"
mkdir -p "$work"

echo "== unpack-root: $img -> $work =="

# Sanity: is this really a root/miniroot disk?
if ! strings -n 6 "$img" 2>/dev/null | grep -q 'lost+found'; then
  echo "warning: no UFS 'lost+found' fingerprint found — is this a root disk?" >&2
fi

echo "-- scanning for embedded objects (binwalk) --"
scan="$work/binwalk.txt"
binwalk "$img" 2>/dev/null | tee "$scan" | sed 's/^/    /' | head -40
echo "    ... (full scan in $scan)"

# Carve POSIX tar members: dd from each reported offset to EOF, then let tar
# extract what it can (it stops at the archive's own end-of-archive marker).
echo "-- carving POSIX tar member(s) --"
tar_offsets=$(awk '/POSIX tar archive/ {print $1}' "$scan")
i=0
for off in $tar_offsets; do
  i=$((i + 1))
  carve="$work/tar_${i}_at_${off}.tar"
  dd if="$img" of="$carve" bs=1 skip="$off" 2>/dev/null
  echo "    carved $carve (from offset $off)"
  if command -v tar >/dev/null 2>&1; then
    dest="$work/tar_${i}"
    mkdir -p "$dest"
    if tar -xf "$carve" -C "$dest" 2>/dev/null; then
      echo "      extracted -> $dest"
      find "$dest" -maxdepth 2 -type f | sed 's/^/        /' | head -20
    else
      echo "      (tar could not fully extract — carved bytes kept for manual inspection)"
    fi
  fi
done
[ "$i" -eq 0 ] && echo "    (no tar members reported)"

# Dump the installer / shell-script text, which is the high-value content.
echo "-- installer script text (high-value strings) --"
strings -n 8 "$img" 2>/dev/null > "$work/strings.txt"
grep -nE '#!/(bin|sbin)/sh|/dev/rmt|/dev/dsk|amixpkg|BOOTSIZE|SWAPPART|mkfs|fsck|ufs|viper_kludge|partition' \
  "$work/strings.txt" | sed 's/^/    /' | head -40
echo "    ... (full strings dump in $work/strings.txt)"

echo
echo "note: ELF installer binaries are present but left in place; their offsets are"
echo "      in $scan (search for 'Motorola 68020'). For a true UFS file tree, use a"
echo "      UFS-aware tool (e.g. a *BSD host, or UFS Explorer) on a copy of the image."
echo "done."
