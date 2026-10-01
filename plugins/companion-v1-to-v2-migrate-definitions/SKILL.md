---
name: companion-v1-to-v2-migrate-definitions
description: 'Before/after transforms for migrating Companion module actions, feedbacks, variables, config fields, and instance typing from @companion-module/base v1.x to v2 (2.0/2.1). Use when converting InstanceBaseExt or InstanceBase<Config> to a typed ModuleSchema, removing parseVariablesInString, adding per-category action/feedback schema types, fixing checkFeedbacks(), feedback subscribe, isVisible, required, InputValue, or array-form setVariableDefinitions. Does NOT cover presets (use companion-v1-to-v2-migrate-presets) or overall migration order (use companion-v1-to-v2-migration).'
license: MIT
---

# Migrate Definitions (Actions, Feedbacks, Variables, Config) to v2

This skill holds the **code-level transforms** used in Phases 2–4 and 6 of **companion-v1-to-v2-migration**. Every "After" snippet compiles against `@companion-module/base` 2.1.3. Items marked **2.1+ (Companion 5.0+)** can be skipped when targeting 2.0.

## When to Use This Skill

### ✅ Use this skill when:

- Converting `src/actions/action-*.ts`, `src/feedback*.ts`, `src/variables*`, or `src/config.ts` from v1 to v2
- Replacing `InstanceBaseExt<Config>` / `InstanceBase<Config>` typing with the v2 `ModuleSchema`
- Removing `parseVariablesInString` (instance or callback `context`)
- Fixing TypeScript errors that appear after bumping the base package to 2.x

### ❌ Do NOT use this skill when:

- Converting presets → **companion-v1-to-v2-migrate-presets**
- Writing upgrade scripts for changed option types → **companion-v1-to-v2-expression-upgrades**
- Adding brand-new definitions to an already-v2 module → **companion-v2-add-action-to-category-file** / **companion-v2-add-feedback-to-category-file**

**The rule:** in v2 the **schema type is the contract**. Every action and feedback id maps to a typed `options` object. Option values arrive with variables already parsed and expressions already evaluated and validated. Remove **casts and manual parsing** (`as string`, `String(x)`, `Number(x)`, `parseVariablesInString`). **Keep `?? default` null guards** for option keys that can be missing from stored data: options added to a definition after users saved buttons, and v1 presets that shipped `options: {}`. The schema types those keys as always present, and Companion does not guarantee to back-fill defaults.

---

## Part A — Instance Typing

### A.1 Config: `interface` → `type` (do this in Phase 2)

v2 requires the config to satisfy `JsonObject`. An `interface` has no implicit index signature, so it fails with `TS2344: Type 'ModuleSchema' does not satisfy the constraint 'InstanceTypes'`. That error appears as soon as `ModuleSchema` exists (Phase 2), so convert the config then.

```ts
// Before (v1)
export interface ZoomConfig {
	host: string
	tx_port: number
	enableSocialStream: boolean
	socialStreamChatTypeToSend: string[]
}

// After (v2)
export type ZoomConfig = {
	host: string
	tx_port: number
	enableSocialStream: boolean
	socialStreamChatTypeToSend: string[]
	label?: string // optional fields are fine
}
```

Every value must be JSON-safe: no `Date`, `Map`, class instances or functions. Keeping the old type name keeps the diff small.

### A.2 `InstanceBaseExt` → `import type ModuleInstance`

v1 split-file modules usually declared a structural interface so that category files wouldn't import the class:

```ts
// Before (v1) — src/utils.ts
export interface InstanceBaseExt<TConfig> extends InstanceBase<TConfig> {
	[x: string]: any
	ZoomClientDataObj: ZoomClientDataObjInterface
	OSC: any
	config: TConfig
}
```

In v2, import the real class **type-only**. `import type` is erased at compile time, so the `main.ts` ↔ category-file cycle never exists at runtime:

