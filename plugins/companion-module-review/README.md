# Companion Module Review

The tooling for reviewing Bitfocus Companion modules for release approval. It contains:
- the `/review-module` orchestrator
- the three review subagents
- the review skills
- the PowerShell pipeline scripts

All of it runs inside a **companion-module-review workspace**: a repo that holds `reviews/`, plus the gitignored `companion-modules-reviewing/` and `companion-module-templates/`. Reviews are **report-only**: they never modify the module under review.

## When to Use

- You run Companion module reviews from a companion-module-review workspace.
- You want "review the next module" / `/review-module [name] [version] [tag|module|both]` to:
  1. queue
  2. set up
  3. build the fact sheet
  4. validate the template
  5. run the parallel reviewers
  6. produce one review file and a TRACKER row
  7. assign you as reviewer in the developer portal at the start, and deliver the review there when you say "submit" (or automatically, if you chose that for the cycle): request changes with the findings link, or approve and watch the build

## Installation

### Claude Code

The workspace repo declares this marketplace and plugin in its `.claude/settings.json`, so Claude Code offers to install them when you trust the folder, and the workspace's `setup.ps1` installs anything missing. To install by hand:

```bash
claude plugin marketplace add digitaldrummerj/bitfocus-companion-skills
claude plugin install companion-module-review@bitfocus-companion-skills
```

The compliance reviewer also needs the knowledge plugins from the same marketplace:
- `companion-v1-api-compliance` and `companion-v2-api-compliance`
- `companion-template-compliance`
- the actions, feedbacks, config, variables and upgrades skills, in both v1 and v2 variants
- `companion-osc-integration`

The workspace settings enable all of them.

For development against a local checkout of this repo, run Claude Code with:

```bash
claude --plugin-dir <path-to>/bitfocus-companion-skills/plugins/companion-module-review
```

## What It Covers

| Component | Path |
|---|---|
| Orchestrator skill (`review-companion-module`), invoked by the `/review-module` command | `skills/review-companion-module/`, `commands/review-module.md` |
| Review subagents: `companion-protocol-reviewer`, `companion-qa-reviewer`, `companion-compliance-reviewer` | `agents/` |
| Finding verifier: `companion-finding-verifier` — tries to refute each AI-judgment Critical/High before it reaches the report | `agents/companion-finding-verifier.md` |
| Report format: section order, 📋 Issues list, per-finding Source / Evidence / Confirm by, 📝 Additional Notes (no scorecard) | `skills/review-report-format/` |
| markdownlint config every review must pass (Step 7a via `scripts/lint-review.ps1`; the workspace keeps a matching `.markdownlint.jsonc`) | `config/.markdownlint.jsonc` |
| Running and interpreting `validate-template.ps1` (finding ids, freshness gate, accepted deviations) | `skills/review-template-check/` |
| Same-tag follow-up reviews | `skills/review-follow-up-same-tag/` |
| Live-testing a finding or fix in the user's local Companion: patched test package, old-format test page, Claude in Chrome import + verify | `skills/review-live-test/` |
| Yarn 4 lockfile follow-ups | `skills/review-yarn4-lockfile-validation/` |
| Workspace layout, review file naming, TRACKER rows | `skills/review-workspace-conventions/` |
| Assigning yourself as reviewer in the developer portal (your logged-in Chrome), for one module or a whole batch up front | `skills/review-assign-reviewer/` |
| Delivering a review: push it, then request changes with the findings link or approve in the portal, then watch the build | `skills/review-submit/` |
| Pipeline scripts: `bitfocus-queue` (marks new modules), `bitfocus-setup-module`, `bitfocus-watch-build` (approval build: published / failed / timed out), `module-facts`, `validate-template`, `api-scan`, `lint-review` (Step 7a markdownlint, pinned, `reviews/` only), `update-templates`, `archive-reviewed-clones`, `cleanup-modules` | `scripts/` |

The skills call the scripts as `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/<name>.ps1`, and the scripts locate everything at runtime:

| What | How it's found | Override |
|---|---|---|
| The workspace | The current directory, or its nearest ancestor with `reviews/` | `COMPANION_REVIEW_ROOT` |
| The clones and templates | Under the workspace | `COMPANION_MODULES_DIR`, `COMPANION_TEMPLATES_DIR` |
| The installed compliance skill plugin | 1. a sibling source checkout<br>2. `~/.claude/plugins/installed_plugins.json`<br>3. the plugin cache | `COMPANION_SKILLS_DIR` (checked first) |

Under `companion-module-templates/`, the module's `@companion-module/base` level picks the template: `companion-module-template-{js,ts}-v1` for 1.x, `…-v2.0.4` for 2.0 (pinned at the 2026-08-28 commits), and the plain `companion-module-template-{js,ts}` (`main`, base 2.1) for 2.1 and later. The pins are in `scripts/lib/ReviewState.ps1` (`Get-TemplatePins`). The pinned clones are never fetched; `update-templates.ps1` refreshes `main` only.

## Tests

```bash
pwsh plugins/companion-module-review/scripts/tests/run-all.ps1
```

The tests are hermetic and need no network or workspace.

## Files

- `skills/`, `agents/`, `commands/`: the Claude Code components.
- `scripts/`: the PowerShell review pipeline, with its shared library in `scripts/lib/ReviewState.ps1` and the tests in `scripts/tests/`.
- `.claude-plugin/plugin.json` and `plugin.json`: plugin metadata, kept identical.
- `manifest.json`: searchable marketplace metadata.

## License

MIT.
