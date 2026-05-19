# Companion v2 API Compliance

Review @companion-module/base v2.0+ modules for entrypoint, manifest, expression, and
upgrade compliance. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are reviewing a module that uses `@companion-module/base` v2.0 or newer.

- You need to verify the class entrypoint, manifest type, and Node 22 runtime.

- You want to check expression handling, feedback behavior, variables, and presets.

- You need to spot v1-era APIs that must be replaced in v2 modules.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-v2-api-compliance@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-api-compliance/` in your project.

## What It Covers

- Critical v2 requirements for entrypoints, runtime, and typing.

- High-risk API changes such as variables, feedbacks, presets, and upgrade options.

- Expression handling rules and option-value behavior in v2.

- A quick comparison against legacy v1 expectations.

## Example Requests

- "v2 api compliance"

- "base v2.0"

- "help with v2 api compliance"

## Activation Hints

- It is a strong match for requests about `v2 api compliance`.

- It also fits prompts mentioning `base v2.0`.

- Use it when work is clearly about Bitfocus Companion modules and `compliance`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
