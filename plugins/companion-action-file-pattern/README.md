# Companion Action File Pattern

Create and wire a new split-file actions category for a Bitfocus Companion module. This
plugin packages the guidance from `SKILL.md` into marketplace-ready metadata so agents
can discover and apply the pattern quickly during Bitfocus Companion module work.

## When to Use

- You are adding a brand-new logical action category.

- No `src/actions/action-{category}.ts` file exists yet for the feature.

- You need to import and spread the new category inside `actions.ts`.

- You want a typed pattern for enums, factories, options, and callbacks.

## Installation

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skill
copilot plugin install companion-action-file-pattern@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-action-file-pattern/` in your project.

## What It Covers

- The file layout for split-file action modules.

- Typed action enums and `GetActions{Category}` factories.

- Aggregator imports, union typing, and spread composition in `actions.ts`.

- Common build-time mistakes such as duplicate IDs and missing `.js` extensions.

## Example Requests

- "new action category"

- "action file pattern"

- "help with action file pattern"

## Activation Hints

- It is a strong match for requests about `new action category`.

- It also fits prompts mentioning `action file pattern`.

- Use it when work is clearly about Bitfocus Companion modules and `actions`.

- It pairs well with other Companion skills when a task spans actions, feedbacks, presets, or review workflows.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
