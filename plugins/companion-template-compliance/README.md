# Companion Template Compliance

Review Companion modules against the official JavaScript and TypeScript template
requirements. This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply the pattern quickly during Bitfocus Companion
module work.

## When to Use

- You are reviewing whether a module matches the official JS or TS starter template.

- You need to verify required files, source layout, and generated config files.

- You want to validate `package.json`, `manifest.json`, `HELP.md`, and husky setup.

- You need a critical-severity checklist for approval or rejection decisions.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-template-compliance@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-template-compliance/` in your project.

## What It Covers

- How to detect JS versus TS modules and apply the right template rules.

- Required files and exact config-file contents for both templates.

- Package, manifest, keyword, and HELP.md compliance checks.

- A severity model and reporting format for review findings.

## Example Requests

- "template compliance"

- "official template"

- "help with template compliance"

## Activation Hints

- It is a strong match for requests about `template compliance`.

- It also fits prompts mentioning `official template`.

- Use it when work is clearly about Bitfocus Companion modules and `compliance`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
