---
name: review-companion-module
description: Review a Bitfocus Companion module for release approval and produce a ranked review report. Use when the user says "review the next module", "review a/the (next) companion module", "review companion-module-X", "start a module review", or names a module. Supports a review scope — "just the tag/the changes" (tag), "the whole module / a full review" (module), or "both" — defaulting to tag. Runs the deterministic scripts, dispatches parallel review subagents, and assembles one review markdown — REPORT ONLY (never modifies the module).
---

# Review a Companion Module (orchestrator)

You are the review **coordinator**. Run the pipeline below **in order**, then assemble one review file. This is **REPORT ONLY**: never modify the module's code, create fix branches, or push to its repo. The maintainer applies the fixes. Your only output is the review markdown under `reviews/` (plus a `TRACKER.md` row). The only things that touch the developer portal are assigning the reviewer (Step 2b) and, when delivering, **`companion-module-review:review-submit`**: requesting changes or approving there. Delivery happens in auto mode, or on the user's "submit" (Step 0b).

All commands run from the root of the current workspace — the companion-module-review repo you're running in (it holds `reviews/`, `companion-modules-reviewing/` and `companion-module-templates/`). The scripts ship with this plugin: invoke them as `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/<name>.ps1`. They find the workspace from the current directory (override with `COMPANION_REVIEW_ROOT`). If a script reports that no workspace or no templates were found, tell the user to run `pwsh setup.ps1` in the workspace.

## Step 0 — Determine the review scope

Pick the scope from the request (default **`tag`** if unspecified):

- **`tag`** — review only what changed in this release (the `previousTag..reviewTag` diff). Triggers: explicit `tag`, or "just the tag", "the changes", "what changed". Pre-existing issues are not surfaced.
- **`module`** — review the whole current module flat (all findings by severity, no diff, no new-vs-existing split). Triggers: explicit `module`, "the whole module", "full review", "the existing module".
- **`both`** — whole module reviewed AND classified new vs pre-existing. Triggers: explicit `both`.

State the chosen scope to the user before proceeding.

## Step 0b — Ask the delivery mode (once per review cycle)

Ask with AskUserQuestion, once at the start of the cycle (one review, or a whole batch), unless the prompt already says which:

- **Hold for my review** (default): write the review and stop at Step 8. The user reads it and says "submit".
- **Deliver automatically**: as soon as the review is lint-clean, deliver it with **`companion-module-review:review-submit`**. That means push it, then click **Request changes** with the findings message or **Approve** in the portal, then watch the build.

Both portal actions email the maintainer and can't be undone, so never assume auto.

## Step 1 — Pick the target

- If the user named a module (e.g. "allenheath-sq"), use it (strip any `companion-module-` prefix).
- If the user also named a **version/tag** (e.g. "v2.1.0" / "2.1.0"), capture it — it selects which pending version to review when a module has more than one queued. A version only applies alongside a named module; without one, the **oldest** pending version is reviewed.
- Otherwise: `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/bitfocus-queue.ps1 -Json` → the target is the first entry whose `state` is `needs-review` (the script excludes `feedback-pending`). The queue lists **connection modules only** (`moduleType: companion-connection`): this pipeline doesn't review surface modules, and the setup script refuses one by name. If all are `feedback-pending`, tell the user there's nothing new and stop.

## Step 2 — Set up the module

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/bitfocus-setup-module.ps1 -ModuleName <name> -Json
```

Add `-ReviewTag <version>` when the user specified a version (omit it otherwise — the oldest pending version is used). Clones into `companion-modules-reviewing/` **and checks out the resolved tag**, so the fact sheet (Step 3), the validate-template build (Step 4), and the `previousTag..reviewTag` diff (Step 5) all reflect that exact version. Returns `{ module, reviewTag, previousTag, newModule, directory }`; `previousTag` is needed for `tag`/`both`, not for `module` scope. `newModule` is `true` when the module has no approved version, i.e. it has never been published (the portal's "New module" badge); it feeds the **Release** row in Step 7. If a specified version isn't pending, the script errors and lists the module's pending versions — relay that. If it errors that the module is already reviewed with feedback pending, surface that; only re-run with `-Force` if the user confirms.

## Step 2b — Assign yourself as reviewer

Invoke **`companion-module-review:review-assign-reviewer`** with the module, so nobody else picks it up while you review. Skip this when the prompt says assignment was already done (a batch assigns everything up front). The skill never takes over a module someone else holds, and it never blocks the review. If it can't assign, note what it reported and carry on.

## Step 3 — Generate the shared fact sheet

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/module-facts.ps1 -ModuleDir <directory> -GitTag <reviewTag> -Json
```

