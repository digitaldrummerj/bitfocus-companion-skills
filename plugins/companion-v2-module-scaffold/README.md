# Companion v2 Module Scaffold

Scaffold a new @companion-module/base v2.x module in the split-file layout with ESM, a typed ModuleSchema and a v2 manifest. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are starting a brand-new Companion module on the v2 API.

- You need the v2 package.json, tsconfig, manifest.json and main.ts setup.

- You want the template reshaped into per-category action, feedback and preset files.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-module-scaffold@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-module-scaffold/` in your project.

## What It Covers

- ESM package.json, tsconfig (recommended-esm / node26) and manifest type connection.

- main.ts with ModuleSchema, default export and UpgradeScripts export.

- Aggregator files for actions, feedbacks and presets.

- Build, lint, companion-module-check and packaging steps.

## Example Requests

- "scaffold a new v2 companion module"

- "set up ModuleSchema for my module"

- "create a companion module from the template with split files"

## Activation Hints

- It is a strong match for requests about `v2 module scaffold`.

- It also fits prompts mentioning `new companion module v2`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
