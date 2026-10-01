# 🎛️ Companion AI Skills — Plugin Marketplace

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Plugins](https://img.shields.io/badge/Plugins-34-green.svg)](#-available-plugins)

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
| [`companion-v1-to-v2-expression-upgrades`](plugins/companion-v1-to-v2-expression-upgrades/) | Retype historical upgrade scripts and add the expression-aware upgrade scripts that ship with a Companion v1 to v2 migration. | `upgrade scripts for v2 migration`, `isExpression upgrade script`, `FixupNumericOrVariablesValueToExpressions` |
| [`companion-v1-to-v2-migrate-definitions`](plugins/companion-v1-to-v2-migrate-definitions/) | Before/after transforms for migrating Companion actions, feedbacks, variables, config, and instance typing from base v1.x to v2. | `migrate actions to v2`, `remove parseVariablesInString`, `InstanceBaseExt to ModuleSchema` |
| [`companion-v1-to-v2-migrate-presets`](plugins/companion-v1-to-v2-migrate-presets/) | Migrate Companion presets from v1 button/category definitions to v2 sections, groups, and simple presets while keeping enum-per-category files. | `migrate presets to v2`, `preset category to sections`, `setPresetDefinitions structure` |
| [`companion-v1-to-v2-migration`](plugins/companion-v1-to-v2-migration/) | Step-by-step procedure for migrating a Companion module from @companion-module/base v1.x to the v2 API (2.0/2.1). | `migrate to v2`, `upgrade to companion api v2`, `remove runEntrypoint` |
| [`companion-v2-action-file-pattern`](plugins/companion-v2-action-file-pattern/) | Create a new v2 action category file with an enum, an enum-keyed schema type and a factory, and wire it into the actions.ts aggregator. | `v2 new action category`, `v2 action file pattern`, `ActionsSchema aggregator` |
| [`companion-v2-actions`](plugins/companion-v2-actions/) | Reference for @companion-module/base v2.x action definitions, typed schemas, expression-parsed options, subscribe, learn and 2.1 results. | `v2 action definition`, `CompanionActionDefinitions`, `optionsToMonitorForSubscribe` |
| [`companion-v2-add-action-to-category-file`](plugins/companion-v2-add-action-to-category-file/) | Add actions to an existing v2 action category file by extending the enum, the schema and the definitions. | `v2 add action`, `extend action category v2`, `add action to category file v2` |
| [`companion-v2-add-feedback-to-category-file`](plugins/companion-v2-add-feedback-to-category-file/) | Add feedbacks to an existing v2 feedback category file by extending the enum, the schema and the definitions, then triggering them. | `v2 add feedback`, `extend feedback category v2`, `add feedback to category file v2` |
| [`companion-v2-add-preset-to-category-file`](plugins/companion-v2-add-preset-to-category-file/) | Add presets to an existing v2 preset category file by extending the enum, adding the definition and referencing it from a section group. | `v2 add preset`, `extend preset enum v2`, `add preset to category file v2` |
| [`companion-v2-api-compliance`](plugins/companion-v2-api-compliance/) | Version-gated review of @companion-module/base v2.x modules (API 2.0 / 2.1) for entrypoint, manifest, ESM, expression, preset, and upgrade compliance. | `v2 api compliance`, `v2.1 api compliance`, `base v2.0` |
| [`companion-v2-config`](plugins/companion-v2-config/) | Reference for @companion-module/base v2.x configuration fields, typed config and secrets, isVisibleExpression and the config lifecycle. | `v2 config fields`, `secret-text`, `isVisibleExpression` |
| [`companion-v2-feedback-file-pattern`](plugins/companion-v2-feedback-file-pattern/) | Create a new v2 feedback category file with an enum, an enum-keyed schema type and a factory, and wire it into the feedbacks.ts aggregator. | `v2 new feedback category`, `v2 feedback file pattern`, `FeedbacksSchema aggregator` |
| [`companion-v2-feedbacks`](plugins/companion-v2-feedbacks/) | Reference for @companion-module/base v2.x feedback definitions, typed schemas, checkFeedbacks, the callback/unsubscribe lifecycle and 2.1 affectedProperties. | `v2 feedback definition`, `CompanionFeedbackDefinitions`, `checkAllFeedbacks` |
| [`companion-v2-module-scaffold`](plugins/companion-v2-module-scaffold/) | Scaffold a new @companion-module/base v2.x module in the split-file layout with ESM, a typed ModuleSchema and a v2 manifest. | `v2 module scaffold`, `new companion module v2`, `ModuleSchema` |
| [`companion-v2-preset-category-file`](plugins/companion-v2-preset-category-file/) | Create a v2 preset category file returning a section and its presets, and aggregate them into setPresetDefinitions(structure, presets). | `v2 preset category`, `v2 preset file`, `setPresetDefinitions structure` |
| [`companion-v2-upgrades`](plugins/companion-v2-upgrades/) | Reference for @companion-module/base v2.x upgrade scripts with expression-wrapped options, secrets and the built-in fixup helpers. | `v2 upgrade script`, `isExpression upgrade`, `FixupNumericOrVariablesValueToExpressions` |
| [`companion-v2-variable-definition`](plugins/companion-v2-variable-definition/) | Declare @companion-module/base v2.x variables with a typed VariablesSchema and the object form of setVariableDefinitions. | `v2 variable definition`, `VariablesSchema`, `setVariableDefinitions object` |
| [`companion-v2-variable-set-value`](plugins/companion-v2-variable-set-value/) | Set and read @companion-module/base v2.x variable values with typed setVariableValues and getVariableValue. | `v2 set variable value`, `setVariableValues v2`, `getVariableValue` |
| [`companion-variable-definition`](plugins/companion-variable-definition/) | Declare and register Bitfocus Companion variables so they appear in the variable picker. | `setVariableDefinitions`, `declare variable`, `variable picker` |
| [`companion-variable-set-value`](plugins/companion-variable-set-value/) | Set and read Bitfocus Companion variable values at runtime after the variables are defined. | `setVariableValues`, `getVariableValue`, `update variable state` |

### Choosing v1 or v2 skills

Pick skills by the `@companion-module/base` version in the module's `package.json`:

- **v1.x modules** — use the unprefixed skills (`companion-actions`, `companion-action-file-pattern`, …) and `companion-v1-api-compliance`.
- **v2.x modules (API 2.0 / Companion 4.3+, API 2.1 / Companion 5.0+)** — use the `companion-v2-*` skills. Start a new module with `companion-v2-module-scaffold`; review with `companion-v2-api-compliance`, which only applies the 2.1 checks when the module is actually on 2.1+.
- **Upgrading v1 → v2** — start with `companion-v1-to-v2-migration`; it hands off to the `companion-v1-to-v2-*` sub-skills.

---

## 🚀 Installation

### GitHub Copilot CLI

#### One-time: register the marketplace

```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
```

#### Install any plugin

```bash
copilot plugin install companion-actions@bitfocus-companion-skills
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
- `.claude-plugin/plugin.json` — Claude Code plugin manifest (a copy of `plugin.json`; keep the two in sync when changing name, description, version or keywords)
- `README.md` — a short human-readable guide for the plugin

This mirrors the marketplace-friendly structure used by `squad-skills`, while keeping the Bitfocus Companion guidance self-contained per plugin.

---

## 📄 License

[MIT](LICENSE)
