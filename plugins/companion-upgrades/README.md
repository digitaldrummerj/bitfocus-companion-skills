# Companion Upgrades

Write Companion upgrade scripts that safely migrate config, actions, and feedbacks
across breaking changes. This plugin packages the guidance from `SKILL.md` into
marketplace-ready metadata so agents can discover and apply the pattern quickly during
Bitfocus Companion module work.

## When to Use

- You are making a breaking change that could affect saved user configurations.

- You need to rename config fields, action IDs, feedback IDs, or option IDs.

- You want to preserve button setups during migrations.

- You need helper patterns for boolean conversion or built-in invert upgrades.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add OWNER/companion-ai-skills
copilot plugin install companion-upgrades@companion-ai-skills
```

### Manual
Copy this directory to `.github/skills/companion-upgrades/` in your project.

## What It Covers

- The `CompanionStaticUpgradeScript` array model and version indexing.

- Config, action, and feedback migration patterns.

- Helper factories such as `EmptyUpgradeScript` and boolean conversion helpers.

- Common migration mistakes such as reordering scripts or forgetting return values.

## Example Requests

- "upgrade script"

- "migrate config"

- "help with upgrades"

## Activation Hints

- It is a strong match for requests about `upgrade script`.

- It also fits prompts mentioning `migrate config`.

- Use it when work is clearly about Bitfocus Companion modules and `upgrades`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