```ts
// After (v2) — any category file
import type ModuleInstance from '../main.js'

export function GetActionsUserHandRaised(instance: ModuleInstance) { ... }
```

Procedure:

1. Replace every `InstanceBaseExt<XConfig>` parameter type with `ModuleInstance`. Add `import type ModuleInstance from '../main.js'`, or `./main.js` for files directly in `src/`.
2. **The class was already a named export** (`export class ModuleInstance`, imported as `import type { ModuleInstance }`)? v2 needs the default export. Switch every `import type { ModuleInstance } from …` to `import type ModuleInstance from …` in `src/` **and** `tests/`, e.g. `grep -rln "import type { ModuleInstance }" src tests`. You can also keep a named re-export for the transition.
3. Delete the `InstanceBaseExt` interface from `utils.ts`.
4. Every property that callbacks reach through `[x: string]: any` must become a **real public field or method on the class**, for example `instance.ZoomClientDataObj`, `instance.OSC` or `instance.sendCommand`. `[x: string]: any` used to hide typos; now `tsc` lists each missing member.
   ```ts
   export default class ModuleInstance extends InstanceBase<ModuleSchema> {
   	config!: ModuleConfig
   	public ZoomClientDataObj: ZoomClientDataObjInterface = { /* ...defaults... */ }
   	public OSC: OSC | null = null
   	state = { playing: false, level: 0, lastCommand: '' }
   	// ...
   }
   ```
5. Type `OSC: any`-style fields properly if you can. Otherwise leave them `any` with a TODO; don't block the migration on it.

---

## Part B — Actions

### B.1 Add a schema type per category file

For each `src/actions/action-{category}.ts`:

1. Keep the existing `enum ActionId{Category}` **unchanged**. The string values are the saved action ids, so renaming them breaks users' buttons.
2. Add `export type ActionsSchema{Category}`, with one key per enum member mapping to `{ options: {...} }`.
3. Derive each option's TS type from its input field:

| Field `type` | Option TS type |
|---|---|
| `textinput` | `string` |
| `number` | `number` |
| `checkbox` | `boolean` |
| `dropdown` | the choice id type (`string`, `number`, a string-literal union, or the `enum` used for the ids) |
| `multidropdown` | `string[]` / `number[]` (the choice id type, as an array) |
| `colorpicker` | `number`, or `string` when `returnType: 'string'` |
| `custom-variable` | `string` |
| `static-text` | `note?: undefined`. **Required on base 2.0.x**, where a static-text `id` must be a schema key. From **2.1.3** static-text ids may be any string, so the key can be omitted. Adding it works on both. |
| no options | `Record<string, never>` |

4. Change the factory's return type to `CompanionActionDefinitions<ActionsSchema{Category}>`.

**Before (v1):**

```ts
import { CompanionActionDefinition } from '@companion-module/base'
import { ZoomConfig } from '../config.js'
import { InstanceBaseExt, options } from '../utils.js'
import { createCommand, select, sendActionCommand } from './action-utils.js'

export enum ActionIdUserHandRaised {
	raiseHand = 'raiseHand',
	lowerHand = 'lowerHand',
}

export function GetActionsUserHandRaised(instance: InstanceBaseExt<ZoomConfig>): {
	[id in ActionIdUserHandRaised]: CompanionActionDefinition | undefined
} {
	const actions: { [id in ActionIdUserHandRaised]: CompanionActionDefinition | undefined } = {
		[ActionIdUserHandRaised.raiseHand]: {
			name: 'Raise Hand',
			options: [options.userName],
			callback: async (action): Promise<void> => {
				const userName = await instance.parseVariablesInString(action.options.userName as string)
				const command = createCommand(instance, '/raiseHand', userName, select.multi)
				// ...
			},
		},
		[ActionIdUserHandRaised.lowerHand]: {
			name: 'Lower Hand',
			options: [options.userName],
			callback: async (action): Promise<void> => {
				const userName = await instance.parseVariablesInString(action.options.userName as string)
				const command = createCommand(instance, '/lowerHand', userName, select.multi)
				// ...
			},
		},
	}
	return actions
}
```

