---
description: Health-check the wiki and report (orphans, broken links, drift, staleness)
---
Lint the wiki, following the LINT workflow in `.opencode/llm-wiki/schema.md`.

Focus (optional): $ARGUMENTS

Report only — do not fix anything unless I ask.

**Check mechanically, with grep. Report what you actually found, with file and line —
never a guess that something "might be" missing:**

- Broken `[[links]]`: a target with no matching file in `wiki/`. Check `aliases:` before
  calling one broken.
- Orphan pages: no inbound links from anywhere in `wiki/`.
- Missing or malformed frontmatter: no `type`, `created`, `updated`, or `sources`.
- Index drift: pages absent from `wiki/index.md`, or listed there but no longer on disk.
- Uncited claims: figures or dates on entity/concept pages with no source link.

**Then the judgement calls:**

- Near-duplicate pages that have drifted into the same idea. Name the survivor and the
  aliases it should absorb.
- Contradictions between pages. Propose a `## Disagreements` section; don't pick a winner.
- Stale claims: a page whose `last_verified` predates a newer source on the same
  subject. Propose `status: superseded` with a `supersedes:` link so the replaced claim
  keeps its history.
- Entities or concepts mentioned often that lack their own page.
- Pages that should cross-reference each other but don't.
- Gaps a new source could fill, and what to add.

Append a `lint` entry to `wiki/log.md` with the counts and the headline findings.
