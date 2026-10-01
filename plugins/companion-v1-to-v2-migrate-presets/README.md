# Companion v1 to v2: Migrate Presets

Migrate Companion presets from v1 button/category definitions to v2 sections, groups, and simple presets while keeping enum-per-category files. This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply it quickly during Bitfocus Companion module work.

## When to Use

- Your preset files still use `type: 'button'` and `category`.

- `setPresetDefinitions` is called with one argument.

- You have `CompanionPresetExt` / `CompanionButtonPresetDefinition` helpers to remove.

- You generate hundreds of presets in a loop and want template groups.

## Installation

### Claude Code
```bash
/plugin marketplace add digitaldrummerj/bitfocus-companion-skills
/plugin install companion-v1-to-v2-migrate-presets@bitfocus-companion-skills
```

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v1-to-v2-migrate-presets@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v1-to-v2-migrate-presets/` in your project.

## What It Covers

- v1 to v2 preset field mapping.

- Category file and aggregator rewrite returning `{ section, presets }`.

- Template groups vs keeping loop-generated simple presets.

- Preset-related test updates.

## Example Requests

- "convert my presets to the v2 sections format"

- "replace Caller_${number} presets with a template"

- "fix setPresetDefinitions expects 2 arguments"

## Activation Hints

- It is a strong match for requests about `migrate presets to v2`.

- It also fits prompts mentioning `preset category to sections`.

- Use it when work is clearly about migrating a Bitfocus Companion module from the v1 API to the v2 API.

- It pairs with the other `companion-v1-to-v2-*` and `companion-v2-*` skills.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
