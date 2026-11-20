import { Notice, Plugin, normalizePath } from "obsidian";
import {
	DEFAULT_SETTINGS,
	LlmWikiSettings,
	LlmWikiSettingTab,
} from "./settings";
import { SETUP_MARKER, scaffoldVault } from "./scaffold";
import {
	ConfirmOverwriteModal,
	CustomPromptModal,
	SetupSummaryModal,
} from "./modals";
import { OPENCODE_ID, isOpencodeEnabled, isOpencodeInstalled, runPrompt } from "./opencode";
import {
	BUILD_PROMPT,
	INGEST_PROMPT,
	LINT_PROMPT,
	QUERY_PROMPT_PREFIX,
} from "./prompts";

const RIBBON_ICON = "book-open";

export default class LlmWikiPlugin extends Plugin {
	settings: LlmWikiSettings = DEFAULT_SETTINGS;
	private ribbonEl: HTMLElement | null = null;

	async onload(): Promise<void> {
		await this.loadSettings();

		this.refreshRibbonIcon();

		this.addCommand({
			id: "setup-vault",
			name: "Set up LLM Wiki in this vault",
			callback: () => this.runSetup(),
		});

		this.addCommand({
			id: "build-wiki",
			name: "Build wiki (convert → ingest → archive)",
			callback: () => this.runPipeline(BUILD_PROMPT, "Build"),
		});

		this.addCommand({
			id: "ingest-inbox",
			name: "Ingest inbox into the wiki",
			callback: () => this.runPipeline(INGEST_PROMPT, "Ingest"),
		});

		this.addCommand({
			id: "lint-wiki",
			name: "Lint the wiki",
			callback: () => this.runPipeline(LINT_PROMPT, "Lint"),
		});

		this.addCommand({
			id: "query-wiki",
			name: "Ask the wiki",
			callback: () => {
				new CustomPromptModal(
					this.app,
					(question) => this.runPipeline(QUERY_PROMPT_PREFIX + question, "Query"),
					{
						title: "Ask the wiki",
						blurb:
							"Sunny answers from the wiki, and opens the cited source when the " +
							"question turns on a figure, date or quotation.",
						placeholder: "What do you want to know?",
					},
				).open();
			},
		});

		this.addCommand({
			id: "custom-prompt",
			name: "Send a custom prompt to Sunny",
			callback: () => {
				new CustomPromptModal(this.app, (prompt) =>
					this.deliver(prompt, "Custom prompt"),
				).open();
			},
		});

		this.addCommand({
			id: "open-opencode-panel",
			name: "Open OpenCode panel",
			callback: () => this.openOpencodePanel(),
		});

		this.addSettingTab(new LlmWikiSettingTab(this.app, this));
	}

	onunload(): void {
		this.ribbonEl?.remove();
		this.ribbonEl = null;
	}

	refreshRibbonIcon(): void {
		this.ribbonEl?.remove();
		this.ribbonEl = null;
		if (this.settings.showRibbonIcon) {
			this.ribbonEl = this.addRibbonIcon(RIBBON_ICON, "Set up LLM Wiki", () =>
				this.runSetup(),
			);
		}
	}

	private async isSetUp(): Promise<boolean> {
		return this.app.vault.adapter.exists(normalizePath(SETUP_MARKER));
	}

	private async runSetup(): Promise<void> {
		try {
			if (await this.isSetUp()) {
				new ConfirmOverwriteModal(this.app, () => this.doScaffold(true)).open();
			} else {
				await this.doScaffold(false);
			}
		} catch (err) {
			this.reportError("set up the vault", err);
		}
	}

	private async doScaffold(overwrite: boolean): Promise<void> {
		try {
			const result = await scaffoldVault(this.app, { overwrite });
			new SetupSummaryModal(this.app, result).open();
			new Notice(
				`LLM Wiki set up — ${result.created.length} created, ` +
					`${result.overwritten.length} refreshed, ${result.skipped.length} skipped.`,
			);
		} catch (err) {
			this.reportError("write the scaffolding", err);
		}
	}

	private async runPipeline(prompt: string, label: string): Promise<void> {
		if (!(await this.isSetUp())) {
			new Notice(
				'This vault isn\'t set up yet. Run "LLM Wiki: Set up LLM Wiki in this vault" first.',
				8000,
			);
			return;
		}
		await this.deliver(prompt, label);
	}

	private async deliver(prompt: string, label: string): Promise<void> {
		try {
			await runPrompt(
				this.app,
				{ delivery: this.settings.delivery, port: this.settings.opencodePort },
				prompt,
				label,
			);
		} catch (err) {
			this.reportError(`send the ${label} prompt`, err);
		}
	}

	private openOpencodePanel(): void {
		if (isOpencodeEnabled(this.app)) {
			(this.app as any).commands?.executeCommandById?.(
				`${OPENCODE_ID}:toggle-opencode-view`,
			);
		} else if (isOpencodeInstalled(this.app)) {
			new Notice(
				"OpenCode is installed but not enabled. Turn it on in Settings → Community plugins.",
				8000,
			);
		} else {
			new Notice(
				"OpenCode plugin not found. Install opencode-obsidian (via BRAT: mtymek/opencode-obsidian).",
				8000,
			);
		}
	}

	private reportError(action: string, err: unknown): void {
		const message = err instanceof Error ? err.message : String(err);
		new Notice(`LLM Wiki: couldn't ${action} — ${message}`, 10000);
		console.error(`[llm-wiki] failed to ${action}:`, err);
	}

	async loadSettings(): Promise<void> {
		this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
	}

	async saveSettings(): Promise<void> {
		await this.saveData(this.settings);
	}
}
