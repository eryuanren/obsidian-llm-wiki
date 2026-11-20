# LLM Wiki Workflow

From raw files to a maintained knowledge base, end to end.

The pipeline is a folder queue:

```
raw/  →  inbox/  →  (Sunny ingests, writes wiki/)  →  processed/
```

`raw/` holds your originals and is never modified. `inbox/` is the queue waiting to be
ingested. `processed/` is where it goes once it's done — and it is not a graveyard: it's
the full text of every source, the layer Sunny falls back to when a wiki page is too
coarse to answer a question.

---

## Phase 1 — Add and convert sources

Drop any source files into `raw/` (PDF, DOCX, HTML, TXT, MD, images, …), then:

```powershell
./tools/convert-all.ps1
```

This walks `raw/` **recursively** (so Web Clipper folders and other nested sources are
picked up, `raw/assets/` excepted), converts documents with `markitdown`, and copies
markdown and image files as-is. Images aren't converted to text — Sunny is multimodal
and views them at ingest.

A file in a subfolder is flattened into the queue name, so `raw/reports/q3.pdf` is
queued as `inbox/reports__q3.md`. Its real path and content hash are recorded in
`.llm-wiki/queue.json`, which Sunny reads for provenance.

**Skipping is by content, not filename.** The content hash of each raw file is checked
against `wiki/processed.md`:

- rename a source → still recognised as ingested, not re-done;
- edit a source → recognised as new, and queued as a revision (`q3.r2.md`) so both the
  old and new text survive in `processed/`.

```
Found 3 file(s) under raw/
Processing: raw/article.pdf  OK
Processing: raw/reports/q3.docx  OK
Skip (already ingested): raw/notes.md

Done: 2 queued, 1 skipped, 0 failed
Queued in inbox/. Next: ./tools/ingest.ps1
```

Single file instead of the whole folder: `./tools/convert-to-md.ps1 reports/q3.pdf`.

---

## Phase 2 — Ingest

```powershell
./tools/ingest.ps1
```

**One source per session.** Each queued file gets its own `sunny run`, so a long batch
can't let context bloat and compaction degrade quality halfway through. Use `-Batch` for
one session covering the whole queue.

Sunny is driven through the `wiki-ingest` custom command in `.opencode/commands/`, so
the procedure lives next to the wiki rather than buried in a script. Runs happen **from
the wiki root**, so `AGENTS.md` loads and relative paths resolve. For each item Sunny:

- reads the markdown (and any images it references in `raw/assets/`), or **views** a
  standalone image and writes a source page describing what it shows,
- writes a source page in `wiki/sources/`, keeping figures and quotations verbatim,
- **searches before creating** an entity or concept page, updating an existing page and
  extending its `aliases:` rather than spawning a near-duplicate,
- adds `[[links]]` both ways and records contradictions under `## Disagreements`,
- updates `wiki/index.md` and appends to `wiki/log.md`,
- **records the outcome** for each file in `.llm-wiki/ingest-status.json`.

That last step is what makes archiving safe. A clean exit code only means the agent
finished its turn — not that every file made it into the wiki. Only files Sunny marks
`done` are archived.

```
[1/2] Ingest article.md
[2/2] Ingest reports__q3.md

=== Ingest finished ===
Marked done by Sunny: 1 of 2
Not marked done (will NOT be archived):
  - reports__q3.md (failed)
```

Useful flags:

| Flag | What it does |
|------|--------------|
| `-File foo.md` | ingest a single queued file |
| `-Batch` | whole queue in one session |
| `-Auto` | auto-approve Sunny's file edits, for unattended runs |
| `-DryRun` | print the commands, don't call Sunny |
| `-Attach` | pass images with `--file` instead of letting Sunny open them |
| `-SunnyCmd <path>` | use a specific CLI |

---

## Phase 3 — Review and archive

Open the vault in Obsidian and review the new pages and the graph. When happy:

```powershell
./tools/mark-all-processed.ps1
```

This archives **only what Sunny marked done**, moving it from `inbox/` to `processed/`
and recording each file in `wiki/processed.md` with its source path and content hash.
Anything else stays in `inbox/` for another pass, listed with the reason. Use `-Force`
to archive the whole queue regardless.

Per file: `./tools/mark-processed.ps1 article.md "notes"`.
Already ingested? `./tools/check-duplicate.ps1 reports/q3.pdf` — answered by content hash.

---

## Phase 4 — Query and grow

```powershell
sunny -Query "what did the Q3 report say about margin?"
```

