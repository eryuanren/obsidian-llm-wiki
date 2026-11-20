// Prompts handed to Sunny (OpenCode/sunny) from inside Obsidian.
//
// These mirror the custom commands in `.opencode/commands/`, which is where the
// procedures really live. The plugin can't invoke a custom command: it delivers a
// prompt through the clipboard or the OpenCode HTTP API, neither of which expands a
// `/wiki-ingest` slash command. So each prompt restates the essentials and points at
// `.opencode/llm-wiki/schema.md`, which Sunny loads from the wiki root.
//
// From a terminal, prefer the commands themselves:
//   sunny -Ingest        ->  sunny run "<files>" --command wiki-ingest

export const BUILD_PROMPT = `Build the wiki end to end, following the BUILD workflow in .opencode/llm-wiki/schema.md.

1. Run \`pwsh ./tools/convert-all.ps1\` to stage every file under raw/ into the inbox/ queue. It recurses into subfolders, converts documents to markdown, copies markdown and images as-is, and skips anything whose content hash is already recorded in wiki/processed.md.
2. Ingest every item now in inbox/, markdown and images alike. For each: read it (or view it, if an image), check wiki/processed.md, read .llm-wiki/queue.json for the raw file it came from, write a source page in wiki/sources/ keeping figures and quotations verbatim, search the wiki before creating any entity or concept page (update an existing one and extend its \`aliases:\` rather than creating a near-duplicate), add [[links]] both ways, flag contradictions under "## Disagreements", update wiki/index.md, and append an entry to wiki/log.md using the documented "## [YYYY-MM-DD] ingest | Title" format.
3. Record each outcome in .llm-wiki/ingest-status.json as {"items": {"<inbox filename>": {"status": "done"|"failed"|"skipped", "note": "..."}}}, preserving entries already there. Mark "done" only for sources that genuinely made it into the wiki — only those get archived.
4. Run \`pwsh ./tools/mark-all-processed.ps1\` to archive what you marked done.
5. Report: files converted, pages created/updated, contradictions found, what is still in inbox/ and why, and any suggested synthesis pages.

Never modify raw/.`;

export const INGEST_PROMPT = `Ingest everything currently queued in inbox/, following the INGEST workflow in .opencode/llm-wiki/schema.md.

For each item: read it (or, if it is an image, open it by its inbox/ path with your read tool and view it — capture the actual values in any chart or table). Check wiki/processed.md to confirm it hasn't already been ingested, and read .llm-wiki/queue.json for the raw file it came from — queue names may be flattened (reports__q3.md came from raw/reports/q3.pdf).

Write a source page in wiki/sources/, keeping figures, dates and quotations verbatim and linking to both processed/<file> and raw/<original>. Search the wiki before creating any entity or concept page: if one already covers the idea under another name, update it and add that name to its \`aliases:\` instead of creating a second page. Add [[links]] both ways, and keep any contradiction under a "## Disagreements" section with attribution rather than overwriting one side. Update wiki/index.md and append an entry to wiki/log.md using the documented prefix format.

Record each outcome in .llm-wiki/ingest-status.json as {"items": {"<inbox filename>": {"status": "done"|"failed"|"skipped", "note": "..."}}}, preserving entries already in that file. Only files marked "done" are archived, so do not mark a half-ingested file done.

Do not modify raw/. Do not archive — I will review first and run ./tools/mark-all-processed.ps1 myself. When finished, report pages created, pages updated, contradictions found, anything you could not ingest and why, and any suggested synthesis pages.`;

export const LINT_PROMPT = `Lint the wiki, following the LINT workflow in .opencode/llm-wiki/schema.md. Health-check and report only — do not fix anything unless I ask.

Check mechanically with grep, and report what you actually found with file and line, never a guess that something "might be" missing: broken [[links]] (check \`aliases:\` before calling one broken), orphan pages with no inbound links, missing or malformed frontmatter, index drift against wiki/index.md, and figures or dates on entity/concept pages with no source link.

Then the judgement calls: near-duplicate pages that have drifted into the same idea (name the survivor and the aliases it should absorb), contradictions between pages (propose a "## Disagreements" section rather than picking a winner), stale claims where a page's \`last_verified\` predates a newer source on the same subject (propose \`status: superseded\` with a \`supersedes:\` link so the replaced claim keeps its history), entities or concepts mentioned often but lacking a page, missing cross-references, and gaps a new source could fill.

Append a lint entry to wiki/log.md with the counts and headline findings.`;

export const QUERY_PROMPT_PREFIX = `Answer this question, following the QUERY workflow in .opencode/llm-wiki/schema.md.

Search wiki/ with your own grep for the question's terms and their synonyms, checking \`aliases:\` in frontmatter; read wiki/index.md if search returns little; then open the most relevant pages.

Then go to the source. If the answer turns on a figure, date, name, quotation, or any specific detail, open the cited source page's archived text in processed/ and read the passage itself — the wiki's pages are summaries, and summaries drop exactly the detail precise questions ask about. Saying "the wiki doesn't cover it" without having opened the cited source is a wrong answer.

Cite pages with [[links]], and cite the source and section for any specific value. If neither the wiki nor its sources cover it, say so plainly rather than inventing anything, and keep your own reasoning separate from what the sources say. Append a query entry to wiki/log.md.

Question: `;
