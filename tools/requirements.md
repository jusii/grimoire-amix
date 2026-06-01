# tools/ — requirements

The scripts in `tools/` are POSIX `bash` and lean on a few common utilities. They are **read-only on
input** (except `build-custom-bootdisk.sh`, which writes a new image) and never modify the source ADFs.

| Tool | Required | Optional |
|---|---|---|
| `inspect-adf.sh` | `bash`, `dd`, `xxd`, `strings` | `binwalk` (embedded-object scan), `xdftool` (amitools; AmigaDOS listing), `sha256sum` |
| `extract-kernel.sh` | `bash`, `dd`, `od` (GNU), and one of `gzip`/`zcat`/`uncompress` | `file` (identify the ELF) |
| `build-bootfloppy.sh` | `bash`, `dd`, `od` (GNU), `python3` (IBLK patch + self-test), `compress` (or `ncompress`), and `gzip`/`zcat` | — |
| `unpack-root.sh` | `bash`, `binwalk`, `dd`, `strings` | `tar` (unpack carved members) |
| `build-custom-bootdisk.sh` | `bash`, `dd`, `printf`, and **`cpio`** *or* `bsdtar` | `cpio` (to list members in the self-test) |
| `gen-llms-full.sh` | `bash`, `cat`, `wc` | — |

## Installing the dependencies

- **Debian/Ubuntu:** `sudo apt install binwalk cpio libarchive-tools coreutils ncompress gzip`
  (`libarchive-tools` provides `bsdtar`; `xxd` ships with `vim-common`/`xxd`; `ncompress` provides
  `compress`/`uncompress`; `gzip`/`zcat` decode `.Z` too.)
- **amitools / `xdftool`** (Amiga disk handling): `pipx install amitools` or `pip install amitools`.
  Used only for the AmigaDOS bootblock/listing path; everything else degrades gracefully without it.

## Notes

- These tools operate on **user-supplied** Amix images. We do not ship the proprietary ADFs — see
  [`../sources/NOTES.md`](../sources/NOTES.md) for where to obtain them and how to verify checksums.
- True UFS file-tree extraction from a root/miniroot disk is **not** done here (Linux's `ufs` driver
  generally can't read Amix's SVR4 big-endian UFS). `unpack-root.sh` carves embedded objects and
  dumps script text instead; for a full tree use a *BSD host or a UFS-aware tool.
