---
title: Style Guide
summary: Prose, formatting, and structural conventions for grimoire-amix pages.
status: reviewed
---

# Style Guide

This guide covers *how* to write pages. For the *rules of accuracy* (grounding, fact-confidence tags,
licensing) see [`AGENTS.md`](../../AGENTS.md) at the repo root — those are mandatory for humans and AI alike.

## Page skeleton

Every page starts with front matter and follows roughly this shape:

```markdown
---
title: How Amix Boots
summary: The Superkickstart→bootstrap→kernel path and on-disk layout.
status: draft
---

# How Amix Boots

<one-paragraph answer: what this page tells you, up front>

## <Topic sections with stable ## / ### headings>

...

## See also
- [related page](../pillar/page.md)

## Sources
- ...
```

## Voice & structure

- **Inverted pyramid.** Lead with the answer; put caveats and depth below.
- **One topic per file.** If a page sprouts a second big topic, split it and cross-link.
- **Short paragraphs**, generous lists and tables. Prefer a config **table** to a paragraph of settings.
- **Second person** for instructions ("set MMU to ON"), present tense.
- **Imperative, copy-pastable commands.** Fence everything; include the expected output when it aids verification.
- Define jargon on first use and link to [`glossary.md`](../how-it-works/glossary.md).

## Markdown conventions

- ATX headings (`#`, `##`). One `#` H1 per page, matching `title`.
- Fenced code blocks with a language hint (` ```sh `, ` ```c `, ` ```text `).
- **Relative links** between docs (`../drivers/driver-model.md`), so they work on GitHub *and* in any
  generated site. Descriptive link text — never "here".
- Use real device/major/minor numbers and exact paths (`/dev/va2000`, char major 68) rather than vague descriptions.
- Callouts: use a bold lead-in (`**Note:**`, `**Warning:**`) — keep it portable Markdown (no HTML).

## Fact-confidence tags

Inline, per the [AGENTS contract](../../AGENTS.md): ✅ verified, 🟡 community-reported, 🔴 unverified/disputed.
Example: "The kernel hard-codes a 16 MB Fast RAM ceiling ✅; exceeding it mis-maps the SCSI drive ✅."

## Filenames

- Lowercase, hyphenated, `.md` (`writing-a-char-driver.md`).
- Match the path used in `llms.txt` and `docs/index.md`. If you move/rename a page, update both plus any inbound links.

## Audience reminder

Write so a newcomer can follow it *and* so an LLM agent can lift exact commands and facts without
guessing. Concrete > clever. When in doubt, add a table, a command, or a citation.

## Sources
- [`AGENTS.md`](../../AGENTS.md) (repo conventions)
- The `llms.txt` convention (Jeremy Howard, Answer.AI, 2024)
