// The scaffold source files under src/scaffold/ are imported as raw strings via
// esbuild's `text` loader (see esbuild.config.mjs). These declarations tell
// TypeScript that a `.md` / `.ps1` import resolves to a string.

declare module "*.md" {
	const content: string;
	export default content;
}

declare module "*.ps1" {
	const content: string;
	export default content;
}

// Scaffolded JSON (e.g. the vault's opencode.json) is copied in verbatim, so it is
// inlined as a string too. `resolveJsonModule` is off in tsconfig.json for this reason.
declare module "*.json" {
	const content: string;
	export default content;
}
