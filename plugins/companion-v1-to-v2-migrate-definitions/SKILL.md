---
name: companion-v1-to-v2-migrate-definitions
description: 'Before/after transforms for migrating Companion module actions, feedbacks, variables, config fields, and instance typing from @companion-module/base v1.x to v2 (2.0/2.1). Use when converting InstanceBaseExt or InstanceBase<Config> to a typed ModuleSchema, removing parseVariablesInString, adding per-category action/feedback schema types, fixing checkFeedbacks(), feedback subscribe, isVisible, required, InputValue, or array-form setVariableDefinitions. Does NOT cover presets (use companion-v1-to-v2-migrate-presets) or overall migration order (use companion-v1-to-v2-migration).'
license: MIT
---

# Migrate Definitions (Actions, Feedbacks, Variables, Config) to v2

This skill holds the **code-level transforms** used in Phases 3, 4 and 6 of **companion-v1-to-v2-migration**. Every "After" snippet compiles against `@companion-module/base` 2.1.3. Items marked **2.1+ (Companion 5.0+)** can be skipped when targeting 2.0.

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

**The rule:** in v2, the **schema type is the contract**. Every action and feedback ID maps to a typed `options` object, and Companion delivers those options already parsed, already expression-evaluated and already validated. Delete casts and manual parsing. Don't patch around them.

---

## Part A — Instance Typing

### A.1 Config: `interface` → `type`

v2 requires the config to satisfy `JsonObject`. An `interface` has no implicit index signature, so it fails with `TS2344: Type 'ModuleSchema' does not satisfy the constraint 'InstanceTypes'`.

```ts
// Before (v1)
export interface ZoomConfig {
	host: string
	tx_port: number
	enableSocialStream: boolean
	socialStreamChatTypeToSend: string[]
}

// After (v2)
export type ModuleConfig = {
	host: string
	tx_port: number
	enableSocialStream: boolean
	socialStreamChatTypeToSend: string[]
	label?: string // optional fields are fine
}
```

Every value must be JSON-safe: no `Date`, `Map`, class instances or functions. You can keep the old type name (e.g. `ZoomConfig`) to keep the diff small.

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

1. Replace every `InstanceBaseExt<XConfig>` parameter type with `ModuleInstance`, and add `import type ModuleInstance from '../main.js'` (or `./main.js` for files in `src/`).
2. Delete the `InstanceBaseExt` interface from `utils.ts`.
3. For every property the interface listed, or that callbacks reach through `[x: string]: any` (e.g. `instance.ZoomClientDataObj`, `instance.OSC`, `instance.sendCommand`), make sure it is a **real public field or method on the class**. `[x: string]: any` used to hide typos, and now `tsc` will list each missing member.
   ```ts
   export default class ModuleInstance extends InstanceBase<ModuleSchema> {
   	config!: ModuleConfig
   	public ZoomClientDataObj: ZoomClientDataObjInterface = { /* ...defaults... */ }
   	public OSC: OSC | null = null
   	state = { playing: false, level: 0, lastCommand: '' }
   	// ...
   }
   ```
4. Type `OSC: any` style fields properly if you can, or leave them `any` for now and add a TODO. Don't block the migration on it.

---

## Part B — Actions

### B.1 Add a schema type per category file

For each `src/actions/action-{category}.ts`:

1. Keep the existing `enum ActionId{Category}` **unchanged**. The string values are the saved action IDs, so renaming them breaks users' buttons.
2. Add `export type ActionsSchema{Category}`, with one key per enum member, mapping to `{ options: {...} }`.
3. Derive each option's TS type from its input field:

