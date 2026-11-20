---
description: Run the full pipeline — convert raw/, ingest, archive what succeeded
---
Build the wiki end to end, following the BUILD workflow in
`.opencode/llm-wiki/schema.md`.

Notes from me (optional): $ARGUMENTS

1. Run `pwsh ./tools/convert-all.ps1` to stage every file under `raw/` into the `inbox/`
   queue. It recurses into subfolders, converts documents to markdown, copies markdown
   and images as-is, and skips anything whose content hash is already recorded in
   `wiki/processed.md`.
2. Ingest every item now in `inbox/`, markdown and images alike, following the INGEST
   workflow. Record each outcome in `.llm-wiki/ingest-status.json` as you go — `done`
   only for sources that genuinely made it into the wiki.
3. Run `pwsh ./tools/mark-all-processed.ps1`. It archives only the items you marked
   `done` and leaves the rest in `inbox/` for another pass.
4. Report: files converted, pages created and updated, contradictions found, what is
   still sitting in `inbox/` and why, and any synthesis pages worth writing.

Never modify `raw/`.
