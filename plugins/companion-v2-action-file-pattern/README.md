# Companion v2 Action File Pattern

Create a new v2 action category file with an enum, an enum-keyed schema type and a factory, and wire it into the actions.ts aggregator. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding a new category of actions to a v2 module.

- You need to create src/actions/action-{category}.ts from scratch.

- You need to wire a new file into actions.ts and ModuleSchema.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-action-file-pattern@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-action-file-pattern/` in your project.

## What It Covers

- Enum IDs plus an enum-keyed ActionsSchema{Category} type.

- GetActions{Category}() returning CompanionActionDefinitions.

- Aggregator intersection type and setActionDefinitions spread.

- Step-by-step recipe and common mistakes.

## Example Requests

- "create a new action category file"

- "add a recording actions file to my v2 module"

- "wire actions into the aggregator"

## Activation Hints

- It is a strong match for requests about `v2 new action category`.

- It also fits prompts mentioning `v2 action file pattern`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