| Field `type` | Option TS type |
|---|---|
| `textinput` | `string` |
| `number` | `number` |
| `checkbox` | `boolean` |
| `dropdown` | the choice ID type (`string`, `number`, a string-literal union, or the numeric `enum` used for the IDs) |
| `multidropdown` | `string[]` / `number[]` (choice ID type, as an array) |
| `colorpicker` | `number` (or `string` when `returnType: 'string'`) |
| `custom-variable` | `string` |
| `static-text` | **omit**; it carries no value |
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
		// ...
	}
	return actions
}
```

**After (v2):**

```ts
import type { CompanionActionDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'
import { userNameOption, modeOption } from './shared-options.js'

export enum ActionIdUserHandRaised {
	raiseHand = 'raiseHand',
	lowerHand = 'lowerHand',
	toggleHand = 'toggleHand',
}

export type ActionsSchemaUserHandRaised = {
	[ActionIdUserHandRaised.raiseHand]: { options: { userName: string } }
	[ActionIdUserHandRaised.lowerHand]: { options: { userName: string } }
	[ActionIdUserHandRaised.toggleHand]: { options: { userName: string; mode: string } }
}

export function GetActionsUserHandRaised(instance: ModuleInstance): CompanionActionDefinitions<ActionsSchemaUserHandRaised> {
	return {
		[ActionIdUserHandRaised.raiseHand]: {
			name: 'Raise Hand',
			options: [userNameOption],
			callback: async (action): Promise<void> => {
				// v2: action.options.userName is already a parsed string — no parseVariablesInString, no cast
				instance.sendCommand('/raiseHand', action.options.userName)
			},
		},
		[ActionIdUserHandRaised.lowerHand]: {
			name: 'Lower Hand',
			options: [userNameOption],
			callback: async (action): Promise<void> => {
				instance.sendCommand('/lowerHand', action.options.userName)
			},
		},
		[ActionIdUserHandRaised.toggleHand]: {
			name: 'Toggle Hand',
			options: [userNameOption, modeOption],
			callback: async (action): Promise<void> => {
				instance.sendCommand('/toggleHand', action.options.userName, action.options.mode)
			},
		},
	}
}
```

What changed:
- The mapped type `{ [id in Enum]: CompanionActionDefinition | undefined }` is gone. `CompanionActionDefinitions<Schema>` already enforces one entry per key, and each entry may still be `undefined` or `false` to hide it conditionally.
- The `as string` / `as number` casts are gone, because `action.options` is typed from the schema.
- `parseVariablesInString` is gone (see B.3).

### B.2 Shared option constants need literal IDs

v1 modules often kept reusable fields in a map typed with wide field types, e.g. `options.userName: CompanionInputFieldTextInput`. In v2 the `options` array is typed `SomeCompanionActionInputField<'userName' | ...>`, so a field whose `id` is typed as plain `string` fails:

```
TS2322: Type 'CompanionInputFieldTextInput<string>' is not assignable to type 'SomeCompanionActionInputField<"userName">'.
```

Give every shared field its literal ID through the field type's generic. Use either a standalone constant per field:

```ts
import type {
	CompanionInputFieldDropdown,
	CompanionInputFieldTextInput,
	CompanionInputFieldNumber,
} from '@companion-module/base'

// v2: give shared option constants a literal id type so they fit any schema that declares that key
export const userNameOption: CompanionInputFieldTextInput<'userName'> = {
	id: 'userName',
	type: 'textinput',
	label: 'User name',
	default: '',
	useVariables: true,
}

export const positionOption: CompanionInputFieldNumber<'position'> = {
	id: 'position',
	type: 'number',
	label: 'Position',
	default: 1,
	min: 1,
	max: 49,
	asInteger: true,
}

export const modeOption: CompanionInputFieldDropdown<'mode'> = {
	id: 'mode',
	type: 'dropdown',
	label: 'Mode',
	choices: [
		{ id: 'auto', label: 'Auto' },
		{ id: 'manual', label: 'Manual' },
	],
	default: 'auto',
	disableAutoExpression: true,
}
```

or keep the existing `options` map and add `satisfies` with the literal ID on each entry. This keeps call sites like `options.userName` unchanged:

```ts
export const options = {
	userName: {
		id: 'userName',
		type: 'textinput',
		label: 'User name',
		default: '',
		useVariables: true,
	} satisfies CompanionInputFieldTextInput<'userName'>,
	feedbackKind: {
		id: 'type',
		type: 'dropdown',
		label: 'Type of feedback',
		default: feedbackType.selected,
		choices: [
			{ id: feedbackType.selected, label: 'Selected' },
			{ id: feedbackType.micLive, label: 'Mic Live' },
		],
	} satisfies CompanionInputFieldDropdown<'type', feedbackType>,
}
```

Delete the old `interface Options { userName: EnforceDefault<CompanionInputFieldTextInput, string> ... }` declaration.

### B.3 `parseVariablesInString` removal semantics

v2 removed `parseVariablesInString` from both the instance and the callback `context`. Companion now parses for you:

| Field | What the callback receives |
|---|---|
| `textinput` with `useVariables: true` | The string with all `$(...)` variables already substituted |
| Any field the user toggled into **expression** mode | The computed value, coerced and validated against the field (number clamped / `asInteger` rounded, dropdown checked against `choices`) |
| Any other field | The literal value |

Procedure for each call site:

1. **Option-backed string** (`await instance.parseVariablesInString(action.options.x as string)`): delete the call, use `action.options.x` directly, and make sure the field has `useVariables: true`.
2. **Number parsed from a variable-enabled text field** (`parseInt(await instance.parseVariablesInString(...))`): convert the field to `type: 'number'` and read `action.options.x` as a number. Ship the `FixupNumericOrVariablesValueToExpressions` upgrade script from **companion-v1-to-v2-expression-upgrades** for it.
3. **String assembled at runtime and then parsed** (e.g. a template stored in config or built in code): there is **no v2 replacement API**. Move the variable-bearing part into an action option with `useVariables: true`, so Companion parses it before the callback runs. Don't write your own `$(...)` parser.
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
5. A field whose value must stay literal and never become an expression (e.g. an on/off/toggle choice that `isVisibleExpression` depends on) gets `disableAutoExpression: true`.

### B.4 Other action changes

| v1 | v2 |
|---|---|
| `optionsToIgnoreForSubscribe: ['label']` | `optionsToMonitorForSubscribe: ['channel']`: an **allowlist** of the options that matter |
| `subscribe` without `optionsToMonitorForSubscribe` | **2.1+ (Companion 5.0+)**: TS error. List the options the subscription depends on. |
| `learn` returns all options `{ ...action.options, level: x }` | Return **only** learned keys, `{ level: x }`, so user expressions on the other fields survive |
| `context.setCustomVariableValue(name, value)` | Still compiles but is deprecated. **2.1+ (Companion 5.0+)**: use `hasResult: true` and return the value (see the example below and **companion-v1-to-v2-expression-upgrades**) |
| Callback ignores cancellation | **2.1+ (Companion 5.0+)**: `context.signal` is optional to honour; pass it to `fetch` or long-running work |
| `required: true` on `textinput` | `minLength: 1` |
| `isVisible: (opts) => opts.mode === 'x'` | `isVisibleExpression: "$(options:mode) == 'x'"`, and the referenced field needs `disableAutoExpression: true` |
| `InputValue` type imports | `JsonValue` (or the precise option type from the schema) |

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
export function GetActions(instance: InstanceBaseExt<ZoomConfig>): CompanionActionDefinitions {
	const actionsGroups: { [id in ActionIdGroups]: CompanionActionDefinition | undefined } = GetActionsGroups(instance)
	// ...
	const actions: { [id in ActionIdGroups | ActionIdGallery /* ... */]: CompanionActionDefinition | undefined } = {
		...actionsGroups,
		// ...
	}
	return actions
}
// main: this.setActionDefinitions(GetActions(this))

// After (v2) — actions.ts
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

- The union of every `ActionId*` enum becomes an **intersection** (`&`) of every `ActionsSchema*`. The aggregator type is what `ModuleSchema.actions` points to.
- If other code still calls `GetActions(this)` (e.g. a `updateDefinitionsForActionsFeedbacksAndPresets()` refresh), switch it to `UpdateActions(this)`.
- Inline "one-off" actions in the aggregator move into their own category file, or into an `action-misc.ts` with its own enum and schema.

---

## Part C — Feedbacks

### C.1 Schema and factory

Feedback schema entries add `type`:

```ts
import { combineRgb, type CompanionFeedbackDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'
import { userNameOption } from './shared-options.js'

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
			options: [userNameOption],
			// v1: async (feedback, context) => { const name = await context.parseVariablesInString(...) }
			callback: (feedback) => instance.state.lastCommand === feedback.options.userName,
		},
		[FeedbackIdUser.userStatusImage]: {
			type: 'advanced',
			name: 'User status image',
			options: [userNameOption, { id: 'showIcon', type: 'checkbox', label: 'Show icon', default: true }],
			affectedProperties: ['imageBuffer', 'text'],
			callback: (feedback) => {
				const buffer = Buffer.alloc(72 * 72 * 4)
				return feedback.options.showIcon
					? { imageBuffer: buffer.toString('base64'), text: feedback.options.userName }
					: {}
			},
			unsubscribe: (feedback) => {
				instance.log('debug', `feedback ${feedback.id} removed`)
			},
		},
	}
}
```

A single-file v1 `feedback.ts` (one `FeedbackId` enum, one `GetFeedbacks`) can stay as a single file: add one `FeedbacksSchema` keyed by the enum. Splitting into `src/feedbacks/feedback-{category}.ts` is optional. If you do split, follow **companion-v2-feedback-file-pattern** and compose the schemas with `&` in `feedbacks.ts`.

### C.2 Feedback transforms

| v1 | v2 |
|---|---|
| `subscribe: (fb) => startPolling(fb)` | Removed. `callback` runs when the feedback is added **and** on every options change. Move setup into `callback`, using `feedback.previousOptions` to detect changes. Keep `unsubscribe` for cleanup (it runs only on delete or disable). |
| `imageBuffer: buffer` (a `Buffer`) | `imageBuffer: buffer.toString('base64')` |
| Advanced feedback with no `affectedProperties` | **2.1+ (Companion 5.0+)**: required key. List the style keys you return (`'text' \| 'size' \| 'color' \| 'bgcolor' \| 'alignment' \| 'pngalignment' \| 'png64' \| 'imageBuffer'`), or set it to `undefined`. |
| `async (feedback, context)` + `context.parseVariablesInString` | See B.3. Usually becomes a synchronous `(feedback) => ...` |
| Dropdown option compared via `feedback.options.type as number` | Schema type `type: feedbackType` (the numeric enum), with no cast |
| `InputValue` parameters in helpers (`feedbackResults(type: InputValue \| undefined, ...)`) | Use the exact schema type (`feedbackType`), or `JsonValue` |
| Feedback that only reads cached state | No change in logic, just remove `async` and the casts |

> **2.1+ (Companion 5.0+)**: `context.signal` aborts when a recheck is queued while the feedback is still running. Use it for slow device queries.

### C.3 Triggering re-checks

```ts
// Before (v1)
instance.checkFeedbacks()                               // all
instance.checkFeedbacks('user_selected', 'group_based') // by id string

