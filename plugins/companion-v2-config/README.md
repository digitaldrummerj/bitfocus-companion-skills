# Companion v2 Config

Reference for @companion-module/base v2.x configuration fields, typed config and secrets, isVisibleExpression and the config lifecycle. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding connection settings to a v2 module.

- You need to store a password or API key safely.

- You need fields that show or hide based on other fields.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-config@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-config/` in your project.

## What It Covers

- ModuleConfig/ModuleSecrets type aliases and field types.

- secret-text, saveConfig(config, secrets) and the lifecycle.

- isVisibleExpression and minLength.

- Regex constants and common pitfalls.

## Example Requests

- "add a password field to my v2 module"

- "show a field only when polling is enabled"

- "what config field types does v2 support"

## Activation Hints

- It is a strong match for requests about `v2 config fields`.

- It also fits prompts mentioning `secret-text`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
