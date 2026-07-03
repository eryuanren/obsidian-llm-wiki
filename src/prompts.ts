// Prompts handed to Sunny (OpenCode). They mirror the workflows documented in the
// scaffolded AGENTS.md, so Sunny loads that schema and follows it from the wiki root.

export const BUILD_PROMPT = `Build the wiki end to end, following the BUILD workflow in AGENTS.md.

1. Run \`pwsh ./tools/convert-all.ps1\` to stage every file in raw/ into the inbox/ queue (documents become markdown; images are queued as-is). Skip items already queued.
2. Ingest every item now in inbox/, markdown and images alike. For each: read it (or view it, if an image), check wiki/processed.md, write a source page in wiki/sources/, create or update the relevant entity and concept pages in wiki/entities/ and wiki/concepts/, add [[links]] both ways and flag any contradictions, update wiki/index.md, and append an entry to wiki/log.md using the documented "## [YYYY-MM-DD] ingest | Title" format.
3. Once ingest is complete and verified, run \`pwsh ./tools/mark-all-processed.ps1\` to archive the queue into processed/.
4. Report: files converted, pages created/updated, contradictions found, and any suggested synthesis pages.

Never modify raw/. If conversion or ingest fails for a file, leave it in inbox/, skip archiving it, and say so.`;

export const INGEST_PROMPT = `Ingest everything currently queued in inbox/, following the INGEST workflow in AGENTS.md.

For each item: read it (or view it, if an image), check wiki/processed.md to confirm it hasn't already been ingested, write a source page in wiki/sources/, create or update the relevant entity and concept pages, add [[links]] both ways and note where the source confirms or contradicts existing pages, update wiki/index.md, and append an entry to wiki/log.md using the documented prefix format.

Do not modify raw/. When finished, report pages created, pages updated, contradictions found, and any suggested synthesis pages. Do not archive — I will review first and run ./tools/mark-all-processed.ps1 myself.`;

export const LINT_PROMPT = `Lint the wiki, following the LINT workflow in AGENTS.md. Health-check and report only — do not auto-fix unless I ask.

Report: orphan pages (no inbound links), contradictions between pages, stale claims superseded by newer sources, missing pages (concepts/entities mentioned often but lacking their own page), missing cross-references, and data gaps a web search could fill.`;
