# CLI Tools

PowerShell helpers for operating the LLM Wiki. The pipeline is a folder queue:
`raw/` → `inbox/` → (Sunny ingests) → `processed/`.

## Prerequisites

- **markitdown** — `pip install 'markitdown[all]'` (for converting non-markdown sources).
- **sunny** — the opencode CLI (sunny is a fork of opencode; `opencode` works too).

> **On the `sunny` name.** `install-alias.ps1` adds a `sunny` *function* to your
> PowerShell profile, and PowerShell resolves functions ahead of executables — so inside
> your shell, `sunny` is the wrapper, not the CLI. These scripts therefore resolve the
> CLI as an executable only (`Resolve-SunnyCli` in `_common.ps1`), never by plain name
> lookup. That is why the alias and the CLI can share a name. Pass `-SunnyCmd
> 'C:\path\to\sunny.exe'` if auto-detection ever fails.

---

### `_common.ps1` — shared helpers
Not run directly. Dot-sourced by the others; holds CLI resolution, content hashing, and
the two state files under `.llm-wiki/`.

---

### `convert-all.ps1` — stage raw/ → inbox/
Walks `raw/` **recursively** (excluding `raw/assets/`). Documents go through markitdown;
`.md` and image files are copied as-is (Sunny views images at ingest — it's multimodal).

Skipping is by **content hash**, not filename: a renamed source is still recognised as
ingested, and an edited one is queued again as a revision (`q3.r2.md`) so both texts
survive in `processed/`. A file in a subfolder is flattened into the queue name
(`raw/reports/q3.pdf` → `inbox/reports__q3.md`); its real path and hash go into
`.llm-wiki/queue.json`.

```powershell
./tools/convert-all.ps1
./tools/convert-all.ps1 -Force   # re-queue even if the content was already ingested
```

`raw/` is never modified.

---

### `convert-to-md.ps1` — convert a single file
```powershell
./tools/convert-to-md.ps1 article.pdf
./tools/convert-to-md.ps1 reports/q3.pdf -Force
```

---

### `ingest.ps1` — ingest the queue via Sunny
Gives each queued file **its own Sunny session** by default, so context bloat and
compaction can't degrade quality halfway through a batch. Runs from the wiki root so
`AGENTS.md` loads and relative paths resolve, and drives Sunny through the `wiki-ingest`
custom command in `.opencode/commands/`.

Archives nothing. Sunny records per-file results in `.llm-wiki/ingest-status.json`, and
only files marked `done` are archived later — a clean exit code means the agent finished
its turn, not that every source made it into the wiki.

```powershell
./tools/ingest.ps1                 # the whole queue, one session per file
./tools/ingest.ps1 -File foo.md    # one queued file
./tools/ingest.ps1 -Batch          # whole queue in a single session
./tools/ingest.ps1 -Auto           # auto-approve Sunny's edits (unattended)
./tools/ingest.ps1 -Inline         # send the full prompt instead of /wiki-ingest
./tools/ingest.ps1 -Attach         # attach images with --file instead of Sunny opening them
./tools/ingest.ps1 -DryRun         # print the commands, don't call Sunny
./tools/ingest.ps1 -SunnyCmd opencode
```

---

### `build.ps1` — the whole pipeline
convert → ingest → archive what succeeded.

```powershell
./tools/build.ps1
./tools/build.ps1 -Review    # stop before archiving
./tools/build.ps1 -Auto      # unattended
```

---

### `mark-all-processed.ps1` — archive what was ingested
Archives only the items Sunny marked `done`, and reports what it left behind and why.

```powershell
./tools/mark-all-processed.ps1 "optional notes"
./tools/mark-all-processed.ps1 -Force    # archive the whole queue regardless
```

---

### `mark-processed.ps1` — archive one file
Moves one file from `inbox/` to `processed/` and records it in `wiki/processed.md` with
its raw source path and content hash. Upgrades an older four-column table in place the
first time it writes. (Does **not** write `wiki/log.md` — Sunny owns the log.)

```powershell
./tools/mark-processed.ps1 article.md "Key insight from this source"
```

---

### `check-duplicate.ps1` — already ingested?
Answered by content hash, with the filename as a weaker fallback. Exit 0 = new or
changed, exit 1 = already ingested.

```powershell
./tools/check-duplicate.ps1 article.pdf
./tools/check-duplicate.ps1 reports/q3.pdf
```

---

### `search-wiki.ps1` — search wiki pages (for you)
Multi-term search across `wiki/`: every term must appear in the page. This is for your
shell — **Sunny should use its own grep**, which is better than shelling out to this.

```powershell
./tools/search-wiki.ps1 "machine learning"
./tools/search-wiki.ps1 transformer attention    # pages containing both
./tools/search-wiki.ps1 -Regex "\bGPT-\d" -Context 1
```

Swap in a real search engine (e.g. qmd, for hybrid BM25/vector search) as the wiki grows.

---

### `sunny.ps1` — the front door
```powershell
./tools/sunny.ps1 -Build                   # convert -> ingest -> archive
./tools/sunny.ps1 -Ingest                  # = ingest.ps1
./tools/sunny.ps1 -Query "what about X?"   # ask the wiki (/wiki-query)
./tools/sunny.ps1 -Lint                    # health check (/wiki-lint)
./tools/sunny.ps1 -Status                  # page counts, queue, recent activity
./tools/sunny.ps1 -Prompt "..."            # free-form prompt from the wiki root
```

---

### `install-alias.ps1` — install the `sunny` command
Adds a `sunny` function to your PowerShell profile so you can run `sunny -Ingest` etc.
from anywhere. Safe alongside the sunny CLI — see the note at the top.

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
# 3. Ingest via Sunny (one session per source)
./tools/ingest.ps1
# 4. Review in Obsidian
# 5. Archive what succeeded
./tools/mark-all-processed.ps1
```

Or all of it at once: `./tools/build.ps1`.

## State files

| File | Written by | Holds |
|------|-----------|-------|
| `.llm-wiki/queue.json` | `convert-all.ps1` | queued file → raw source path + content hash |
| `.llm-wiki/ingest-status.json` | Sunny, during ingest | per-file `done`/`failed`/`skipped` |
| `wiki/processed.md` | the archive step | the audit table: date, file, source, hash |

## Notes

- Review converted markdown in `inbox/` before ingest to catch conversion errors.
- For images, set Obsidian's attachment path to `raw/assets/` so Sunny can view them.
- Run scripts from anywhere — they resolve paths relative to the `tools/` folder — but
  Sunny itself is always invoked from the wiki root.
