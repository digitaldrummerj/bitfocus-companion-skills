# 🎛️ Companion AI Skills — Plugin Marketplace

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Plugins](https://img.shields.io/badge/Plugins-17-green.svg)](#-available-plugins)

**AI skills for Bitfocus Companion module development.** Drop-in knowledge plugins that teach AI agents how to build, configure, and maintain Bitfocus Companion modules using `@companion-module/base`.

---

## 💡 What Is This?

Bitfocus Companion is a control and automation platform used to drive production systems, broadcast tools, conferencing platforms, and custom devices from buttons, variables, feedbacks, and presets. These plugins package module-development knowledge into reusable AI skills so an agent can quickly learn Companion-specific patterns for actions, feedbacks, OSC, config, upgrades, API compliance, and review workflows.

Every plugin is centered on a `SKILL.md` file, then wrapped with marketplace metadata so it can be installed through Copilot CLI or copied into any agent-compatible skills directory.

---

## 📦 Available Plugins

| Plugin | Description | Triggers |
|--------|-------------|----------|
| [`companion-action-file-pattern`](plugins/companion-action-file-pattern/) | Create and wire a new split-file actions category for a Bitfocus Companion module. | `new action category`, `action file pattern`, `actions.ts aggregator` |
| [`companion-actions`](plugins/companion-actions/) | Implement Bitfocus Companion actions with typed definitions, options, callbacks, and lifecycle hooks. | `add action`, `button command`, `action callback` |
| [`companion-add-action-to-category-file`](plugins/companion-add-action-to-category-file/) | Add new actions to an existing Companion action category file without changing the aggregator. | `add action to existing file`, `extend action category`, `action enum member` |
| [`companion-add-feedback-to-category-file`](plugins/companion-add-feedback-to-category-file/) | Add new feedbacks to an existing Companion feedback category file without creating a new category. | `add feedback to existing file`, `extend feedback category`, `feedback enum member` |
| [`companion-add-preset-to-category-file`](plugins/companion-add-preset-to-category-file/) | Add new presets to an existing enum-based Companion preset category file. | `add preset to existing file`, `extend preset enum`, `preset-{category}.ts` |
| [`companion-bitfocus-dashboard`](plugins/companion-bitfocus-dashboard/) | Discover pending Companion module reviews from the Bitfocus developer portal and prepare repos for review. | `what's pending`, `pending review queue`, `Bitfocus dashboard` |
| [`companion-config`](plugins/companion-config/) | Define and validate Bitfocus Companion configuration fields, defaults, and configUpdated behavior. | `add config field`, `connection settings`, `configUpdated` |
| [`companion-feedback-file-pattern`](plugins/companion-feedback-file-pattern/) | Create and wire a new split-file feedback category for a Bitfocus Companion module. | `new feedback category`, `feedback file pattern`, `feedback.ts aggregator` |
| [`companion-feedbacks`](plugins/companion-feedbacks/) | Implement Bitfocus Companion feedbacks for boolean styling, advanced rendering, and state-driven updates. | `add feedback`, `button colors`, `advanced feedback` |
| [`companion-osc-integration`](plugins/companion-osc-integration/) | Integrate OSC transport, lifecycle management, and state updates into a Bitfocus Companion module. | `OSC integration`, `OSC UDP`, `OSC receive` |
| [`companion-preset-category-file`](plugins/companion-preset-category-file/) | Create and wire a new enum-based preset category file for a split-file Companion module. | `new preset category`, `presets.ts aggregator`, `preset file pattern` |
| [`companion-template-compliance`](plugins/companion-template-compliance/) | Review Companion modules against the official JavaScript and TypeScript template requirements. | `template compliance`, `official template`, `manifest.json rules` |
| [`companion-upgrades`](plugins/companion-upgrades/) | Write Companion upgrade scripts that safely migrate config, actions, and feedbacks across breaking changes. | `upgrade script`, `migrate config`, `rename action id` |
| [`companion-v1-api-compliance`](plugins/companion-v1-api-compliance/) | Review @companion-module/base v1.x modules for required lifecycle behavior and version-specific compliance. | `v1 api compliance`, `base v1.x`, `runEntrypoint` |
| [`companion-v2-api-compliance`](plugins/companion-v2-api-compliance/) | Review @companion-module/base v2.0+ modules for entrypoint, manifest, expression, and upgrade compliance. | `v2 api compliance`, `base v2.0`, `InstanceTypes` |
| [`companion-variable-definition`](plugins/companion-variable-definition/) | Declare and register Bitfocus Companion variables so they appear in the variable picker. | `setVariableDefinitions`, `declare variable`, `variable picker` |
| [`companion-variable-set-value`](plugins/companion-variable-set-value/) | Set and read Bitfocus Companion variable values at runtime after the variables are defined. | `setVariableValues`, `getVariableValue`, `update variable state` |

---

## 🚀 Installation

### GitHub Copilot CLI

#### One-time: register the marketplace

```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
```

#### Install any plugin

```bash
copilot plugin install digitaldrummerj@bitfocus-companion-skills
```

#### Or install directly from the repo (no marketplace registration needed)

```bash
copilot plugin install digitaldrummerj/bitfocus-companion-skills:plugins/companion-actions
```

---

## 📁 Plugin Structure

Each plugin directory includes:

- `SKILL.md` — the core agent-facing knowledge document
- `manifest.json` — machine-readable metadata for marketplaces and discovery
- `plugin.json` — Copilot CLI plugin metadata
- `README.md` — a short human-readable guide for the plugin

This mirrors the marketplace-friendly structure used by `squad-skills`, while keeping the Bitfocus Companion guidance self-contained per plugin.

---

## 📄 License

[MIT](LICENSE)
