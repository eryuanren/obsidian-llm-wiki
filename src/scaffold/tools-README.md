# CLI Tools

PowerShell helpers for operating the LLM Wiki. The pipeline is a folder queue:
`raw/` → `inbox/` → (Sunny ingests) → `processed/`.

## Prerequisites

- **markitdown** — `pip install markitdown` (for converting non-markdown sources).
- **sunny** — the opencode CLI (`sunny` is the same as `opencode`). Scripts call
  `sunny run` and fall back to `opencode run` if `sunny` isn't on PATH.

---

### `convert-all.ps1` — stage raw/ → inbox/
Stages every source in `raw/` into `inbox/`. Documents go through markitdown; `.md` files
are copied; **image files are queued as-is** (Sunny views them at ingest — it's
multimodal). Already-queued items are skipped.

```powershell
./tools/convert-all.ps1
./tools/convert-all.ps1 -Force   # re-convert even if output exists
```

`raw/` is never modified.

---

### `convert-to-md.ps1` — convert a single file
```powershell
./tools/convert-to-md.ps1 article.pdf
./tools/convert-to-md.ps1 article.pdf -Force
```

---

### `ingest.ps1` — ingest the queue via Sunny
Finds the markdown **and image** items in `inbox/`, builds a prompt, and runs Sunny from
the wiki root so it loads `AGENTS.md`. Image items are listed by path; Sunny opens them
with its read tool to view them. Sunny creates/updates wiki pages, the index, and the log.

```powershell
./tools/ingest.ps1                 # ingest everything in inbox/
./tools/ingest.ps1 -File foo.md    # ingest one queued file
./tools/ingest.ps1 -DryRun         # print the prompt, don't call Sunny
./tools/ingest.ps1 -SunnyCmd opencode
```

After review, archive with `mark-all-processed.ps1`.

---

### `mark-all-processed.ps1` — archive the whole queue
Moves every `.md` in `inbox/` to `processed/` and records each in `wiki/processed.md`.

```powershell
./tools/mark-all-processed.ps1 "optional notes"
```

---

### `mark-processed.ps1` — archive one file
Moves one file from `inbox/` to `processed/` and records it in `wiki/processed.md`.
(Does **not** write `wiki/log.md` — Sunny owns the log during ingest.)

```powershell
./tools/mark-processed.ps1 article.md "Key insight from this source"
```

---

### `check-duplicate.ps1` — already ingested?
Checks `processed/` and `wiki/processed.md`. Exit 0 = new, exit 1 = duplicate.

```powershell
./tools/check-duplicate.ps1 article.pdf
```

---

### `search-wiki.ps1` — search wiki pages
Naive full-text search across `wiki/`. Enough at small scale; swap in a real search
engine (e.g. qmd) as the wiki grows.

```powershell
./tools/search-wiki.ps1 "machine learning"
```

---

### `sunny.ps1` — Sunny wrapper
```powershell
./tools/sunny.ps1 -Ingest                  # = ingest.ps1
./tools/sunny.ps1 -Status                  # page counts, queue, recent activity
./tools/sunny.ps1 -Prompt "lint the wiki"  # custom prompt (runs sunny run from wiki root)
```

---

### `install-alias.ps1` — install the `sunny` command
Adds a `sunny` function to your PowerShell profile so you can run `sunny -Ingest` etc.
from anywhere.

```powershell
./tools/install-alias.ps1
```

---

### `invoke-sunny.ps1` — deprecated
Kept for backward compatibility; forwards to `ingest.ps1`. Use `ingest.ps1` directly.

---

## Typical flow

```powershell
# 1. Drop sources into raw/
# 2. Convert to the queue
./tools/convert-all.ps1
# 3. Ingest via Sunny
./tools/ingest.ps1
# 4. Review in Obsidian
# 5. Archive the queue
./tools/mark-all-processed.ps1
```

## Notes

- Review converted markdown in `inbox/` before ingest to catch conversion errors.
- For images, set Obsidian's attachment path to `raw/assets/` so Sunny can view them.
- Run scripts from anywhere — they resolve paths relative to the `tools/` folder — but
  Sunny itself is always invoked from the wiki root.
