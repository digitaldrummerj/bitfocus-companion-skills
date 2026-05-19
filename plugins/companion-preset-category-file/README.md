# Companion Preset Category File

Create and wire a new enum-based preset category file for a split-file Companion module.
This plugin packages the guidance from `SKILL.md` into marketplace-ready metadata so
agents can discover and apply the pattern quickly during Bitfocus Companion module work.

## When to Use

- You are adding a brand-new logical preset category.

- No matching `src/presets/preset-{category}.ts` file exists yet.

- You need to wire the new preset file into `presets.ts`.

- You want typed preset IDs, typed action references, and a consistent button pattern.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-preset-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-preset-category-file/` in your project.

## What It Covers

- The file layout for split-file preset modules.

- Enum-based preset IDs and typed preset factory return values.

- Aggregator imports, union typing, spreads, and return casting.

- Button preset structure with style, steps, and feedback lists.

## Example Requests

- "new preset category"

- "presets.ts aggregator"

- "help with preset category file"

## Activation Hints

- It is a strong match for requests about `new preset category`.

- It also fits prompts mentioning `presets.ts aggregator`.

- Use it when work is clearly about Bitfocus Companion modules and `presets`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
