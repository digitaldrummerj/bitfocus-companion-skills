---
name: companion-template-compliance
description: 'Checklist for verifying that a Bitfocus Companion module matches the official JavaScript or TypeScript template, including required files, config file contents, package.json rules, manifest.json rules, HELP.md validation, and husky hooks.'
license: MIT
---

# Skill: companion-template-compliance

**Description:** Full checklist for verifying that a Companion module matches the official JS or TS template. Covers required files, config file content, package.json rules, manifest.json rules, HELP.md validation, and husky hooks.  
**Confidence:** high  
**Last-updated:** 2026-10-04

> **In a companion-module-review workspace**, don't run this checklist by hand: the
> **`companion-module-review:review-template-check`** skill runs `validate-template.ps1`, which
> checks everything below deterministically, and tells you how to interpret each finding id.

## Template Source Directories

When in doubt, compare directly against the authoritative templates — clones of the official repos, wherever you keep them:

| Type | Template repo | Typical local clone |
|------|---------------|---------------------|
| **JavaScript** | `bitfocus/companion-module-template-js` | `companion-module-template-js/` (a companion-module-review workspace keeps it under `companion-module-templates/`) |
| **TypeScript** | `bitfocus/companion-module-template-ts` | `companion-module-template-ts/` (same) |

**Pick the template by API version × language.** A module on `@companion-module/base` 2.x is compared with the current templates above. A module on 1.x is compared with the template **as it stood at its last v1.x commit** (`git checkout` that commit in a separate clone), so it is never flagged for v2-only differences such as the manifest `type` field. The template repo is the authority: when this checklist and the template disagree, the template wins.

