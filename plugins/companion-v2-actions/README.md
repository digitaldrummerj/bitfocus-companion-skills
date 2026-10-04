# Companion v2 Actions

Reference for @companion-module/base v2.x action definitions, typed schemas, expression-parsed options, subscribe, learn and 2.1 results. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding or fixing an action in a v2 module.

- You need to type action options with a schema.

- You want to use subscribe/unsubscribe, learn, abort signals or action results.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-actions@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-actions/` in your project.

## What It Covers

- Action schema typing and CompanionActionDefinitions.

- Expression and variable handling of option values.

- Subscribe/unsubscribe with optionsToMonitorForSubscribe and learn.

- 2.1 abort signals and hasResult actions.

## Example Requests

- "add an action to my v2 module"

- "how does expression parsing work for action options"

- "return a value from a companion action"

## Activation Hints

- It is a strong match for requests about `v2 action definition`.

- It also fits prompts mentioning `CompanionActionDefinitions`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
