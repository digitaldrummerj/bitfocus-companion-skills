# Companion Add Feedback to Category File

Add new feedbacks to an existing Companion feedback category file without creating a new
category. This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply the pattern quickly during Bitfocus Companion
module work.

## When to Use

- An existing `src/feedbacks/feedback-{category}.ts` file already fits the change.

- You only need to extend the feedback enum and object in that file.

- You want to add boolean or advanced feedback logic without adding a new category.

- You need patterns for room guards, option casting, and state-based callbacks.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-add-feedback-to-category-file@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-add-feedback-to-category-file/` in your project.

## What It Covers

- How to add a new feedback enum member safely.

- How to implement boolean and advanced feedback definitions.

- How to reuse shared options such as room selectors.

- How to avoid missing-state and return-shape mistakes.

## Example Requests

- "add feedback to existing file"

- "extend feedback category"

- "help with add feedback to category file"

## Activation Hints

- It is a strong match for requests about `add feedback to existing file`.

- It also fits prompts mentioning `extend feedback category`.

- Use it when work is clearly about Bitfocus Companion modules and `feedbacks`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

- `.claude-plugin/plugin.json` provides the Claude Code plugin manifest (same content as `plugin.json`).

## License

MIT.
