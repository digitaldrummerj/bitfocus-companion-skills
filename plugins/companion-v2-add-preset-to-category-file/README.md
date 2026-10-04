# Companion v2 Add Preset to Category File

Add presets to an existing v2 preset category file by extending the enum, adding the definition and referencing it from a section group. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding a preset button to an existing v2 preset category file.

- The category already returns a section and its presets.

- You need the type simple preset shape.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-add-preset-to-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-add-preset-to-category-file/` in your project.

## What It Covers

- The three edits: enum member, definition, group reference.

- The type simple preset button shape.

- When to use a template group instead.

- Common mistakes.

## Example Requests

- "add a pause preset"

- "extend the transport presets"

- "why doesn't my new preset show up"

## Activation Hints

- It is a strong match for requests about `v2 add preset`.

- It also fits prompts mentioning `extend preset enum v2`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
