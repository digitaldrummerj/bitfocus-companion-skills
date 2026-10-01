# Companion v2 API Compliance

Version-gated review of @companion-module/base v2.x modules (API 2.0 for Companion 4.3+,
API 2.1 for Companion 5.0+) for entrypoint, manifest, ESM, expression, preset, and
upgrade compliance. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are reviewing a module that uses `@companion-module/base` v2.0 or newer.

- You need the review to match the module's exact API version, without demanding 2.1 features from a 2.0 module.

- You need to verify the class entrypoint, manifest type, ESM setup, and Node 22/26 runtime.

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

- Resolving the installed base version (lockfile first) and choosing which rule files apply.

- API 2.0 baseline: entrypoint, manifest, ESM/tsconfig, removed APIs, expression handling, presets, and wrapped upgrade-script options.

- API 2.1 deltas: required `optionsToMonitorForSubscribe`, `affectedProperties`, abort signals, action results, layered/alternatives presets, `internal:*` preset entries, and node26.

- Version-mismatch detection: a 2.0 module that uses 2.1-only features.

- Severity-ranked reporting with pointers to the v2 build and v1→v2 migration skills.

## Example Requests

- "v2 api compliance"

- "base v2.0"

- "v2.1 api compliance"

- "review this module against the Companion 5.0 API"

- "help with v2 api compliance"

## Activation Hints

- It is a strong match for requests about `v2 api compliance`.

- It also fits prompts mentioning `base v2.0`.

- Use it when work is clearly about Bitfocus Companion modules and `compliance`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains version detection, gating rules, and reporting guidance.

- `references/v2.0.md` holds the API 2.0 baseline checklist (loaded for every 2.x module).

- `references/v2.1.md` holds only the API 2.1 deltas (loaded when base ≥ 2.1.0).

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
