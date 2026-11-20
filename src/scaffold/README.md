# LLM Wiki

A personal knowledge base that an LLM agent (**Sunny**, via sunny/opencode) builds and
maintains for you. Instead of retrieving from raw documents on every query (RAG), Sunny
compiles your sources once into a structured, interlinked wiki and keeps it current as
you add more.

Based on the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## The pipeline

```
raw/         →  inbox/          →  (Sunny ingests)  →  processed/
originals       converted .md       wiki/ updated        the retrieval layer
(immutable)     (the queue)         (pages, index, log)
```

1. **Add sources** — drop any files (PDF, DOCX, HTML, MD, images, …) into `raw/`,
   in subfolders if you like.
2. **Convert** — `./tools/convert-all.ps1` stages them into `inbox/` (documents become
   markdown; images are queued as-is for Sunny to view).
3. **Ingest** — `./tools/ingest.ps1` gives each queued file its own Sunny session, which
   reads it, reads the current wiki, and creates or updates pages accordingly.
4. **Review** — browse the new pages in Obsidian.
5. **Archive** — `./tools/mark-all-processed.ps1` files away what Sunny marked done.

`raw/` is never modified — it's your immutable source of truth.

### Install the `sunny` command

```powershell
./tools/install-alias.ps1
# then, from anywhere:
sunny -Build | sunny -Ingest | sunny -Query "..." | sunny -Lint | sunny -Status
```

## Structure

```
llm-wiki/
├── raw/          # immutable original sources (any type); assets/ for images
├── inbox/        # converted markdown awaiting ingest (the queue)
├── processed/    # ingested sources — kept, and read back when detail is needed
├── wiki/         # the LLM-maintained knowledge base
│   ├── entities/   # people, orgs, places, products, things
│   ├── concepts/   # ideas, theories, frameworks
│   ├── sources/    # one summary page per ingested source
│   ├── synthesis/  # cross-source analysis & filed-back answers
│   ├── index.md    # content catalog
│   ├── log.md      # chronological activity record (ingest, query, lint)
│   └── processed.md# audit table: file, source, content hash
├── tools/        # PowerShell helpers
├── .llm-wiki/    # pipeline state (queue manifest, ingest status)
├── .opencode/    # the schema and Sunny's custom commands (plugin-owned)
└── AGENTS.md     # YOUR rules — never overwritten by a plugin update
```

## How it works

Unlike RAG, which re-derives knowledge on every query, this system:

- **Compiles knowledge once** into structured wiki pages.
- **Maintains cross-references** with `[[wiki links]]`.
- **Updates existing pages** when new sources arrive, flagging contradictions.
- **Files answers back** into `wiki/synthesis/` so explorations compound.

### A map, not a replacement for the territory

Compiling a source into a summary drops detail — exact figures, dates, caveats. So the
wiki's job is to tell you *what is known and where it is recorded*, and when a question
turns on a specific value, Sunny opens the cited source in `processed/` and reads the
passage. Summaries alone answer fewer questions than summaries plus the sources they
point at.

### Where the rules live

- `AGENTS.md` — **yours.** Your conventions, your house style, your topics. A plugin
  update never touches it.
- `.opencode/llm-wiki/schema.md` — the plugin's schema: page conventions and the
  INGEST / QUERY / LINT / BUILD workflows. Replaced on update, so don't edit it.
- `.opencode/commands/` — the workflows as Sunny commands (`/wiki-ingest`, `/wiki-query`,
  `/wiki-lint`, `/wiki-build`), so the procedures aren't loaded into every conversation.

## Operations

**Ingest** — `./tools/ingest.ps1`, or `sunny -Ingest`. One session per source. Sunny
writes source/entity/concept pages, updates the index, appends to the log, and records
per-file results so only what actually succeeded gets archived.

**Query** — `sunny -Query "..."`. Sunny searches the wiki, reads the relevant pages, then
opens the cited source when the answer turns on a figure, date or quotation. Good answers
can be filed back as synthesis pages.

**Lint** — `sunny -Lint`. Broken links, orphans, index drift and uncited claims by grep;
then near-duplicate pages, contradictions and stale claims by judgement.

## Using with Obsidian

1. Open this folder as your Obsidian vault.
2. Use Graph View to see connections emerge.
3. Keep Sunny on one side, Obsidian on the other, and watch edits land in real time.

## Tips

- Review the first few ingests to guide Sunny's emphasis.
- Commit before an ingest. The agent edits freely; the diff is how you see what a source
  actually changed, and `git checkout` is how you undo a bad run.
- Run lint periodically. Near-duplicate pages are the failure mode that creeps up on you.
- Let answers compound — file good ones as synthesis pages.

Your job: curate sources, ask good questions, think about meaning. Sunny's job: everything else.
