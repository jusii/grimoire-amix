---
title: The Amix Package Repository Format
summary: How a remote Amix package repository is laid out and consumed — the static tree, the pipe-delimited catalog v1 grammar, the md5 integrity model, the apkg client's three sources (HTTP / mounted medium / raw slice), and the fail-closed publish gates.
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

> **Licensing note.** The format is open; the *content* is not. The Amix distribution packages are
> proprietary Commodore material (treated as abandonware, not licensed for redistribution) — a
> repository that carries repackaged stock packages is a **private, site-local** repository, not a
> public mirror. See [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md) §5.
> The publish tooling enforces one specific refusal of its own (below); everything else is on the
> operator.

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
    ├── stock/                 repackaged distribution packages (site-local only)
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
| 1 | `name` | Catalog name — what a user types | Lowercased `PKG` by default; overridable per package |
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
sequencing — retrofitting signatures *after* third-party clients exist never happens, so the scheme
is meant to land before the repository is public. On the client side sha256 verification is a small
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

**There is no FTP transport in the client** ✅. (FTP appears throughout this project as the *host ↔
box* development file bridge, and a future public site may offer FTP for browsers, but `apkg` itself
speaks HTTP, a mounted filesystem, or a raw device — nothing else.) No TLS means a public repository
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

Publishing is `rsync` plus verification, in a deliberate order ✅:

1. **Packages first, catalog second** — a client must never see a catalog that references payloads
   that are not uploaded yet.
2. The staged `catalog` must match its own `catalog.md5`, or the publish refuses (that catches a
   stale generator run or a hand-edited catalog).
3. Removed packages are pruned from the server, so the tree cannot accumulate orphans.
4. After the sync, the published catalog is **fetched back over plain HTTP** — the same path the
   client uses — and its md5 compared against the staged copy. A mismatch is a non-zero exit.

### The fail-closed content gate

The publish path also refuses, unconditionally, to push **kernel packages** ✅. Those packages carry
a whole `/stand/unix` plus the second-stage boot loader; that payload is proprietary-derived, so it
is private-only and may never reach a redistributable tree.

Two details make the gate trustworthy rather than decorative:

- **It keys on `pkginfo` markers, not on pathnames.** An earlier pathname-keyed version condemned
  *stock* packages, which legitimately ship `/stand` members as original distribution content. The
  markers are parameters the kernel-package build mints for exactly this purpose, so the refusal
  matches kernel packages precisely.
- **It fails closed and has no `--force`.** The publisher syncs every package present in staging
  (not merely the catalogued ones), so a hand-added or stale-catalog kernel package would otherwise
  reach the server. If the scan cannot even run, the publish refuses rather than proceeding
  unverified.

**Planned** 🟡: an explicit, separately-confirmed `--public-release` override for the day a genuinely
public repository ships distribution content deliberately — with the fail-closed gates remaining the
default, so nothing proprietary can leak *accidentally*.

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
  `tools/repo/deps.conf` (the authored dependency graph and its two principles).
- A **real staging tree** inspected locally (2026-07-26): 32 catalog rows over `stock/` (27),
  `base/` (3) and `test/` (2), catalog md5 `edeba578b73fc892f3c8c5ede603aca7` ✅.
- The stock-metadata facts the authored dependency graph rests on (no `depend` files, no install
  scripts, `CLASSES=none`) — bench-verified on a live Amix 2.1c image, and recorded on the
  [package management](package-management.md) page ✅.
- Roadmap items (sha256 + catalog signature; the `--public-release` override) are **planned, not
  implemented** 🟡 — recorded here so the format's evolution is predictable, not as current
  behaviour.