**After (v2):** the same enum and ids. `options.userName` is now the literal-id shared field from B.2.

```ts
import type { CompanionActionDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'
import { options } from '../utils.js'

export enum ActionIdUserHandRaised {
	raiseHand = 'raiseHand',
	lowerHand = 'lowerHand',
}

export type ActionsSchemaUserHandRaised = {
	[ActionIdUserHandRaised.raiseHand]: { options: { userName: string } }
	[ActionIdUserHandRaised.lowerHand]: { options: { userName: string } }
}

export function GetActionsUserHandRaised(
	instance: ModuleInstance,
): CompanionActionDefinitions<ActionsSchemaUserHandRaised> {
	return {
		[ActionIdUserHandRaised.raiseHand]: {
			name: 'Raise Hand',
			options: [options.userName],
			callback: async (action): Promise<void> => {
				// v2: action.options.userName is already a parsed string — no parseVariablesInString, no cast
				instance.sendCommand('/raiseHand', action.options.userName)
			},
		},
		[ActionIdUserHandRaised.lowerHand]: {
			name: 'Lower Hand',
			options: [options.userName],
			callback: async (action): Promise<void> => {
				instance.sendCommand('/lowerHand', action.options.userName)
			},
		},
	}
}
```

What changed:

- The mapped type `{ [id in Enum]: CompanionActionDefinition | undefined }` is gone. `CompanionActionDefinitions<Schema>` already enforces one entry per key, and an entry may still be `undefined` or `false` to hide it conditionally.
- The `as string` / `as number` casts are gone, because `action.options` is typed from the schema.
- `parseVariablesInString` is gone (see B.3).

**Casts vs. null guards:**

| v1 code | v2 |
|---|---|
| `action.options.x as string`, `String(action.options.x)`, `Number(action.options.x)` | Remove |
| `String(action.options.title ?? '')` where the key may be missing in saved buttons | Keep the guard and drop the conversion: `(action.options.title ?? '').trim()` |
| `action.options.bus ?? MUTE_MAIN` for an option added after release | Keep it as is |

### B.2 Shared options, option factories and definition helpers need literal ids

v1 modules kept reusable fields typed with wide field types, e.g. `options.userName: CompanionInputFieldTextInput`. In v2 the `options` array only accepts fields whose `id` is one of the schema's keys. A plain `string` id fails with `TS2322 … not assignable to type 'SomeCompanionActionInputField<"userName">'`.

| v1 pattern | v2 fix |
|---|---|
| Shared constant `userName: CompanionInputFieldTextInput` | `CompanionInputFieldTextInput<'userName'>`, or `satisfies CompanionInputFieldTextInput<'userName'>` inside the existing map |
| Factory `deviceDropdown(id: string, …): CompanionInputFieldDropdown` | Generic key: `deviceDropdown<TKey extends string>(id: TKey, …): CompanionInputFieldDropdown<TKey>` |
| Factory returning several fields | Return `Field<'useVariable' \| 'id' \| 'idVariable'>[]` and export the matching option-values type (`DeviceIdOptions`) for the schemas |
| Helper returning a whole definition (`const simple = (…): CompanionActionDefinition => …`) | Give it the schema-entry generic: `CompanionActionDefinition<{ options: Record<string, never> }>` on 2.1 (`<Record<string, never>>` on 2.0.x); `CompanionFeedbackDefinition<{ type: 'boolean'; options: … }>` |

Full examples, and how to handle the v1 "Use variable" checkbox idiom, are in **`references/shared-options.md`**.

### B.3 `parseVariablesInString` removal semantics

v2 removed `parseVariablesInString` from both the instance and the callback `context`. Companion now parses for you:

| Field | What the callback receives |
|---|---|
| `textinput` with `useVariables: true` | The string with all `$(...)` variables already substituted |
| Any field the user toggled into **expression** mode | The computed value, coerced and validated against the field (number clamped or `asInteger`-rounded, dropdown checked against `choices`) |
| Any other field | The literal value |

