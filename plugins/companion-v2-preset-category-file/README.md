# Companion v2 Preset Category File

Create a v2 preset category file returning a section and its presets, and aggregate them into setPresetDefinitions(structure, presets). This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are creating a new preset category file in a v2 module.

- You need sections, groups or template groups.

- You want 2.1 layered presets, alternatives or internal:* actions.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-preset-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-preset-category-file/` in your project.

## What It Covers

- Enum preset IDs and the { section, presets } return shape.

- The presets.ts aggregator and setPresetDefinitions(structure, presets).

- Simple preset fields, local variables, hold actions and template groups.

- 2.1 internal actions/feedbacks, layered presets, alternatives and feedback local variables.

## Example Requests

- "create a preset category file"

- "add a new preset section"

- "make one preset per channel with a template"

## Activation Hints

- It is a strong match for requests about `v2 preset category`.

- It also fits prompts mentioning `v2 preset file`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
