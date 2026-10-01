# Companion v1 to v2: Expression Upgrade Scripts

Retype historical upgrade scripts and add the expression-aware upgrade scripts that ship with a Companion v1 to v2 migration. This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply it quickly during Bitfocus Companion module work.

## When to Use

- Upgrade scripts stop compiling after bumping base to 2.x.

- A `textinput` used for numbers or booleans becomes a `number` or `checkbox` field.

- You are renaming dropdown IDs or switching from 0-based to 1-based values.

- Actions used `setCustomVariableValue` and should return results (2.1).

## Installation

### Claude Code
```bash
/plugin marketplace add digitaldrummerj/bitfocus-companion-skills
/plugin install companion-v1-to-v2-expression-upgrades@bitfocus-companion-skills
```

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v1-to-v2-expression-upgrades@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v1-to-v2-expression-upgrades/` in your project.

## What It Covers

- The wrapped `{ isExpression, value }` option shape.

- Retyping historical scripts with literal-value helpers.

- Fixup helpers, dropdown renames, index offsets, builtin invert, action result store.

- Unit-testing upgrade scripts.

## Example Requests

- "my upgrade scripts break after moving to base 2"

- "convert this textinput to a number field without breaking buttons"

- "write an upgrade script for friendly dropdown ids"

## Activation Hints

- It is a strong match for requests about `upgrade scripts for v2 migration`.

- It also fits prompts mentioning `isExpression upgrade script`.

- Use it when work is clearly about migrating a Bitfocus Companion module from the v1 API to the v2 API.

- It pairs with the other `companion-v1-to-v2-*` and `companion-v2-*` skills.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
