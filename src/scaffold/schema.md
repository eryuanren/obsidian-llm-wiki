# LLM Wiki — schema

How this wiki is structured, the conventions to follow, and the workflows for
**ingesting** sources, **answering** questions, and **linting**.

*This file ships with the LLM Wiki plugin and is replaced when the plugin updates. Put
your own rules in `AGENTS.md`, which is never overwritten.*

This wiki follows the "LLM Wiki" pattern: instead of re-deriving knowledge from raw
documents on every query (RAG), you **incrementally build and maintain a persistent,
interlinked wiki** that sits between the user and the raw sources. Knowledge is compiled
once and then kept current. The wiki is a compounding artifact — the cross-references,
contradictions, and synthesis are already there before any question is asked.

**The wiki is a map, not a replacement for the territory.** Compiling a source into a
summary drops detail: exact figures, dates, caveats, footnotes. The wiki's job is to
tell you *what is known and where it is recorded*. When precision matters, the wiki
points you back to the source and you read the source. A page that cannot be traced to
a source is a page that cannot be checked.

---

## Architecture

Three layers:

1. **Raw sources** (`raw/`) — the user's curated source documents, any file type.
   **These are immutable.** You read from them but never modify, move, or delete them.
2. **The wiki** (`wiki/`) — the markdown knowledge base. You own this layer entirely.
3. **The schema** (this file + `AGENTS.md`) — how the wiki works.

### Pipeline folders

| Folder       | Holds                                          | Who writes        |
|--------------|------------------------------------------------|-------------------|
| `raw/`       | Original uploads (any type) — **immutable**    | Human             |
| `raw/assets/`| Local copies of images referenced by sources   | Human / tooling   |
| `inbox/`     | Markdown + image files **awaiting ingest**     | `convert-all.ps1` |
| `processed/` | Items **already ingested** — the retrieval layer | archive step    |
| `wiki/`      | The knowledge base                             | **You (Sunny)**   |
| `.llm-wiki/` | Pipeline state (queue manifest, ingest status) | tooling + you     |

The flow: files land in `raw/` → converted to markdown into `inbox/` → you ingest
everything in `inbox/` → what succeeded is archived to `processed/`.

**`processed/` is not a graveyard.** It is the full text of every ingested source, and
it is where you go when a wiki page is too coarse to answer a question. Source pages
link into it.

`.llm-wiki/queue.json` records, for each queued file, the raw file it came from and that
file's content hash. Read it when you need real provenance for a source page: the queue
name may be flattened (`reports__q3.md` came from `raw/reports/q3.pdf`).

### Wiki layout

```
wiki/
├── sources/    # one page per ingested source (summary + provenance + link to the text)
├── entities/   # people, orgs, places, products, things
├── concepts/   # ideas, theories, frameworks, methods
├── synthesis/  # cross-source analysis, comparisons, filed-back answers
├── index.md    # content catalog (you update every ingest)
├── log.md      # chronological append-only activity record
└── processed.md # audit table of ingested files
```

---

## Page conventions

Every wiki page starts with YAML frontmatter, then an H1 title, then the body, then a
`## Related` section of `[[links]]`.

```markdown
---
type: entity                 # entity | concept | source | synthesis
tags: [topic, area]
aliases: [ML, machine-learning]   # synonyms, so links and search resolve
created: 2026-06-22
updated: 2026-06-22
last_verified: 2026-06-22    # when a human or you last checked this against a source
status: current              # current | superseded | disputed | stub
sources:                     # links, not a count — this is the provenance trail
  - "[[Smith 2024 (source)]]"
  - "[[Q3 Report (source)]]"
supersedes: "[[Older Page]]" # optional, when this replaces an earlier claim
---

# Page Title

Body...

## Disagreements

*Only when sources conflict. Keep both sides with attribution — never overwrite one
with the other.*

## Related
- [[Other Page]]
- [[Another Page]]
```

**Conventions:**

- **Filenames** are the human-readable title in Title Case (e.g. `Machine Learning.md`),
  so `[[Machine Learning]]` links resolve in Obsidian. **No colons** — `Smith 2024
  (source)`, never `Source: Smith 2024`. A colon is an illegal filename character on
  Windows and the link will silently fail to resolve.