Capture `language`, `apiVersion`, **`apiSkill`** (`companion-v1-api-compliance` or `companion-v2-api-compliance` — a plugin from the bitfocus-companion-skills marketplace, invoked as `<apiSkill>:<apiSkill>`), **`apiSkillInstalled`**, `protocols`, `srcFiles`, `templateCheck`, **`templateFreshness`**, **`sourceLinkBase`** (`<repoWebUrl>/blob/<reviewCommit>`: the GitHub base for every source link in the review, pinned to the tag's full commit SHA), and the API-level fields:

| Field | Meaning |
| --- | --- |
| `apiLevel` | `1`, `2.0`, `2.1`, … — the exact API rule set (resolved from `yarn.lock` / lockfile / `node_modules`, falling back to the `package.json` range) |
| `baseVersion` / `baseVersionSource` | e.g. `2.1.3` from `yarn.lock` |
| `apiAmbiguous` | `true` when only a caret range (`^2.x`) was available, so the minor version had to be assumed |
| `minCompanion` | the Companion version the module needs (4.3 for API 2.0, 5.0 for API 2.1) |
| `apiReferences` | the reference files of `apiSkill` the compliance reviewer must load (e.g. `references/v2.0.md`, `references/v2.1.md`) |
| `apiScan` | deterministic version-specific hints from `api-scan.ps1` (leads for the compliance reviewer, not findings) |

If **`apiSkillInstalled`** is `false`, stop and tell the user to run `pwsh setup.ps1` in the workspace (or `claude plugin install <apiSkill>@bitfocus-companion-skills`): the compliance reviewer can't apply the version rules without that plugin.

### Step 3a — Template freshness gate (STOP here if it fails)

If **`templateFreshness`** is anything other than `fresh`, `pinned`, or `skipped` — i.e. `stale`, `unverified`, or `error` — **STOP**. Do not run Step 4, do not dispatch subagents, do not write a review file, do not add a TRACKER row.

The reason to stop rather than report: with an out-of-date template every `CONFIG-DIFF`, `FILE-MISSING`, `PKG-DEVDEP`, `MAN-RUNTIME`, and `.yarnrc.yml` key finding is derived from wrong expectations. A report full of false Criticals is worse than no report, and the maintainer can't act on your local clone anyway. Stopping here — before `-RunBuild`'s full `yarn install` and before three subagents — also costs nothing.

Tell the user the local and upstream SHAs from `templateCheck` / the validator output and:

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/update-templates.ps1     # then re-run the review
```

Templates are never refreshed automatically because concurrent review sessions share these clones. If the user explicitly wants an offline run, re-invoke Step 3 **and** Step 4 with `-SkipTemplateFreshness` (threading it to only one still aborts) and record `Template freshness: skipped (offline)` in the meta table.

## Step 4 — Deterministic compliance + build/lint

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/validate-template.ps1 -ModuleDir <directory> -ExpectedVersion <reviewTag> -RunBuild -Json
```

Interpret the output with the **`companion-module-review:review-template-check`** skill (invoke it with the Skill tool: finding ids, accepted deviations, environment findings). Every `Critical` and `High` finding is **blocking** — carry each into the review verbatim. (These are full-module checks; they apply regardless of scope, since a release that breaks the build/template can't ship.) A `.github/**` file the module has but that differs from the template is High; a missing one is `Medium`, reported but non-blocking.

`TEMPLATE-STALE`, `TEMPLATE-UNVERIFIED`, and `TEMPLATE-COVERAGE` are **environment** findings about your workspace, not the module — they never appear in the review markdown. The first two should have already stopped you at Step 3a; `TEMPLATE-COVERAGE` means the template gained a file the validator has no rule for, so mention it to the user and move on.

## Step 5 — Scope the review surface

- **`tag`:** `git -C <directory> diff <previousTag>..<reviewTag>` — the changed files/hunks are the review surface; every code finding is NEW/REGRESSION.
- **`module`:** no diff; the whole current `src/` is the surface; findings are reported flat (no classification).
- **`both`:** whole module is the surface AND each finding is classified NEW / REGRESSION / PRE-EXISTING via the same diff (only NEW/REGRESSION block; pre-existing medium-and-lower are non-blocking notes).
- **First release** (`newModule` is `true`; `previousTag` = "(none — first release)") under `tag`/`both`: there's no diff, so fall back to a full review and note it in the report. A re-review of a module that has still never been published is a first release too: diff against the previously reviewed tag for the follow-up, but the **Release** row still says new module.
- **Re-review:** if a prior review for this module exists under `reviews/<name>/`, invoke the **`companion-module-review:review-follow-up-same-tag`** skill and frame this as a follow-up that *verifies the maintainer's fixes* — still report-only.

## Step 6 — Dispatch the review subagents (in parallel)

Launch all three with the Agent tool in one message, using the plugin's namespaced agent types (`companion-module-review:companion-protocol-reviewer`, `companion-module-review:companion-qa-reviewer`, `companion-module-review:companion-compliance-reviewer`). Give each: the **scope** (Step 0), the **fact sheet**, the clone `directory`, the `previousTag`, and the `apiSkill` name. Give the compliance reviewer also `apiLevel`, `baseVersion`, `apiSkillDir`, `apiReferences`, `apiScan`, and `newModule` (Step 2; it applies the first-release rules). Each returns findings (severity, `file:line`, classification when scope ≠ module, description, suggested fix **for the maintainer**) — they never edit the module.

- `companion-protocol-reviewer` — connection lifecycle, sockets, OSC/TCP/UDP/HTTP/Bonjour, timeouts, `destroy()` cleanup, `InstanceStatus`.
- `companion-qa-reviewer` — bugs, edge cases, error handling, performance, async correctness, silent failures.
- `companion-compliance-reviewer` — invokes the `<apiSkill>:<apiSkill>` skill (and only the listed `apiReferences`); actions/feedbacks/presets/variables/config structure, upgrade scripts; runs the module's tests when present and reports **only failures**, as findings.

(Template/build/lint already came from Step 4 — don't duplicate it.)

Every Critical/High a reviewer returns carries **Evidence** (verbatim code with `file:line`) and a **Confirm by** line. A reviewer Critical/High without evidence is demoted to 🟡 Medium before Step 6b.

## Step 6b — Verify every AI-judgment Critical/High (in parallel)

Dedupe the reviewers' findings by file+line first (merge duplicates; keep the higher severity). Then, for **each** remaining Critical/High that came from a reviewer — **not** the Step-4 validator findings, which are deterministic and tested — launch one `companion-module-review:companion-finding-verifier` in a single parallel message. Give each: the one finding (severity, title, `file:line`, description, the reviewer's evidence), the clone `directory`, the scope, `reviewTag`, and `previousTag`. Each verifier tries to **refute** the finding and returns `VERDICT` / `SEVERITY` / `EVIDENCE` / `CONFIRM BY` / `REASON` / `ASSUMPTIONS`.

Drop any finding that rests only on an assumption about the **device's** behaviour contradicting how the module is written (trust the maintainer's knowledge of their device), and any hypothetical network-timing or config-change race (Companion handles drops and config changes). Timers, sockets or listeners not stopped in `destroy()` or after `configUpdated()` always stay. Keep every remaining `ASSUMPTIONS` entry from the reviewers (Step 6) and the verifiers, together with the findings it affects. Merge duplicates. They become the review's **❓ Assumptions to Confirm** section.

Apply the verdicts:

- **`confirmed`** → keep it at the verifier's `SEVERITY`; Source `🔎 <reviewer> — verified`; use the verifier's EVIDENCE and CONFIRM BY in the report (freshly captured, not the reviewer's copy).
- **`refuted`** → drop it from the report. Record `<title> — <REASON>` for the Step 8 summary.
- **`uncertain`** → keep it at the verifier's `SEVERITY`; Source `🔎 <reviewer> — ⚠️ needs your check`; include the verifier's CONFIRM BY so the human knows what to check.

If the verifier's `SEVERITY` is Medium or lower, the finding moves out of the blocking sections. When an `uncertain` verdict (or one of the ❓ assumptions) depends on how Companion itself behaves, such as upgrade-script input, option formats or migrations, suggest a live test in the summary you give the reviewer (they can ask in plain words or run **`/companion-module-review:review-live-test`**) instead of leaving it open. Never run one during the review: the live-test skill runs only when the reviewer asks. Findings below High from the reviewers are not verified.

## Step 7 — Assemble the review

Invoke the **`companion-module-review:review-report-format`** skill for the section order, the Verdict line, the 📋 Issues list, the per-finding block (**Source** / Evidence / Confirm by) and 📝 Additional Notes. There is **no scorecard**. Put **❓ Assumptions to Confirm** right after the Verdict (each assumption links to the findings it affects), and make every cited module file a GitHub link built from `sourceLinkBase` (review-report-format → Source Links): `[`src/x.ts:10-20`](<sourceLinkBase>/src/x.ts#L10-L20)`. Write every finding **user-first** (review-report-format → "Write for the user, not the code"): a title that names the visible effect, then **What goes wrong** (a concrete scenario in Companion UI terms), then **Why it happens** (plain mechanism, any API jargon defined), and only then the code. Rewrite reviewer wording that leads with identifiers. Merge the Step-4 deterministic findings (Source `🤖 validate-template (<ID>)`) + the verified reviewer findings into ONE file, deduped by file+line. `TSCONFIG-DIFF` validator notes go to **📝 Additional Notes** (one line each), never into a severity section. 📋 Issues doesn't list them, but it ends with a `### Notes` group linking to the section (`- [📝 Additional Notes](#-additional-notes)`) whenever there is one. Header meta table includes a **`Scope:`** line (`tag` / `module` / `both`) and a **`Template`** row naming the exact revision the verdict was rendered against, so a disputed finding can be re-checked at that commit later:

```markdown
| **Template** | `companion-module-template-js-v1` @ `9e222b4` (2026-03-26, pinned) · `.yarnrc.yml` from `companion-module-template-js` @ `0f916f9` (2026-06-24) |
```

Take the values from the validator's `templateRevision` / `yarnrcTemplate`; v2 modules have no second clause. Right after the **Version** row, add a **`Release`** row from Step 2's `newModule` / `previousTag`, using one of these two forms:

```markdown
| **Release** | New module — never published |
| **Release** | Update — last published v4.0.0 |
```

Add an **`API`** row from the fact sheet:

```markdown
| **API** | 2.1 (base 2.1.3, yarn.lock) — requires Companion 5.0+ |
```

For v1 modules write e.g. `1 (base 1.14.1, yarn.lock)`. If `apiAmbiguous` is true, add a 🟡 Medium finding asking the maintainer to pin `@companion-module/base` with `~2.N.x` (or commit the lockfile) so the target API version — and the Companion version users need — is explicit. If the run used `-SkipTemplateFreshness`, append `— freshness not verified (offline run)`. Sections in order: title + meta, **Verdict**, **📋 Issues** (Blocking / Non-blocking), `🔴 Critical` → `🟠 High` → `🟡 Medium` → `🟢 Low` → `💡 Nice to Have` → `🔮 Next Release` → `⚠️ Pre-existing Notes` → `📝 Additional Notes`. Omit empty sections. The **Verdict** section is the status line only (`✅ Approved` / `❌ Changes Required`) — no reasoning paragraph. There is **no 🧪 Tests section**: a failing test run is reported as a normal finding, and nothing else about tests (passing, quality, coverage or absence) goes in the report. Plain text (no emoji) in individual issue headings for stable anchors.

Scope adjusts the presentation:

- **`tag`:** omit `⚠️ Pre-existing Notes`; every finding is classified 🆕 NEW or 🔙 REGRESSION.
- **`module`:** omit `⚠️ Pre-existing Notes` and the Classification lines; add the line "whole-module scope — new vs pre-existing not assessed." under the meta table.
- **`both`:** classify every finding and include `⚠️ Pre-existing Notes`.

Write to `reviews/<name>/review-<name>-<reviewTag>-<YYYYMMDD-HHMMSS>.md` in the workspace (layout and naming: **`companion-module-review:review-workspace-conventions`**) (`mkdir -p reviews/<name>/` first; timestamp from `date -u +"%Y%m%d-%H%M%S"`). Append to `reviews/TRACKER.md`:

```markdown
| ⬜ | <name> | <reviewTag> | <YYYY-MM-DD> | [review](<name>/review-<name>-<reviewTag>-<stamp>.md) |
```

The ⬜ stays until the user delivers the review and marks it ✅ — that's what keeps the module from being reviewed twice.

## Step 7a — Lint the review (must be clean)

Run the plugin's lint script on the review file:

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/lint-review.ps1 -ReviewFile reviews/<name>/<review-file>.md
```

The script refuses anything that isn't a `.md` file under the workspace's `reviews/` (exit 2). It then lints **copies** of the files in a fresh temp directory with a **pinned** `markdownlint-cli2` and the plugin's `config/.markdownlint.jsonc`. markdownlint-cli2 can execute code from config files next to what it lints (`.markdownlint-cli2.*` `customRules`/plugins, `.cjs`/`.mjs` configs, `package.json`), and `npx` prefers a local `node_modules`/`.npmrc`, so the linter never runs in the workspace or a review folder. Output shows the original file names, and `-Fix` writes the fixed copies back. It's covered by the workspace's existing `pwsh …/companion-module-review/scripts/*` permission, so don't call `npx markdownlint-cli2` directly.

- **Exit 0** means clean.
- **Exit 1** means lint errors: re-run with `-Fix` (blank lines around headings/lists/fences, table pipe spacing), then hand-fix what remains. That's typically MD036 (a bold-only line used as a heading → make it a `###` heading) and MD040 (a fence with no language → add `ts`/`js`/`json`/`bash`/`text`…). Re-run until it exits 0.
- After a `-Fix`, re-check that tables with `\|` inside code spans and the 📋 Issues anchors are intact.

The rules are in **`companion-module-review:review-report-format`** → Markdown Lint. Never finish with lint errors: the maintainer's editor shows every one.

## Step 8 — Stop, or deliver (auto mode)

Tell the user the review file path, the scope, the verdict (✅ Approved / ❌ Changes Required), and a verification summary so they know where their own checking is needed:

```text
Blocking: N  (X deterministic · Y verified · Z ⚠️ need your check)
Dropped by verification: <title> — <reason>; …   (or "none")
Assumptions to confirm: K  (A1 → C1, H2; A2 → H1; …)   (or "none")
```

Confirmed or corrected assumptions are fed back into the review skills (the api-compliance references, the reviewer agents), so later reviews don't have to assume the same thing.

The ⚠️ items are the only blocking findings the user must check against the code; verified ones only need a glance at the quoted Evidence. Do **not** modify the module, create a `fix/...` branch, or push anything to the module's repo.

Then, by the Step 0b delivery mode:

- **Hold** (default): stop. The user reviews the report and says "submit", which runs **`companion-module-review:review-submit`**.
- **Deliver automatically**: run **`companion-module-review:review-submit`** now, unless the prompt says this review is part of a batch. A batch delivers afterwards, from the main session.

## Reviewing several modules (a batch)

When the user queues up several modules:

1. Ask the Step 0 scope and the Step 0b delivery mode **once** for the whole batch.
2. **Before any review starts**, assign the user to **every** module in the batch. Run **`companion-module-review:review-assign-reviewer`** with the full list from the main session, so nobody else picks one up while the batch runs.
3. Run the reviews. Tell each one that assignment is already done and that it must **not** deliver. Parallel reviews must never drive the browser or push to git.
4. After the reviews finish:
   - **Auto mode:** deliver each one with `review-submit`, one at a time, in queue order, from the main session.
   - **Hold mode:** wait for the user to say "submit".
