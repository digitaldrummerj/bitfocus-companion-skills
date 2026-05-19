# Companion Feedback File Pattern

Create and wire a new split-file feedback category for a Bitfocus Companion module. This
plugin packages the guidance from `SKILL.md` into marketplace-ready metadata so agents
can discover and apply the pattern quickly during Bitfocus Companion module work.

## When to Use

- You are adding a brand-new logical feedback category.

- No matching `src/feedbacks/feedback-{category}.ts` file exists yet.

- You need to add imports, union types, and spreads in `feedback.ts`.

- You want a safe pattern for feedback helpers, enums, and callback guards.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add OWNER/companion-ai-skills
copilot plugin install companion-feedback-file-pattern@companion-ai-skills
```

### Manual
Copy this directory to `.github/skills/companion-feedback-file-pattern/` in your project.

## What It Covers

- The file layout for split-file feedback modules.

- Typed feedback enums and `GetFeedbacks{Category}` factories.

- Aggregator wiring for imports, typed locals, and object spreads.

- Shared helper usage such as room option factories and live state access.

## Example Requests

- "new feedback category"

- "feedback file pattern"

- "help with feedback file pattern"

## Activation Hints

- It is a strong match for requests about `new feedback category`.

- It also fits prompts mentioning `feedback file pattern`.

- Use it when work is clearly about Bitfocus Companion modules and `feedbacks`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
