---
name: companion-v1-to-v2-migration
description: 'Step-by-step procedure for upgrading a Bitfocus Companion module from @companion-module/base v1.x to the v2 API (2.0 or 2.1). Use when asked to migrate, upgrade, or port a module to API v2, base 2.x, Companion 4.3+/5.0+, or to remove runEntrypoint. Orchestrates the assessment, tooling/ESM, manifest, entrypoint, and test phases and hands off to companion-v1-to-v2-migrate-definitions, companion-v1-to-v2-migrate-presets, and companion-v1-to-v2-expression-upgrades. Does NOT apply to building a new v2 module from scratch — use companion-v2-module-scaffold instead.'
license: MIT
---

# Companion v1 → v2 Module Migration

This skill is the **orchestrator** for converting an existing `@companion-module/base` 1.x module to the v2 API. Work through the phases **in order**. Each phase ends with a build check and a **commit boundary**, so the history reads as small, reviewable steps.

The finished module should match the v2 split-file layout taught by the `companion-v2-*` skills:

```
src/
  main.ts                 ModuleSchema + `export default class ModuleInstance extends InstanceBase<ModuleSchema>` + `export { UpgradeScripts }`
  config.ts               `export type ModuleConfig = {...}` + GetConfigFields()
  actions.ts              `export type ActionsSchema = ActionsSchemaA & ActionsSchemaB`; UpdateActions(instance)
  actions/action-{category}.ts
  feedbacks.ts            `export type FeedbacksSchema = ...`; UpdateFeedbacks(instance)
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
- You are asked to make a module "expression ready" or to support Companion 4.3+ / 5.0+ features

### ❌ Do NOT use this skill when:

- You are creating a brand-new module → **companion-v2-module-scaffold**
- The module is already on base 2.x and you only need to add an action, feedback, or preset → use the `companion-v2-*` skills
- You are only **reviewing** a module → **companion-v1-api-compliance** or **companion-v2-api-compliance**

**The rule:** v1 and v2 APIs never mix inside one module. Once you change the base version, the whole module has to follow the v2 API before it builds again. Phases 1–2 change the toolchain, so the build is expected to stay red until the definition phases are done. From Phase 3 onward, each phase should bring the build closer to green.

---

## Phase 0 — Assess and Choose a Target

### 0.1 Record the starting point

```bash
git status                                   # must be clean
git checkout -b feat/companion-api-v2        # never migrate on main
grep '"@companion-module/base"\|"@companion-module/tools"\|"typescript"\|"type"' package.json
grep -n '"type"\|"runtime"' -A4 companion/manifest.json
yarn install && yarn build && yarn test      # baseline: note what already fails
```

### 0.2 Choose the target API

| Target | Base version | Companion | Pick it when |
|---|---|---|---|
| **2.1** (recommended) | `~2.1.3` | 5.0+ | Default choice. You also get `context.signal`, action results (`hasResult`), `affectedProperties`, layered/alternatives presets, `internal:*` preset actions, and `node26`. |
| **2.0** | `~2.0.4` | 4.3+ | Users must stay on Companion 4.3/4.4. Skip every step marked **2.1+**. |

In 2.1, some things are required at the TypeScript level only:
- **Advanced feedbacks** must declare `affectedProperties`.
- **Actions with `subscribe`** must declare `optionsToMonitorForSubscribe`.

Both are covered in **companion-v1-to-v2-migrate-definitions**.

### 0.3 Inventory every v1 API in use

Run these from the module root and save the output. Each line that matches is a work item.

```bash
# Entry point / class typing
grep -rn "runEntrypoint" src
grep -rn "InstanceBase<\|InstanceBaseExt" src tests 2>/dev/null
grep -rnE "^export (interface|type) .*Config" src
grep -rnE "interface \w*Config" src

# Variable parsing (removed in v2)
grep -rn "parseVariablesInString" src tests 2>/dev/null

# Feedback checks / lifecycle
grep -rnE "checkFeedbacks\(\s*\)" src
grep -rn "subscribe" src/feedback* src/feedbacks 2>/dev/null
grep -rn "imageBuffer" src

# Variables
grep -rn "setVariableDefinitions" src
grep -rn "variableId" src

# Inputs / config
grep -rn "isVisible:" src
grep -rnE "\brequired:\s*(true|false)" src
grep -rn "InputValue" src tests 2>/dev/null
grep -rn "optionsToIgnoreForSubscribe" src
grep -rn "learn:" src