// After (v2)
instance.checkAllFeedbacks()
instance.checkFeedbacks(FeedbackIdUser.userSelected, FeedbackIdGroup.groupBased)
```

`checkFeedbacks` now requires at least one argument, typed `StringKeys<FeedbacksSchema>`. With an enum-keyed schema, a raw string such as `'user_selected'` is a TS error, so always pass the enum member. `checkFeedbacksById(...)` is unchanged.

---

## Part D — Variables

### D.1 Definitions: array → object, plus a `VariablesSchema`

```ts
// Before (v1)
const variables: CompanionVariableDefinition[] = [
	{ variableId: 'zoomVersion', name: 'Zoom version' },
	{ variableId: 'callStatus', name: 'Call status' },
]
for (let i = 1; i <= groups; i++) variables.push({ variableId: `CallersInGroup${i}`, name: `Callers in group ${i}` })
instance.setVariableDefinitions(variables)

// After (v2)
import type { CompanionVariableDefinitions } from '@companion-module/base'
import type ModuleInstance from './main.js'

const CHANNEL_COUNT = 4

export type VariablesSchema = {
	last_command: string
	connection_state: string
	[channelLevel: `channel_${number}_level`]: number
}

export function UpdateVariableDefinitions(instance: ModuleInstance): void {
	const definitions: CompanionVariableDefinitions<VariablesSchema> = {
		last_command: { name: 'Last command sent' },
		connection_state: { name: 'Connection state' },
	}
	for (let ch = 1; ch <= CHANNEL_COUNT; ch++) {
		definitions[`channel_${ch}_level`] = { name: `Channel ${ch} level` }
	}
	instance.setVariableDefinitions(definitions)
}
```

Procedure:

1. List every static `variableId`, and add each to `VariablesSchema` with its value type (`string`, `number`, `boolean`, or any JSON).
2. For dynamic families (`Group${i}Position${p}`, `Participant001`, per-user IDs), add **template-literal index signatures** such as `` [k: `Group${number}Position${number}`]: string ``. If a family has no fixed shape, use `[k: string]: string | number | undefined`, which keeps the code compiling but gives up typo checking for those keys.
3. Convert the array or `Set` building into object assignment `definitions[id] = { name }`. Keep variable IDs **byte-identical**, because users reference them as `$(module:id)`.
4. IDs may only contain `[a-zA-Z0-9_-]`.

### D.2 Values

`setVariableValues` now accepts `Partial<VariablesSchema>`. Values can be any JSON, and `undefined` unsets a value. Helpers that mutate a shared bag keep working if you type the bag:

```ts
// Before (v1)
const variables: CompanionVariableValues = {}
updateCallStatus(instance, variables)
instance.setVariableValues(variables)

