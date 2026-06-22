# `import/` — incoming handoff briefs

This is the **intake drop-box** for findings handed to grimoire-amix by other projects/agents.
Nothing here is authoritative: a brief becomes part of the docs only once grimoire's own agent
**grounds and integrates** it into `docs/` (with citations). Keep raw handoffs *out* of
[`sources/`](../sources/) — that directory is the grounded source of truth, not an inbox.

## What goes here

One Markdown file per handoff, named `import/<project>-<topic>.md` — e.g.
`import/amix-z3660net-ethernet.md`.

## Brief format (the contract)

State, **per finding**, three things:

- the **claim**;
- a **confidence tag** — ✅ verified (primary/repo source, or reproduced firsthand) · 🟡
  community-reported (forum / Usenet / wiki) · 🔴 unverified / disputed;
- a one-line **how-I-know** (the source: repo path + commit, a live result, a manual page, a forum
  post).

Follow the repo tag policy in [`../AGENTS.md`](../AGENTS.md): tags are carried **as written** and are
**never upgraded** downstream (no 🟡 → ✅ on a contributor's own authority).

## Lifecycle

1. A contributing agent (or you) drops a brief here.
2. grimoire's agent grounds + integrates it into the relevant `docs/` page(s), adds it to that
   page's `## Sources`, and regenerates `llms-full.txt`.
3. The brief is then **cleared** — deleted, or returned to the originating project — so `import/`
   only ever holds *un-integrated* work.

## Git

Briefs are **not tracked** (see [`.gitignore`](.gitignore)) — they are transient transport
artifacts and must not ship in the published site or land in `sources/`. Only this `README.md` and
`.gitignore` are committed.
