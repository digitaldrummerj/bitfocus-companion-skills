# Companion v2 Variable Definition

Declare @companion-module/base v2.x variables with a typed VariablesSchema and the object form of setVariableDefinitions. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are declaring variables in a v2 module.

- You need dynamic per-channel or per-input variables.

- You need to type variables in ModuleSchema.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-variable-definition@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-variable-definition/` in your project.

## What It Covers

- VariablesSchema and the object form of setVariableDefinitions.

- Template-literal keys for dynamic families.

- JSON value types and ID naming rules.

- Splitting variables by area.

## Example Requests

- "add a variable to my v2 module"

- "define per-channel variables"

- "convert setVariableDefinitions to the object form"

## Activation Hints

- It is a strong match for requests about `v2 variable definition`.

- It also fits prompts mentioning `VariablesSchema`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
