---
title: The Amix Package Repository Format
summary: How the Amix package repository is laid out, served and consumed — the canonical public host pkg.amigaux.org, the static tree, the pipe-delimited catalog v1 grammar and names.conf, the md5 integrity model, the apkg client's three sources (HTTP / mounted medium / raw slice), and the publish gates (the owner's hand, the payload-licence gate, the kernel-package gate) plus the catalog-regenerate trap.
status: draft
---

# The Amix Package Repository Format

An Amix package repository is a **plain static file tree**: one `catalog` text file plus a `pkgs/`
directory of ordinary SVR4 datastream packages ✅. There is no server-side software, no database and
no dynamic index — publishing is an `rsync`, and serving it needs nothing more than a stock web
server. That is deliberate: the client is a small C89 program running on a 1992 SVR4 box, and the
simplest thing that can possibly work is the thing that keeps working.

This page documents the **format and the contract** — the tree, the catalog grammar, the integrity
model, what the client does with them, and the gates on the publish path. For the *local* package
database that `pkgadd` maintains on the installed system (`/var/sadm`, `contents(4)`, and the
stock-image defect that breaks `pkgrm`), see [package management](package-management.md). For
building packages in the first place, see [toolchain and packaging](../drivers/toolchain.md).

> **Licensing note (updated 2026-09-23).** The format is open. The Amix distribution packages are
> Commodore material; since 2026-09-23 the Amix release restriction is lifted (Amiga Corporation's
> approval, the project owner's ruling — see [`AGENTS.md` §5](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md#5-respect-the-licensing-boundary)), so repackaged
> stock packages may be served publicly. The publish tooling still enforces its own refusals
> (below); everything else is on the operator.

## The public repository: `pkg.amigaux.org` ✅

**`http://pkg.amigaux.org/` is the canonical Amix package repository**, live since **2026-09-14** ✅.

- **Plain HTTP on port 80, no redirect — permanently.** `apkg` speaks HTTP/1.0 over the 1992 SVR4
  sockets with no TLS (see [HTTP specifics](#http-specifics)), so the repo URL is `http://` for good;
  an HTTPS twin serves the same tree to browsers ✅.
- **The hostname is the only supported form.** The host is name-based virtual hosting: a request
  whose `Host:` header carries the bare IP gets a 404. A box with no working DNS
  resolves the name through one `/etc/inet/hosts` line mapping `pkg.amigaux.org` to the host's
  address, and `apkg` still sends the *name* in `Host:` ✅.
- **The client's compiled-in default** (no `repo=` in `/etc/apkg.conf`) is
  `http://pkg.amigaux.org` in the client source since 2026-09-14 ✅.
- **Contents (2026-09-26):** **39 catalog entries — the 27 stock Amix 2.1 packages plus 12 of the
  project's own** (the `apkg` client and its engine, `cdfs`, the first batch of six cross-built
  tool packages, `amix-benchmark`, and two `test` fixtures) ✅.

## Repository layout

Uniformly ✅ (repo source + reproduced locally against a real staging tree).

```text
<repo>/
├── catalog                    the index (see below)
├── catalog.md5                `md5sum`-format checksum line for `catalog`
└── pkgs/
    ├── base/                  packages we build ourselves
    │   ├── APKG-0.1.pkg
    │   └── APKGENG-1.12.0.pkg
    ├── stock/                 repackaged Amix 2.1 distribution packages
    │   ├── core-2.1.pkg
    │   └── net-2.1.pkg
    └── test/                  fixtures for end-to-end client tests
        └── DEMOLIB-1.0.pkg
```

Two rules make this work:

- **The `pkgs/` segment is part of the URL, not part of the catalog.** A catalog `filename` of
  `stock/net-2.1.pkg` is served from `<repo>/pkgs/stock/net-2.1.pkg` ✅. A hand-rolled probe that
  drops the `pkgs/` segment gets a 404 and mis-reads it as "the payloads were never published" — the
  client builds the correct URL, so only manual host-side checks fall into this trap. Verify against
  the client's own catalog, not a guessed path. (Also noted in the
  [command cheat sheet](../reference/commands-cheatsheet.md).)
- **The subdirectories are pure metadata.** `base/`, `stock/`, `test/` carry no meaning to the
  client; they exist because the `filename` field records a relative path, so the tree can be
  reorganised by regenerating the catalog ✅.

**Package basenames must be unique repository-wide** ✅ — the URL uses the full relative path but
the client's on-box cache is **flat** and keys on the basename. `name-version.pkg` naming makes this
true for free.

## The catalog

### Grammar (catalog format v1)

A UTF-8-clean ASCII text file. First line is the version banner; `#` lines are comments; one package
per line, **pipe-delimited**, no pipes in any field ✅:

```text
#apkg-catalog 1
name|version|pkginst|filename|md5|size|deps|category|description[|offset]
```

| # | Field | Meaning | Notes |
|---|---|---|---|
| 1 | `name` | Catalog name — what a user types | Lowercased `PKG` by default; overridable per package in [`names.conf`](#catalog-name-versus-pkginst-namesconf) |
| 2 | `version` | Catalog version string | Compared segment-wise (below) |
| 3 | `pkginst` | The SVR4 `PKG` instance name | **≤ 9 characters** — stock `pkgadd` silently drops longer ones ✅ |
| 4 | `filename` | Path under `pkgs/`, forward slashes | May contain `/`; validated (below) |
| 5 | `md5` | 32 hex digits, of the file **as transported** | i.e. of the `.Z` file when compressed |
| 6 | `size` | Byte size of the same file | Second integrity check |
| 7 | `deps` | Comma-separated catalog `name`s, or `none` | Resolved recursively |
| 8 | `category` | Free text (`system`, `application`, `test`, …) | Informational |
| 9 | `description` | Free text; the only field where spaces are idiomatic | Searched by the client |
| 10 | `offset` | **Optional.** Decimal byte offset into a raw slice | Only the raw-medium source uses it; a 9-field line leaves it unset and the raw source fails closed on that entry |

Real rows (from the reference staging tree) ✅:

```text
#apkg-catalog 1
apkg|0.1|APKG|base/APKG-0.1.pkg|ea72218a454ae57700d254b16e1540b8|115200|apkgeng|application|Remote package client: update/list/search/install over HTTP
apkgeng|1.12.0|APKGENG|base/APKGENG-1.12.0.pkg|fb2f08f46c6921e979e265c36cece000|2436608|none|application|Heirloom SVR4 pkg tools: tolerant contents parser, removef/pkgask, man pages
```

### Catalog name versus pkginst: `names.conf` ✅

The catalog carries **two** names per package: field 1, the catalog `name` a user types, and field
3, the SVR4 `pkginst` the engine hands to `pkgadd`/`pkgrm` and records under `/var/sadm`. By default
the catalog name is the pkginst lowercased (`PKG=APKG` → `apkg`). When the two must differ, the
override is an authored host-side file, **`names.conf`**, one mapping per line:

```text
# <PKGINST>: <catalog-name>
amixbench: amix-benchmark
```

It is keyed on the **pkginst** — it is what *produces* the catalog name, so it cannot be keyed on its
own output — and the value must match `[A-Za-z0-9][A-Za-z0-9+.-]*` with no `|`, or the generator
refuses the package. The mapping above is the first real one: `amix-benchmark` is 14 characters,
over the **9-character pkginst limit** stock `pkgadd` enforces by silently dropping a longer
instance, so the package installs as `amixbench` and is listed, searched and installed as
`amix-benchmark`. Nothing is renamed and no `.pkg` byte moves; a package absent from `names.conf`
keeps the default. Its siblings follow the same catalog-level pattern: `deps.conf` (the dependency
graph, below), `descs.conf` (description overrides) and `cats.conf` (the category taxonomy).

### Parsing is defensive, and a bad catalog is rejected whole

The client validates field count, a 32-hex `md5`, a numeric `size`, and a
`[A-Za-z0-9._+-]`-plus-`/` whitelist on `filename` — because a filename reaches a URL, a shell
pipeline and a cache path. A leading `/`, any `.` or `..` component, a `//`, or a trailing `/`
**rejects the entire catalog** rather than the one row ✅. Nothing in a catalog can address anything
outside the `pkgs/` tree.

**Version comparison** ✅: split on `.` and `-`; numeric segments compare numerically, otherwise
`strcmp`; a missing segment counts as 0. That is the rule `upgrade` and the already-installed skip
both use.

### Dependencies are authored, not inherited

Stock Amix package metadata carries **no dependency information at all** — no `depend` files, no
install scripts ✅. The catalog's `deps` field is therefore **authored**, in a separate host-side
`deps.conf` the catalog generator reads. Two principles keep that graph honest ✅:

- `core` is the essential base OS and is **never** listed as a dependency — it is always present.
- **No "you need a compiler" dependencies.** Which compiler (the stock AT&T `cc` or the community
  GCC) is the user's choice, and installing a source package purely to read it is legitimate.

## Integrity model

**Today: md5 plus size, everywhere, checked before anything is mutated.** ✅

| Artifact | Check |
|---|---|
| `catalog` | `catalog.md5` sits beside it; the publisher refuses to publish a catalog that does not match its own checksum file, and re-fetches the served copy afterwards to compare |
| each package | the catalog's `md5` **and** `size`, verified after staging and before `pkgadd` sees the file |
| a dependency chain | **every** member is staged and verified before the **first** `pkgadd` runs — a bad source cannot leave a half-installed chain |

The md5 covers the file **as transported**: for a `.pkg.Z` the digest is of the compressed file ✅.

**Planned, not yet implemented** 🟡: a `sha256` field alongside `md5`, plus a detached signature over
the catalog (minisign/signify family). The reason it is on the roadmap rather than "nice to have" is
sequencing — retrofitting signatures *after* third-party clients exist never happens. (The scheme
was meant to land before the repository went public; the repository has been public since
2026-09-14 and the signature has not landed yet.) On the client side sha256 verification is a small
C addition; the catalog grammar already tolerates extra fields at the end.

## The client (`apkg`)

`apkg` is a single C89 binary (MIT) that reads installed state straight from the stock
`/var/sadm/pkg` database and drives `pkgadd`/`pkgrm` non-interactively, so it coexists with the
native tools ✅.

```text
apkg [-n] [-f] [-v] [-c conffile] [-R root] <verb> [args]

update                  fetch <repo>/catalog -> the local catalog (tmp + rename)
list [installed|all]    catalog entries with an installed-version column
search <substr>         case-insensitive match on name|description
info <name>             full catalog entry + installed state
download <name>         fetch <repo>/pkgs/<filename> into the cache, md5-verify
install <name>...       resolve deps -> stage + verify ALL -> pkgadd each
upgrade <name>          catalog newer than installed: pkgrm old, pkgadd new
remove <name>           pkgrm wrapper
```

Exit codes ✅: `0` ok · `1` usage/config · `2` network · `3` verify (md5/size/catalog) · `4`
`pkgadd`/`pkgrm`/`zcat` failure · `5` dependency cycle or missing dependency.

Configuration is `/etc/apkg.conf`, `key=value`, `#` comments — `repo=`, `cachedir=`, `pkgadd=`,
`pkgrm=`, `admin=`, `timeout=` ✅.

### Three sources, one format

The `repo=` string is classified **explicitly** — no heuristics, and anything unrecognised is a hard
error ✅. The same catalog format serves all three:

| `repo=` form | Source | Catalog fetch | Package staging |
|---|---|---|---|
| `http://host[:port]/path` | **HTTP** | `GET <repo>/catalog` | download to cache, then verify |
| `file:///cdrom`, or a bare `/cdrom` | **mounted medium** | copy `<dir>/catalog` | a plain `.pkg` is verified **in place** and handed to `pkgadd` from the medium (no cache copy); a `.pkg.Z` is decompressed into the cache |
| `raw:/dev/rdsk/...` | **raw slice** (tape / install slice) | read a fixed metadata region at offset 0 | `dd` from the catalog's byte `offset` into the cache, then verify |

Staging is driven by **read cost**: a mounted plain package is read once, not three times. The raw
slice is *self-describing* — catalog at offset 0, `catalog.md5` at 32768, packages at 512-aligned
offsets the catalog records — which is what a tape or a from-media install slice looks like ✅.

### HTTP specifics

The client speaks **HTTP/1.0 only**, hand-rolled over BSD sockets ✅:

- `GET` with a `Host:` header (**load-bearing** — the reference repository is virtual-hosted) and
  `Connection: close`.
- Headers parsed case-insensitively; `Content-Length` used as a truncation check.
- Follows **exactly one** 301/302 redirect.
- Whole-transfer `alarm()` timeout, 60 s by default.
- IPv4 literals are parsed locally, because the SVR4 `gethostbyname()` need not accept dotted quads.
- **Plain `http://` only** — no TLS.

**There is no FTP transport in the client** ✅: `apkg` speaks HTTP, a mounted filesystem, or a raw
device — nothing else. No TLS means a public repository
must lean on the planned catalog signature for authenticity rather than on the transport.

### Other behaviours worth knowing ✅

- **`.Z` transparency:** a `filename` ending in `.Z` is piped through the box's native `zcat` into
  the cache before `pkgadd` sees it.
- **Installed state** is `<root>/var/sadm/pkg/<pkginst>/pkginfo` existing; its `VERSION=` is the
  installed version. Stock Amix packages predate that convention and read as *unversioned*, which
  `upgrade` treats as older than any catalog version.
- **`pkgadd`/`pkgrm` run via `fork`/`execv`**, not a shell — no quoting surface, exact argv logging.
  The child's stdin is `/dev/null` so the stock 1991 `pkgadd`'s prompts read EOF and abort loudly
  instead of hanging forever.
- **An `admin` file** with the interactive checks disabled is shipped alongside the client and passed
  as `pkgadd -n -a <admin> -d <file> <pkginst>`.
- **`-R <target>`** prefixes the install target (the "is it installed?" database and `pkgadd -R`)
  without moving the engine — the engine runs from the installer medium and installs *into* the
  target. Keep alternate-root paths short: stock SVR4 `libadm` has a fixed-size path buffer that
  smashes its stack past roughly 105 characters ✅.

## Publishing

Publishing is `rsync` plus verification, in a deliberate order, behind two gates: the **owner's own
hand** and the **licence gates** ✅.

### Gate 1: every publish is the owner's decision, run by the owner ✅

Publishing to `pkg.amigaux.org` is a manual, per-change owner action; no automation uploads.

### The publish sequence ✅

1. **Packages first, catalog second** — a client must never see a catalog that references payloads
   that are not uploaded yet.
2. The staged `catalog` must match its own `catalog.md5`, or the publish refuses (that catches a
   stale generator run or a hand-edited catalog).
3. Removed packages are pruned from the server, so the tree cannot accumulate orphans.
4. After the sync, the published catalog is **fetched back over plain HTTP** — the same path the
   client uses — and its md5 compared against the staged copy. A mismatch is a non-zero exit.

**Stage from the live host, never from a mirror** ✅: `publish.sh` syncs with
`--delete --delete-excluded`, so a staging root built from a stale copy would delete served packages. Pull the live tree down, prove it
against the live catalog (md5 **and** size of every entry), then add the change.

### ⚠ Never regenerate the catalog over a live-pulled staging root ✅

Catalog v1 holds **one version per name**, and the generator keys candidates on the catalog name
and **sorts** them. The live host still serves superseded `APKG` files (`base/APKG-0.1.pkg`, and
`APKG-0.2.pkg` too once a newer client is catalogued) that are no longer catalogued but must stay
in staging — otherwise `--delete-excluded` removes a file someone may still fetch. With two `APKG` versions present, both
map to `apkg`, the older one sorts first and **wins**, and the newer one is dropped with only a
stderr `SKIP`: a regenerate would silently decatalogue the live client and republish the old one.

The rule: generate the catalog with the superseded `APKG` files moved **out** of the root, move them
back, and leave a `DO-NOT-REGENERATE.txt` in the root saying so. Verify a staged catalog by
comparing it to the expected md5 — never by re-running the generator there. `publish.sh` itself is
safe: it only checks `catalog.md5` and runs the scans, it builds no catalog. (A durable fix —
prefer the highest version, or an explicit pin — is a candidate, not implemented 🟡.)

### Gate 2: the licence gates (mechanical, fail-closed, no `--force`) ✅

Two independent scans, deliberately kept in separate tools so neither can quietly absorb and weaken
the other. Both are fatal in `publish.sh` (exit 5).

**The payload-licence gate** (`payload-licence-gate.py`) answers *does a package carry somebody
else's object code?* ✅

- It refuses a payload ELF that **statically embeds stock SVR4 object code**, detected by the
  source-file (`STT_FILE`) names a static link leaves behind: a distinctive marker (`matherr.c`,
  `reduce.c`) or **three or more** `libm` names together.
- **`DT_NEEDED` is informational only** — dynamic linkage against a library that lives on the box
  redistributes nothing (the published `apkg` legitimately needs `libnsl.so`).
- The `stock/` packages are skipped **by provenance, out loud** — they are Commodore's own content,
  governed by the licensing decision above, not re-judged by the gate.
- **Honest limit:** a **stripped** binary has no symbol table and reports **UNKNOWN — untested, not
  clean**; the add-on set is therefore *un-refuted* rather than proven clean until its binaries ship
  unstripped or attest their link line.

**The kernel-package gate** (`gen-catalog.py --scan-private`) answers *is this one of our own kernel
packages?* It refuses, unconditionally, to push **kernel packages** ✅. Those packages carry
a whole `/stand/unix` plus the second-stage boot loader — our own kernel mints — and the gate's
contract is that those never reach the public catalog. It predates, and is independent of, the
2026-09-23 licensing outcome: publishing a kernel is a separate owner decision, not something a
publish run may do by accident.

Two details make the gate trustworthy rather than decorative:

- **It keys on `pkginfo` markers, not on pathnames.** An earlier pathname-keyed version condemned
  *stock* packages, which legitimately ship `/stand` members as original distribution content. The
  markers are parameters the kernel-package build mints for exactly this purpose, so the refusal
  matches kernel packages precisely.
- **It fails closed and has no `--force`.** The publisher syncs every package present in staging
  (not merely the catalogued ones), so a hand-added or stale-catalog kernel package would otherwise
  reach the server. If the scan cannot even run, the publish refuses rather than proceeding
  unverified.

## See also

- [Package management](package-management.md) — the *local* side: `/var/sadm`, the `contents(4)`
  grammar, how `pkgadd` mutates the database, and the stock-image defect that breaks `pkgrm`.
- [Toolchain and packaging](../drivers/toolchain.md) — `pkgproto` → `pkgmk` → `pkgtrans` → `pkgadd`,
  i.e. how the `.pkg` files in `pkgs/` are built.
- [Command cheat sheet](../reference/commands-cheatsheet.md) — the `pkg*` command table and the
  `pkgs/`-segment URL gotcha.
- [Filesystems and disks](filesystems-and-disks.md) — `cdfs`, which is what makes the mounted-medium
  source reach an optical disc.

## Sources

- The **amix-packagemanager** repository (the reference implementation of everything on this page)
  ✅: `docs/design.md` §2 (client verbs, config keys, catalog format v1, HTTP client, version
  compare), §2a (the three package sources and the self-describing raw layout) and §5 (repo tools);
  `src/apkg/README.md` (HTTP/1.0 details, catalog validation whitelist, flat-cache basename
  requirement, `fork`/`execv` install path, `-R` semantics); `tools/repo/gen-catalog.py` (catalog
  emission, the `#apkg-catalog 1` banner, the 9-character `PKG` limit, `--raw` offsets);
  `tools/repo/publish.sh` (publish ordering, the `catalog.md5` precondition, the marker-keyed
  private-content refusal with no `--force`, the post-publish HTTP re-fetch and md5 compare);
  `tools/repo/deps.conf` (the authored dependency graph and its two principles);
  `tools/repo/names.conf` (the `<PKGINST>: <catalog-name>` override, the `amixbench` →
  `amix-benchmark` mapping and its 9-character reason); `tools/repo/payload-licence-gate.py` (what
  refuses, `DT_NEEDED` informational, the `stock/` provenance skip, UNKNOWN for stripped binaries);
  `docs/design.md` §5.3 (the authored `deps`/`cats`/`descs`/`names` files); `src/apkg/conf.c`
  (`DEF_REPO` = `http://pkg.amigaux.org`).
- The amix-packagemanager **`NOTES.md`** — the format and publish authority ✅: the `pkg.amigaux.org`
  move and its client contract (plain HTTP on port 80, name-based vhost, the hosts-file path;
  2026-09-14); the payload-licence gate and why it exists (2026-09-16); the `names.conf` first use and
  the catalog-regenerate trap (2026-09-16 publish log); owner-run publishing (2026-09-16); the
  39-entry live catalog, 27 stock + 12 own, and the stock packages' exposure posture (2026-09-26).
- The 2026-09-23 licensing outcome — [`AGENTS.md` §5](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md#5-respect-the-licensing-boundary) ✅.
- A **real staging tree** inspected locally (2026-07-26): 32 catalog rows over `stock/` (27),
  `base/` (3) and `test/` (2), catalog md5 `edeba578b73fc892f3c8c5ede603aca7` ✅.
- The stock-metadata facts the authored dependency graph rests on (no `depend` files, no install
  scripts, `CLASSES=none`) — bench-verified on a live Amix 2.1c image, and recorded on the
  [package management](package-management.md) page ✅.
- Roadmap items (sha256 + catalog signature) are **planned, not
  implemented** 🟡 — recorded here so the format's evolution is predictable, not as current
  behaviour.
