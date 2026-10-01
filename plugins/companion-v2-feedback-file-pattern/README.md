# Companion v2 Feedback File Pattern

Create a new v2 feedback category file with an enum, an enum-keyed schema type and a factory, and wire it into the feedbacks.ts aggregator. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You are adding a new category of feedbacks to a v2 module.

- You are splitting a single feedbacks.ts into category files.

- You need to wire a new feedback file into the aggregator.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v2-feedback-file-pattern@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v2-feedback-file-pattern/` in your project.

## What It Covers

- Optional feedback-utils.ts helpers.

- Enum IDs plus an enum-keyed FeedbacksSchema{Category}.

- Aggregator intersection type and setFeedbackDefinitions spread.

- Step-by-step recipe and common mistakes.

## Example Requests

- "create a new feedback category file"

- "split my feedbacks into files"

- "wire feedbacks into the aggregator"

## Activation Hints

- It is a strong match for requests about `v2 new feedback category`.

- It also fits prompts mentioning `v2 feedback file pattern`.

- Use it when work is clearly about a Bitfocus Companion module on `@companion-module/base` v2.x.

- For modules still on v1.x, use the matching v1 skill; for upgrading a v1 module, use `companion-v1-to-v2-migration`.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