Use an **up-to-date** template clone. A clone that is behind upstream produces false findings against a correct module (e.g. flagging the template's current `.yarnrc.yml` hardening as "extra keys").

---

## 1. Detecting JS vs TS

A module is **TypeScript** if either of these is true:
- `tsconfig.json` exists at the module root
- it has `.ts` source files under `src/`

Otherwise treat it as **JavaScript**. Do **not** use `package.json` `"type": "module"` (plain-JS modules can be ESM too) or a `typescript` devDependency (it can be a typescript-eslint peer on a JS module) as the signal.

---

## 2. Required Files Checklist

### JavaScript modules

| File | Required |
|------|----------|
| `.gitattributes` | ✅ |
| `.gitignore` | ✅ |
| `.prettierignore` | ✅ |
| `.yarnrc.yml` | ✅ |
| `LICENSE` | ✅ |
| `package.json` | ✅ |
| `yarn.lock` | ✅ |
| `companion/manifest.json` | ✅ |
| `companion/HELP.md` | ✅ |
| `src/main.js` | ✅ |

### TypeScript modules

All JS files above, **plus**:

| File | Required |
|------|----------|
| `eslint.config.mjs` | ✅ |
| `tsconfig.build.json` | ✅ |
| `tsconfig.json` | ✅ |
| `.husky/pre-commit` | ✅ |
| `src/main.ts` | ✅ |

> **Note:** `package-lock.json` must **NOT** be present in either module type — presence is an automatic rejection.

> **Entry-point filename:** `src/main.js` / `src/main.ts` are the template's names, not a requirement. A module may use e.g. `src/index.ts`, as long as `package.json` `main` and the manifest `runtime.entrypoint` both reference a file that exists and resolve to the **same** file. Don't ask a maintainer to rename a working entry point.

> **The template's tracked files are the list.** Anything else the template tracks (for example `.github/workflows/**` and `.github/ISSUE_TEMPLATE/**`) is compared too. A `.github/**` file the module has must match the template: a different workflow or issue template is 🟠 High (blocking), because a drifted file confuses later troubleshooting. A missing `.github` file is 🟡 Medium. Indentation-only and comment-only differences are not a divergence. **Accepted customisation:** enabling anything the template ships commented out is not a divergence: the `node.yaml` `test:` job under `# Uncomment this to enable running unit tests`, and the `with:` / `upload-artifact: true` lines in `companion-module-checks.yaml` (the template tells you to uncomment them).

---

## 3. Source Code Directory Rule

**All source code files must be in the `src/` directory.** No `.js` or `.ts` source files may exist at the module root or in any directory other than `src/` (and its subdirectories).

> **Exempt: tool config files.** Files named `<tool>.config.(js|ts)` (`vitest.config.ts`, `vite.config.js`, `jest.config.ts`, …) are configuration, not module source. The tools look for them at the repo root, so that is where they belong. Don't flag them.

**Check:**
- For JS modules: `src/main.js` must exist; `main.js` at the root is a Critical violation
- For TS modules: `src/main.ts` must exist; `main.ts` at the root is a Critical violation
- If source files are at the root, the `package.json` `"main"` field will also be wrong (e.g., `"main.js"` instead of `"src/main.js"`) — flag both
- If source files are at the root, `manifest.json` `"entrypoint"` will also be wrong (e.g., `"../main.js"` instead of `"../src/main.js"`) — flag both

**Severity:** 🔴 Critical — blocks approval.

---

## 4. Config File Content Rules
### `.gitattributes`

**JS and TS (identical):**
```
* text=auto eol=lf
```

Comment lines are fine (for example one explaining the rule), and so are extra rules that only mark file types as binary (`*.png binary`). The template's rule itself must be there and match.

### `.gitignore`

**JS template:**
```
node_modules/
package-lock.json
/pkg
/*.tgz
DEBUG-*
/.yarn
```

**TS template** — same as JS plus these two lines:
```
/dist
/.vscode
```

**Subset rule:** every template entry must be present. **Extra** module entries are allowed and are not a finding.

### `.prettierignore`

**JS and TS (identical):**
```
package.json
/LICENSE.md
```

Both template entries must be there unchanged. Extra entries for generated files (a generated source file, build output) are fine; an extra entry that hides hand-written source from Prettier is a divergence.

### `LICENSE`

Must carry the template's MIT licence text. The copyright line is the module author's: with an MIT licence you never replace the holder, and the year is the year the module was created, so a different copyright line is **not** a divergence. Line wrapping, line endings and the `The MIT License` spelling of the title aren't either. A different licence, or changed licence text, is a divergence (🟠 High). A module that genuinely needs different terms should raise it with Bitfocus.

### `.yarnrc.yml`

**JS and TS (identical), current template:**
```yaml
nodeLinker: node-modules
enableScripts: false
npmMinimalAgeGate: 3d
npmPreapprovedPackages:
  - "@companion-module/*"
```

Compare **by key**, not as raw text: key order, quote style and blank lines are not divergences; a missing key, an extra key, or a conflicting value is. `.yarnrc.yml` is repo tooling, not API surface, and Bitfocus only updates it on the current template — so compare **v1 modules against the current template's** `.yarnrc.yml` too, not the pinned v1 copy. Never tell a maintainer to delete `enableScripts: false` or the age gate: that is the template's supply-chain hardening.

### `eslint.config.mjs` (TS only)

```js
import { generateEslintConfig } from '@companion-module/tools/eslint/config.mjs'
export default generateEslintConfig({ enableTypescript: true })
```

### `tsconfig.build.json` (TS only)

**v2 template, API 2.0 (base 2.0.x, node22):** (the API 2.1 template, base 2.1.x, is identical except that it extends `@companion-module/tools/tsconfig/node26/recommended.json`)
```json
{
  "extends": "@companion-module/tools/tsconfig/node22/recommended-esm.json",
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules/**", "src/**/*spec.ts", "src/**/__tests__/*", "src/**/__mocks__/*"],
  "compilerOptions": { "outDir": "./dist", "rootDir": "./src", "verbatimModuleSyntax": true }
}
```

The v1 template extends `node22/recommended` with `"module"`/`"moduleResolution": "Node16"`; compare a v1 module against that one.

> Deviations must be justified in the review. One is accepted without justification:
> - removing the template's commented-out jest hint from `compilerOptions.types` (see below).

### `tsconfig.json` (TS only)

```json
{
  "extends": "./tsconfig.build.json",
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules/**"],
  "compilerOptions": {"types": ["node" /* , "jest" ] // uncomment this if using jest */]}
}
```

`"types": ["node"]` without the commented-out jest hint is an **accepted** divergence, not a finding — ignore inline comments and bracket spacing when comparing tsconfig lines.

**Accepted divergence: `tsconfig.json` widened to type-check tests.** `tsconfig.json` is only the editor/typecheck config; the build uses `tsconfig.build.json`, which must still match exactly. A module that ships tests may add:
- extra `include` / `exclude` entries (`tests/**/*.ts`, `scripts/**/*.ts`, `vitest.config.ts`, …)
- extra `compilerOptions.types` entries (`vitest/globals`, `jest`, …)
- `compilerOptions.rootDir` (e.g. `"./"`, so `tests/` sits inside it) and `compilerOptions.noEmit: true`

Not a finding, as long as every value the template sets is still present and unchanged. A different `extends`, any other added or changed compiler option, or a removed template `include` entry is still a divergence.

**Accepted divergence: `eslint.config.mjs` that extends the template's config.** A module may keep the template's `generateEslintConfig` call and build on it:

```js
import { generateEslintConfig } from '@companion-module/tools/eslint/config.mjs'
import tseslint from 'typescript-eslint'

const baseConfig = await generateEslintConfig({ enableTypescript: true })
export default [
	...baseConfig,
	{ files: ['vitest.config.ts'], ...tseslint.configs.disableTypeChecked },
	{ files: ['tests/**/*.ts'], rules: { 'n/no-unpublished-import': 'off' } },
]
```

Extra imports and plugins, extra `generateEslintConfig` options (such as `ignores`), and extra config blocks before or after the base config (including `src/` overrides) are the module's choice, not a finding.

Still a divergence:
- a template import is removed;
- `generateEslintConfig` is no longer called;
- one of the template's own options is removed or changed (e.g. `enableTypescript: false`);
- the generated config is not part of what is exported.

---

## 5. `package.json` Rules

### 4a. JavaScript modules

**Required fields and expected values:**

| Field | Expected value / pattern |
|-------|--------------------------|
| `name` | module name (no `companion-module-` prefix required, but must be consistent with repo) |
| `version` | must match git tag without the `v` prefix (e.g. tag `v2.1.0` → `"2.1.0"`) |
| `main` | `"src/main.js"` |
| `license` | `"MIT"` |
| `repository.type` | `"git"` |
| `repository.url` | `"git+https://github.com/bitfocus/companion-module-{module-name}.git"` |
| `engines.node` | `"^22.20"` or broader `"^22.x"` pattern |
| `engines.yarn` | `"^4"` |
| `prettier` | `"@companion-module/tools/.prettierrc.json"` |
| `packageManager` | must start with `"yarn@4"` (e.g. `"yarn@4.12.0"`) |

**Required `scripts`:**

| Script | Required |
|--------|----------|
| `format` | ✅ (`prettier -w .`) |
| `package` | ✅ (`companion-module-build`) |

**Required `dependencies`:**

| Package | Notes |
|---------|-------|
| `@companion-module/base` | required; semver flexibility allowed (e.g. `~1.14.1`) |

**Required `devDependencies`:**

| Package | Notes |
|---------|-------|
| `@companion-module/tools` | required |
| `prettier` | required |

---

### 4b. TypeScript modules

All JS rules above, **plus**:

**`main`** must be `"dist/main.js"` (not `src/`)  
**`type`** must be `"module"`

**Required `scripts` (TS adds):**

| Script | Required |
|--------|----------|
| `postinstall` | ✅ (`husky`) |
| `build` | ✅ (`rimraf dist && run build:main`) |
| `build:main` | ✅ (`tsc -p tsconfig.build.json`) |
| `dev` | ✅ (`tsc -p tsconfig.build.json --watch`) |
| `lint:raw` | ✅ (`eslint`) |
| `lint` | ✅ (`run lint:raw .`) |
| `package` | ✅ (`run build && companion-module-build`) |
| `format` | ✅ (`prettier -w .`) |

**Required `devDependencies` (TS adds):**

| Package | Notes |
|---------|-------|
| `@types/node` | required |
| `eslint` | required |
| `husky` | required |
| `lint-staged` | required |
| `rimraf` | required |
| `typescript` | required |
| `typescript-eslint` | required |

**Required extra sections:**

| Section | Expected value |
|---------|----------------|
| `lint-staged` | must be present with at least `*.{ts,tsx,js,jsx}` and `*.{css,json,md,scss}` entries |

---

## 6. `manifest.json` Rules (JS and TS)

| Field | Rule |
|-------|------|
| `id` | must equal the module name **without** the `companion-module-` prefix |
| `name` | the human-facing module name — **expected to differ** from `id` (e.g. `id: fblab-bpm2osc` / `name: BPM2OSC`). Don't flag it |
| `maintainers[].name` | must NOT be `"Your name"` or any obvious placeholder |
| `maintainers[].email` | must NOT be `"Your email"`. An empty email is allowed: a contact is nice to have but not required |
| `maintainers` | must NOT be empty array `[]` |
| `repository` | must be `"git+https://github.com/bitfocus/companion-module-{module-name}.git"` |
| `type` | `"connection"` on base 2.x (required since 2.0.4); absent on v1 manifests — don't flag a v1 module for it |
| `runtime.type` | Must match the template for the module's API level: `"node22"` on base 2.0.x, `"node26"` on base **≥ 2.1** (Companion 5.0+). `node26` on a 2.0.x module is 🔴 (it needs base ≥ 2.1); `node22` on a 2.1 module is 🔴 (it doesn't match the 2.1 template) |
| `runtime.api` | `"nodejs-ipc"` |
| `runtime.entrypoint` | Must reference a file that exists (build outputs under `dist/` are produced by the build) and resolve to the same file as `package.json` `main`. It does not have to be the template's filename |
| `keywords` | see below |
| `$schema` | should reference `../node_modules/@companion-module/base/assets/manifest.schema.json` |