Procedure for each call site:

1. **Option-backed string** (`await instance.parseVariablesInString(action.options.x as string)`): delete the call, use `action.options.x` directly, and make sure the field has `useVariables: true`.
2. **Number parsed from a variable-enabled text field** (`parseInt(await instance.parseVariablesInString(...))`): convert the field to `type: 'number'` and read `action.options.x` as a number. Ship the `FixupNumericOrVariablesValueToExpressions` upgrade script from **companion-v1-to-v2-expression-upgrades** for it.
3. **String assembled at runtime and then parsed** (a template stored in config or built in code): there is **no v2 replacement API**. Move the variable-bearing part into an action option with `useVariables: true` so Companion parses it before the callback runs. Don't write your own `$(...)` parser.
4. **Feedback `context.parseVariablesInString`**: same as 1 and 3. The callback becomes synchronous where possible:
   ```ts
   // Before (v1)
   callback: async (feedback, context) => {
   	const name = await context.parseVariablesInString(feedback.options.name as string)
   	return isSelected(name)
   }
   // After (v2)
   callback: (feedback) => isSelected(feedback.options.name)
   ```
5. A field whose value must stay literal and never become an expression gets `disableAutoExpression: true`. Example: an on/off/toggle choice that an `isVisibleExpression` depends on.

### B.4 Other action changes

| v1 | v2 |
|---|---|
| `optionsToIgnoreForSubscribe: ['label']` | `optionsToMonitorForSubscribe: ['channel']`, an **allowlist** of the options that matter |
| `subscribe` without `optionsToMonitorForSubscribe` | **2.1+ (Companion 5.0+)**: TS error. List the options the subscription depends on. |
| `learn` returns all options `{ ...action.options, level: x }` | Return **only** the learned keys `{ level: x }` so user expressions on the other fields survive |
| `context.setCustomVariableValue(name, value)` | Still compiles but is deprecated. **2.1+ (Companion 5.0+)**: use `hasResult: true` and return the value (see below and **companion-v1-to-v2-expression-upgrades**) |
| Callback ignores cancellation | **2.1+ (Companion 5.0+)**: `context.signal` is optional to honour. Pass it to `fetch` or other long-running work. |
| `required: true` on `textinput` | `minLength: 1` |
| `isVisible: (opts) => opts.mode === 'x'` | `isVisibleExpression: '$(options:mode) == "x"'`. The referenced field needs `disableAutoExpression: true`. |
| **Existing** `isVisibleExpression` (allowed since v1.12) | Still valid, but in actions and feedbacks every field it references now needs `disableAutoExpression: true`. Find them with `grep -rn "isVisibleExpression" src`. Config fields have no expression mode, so they are exempt. |
| `InputValue` type imports | `JsonValue`, or the precise option type from the schema |

Subscribe and learn, as they should look after the migration:

```ts
[ActionIdLevel.setLevel]: {
	name: 'Set level',
	options: [
		{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 },
		{ id: 'level', type: 'number', label: 'Level', default: 0, min: 0, max: 100, range: true, clampValues: true },
	],
	callback: (event) => {
		instance.sendCommand('/level', event.options.channel, event.options.level)
	},
	learn: () => ({ level: instance.state.level }),
},
[ActionIdLevel.watchChannel]: {
	name: 'Watch channel',
	options: [
		{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 },
		{ id: 'label', type: 'textinput', label: 'Label', default: '' },
	],
	optionsToMonitorForSubscribe: ['channel'],
	subscribe: (action) => {
		instance.sendCommand('/subscribe', action.options.channel)
	},
	unsubscribe: (action) => {
		instance.sendCommand('/unsubscribe', action.options.channel)
	},
	callback: () => {},
},
```

