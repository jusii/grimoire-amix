---
title: Writing for LLM Consumers
summary: How this repo is structured for AI agents and how to contribute as one.
status: draft
---

# Writing for LLM Consumers

This repo is built so that **both a human and an LLM agent can read it cold and lift exact, trustworthy facts** about Amiga Unix (Amix) without guessing. This page explains the machinery that makes that work — the `llms.txt` / `llms-full.txt` index files, per-page front matter, the ✅/🟡/🔴 fact-confidence system, and the single source of truth — and tells you, the AI contributor, how to add or edit a page without breaking any of it.

If you only read one other file, read [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md) at the repo root. It is the mandatory contract; this page is the practical companion to it. For prose and Markdown conventions, see the [style guide](style-guide.md).

## Why this repo is built this way

Amix is obscure and badly documented, and a lot of plausible-sounding lore about it is simply wrong (see the "2.2 does not exist" and "2.1c, 1994" cases in the [versions reference](../reference/versions.md)). An LLM trained on the open web will confidently repeat that lore. So the repo's whole design is defensive: every claim is traceable to a source, every uncertainty is tagged, and the corpus is shaped so a model can find the relevant page and quote it verbatim instead of hallucinating.

The practical upshot: **concrete beats clever.** A config table, an exact command, a `/dev` node with its major/minor number, or a citation is worth more than a paragraph of fluent prose — to a human skimming and to a model retrieving alike.

## The source-of-truth hierarchy

Everything in `docs/` is downstream of one file:

