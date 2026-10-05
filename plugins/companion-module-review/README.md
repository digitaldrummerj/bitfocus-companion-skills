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
| Scorecard / issue-list format | `skills/review-scorecard/` |
| Running and interpreting `validate-template.ps1` (finding ids, freshness gate, accepted deviations) | `skills/review-template-check/` |
| Same-tag follow-up reviews | `skills/review-follow-up-same-tag/` |
| Yarn 4 lockfile follow-ups | `skills/review-yarn4-lockfile-validation/` |
| Workspace layout, review file naming, TRACKER rows | `skills/review-workspace-conventions/` |
| Pipeline scripts: `bitfocus-queue`, `bitfocus-setup-module`, `module-facts`, `validate-template`, `api-scan`, `update-templates`, `archive-reviewed-clones`, `cleanup-modules` | `scripts/` |

The skills call the scripts as `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/<name>.ps1`, and the scripts locate everything at runtime:

| What | How it's found | Override |
|---|---|---|
| The workspace | The current directory, or its nearest ancestor with `reviews/` | `COMPANION_REVIEW_ROOT` |
| The clones and templates | Under the workspace | `COMPANION_MODULES_DIR`, `COMPANION_TEMPLATES_DIR` |
| The installed compliance skill plugin | 1. a sibling source checkout<br>2. `~/.claude/plugins/installed_plugins.json`<br>3. the plugin cache | `COMPANION_SKILLS_DIR` (checked first) |

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