- **Always link** related entities and concepts with `[[wiki links]]`. A page with no
  inbound or outbound links is an orphan — avoid creating them.
- **One concept/entity per page.** Don't bundle.
- **Cite at claim level, not page level.** Point at the section that carries the claim:
  `Per [[Q3 Report (source)#Revenue]], ...`. "According to the sources" is not a
  citation and cannot be checked.
- **Source pages** go in `sources/`, named after the source, and must record: a summary,
  key takeaways, the archived text (`processed/<file>`), the original (`raw/<file>`),
  and links to every entity/concept page they touched.
- **Keep the numbers in the source page.** Figures, dates, quotations and units belong
  on the source page verbatim, where they can be checked. Entity and concept pages
  summarise and link; they do not restate numbers from memory.
- **Rewrite summaries, don't append to them.** A page whose summary grows by accretion
  stops being a summary. Revise it so it reads as one coherent account.

### Before you create a page

**Search first.** Near-duplicate pages are this pattern's default failure mode:
`Machine Learning` and `machine learning (ML)` and `ML Methods` drift apart and nothing
links them.

1. Grep the wiki for the title and its obvious synonyms.
2. Check `aliases:` on existing pages.
3. If a page covers the same idea, **update it** and add the new name to its `aliases:`.
4. Only then create a new page.

Note when a new source **confirms** or **contradicts** existing claims, and keep both
sides with attribution under `## Disagreements`.

---

## Workflow: INGEST

Triggered by `/wiki-ingest`, by the user asking to ingest, or by `./tools/ingest.ps1`.

The queue holds two kinds of items:

- **Markdown files** — the converted text of a source.
- **Image files** (`.png`, `.jpg`, etc.) — standalone images. **Open each by its
  `inbox/` path with your read tool to view it** (you are multimodal). Treat each image
  as its own source: write a source page describing what it shows (any text, data,
  diagram contents, key visual details), and embed the original with `![[filename]]` so
  it can be re-examined later. Do not reduce a data-rich image (chart, table screenshot)
  to a vague caption — capture the actual values you can read.

For each item in `inbox/`:

1. **Read or view it.** For markdown, read it fully; if it references images in
   `raw/assets/`, read the text first then view those images separately.
2. **Check** `wiki/processed.md` to confirm it hasn't already been ingested, and
   `.llm-wiki/queue.json` for the raw path it came from.
3. **Write a source page** in `wiki/sources/` — summary, key takeaways, verbatim figures,
   and provenance (links to `processed/<file>` and `raw/<original>`).
4. **Create or update entity pages** in `wiki/entities/` for people, orgs, places,
   products, things mentioned. Search before creating.
5. **Create or update concept pages** in `wiki/concepts/` for ideas, frameworks, methods.
   Search before creating.
6. **Draw connections** — add `[[links]]` both ways, and explicitly note where this
   source confirms or contradicts existing pages.
7. **Update `wiki/index.md`** — add/refresh entries for every page you created or changed,
   and update the stats line.
8. **Append to `wiki/log.md`** one entry per source, using the exact prefix format:

   ```
   ## [2026-06-22] ingest | Source Title
   - Created: [[Page A]], [[Page B]]
   - Updated: [[Page C]]
   - Summary: one-line takeaway
   ```

9. **Record the outcome** in `.llm-wiki/ingest-status.json`, keeping the entries already
   in that file:

   ```json
   { "items": { "foo.md": { "status": "done", "note": "" } } }
   ```

   `status` is `done`, `failed`, or `skipped`. **Only files you mark `done` are
   archived** — a file you couldn't read, or only half-ingested, must not be marked
   done, or it will be filed away as if it had been. This is the one piece of
   bookkeeping the tooling cannot do for you: a clean exit code says you finished your
   turn, not that the source made it into the wiki.

A single source typically touches 10–15 wiki pages. After processing all files, report:
total pages created, total updated, any contradictions found, orphan pages to review,
and suggested synthesis pages.

> **Note:** You own `wiki/log.md`. The archive script (`mark-all-processed.ps1`) only
> records files in `wiki/processed.md` — it does not write the log.

---

## Workflow: BUILD (full pipeline)

Triggered by `/wiki-build`, or by "build the wiki", "process raw", "ingest everything".