Sunny searches the wiki, reads the relevant pages, **and then opens the cited source in
`processed/`** when the answer turns on a figure, date, name or quotation. That fallback
is the point: wiki pages are summaries, and summaries drop the footnote-level detail
that precise questions are usually about.

**File valuable answers back** as `wiki/synthesis/` pages so explorations compound:

```
"Create a synthesis page comparing X and Y."
```

Run a health check periodically:

```powershell
sunny -Lint
```

Sunny reports broken links, orphans, index drift and uncited claims from grep — then the
judgement calls: near-duplicate pages that have drifted into the same idea, contradictions,
and stale claims whose `last_verified` predates a newer source.

---

## Visual summary

```
PHASE 1: CONVERT
  raw/article.pdf ─────┐
  raw/reports/q3.docx ─┼─ ./tools/convert-all.ps1 ─→ inbox/  (+ .llm-wiki/queue.json)
  raw/notes.md ────────┘   recursive, skips by content hash

PHASE 2: INGEST
  ./tools/ingest.ps1 ─→ one `sunny run --command wiki-ingest` per file, from the wiki root
     creates/updates wiki/sources, entities, concepts
     updates wiki/index.md, appends wiki/log.md
     writes .llm-wiki/ingest-status.json  ← decides what may be archived

PHASE 3: REVIEW + ARCHIVE
  review in Obsidian ─→ ./tools/mark-all-processed.ps1
     archives only the items marked done; the rest stay queued

PHASE 4: QUERY + GROW
  sunny -Query "..." ─→ wiki pages first, then the cited source in processed/
  file good answers ─→ wiki/synthesis/*.md
  sunny -Lint                                  (periodic health check)
```

---

## File states

| Location            | Purpose                              | Who writes        |
|---------------------|--------------------------------------|-------------------|
| `raw/`              | Original sources (immutable)         | Human             |
| `inbox/`            | Markdown + images awaiting ingest    | `convert-all.ps1` |
| `processed/`        | Ingested sources — the retrieval layer | archive step    |
| `.llm-wiki/`        | Queue manifest + ingest status       | tooling + Sunny   |
| `.opencode/`        | Schema and custom commands           | the plugin        |
| `AGENTS.md`         | **Your** rules — never overwritten   | Human             |
| `wiki/sources/`     | Source summaries                     | Sunny             |
| `wiki/entities/`    | People, orgs, places, things         | Sunny             |
| `wiki/concepts/`    | Ideas, frameworks                    | Sunny             |
| `wiki/synthesis/`   | Cross-source analysis                | Sunny (when asked)|
| `wiki/index.md`     | Content catalog                      | Sunny             |
| `wiki/log.md`       | Activity timeline (ingest/query/lint)| Sunny             |
| `wiki/processed.md` | Audit table with source + hash       | archive step      |

---

## Quick reference

```powershell
./tools/convert-all.ps1                 # convert raw/ -> inbox/ (recursive, hash-skip)
./tools/convert-to-md.ps1 file.pdf      # convert one file
./tools/ingest.ps1                      # ingest the queue, one session per file
./tools/ingest.ps1 -File file.md        # ingest one queued file
./tools/ingest.ps1 -Batch -Auto         # whole queue, one session, unattended
./tools/ingest.ps1 -DryRun              # show the commands, don't call Sunny
./tools/mark-all-processed.ps1          # archive what Sunny marked done
./tools/mark-all-processed.ps1 -Force   # archive the whole queue regardless
./tools/check-duplicate.ps1 file.pdf    # already ingested? (by content hash)
./tools/search-wiki.ps1 term1 term2     # search wiki pages (for you, not Sunny)
sunny -Status                           # wiki stats + queue + recent activity
sunny -Query "question"                 # ask the wiki
sunny -Lint                             # health check
```

Install the `sunny` command once with `./tools/install-alias.ps1`.

## Tips

1. Review early ingests to guide Sunny's emphasis.
2. Commit before an ingest. The agent edits freely, and a bad run is then one
   `git checkout` away from undone — and the diff shows exactly what a source changed.
3. Use Obsidian Graph View to watch connections emerge.
4. Run lint periodically as the wiki grows; near-duplicate pages are the failure mode
   that creeps up on you.
5. File good answers as synthesis pages so explorations compound.
6. Put your own conventions in `AGENTS.md` — plugin updates never touch it.
7. `sunny -Status` shows how many files are queued, archived, or waiting to be archived.