### Banned `keywords`

The `keywords` array must NOT contain any of:
- `"companion"`
- `"module"`
- `"stream deck"` / `"streamdeck"`
- `"bitfocus"`

Flag only these. A keyword that repeats the module's manufacturer or product name (for example `"switch"` in `goalake-switch`, or `"easyworship"`) is not a finding.

---

## 7. `companion/HELP.md` Rules (JS and TS)

The file must contain real user-facing documentation. Flag it if:

- It contains the exact string `"Write some help for your users here"` → stub, not acceptable
- The only heading is `## Your module` with no additional content → stub, not acceptable
- The file is fewer than 5 meaningful lines → likely placeholder

A good HELP.md covers: what the module does, how to configure it (host/port/auth), what actions/feedbacks/variables are available, and any troubleshooting tips.

---

## 8. TS-only: `.husky` Directory

- The `.husky/` directory must be committed to the repo (must NOT appear in `.gitignore`)
- Must contain a `pre-commit` file
- The `pre-commit` file must contain (at minimum):
  ```
  lint-staged
  ```
- The hook runs `lint-staged` before every commit, ensuring code is linted and formatted

---

## 9. Severity Table

> **⚠️ Template compliance violations are CRITICAL — they block approval — unless the row says otherwise.**

| Violation | Severity |
|-----------|----------|
| Missing required file | **🔴 Critical** (blocks) |
| `package-lock.json` present | **🔴 Critical** (blocks) |
| Source code files not in `src/` directory | **🔴 Critical** (blocks) |
| `version` in `package.json` doesn't match git tag | **🔴 Critical** (blocks) |
| Wrong `repository` URL (package.json or manifest.json) | **🔴 Critical** (blocks) |
| Placeholder maintainer `name` or `email` in manifest | **🔴 Critical** (blocks) |
| Empty `maintainers` array | **🔴 Critical** (blocks) |
| Stub `companion/HELP.md` | **🔴 Critical** (blocks) |
| Banned keyword in `manifest.json` keywords | **🔴 Critical** (blocks) |
| Missing `engines`, `prettier`, or `packageManager` fields | **🔴 Critical** (blocks) |
| Missing required `scripts` (TS) | **🔴 Critical** (blocks) |
| Missing required `devDependencies` | **🔴 Critical** (blocks) |
| `.husky` missing or not committed (TS) | **🔴 Critical** (blocks) |
| `manifest.json` `id` doesn't match the module name | **🔴 Critical** (blocks) |
| Config file content differs from template | **🔴 Critical** (blocks) |
| Missing template `.gitignore` entries (extra module entries are fine) | **🔴 Critical** (blocks) |
| `tsconfig` deviations without justification | **🔴 Critical** (blocks) |
| `package.json` `main` / manifest `runtime.entrypoint` missing or resolving to different files | **🔴 Critical** (blocks) |
| `LICENSE` licence text differs from the template (the copyright line is the author's and is not compared) | **🟠 High** |
| `.github/**` workflow / issue template present but different (except indentation-only or comment-only changes, and enabling what the template ships commented out: the `node.yaml` test job, `upload-artifact: true`) | **🟠 High** |
| `.github/**` workflow / issue template missing | **🟡 Medium** |

---

## 10. How to Report Findings

Show side-by-side comparisons so the maintainer can see exactly what to change:

```
Template expects:  "repository.url": "git+https://github.com/bitfocus/companion-module-{name}.git"
Found:             "repository.url": "git+https://github.com/personal-user/companion-module-name.git"
```

```
Template expects:  engines.node = "^22.20"
Found:             engines.node field missing entirely
```

```
Template expects:  keywords = [] (or non-banned terms only)
Found:             keywords = ["companion", "module", "easyworship"]
  → Banned: "companion", "module" ("easyworship" is fine)
```

For missing files:
```
Required file missing: .husky/pre-commit
  → TS modules must commit the husky pre-commit hook
```

For maintainer placeholders:
```
manifest.json maintainers[0].name = "Your name"  ← placeholder, must be replaced
manifest.json maintainers[0].email = "Your email"  ← placeholder, must be replaced
```
