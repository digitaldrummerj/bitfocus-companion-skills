# Companion v2 Add Feedback to Category File

Add feedbacks to an existing v2 feedback category file by extending the enum, the schema and the definitions, then triggering them. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding one or more feedbacks to an existing v2 category file.

- The category already exports its enum, schema and factory.

- You need the new feedback to update when state changes.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-add-feedback-to-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-add-feedback-to-category-file/` in your project.

## What It Covers

- The three edits plus the checkFeedbacks trigger.

- Boolean, value and advanced feedback requirements.

- Accessing typed, pre-parsed options and previousOptions.

- Common mistakes.

## Example Requests

- "add a clipping feedback to the mixer feedbacks"

- "extend feedback-transport.ts"

- "add another feedback to an existing file"

## Activation Hints

- It is a strong match for requests about `v2 add feedback`.

- It also fits prompts mentioning `extend feedback category v2`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
