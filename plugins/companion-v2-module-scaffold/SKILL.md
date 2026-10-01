---
name: companion-v2-module-scaffold
description: '(@companion-module/base v2.x) Scaffold a new Bitfocus Companion module on the v2 API from the official TypeScript template, in the split-file layout with a typed ModuleSchema. Use when starting a brand-new v2 module or setting up its package.json, tsconfig, manifest.json and main.ts. Does NOT apply to upgrading a v1 module (use companion-v1-to-v2-migration) or adding a category to an existing v2 module (use companion-v2-action-file-pattern, companion-v2-feedback-file-pattern or companion-v2-preset-category-file).'
license: MIT
---

# Companion v2 Module Scaffold

Create a new Companion module on **`@companion-module/base` v2.x**. Start from the official TypeScript template, then reshape it into the **split-file layout**: one file per category of actions, feedbacks and presets, each combined by an aggregator. Everything is typed through a single `ModuleSchema`.

> **API level:** this skill targets base **~2.1.x** (Companion 5.0+). Anything marked **2.1+ (Companion 5.0+)** is not available in base 2.0.x (Companion 4.3+). If you must support Companion 4.3/4.x, pin base to `~2.0.4` and skip those features.

## When to Use This Skill

### ✅ Use when:

- Creating a **new** Companion module and you want the v2 API
- Setting up `package.json`, `tsconfig*.json`, `companion/manifest.json` and `src/main.ts` for a v2 module
- Converting the single-file TS template (`src/actions.ts`, `src/feedbacks.ts`, …) into the split-file layout before writing real definitions

### ❌ Do NOT use when:

- The module is on base **v1.x** and you want to keep it there → use the v1 skills (`companion-action-file-pattern`, etc.)
- You are **upgrading** an existing v1 module to v2 → use **`companion-v1-to-v2-migration`**
- The v2 module already exists and you need a new category → use **`companion-v2-action-file-pattern`**, **`companion-v2-feedback-file-pattern`** or **`companion-v2-preset-category-file`**

---

## Target Layout

```
companion/
  HELP.md
  manifest.json
src/
  main.ts                         ← ModuleSchema + `export default class ModuleInstance` + `export { UpgradeScripts }`
  config.ts                       ← `type ModuleConfig` (+ `type ModuleSecrets`) + GetConfigFields()
  actions.ts                      ← aggregator: ActionsSchema = A & B & …; UpdateActions(instance)
  actions/action-{category}.ts    ← enum ActionId{Category} + ActionsSchema{Category} + GetActions{Category}()
  feedbacks.ts                    ← aggregator: FeedbacksSchema = A & B & …; UpdateFeedbacks(instance)
  feedbacks/feedback-{category}.ts
  presets.ts                      ← aggregator: collects { section, presets } from each category
  presets/preset-{category}.ts
  variables.ts                    ← VariablesSchema + UpdateVariableDefinitions()
  upgrades.ts                     ← export const UpgradeScripts = [...]
package.json  tsconfig.json  tsconfig.build.json  eslint.config.mjs  .yarnrc.yml  .gitignore  .prettierignore
```

---

## Step 1 — Copy the TypeScript template

