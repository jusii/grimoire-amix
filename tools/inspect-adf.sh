#!/usr/bin/env bash
#
# inspect-adf.sh — identify and structurally inspect an Amiga Unix (Amix) floppy
# image (.adf). Works on the three install-set disk types:
#
#   * boot  disk  — bootable AmigaDOS bootblock + Amix secondary bootstrap
#                   that loads & decompresses a kernel (NO AmigaDOS filesystem)
#   * root  disk  — a UFS "miniroot" holding the installer (m68k ELF) + scripts
#   * patch disk  — a self-extracting hybrid: ~1 KB /sbin/sh header + cpio archive
#
# It is read-only: it never modifies the image. It prefers `binwalk` and
# `xdftool` (amitools) when present and degrades gracefully to `xxd`/`strings`.
#
# Usage:   tools/inspect-adf.sh <image.adf>
# Example: tools/inspect-adf.sh sources/floppy/amix_21_boot.adf
#
# Exit status: 0 on success, 2 on usage error, 3 if the file is unreadable.

set -u

img="${1:-}"
if [ -z "$img" ]; then
	echo "usage: $0 <image.adf>" >&2
	exit 2
fi
if [ ! -r "$img" ]; then
	echo "error: cannot read '$img'" >&2
	exit 3
fi

have() { command -v "$1" >/dev/null 2>&1; }
rule() { printf '%s\n' "------------------------------------------------------------------------"; }

size=$(wc -c <"$img" | tr -d ' ')
echo "== Amix ADF inspector =="
echo "file : $img"
echo "size : $size bytes"
if [ "$size" -eq 901120 ]; then
	echo "       (901120 = standard 880 KB Amiga DD floppy)"
fi
if have sha256sum; then
	echo "sha256: $(sha256sum "$img" | cut -d' ' -f1)"
fi
rule

# --- Read the first 12 bytes as hex to detect the disk type ----------------
# bootblock starts with "DOS" + flag byte; a cpio "newc" header starts 070701;
# a shell script starts with "#!".
head_hex=$(dd if="$img" bs=1 count=12 2>/dev/null | xxd -p | tr -d '\n')

kind="unknown"
case "$head_hex" in
	444f53*) kind="boot" ;;   # 'DOS'  -> AmigaDOS bootblock (Amix bootstrap)
	2321*)   kind="patch" ;;  # '#!'   -> shell-script header (self-extracting patch disk)
esac

# A root/miniroot disk often begins with a zeroed boot area; confirm by looking
# for a UFS fingerprint (lost+found dir entry + fsck strings) further in.
if [ "$kind" = "unknown" ]; then
	if strings -n 6 "$img" 2>/dev/null | grep -q 'lost+found'; then
		kind="root"
	fi
fi

echo "detected disk type : $kind"
case "$kind" in
	boot)  echo "  -> bootable AmigaDOS bootblock; expect a compressed kernel payload, no AmigaDOS FS" ;;
	root)  echo "  -> UFS miniroot; expect m68k ELF installer binaries + install shell scripts" ;;
	patch) echo "  -> self-extracting patch disk; expect /sbin/sh header + embedded cpio archive" ;;
	*)     echo "  -> could not classify; see raw analysis below" ;;
esac
rule

# --- Bootblock detail (boot disks) -----------------------------------------
if [ "$kind" = "boot" ]; then
	echo "[bootblock] first 64 bytes:"
	dd if="$img" bs=1 count=64 2>/dev/null | xxd
	echo
	echo "[bootblock] DOS type id: ${head_hex:0:8} (expect 444f5300 = 'DOS\\0', OFS bootblock)"
	echo "[boot] kernel/bootstrap strings of interest:"
	strings -n 6 "$img" 2>/dev/null \
		| grep -iE 'kernel|boot|decompress|checksum|corrupt|unix|volume|RPC' \
		| sort -u | sed 's/^/    /' | head -20
	rule
fi

# --- AmigaDOS filesystem listing (only meaningful if a real ADOS FS exists) -
if have xdftool; then
	echo "[xdftool] attempting AmigaDOS directory listing (expected to fail for boot/root):"
	xdftool "$img" list 2>&1 | sed 's/^/    /' | head -20
	rule
fi

# --- Embedded objects (ELF / cpio / tar / gzip) ----------------------------
if have binwalk; then
	echo "[binwalk] embedded object signatures (first 30):"
	binwalk "$img" 2>/dev/null | sed 's/^/    /' | head -34
else
	echo "[binwalk not installed] grepping for ELF magic + cpio headers manually:"
	echo "    ELF '7f454c46' offsets:"
	xxd -p "$img" | tr -d '\n' | grep -ob '7f454c46' | head | sed 's/^/      /' || true
fi
rule

# --- Patch-disk specifics: show the bootstrap script + cpio member names -----
if [ "$kind" = "patch" ]; then
	echo "[patch] leading /sbin/sh bootstrap (first ~1 KB):"
	dd if="$img" bs=1 count=1024 2>/dev/null | strings -n 4 | sed 's/^/    /' | head -40
	echo
	echo "[patch] cpio member names (newc/ASCII 070701 archive):"
	# cpio 'newc' filenames follow the 110-byte ASCII header; grep readable paths.
	strings -n 4 "$img" 2>/dev/null | grep -E '^(var|usr|etc|opt|sbin|bin)/' | sort -u | sed 's/^/    /' | head -40
	rule
fi

# --- Root/miniroot specifics: installer scripts + tape pipeline -------------
if [ "$kind" = "root" ]; then
	echo "[root] installer / tape pipeline strings:"
	strings -n 8 "$img" 2>/dev/null \
		| grep -iE '/dev/rmt|cpio|amixpkg|BOOTSIZE|SWAPPART|/dev/dsk|mkfs|fsck|ufs|viper' \
		| sort -u | sed 's/^/    /' | head -30
	rule
fi

echo "done."
