# LLM Wiki (Obsidian plugin)

Turn any Obsidian vault into an **LLM-maintained wiki** with one command, then drive the
whole convert → ingest → archive pipeline through [OpenCode](https://github.com/mtymek/opencode-obsidian).

This is the Obsidian-native version of the `init-wiki.ps1` setup script: instead of running
PowerShell, you run a command inside Obsidian and the plugin scaffolds the entire structure
(folders, the `AGENTS.md` schema, the `tools/` scripts, and fresh wiki seeds) directly into
your vault using Obsidian's own file API — cross-platform, no shell required.

It implements the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f):
rather than re-deriving knowledge from raw documents on every query (RAG), an agent (**Sunny**)
compiles your sources once into a structured, interlinked wiki and keeps it current.

## Install

**Manual (simplest):**

1. Download `main.js`, `manifest.json`, and `styles.css` from the
   [latest release](../../releases/latest).
2. Put them in your vault at `.obsidian/plugins/llm-wiki/`.
3. In Obsidian: Settings → Community plugins → turn off Restricted Mode, then enable **LLM Wiki**.

**Via BRAT** (auto-updates): install the
[BRAT](https://github.com/TfTHacker/obsidian42-brat) plugin, then "Add beta plugin" and paste
this repo's URL.

## What it does

**Set up LLM Wiki in this vault** creates:

```
raw/            immutable source files (any type); assets/ for images
inbox/          converted markdown awaiting ingest (the queue)
processed/      converted markdown already ingested
wiki/           the knowledge base Sunny maintains
  entities/  concepts/  sources/  synthesis/
  index.md   log.md   processed.md
tools/          the PowerShell pipeline scripts
AGENTS.md       the schema — how Sunny ingests, answers, and lints
WORKFLOW.md     the end-to-end workflow guide
README.md       vault-level readme
```

Then the pipeline commands hand a prompt to Sunny through the OpenCode plugin:

- **Build wiki (convert → ingest → archive)** — the full pipeline in one prompt.
- **Ingest inbox into the wiki** — ingest only, so you can review before archiving.
- **Lint the wiki** — health check (orphans, contradictions, stale claims, gaps).
- **Send a custom prompt to Sunny** — ask anything against the wiki.
- **Open OpenCode panel** — convenience toggle.

## Commands & ribbon

All actions are available from the Command Palette. A ribbon icon (📖) runs setup; it can be
turned off in settings.

## Prompt delivery

The pipeline commands need the [`opencode-obsidian`](https://github.com/mtymek/opencode-obsidian)
plugin (which embeds OpenCode/Sunny). Two delivery modes (Settings → LLM Wiki):

- **Copy to clipboard & open panel** *(default, reliable)* — opens the OpenCode panel and
  copies the prompt; you paste it and press Enter, and watch the run live.
- **Send automatically via OpenCode API** *(experimental)* — starts the OpenCode server and
  posts the prompt straight to its REST API. Falls back to the clipboard hand-off if anything
  fails.

## Prerequisites

The scaffolding step needs nothing but Obsidian. To actually run the pipeline you need:

1. **`opencode-obsidian`** plugin installed and enabled (the AI panel).
2. **`opencode` / `sunny` CLI** on your PATH (the AI engine).
3. **`markitdown`** for converting PDFs/DOCX etc.: `pip install 'markitdown[all]'`.

The setup summary shows a live checklist of these.

## Safety

- `raw/` sources and existing `wiki/` pages are **never** modified.
- Re-running setup refreshes only the methodology/tool files (`AGENTS.md`, `WORKFLOW.md`,
  `tools/*`). Your `wiki/index.md`, `log.md`, and `processed.md` are **never overwritten**, so
  a re-run can't wipe an existing wiki.

## Development

```bash
npm install
npm run dev      # watch build → main.js
npm run build    # type-check + production bundle
```

The scaffold source files live under `src/scaffold/` as real `.md`/`.ps1` files and are inlined
into `main.js` at build time via esbuild's `text` loader, so they stay readable and editable.

To test in Obsidian, copy `main.js`, `manifest.json`, and `styles.css` into
`<vault>/.obsidian/plugins/llm-wiki/` and enable the plugin.

## License

MIT