> **2.1+ (Companion 5.0+)**: an action that returns a value declares `result` in its schema and sets `hasResult: true`:
>
> ```ts
> [ActionIdLevel.readLevel]: { options: { channel: number }; result: number }
> // ...
> [ActionIdLevel.readLevel]: {
> 	name: 'Read level',
> 	options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
> 	hasResult: true,
> 	callback: async () => instance.state.level,
> },
> ```

### B.5 Actions aggregator

```ts
// Before (v1) — actions.ts
export enum ActionId {} // empty "anchor" enum, only used for the union below and in preset-utils
export function GetActions(instance: InstanceBaseExt<ZoomConfig>): CompanionActionDefinitions {
	const actionsGroups: { [id in ActionIdGroups]: CompanionActionDefinition | undefined } = GetActionsGroups(instance)
	// ...
	const actions: { [id in ActionId | ActionIdGroups /* ... */]: CompanionActionDefinition | undefined } = {
		...actionsGroups,
		// ...
	}
	return actions
}
// main: this.setActionDefinitions(GetActions(this))

// After (v2) — actions.ts
import type ModuleInstance from './main.js'
import { GetActionsGroups, type ActionsSchemaGroups } from './actions/action-groups.js'
import { GetActionsUserHandRaised, type ActionsSchemaUserHandRaised } from './actions/action-user-hand-raised.js'

export type ActionsSchema = ActionsSchemaGroups & ActionsSchemaUserHandRaised

export function UpdateActions(instance: ModuleInstance): void {
	instance.setActionDefinitions({
		...GetActionsGroups(instance),
		...GetActionsUserHandRaised(instance),
	})
}
```

- The union of every `ActionId*` enum becomes an **intersection** (`&`) of every `ActionsSchema*`. `ModuleSchema.actions` points to the aggregate type.
- Delete empty "anchor" enums such as `export enum ActionId {}`. Their only other consumer, the `preset-utils` id unions, is deleted in Phase 5. Until then those imports fail, which is expected.
- If other code still calls `GetActions(this)` (e.g. a definitions-refresh method), switch it to `UpdateActions(this)`.
- Inline "one-off" actions in the aggregator move into their own category file, or into an `action-misc.ts` with its own enum and schema.

---

## Part C — Feedbacks

### C.1 Schema and factory

Feedback schema entries add `type`:

```ts
import { combineRgb, type CompanionFeedbackDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'
import { options } from '../utils.js'

export enum FeedbackIdUser {
	userSelected = 'user_selected',
	userStatusImage = 'user_status_image',
}

export type FeedbacksSchemaUser = {
	[FeedbackIdUser.userSelected]: { type: 'boolean'; options: { userName: string } }
	[FeedbackIdUser.userStatusImage]: { type: 'advanced'; options: { userName: string; showIcon: boolean } }
}

export function GetFeedbacksUser(instance: ModuleInstance): CompanionFeedbackDefinitions<FeedbacksSchemaUser> {
	return {
		[FeedbackIdUser.userSelected]: {
			type: 'boolean',
			name: 'User selected',
			defaultStyle: { bgcolor: combineRgb(255, 0, 0) },
			options: [options.userName],
			// v1: async (feedback, context) => { const name = await context.parseVariablesInString(...) }
			callback: (feedback) => instance.state.lastCommand === feedback.options.userName,
		},
		[FeedbackIdUser.userStatusImage]: {
			type: 'advanced',
			name: 'User status image',
			options: [options.userName, { id: 'showIcon', type: 'checkbox', label: 'Show icon', default: true }],
			affectedProperties: ['imageBuffer', 'text'], // 2.1+ (Companion 5.0+): required key; delete this line on 2.0.x
			callback: (feedback) => {
				const buffer = Buffer.alloc(72 * 72 * 4)
				return feedback.options.showIcon
					? {
							imageBuffer: buffer.toString('base64'),
							imageBufferEncoding: { pixelFormat: 'RGBA' },
							text: feedback.options.userName,
						}
					: {}
			},
			unsubscribe: (feedback) => {
				instance.log('debug', `feedback ${feedback.id} removed`)
			},
		},
	}
}
```

