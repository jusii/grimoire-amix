# CLAUDE.md — grimoire-amix

The public developer/LLM documentation for Amiga Unix (Amix). The **knowledge sink** of the Amix
family: sibling driver repos hand it confidence-tagged findings; this repo grounds, integrates, and
publishes them. Not a code repo; not a dump for raw debug artifacts — grounded, citable prose only.

## `AGENTS.md` is binding

**Read `AGENTS.md` first and obey it exactly. If this file and `AGENTS.md` disagree, `AGENTS.md`
wins.** It owns (read them at the source, don't restate): ground every claim in
`sources/research-brief.md`; mandatory ✅/🟡/🔴 confidence tags, **never upgraded**; front matter +
a closing `## Sources` on every page; the **licensing boundary** (never commit proprietary
ADFs/HDFs/tapes/manuals — name + checksum + pointer only); keep `llms.txt` / `docs/index.md` /
`gen-llms-full.sh` in sync; **no AI attribution** in commits.

## Knowledge base (Obsidian vault)

Family context lives in the vault via the **obsidian-vault MCP server**. Read at session start:
- `CLAUDE.md` (vault root) + `Machine/Coding Standards.md` — vault rules + commit discipline
- `Machine/Personal/Amix/Overview.md` — the family map + edges
- `Machine/Personal/Amix/Contracts.md` — the cross-repo contracts (esp. the brief format + intake)
- `Machine/Personal/Amix/grimoire-amix.md` — this repo's role + intake responsibility

## Your job as the sink — brief intake (`AGENTS.md` §8)

Findings arrive in `import/<repo>-<topic>.md` — a **gitignored drop-box** (only `README.md` +
`.gitignore` tracked; briefs are transient). A non-empty `import/` is your to-do list:
1. **Ground** each finding against `sources/research-brief.md`.
2. **Fold** it into the relevant `docs/` page(s), **carrying its tag unchanged**.
3. **Cite** it in that page's `## Sources`.
4. **Regenerate** `llms-full.txt` (`tools/gen-llms-full.sh`); keep `llms.txt`/`docs/index.md`/`order=()` in sync.
5. **Clear** the brief (delete or return to origin). Never move a raw brief into `sources/`.

## Commit discipline

Follow `Machine/Coding Standards.md` + `AGENTS.md` §6: **never mention AI tools in commit messages**
(no `Co-Authored-By`, no "generated with"). Identity: `Jusii <jussi@alanara.fi>`. This is a **public**
repo — the `AGENTS.md` §5 licensing boundary is not optional.
