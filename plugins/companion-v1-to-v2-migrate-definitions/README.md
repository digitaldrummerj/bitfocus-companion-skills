# Companion v1 to v2: Migrate Definitions

Before/after transforms for migrating Companion actions, feedbacks, variables, config, and instance typing from base v1.x to v2. This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply it quickly during Bitfocus Companion module work.

## When to Use

- You are converting action or feedback category files from v1 to v2.

- You need to replace `InstanceBaseExt<Config>` with an `import type ModuleInstance`.

- You need to remove `parseVariablesInString` from actions or feedback contexts.

- You need to convert array-form variable definitions, `isVisible`, or `required` fields.

## Installation

### Claude Code
```bash
/plugin marketplace add digitaldrummerj/bitfocus-companion-skills
/plugin install companion-v1-to-v2-migrate-definitions@bitfocus-companion-skills
```

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v1-to-v2-migrate-definitions@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v1-to-v2-migrate-definitions/` in your project.

## What It Covers

- Config `interface` to `type` and instance typing.

- Per-category action and feedback schema types keyed by existing enums.

- Feedback lifecycle, `checkAllFeedbacks`, `affectedProperties` (2.1).

- Variables (object form, template-literal keys) and config field changes.

## Example Requests

- "convert action-user-hand-raised.ts to v2"

- "remove parseVariablesInString from my feedbacks"

- "fix setVariableDefinitions after upgrading to base 2"

## Activation Hints

- It is a strong match for requests about `migrate actions to v2`.

- It also fits prompts mentioning `remove parseVariablesInString`.

- Use it when work is clearly about migrating a Bitfocus Companion module from the v1 API to the v2 API.

- It pairs with the other `companion-v1-to-v2-*` and `companion-v2-*` skills.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `references/behaviour.md` lists the behaviour-preserving judgement calls (useVariables, textinput→number, casts, hidden members, dotted ids).

- `references/shared-options.md` holds shared option fields, option factories, definition helpers and the "Use variable" idiom.

- `references/variables.md` holds literal variable conversion and catalog-driven variable typing.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