`imageBufferEncoding` and `imageBufferPosition` are optional. Set the encoding when the buffer isn't Companion's default pixel format.

A single-file v1 `feedback.ts` (one `FeedbackId` enum, one `GetFeedbacks`) can stay a single file: add one `FeedbacksSchema` keyed by the enum. Splitting it into `src/feedbacks/feedback-{category}.ts` is optional. If you split, follow **companion-v2-feedback-file-pattern** and compose with `&`. Delete empty anchor enums (`export enum FeedbackId {}`) as in B.5.

### C.2 Feedback transforms

| v1 | v2 |
|---|---|
| `subscribe: (fb) => startPolling(fb)` | Removed. `callback` runs when the feedback is added **and** on every options change. Move setup into `callback` and use `feedback.previousOptions` to detect changes. Keep `unsubscribe` for cleanup (it runs only on delete or disable). |
| `imageBuffer: buffer` (a `Buffer`) | `imageBuffer: buffer.toString('base64')` |
| Advanced feedback with no `affectedProperties` | **2.1+ (Companion 5.0+)**: required key. List the style keys you return (`'text' \| 'size' \| 'color' \| 'bgcolor' \| 'alignment' \| 'pngalignment' \| 'png64' \| 'imageBuffer'`), or set it to `undefined`. On 2.0.x the key does not exist; leave it out. |
| `async (feedback, context)` + `context.parseVariablesInString` | See B.3. Usually becomes a synchronous `(feedback) => ...` |
| Dropdown option compared via `feedback.options.type as number` | Schema type `type: feedbackType` (the numeric enum), no cast |
| `InputValue` parameters in helpers (`feedbackResults(type: InputValue \| undefined, ...)`) | The exact schema type (`feedbackType`), or `JsonValue` |

> **2.1+ (Companion 5.0+)**: `context.signal` aborts when a recheck is queued while the feedback is still running. Use it for slow device queries.

### C.3 Triggering re-checks

| v1 | v2 |
|---|---|
| `instance.checkFeedbacks()` (all) | `instance.checkAllFeedbacks()` |
| `instance.checkFeedbacks('user_selected', 'group_based')` | `instance.checkFeedbacks(FeedbackIdUser.userSelected, FeedbackIdGroup.groupBased)`: enum members, because a raw string is a TS error with an enum-keyed schema |
| `instance.checkFeedbacks(...changedIds)` with a runtime `string[]` / `Set<string>` | Type the collection with the union of every feedback enum, and split off the first element (the signature requires at least one id): see below |

```ts
// feedbacks.ts — export the id union next to the schema, so code outside feedbacks/ can type its id lists
export type AnyFeedbackId = FeedbackIdUser | FeedbackIdGroup /* | ... every FeedbackId* enum */

// wherever ids are collected at runtime
export function recheck(instance: ModuleInstance, changed: Set<AnyFeedbackId>): void {
	const [first, ...rest] = changed
	if (first !== undefined) instance.checkFeedbacks(first, ...rest)
}
```

`checkFeedbacksById(...)` is unchanged.

---

## Part D — Variables

| v1 | v2 |
|---|---|
| `setVariableDefinitions([{ variableId, name }, ...])` | `setVariableDefinitions({ [variableId]: { name } })`, typed `CompanionVariableDefinitions<VariablesSchema>` |
| No variable typing | `export type VariablesSchema = { … }`, referenced from `ModuleSchema.variables` |
| `` `CallersInGroup${i}` `` ids built in a loop | Template-literal key in the schema: `` [k: `CallersInGroup${number}`]: string `` |
| `setVariableValues(values: CompanionVariableValues)` | `setVariableValues(Partial<VariablesSchema>)`. Values can be any JSON, and `undefined` unsets one. |
| Helpers mutating a shared `CompanionVariableValues` bag | Type the bag `Partial<VariablesSchema>` |

