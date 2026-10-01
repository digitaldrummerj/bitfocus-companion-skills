# Companion v2 Add Action to Category File

Add actions to an existing v2 action category file by extending the enum, the schema and the definitions. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding one or more actions to an existing v2 category file.

- The category already exports its enum, schema and factory.

- You need the right option type and schema value type.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-add-action-to-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-add-action-to-category-file/` in your project.

## What It Covers

- The three edits: enum member, schema entry, definition.

- Callback forms including 2.1 results and abort signals.

- Option types with their schema value types.

- Common mistakes and how TypeScript catches them.

## Example Requests

- "add a pause action to the transport file"

- "extend the mixer actions"

- "add another action to action-scene.ts"

## Activation Hints

- It is a strong match for requests about `v2 add action`.

- It also fits prompts mentioning `extend action category v2`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
