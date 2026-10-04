# Companion v2 Variable Set Value

Set and read @companion-module/base v2.x variable values with typed setVariableValues and getVariableValue. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are pushing device state into variables in a v2 module.

- You need to clear variables on disconnect.

- You want to read back a variable the module set.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-variable-set-value@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-variable-set-value/` in your project.

## What It Covers

- Partial<VariablesSchema> updates and batching.

- Unsetting with undefined.

- Typed getVariableValue.

- Value type rules and common mistakes.

## Example Requests

- "update a variable when the device changes"

- "clear variables on disconnect"

- "store a JSON object in a variable"

## Activation Hints

- It is a strong match for requests about `v2 set variable value`.

- It also fits prompts mentioning `setVariableValues v2`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
