# Companion v2 Upgrades

Reference for @companion-module/base v2.x upgrade scripts with expression-wrapped options, secrets and the built-in fixup helpers. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are renaming actions, feedbacks or options in a v2 module.

- You are changing an option type or migrating config.

- You need the v2 upgrade helper functions.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-upgrades@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-upgrades/` in your project.

## What It Covers

- UpgradeScripts export and the append-only rule.

- Wrapped { isExpression, value } options and isInverted.

- Config/secrets migrations and fixup helpers.

- Testing upgrade scripts.

## Example Requests

- "rename an action without breaking buttons"

- "write a v2 upgrade script"

- "convert a textinput option to a number"

## Activation Hints

- It is a strong match for requests about `v2 upgrade script`.

- It also fits prompts mentioning `isExpression upgrade`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
