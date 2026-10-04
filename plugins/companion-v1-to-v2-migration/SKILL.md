---
name: companion-v1-to-v2-migration
description: 'Step-by-step procedure for upgrading a Bitfocus Companion module from @companion-module/base v1.x to the v2 API (2.0 or 2.1). Use when asked to migrate, upgrade, or port a module to API v2, base 2.x, Companion 4.3+/5.0+, or to remove runEntrypoint. Orchestrates the assessment, tooling/ESM, manifest, entrypoint, and test phases and hands off to companion-v1-to-v2-migrate-definitions, companion-v1-to-v2-migrate-presets, and companion-v1-to-v2-expression-upgrades. Does NOT apply to building a new v2 module from scratch — use companion-v2-module-scaffold instead.'
license: MIT
---

# Companion v1 → v2 Module Migration

This skill is the **orchestrator** for converting an existing `@companion-module/base` 1.x module to the v2 API. Work through the phases **in order**. Each phase ends with a build check and a **commit boundary**, so the history reads as small, reviewable steps.

The finished module matches the v2 split-file layout taught by the `companion-v2-*` skills:

```
src/
  main.ts                 ModuleSchema + `export default class ModuleInstance extends InstanceBase<ModuleSchema>` + `export { UpgradeScripts }`
  config.ts               `export type ModuleConfig = {...}` + GetConfigFields()
  actions.ts              `export type ActionsSchema = ActionsSchemaA & ActionsSchemaB`; UpdateActions(instance)
  actions/action-{category}.ts
  feedbacks.ts            `export type FeedbacksSchema = ...` (+ `AnyFeedbackId`); UpdateFeedbacks(instance)
  feedbacks/feedback-{category}.ts
  presets.ts              merges { section, presets } from each category → setPresetDefinitions(structure, presets)
  presets/preset-{category}.ts
  variables.ts (or variables/*)   VariablesSchema + object-form setVariableDefinitions
  upgrades.ts (or upgrades/*)     `export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig>[]`
```

## When to Use This Skill

### ✅ Use this skill when:

- A module's `package.json` has `@companion-module/base` `^1.x` / `~1.x` and you are asked to move it to v2
- The module calls `runEntrypoint(...)` and needs a default export instead
- You are asked to make a module "expression ready", or to support Companion 4.3+ / 5.0+ features

### ❌ Do NOT use this skill when:

- You are creating a brand-new module → **companion-v2-module-scaffold**
- The module is already on base 2.x and you only need to add an action, feedback or preset → the `companion-v2-*` skills
- You are only **reviewing** a module → **companion-v1-api-compliance** or **companion-v2-api-compliance**

**The rule:** v1 and v2 APIs never mix inside one module. Once you change the base version, the whole module must follow the v2 API before it builds again. The build is expected to be red from Phase 1 until Phase 6. Each phase from Phase 3 on should bring it closer to green.

### Commits while the build is red

Modules generated from the template run husky + lint-staged (`eslint --fix`) on commit. While the build is red (Phases 1–5) those hooks usually fail, because v1-style code also breaks v2-aware lint rules.

- **Check the hook at baseline** (Phase 0) with the commands in **`references/esm-and-tooling.md`** → "Git hooks". It may be missing, broken for unrelated reasons, or have globs that match nothing, and each case is handled differently.
- **Try a normal commit first.** Use `git commit --no-verify` only when the hook **actually fails** on a red-build phase. Say so in the commit body, e.g. "Build is still red here (v1 definitions); committed with --no-verify". From Phase 6 on, when the build is green, don't skip the hook again unless it was already broken at baseline.
- **Alternative:** if the repo's policy forbids skipping hooks, do Phases 2–6 in the working tree and commit them as one green commit.

---

## Phase 0 — Assess and Choose a Target

### 0.1 Record the starting point

```bash
git status                                   # must be clean
git checkout -b feat/companion-api-v2        # never migrate on main
node -p "const p=require('./package.json');({type:p.type,base:p.dependencies['@companion-module/base'],tools:p.devDependencies['@companion-module/tools'],ts:p.devDependencies.typescript})"
grep -n '"type"\|"runtime"' -A4 companion/manifest.json
yarn install && yarn build && yarn test      # baseline: write down what ALREADY fails
```

Any test that already fails before the migration is not a migration regression. Record it, and don't "fix" it to make the migration look green.

### 0.2 Choose the target API

