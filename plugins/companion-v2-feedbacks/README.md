# Companion v2 Feedbacks

Reference for @companion-module/base v2.x feedback definitions, typed schemas, checkFeedbacks, the callback/unsubscribe lifecycle and 2.1 affectedProperties. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding or fixing a feedback in a v2 module.

- You need boolean, value or advanced feedback typing.

- You need to trigger feedback updates from device state.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-feedbacks@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-feedbacks/` in your project.

## What It Covers

- Feedback schema typing with type and options.

- Boolean, value and advanced feedbacks with base64 imageBuffer.

- checkFeedbacks(id, …), checkAllFeedbacks and previousOptions.

- 2.1 affectedProperties and abort signals.

## Example Requests

- "add a feedback that turns the button red when muted"

- "create a value feedback"

- "why does checkFeedbacks not compile"

## Activation Hints

- It is a strong match for requests about `v2 feedback definition`.

- It also fits prompts mentioning `CompanionFeedbackDefinitions`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
