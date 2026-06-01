# sources/ — provenance & licensing

This directory holds the **primary materials** the documentation is built from, plus our synthesized
research. The binary primary materials are **kept local and never committed** (see `../.gitignore`);
we commit checksums + this provenance note instead.

## What's here

| Path | Committed? | Notes |
|---|---|---|
| `research-brief.md` | ✅ yes | Our own synthesis (facts + citations + confidence tags). The grounding source of truth for `docs/`. Facts aren't copyrightable; this is original analysis. |
| `CHECKSUMS.txt` | ✅ yes | SHA-256 of the local primary artifacts, so anyone with their own copies can verify they match. |
| `NOTES.md` | ✅ yes | This file. |
| `floppy/*.adf` | ❌ no (gitignored) | The real Amix 2.1 boot / root / patch floppies. Proprietary Commodore media. |
| `pdf/*.pdf` | ❌ no (gitignored) | Michael Ditto, *Writing Amix Device Drivers*, 1990 European Amiga Developer's Conference. Conference handout. |

## Licensing / redistribution

The Amix operating system, its install media (the ADFs, tape images, HDFs), and the scanned Commodore
manuals are **proprietary Commodore-Amiga material**. They are widely treated as *abandonware* and are
mirrored at amigaunix.com and the Internet Archive, but they are **not licensed for redistribution**.
Accordingly:

- We do **not** redistribute these files in this repo.
- We **cite, link, and analyze** them, and quote short excerpts (string fingerprints, script
  snippets) for documentation and interoperability.
- All tooling in `../tools/` operates on **user-supplied** images.

Where to obtain the media yourself:

- **amigaunix.com → Downloads**: <https://www.amigaunix.com/doku.php/downloads>
- **Internet Archive**: <https://archive.org/details/commodore-amiga-operating-systems-amix>
- **Manuals (Using / Learning / Installing Amiga UNIX)**: archive.org (search "Amiga UNIX System V Release 4").

After downloading, verify against `CHECKSUMS.txt` (filenames may differ — e.g. `amix_2.1_boot.adf`
vs our `amix_21_boot.adf`; match by hash, not name).

## Citing the Ditto paper

Cite as: **Michael Ditto, "Writing Amix Device Drivers," 1990 European Amiga Developer's Conference,
Commodore-Amiga, Inc.** (The page headers say "European"; the filename's "North American DevCon" is
inaccurate.) The PDF is 44 pages but pp. 23–44 are a duplicate scan of pp. 1–22 — there are **22
unique pages**; p.22 is the `par(7A)` man page.