| Target | Base version | Companion | Pick it when |
|---|---|---|---|
| **2.1** (recommended) | `~2.1.3` | 5.0+ | The default. Adds `context.signal`, action results (`hasResult`), `affectedProperties`, layered/alternatives presets, `internal:*` preset actions and `node26`. |
| **2.0** | `~2.0.4` | 4.3+ | Users must stay on Companion 4.3/4.4. Skip every step marked **2.1+**. |

Two things are required in 2.1 at the TypeScript level only: advanced feedbacks must declare `affectedProperties`, and actions with `subscribe` must declare `optionsToMonitorForSubscribe`. Both are covered in **companion-v1-to-v2-migrate-definitions**.

### 0.3 Inventory every v1 API in use

Run the grep inventory in **`references/inventory.md`** and save the output. Each matching line is a work item. It also checks for a lint-staged pre-commit hook and for hard-coded version strings.

### 0.4 No tests? Write characterization tests first

If the module has no test suite, add a small vitest suite against the **v1** code and commit it once it passes, **before** Phase 1. It is the migration's safety net: every later test edit is then a deliberate v2 shape change. The pattern, including how to load a v1 class that calls `runEntrypoint` at import time, is in **`references/characterization-tests.md`**.

If the module has **jest** tests, convert them to vitest as a separate commit now and confirm identical pass/fail counts (**`references/jest-to-vitest.md`**).

---

## Phase 1 — Tooling and ESM

### 1.1 `package.json`

