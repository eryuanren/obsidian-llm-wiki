# LLM Wiki

A personal knowledge base that an LLM agent (**Sunny**, via opencode) builds and maintains
for you. Instead of retrieving from raw documents on every query (RAG), Sunny compiles your
sources once into a structured, interlinked wiki and keeps it current as you add more.

Based on the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## The pipeline

```
raw/         →  inbox/          →  (Sunny ingests)  →  processed/
originals       converted .md       wiki/ updated        archived .md
(immutable)     (the queue)         (pages, index, log)
```

1. **Add sources** — drop any files (PDF, DOCX, HTML, MD, images, …) into `raw/`.
2. **Convert** — `./tools/convert-all.ps1` stages them into `inbox/` (documents become
   markdown; images are queued as-is for Sunny to view).
3. **Ingest** — `./tools/ingest.ps1` hands the queue to Sunny, which reads each file,
   reads the current wiki + index, and creates/updates pages accordingly.
4. **Review** — browse the new pages in Obsidian.
5. **Archive** — `./tools/mark-all-processed.ps1` moves the queue into `processed/`.

`raw/` is never modified — it's your immutable source of truth.

### Install the `sunny` command (optional)

```powershell
./tools/install-alias.ps1
# then, from anywhere: sunny -Ingest | sunny -Status | sunny -Prompt "lint the wiki"
```

## Structure

```
llm-wiki/
├── raw/          # immutable original sources (any type); assets/ for images
├── inbox/        # converted markdown awaiting ingest (the queue)
├── processed/    # converted markdown already ingested (archive)
├── wiki/         # the LLM-maintained knowledge base
│   ├── entities/   # people, orgs, places, products, things
│   ├── concepts/   # ideas, theories, frameworks
│   ├── sources/    # one summary page per ingested source
│   ├── synthesis/  # cross-source analysis & filed-back answers
│   ├── index.md    # content catalog
│   ├── log.md      # chronological activity record
│   └── processed.md# audit table of ingested files
├── tools/        # PowerShell helpers
└── AGENTS.md     # the schema — how Sunny operates (ingest / query / lint)
```

## How it works

Unlike RAG, which re-derives knowledge on every query, this system:

- **Compiles knowledge once** into structured wiki pages.
- **Maintains cross-references** with `[[wiki links]]`.
- **Updates existing pages** when new sources arrive, flagging contradictions.
- **Files answers back** into `wiki/synthesis/` so explorations compound.

The schema in `AGENTS.md` is what makes Sunny a disciplined maintainer rather than a
generic chatbot. You and Sunny co-evolve it as your needs become clearer.

## Operations

**Ingest** — `./tools/ingest.ps1`. Sunny reads queued sources, writes source/entity/concept
pages, updates the index, and appends to the log.

**Query** — ask Sunny questions. It searches the wiki, reads relevant pages, and answers
with citations. Good answers can be filed back as synthesis pages.

**Lint** — `./tools/sunny.ps1 -Prompt "lint the wiki"`. Sunny reports orphan pages,
contradictions, stale claims, missing pages, and data gaps.

## Using with Obsidian

1. Open `llm-wiki/` as your Obsidian vault.
2. Use Graph View to see connections emerge.
3. Keep Sunny on one side, Obsidian on the other, and watch edits land in real time.

## Tips

- Review the first few ingests to guide Sunny's emphasis.
- Run lint periodically to keep the wiki healthy.
- Let answers compound — file good ones as synthesis pages.
- The wiki is a git repo: you get version history for free.

Your job: curate sources, ask good questions, think about meaning. Sunny's job: everything else.