# Presets
grep -rn "setPresetDefinitions" src
grep -rn "CompanionButtonPresetDefinition\|CompanionPresetDefinitions\|CompanionTextPresetDefinition" src
grep -rn "category:" src/preset* src/presets 2>/dev/null
grep -rnE "type: ['\"](button|text)['\"]" src
grep -rn "relativeDelay" src

# Module format
grep -rn "require(" src
grep -n '"type"' package.json
grep -n '"extends"\|"module"\|"moduleResolution"' tsconfig*.json

# Custom variable writes from actions (candidates for 2.1 action results)
grep -rn "setCustomVariableValue" src
```

Also list the test setup, because tests usually mock the v1 instance surface:

```bash
ls tests/helpers tests/__mocks__ 2>/dev/null; grep -rln "parseVariablesInString\|checkFeedbacks\|setVariableDefinitions\|setPresetDefinitions" tests 2>/dev/null
```

---

## Phase 1 — Tooling and ESM

### 1.1 `package.json`

| Field | v1 typical | v2 value |
|---|---|---|
| `"type"` | missing (CommonJS) | `"module"` |
| `dependencies["@companion-module/base"]` | `~1.14.1` | `~2.1.3` (or `~2.0.4` for the 2.0 target) |
| `devDependencies["@companion-module/tools"]` | `^2.x` | `^3.1.0` (minimum 2.7.1; v3 is a drop-in replacement) |
| `devDependencies["typescript"]` | `~5.x` | `~6.0.3` |
| `devDependencies["@types/node"]` | `^22.x` | `^22.19.17` (match `engines.node`) |
| `engines.node` | `^22.x` | `^22.20` |
| `packageManager` | `yarn@4.x` | keep yarn 4 (the template uses `yarn@4.17.0`) |
| `main` | `dist/index.js` or `dist/main.js` | keep it, but it **must match** `runtime.entrypoint` in the manifest |

Then:

```bash
yarn install
```

### 1.2 `tsconfig.build.json`

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

- Remove any `"module": "Node16"`, `"moduleResolution": "Node16"`, `baseUrl` or `paths` overrides you carried over from v1. `recommended-esm` sets `nodenext`.
- Keep `tsconfig.json`, which extends the build config and adds `tests/**` plus `"types": ["node", ...]`, with its test-framework types unchanged.
- **2.1+ (Companion 5.0+)** with a `node26` runtime: extend `@companion-module/tools/tsconfig/node26/recommended.json` instead.

### 1.3 Fix ESM import syntax across `src/` (and `tests/`)

`verbatimModuleSyntax` turns three things into errors:

| Problem | Fix |
|---|---|
| Type-only names imported as values: `import { CompanionActionDefinition } from '@companion-module/base'` | `import type { ... }`, or inline `import { InstanceBase, type SomeCompanionConfigField }` |
| Relative imports without an extension: `from './utils'` | `from './utils.js'` (always `.js`, even for `.ts` sources) |
| `require('x')` / `module.exports` | ESM `import`. For CJS-only packages with no usable ESM entry, use `createRequire` (below) |

```ts
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
// CJS-only dependency without ESM exports / types
const legacyLib = require('node:os') as typeof import('node:os')
```

Most CJS packages can be default-imported under `nodenext`, e.g. `import osc from 'osc'` or `import nodeOsc from 'node-osc'`. Try that first, and use `createRequire` only if the default import fails at runtime.

`__dirname` and `__filename` don't exist in ESM. Use `import.meta.dirname` (Node 22) or `fileURLToPath(new URL('.', import.meta.url))`.

### 1.4 Lint config

`eslint.config.mjs` stays `generateEslintConfig({ enableTypescript: true })`. Keep any custom rule overrides the module already had.

### 1.5 Test runner

| Runner | What to change |
|---|---|
| **vitest** | Usually nothing. It is ESM-native. Keep `vitest.config.*`. |
| **jest + ts-jest** | Either switch to vitest (simplest), or use `ts-jest`'s ESM preset (`preset: 'ts-jest/presets/default-esm'`, `extensionsToTreatAsEsm: ['.ts']`, `moduleNameMapper: { '^(\\.{1,2}/.*)\\.js$': '$1' }`) and run jest with `NODE_OPTIONS=--experimental-vm-modules`. `jest.config.ts` needs `ts-node` with ESM support, or rename it to `jest.config.cjs`/`.mjs`. |

**Commit boundary:** `chore: switch tooling to companion API v2 (ESM, tools v3, base 2.1)`

The build will be red here. That's expected, because the code still uses v1 APIs.

---

## Phase 2 — Manifest and Entry Point

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
- Keep every other existing field as-is: `id`, `name`, `shortname`, `maintainers`, `legacyIds`, `products`, `keywords`, `bonjourQueries`, `runtime.permissions` and so on. Don't change `id`.
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

**After (v2):**

```ts
import { InstanceBase, InstanceStatus, type SomeCompanionConfigField } from '@companion-module/base'
import { GetConfigFields, type ModuleConfig } from './config.js'
import { UpdateActions, type ActionsSchema } from './actions.js'
import { UpdateFeedbacks, type FeedbacksSchema } from './feedbacks.js'
import { UpdatePresets } from './presets.js'
import { UpdateVariableDefinitions, type VariablesSchema } from './variables.js'
import { UpgradeScripts } from './upgrades.js'

export type ModuleSchema = {
	config: ModuleConfig
	secrets: undefined
	actions: ActionsSchema
	feedbacks: FeedbacksSchema
	variables: VariablesSchema
}

export { UpgradeScripts }

export default class ModuleInstance extends InstanceBase<ModuleSchema> {
	config!: ModuleConfig

	constructor(internal: unknown) {
		super(internal)
	}

	async init(config: ModuleConfig): Promise<void> {
		this.config = config
		this.updateStatus(InstanceStatus.Ok)
		this.updateDefinitions()
	}

	async destroy(): Promise<void> {
		this.log('debug', 'destroy')
	}

	async configUpdated(config: ModuleConfig): Promise<void> {
		this.config = config
	}

	getConfigFields(): SomeCompanionConfigField[] {
		return GetConfigFields()
	}

	updateDefinitions(): void {
		UpdateVariableDefinitions(this)
		UpdateActions(this)
		UpdateFeedbacks(this)
		UpdatePresets(this)
	}
}
```

Rules:

1. Export the class as **`export default class`**. You may keep the old class name, e.g. `export default class ZoomInstance`.
2. Move the upgrade-script array **verbatim** into `src/upgrades.ts` as `export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig>[] = [ ... ]`, and re-export it from the main file with `export { UpgradeScripts }`.
   - **Keep the same order, and keep duplicates.** Companion stores the index of the last script it ran, so removing or reordering scripts breaks existing users. If v1 listed `UpgradeV2ToV3` twice, list it twice.
   - Retype each script's signature as described in **companion-v1-to-v2-expression-upgrades** ("Retype existing scripts").
3. The `ModuleSchema` type replaces the v1 `InstanceBase<Config>` generic. `ActionsSchema`, `FeedbacksSchema` and `VariablesSchema` are created in Phases 3–5. Until then, you can temporarily use `Record<string, never>` placeholders.
4. Lifecycle signatures:
   - `init(config, isFirstInit, secrets)`
   - `configUpdated(config, secrets)`
   - `saveConfig(config)`, or `saveConfig(config, secrets)` when `secrets` is not `undefined`.
5. If the file is named `index.ts` you can keep it. Just make sure `package.json` `main` and the manifest `runtime.entrypoint` both point at its compiled `.js`.
6. Keep `this.instanceOptions.disableVariableValidation = true` in the constructor if the module had it. The option still exists.

**Commit boundary:** `refactor: v2 manifest and default-export entrypoint`

---

## Phase 3 — Actions

Follow **companion-v1-to-v2-migrate-definitions → Part A (Instance typing)** and **Part B (Actions)** for every `src/actions/action-*.ts` file and the `actions.ts` aggregator.

```bash
yarn build 2>&1 | grep -c "error TS"     # count should drop; action files should now be clean
```

**Commit boundary:** `refactor(actions): typed v2 action schemas, drop parseVariablesInString`

## Phase 4 — Feedbacks

Follow **companion-v1-to-v2-migrate-definitions → Part C (Feedbacks)**. Then replace every call that triggers feedback re-checks:
- no-arg `checkFeedbacks()` → `checkAllFeedbacks()`
- string IDs → enum members

**Commit boundary:** `refactor(feedbacks): typed v2 feedback schemas and lifecycle`

## Phase 5 — Presets

Follow **companion-v1-to-v2-migrate-presets**.

**Commit boundary:** `refactor(presets): v2 sections/groups and simple presets`

## Phase 6 — Variables and Config

Follow **companion-v1-to-v2-migrate-definitions → Part D (Variables)** and **Part E (Config)**.

**Commit boundary:** `refactor: v2 variable definitions and config fields`

At this point `yarn build` must succeed.

## Phase 7 — Upgrade Scripts for the Migration

Follow **companion-v1-to-v2-expression-upgrades**. You need a new upgrade script whenever the migration changes how saved options are stored:
- a `textinput` became a `number` or `checkbox`
- dropdown IDs were renamed
- a 0-based value became 1-based

Append new scripts to the **end** of `UpgradeScripts`.

**Commit boundary:** `feat(upgrades): migrate saved options for v2 field types`

## Phase 8 — Tests

Update the tests so they assert v2 shapes:

| v1 test pattern | v2 replacement |
|---|---|
| Mock instance stubs `parseVariablesInString: vi.fn(async (s) => s)` | Delete the stub. Callbacks receive already-parsed `options`, so pass the final values straight into `callback({ options: {...} } as any, ctx)`. |
| Mock instance stubs `checkFeedbacks` and asserts `toHaveBeenCalledWith()` with no args | Stub `checkAllFeedbacks` too. Assert `checkFeedbacks` is called with **feedback IDs** (`FeedbackIdX.member`). |
| `setVariableDefinitions` mock asserts an array of `{ variableId, name }` | Assert an object: `expect(defs).toHaveProperty('my_var', { name: '...' })`, or `Object.keys(defs)`. |
| `setPresetDefinitions` mock captures one argument; tests read `preset.category` / `type: 'button'` | It now captures `(structure, presets)`. Assert `type: 'simple'`, and find a preset's section by searching `structure[].definitions[].presets`. |
| Tests call `callback(event)` only | v2 passes a context object as the 2nd argument. Pass `{ type: 'action', signal: new AbortController().signal }` (or `'feedback'`) when the code reads the context. |
| Tests import the default class through `require` or `index.js` | `import ModuleInstance from '../src/main.js'` |
| Tests build option values like `{ userName: '$(internal:x)' }` and expect parsing | Parsing is now Companion's job. Test with already-resolved values. |
| Guard tests over definitions check `options[].id` uniqueness | Keep them. Duplicate option IDs are rejected at runtime in 2.1. |

Mock helpers: rename any `InstanceBaseExt` mock type to `ModuleInstance`. Cast with `as unknown as ModuleInstance` and add whatever fields the code under test touches.

**Commit boundary:** `test: update tests for companion API v2`

---

## Phase 9 — Verify (loop until clean)

```bash
yarn install
yarn build                        # tsc -p tsconfig.build.json — must be 0 errors
yarn lint                         # fix with: yarn lint:raw --fix  /  yarn format
yarn test                         # all unit tests green (skip live/hardware suites)
yarn companion-module-check       # manifest + package validation
yarn package                      # produces <id>-<version>.tgz; optional smoke test in Companion
```

Final grep. All of these should return nothing:

```bash
grep -rn "runEntrypoint\|parseVariablesInString\|InstanceBaseExt\|CompanionButtonPresetDefinition\|optionsToIgnoreForSubscribe\|relativeDelay\|isVisible:" src
grep -rnE "checkFeedbacks\(\s*\)" src
grep -rnE "type: ['\"]button['\"]|category:" src/preset* src/presets 2>/dev/null
```

Then update `companion/HELP.md` if the migration changed how users enter values (e.g. fields that now accept expressions), and bump the `package.json` version. A major bump is appropriate when the minimum Companion version changes.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Removing a duplicate or "obsolete" upgrade script while moving the array | Scripts are positional. Copy the v1 array exactly and only append. |
| Forgetting `"type": "connection"` in the manifest | Module fails to load in Companion 4.3+. `companion-module-check` catches it. |
| `package.json` `main` / manifest `entrypoint` still points at `dist/index.js` after renaming to `main.ts` | Keep the names aligned. |
| Leaving `"module": "Node16"` in tsconfig | Extend `recommended-esm` and delete the overrides. |
| Running `parseVariablesInString` replacements with a custom regex | Don't. Set `useVariables: true` on the `textinput` and let Companion parse. |
| Migrating to 2.1 but the advanced feedback has no `affectedProperties` | TS error in 2.1. Add the property (may be `undefined`). |
| Big-bang single commit | Commit at every phase boundary above. |

## Related Skills

- **companion-v1-to-v2-migrate-definitions** — actions, feedbacks, variables, config, and instance typing transforms
- **companion-v1-to-v2-migrate-presets** — `button` + `category` → sections, groups and `simple` presets
- **companion-v1-to-v2-expression-upgrades** — upgrade scripts that ship with the migration
- **companion-v2-module-scaffold** — the target layout for a fresh v2 module
- **companion-v2-action-file-pattern**, **companion-v2-feedback-file-pattern**, **companion-v2-preset-category-file** — the per-category v2 patterns
- **companion-v2-api-compliance** — review the result once the migration is done

## References

- [API 2.0 changes](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [API 2.1 changes](https://companion.free/for-developers/module-development/api-changes/v2.1)
- Official TS template: `bitfocus/companion-module-template-ts`