Start from [`bitfocus/companion-module-template-ts`](https://github.com/bitfocus/companion-module-template-ts). Keep its `.github/`, `.husky/`, `.yarnrc.yml`, `.gitignore`, `.gitattributes`, `.prettierignore`, `eslint.config.mjs` and `LICENSE` as they are.

## Step 2 — `package.json`

```json
{
	"name": "acme-mixer",
	"version": "0.1.0",
	"main": "dist/main.js",
	"type": "module",
	"scripts": {
		"postinstall": "husky",
		"format": "prettier -w .",
		"package": "run build && companion-module-build",
		"build": "rimraf dist && run build:main",
		"build:main": "tsc -p tsconfig.build.json",
		"dev": "tsc -p tsconfig.build.json --watch",
		"lint:raw": "eslint",
		"lint": "run lint:raw ."
	},
	"license": "MIT",
	"repository": {
		"type": "git",
		"url": "git+https://github.com/bitfocus/companion-module-acme-mixer.git"
	},
	"engines": {
		"node": "^22.20",
		"yarn": "^4"
	},
	"dependencies": {
		"@companion-module/base": "~2.1.3"
	},
	"devDependencies": {
		"@companion-module/tools": "^3.1.0",
		"@types/node": "^22.19.17",
		"eslint": "^10.2.0",
		"husky": "^9.1.7",
		"lint-staged": "^16.4.0",
		"prettier": "^3.8.3",
		"rimraf": "^6.1.3",
		"typescript": "~6.0.3",
		"typescript-eslint": "^8.59.0"
	},
	"prettier": "@companion-module/tools/.prettierrc.json",
	"lint-staged": {
		"*.{css,json,md,scss}": ["prettier --write"],
		"*.{ts,tsx,js,jsx}": ["yarn lint:raw --fix"]
	},
	"packageManager": "yarn@4.17.0"
}
```

The parts that matter for v2:

| Field | Value | Why |
|---|---|---|
| `"type"` | `"module"` | The TS template and these skills are ESM. Base v2 ships both `import` and `require` entries, so a plain-JS module could stay CommonJS (`module.exports = class …`), but a TypeScript module built from this template must be ESM |
| `@companion-module/base` | `~2.1.3` (or `~2.0.4` for Companion 4.3) | Use a **tilde** range: a minor bump changes the API level and the minimum Companion version |
| `@companion-module/tools` | `^3.1.0` (minimum `2.7.1`) | Its build understands v2 and node26 |
| `main` | `dist/main.js` | Must match `runtime.entrypoint` in the manifest |
| `eslint` / `prettier` / `typescript-eslint` | `^10.2.0` / `^3.8.1`+ / `^8.56.1`+ | Tools 3.1 peers. The template's `eslint ^9.39.x` works, but yarn prints `YN0060` because tools' `@eslint/js` 10 wants eslint ^10.2 |

> After changing `"name"`, run `yarn install` again. Otherwise yarn 4 fails with `Package for <name>@workspace:. not found`.

## Step 3 — TypeScript config

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

`tsconfig.json` (for the editor, lint and tests). This is the template's version, which covers only `src/`:

```json
{
	"extends": "./tsconfig.build.json",
	"include": ["src/**/*.ts"],
	"exclude": ["node_modules/**"],
	"compilerOptions": {
		"types": ["node"]
	}
}
```

When you add tests (`tests/**/*.ts`, `vitest.config.ts`), also set `"rootDir": "./"` and `"noEmit": true` in this file. Otherwise `tsc -p tsconfig.json` fails with TS6059 (files outside `rootDir`), or writes `.js` files next to the tests. Typecheck tests with `yarn tsc -p tsconfig.json --noEmit`, because test runners strip types.

- **Never** use `node22/recommended`. It is CommonJS (`"module": "commonjs"`, `"moduleResolution": "node"`). `node22/recommended-esm` sets `"module": "node20"` / `"moduleResolution": "node16"`, which together with `"type": "module"` produces ESM.
- `verbatimModuleSyntax: true` means any import used **only as a type** must be written `import type { … }` or `import { type X }`.
- Every relative import needs the `.js` extension (`./actions.js`), even though the source file is `.ts`.

> **2.1+ (Companion 5.0+)** — Node 26: extend `@companion-module/tools/tsconfig/node26/recommended.json` instead. It has no `-esm` variant and doesn't need one: it already uses `node20`/`node16` module settings with an `es2025` target. Then set `runtime.type` to `"node26"` in the manifest (Step 4), and bump `engines.node` and `@types/node` to Node 26. `node22` remains supported.

## Step 4 — `companion/manifest.json`

```json
{
	"$schema": "../node_modules/@companion-module/base/assets/manifest.schema.json",
	"type": "connection",
	"id": "acme-mixer",
	"name": "acme-mixer",
	"shortname": "mixer",
	"description": "Control Acme digital mixers",
	"version": "0.0.0",
	"license": "MIT",
	"repository": "git+https://github.com/bitfocus/companion-module-acme-mixer.git",
	"bugs": "https://github.com/bitfocus/companion-module-acme-mixer/issues",
	"maintainers": [{ "name": "Jane Doe", "email": "jane@example.com" }],
	"runtime": {
		"type": "node22",
		"api": "nodejs-ipc",
		"apiVersion": "0.0.0",
		"entrypoint": "../dist/main.js"
	},
	"legacyIds": [],
	"manufacturer": "Acme",
	"products": ["Mixer"],
	"keywords": ["audio", "mixer"]
}
```

- **`"type": "connection"` is required in v2.** Some docs pages leave it out, but `companion-module-check` rejects a manifest without it.
- `version` and `apiVersion` stay `"0.0.0"`, because the build fills them in.
- `runtime.type` is `"node22"`, or `"node26"` on **2.1+**. `node18` is not allowed in v2.
- **Replace every template placeholder.** `companion-module-check` fails if the manifest still contains any of: `companion-module-your-module-name`, `module-shortname`, `A short one line description of your module`, `Your name`, `Your email`, `Your company`, `Your product`.
- Optional fields: `runtime.permissions` (`filesystem`, `child-process`, `worker-threads`, `native-addons`, `insecure-algorithms`), `bonjourQueries`, `isPrerelease`.

## Step 5 — `src/main.ts`

```typescript
import { InstanceBase, InstanceStatus, type SomeCompanionConfigField } from '@companion-module/base'
import { GetConfigFields, type ModuleConfig } from './config.js'
import { UpdateActions, type ActionsSchema } from './actions.js'
import { UpdateFeedbacks, type FeedbacksSchema } from './feedbacks.js'
import { UpdatePresets } from './presets.js'
import { UpdateVariableDefinitions, type VariablesSchema } from './variables.js'
import { UpgradeScripts } from './upgrades.js'
import { FeedbackIdTransport } from './feedbacks/feedback-transport.js'

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
	state = { playing: false, level: 0 }

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

	sendCommand(path: string, ...args: (string | number | boolean)[]): void {
		this.log('debug', `${path} ${args.join(' ')}`)
		this.setVariableValues({ last_command: path })
		this.checkFeedbacks(FeedbackIdTransport.playing)
	}
}
```

Rules:

- `export default class …`. There is **no** `runEntrypoint()` in v2.
- `export { UpgradeScripts }` must be a **named** export.
- `ModuleSchema` ties everything together. `InstanceBase<ModuleSchema>` then type-checks every `setActionDefinitions`, `setFeedbackDefinitions`, `setPresetDefinitions`, `setVariableValues` and `checkFeedbacks` call.
- Set `secrets: undefined` when the module has no `secret-text` fields. Otherwise use `secrets: ModuleSecrets` and accept the third `init` argument (see **companion-v2-config**).
- `init()` must not wait for the device to connect. Start the connection and return.
- Base helpers `TCPHelper` / `UDPHelper`: in v2, `send()` is **synchronous**. `TCPHelper.send` returns `boolean` (`false` when not connected), and `UDPHelper.send` returns `void`. Errors go to the `'error'` event. Use `await sendAsync()` when you need the promise (resolve or reject). `tsc` doesn't flag `await send()`; only lint's `await-thenable` does.
- `state` and `sendCommand` stand in for your module's own device state and transport. The examples in the other `companion-v2-*` skills call members like these (`instance.state.muted`, `instance.query(...)`). Define whatever your module needs as real public members of the class.
- Call `setActionDefinitions` and `setFeedbackDefinitions` **before** `setPresetDefinitions`.
- Category files import the class as a type only: `import type ModuleInstance from '../main.js'`. Because the import is erased, there is no runtime circular dependency, and every public member of the class (state, helpers, `log`, `setVariableValues`, …) is typed. Do not recreate the v1 `InstanceBaseExt<Config>` interface with `[x: string]: any`.

## Step 6 — Aggregators and the first category files

Create one category file per area using the pattern skills. The aggregators look like this.

`src/actions.ts`:

```typescript
import type ModuleInstance from './main.js'
import { GetActionsTransport, type ActionsSchemaTransport } from './actions/action-transport.js'
import { GetActionsLevel, type ActionsSchemaLevel } from './actions/action-level.js'

export type ActionsSchema = ActionsSchemaTransport & ActionsSchemaLevel

export function UpdateActions(instance: ModuleInstance): void {
	instance.setActionDefinitions({
		...GetActionsTransport(instance),
		...GetActionsLevel(instance),
	})
}
```

`src/feedbacks.ts` has the same shape, using `FeedbacksSchema`, `setFeedbackDefinitions` and the `GetFeedbacks{Category}` factories.

`src/presets.ts`:

```typescript
import type { CompanionPresetDefinitions, CompanionPresetSection } from '@companion-module/base'
import type ModuleInstance from './main.js'
import type { ModuleSchema } from './main.js'
import { GetPresetsTransport } from './presets/preset-transport.js'

export function UpdatePresets(instance: ModuleInstance): void {
	const categories = [GetPresetsTransport()]

	const structure: CompanionPresetSection<ModuleSchema>[] = categories.map((c) => c.section)
	const presets: CompanionPresetDefinitions<ModuleSchema> = Object.assign({}, ...categories.map((c) => c.presets))

	instance.setPresetDefinitions(structure, presets)
}
```

`src/upgrades.ts`:

```typescript
import type { CompanionStaticUpgradeScript } from '@companion-module/base'
import type { ModuleConfig } from './config.js'

export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig>[] = [
	// Append new scripts at the end. Never remove or reorder them.
]
```

For the category files, `config.ts` and `variables.ts`, see the related skills below.

## Step 7 — Build and verify

```bash
yarn install
yarn build                    # tsc must report 0 errors
yarn lint                     # prettier + eslint
yarn companion-module-check   # manifest + package validation; success prints only the path lines and exits 0
yarn package                  # produces <name>-<version>.tgz
```

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| `runEntrypoint(ModuleInstance, UpgradeScripts)` at the bottom of `main.ts` | Removed in v2. Use `export default class` plus `export { UpgradeScripts }` |
| `"type": "module"` missing from `package.json` | The TS template is ESM. Add it |
| Extending `tsconfig/node22/recommended` | Use `node22/recommended-esm` (or `node26/recommended` on 2.1+) |
| Manifest without `"type": "connection"` | Required in v2 |
| Template placeholders left in the manifest | `companion-module-check` rejects them. Replace them all |
| `yarn` fails with "Package for X@workspace:. not found" | You renamed the package. Run `yarn install` again |
| `import { ModuleConfig } from './config.js'` for a type | Use `import type` / `type` modifiers, because `verbatimModuleSyntax` requires them |
| `interface ModuleConfig { … }` | Use a `type` alias. Interfaces don't satisfy `JsonObject` |
| `InstanceBase<ModuleConfig>` | v2 takes the whole schema: `InstanceBase<ModuleSchema>` |
| `await tcp.send(…)` / `await udp.send(…)` | `send()` is synchronous in v2. Use `sendAsync()` for promise semantics |
| Adding vitest tests and lint fails on every test file | Turn off `n/no-unpublished-import` and `@typescript-eslint/unbound-method` for `tests/**` and `vitest.config.ts` (see **companion-v1-to-v2-migration** → `references/esm-and-tooling.md`) |
| Base range `^2.0.0` | Use `~2.1.3` / `~2.0.4`. A minor bump raises the minimum Companion version |

## Related Skills

- **`companion-v2-action-file-pattern`** — create `src/actions/action-{category}.ts` and wire it into `actions.ts`
- **`companion-v2-feedback-file-pattern`** — create `src/feedbacks/feedback-{category}.ts`
- **`companion-v2-preset-category-file`** — create `src/presets/preset-{category}.ts`
- **`companion-v2-config`** — `config.ts`, secrets and `isVisibleExpression`
- **`companion-v2-variable-definition`** — `variables.ts` and `VariablesSchema`
- **`companion-v2-upgrades`** — `upgrades.ts`
- **`companion-v2-api-compliance`** — review checklist for a finished v2 module
- **`companion-v1-to-v2-migration`** — when starting from an existing v1 module instead

## References

- [Module template (TypeScript)](https://github.com/bitfocus/companion-module-template-ts)
- [API 2.0 changes](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [API 2.1 changes](https://companion.free/for-developers/module-development/api-changes/v2.1)
- [manifest.json](https://companion.free/for-developers/module-development/module-setup/manifest.json)
