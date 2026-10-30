---
name: review-template-check
description: Run and interpret validate-template.ps1 (the deterministic template-compliance check of the companion-module-review workspace) — exit codes, the template freshness gate, every finding id, accepted deviations (test-widened tsconfig.json, eslint configs that extend the template's generateEslintConfig, comment-only or binary-rule .gitattributes additions, comment-only or re-indented .github workflows and the template's optional test job, the module author's LICENSE copyright line, an empty maintainer email, root tool config files), tsconfig differences as non-blocking Additional Notes, and which findings stay out of the review. Use in step 4 of a module review. For the general template rules outside a review workspace, use companion-template-compliance:companion-template-compliance.
---

# Skill: review-template-check (validate-template.ps1)

The template rules themselves (what the official template contains and why) are in the
**`companion-template-compliance:companion-template-compliance`** skill. This skill is the review
workspace's deterministic runner for them.

Template compliance is almost entirely **deterministic** — file presence, exact config-file
content, package.json/manifest.json fields, LICENSE text, banned keywords. Do **not** check
these by hand (that is where reviews drift and miss things). Run the script; it compares the
module against the correct template (selected by API version × language) and emits a findings
list. Then apply judgment to the handful of items the script can't decide.

## 1. Run the validator

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/validate-template.ps1 -ModuleDir <module path> -ExpectedVersion <git tag> [-RunBuild]
```

- `-ExpectedVersion` (the submitted git tag, e.g. `v2.1.0`) enables the `package.json` version-match check. Pass it whenever you know the tag.
- `-RunBuild` additionally runs `yarn install --immutable`, `yarn package` (build) and, for TS, `yarn lint`, and gates on success. Use it to satisfy the "build runs / lint runs" review gates. It is slower and needs network.
- Add `-Json` for machine-readable output. Templates are auto-selected from `companion-module-templates/` in the workspace (override with `COMPANION_TEMPLATES_DIR`; the workspace itself with `COMPANION_REVIEW_ROOT`) or pass `-TemplateDir`.

**Which template.** The module's installed `@companion-module/base` version (its `apiLevel`) picks the folder under `companion-module-templates/`:

| Module API level | Template folder | Pinned at |
| --- | --- | --- |
| 1.x | `companion-module-template-{js,ts}-v1` | last v1.x commit (js `9e222b4`, ts `42609d8`) |
| 2.0 | `companion-module-template-{js,ts}-v2.0.4` | 2026-08-28, base 2.0.4 / `node22` (js `e4caa76`, ts `d62230e`) |
| 2.1+ | `companion-module-template-{js,ts}` | `main` (base 2.1 / `node26`), checked for freshness |

The pins live in `Get-TemplatePins` / `Get-TemplateSuffix` (`scripts/lib/ReviewState.ps1`). If the pinned folder for the module's level is missing, the validator exits `2` naming it; it never falls back to `main`, because the wrong template produces false findings. Run the workspace `setup.ps1` to create it.

**Every `Critical` finding blocks approval.** Each finding already states the file, expected value, and what was found — drop those straight into the review's side-by-side report.

Exit codes: `0` clean · `1` Critical findings · `2` unusable `-ModuleDir` / no template · `3` the template clone is stale or unverifiable (see §1.5).

## 1.5 Template freshness — checked first, and it is an *environment* finding

Before anything is compared, the validator verifies the local template clone against its
upstream with a read-only `git ls-remote` (no fetch, no pull, nothing written). This matters
because a clone that is behind upstream produces **false findings against a correct module** —
that has actually happened here: a pre-2026-06-24 clone flagged a module's correct
`enableScripts: false` as an *extra* `.yarnrc.yml` key, and the review told the maintainer to
delete their supply-chain hardening.

| Finding | Meaning |
| --------- | --------- |
| `TEMPLATE-STALE` (Critical) | Local HEAD ≠ `origin/main`. **Any** commit behind counts. |
| `TEMPLATE-UNVERIFIED` (Critical) | The upstream couldn't be reached, or an auto-resolved template isn't a git clone. |

**These two are never carried into the review markdown.** They describe *your* workspace, not
the maintainer's module — the maintainer cannot act on them. When either appears, the review
**aborts**: refresh and start over, so no report is produced from untrustworthy expectations.

```powershell
pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/update-templates.ps1     # the ONLY thing that ever moves a template
```

Templates are never refreshed automatically, and `setup.ps1` does not pull either. Several
review sessions share these clones, so an automatic pull would change the reference underneath
a review already in progress. Refresh **between** sessions, not during one.

The pinned clones (`-v1`, `-v2.0.4`) sit in detached HEAD by design and are exempt — but
their `main` parent, which supplies the `.yarnrc.yml` expectations for pinned modules, is
still checked. For a deliberate offline run, pass `-SkipTemplateFreshness` (or set
`COMPANION_SKIP_TEMPLATE_FRESHNESS=1`) and record `Template freshness: skipped` in the review's
meta table.

## 2. What the script checks (Critical = blocking, unless the row says otherwise)

| Area | Finding ids |
| ------ | ------------- |
| **(Checked first)** Template clone is not behind upstream — see §1.5 | `TEMPLATE-STALE`, `TEMPLATE-UNVERIFIED` |
| Required files present; no `package-lock.json` | `FILE-MISSING`, `NPM-LOCK` |
| Config-file parity vs template — exact match for `.gitattributes` (comment lines and extra `<pattern> binary` rules ignored), `.prettierignore` (extra entries are listed in the message; see below), TS `eslint.config.mjs` (extending the template's config is accepted, see below), and `.husky/*`. `.gitignore` is a **subset** check: every template entry must be present, but **extra** module entries are allowed and not flagged. `.yarnrc.yml` is a **key-level** check (see below) | `CONFIG-DIFF` |
| **(High when the file exists and differs · Medium when it is missing)** `.github/workflows/**` and other `.github/**` parity (e.g. `.github/ISSUE_TEMPLATE/**`). A file the module has must match the template, so a content difference is a High `CONFIG-DIFF`; a missing file is a Medium `FILE-MISSING`. Indentation-only and comment-only differences are not reported, and neither is enabling anything the template ships commented out (the `node.yaml` `test:` job, `upload-artifact: true` in `companion-module-checks.yaml`; see below) | `CONFIG-DIFF`, `FILE-MISSING` |
| **(Info — 📝 Additional Notes, never blocking)** TS `tsconfig.json` / `tsconfig.build.json` differ from the template. Maintainers may tune their tsconfig as long as the module builds — a broken build is reported by `BUILD-*`/`LINT`, not here. A **missing** tsconfig is still a Critical `FILE-MISSING` | `TSCONFIG-DIFF` |
| **(Info — for you, not the maintainer)** The template tracks a file the validator has no rule for. It is still compared, as exact text; add a row to `$templateFileRules` in this plugin's `scripts/validate-template.ps1` and a line to this table | `TEMPLATE-COVERAGE` |
| Gitignored artifacts not committed (`node_modules`, `/pkg`, `*.tgz`, `/dist`, `/.yarn`, …) | `GITIGNORED-COMMITTED` |
| **(High)** `LICENSE` carries the template's licence text; the copyright line is the module author's and is not compared (see below) | `LICENSE-DIFF` |
| All source under `src/` (none at module root). Tool config files named `<tool>.config.(js\|ts)` (`vitest.config.ts`, `vite.config.js`, `jest.config.ts`, …) belong at the root and are exempt | `SRC-AT-ROOT` |
| `package.json`: version-vs-tag, `main` (references an existing entry file; filename may differ from the template), `repository.url`, required fields, `packageManager` (yarn@4), required scripts, devDependencies, lint-staged | `PKG-VERSION`, `PKG-MAIN`, `PKG-REPO`, `PKG-FIELD`, `PKG-YARN`, `PKG-SCRIPT`, `PKG-DEVDEP`, `PKG-LINTSTAGED`, `PKG-DEP` |
| `manifest.json`: non-placeholder maintainers (an empty `email` is allowed), banned keywords, `type` (v2 `connection`), `runtime.type/api` (must match the template; see the runtime rule below), `runtime.entrypoint` (exists and resolves to the same file as `main`) | `MAN-PLACEHOLDER`, `MAN-MAINT`, `MAN-KEYWORD`, `MAN-TYPE`, `MAN-RUNTIME`, `ENTRY-MISMATCH` |
| `companion/HELP.md` not a stub | `HELP-STUB` |
| TS husky `pre-commit` runs `lint-staged` | `HUSKY` |
| Build / lint (with `-RunBuild`) | `BUILD-INSTALL`, `BUILD-PACKAGE`, `LINT` |

**Runtime must match the module's own template.** Each API level allows exactly the runtime its template uses: 2.0 → `node22` (`-v2.0.4`), 2.1+ → `node26` (`main`). A module on API 2.1 is expected to match the 2.1 template, so staying on Node 22 is a finding. The validator resolves the module's installed base version (the same `apiLevel` the fact sheet reports):

| Situation | Result |
| --- | --- |
| base ≥ 2.1, `runtime.type: "node26"` | matches the 2.1 template — no `MAN-RUNTIME` |
| base ≥ 2.1, `runtime.type: "node22"` | `MAN-RUNTIME` (Critical): "should be 'node26' to match the API 2.1 template" — for TS the message also says to extend `@companion-module/tools/tsconfig/node26/recommended.json` in `tsconfig.build.json` |
| base 2.0.x, `runtime.type: "node26"` | `MAN-RUNTIME` (Critical): "node26 requires @companion-module/base ≥ 2.1 (Companion 5.0+)" — the fix is to bump base to `~2.1.x` or go back to `node22` |

A `tsconfig.build.json` that still extends the node22 preset on a 2.1 module is also a `TSCONFIG-DIFF` note. Report it inside the `MAN-RUNTIME` finding's fix, not as a separate note.

**Accepted deviation: comments and the template's commented-out options in `.github` workflows.** Comments are not part of the CI a workflow runs, so the validator compares only the lines that run: adding, removing or rewording prose comments is not a finding. A comment that is really commented-out code is different: commenting out one of the template's lines, or parking new code in a comment (`# - run: yarn build`), is still a High `CONFIG-DIFF` (`Comments out code that is not in the template: …`). Anything the template ships commented out may also be enabled. That covers the `node.yaml` `test:` job under `# Uncomment this to enable running unit tests`, and `upload-artifact: true` in `companion-module-checks.yaml`, which the template tells the maintainer to uncomment so the built package is uploaded as a workflow artifact:

```yaml
    uses: bitfocus/actions/.github/workflows/module-checks.yaml@main
    with:
      upload-artifact: true
```

A module that only removes comments or enables these options is clean, with no finding and no note. An enabled block must match the template's commented-out lines: any other `with:` input, a test job that differs from the template's, or any other change to a line that runs is still a High `CONFIG-DIFF`.

**Accepted deviation: `tsconfig.json` widened to type-check tests.** `tsconfig.json` is the editor/typecheck config; the build uses `tsconfig.build.json`. A module that ships tests may widen `tsconfig.json` with:

- extra `include` / `exclude` entries (`tests/**/*.ts`, `scripts/**/*.ts`, `vitest.config.ts`, …)
- extra `compilerOptions.types` entries (`vitest/globals`, `jest`, …)
- `compilerOptions.rootDir` and `compilerOptions.noEmit`

Every value the template sets must still be present and unchanged. If that holds, the validator reports an Info `TSCONFIG-DEV-SCOPE` listing what was widened, and nothing reaches the review. Anything else in `tsconfig.json` (a different `extends`, another compiler option, a removed template `include`) is a `TSCONFIG-DIFF` note. `TSCONFIG-DEV-SCOPE` does not go into the review markdown.

**Accepted deviation: `eslint.config.mjs` that extends the template's config.** The template's config is a single `export default generateEslintConfig({…})`. A module may build on it: assign the result (`const baseConfig = await generateEslintConfig({…})`) and export `[...baseConfig, …]`, add its own imports (`typescript-eslint`, a plugin such as `eslint-plugin-simple-import-sort`), pass extra options (`ignores`, …), and add config blocks before or after the base config (test overrides, `tseslint.configs.disableTypeChecked` for `vitest.config.ts`, `parserOptions.project`, plugin rules, `src/` overrides). Reviewers accept all of these: the module's own lint setup is its choice.

The validator reports Info `ESLINT-TEST-SCOPE` when the only additions are test-scoped overrides (`files` limited to `tests/**`, `__tests__/**`, `__mocks__/**`, `scripts/**`, `*.test.*`, `*.spec.*` or a root `*.config.*` file), and Info `ESLINT-EXTENDS`, naming the extra imports, options and blocks, for any other extension. Neither goes into the review.

Still a Critical `CONFIG-DIFF`, with the reason in the message:

- a template import is missing;
- the config no longer calls `generateEslintConfig`;
- one of the template's own options is missing or changed (e.g. `enableTypescript: false`);
- the generated config is built but not part of what is exported.

**Accepted deviation: comment lines and binary rules in `.gitattributes`.** Comment and blank lines are dropped from both files before comparing, so a module that explains the template's `* text=auto eol=lf` rule in a comment is clean. Extra rules that only mark file types as binary (`*.png binary`, `*.companionconfig binary`) are accepted too: they make git detect those files correctly. Any other rule, or a changed or missing template rule, is still a Critical `CONFIG-DIFF`.

**`.prettierignore` entries for generated files are fine; the reviewer decides.** When the module keeps every template entry and only adds some, the validator's `CONFIG-DIFF` message starts with `Extra entries not in template:` and lists them. Drop the finding when every extra entry is a generated file (for example a generated `src/scriptSource.ts`, build output such as `dist/` or `pkg/`). Keep it when an extra entry hides hand-written source from Prettier. A changed or missing template entry (`/LICENSE` instead of `/LICENSE.md`) is a plain `CONFIG-DIFF` and stays.

Expectations are derived from the matched template, so v1 modules are checked against the
v1 template and are not flagged for v2-only differences (e.g. v1 manifests correctly have
no `type` field).

**Which files get compared is derived too**, from the template's own tracked files
(`git ls-files`) rather than a list maintained inside the validator. A config file Bitfocus
adds upstream is therefore compared on the next review automatically. Excluded as
module-owned: `src/**`, `README.md`, `yarn.lock`. Excluded because a dedicated rule already
owns them: `LICENSE`, `package.json`, `companion/manifest.json`, `companion/HELP.md`. Binary
files are skipped. Everything else is compared — and a path matching no rule is *still*
compared, plus a `TEMPLATE-COVERAGE` note, so a new template file can never slip through
unjudged.

This is also why the JS/TS split needs no special-casing: `.husky/pre-commit`,
`eslint.config.mjs`, and `tsconfig*.json` are demanded of TS modules only because only the TS
template tracks them. One consequence: `yarn.lock` is required of every module even though the
v2 templates deliberately don't commit one — that requirement is hardcoded, not derived.

**`LICENSE` must carry the template's MIT licence text; the copyright line is the module author's.** With an MIT licence you never replace the copyright holder: the line names the module's author and the year the module was created, so it is never compared and never a finding. The licence text is compared word by word, so line wrapping is not a difference, and the `The MIT License` spelling of the title is accepted. A different licence, or changed licence text, is a `LICENSE-DIFF` at **High**, not Critical. A module that legitimately needs different terms should raise it with Bitfocus.

**`.yarnrc.yml` is the one exception to that rule.** It is repo tooling rather than API
surface, and Bitfocus only updates it on `main` — so it is always compared against the
`main` (unsuffixed) template, for every API level. It is also compared **by parsed key**, not
raw text: key order, quote style (`'@companion-module/*'` vs `"…"`), blank lines, and
comments are **not** divergences and are never flagged. What *is* Critical:

- **Missing template keys** — the template hardened this file on 2026-06-24, adding
  `enableScripts: false`, `npmMinimalAgeGate: 3d`, and `npmPreapprovedPackages`. A module
  still shipping only `nodeLinker: node-modules` is missing that supply-chain hardening.
- **Conflicting value** — e.g. `enableScripts: true`, `npmMinimalAgeGate: 5`.
- **Extra keys** — e.g. `yarnPath`, `enableGlobalCache`, `approvedGitRepositories`; these
  change install behaviour for everyone building the module.

Note `enableScripts: false` combined with a `"postinstall": "husky"` script means git hooks
stop installing after a fresh clone — the current template ships both, so raise that with
Bitfocus rather than the maintainer.

## 3. Judgment items the script can't fully decide

- **HELP.md quality.** The script only catches stubs (placeholder string, `## Your module`, <5 meaningful lines). You still judge whether the content is *useful*: what the module does, how to configure it (host/port/auth), available actions/feedbacks/variables, troubleshooting. Thin-but-real docs are acceptable; empty scaffolding is not.
- **`.github/**` severity is decided by the validator; don't change it.** A `.github` file the module has must match the template: any content difference is a High `CONFIG-DIFF` (blocking). That covers a rewritten `release.yaml` that no longer calls `bitfocus/actions` module-checks, `node.yaml` drift (extra `permissions`, other action versions, a Codecov job), an older `actions/checkout` pin, and a dropped template-repo `if:` guard. A missing `.github` file (no `release.yaml`, `node.yaml` or issue forms) is a Medium `FILE-MISSING`. Indentation-only and comment-only differences are not reported. The fix is to copy the template's file. Enabling what the template ships commented out (the `node.yaml` `test:` job, `upload-artifact: true` in `companion-module-checks.yaml`) is accepted: the validator ignores it, so never report it. Give each High one Evidence line (the differing lines with `file:line`) and a Confirm by line.
- **`tsconfig` differences are never blocking.** A `TSCONFIG-DIFF` goes into the review's **📝 Additional Notes** section as one line per file (what differs, from the validator message) — not into Critical/High/Medium, not into 📋 Issues, and with no demand to change it. If the module builds and lints (`-RunBuild` passed), the maintainer's tsconfig choices are theirs. If the build fails, report the `BUILD-*`/`LINT` finding — that is the blocking item, even when a tsconfig change caused it. Removing the template's commented-out jest hint in `compilerOptions.types` is stripped before comparing and produces no note at all.
- **Entry-point filename.** `package.json main` and `manifest runtime.entrypoint` do **not** have to match the template's `src/main.js` / `../src/main.js`. A non-template name (e.g. `src/index.js`) is fine as long as both fields are present, reference a file that **exists**, and resolve to the **same** file. The validator already checks this: `PKG-MAIN`/`MAN-RUNTIME` fire only when the referenced file is missing, and `ENTRY-MISMATCH` fires only when `main` and `entrypoint` point to different files. Do **not** ask the maintainer to rename their entry to `main.js` when it loads correctly.
- **Manifest `name` vs `id`.** These are **not** required to match, and the validator no longer checks it. `id` is the slug (the repository/module identifier); `name` is the human-facing module name and is *expected* to differ — e.g. `id: fblab-bpm2osc` / `name: BPM2OSC`, `id: lindy-38359-matrix` / `name: Lindy 38359 HDMI Matrix`. Do **not** raise this by hand or tell a maintainer to set `name` to the slug.
- **Manifest version normalization.** `companion/manifest.json` `version` of `"0.0.0"` is acceptable/preferred in source control. If a real version string is committed instead, it must exactly match `package.json`. Treat `package.json` (vs the git tag) and the manifest as **separate** checks.
- **`runtime.apiVersion` placeholder.** `companion/manifest.json` `runtime.apiVersion` of `"0.0.0"` is **not** a defect — like top-level `version`, it is the expected source-control placeholder that the BitFocus **publish pipeline fills in** at submission time. All four official templates (js, ts, js-v1, ts-v1) ship `runtime.apiVersion: "0.0.0"`. This holds for **both v1 and v2** modules. Do **not** flag `"0.0.0"` here or tell the maintainer to set a "real" value (e.g. `"1.0.0"`).
- **Banned keywords.** The script flags only the fixed list (`companion`, `module`, `stream deck`, `streamdeck`, `bitfocus`). A keyword that repeats the module id or part of it (the manufacturer or product name, for example `switch` in `goalake-switch`) is **not** a finding, so don't add one by hand.

## 4. Reporting

Use the script's expected-vs-found for side-by-side guidance the maintainer can act on:

```text
Template expects:  "repository.url": "git+https://github.com/bitfocus/companion-module-{name}.git"
Found:             "repository.url": "git+https://github.com/personal-user/companion-module-name.git"
```

```text
manifest.json maintainers[0].name = "Your name"  ← placeholder, must be replaced
```

`TSCONFIG-DIFF` goes to **📝 Additional Notes** only (never blocking, never in 📋 Issues).

Findings addressed to *you* rather than the maintainer — `TEMPLATE-STALE`,
`TEMPLATE-UNVERIFIED`, `TEMPLATE-COVERAGE`, `TSCONFIG-DEV-SCOPE`, `ESLINT-TEST-SCOPE`, `ESLINT-EXTENDS` — never appear in the review markdown.

If the script cannot run (templates unavailable), fall back to comparing the module directly
against the matching template repo in `companion-module-templates/` (run `setup.ps1` to clone
them, `pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/update-templates.ps1` to refresh an existing clone) — but prefer fixing
the environment so the deterministic path runs every time. Never `git pull` a template by
hand, and never mid-review: other sessions are diffing against the same clone.
