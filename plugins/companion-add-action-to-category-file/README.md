# Companion Add Action to Category File

Add new actions to an existing Companion action category file without changing the
aggregator. This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply the pattern quickly during Bitfocus Companion
module work.

## When to Use

- An existing `src/actions/action-{category}.ts` file already matches the feature area.

- You only need to extend an enum and the `actions` object in that file.

- You want to add one or more callbacks without touching `actions.ts`.

- You need a quick reference for sync versus async action callback forms.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-add-action-to-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-add-action-to-category-file/` in your project.

## What It Covers

- How to add a new enum member with a globally unique action ID.

- How to append the matching action definition in the existing file.

- When to use sync callbacks versus async callbacks with variable parsing.

- Common mistakes such as duplicate IDs or mismatched enum keys.

## Example Requests

- "add action to existing file"

- "extend action category"

- "help with add action to category file"

## Activation Hints

- It is a strong match for requests about `add action to existing file`.

- It also fits prompts mentioning `extend action category`.

- Use it when work is clearly about Bitfocus Companion modules and `actions`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
