import { App, Modal, Setting } from "obsidian";
import { isOpencodeEnabled, isOpencodeInstalled } from "./opencode";
import type { ScaffoldResult } from "./scaffold";

/** Confirm before overwriting an existing LLM Wiki setup. */
export class ConfirmOverwriteModal extends Modal {
	private onConfirm: () => void;

	constructor(app: App, onConfirm: () => void) {
		super(app);
		this.onConfirm = onConfirm;
	}

	onOpen(): void {
		const { contentEl } = this;
		this.titleEl.setText("LLM Wiki already set up here");

		contentEl.createEl("p", {
			text:
				"This vault already contains an AGENTS.md, so the LLM Wiki has been set up before. " +
				"You can refresh the methodology files and tool scripts.",
		});

		const ul = contentEl.createEl("ul");
		ul.createEl("li", {
			text:
				"Will overwrite: the schema and commands under .opencode/, WORKFLOW.md, " +
				"README.md, and every tools/ script.",
		});
		ul.createEl("li", {
			text:
				"Will NOT touch: AGENTS.md (your own rules live there), .opencode/opencode.json, " +
				"your raw/ sources, your wiki pages, or wiki/index.md, log.md and processed.md.",
		});

		new Setting(contentEl)
			.addButton((btn) =>
				btn.setButtonText("Cancel").onClick(() => this.close()),
			)
			.addButton((btn) =>
				btn
					.setButtonText("Overwrite scaffolding")
					.setWarning()
					.onClick(() => {
						this.close();
						this.onConfirm();
					}),
			);
	}

	onClose(): void {
		this.contentEl.empty();
	}
}

/** Summary shown after setup: what was written, prerequisites, and next steps. */
export class SetupSummaryModal extends Modal {
	private result: ScaffoldResult;

	constructor(app: App, result: ScaffoldResult) {
		super(app);
		this.result = result;
		this.modalEl.addClass("llm-wiki-modal");
	}

	onOpen(): void {
		const { contentEl, result } = this;
		this.titleEl.setText("LLM Wiki is ready");

		const summary = contentEl.createEl("p");
		summary.appendText("Wrote ");
		summary.createEl("span", {
			text: String(result.created.length),
			cls: "llm-wiki-count",
		});
		summary.appendText(" new file(s)");
		if (result.overwritten.length) {
			summary.appendText(", refreshed ");
			summary.createEl("span", {
				text: String(result.overwritten.length),
				cls: "llm-wiki-count",
			});
		}
		if (result.skipped.length) {
			summary.appendText(", left ");
			summary.createEl("span", {
				text: String(result.skipped.length),
				cls: "llm-wiki-count",
			});
			summary.appendText(" existing file(s) untouched");
		}
		summary.appendText(".");

		this.fileList(contentEl, "Created", result.created);
		this.fileList(contentEl, "Refreshed", result.overwritten);
		this.fileList(contentEl, "Skipped (already present)", result.skipped);

		// Prerequisites checklist.
		contentEl.createEl("div", { text: "Prerequisites", cls: "llm-wiki-section-title" });
		const prereqs = contentEl.createEl("ul", { cls: "llm-wiki-list" });
		this.prereq(
			prereqs,
			isOpencodeEnabled(this.app),
			"opencode-obsidian plugin enabled",
			isOpencodeInstalled(this.app)
				? "Installed — enable it in Settings → Community plugins."
				: "Not found — install it (via BRAT: mtymek/opencode-obsidian).",
		);
		this.prereqNeutral(
			prereqs,
			"opencode / sunny CLI on your PATH (the AI engine).",
		);
		this.prereqNeutral(
			prereqs,
			"markitdown for converting PDFs/DOCX: pip install 'markitdown[all]'.",
		);

		// Next steps.
		contentEl.createEl("div", { text: "Next steps", cls: "llm-wiki-section-title" });
		const steps = contentEl.createEl("ol");
		steps.createEl("li", { text: "Drop source files (PDF, DOCX, MD, images…) into raw/." });
		steps.createEl("li", {
			text: 'Run the "LLM Wiki: Build wiki" command to convert, ingest, and archive.',
		});
		steps.createEl("li", { text: "Browse the new pages in wiki/ and use Graph View." });

		new Setting(contentEl).addButton((btn) =>
			btn
				.setButtonText("Done")
				.setCta()
				.onClick(() => this.close()),
		);
	}

	private fileList(parent: HTMLElement, title: string, files: string[]): void {
		if (!files.length) return;
		parent.createEl("div", { text: title, cls: "llm-wiki-section-title" });
		const ul = parent.createEl("ul", { cls: "llm-wiki-list" });
		for (const f of files) ul.createEl("li", { text: f });
	}

	private prereq(parent: HTMLElement, ok: boolean, name: string, hint: string): void {
		const li = parent.createEl("li");
		li.appendText(`${ok ? "✓" : "•"} ${name}`);
		if (!ok) {
			li.createEl("div", { text: hint, cls: "llm-wiki-muted" });
		}
	}

	private prereqNeutral(parent: HTMLElement, text: string): void {
		parent.createEl("li", { text: `• ${text}`, cls: "llm-wiki-muted" });
	}

	onClose(): void {
		this.contentEl.empty();
	}
}

/** Prompt the user for a free-form message to send to Sunny. */
export interface PromptModalCopy {
	title: string;
	blurb: string;
	placeholder: string;
}

const DEFAULT_PROMPT_COPY: PromptModalCopy = {
	title: "Send a prompt to Sunny",
	blurb: 'Sunny answers from the wiki and can run the tools. e.g. "Compare X and Y" or "lint the wiki".',
	placeholder: "Type your message…",
};

export class CustomPromptModal extends Modal {
	private onSubmit: (prompt: string) => void;
	private copy: PromptModalCopy;

	constructor(app: App, onSubmit: (prompt: string) => void, copy?: Partial<PromptModalCopy>) {
		super(app);
		this.onSubmit = onSubmit;
		this.copy = { ...DEFAULT_PROMPT_COPY, ...(copy ?? {}) };
		this.modalEl.addClass("llm-wiki-modal");
	}

	onOpen(): void {
		const { contentEl } = this;
		this.titleEl.setText(this.copy.title);

		contentEl.createEl("p", {
			text: this.copy.blurb,
			cls: "llm-wiki-muted",
		});

		const textarea = contentEl.createEl("textarea", {
			cls: "llm-wiki-prompt-textarea",
		});
		textarea.setAttr("placeholder", this.copy.placeholder);
		window.setTimeout(() => textarea.focus(), 0);

		const submit = () => {
			const value = textarea.value.trim();
			if (!value) return;
			this.close();
			this.onSubmit(value);
		};

		// Cmd/Ctrl+Enter submits.
		textarea.addEventListener("keydown", (evt) => {
			if ((evt.metaKey || evt.ctrlKey) && evt.key === "Enter") {
				evt.preventDefault();
				submit();
			}
		});

		new Setting(contentEl)
			.addButton((btn) => btn.setButtonText("Cancel").onClick(() => this.close()))
			.addButton((btn) =>
				btn.setButtonText("Send to Sunny").setCta().onClick(submit),
			);
	}

	onClose(): void {
		this.contentEl.empty();
	}
}
