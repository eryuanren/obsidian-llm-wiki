---
description: Ingest queued sources from inbox/ into the wiki
---
Ingest into the wiki, following the INGEST workflow in `.opencode/llm-wiki/schema.md`.

Items to ingest: $ARGUMENTS

If no items are named above, ingest everything currently in `inbox/` except `.gitkeep`.

For each item, in order:

1. Read it. If it is an image (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`,
   `.tif`, `.tiff`), open it by its `inbox/` path with your read tool and view it — you
   are multimodal. Treat a standalone image as its own source: capture the actual values
   you can read from any chart or table, and embed the original with `![[filename]]`.
2. Check `wiki/processed.md` to confirm it hasn't already been ingested, and read
   `.llm-wiki/queue.json` for the raw file it came from — the queue name may be
   flattened (`reports__q3.md` came from `raw/reports/q3.pdf`).
3. Write a source page in `wiki/sources/`, keeping figures, dates and quotations
   verbatim, and linking to both `processed/<file>` and `raw/<original>`.
4. Search the wiki before creating any entity or concept page. If one already covers the
   idea under another name, update it and add the name to its `aliases:` instead of
   creating a second page.
5. Create or update the entity and concept pages this source touches, adding `[[links]]`
   both ways. Where it confirms or contradicts an existing claim, say so on the page,
   with attribution, under `## Disagreements`.
6. Update `wiki/index.md`, including the stats line.
7. Append one entry per source to `wiki/log.md` using the documented prefix format.
8. Record the outcome in `.llm-wiki/ingest-status.json`, preserving entries already
   there:

   ```json
   { "items": { "<inbox filename>": { "status": "done", "note": "" } } }
   ```

   Use `done` only when the source is genuinely in the wiki. Use `failed` or `skipped`
   otherwise, with a short note. Only `done` items get archived — marking a half-ingested
   file `done` buries it.

Do not modify `raw/`. Do not archive anything yourself; the tooling does that.

When finished, report: pages created, pages updated, contradictions found, anything you
could not ingest and why, and any synthesis pages worth writing.
