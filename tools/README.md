# tools/

Reproducible tooling for inspecting and building Amiga Unix (Amix) floppy images. All scripts operate
on **user-supplied** images (we don't redistribute Commodore's proprietary media — see
[`../sources/NOTES.md`](../sources/NOTES.md)). Dependencies: [`requirements.md`](requirements.md).

| Script | What it does | Status |
|---|---|---|
| [`inspect-adf.sh`](inspect-adf.sh) | Classify an `.adf` (boot / root / patch) and dump its structure: bootblock, embedded ELF/cpio/tar, install-script and kernel strings. | ✅ works & tested on the real 2.1 disks |
| [`extract-kernel.sh`](extract-kernel.sh) | Decompress the kernel out of a `boot.adf` (Unix `compress`/LZW at `0x2800`) → m68k ELF, trimmed via the ELF header. | ✅ works & verified |
| [`build-bootfloppy.sh`](build-bootfloppy.sh) | Build a **bootable** `boot.adf` from a donor bootstrap + your kernel ELF (`compress -b16`); self-tests the round-trip. | ✅ host round-trip verified; 🟡 **not yet booted on real Amix** |
| [`unpack-root.sh`](unpack-root.sh) | Best-effort carve of a root/miniroot disk: extracts tar members, reports ELF offsets, dumps installer script text. | ✅ works (carve, not full UFS tree) |
| [`build-custom-bootdisk.sh`](build-custom-bootdisk.sh) | Build a **self-extracting add-on/driver disk** (1 KB `/sbin/sh` header + cpio payload), modeled on the real Amix patch disk. | 🟡 structure validated; **untested on real Amix** |
| [`gen-llms-full.sh`](gen-llms-full.sh) | Concatenate all docs (reading order) into `../llms-full.txt` for LLM ingestion. | ✅ works |

## Quick start

```sh
# Identify and dissect any Amix floppy:
tools/inspect-adf.sh path/to/amix_2.1_boot.adf

# Extract the kernel from a boot floppy (-> m68k ELF):
tools/extract-kernel.sh path/to/amix_2.1_boot.adf unix.elf

# Rebuild a bootable floppy carrying your own kernel (verify in an emulator):
tools/build-bootfloppy.sh --donor path/to/amix_2.1_boot.adf --kernel unix.elf --out custom_boot.adf

# Study the installer on the root disk:
tools/unpack-root.sh path/to/amix_2.1_root.adf      # output in tools/_work/ (gitignored)

# Build a self-extracting driver add-on disk from a payload directory:
tools/build-custom-bootdisk.sh --payload mydriver/ --out addon.adf --install var/addon/install
```

## Status & caveats

The `boot.adf` format is **reverse-engineered** (Unix `compress`/LZW kernel → m68k ELF; non-fatal
16-bit checksum — see [`../docs/boot-disks/reverse-engineering-boot-adf.md`](../docs/boot-disks/reverse-engineering-boot-adf.md)).
`extract-kernel.sh` and `build-bootfloppy.sh` round-trip correctly **on the host**, but a rebuilt floppy
has **not yet been booted on real Amix** (🟡) — verify in WinUAE/FS-UAE before relying on it. A custom
kernel boots with a cosmetic checksum warning (the exact checksum range/expected-location isn't pinned).
For an installed system, the simplest path remains relinking into the on-disk **boot partition** with
`make bootpart` ([`../docs/drivers/kernel-build.md`](../docs/drivers/kernel-build.md)). Decision tree
across all three delivery surfaces:
[`../docs/boot-disks/adding-drivers-to-boot-disk.md`](../docs/boot-disks/adding-drivers-to-boot-disk.md).
