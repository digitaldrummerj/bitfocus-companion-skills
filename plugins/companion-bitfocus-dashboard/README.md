# Companion Bitfocus Dashboard

Discover pending Companion module reviews from the Bitfocus developer portal and prepare
repos for review. This plugin packages the guidance from `SKILL.md` into marketplace-
ready metadata so agents can discover and apply the pattern quickly during Bitfocus
Companion module work.

## When to Use

- You need to know which Bitfocus Companion modules are waiting for review.

- You want to inspect the oldest pending item or the full review queue.

- You need to derive the GitHub repository and previous approved tag for a module.

- You want to clone or set up a module repo for review work.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-bitfocus-dashboard@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-bitfocus-dashboard/` in your project.

## What It Covers

- Authentication with the Bitfocus developer portal using `gh auth token`.

- The pending-review and version-history API endpoints.

- How to find the previous approved tag or detect a first release.

- How to derive repo URLs and clone modules into a review workspace.

## Example Requests

- "what's pending"

- "pending review queue"

- "help with bitfocus dashboard"

## Activation Hints

- It is a strong match for requests about `what's pending`.

- It also fits prompts mentioning `pending review queue`.

- Use it when work is clearly about Bitfocus Companion modules and `review`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
