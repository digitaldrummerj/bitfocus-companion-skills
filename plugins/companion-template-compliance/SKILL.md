---
name: companion-template-compliance
description: 'Checklist for verifying that a Bitfocus Companion module matches the official JavaScript or TypeScript template, including required files, config file contents, package.json rules, manifest.json rules, HELP.md validation, and husky hooks.'
license: MIT
---

# Skill: companion-template-compliance

**Description:** Full checklist for verifying that a Companion module matches the official JS or TS template. Covers required files, config file content, package.json rules, manifest.json rules, HELP.md validation, and husky hooks.  
**Confidence:** high  
**Last-updated:** 2026-10-04

## Template Source Directories

When in doubt, compare directly against the authoritative templates in the workspace:

| Type | Directory |
|------|-----------|
| **JavaScript** | `companion-module-template-js/` (workspace root) |
| **TypeScript** | `companion-module-template-ts/` (workspace root) |

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

> **The template's tracked files are the list.** Anything else the template tracks (for example `.github/workflows/**` and `.github/ISSUE_TEMPLATE/**`) is compared too. `.github/**` divergences are usually GitHub Action pin churn (`actions/checkout@v4` vs the template's newer pin) — report them at 🟡 Medium, non-blocking, and don't tell a maintainer to overwrite a workflow they deliberately extended.

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

### `LICENSE`

Must match the template **exactly**, including `Copyright (c) 2022 Bitfocus AS - Open Source`. The template's LICENSE is the licence Bitfocus ships for every module, not a scaffold to personalise — a maintainer's own name or year is a divergence (🟠 High). Line endings and trailing whitespace are not. A module that genuinely needs different terms should raise it with Bitfocus.

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

**v2 template (base 2.x):**
```json
{
  "extends": "@companion-module/tools/tsconfig/node22/recommended-esm.json",
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules/**", "src/**/*spec.ts", "src/**/__tests__/*", "src/**/__mocks__/*"],
  "compilerOptions": { "outDir": "./dist", "rootDir": "./src", "verbatimModuleSyntax": true }
}
```

The v1 template extends `node22/recommended` with `"module"`/`"moduleResolution": "Node16"`; compare a v1 module against that one.

> Deviations must be justified in the review. Two are accepted without justification:
> - a module on base **≥ 2.1** with `runtime.type: "node26"` may extend `@companion-module/tools/tsconfig/node26/recommended(.json)` instead of the node22 preset;
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
| `maintainers[].email` | must NOT be `"Your email"` or any obvious placeholder |
| `maintainers` | must NOT be empty array `[]` |
| `repository` | must be `"git+https://github.com/bitfocus/companion-module-{module-name}.git"` |
| `type` | `"connection"` on base 2.x (required since 2.0.4); absent on v1 manifests — don't flag a v1 module for it |
| `runtime.type` | `"node22"`. `"node26"` is also valid when base resolves to **≥ 2.1** (Companion 5.0+); on a 2.0.x module it is 🔴 |
| `runtime.api` | `"nodejs-ipc"` |
| `runtime.entrypoint` | Must reference a file that exists (build outputs under `dist/` are produced by the build) and resolve to the same file as `package.json` `main`. It does not have to be the template's filename |
| `keywords` | see below |
| `$schema` | should reference `../node_modules/@companion-module/base/assets/manifest.schema.json` |

### Banned `keywords`

The `keywords` array must NOT contain any of:
- `"companion"`
- `"module"`
- `"stream deck"`
- The manufacturer name (e.g. `"bitfocus"`, `"softouch"`)
- The module/product name (e.g. `"easyworship"`, `"tallyccupro"`)
- The full product name (e.g. `"EasyWorship"`, `"Generic SNMP"`)

Flag any keyword that matches these patterns — it adds no value and pollutes search.

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
| `LICENSE` differs from the template (including the `Copyright (c) 2022 Bitfocus AS - Open Source` line) | **🟠 High** |
| `.github/**` workflow / issue-template divergence | **🟡 Medium** (non-blocking) |

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
  → Banned: "companion", "module", "easyworship" (product name)
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
