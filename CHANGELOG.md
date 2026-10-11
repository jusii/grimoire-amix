# Changelog

Started 2026-09-26; entries are written after the owner's review.

## 2026-10-11 — quirks 71; station notes local-only (0d766a2, b77b04a)

boot-process, quirks 71: fssm_Device's BSTR length counts the NUL. The station notes file is untracked and ignored
with .claude/ (owner rule 2026-10-10).

## 2026-10-05 — 040/060, Z3660, A4092, quirks 58-70, the content review

One entry for the work of 2026-09-14 to 2026-10-04.

- Licensing wording follows the 2026-09-23 outcome (Amiga Corporation's approval; the release restriction is
  lifted); README carries the amigaux.org trademark disclaimer. Media are still never committed here.
- Package repository: pkg.amigaux.org is canonical; the two publish gates, names.conf, the regenerate trap.
- 68040/68060 status rewritten for the public port asokero/amix-040-060-port: what it is, how it builds, what
  works, 060-direct versus the Z3660 software-030 route, 128 MB on metal. "No 68040/68060, no A4000" is
  qualified as a stock-kernel limit. Amix 2.1c boots to login on a real 68LC060.
- RAM: the envelope is 16-64 MB on the stock 030 line and 128 MB on the 040/060 kernels; no page states a 16 MB
  ceiling. Zorro III lies outside the stock identity map; a driver that maps its board with sptalloc() reaches it.
- Toolchain: the stock on-box compiler is GNU GCC 1.40.5; the GCC 2.7.2.3 package claim is withdrawn.
- Quirks 58-61: the telnet run-level stall in stock init, stock Z3660 firmware and the warm reset, the Z3660
  isoN slot = SCSI target rule, the VPOSR AGA test. Battery clock: stock sysinit runs setclk and date rejects
  its year; Y2K is a setclk bug.
- Quirks 66-70: undecoded local-I/O reads under the Z3660, kickstart 0 on the Z3660 real 060, the .d6
  reset-vector rule, the 040/060 kernel's disk write stream, stock installf on a 68060 kernel (use APKG).
- A4092: the autocon signed-shift bug, Zorro III DMA into Z3660 RAM, 68LC060. Boot process: boot priority picks
  the loader, rootdev picks the root. Kernel build: verify /stand/unix after an install.
- X11/RTG: the Z3660 hard-mapped RTG window; the Z3660 RTG target shares zz9000's major 49 by design.
- Content review: Amix and platform facts only; example addresses per RFC 5737; one Sources convention;
  broken anchors fixed; llms-full regenerated.
