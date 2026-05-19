# Companion Add Preset to Category File

Add new presets to an existing enum-based Companion preset category file. This plugin
packages the guidance from `SKILL.md` into marketplace-ready metadata so agents can
discover and apply the pattern quickly during Bitfocus Companion module work.

## When to Use

- An existing `src/presets/preset-{category}.ts` file already contains the right category.

- You need to add a new preset entry without wiring a new file into `presets.ts`.

- You want a reference for button preset shape, steps, styles, and feedbacks.

- You need to keep preset IDs typed and namespaced with the category prefix.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add OWNER/companion-ai-skills
copilot plugin install companion-add-preset-to-category-file@companion-ai-skills
```

### Manual
Copy this directory to `.github/skills/companion-add-preset-to-category-file/` in your project.

## What It Covers

- How to extend the preset enum with a globally unique preset ID.

- How to add a button preset with style, steps, and feedbacks.

- How to reference action enums instead of string literals.

- How to avoid accidental UI grouping mistakes with mismatched categories.

## Example Requests

- "add preset to existing file"

- "extend preset enum"

- "help with add preset to category file"

## Activation Hints

- It is a strong match for requests about `add preset to existing file`.

- It also fits prompts mentioning `extend preset enum`.

- Use it when work is clearly about Bitfocus Companion modules and `presets`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
