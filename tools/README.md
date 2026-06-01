# tools/

Reproducible tooling for inspecting and building Amiga Unix (Amix) floppy images. All scripts operate
on **user-supplied** images (we don't redistribute Commodore's proprietary media — see
[`../sources/NOTES.md`](../sources/NOTES.md)). Dependencies: [`requirements.md`](requirements.md).

| Script | What it does | Status |
|---|---|---|
| [`inspect-adf.sh`](inspect-adf.sh) | Classify an `.adf` (boot / root / patch) and dump its structure: bootblock, embedded ELF/cpio/tar, install-script and kernel strings. | ✅ works & tested on the real 2.1 disks |
| [`unpack-root.sh`](unpack-root.sh) | Best-effort carve of a root/miniroot disk: extracts tar members, reports ELF offsets, dumps installer script text. | ✅ works (carve, not full UFS tree) |
| [`build-custom-bootdisk.sh`](build-custom-bootdisk.sh) | Build a **self-extracting add-on/driver disk** (1 KB `/sbin/sh` header + cpio payload), modeled on the real Amix patch disk. | 🟡 structure validated; **untested on real Amix** |
| [`gen-llms-full.sh`](gen-llms-full.sh) | Concatenate all docs (reading order) into `../llms-full.txt` for LLM ingestion. | ✅ works |

## Quick start

```sh
# Identify and dissect any Amix floppy:
tools/inspect-adf.sh path/to/amix_2.1_boot.adf

# Study the installer on the root disk:
tools/unpack-root.sh path/to/amix_2.1_root.adf      # output in tools/_work/ (gitignored)

# Build a self-extracting driver add-on disk from a payload directory:
tools/build-custom-bootdisk.sh --payload mydriver/ --out addon.adf --install var/addon/install
```

## What these tools deliberately do NOT do

Regenerating the **compressed, checksummed Amix boot floppy** (`boot.adf`) is **not yet solved** (🔴) —
that bootstrap/kernel container format is not fully reverse-engineered. For shipping new drivers today,
the supported path is to relink the driver into the on-disk **boot partition** with `make bootpart`
(see [`../docs/drivers/kernel-build.md`](../docs/drivers/kernel-build.md)), and/or distribute a
self-extracting add-on disk built with `build-custom-bootdisk.sh`. Background and the open
reverse-engineering problems are in
[`../docs/boot-disks/adding-drivers-to-boot-disk.md`](../docs/boot-disks/adding-drivers-to-boot-disk.md).
