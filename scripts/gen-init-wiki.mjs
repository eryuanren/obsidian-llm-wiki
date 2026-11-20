#!/usr/bin/env node
/**
 * Regenerate the embedded scaffolding block inside ../init-wiki.ps1 from the files in
 * src/scaffold/.
 *
 * Why this exists: the scaffold used to live in two places - these source files, and a
 * hand-maintained copy pasted into init-wiki.ps1 as here-strings. The Python desktop app
 * shells out to that installer, so every fix had to be made twice or the two installers
 * silently drifted apart. Now the installer is generated.
 *
 * It rewrites only the region between:
 *     $files = [ordered]@{}
 * and
 *     # --- Fresh, dated wiki seeds ---
 * Everything outside that region (the header, the dated seeds, folder creation, the
 * writer loop, prereqs, plugin install) is preserved exactly as it is.
 *
 * Usage:  node scripts/gen-init-wiki.mjs [--check]
 *         --check verifies the installer is up to date without writing (for CI).
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const scaffoldDir = resolve(here, "..", "src", "scaffold");
const installerPath = resolve(here, "..", "..", "init-wiki.ps1");

const BEGIN = "$files = [ordered]@{}";
const END = "# --- Fresh, dated wiki seeds ---";

/**
 * Source file in src/scaffold/ -> path it is written to inside the vault.
 * Keep in step with SCAFFOLD_FILES + seedFiles() in src/scaffold.ts.
 */
const FILES = [
	["AGENTS.md", "AGENTS.md"],
	["schema.md", ".opencode/llm-wiki/schema.md"],
	["opencode.json", ".opencode/opencode.json"],
	["cmd-wiki-build.md", ".opencode/commands/wiki-build.md"],
	["cmd-wiki-ingest.md", ".opencode/commands/wiki-ingest.md"],
	["cmd-wiki-lint.md", ".opencode/commands/wiki-lint.md"],
	["cmd-wiki-query.md", ".opencode/commands/wiki-query.md"],
	["WORKFLOW.md", "WORKFLOW.md"],
	["README.md", "README.md"],
	["tools-README.md", "tools/README.md"],
	["_common.ps1", "tools/_common.ps1"],
	["build.ps1", "tools/build.ps1"],
	["check-duplicate.ps1", "tools/check-duplicate.ps1"],
	["convert-all.ps1", "tools/convert-all.ps1"],
	["convert-to-md.ps1", "tools/convert-to-md.ps1"],
	["ingest.ps1", "tools/ingest.ps1"],
	["install-alias.ps1", "tools/install-alias.ps1"],
	["invoke-sunny.ps1", "tools/invoke-sunny.ps1"],
	["mark-all-processed.ps1", "tools/mark-all-processed.ps1"],
	["mark-processed.ps1", "tools/mark-processed.ps1"],
	["search-wiki.ps1", "tools/search-wiki.ps1"],
	["sunny.ps1", "tools/sunny.ps1"],
];

function buildBlock() {
	const chunks = [];
	for (const [srcName, vaultPath] of FILES) {
		const body = readFileSync(join(scaffoldDir, srcName), "utf8").replace(/\r\n/g, "\n");

		// A single-quoted here-string ends at a line that is exactly `'@`. Content can't
		// contain one, and a literal here-string means nothing else needs escaping.
		for (const [i, line] of body.split("\n").entries()) {
			if (line === "'@") {
				throw new Error(
					`${srcName}:${i + 1} is a bare "'@", which would terminate the here-string. ` +
						"Indent it or rephrase the line.",
				);
			}
		}

		chunks.push(`$files['${vaultPath}'] = @'\n${body.replace(/\n+$/, "")}\n'@\n`);
	}
	return chunks.join("\n");
}

function main() {
	const check = process.argv.includes("--check");
	const installer = readFileSync(installerPath, "utf8");
	const eol = installer.includes("\r\n") ? "\r\n" : "\n";
	const normalized = installer.replace(/\r\n/g, "\n");

	const beginIdx = normalized.indexOf(BEGIN);
	const endIdx = normalized.indexOf(END);
	if (beginIdx === -1 || endIdx === -1 || endIdx < beginIdx) {
		throw new Error(
			`Could not find the generated region in ${installerPath}. ` +
				`Expected "${BEGIN}" followed by "${END}".`,
		);
	}

	const head = normalized.slice(0, beginIdx + BEGIN.length);
	const tail = normalized.slice(endIdx);
	const next = `${head}\n\n${buildBlock()}\n${tail}`;

	if (normalized === next) {
		console.log("init-wiki.ps1 is up to date.");
		return;
	}

	if (check) {
		console.error(
			"init-wiki.ps1 is out of date with src/scaffold/. Run: node scripts/gen-init-wiki.mjs",
		);
		process.exit(1);
	}

	writeFileSync(installerPath, eol === "\r\n" ? next.replace(/\n/g, "\r\n") : next, "utf8");
	console.log(`Regenerated ${FILES.length} embedded files in init-wiki.ps1`);
}

main();