1. **Convert** — run `pwsh ./tools/convert-all.ps1` to stage every file under `raw/`
   into the `inbox/` queue (documents become markdown; images are queued as-is). It
   recurses, and skips anything whose content hash is already in `wiki/processed.md`.
2. **Ingest** — perform the INGEST workflow above for every item now in `inbox/`,
   markdown and images alike, recording each outcome in `.llm-wiki/ingest-status.json`.
3. **Archive** — run `pwsh ./tools/mark-all-processed.ps1`, which files away only the
   items you marked `done`.
4. **Report** — files converted, pages created/updated, contradictions found, anything
   left in `inbox/` and why, suggested synthesis pages.

Never touch `raw/`.

---

## Workflow: QUERY

Triggered by `/wiki-query` or by a question. **Answer from the wiki and its sources, not
from memory.**

1. **Search** — grep `wiki/` for the terms and their synonyms. Use your own search
   tools; they are better than the helper script, which exists for the user's shell.
2. **Read the index** — `wiki/index.md` if search returns little.
3. **Read deeply** — open the most relevant pages before answering.
4. **Fall back to the source.** This is not optional. If the answer turns on a **figure,
   date, name, quotation, or any specific detail**, open the source page's archived text
   in `processed/` and read the passage. Wiki pages are summaries; summaries drop the
   footnote-level detail that precise questions are usually about. Answering "the wiki
   doesn't say" without having opened the cited source is a wrong answer.
5. **Synthesise** — concise answer, citing pages with `[[links]]` and, for specifics, the
   source and section you read it in.
6. **Be honest about gaps** — say when neither the wiki nor its sources cover it; don't
   invent facts, dates, names, or behaviour. Separate what the sources say from your own
   reasoning.
7. **Call out conflicts** — if pages or sources disagree, cite both and note it.
8. **Log it.** Append to `wiki/log.md`:

   ```
   ## [2026-06-22] query | the question, briefly
   - Consulted: [[Page A]], processed/foo.md
   - Answer: one-line summary
   ```

**File good answers back.** A comparison, analysis, or connection worth keeping should
become a `wiki/synthesis/` page (with the user's go-ahead) so explorations compound
instead of disappearing into chat. Offer this when an answer has lasting value.

---

## Workflow: LINT

Triggered by `/wiki-lint` or "lint the wiki". Health-check and report; don't auto-fix
unless asked.

Mechanical checks — do these by grep, and report exactly what you found, not what might
be missing:

- **Broken `[[links]]`** — targets with no matching file (check `aliases:` too).
- **Orphan pages** — no inbound links.
- **Missing or malformed frontmatter** — absent `type`, `created`, `updated`, `sources`.
- **Index drift** — pages missing from `wiki/index.md`, or listed there but deleted.
- **Uncited claims** — figures and dates on entity/concept pages with no source link.

Judgement calls — these need you, not grep:

- **Near-duplicate pages** — two pages that have drifted into the same idea. Propose a
  merge, name the survivor, and list the aliases it should absorb.
- **Contradictions** — pages that disagree. Propose a `## Disagreements` section rather
  than picking a winner.
- **Stale claims** — a page whose `last_verified` predates a newer source that touches
  the same subject. Flag it and propose `status: superseded` with a `supersedes:` link,
  so the replaced claim keeps its history instead of vanishing.
- **Missing pages** — concepts/entities mentioned often but lacking their own page.
- **Missing cross-references** — pages that should link but don't.
- **Data gaps** — questions a web search could fill; suggest sources to add.

Log the pass in `wiki/log.md` with a `lint` prefix, same format as the others.

---

## Operating rules

- **You write the wiki.** During ingest and lint you create and edit pages freely. During
  query you only write when the user asks you to file an answer.
- **Never modify `raw/`.** It is immutable.
- **Log every operation** — ingest, query, and lint. `wiki/log.md` is the record of how
  the wiki came to say what it says.
- **Keep `index.md` current** on every ingest — it is how the wiki is navigated at scale.
- **Run from the wiki root** so relative paths (`inbox/`, `wiki/index.md`) resolve.
- **The wiki is a git repo.** Commit before an ingest and after a clean one, so a bad
  run is one `git checkout` away from undone and the diff shows exactly what a source
  changed.