// After (v2)
const variables: Partial<VariablesSchema> = {}
updateCallStatus(instance, variables)
instance.setVariableValues(variables)
```

`instance.getVariableValue('id')` is typed from the schema. Details are in **companion-v2-variable-set-value**.

---

## Part E — Config

| v1 | v2 |
|---|---|
| `interface XConfig` | `type ModuleConfig = {...}` (A.1) |
| `isVisible: (options) => options['enableSocialStream'] === true` | `isVisibleExpression: '$(options:enableSocialStream)'` |
| `isVisible: (o) => o.mode == 1` | `isVisibleExpression: '$(options:mode) == 1'` |
| `required: true` on `textinput` | `minLength: 1` |
| Passwords and API keys in plain `textinput` | Optional: `type: 'secret-text'`. The value goes into a separate `secrets` object, so set `ModuleSchema.secrets` to a `type ModuleSecrets = {...}` and handle it in `init` / `configUpdated` (see **companion-v2-config**). This needs an upgrade script that moves the value with `updatedSecrets`. |
| `this.saveConfig(config)` | Same call. With secrets: `this.saveConfig(config, secrets)` |
| Duplicate field IDs | **2.1+ (Companion 5.0+)**: duplicates are rejected and dropped at runtime, so make the IDs unique |

```ts
{
	type: 'number',
	id: 'pollInterval',
	label: 'Poll interval (ms)',
	width: 6,
	min: 100,
	max: 60000,
	default: 1000,
	isVisibleExpression: '$(options:enablePolling)',
},
```

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Renaming enum string values while adding schemas | Keep the IDs exactly. They are persisted in users' configs. |
| Keeping `as string` casts "to be safe" | Remove them. If TS complains, the schema is wrong, so fix the schema. |
| Shared option typed `CompanionInputFieldTextInput` (no generic) | Add the literal-ID generic: `CompanionInputFieldTextInput<'userName'>` |
| `checkFeedbacks('my_feedback')` with an enum-keyed schema | Pass `FeedbackIdX.member` |
| Leaving `[x: string]: any` on the instance type | Delete `InstanceBaseExt`, and add the missing members to the class |
| Converting a `textinput` to `number` without an upgrade script | Saved string values will fail validation. Add a `FixupNumericOrVariablesValueToExpressions` script. |
| Feedback setup still in `subscribe` | It's never called in v2. Move it into `callback` and use `previousOptions`. |

## Related Skills

- **companion-v1-to-v2-migration** — phase order, tooling, entrypoint, tests
- **companion-v1-to-v2-migrate-presets** — presets
- **companion-v1-to-v2-expression-upgrades** — upgrade scripts for changed fields
- **companion-v2-actions**, **companion-v2-feedbacks**, **companion-v2-variable-definition**, **companion-v2-variable-set-value**, **companion-v2-config** — v2 API references
- **companion-v2-action-file-pattern**, **companion-v2-feedback-file-pattern** — target file layout

## References

- [API 2.0 changes](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [API 2.1 changes](https://companion.free/for-developers/module-development/api-changes/v2.1)
