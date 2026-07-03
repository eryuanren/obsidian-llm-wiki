import { App, PluginSettingTab, Setting } from "obsidian";
import type { DeliveryMode } from "./opencode";
import type LlmWikiPlugin from "./main";

export interface LlmWikiSettings {
	/** How pipeline prompts reach Sunny. */
	delivery: DeliveryMode;
	/** OpenCode server port (matches opencode-obsidian's setting; default 14096). */
	opencodePort: number;
	/** Show the ribbon icon in the left sidebar. */
	showRibbonIcon: boolean;
}

export const DEFAULT_SETTINGS: LlmWikiSettings = {
	delivery: "clipboard",
	opencodePort: 14096,
	showRibbonIcon: true,
};

export class LlmWikiSettingTab extends PluginSettingTab {
	plugin: LlmWikiPlugin;

	constructor(app: App, plugin: LlmWikiPlugin) {
		super(app, plugin);
		this.plugin = plugin;
	}

	display(): void {
		const { containerEl } = this;
		containerEl.empty();

		new Setting(containerEl).setName("Pipeline").setHeading();

		new Setting(containerEl)
			.setName("Prompt delivery")
			.setDesc(
				"How the Build / Ingest / Lint commands hand a prompt to Sunny. " +
					"Clipboard is reliable and lets you watch the run; Auto-send is experimental.",
			)
			.addDropdown((dd) =>
				dd
					.addOption("clipboard", "Copy to clipboard & open panel")
					.addOption("auto", "Send automatically via OpenCode API (experimental)")
					.setValue(this.plugin.settings.delivery)
					.onChange(async (value) => {
						this.plugin.settings.delivery = value as DeliveryMode;
						await this.plugin.saveSettings();
					}),
			);

		new Setting(containerEl)
			.setName("OpenCode server port")
			.setDesc(
				"Used only by Auto-send, and only if the port can't be read from the " +
					"opencode-obsidian plugin. Must match that plugin's port setting.",
			)
			.addText((text) =>
				text
					.setPlaceholder("14096")
					.setValue(String(this.plugin.settings.opencodePort))
					.onChange(async (value) => {
						const port = Number(value.trim());
						if (Number.isInteger(port) && port > 0 && port < 65536) {
							this.plugin.settings.opencodePort = port;
							await this.plugin.saveSettings();
						}
					}),
			);

		new Setting(containerEl).setName("Appearance").setHeading();

		new Setting(containerEl)
			.setName("Show ribbon icon")
			.setDesc("Show the LLM Wiki setup icon in the left sidebar.")
			.addToggle((toggle) =>
				toggle.setValue(this.plugin.settings.showRibbonIcon).onChange(async (value) => {
					this.plugin.settings.showRibbonIcon = value;
					await this.plugin.saveSettings();
					this.plugin.refreshRibbonIcon();
				}),
			);
	}
}