| Field | v1 typical | v2 value |
|---|---|---|
| `"type"` | missing (CommonJS) | `"module"` for TypeScript modules. Plain-JS modules may stay CommonJS: base v2 also exports a `require` entry, so `module.exports = class …` with `module.exports.UpgradeScripts = […]` still works. |
| `dependencies["@companion-module/base"]` | `~1.14.1` | `~2.1.3` (or `~2.0.4` for the 2.0 target) |
| `devDependencies["@companion-module/tools"]` | `^2.x` | `^3.1.0` (minimum 2.7.1; v3 is a drop-in replacement) |
| `devDependencies["typescript"]` | `~5.x` | `~6.0.3` |
| `devDependencies["eslint"]` | `^9.x` | `^10.2.0`. Tools 3.1 depends on `@eslint/js` 10, which peers on eslint ^10.2. With eslint 9, yarn prints `YN0060`. |
| `devDependencies["prettier"]` | `^3.x` | `^3.8.1` (tools 3.1 peer) |
| `devDependencies["typescript-eslint"]` | `^8.x` | `^8.56.1` (tools 3.1 peer; older versions don't support TS 6) |
| `devDependencies["@types/node"]` | `^22.x` | `^22.19.17` (match `engines.node`) |
| `engines.node` | `^22.x` | `^22.20` |
| `packageManager` | `yarn@4.x` | keep yarn 4 (the template uses `yarn@4.17.0`) |
| `main` | `dist/index.js` or `dist/main.js` | keep it, but it **must match** `runtime.entrypoint` in the manifest |

If in doubt, match `node_modules/@companion-module/tools/package.json` → `peerDependencies`. These versions are **minimums**: keep newer versions the repo already pins. Bump base and tools in **one** `yarn add`, then run `yarn install` and confirm there are no `YN0060` peer warnings.

Already ESM (`"type": "module"`)? Then Phase 1 is mostly the tsconfig swap plus `import type` fixes (expect TS1484 for each type-only import).

### 1.2 TypeScript config

`tsconfig.build.json`:

```json
{
	"extends": "@companion-module/tools/tsconfig/node22/recommended-esm.json",
	"include": ["src/**/*.ts"],
	"exclude": ["node_modules/**", "src/**/*spec.ts", "src/**/__tests__/*", "src/**/__mocks__/*"],
	"compilerOptions": {
		"outDir": "./dist",
		"rootDir": "./src",
		"verbatimModuleSyntax": true
	}
}
```

`tsconfig.json`, used for tests and the IDE. It extends the build config and **must override `rootDir` and set `noEmit`**. If the repo has the inheritance the other way round (`tsconfig.build.json` extends `tsconfig.json`), invert it first; see **`references/esm-and-tooling.md`**.

```json
{
	"extends": "./tsconfig.build.json",
	"include": ["src/**/*.ts", "tests/**/*.ts"],
	"exclude": ["node_modules/**"],
	"compilerOptions": {
		"rootDir": "./",
		"noEmit": true,
		"types": ["node"]
	}
}
```

- Without `rootDir: "./"`, `tsc -p tsconfig.json` fails with TS6059 ("not under rootDir"). Without `noEmit`, a stray `tsc -p tsconfig.json` writes `.js` files next to your tests, and lint then fails on them. Add your test framework's types (`"vitest/globals"`, `"jest"`) and extra include globs (`vitest.config.ts`, `scripts/**`) as needed.
- Remove `"module": "Node16"`, `"moduleResolution": "Node16"`, `baseUrl` and `paths` overrides carried over from v1. `node22/recommended-esm` already sets an ESM-capable `"module": "node20"` / `"moduleResolution": "node16"`, and `"type": "module"` makes the output ESM.
- **2.1+ (Companion 5.0+)** with a `node26` runtime: extend `@companion-module/tools/tsconfig/node26/recommended.json` instead. It has no `-esm` variant and doesn't need one, because it also uses `node20`/`node16` (with `es2025`). Also bump `engines.node` and `@types/node` to Node 26.

### 1.3 Fix ESM import syntax across `src/` (and `tests/`)

`verbatimModuleSyntax` turns three things into errors:

| Problem | Fix |
|---|---|
| Type-only names imported as values: `import { CompanionActionDefinition } from '@companion-module/base'` | `import type { ... }`, or inline `import { InstanceBase, type SomeCompanionConfigField }` |
| Relative imports without an extension: `from './utils'` | `from './utils.js'` (always `.js`, even for `.ts` sources) |
| `require('x')` / `module.exports` | ESM `import`. For a CJS-only package with no usable ESM entry, use `createRequire` (below). |

```ts
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
// a CJS-only package that has no ESM entry point (placeholder name)
const legacyLib = require('some-cjs-only-lib') as { connect(host: string): void }
```

Many CJS packages work as a default import under ESM, e.g. `import osc from 'osc'`. But some need a **named** import (`import { got } from 'got-cjs'`). Untyped packages need an ambient `.d.ts`, and test mocks must then provide `default`. `tsc` and vitest often miss these mistakes, so **check every CJS dependency in Node** with the one-liners in **`references/esm-and-tooling.md`** → "CommonJS packages under ESM". Use `createRequire` only when no import form works.

`"type": "module"` also turns every plain-JS **helper script** (`scripts/*.js` run by husky or `package.json` scripts) into ESM. Rename CommonJS ones to `.cjs` and update their callers.

`__dirname` and `__filename` don't exist in ESM. Use `import.meta.dirname` (Node 22) or `fileURLToPath(new URL('.', import.meta.url))`.

### 1.4 Lint config

`eslint.config.mjs` stays `generateEslintConfig({ enableTypescript: true })`. Keep any custom rule overrides the module already had. If the module has (or gains) vitest tests, add the **test-file override** (`n/no-unpublished-import`, `@typescript-eslint/unbound-method` off for `tests/**` and `vitest.config.ts`) from **`references/esm-and-tooling.md`**. Remove `enableJest: true` when leaving jest.

The tools v3 bump (eslint 10, newer typescript-eslint) also flags some untouched code. The rule-by-rule fixes are in **`references/esm-and-tooling.md`** → "New lint findings after the tools v3 bump".

### 1.5 Test runner

| Runner | What to change |
|---|---|
| **vitest** | Usually nothing. It's ESM-native, so keep `vitest.config.*`. |
| **jest + ts-jest** | Either switch to vitest (simplest; checklist in **`references/jest-to-vitest.md`**, ideally done in Phase 0.4), or use `ts-jest`'s ESM preset: `preset: 'ts-jest/presets/default-esm'`, `extensionsToTreatAsEsm: ['.ts']`, `moduleNameMapper: { '^(\\.{1,2}/.*)\\.js$': '$1' }`, and run jest with `NODE_OPTIONS=--experimental-vm-modules`. `jest.config.ts` needs `ts-node` with ESM support, or rename it to `jest.config.cjs`/`.mjs`. |

**Commit boundary:** `chore: switch tooling to companion API v2 (ESM, tools v3, base 2.1)`. The build is red here, which is expected (see "Commits while the build is red").

---

## Phase 2 — Manifest, Entry Point and Config Type

### 2.1 `companion/manifest.json`

```json
{
	"$schema": "../node_modules/@companion-module/base/assets/manifest.schema.json",
	"type": "connection",
	"id": "your-module-id",
	"runtime": {
		"type": "node22",
		"api": "nodejs-ipc",
		"apiVersion": "0.0.0",
		"entrypoint": "../dist/main.js"
	}
}
```

- Add `$schema` (recommended) and `"type": "connection"` (**required**: v2 refuses to load without it).
- `runtime.type`: `node18` is no longer allowed. Use `node22`, or `node26` (**2.1+ (Companion 5.0+)**).
- Keep every other field as it is: `id`, `name`, `shortname`, `maintainers`, `legacyIds`, `products`, `keywords`, `bonjourQueries`, `runtime.permissions`, and so on. Never change `id`.
- `runtime.entrypoint` must point at the compiled file that holds the default export.

### 2.2 Entry point: `runEntrypoint` → default export

**Before (v1):**

```ts
import { InstanceBase, runEntrypoint } from '@companion-module/base'
import { ZoomConfig } from './config.js'
import { UpgradeV2ToV3 } from './upgrades/v2CommandsToUpgradeTov3.js'
import { fixWrongPinCommands } from './upgrades/fixWrongPinCommands.js'

class ZoomInstance extends InstanceBase<ZoomConfig> {
	// ...
}

runEntrypoint(ZoomInstance, [UpgradeV2ToV3, UpgradeV2ToV3, fixWrongPinCommands])
```

**After (v2):** the essential changes are below. The complete `main.ts` is in **companion-v2-module-scaffold → Step 5**.

```ts
import { InstanceBase } from '@companion-module/base'
import type { ZoomConfig } from './config.js'
import type { ActionsSchema } from './actions.js'
import type { FeedbacksSchema } from './feedbacks.js'
import type { VariablesSchema } from './variables.js'
import { UpgradeScripts } from './upgrades.js'

export type ModuleSchema = {
	config: ZoomConfig
	secrets: undefined
	actions: ActionsSchema
	feedbacks: FeedbacksSchema
	variables: VariablesSchema
}

export { UpgradeScripts }

export default class ZoomInstance extends InstanceBase<ModuleSchema> {
	// existing fields, lifecycle methods and an updateDefinitions() that calls
	// UpdateVariableDefinitions / UpdateActions / UpdateFeedbacks / UpdatePresets
}
```

Rules:

1. Export the class as **`export default class`**. You may keep the old class name. If the class was already a **named** export imported as `import type { X }`, switch every importer in `src/` and `tests/` to the default import (**companion-v1-to-v2-migrate-definitions** A.2).
2. Move the upgrade-script array **verbatim** into `src/upgrades.ts` as `export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig>[] = [ ... ]`, and re-export it from the main file with `export { UpgradeScripts }`.
   - **Keep the same order and keep duplicates.** Companion stores the index of the last script it ran. If v1 listed `UpgradeV2ToV3` twice, list it twice.
   - If v1 passed `[]` (no upgrades file), still create `src/upgrades.ts` exporting an **empty typed array**, so Phase 7 has somewhere to append.
   - Retype each existing script **completely** as described in **companion-v1-to-v2-expression-upgrades** → Part A. That means the signature **and** the A.2 wrapped-option rewrite, plus any base helper in the array (A.4). A historical script that reads `action.options.x` can't compile with a signature change alone, and the build has to be green by the end of Phase 6. Only **new** scripts wait for Phase 7.
   - **Module with secrets:** `ModuleSchema.secrets` is `ModuleSecrets`, and the array is `CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets>[]`, even when it is empty.
3. **Convert the config `interface` to a `type` alias now** (**companion-v1-to-v2-migrate-definitions** A.1). `ModuleSchema` fails with TS2344 until you do.
4. `ActionsSchema`, `FeedbacksSchema` and `VariablesSchema` are written in Phases 3–6. Until then, use `Record<string, never>` placeholders, and swap each placeholder for the real schema type **in the phase that creates it**, so the error count stays meaningful. A module with no feedbacks or no variables keeps `Record<string, never>` for good (and `setVariableDefinitions({})`).
5. Lifecycle signatures are `init(config, isFirstInit, secrets)` and `configUpdated(config, secrets)`. Declaring fewer trailing parameters is fine. `saveConfig(config)` stays the same, or becomes `saveConfig(config, secrets)` when the module has secrets.
6. A file named `index.ts` can keep its name. Just make sure `package.json` `main` and the manifest `runtime.entrypoint` both point at its compiled `.js`.
7. Keep `this.instanceOptions.disableVariableValidation = true` in the constructor if the module had it. The option still exists in 2.x.
8. Exporting the class makes its public methods module boundaries, so `@typescript-eslint/explicit-module-boundary-types` may start failing lint (and the pre-commit hook) at the first green commit. Add return types; see **`references/esm-and-tooling.md`**.

**Commit boundary:** `refactor: v2 manifest and default-export entrypoint`

---

## Counting build errors

`tsc`'s default "pretty" output is coloured, so `grep "error TS"` finds nothing. Count errors like this:

```bash
yarn tsc -p tsconfig.build.json --noEmit --pretty false | grep -c "error TS"
```

## Phase 3 — Actions

Follow **companion-v1-to-v2-migrate-definitions → Part A** (instance typing) and **Part B** (actions) for every `src/actions/action-*.ts` file and the `actions.ts` aggregator. The error count should drop, and the action files should come out clean.

**Commit boundary:** `refactor(actions): typed v2 action schemas, drop parseVariablesInString`

## Phase 4 — Feedbacks

Follow **companion-v1-to-v2-migrate-definitions → Part C**. Then fix every feedback re-check:
- `checkFeedbacks()` with no arguments → `checkAllFeedbacks()`
- string ids → enum members
- spreading a runtime list → the `AnyFeedbackId` pattern

**Commit boundary:** `refactor(feedbacks): typed v2 feedback schemas and lifecycle`

## Phase 5 — Presets

Follow **companion-v1-to-v2-migrate-presets**. A module with **no presets** (an empty `updatePresets()` or none at all) needs nothing here. Don't add an empty `setPresetDefinitions([], {})` call, and skip this commit.

**Commit boundary:** `refactor(presets): v2 sections/groups and simple presets`

## Phase 6 — Variables and Config

Follow **companion-v1-to-v2-migrate-definitions → Part D** (variables) and **Part E** (config). Part E may be a no-op if the module already uses `isVisibleExpression` and has no `required` or secrets.

**Commit boundary:** `refactor: v2 variable definitions and config fields`

`yarn build` must succeed at this point, including the historical upgrade scripts retyped in Phase 2. From here on, commit with hooks enabled.

## Phase 7 — Upgrade Scripts for the Migration

Follow **companion-v1-to-v2-expression-upgrades**. A new script is needed whenever the migration changes how saved options are stored:
- a `textinput` became a `number` or `checkbox`
- dropdown ids were renamed
- a 0-based value became 1-based

Append new scripts at the **end** of `UpgradeScripts`.

**Commit boundary:** `feat(upgrades): migrate saved options for v2 field types`. Skip this commit if nothing was added or retyped.

## Phase 8 — Tests

Update the tests so they assert v2 shapes. The rewrite table is in **`references/tests.md`**. The most important rows:

- Delete `parseVariablesInString` stubs, and stub `checkAllFeedbacks`.
- `setPresetDefinitions` captures `(structure, presets)`. Change `type === 'button'` filters to `'simple'`, otherwise guard tests pass while checking nothing.
- Harness helpers typed with un-parameterised `CompanionActionDefinition` → `unknown` or the precise generic.

**Commit boundary:** `test: update tests for companion API v2`

---

## Phase 9 — Verify (loop until clean)

```bash
yarn install                        # no YN0060 peer warnings
yarn build                          # tsc -p tsconfig.build.json: 0 errors
yarn tsc -p tsconfig.json --noEmit  # typechecks tests too; vitest/jest strip types and hide breakage
yarn lint                           # fix with: yarn lint:raw --fix  /  yarn format
yarn test                           # same or fewer failures than the Phase 0 baseline
yarn companion-module-check         # exit 0; esbuild warnings such as [direct-eval] are not failures
```

Fix `tsc -p tsconfig.json` errors before lint errors in tests: many test lint errors are knock-on effects of type errors. Lint errors in non-module paths that already failed at baseline (agent tooling, scripts) are recorded, not fixed.

Final grep over **code**. Comment lines are filtered out, because explanatory comments may name removed APIs:

```bash
nc() { grep -vE '^[^:]+:[0-9]+:\s*(\*|//|/\*)'; }
grep -rn "runEntrypoint\|parseVariablesInString\|InstanceBaseExt\|CompanionButtonPresetDefinition\|optionsToIgnoreForSubscribe\|relativeDelay\|isVisible:" src | nc
grep -rnE "checkFeedbacks\(\s*\)" src | nc
grep -rnE "type: ['\"]button['\"]|category:" src/preset* src/presets 2>/dev/null | nc
```

Then:

1. **Bump `package.json` `version` before packaging.** A major bump is appropriate when the minimum Companion version changes. `yarn package` writes `<id>-<version>.tgz` to the repo root and would overwrite an existing tarball with the same version.
2. `yarn package`, then smoke-test the packaged entry with Node (and optionally in Companion). The one-liner, the tracked-`pkg/` caveat and the manifest-version note are in **`references/esm-and-tooling.md`** → "Packaging".
3. Update `companion/HELP.md` if the migration changed how users enter values (fields that now accept expressions) or how presets are grouped.
4. Search for hard-coded copies of the old version (`grep -rn "<old version>" src`) and decide whether each should change.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Removing a duplicate or "obsolete" upgrade script while moving the array | Scripts are positional. Copy the v1 array exactly and only append. |
| Forgetting `"type": "connection"` in the manifest | The module fails to load in Companion 4.3+. `companion-module-check` catches it. |
| `package.json` `main` / manifest `entrypoint` still points at `dist/index.js` after renaming to `main.ts` | Keep the names aligned. |
| Leaving `"module": "Node16"` in tsconfig | Extend `recommended-esm` and delete the overrides. |
| `tsconfig.json` without `rootDir: "./"` + `noEmit` | TS6059 on tests, or stray `.js` files next to tests |
| Not bumping eslint / prettier / typescript-eslint with tools v3 | `YN0060` peer warnings, and lint running an old typescript-eslint against TS 6 |
| Writing a custom regex to replace `parseVariablesInString` | Don't. Set `useVariables: true` on the `textinput` and let Companion parse it. |
| Removing a `parseVariablesInString` call without adding `useVariables: true` to that field | v2 only parses fields marked `useVariables`, so users' `$(…)` silently stops working. See **companion-v1-to-v2-migrate-definitions** B.3. |
| `await tcp.send(…)` / `await udp.send(…)` kept as is | `send()` is synchronous in v2, and `tsc` doesn't flag the `await`. Use `sendAsync()` (migrate-definitions B.4). |
| Default-importing a CJS package because the types allow it | Check the import in Node; some packages need a named import (`references/esm-and-tooling.md`). |
| Historical upgrade scripts left for Phase 7 | Retype them fully in Phase 2, otherwise the build can't be green after Phase 6. |
| Deleting `?? default` guards along with the casts | Options missing from saved buttons then crash the callback. See **companion-v1-to-v2-migrate-definitions** B.1. |
| Migrating to 2.1 but an advanced feedback has no `affectedProperties` | TS error in 2.1. Add the property (it may be `undefined`). |
| Only running `yarn build` + `yarn test` | Tests aren't typechecked. Also run `tsc -p tsconfig.json --noEmit`. |
| Big-bang single commit | Commit at every phase boundary above. |

## Related Skills

- **companion-v1-to-v2-migrate-definitions**: actions, feedbacks, variables, config, and instance typing transforms
- **companion-v1-to-v2-migrate-presets**: `button` + `category` → sections, groups and `simple` presets
- **companion-v1-to-v2-expression-upgrades**: upgrade scripts that ship with the migration
- **companion-v2-module-scaffold**: the target layout and the full `main.ts`
- **companion-v2-action-file-pattern**, **companion-v2-feedback-file-pattern**, **companion-v2-preset-category-file**: the per-category v2 patterns
- **companion-v2-upgrades**: the v2 upgrade-script API
- **companion-v2-api-compliance**: review the result once the migration is done

## References

- `references/inventory.md`: Phase 0.3 grep inventory
- `references/tests.md`: Phase 8 test rewrite table
- `references/characterization-tests.md`: Phase 0.4 tests for modules without a suite
- `references/jest-to-vitest.md`: jest → vitest checklist
- `references/esm-and-tooling.md`: CJS packages, helper scripts, tsconfig inversion, lint findings after tools v3, git hooks, packaging
- [API 2.0 changes](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [API 2.1 changes](https://companion.free/for-developers/module-development/api-changes/v2.1)
- Official TS template: `bitfocus/companion-module-template-ts`
