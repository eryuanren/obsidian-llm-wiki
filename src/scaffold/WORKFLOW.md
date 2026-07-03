# LLM Wiki Workflow

From raw files to a maintained knowledge base, end to end.

The pipeline is a folder queue:

```
raw/  →  inbox/  →  (Sunny ingests, writes wiki/)  →  processed/
```

`raw/` holds your originals and is never modified. `inbox/` is the queue of converted
markdown waiting to be ingested. `processed/` is where that markdown goes once it's done.

---

## Phase 1 — Add and convert sources

Drop any source files into `raw/` (PDF, DOCX, HTML, TXT, MD, …), then:

```powershell
./tools/convert-all.ps1
```

This converts every document with `markitdown`, copies any `.md` files as-is, and queues
any **image files** (`.png`, `.jpg`, `.gif`, `.webp`, …) as-is into `inbox/`. Images
aren't converted to text here — Sunny is multimodal and views them directly at ingest.
Items already queued are skipped; use `-Force` to redo.

```
Found 3 file(s) in raw/
Converting: article.pdf  OK
Converting: paper.docx   OK
Converting: notes.md     (copied)

Done: 3 converted, 0 skipped, 0 failed
Markdown is queued in inbox/. Next: ./tools/ingest.ps1
```

Single file instead of the whole folder: `./tools/convert-to-md.ps1 article.pdf`.

---

## Phase 2 — Ingest

```powershell
./tools/ingest.ps1
```

This finds everything in `inbox/`, builds a prompt, and calls Sunny (`sunny run`, or
`opencode run`) **from the wiki root** so it loads `AGENTS.md` and resolves relative paths.

`ingest.ps1` lists any queued **image files** by path and tells Sunny to open them with
its read tool, so its vision model sees them. Following the INGEST workflow in `AGENTS.md`,
Sunny will, for each item:

- read the markdown (and any images it references in `raw/assets/`), or **view** a
  standalone image and write a source page describing what it shows,
- write a source page in `wiki/sources/`,
- create or update entity pages in `wiki/entities/` and concept pages in `wiki/concepts/`,
- add `[[links]]` both ways and flag any contradictions with existing pages,
- update `wiki/index.md`,
- append an entry to `wiki/log.md` (`## [YYYY-MM-DD] ingest | Title`).

A single source typically touches 10–15 pages. When it finishes, Sunny reports pages
created/updated, contradictions found, and suggested synthesis pages.

> Prefer to ingest one file at a time and stay involved on early sources:
> `./tools/ingest.ps1 -File article.md`. Batch the whole inbox once you trust the output.

> Want to see the prompt without calling Sunny? `./tools/ingest.ps1 -DryRun`.

---

## Phase 3 — Review and archive

Open the vault in Obsidian and review the new/updated pages and the graph. When happy:

```powershell
./tools/mark-all-processed.ps1            # or per file: ./tools/mark-processed.ps1 article.md "notes"
```

This moves the ingested markdown from `inbox/` to `processed/` and records each file in
`wiki/processed.md`. (Sunny owns `wiki/log.md`; the archive step only writes the audit
table, so there's no double logging.)

To check whether a file was already ingested: `./tools/check-duplicate.ps1 article.pdf`.

---

## Phase 4 — Query and grow

Ask Sunny questions against the wiki:

```
"What are the main themes across all sources?"
"Compare X and Y approaches."
"What does [Author] say about Z?"
```

Sunny searches (`search-wiki.ps1`), reads relevant pages, and answers with `[[citations]]`.
**File valuable answers back** as `wiki/synthesis/` pages so they compound:

```
"Create a synthesis page comparing X and Y."
```

Run a health check periodically:

```powershell
./tools/sunny.ps1 -Prompt "lint the wiki"
```

Sunny reports orphan pages, contradictions, stale claims, missing pages, and data gaps.

---

## Visual summary

```
PHASE 1: CONVERT
  raw/article.pdf ─┐
  raw/paper.docx ──┼─ ./tools/convert-all.ps1 ─→ inbox/*.md
  raw/notes.md ────┘

PHASE 2: INGEST
  ./tools/ingest.ps1 ─→ sunny run (from wiki root, uses AGENTS.md)
     creates/updates wiki/sources, entities, concepts
     updates wiki/index.md, appends wiki/log.md

PHASE 3: REVIEW + ARCHIVE
  review in Obsidian ─→ ./tools/mark-all-processed.ps1 ─→ inbox/*.md moved to processed/

PHASE 4: QUERY + GROW
  ask Sunny ─→ searches + reads + answers with citations
  file good answers ─→ wiki/synthesis/*.md
  ./tools/sunny.ps1 -Prompt "lint the wiki"  (periodic health check)
```

---

## File states

| Location          | Purpose                              | Who writes        |
|-------------------|--------------------------------------|-------------------|
| `raw/`            | Original sources (immutable)         | Human             |
| `inbox/`          | Markdown + images awaiting ingest    | `convert-all.ps1` |
| `processed/`      | Items already ingested               | archive step      |
| `wiki/sources/`   | Source summaries                     | Sunny             |
| `wiki/entities/`  | People, orgs, places, things         | Sunny             |
| `wiki/concepts/`  | Ideas, frameworks                    | Sunny             |
| `wiki/synthesis/` | Cross-source analysis                | Sunny (when asked)|
| `wiki/index.md`   | Content catalog                      | Sunny             |
| `wiki/log.md`     | Activity timeline                    | Sunny             |
| `wiki/processed.md`| Audit table of ingested files       | archive step      |

---

## Quick reference

```powershell
./tools/convert-all.ps1                 # convert raw/ -> inbox/
./tools/convert-to-md.ps1 file.pdf      # convert one file
./tools/ingest.ps1                      # ingest the whole inbox via Sunny
./tools/ingest.ps1 -File file.md        # ingest one queued file
./tools/ingest.ps1 -DryRun              # show the prompt, don't call Sunny
./tools/mark-all-processed.ps1          # archive inbox/ -> processed/
./tools/mark-processed.ps1 file.md "n"  # archive one file
./tools/check-duplicate.ps1 file.pdf    # already ingested?
./tools/search-wiki.ps1 "query"         # search wiki pages
./tools/sunny.ps1 -Status               # wiki stats + queue + recent activity
./tools/sunny.ps1 -Prompt "lint the wiki"
```

## Tips

1. Review early ingests to guide Sunny's emphasis.
2. Use Obsidian Graph View to watch connections emerge.
3. Run lint periodically as the wiki grows.
4. File good answers as synthesis pages so explorations compound.
5. One file at a time when you want tight quality control; batch when you trust it.
6. `./tools/sunny.ps1 -Status` shows how many files are queued vs. archived.
