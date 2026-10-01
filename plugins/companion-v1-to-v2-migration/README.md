# Companion v1 to v2 Migration

Step-by-step procedure for migrating a Companion module from @companion-module/base v1.x to the v2 API (2.0/2.1). This plugin packages the guidance from `SKILL.md` into marketplace-ready
metadata so agents can discover and apply it quickly during Bitfocus Companion module work.

## When to Use

- You are upgrading an existing module from `@companion-module/base` 1.x to 2.0 or 2.1.

- You need to replace `runEntrypoint` with a default export and `UpgradeScripts` export.

- You need the CommonJS to ESM tooling changes (tsconfig, `import type`, `.js` imports, `createRequire`).

- You want a phase-by-phase plan with build checks and commit boundaries.

## Installation

### Claude Code
```bash
/plugin marketplace add digitaldrummerj/bitfocus-companion-skills
/plugin install companion-v1-to-v2-migration@bitfocus-companion-skills
```

### GitHub Copilot CLI
```bash
copilot plugin marketplace add digitaldrummerj/bitfocus-companion-skills
copilot plugin install companion-v1-to-v2-migration@bitfocus-companion-skills
```

### Manual
Copy this directory to `.github/skills/companion-v1-to-v2-migration/` in your project.

## What It Covers

- Assessment grep checklist and choosing the 2.0 vs 2.1 target.

- package.json, tsconfig, manifest, and entrypoint changes.

- Hand-off to the definitions, presets, and upgrade-script migration skills.

- Test updates and the final verify loop (build, lint, test, companion-module-check, package).

## Example Requests

- "migrate this module to companion api v2"

- "upgrade base 1.14 to 2.1"

- "remove runEntrypoint and use a default export"

## Activation Hints

- It is a strong match for requests about `migrate to v2`.

- It also fits prompts mentioning `upgrade to companion api v2`.

- Use it when work is clearly about migrating a Bitfocus Companion module from the v1 API to the v2 API.

- It pairs with the other `companion-v1-to-v2-*` and `companion-v2-*` skills.

## Files

- `SKILL.md` contains the full agent-facing guidance.

- `references/inventory.md` holds the Phase 0.3 grep inventory of v1 APIs.

- `references/tests.md` holds the Phase 8 test-rewrite table.

- `manifest.json` exposes searchable metadata for marketplaces and tooling.

- `plugin.json` provides Copilot CLI plugin metadata for installation.

## License

MIT.