1. **[`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md)** — the internal, citation-bearing grounding document. It is the *single internal source of truth*. Read it before you write anything. ✅
2. **Cited primary sources** — the Ditto driver paper (1990 European Amiga Developer's Conference), the real install ADFs analysed with `tools/inspect-adf.sh`, repo source for the modern drivers, and official Commodore manuals.
3. **Archived Usenet** (comp.unix.amiga) above **forum lore** — when sources conflict, prefer the higher tier.

The rule, restated from [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md): **do not state a fact in `docs/` that is not supported in the brief or a cited primary source.** If you believe something but cannot ground it, either drop it or mark it 🔴 and say so. Never launder an unverified claim into confident prose — that is exactly the failure mode this repo exists to prevent.

## Fact-confidence tags

Tag every non-obvious factual statement inline with one of three markers, and carry the **same** tag the brief uses:

| Tag | Meaning | Where it comes from |
|---|---|---|
| ✅ | **Verified** — primary source, repo source, official manual, or reproduced locally | brief marks it ✅ |
| 🟡 | **Community-reported** — amigaunix.com / forums / Usenet; credible, not primary-verified | brief marks it 🟡 |
| 🔴 | **Unverified / disputed** — conflicting or unbacked; must be flagged, never stated as fact | brief marks it 🔴 |

Rules of use:

- **Never upgrade confidence on your own authority.** If the brief says 🟡, your page says 🟡. Promoting 🟡 → ✅ because the claim "seems right" is the single worst thing you can do here.
- **One tag per claim**, not per sentence. If an entire section is uniformly ✅, say so once at the top (e.g. "Everything in this section is ✅ from the Ditto paper unless noted").
- A 🔴 must be *visibly* flagged in the running text, not buried — the reader should never mistake it for fact.

Example, copy the brief's own style:

```markdown
The kernel hard-codes a 16 MB Fast RAM ceiling ✅; exceeding it mis-maps the SCSI drive ✅.
A "2.2" release does not exist in any primary source 🔴.
```

## The two index files: `llms.txt` and `llms-full.txt`

The repo exposes itself to agents through two complementary files at the repo root, following the [`llms.txt` convention](https://llmstxt.org/) (Jeremy Howard, Answer.AI, Sept 2024):

- **`llms.txt`** — a **curated, hand-maintained index**: a short Markdown map of the site with one descriptive link per page, grouped by pillar. It is the "front door" an agent reads first to decide *which* page it needs. Keep it small and high-signal.
- **`llms-full.txt`** — the **full corpus concatenated** into a single file (every page, in canonical reading order, with `# FILE: <path>` separators) so a model can ingest the entire documentation set in one shot. It is **generated, never hand-edited.**

You regenerate `llms-full.txt` with the bundled script after any content change:

```sh
tools/gen-llms-full.sh
# wrote .../llms-full.txt (NNNNN bytes, 37 pages, 0 missing)
```

`tools/gen-llms-full.sh` resolves paths relative to the repo root, prepends a header that points back at `sources/research-brief.md`, and walks a fixed `order=( … )` array. A non-zero "missing" count in its output means a page in the reading order does not exist yet — that is expected while the site is being filled in, but it should reach **0 missing** for a complete corpus.

**Keep the three orderings in sync.** When you add, rename, move, or delete a page, update *all* of:

1. the `order=( … )` array in [`tools/gen-llms-full.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/gen-llms-full.sh),
2. the curated `llms.txt`, and
3. `docs/index.md` (the human-facing site map).

Then rerun `tools/gen-llms-full.sh`. If these drift apart, agents get a stale or incomplete view of the corpus.

## Per-page front matter

Every page begins with YAML front matter — three fields, exactly as in [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md):

```markdown
---
title: <Human Title>
summary: <one sentence — what this page answers>
status: draft | reviewed
---
```

- `title` must match the page's single H1.
- `summary` is one sentence answering "what does this page tell me?" — it is what feeds the curated `llms.txt` link and gives an agent a cheap relevance signal without reading the whole page.
- `status` is `draft` until a human reviews it; only a human reviewer should flip it to `reviewed`.

## Structural rules that make pages machine-navigable

These are the conventions that let a model (and a human) jump straight to the right fragment:

- **One topic per file.** If a page grows a second big topic, split it and cross-link. A focused page is far easier to retrieve and quote than a sprawling one.
- **Stable, descriptive `##` / `###` headings.** Both humans and LLMs navigate by headings; treat them as a stable API. Don't rename a heading casually — inbound deep links and an agent's mental model both depend on it.
- **Lead with the answer (inverted pyramid).** First paragraph answers the question; caveats and depth go below. An agent that reads only the top of the page should still get the correct headline.
- **Reproducibility over prose.** Prefer exact commands, config tables, file paths, and major/minor numbers (`/dev/va2000`, char major 68) to hand-wavy description. Fence all code/config with a language hint (` ```sh `, ` ```c `, ` ```text `) and make it copy-pastable.
- **Relative links with descriptive text.** Cross-link siblings as `../drivers/driver-model.md` (works on GitHub and in any generated site), and use link text that says what's on the other end — `the Ditto driver paper`, never "click here". Define jargon on first use and link the [glossary](../how-it-works/glossary.md).
- **Every page ends with `## Sources`** — a bullet list of the specific sources behind *that* page (URLs, "Ditto paper p.N", "`amix_21_root.adf` analysis via `tools/inspect-adf.sh`", repo paths). No page ships without it. This is what lets a reader (or a downstream model) verify any claim, and it is non-negotiable per [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md).

## The licensing boundary

The Amix distribution, the boot/root/patch ADFs, the HDFs/tape images, and the scanned manuals are **proprietary Commodore material** (treated as abandonware, not licensed for redistribution) and are `.gitignore`d. **Never commit them, and never tell anyone else to.** Refer to them by name + checksum (`sources/CHECKSUMS.txt`) plus a pointer to [amigaunix.com](https://www.amigaunix.com/doku.php/home) or archive.org. Tooling must operate on **user-supplied** images. Quoting short script snippets or string excerpts for documentation is fine; bulk-reproducing files is not. ✅

## A checklist for AI contributors

Before you finish a page edit, confirm:

- [ ] Read [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) and grounded every non-obvious claim in it (or a cited primary source).
- [ ] Carried the brief's exact ✅/🟡/🔴 tag on each claim — **no upward upgrades.**
- [ ] Front matter present (`title` matching the H1, one-sentence `summary`, `status`).
- [ ] One topic, stable headings, answer first, code fenced with language hints, relative links with descriptive text.
- [ ] A `## Sources` list citing this page's specific sources.
- [ ] Respected the licensing boundary — no proprietary media committed or recommended for committing.
- [ ] Did not invent any `tools/`, file, or skill name (if you reference a `tools/` script, it must exist).
- [ ] Updated `llms.txt`, `docs/index.md`, and the `order=()` array in `tools/gen-llms-full.sh` if you added/renamed/moved a page, then reran `tools/gen-llms-full.sh`.

## See also

- [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md) — the mandatory contributor contract (read first)
- [Style Guide](style-guide.md) — prose and Markdown conventions
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) — the grounding source of truth

## Sources

- [`AGENTS.md`](https://github.com/Jusii/grimoire-amix/blob/master/AGENTS.md) — repo contract: grounding, fact-confidence tags, `## Sources` requirement, front matter, licensing boundary, "keep `llms.txt` in sync / run `tools/gen-llms-full.sh`".
- [`docs/contributing/style-guide.md`](style-guide.md) — page skeleton, headings, relative links, tags.
- [`tools/gen-llms-full.sh`](https://github.com/Jusii/grimoire-amix/blob/master/tools/gen-llms-full.sh) — the generator for `llms-full.txt`; its `order=()` array is the canonical reading order (37 pages).
- [`sources/research-brief.md`](https://github.com/Jusii/grimoire-amix/blob/master/sources/research-brief.md) §0 (source-of-truth hierarchy, confidence tags) and the §1 versions example (2.2 / 2.1c-1994 lore as 🔴).
- The `llms.txt` convention: <https://llmstxt.org/> (Jeremy Howard, Answer.AI, Sept 2024).