Procedure:

1. Add every static `variableId` to `VariablesSchema` with its value type.
2. Add template-literal keys for each dynamic family.
3. Convert array or `Set` building into `definitions[id] = { name }`. Keep variable ids **byte-identical**, because users reference them as `$(module:id)`. Ids may only contain `[a-zA-Z0-9_-]`.
4. Keep the existing function names (`initVariableDefinitions`, …) if tests or other code call them.

For a literal before/after conversion, and for **catalog- or list-driven** modules (optional static keys, one shared value type for union-key writes, template literals derived from const tables), see **`references/variables.md`**. The API details are in **companion-v2-variable-definition** and **companion-v2-variable-set-value**.

---

## Part E — Config

| v1 | v2 |
|---|---|
| `interface XConfig` | `type XConfig = {...}` (A.1, done in Phase 2) |
| `isVisible: (options) => options['enableSocialStream'] === true` | `isVisibleExpression: '$(options:enableSocialStream)'` |
| `isVisible: (o) => o.mode == 1` | `isVisibleExpression: '$(options:mode) == 1'` |
| `required: true` on `textinput` | `minLength: 1` |
| Passwords and API keys in plain `textinput` | Optional: switch to `type: 'secret-text'`. The value then lives in a separate `secrets` object, so add a `ModuleSecrets` type and an upgrade script that moves the value (`updatedSecrets`). See **companion-v2-config**. |
| `this.saveConfig(config)` | Same call. With secrets: `this.saveConfig(config, secrets)` |
| Duplicate field ids | **2.1+ (Companion 5.0+)**: duplicates are rejected and dropped at runtime. Make the ids unique. |

Part E may be a no-op. That happens when the module already uses `isVisibleExpression`, has no `required`, and keeps no secrets.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Renaming enum string values while adding schemas | Keep the ids exactly. They are persisted in users' configs. |
| Keeping `as string` casts "to be safe" | Remove them. If TS complains, fix the schema. |
| Removing `?? default` guards together with the casts | Keep guards for keys that saved buttons may lack (later-added options, v1 presets with `options: {}`). Otherwise `.trim()` and similar calls throw at runtime. |
| Shared option or factory typed with a wide `id: string` | Add the literal-id generic (B.2) |
| Helper returning an un-parameterised `CompanionActionDefinition` | Give it the schema-entry generic (B.2) |
| `checkFeedbacks('my_feedback')` with an enum-keyed schema | Pass `FeedbackIdX.member` |
| `checkFeedbacks(...set)` | Split off the first element, and type the set as `AnyFeedbackId` (C.3) |
| Leaving `[x: string]: any` on the instance type | Delete `InstanceBaseExt` and add the missing members to the class |
| An `isVisibleExpression` referencing a field without `disableAutoExpression` | Add `disableAutoExpression: true` to the referenced field |
| Converting a `textinput` to `number` without an upgrade script | Saved string values will fail validation. Add a `FixupNumericOrVariablesValueToExpressions` script. |
| Feedback setup still in `subscribe` | It is never called in v2. Move it into `callback` and use `previousOptions`. |

## Related Skills

- **companion-v1-to-v2-migration**: phase order, tooling, entrypoint, tests
- **companion-v1-to-v2-migrate-presets**: presets
- **companion-v1-to-v2-expression-upgrades**: upgrade scripts for changed fields
- **companion-v2-actions**, **companion-v2-feedbacks**, **companion-v2-variable-definition**, **companion-v2-variable-set-value**, **companion-v2-config**: v2 API references
- **companion-v2-action-file-pattern**, **companion-v2-feedback-file-pattern**: target file layout

## References

- `references/shared-options.md`: shared fields, option factories, definition helpers, the "Use variable" idiom
- `references/variables.md`: literal conversion example, catalog-driven variables
- [API 2.0 changes](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [API 2.1 changes](https://companion.free/for-developers/module-development/api-changes/v2.1)
