import { App, FileSystemAdapter, Notice, requestUrl } from "obsidian";

export const OPENCODE_ID = "opencode-obsidian";
const CMD_START = `${OPENCODE_ID}:start-opencode-server`;
const CMD_TOGGLE = `${OPENCODE_ID}:toggle-opencode-view`;

export type DeliveryMode = "clipboard" | "auto";

interface RunOptions {
	delivery: DeliveryMode;
	port: number;
}

/** The opencode-obsidian plugin instance, if it is installed AND enabled. */
function opencodePlugin(app: App): any | null {
	return (app as any).plugins?.plugins?.[OPENCODE_ID] ?? null;
}

export function isOpencodeInstalled(app: App): boolean {
	return !!(app as any).plugins?.manifests?.[OPENCODE_ID];
}

export function isOpencodeEnabled(app: App): boolean {
	return !!opencodePlugin(app);
}

function executeCommand(app: App, id: string): boolean {
	try {
		return !!(app as any).commands?.executeCommandById?.(id);
	} catch {
		return false;
	}
}

/** Absolute path of the vault root — OpenCode runs here so AGENTS.md loads. */
function vaultDir(app: App): string {
	const adapter = app.vault.adapter;
	if (adapter instanceof FileSystemAdapter) return adapter.getBasePath();
	return "";
}

/** Resolve the OpenCode server base URL from the plugin, falling back to the port. */
function apiBaseUrl(app: App, port: number): string {
	const plugin = opencodePlugin(app);
	try {
		const url = plugin?.getApiBaseUrl?.();
		if (url) return String(url).replace(/\/+$/, "");
	} catch {
		/* fall through to constructed URL */
	}
	const configuredPort = Number(plugin?.settings?.port) || port;
	return `http://127.0.0.1:${configuredPort}`;
}

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Any HTTP response (even 4xx) means the server socket is accepting connections. */
async function serverReachable(base: string, dir: string): Promise<boolean> {
	try {
		const res = await requestUrl({
			url: `${base}/session?directory=${encodeURIComponent(dir)}`,
			method: "GET",
			headers: { "x-opencode-directory": dir },
			throw: false,
		});
		return res.status > 0;
	} catch {
		return false;
	}
}

/** Ensure the OpenCode server is running, starting it if necessary. */
async function ensureServer(app: App, base: string, dir: string): Promise<boolean> {
	if (await serverReachable(base, dir)) return true;

	const plugin = opencodePlugin(app);
	let triggered = false;
	try {
		if (typeof plugin?.startServer === "function") {
			await plugin.startServer();
			triggered = true;
		}
	} catch {
		/* fall back to the command */
	}
	if (!triggered) executeCommand(app, CMD_START);

	// Server startup (spawns sunny + boots the HTTP API) can take a while.
	for (let i = 0; i < 45; i++) {
		await sleep(1000);
		if (await serverReachable(base, dir)) return true;
	}
	return false;
}

/** Create a session and post the prompt so Sunny acts on it. Throws on failure. */
async function sendViaApi(base: string, dir: string, prompt: string): Promise<void> {
	const headers = {
		"Content-Type": "application/json",
		"x-opencode-directory": dir,
	};

	const sessionRes = await requestUrl({
		url: `${base}/session`,
		method: "POST",
		headers,
		body: JSON.stringify({ title: "LLM Wiki" }),
		throw: false,
	});
	if (sessionRes.status < 200 || sessionRes.status >= 300) {
		throw new Error(`could not create a session (HTTP ${sessionRes.status})`);
	}

	const json = sessionRes.json ?? {};
	const sessionId = json.id ?? json.sessionID ?? json.sessionId ?? json.session?.id;
	if (!sessionId) {
		throw new Error("OpenCode did not return a session id");
	}

	const messageRes = await requestUrl({
		url: `${base}/session/${encodeURIComponent(String(sessionId))}/message`,
		method: "POST",
		headers,
		body: JSON.stringify({ parts: [{ type: "text", text: prompt }] }),
		throw: false,
	});
	if (messageRes.status < 200 || messageRes.status >= 300) {
		throw new Error(`could not send the prompt (HTTP ${messageRes.status})`);
	}
}

async function copyToClipboard(text: string): Promise<boolean> {
	try {
		await navigator.clipboard.writeText(text);
		return true;
	} catch {
		return false;
	}
}

/** Clipboard hand-off: copy the prompt and open the panel for the user to paste. */
async function handOff(app: App, prompt: string, label: string): Promise<void> {
	const copied = await copyToClipboard(prompt);

	if (isOpencodeEnabled(app)) {
		executeCommand(app, CMD_START);
		executeCommand(app, CMD_TOGGLE);
		new Notice(
			copied
				? `${label} prompt copied. Paste it into the OpenCode panel (Ctrl/Cmd+V) and press Enter.`
				: `Couldn't access the clipboard. Open the OpenCode panel and paste the ${label} prompt manually.`,
			12000,
		);
	} else if (isOpencodeInstalled(app)) {
		new Notice(
			`OpenCode is installed but not enabled. Turn it on in Settings → Community plugins, then paste the ${label} prompt${copied ? " (copied to your clipboard)" : ""}.`,
			12000,
		);
	} else {
		new Notice(
			`OpenCode plugin not found. The ${label} prompt is${copied ? " copied to your clipboard" : " ready"} — install/enable opencode-obsidian, or run the ./tools scripts in PowerShell.`,
			12000,
		);
	}
}

/**
 * Deliver a prompt to Sunny. In "auto" mode, drive the OpenCode HTTP API directly;
 * on any failure (or in "clipboard" mode) fall back to the clipboard hand-off.
 */
export async function runPrompt(
	app: App,
	options: RunOptions,
	prompt: string,
	label: string,
): Promise<void> {
	if (options.delivery === "auto" && isOpencodeEnabled(app)) {
		const dir = vaultDir(app);
		const base = apiBaseUrl(app, options.port);
		try {
			new Notice(`Starting Sunny for "${label}"…`);
			if (!(await ensureServer(app, base, dir))) {
				throw new Error("the OpenCode server did not start in time");
			}
			await sendViaApi(base, dir, prompt);
			executeCommand(app, CMD_TOGGLE);
			new Notice(`Sent the "${label}" prompt to Sunny. Watch the OpenCode panel.`, 8000);
			return;
		} catch (err) {
			const message = err instanceof Error ? err.message : String(err);
			new Notice(`Auto-send failed (${message}). Falling back to clipboard.`, 8000);
			// fall through to the reliable hand-off
		}
	}

	await handOff(app, prompt, label);
}
