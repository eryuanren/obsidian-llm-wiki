import { App, normalizePath } from "obsidian";

// Scaffold source-of-truth files, inlined as strings at build time (esbuild `text`
// loader). These are byte-for-byte the same files that init-wiki.ps1 embeds.
import agentsMd from "./scaffold/AGENTS.md";
import workflowMd from "./scaffold/WORKFLOW.md";
import readmeMd from "./scaffold/README.md";
import toolsReadmeMd from "./scaffold/tools-README.md";
import buildPs1 from "./scaffold/build.ps1";
import checkDuplicatePs1 from "./scaffold/check-duplicate.ps1";
import convertAllPs1 from "./scaffold/convert-all.ps1";
import convertToMdPs1 from "./scaffold/convert-to-md.ps1";
import ingestPs1 from "./scaffold/ingest.ps1";
import installAliasPs1 from "./scaffold/install-alias.ps1";
import invokeSunnyPs1 from "./scaffold/invoke-sunny.ps1";
import markAllProcessedPs1 from "./scaffold/mark-all-processed.ps1";
import markProcessedPs1 from "./scaffold/mark-processed.ps1";
import searchWikiPs1 from "./scaffold/search-wiki.ps1";
import sunnyPs1 from "./scaffold/sunny.ps1";

/** Marker file whose presence means the vault has already been set up. */
export const SETUP_MARKER = "AGENTS.md";

/** Folders created by the scaffold, parents before children. */
const FOLDERS = [
	"raw",
	"raw/assets",
	"inbox",
	"processed",
	"tools",
	"wiki",
	"wiki/entities",
	"wiki/concepts",
	"wiki/sources",
	"wiki/synthesis",
];

/** Folders that start empty; a .gitkeep keeps them under version control. */
const GITKEEP_FOLDERS = [
	"raw",
	"raw/assets",
	"inbox",
	"processed",
	"wiki/entities",
	"wiki/concepts",
	"wiki/sources",
	"wiki/synthesis",
];

/**
 * Methodology / tooling files. Safe to overwrite when the user re-runs setup with
 * "overwrite" (e.g. to pick up updated tool scripts). They contain no user data.
 */
const SCAFFOLD_FILES: Record<string, string> = {
	"AGENTS.md": agentsMd,
	"WORKFLOW.md": workflowMd,
	"README.md": readmeMd,
	"tools/README.md": toolsReadmeMd,
	"tools/build.ps1": buildPs1,
	"tools/check-duplicate.ps1": checkDuplicatePs1,
	"tools/convert-all.ps1": convertAllPs1,
	"tools/convert-to-md.ps1": convertToMdPs1,
	"tools/ingest.ps1": ingestPs1,
	"tools/install-alias.ps1": installAliasPs1,
	"tools/invoke-sunny.ps1": invokeSunnyPs1,
	"tools/mark-all-processed.ps1": markAllProcessedPs1,
	"tools/mark-processed.ps1": markProcessedPs1,
	"tools/search-wiki.ps1": searchWikiPs1,
	"tools/sunny.ps1": sunnyPs1,
};

function today(): string {
	const d = new Date();
	const pad = (n: number) => String(n).padStart(2, "0");
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/**
 * Seed pages that may accumulate user/agent data. These are written only when
 * missing and are NEVER overwritten, so a re-run can't wipe an existing wiki's
 * index, activity log, or processed-files audit table.
 */
function seedFiles(): Record<string, string> {
	const date = today();
	return {
		"wiki/index.md": [
			"# Wiki Index",
			"",
			`*Last updated: ${date}*`,
			"",
			"## Entities",
			"",
			"*No entities yet - add your first source to begin*",
			"",
			"## Concepts",
			"",
			"*No concepts yet - add your first source to begin*",
			"",
			"## Sources",
			"",
			"*No sources yet - place files in `raw/` to begin*",
			"",
			"## Synthesis",
			"",
			"*No synthesis pages yet*",
			"",
			"---",
			"",
			"**Stats**: 0 entities | 0 concepts | 0 sources | 0 synthesis pages",
			"",
		].join("\n"),
		"wiki/log.md": [
			"# Activity Log",
			"",
			`*Wiki created: ${date}*`,
			"",
			"---",
			"",
			"*No activity yet. Add a source to `raw/` and run the pipeline to begin.*",
			"",
		].join("\n"),
		"wiki/processed.md": [
			"# Processed Files Log",
			"",
			"*Tracks which source files have been ingested to prevent duplicates*",
			"",
			"---",
			"",
			"## Ingested Sources",
			"",
			"| Date | File | Status | Notes |",
			"|------|------|--------|-------|",
			"",
			"---",
			"",
		].join("\n"),
	};
}

export interface ScaffoldOptions {
	/** Overwrite existing methodology/tooling files (never touches seeds or user data). */
	overwrite: boolean;
}

export interface ScaffoldResult {
	created: string[];
	overwritten: string[];
	skipped: string[];
	foldersCreated: string[];
}

/**
 * Build the LLM Wiki structure into the current vault using the Vault adapter.
 * Cross-platform, no shell required. `raw/` sources and existing wiki pages are
 * never modified.
 */
export async function scaffoldVault(app: App, options: ScaffoldOptions): Promise<ScaffoldResult> {
	const adapter = app.vault.adapter;
	const result: ScaffoldResult = {
		created: [],
		overwritten: [],
		skipped: [],
		foldersCreated: [],
	};

	// 1. Folders.
	for (const folder of FOLDERS) {
		const path = normalizePath(folder);
		if (!(await adapter.exists(path))) {
			await adapter.mkdir(path);
			result.foldersCreated.push(folder);
		}
	}

	// 2. .gitkeep placeholders (created only if the folder is otherwise empty of one).
	for (const folder of GITKEEP_FOLDERS) {
		const path = normalizePath(`${folder}/.gitkeep`);
		if (!(await adapter.exists(path))) {
			await adapter.write(path, "");
			result.created.push(`${folder}/.gitkeep`);
		}
	}

	// 3. Methodology / tooling files (overwritable on request).
	for (const [rel, content] of Object.entries(SCAFFOLD_FILES)) {
		const path = normalizePath(rel);
		const exists = await adapter.exists(path);
		if (exists && !options.overwrite) {
			result.skipped.push(rel);
			continue;
		}
		await ensureParent(app, path);
		await adapter.write(path, content);
		(exists ? result.overwritten : result.created).push(rel);
	}

	// 4. Seed pages — written only when missing, never overwritten (protects user data).
	for (const [rel, content] of Object.entries(seedFiles())) {
		const path = normalizePath(rel);
		if (await adapter.exists(path)) {
			result.skipped.push(rel);
			continue;
		}
		await ensureParent(app, path);
		await adapter.write(path, content);
		result.created.push(rel);
	}

	return result;
}

async function ensureParent(app: App, path: string): Promise<void> {
	const parent = path.substring(0, path.lastIndexOf("/"));
	if (parent && !(await app.vault.adapter.exists(parent))) {
		await app.vault.adapter.mkdir(parent);
	}
}
