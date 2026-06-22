# AGENTS.md — contract for AI (and human) contributors

This repository documents **Amiga Unix (Amix)**, Commodore's port of AT&T System V Release 4 to
68030 Amigas, for an audience of **both humans and LLM agents**. If you are an AI agent editing
this repo, follow these rules exactly. They exist so the docs stay *trustworthy* about an obscure,
poorly-documented system where a lot of plausible-sounding lore is wrong.

## 1. Ground every claim

- The **single internal source of truth** is [`sources/research-brief.md`](sources/research-brief.md).
  Read it before writing. It carries citations and confidence tags for essentially everything we know.
- **Do not introduce a fact that is not supported** by the brief or by a cited primary source. If you
  believe something true but can't ground it, mark it 🔴 and say so — do not launder it into prose.
- **Source-of-truth hierarchy:** primary manuals / the Ditto driver paper / the real disk images &
  repo source **>** archived Usenet (comp.unix.amiga) **>** forum lore. Prefer the higher tier.

## 2. Fact-confidence tags (mandatory)

Tag every non-obvious factual statement inline with one of:

- ✅ **Verified** — primary source, repo source, official manual, or reproduced locally.
- 🟡 **Community-reported** — amigaunix.com / forums / Usenet; credible, not primary-verified.
- 🔴 **Unverified / disputed** — conflicting or unbacked; must be flagged, never stated as fact.

Use the tag once per claim (not on every sentence). If a whole section is uniformly ✅, say so once
at the top. Carry the *same* tag the brief uses — do not upgrade 🟡 to ✅ on your own authority.

## 3. Every page ends with `## Sources`

A bullet list of the specific sources behind that page (URLs, "Ditto paper p.N", "`amix_21_root.adf`
analysis via `tools/inspect-adf.sh`", repo paths). No page ships without it.

## 4. Write for two readers at once

- **One topic per file.** Stable, descriptive `##`/`###` headings (LLMs and humans both navigate by them).
- **Front matter** at the very top of every page:
  ```markdown
  ---
  title: <Human Title>
  summary: <one sentence — what this page answers>
  status: draft | reviewed
  ---
  ```
- **Descriptive link text** (`[the Ditto driver paper](...)`, never "click here").
- **Reproducibility over prose:** prefer exact commands, config tables, file paths, and minor/major
  numbers to hand-wavy description. Fence all code/config; make it copy-pastable.
- **Cross-link** related pages with relative Markdown links. Link to the live `docs/reference/glossary.md`
  on first use of a jargon term where helpful.
- Keep paragraphs short. Lead with the answer, then the detail (inverted pyramid).

## 5. Respect the licensing boundary

The Amix distribution, the boot/root/patch ADFs, and the scanned manuals are **proprietary Commodore
material** (treated as abandonware, not licensed for redistribution). **Never commit** the ADFs, HDFs,
tape images, or the PDF (they are `.gitignore`d). Refer to them by name + checksum + a pointer to
amigaunix.com / archive.org. Tooling must operate on **user-supplied** images. Quoting short script
snippets or string excerpts for documentation/interoperability is fine; bulk-reproducing files is not.

## 6. Don't break the conventions infra

- `llms.txt` (root) is the curated LLM index — keep it in sync when you add/rename/move a page.
- `tools/gen-llms-full.sh` regenerates `llms-full.txt`; run it after content changes.
- Don't invent skill/tool/file names. If you reference a `tools/` script, it must exist.

## 7. Scope

Four content pillars under `docs/`: **how-it-works**, **getting-started** (emulation-first),
**drivers** (software & device-driver development), **boot-disks** (custom boot/install disks +
tooling), plus **reference**. See [`docs/index.md`](docs/index.md) for the map and
[`docs/contributing/style-guide.md`](docs/contributing/style-guide.md) for prose conventions.

This is an **independent** resource that **cross-links** to [amigaunix.com](https://www.amigaunix.com/doku.php/home)
for end-user/historical/install-media material — we do not duplicate it, we go deeper on development.

## 8. Importing findings from other projects (`import/`)

New findings handed over by other projects/agents arrive as **confidence-tagged briefs** dropped in
[`import/`](import/) — one Markdown file per handoff, `import/<project>-<topic>.md`. Each brief states,
per finding: the **claim**, its **✅/🟡/🔴 tag**, and a one-line **how-I-know**. Briefs are **not**
authoritative and are **gitignored** (they are transient transport artifacts — see
[`import/README.md`](import/README.md)).

To integrate one: ground it against existing sources, fold it into the relevant `docs/` page(s)
**carrying its tags unchanged** (never upgrade — §2), add it to that page's `## Sources`, regenerate
`llms-full.txt` (§6), then **clear** the brief from `import/` (delete it, or return it to the
originating project). Never leave a raw brief in [`sources/`](sources/) — that directory is the
grounded source of truth (§1), not an inbox.
