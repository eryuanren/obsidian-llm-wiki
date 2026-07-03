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
