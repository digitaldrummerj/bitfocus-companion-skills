---
name: companion-v2-actions
description: '(@companion-module/base v2.x) Reference for Companion v2 action definitions: typed action schemas, CompanionActionDefinitions, automatic expression/variable parsing of options, subscribe/unsubscribe with optionsToMonitorForSubscribe, learn, and 2.1 abort signals and action results. Use when asked to add or fix an action, wire a button command, define action options, or understand callback/subscribe/learn behaviour in a v2 module. Does NOT apply to v1 modules (base 1.x) — use companion-actions; for the split-file wiring use companion-v2-action-file-pattern; for upgrading v1 code use companion-v1-to-v2-migrate-definitions.'
license: MIT
---

# Companion v2 Actions Skill

The API reference for **actions** in `@companion-module/base` **v2.x**. The file layout (one file per category plus an aggregator) is covered in **`companion-v2-action-file-pattern`**.

> **API level:** examples target base ~2.1.x. Sections marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.

## When to Use This Skill

- Defining an action and its options in a v2 module
- Typing action options with a schema, so `event.options.x` needs no casts
- Choosing option types and expression behaviour (`useVariables`, `disableAutoExpression`, …)
- Using `subscribe` / `unsubscribe` / `learn`
- Returning a value from an action, or honouring cancellation (2.1)

---

## Key API Types

### Action schema

Every action has a schema entry that describes its options (and, from 2.1, its result):

```typescript
export type ActionsSchemaLevel = {
	[ActionIdLevel.setLevel]: { options: { channel: number; level: number } }
	[ActionIdLevel.readLevel]: { options: { channel: number }; result: number } // 2.1+
	[ActionIdLevel.watchChannel]: { options: { channel: number; label: string } }
}
```

- An action without options uses `{ options: Record<string, never> }`.
- Option value types: `number`, `string`, `boolean`, `string[]` / `number[]` (multidropdown), or any `JsonValue`.
- The schema and the `options: [...]` array are **not** cross-checked for types. Keep each `id` and its value type in step by hand. A field id that is missing from the schema *is* a compile error, because `id` is typed as `keyof options`.

### `CompanionActionDefinitions<Schema>`

```typescript
export function GetActionsLevel(instance: ModuleInstance): CompanionActionDefinitions<ActionsSchemaLevel> {
	return { /* one entry per schema key */ }
}
```

`setActionDefinitions(...)` on `InstanceBase<ModuleSchema>` checks the merged object against `ModuleSchema['actions']`. An entry may be `undefined` or `false` to hide an action conditionally.

### Definition fields

| Field | Notes |
|---|---|
| `name` | Shown in the UI |
| `sortName?` | Overrides the sort order without changing the visible name |
| `description?` | Help text |
| `options` | Input fields, whose `id`s must be keys of the schema options |
| `callback(event, context)` | Runs the action. `event.options` is typed **and already parsed**: variables and expressions are resolved |
| `learn?(event, context)` | Return **only** the learned options, e.g. `{ level: 42 }` |
| `learnTimeout?` | Milliseconds (default 5000) |
| `subscribe?` / `unsubscribe?` | Lifecycle hooks for actions placed on buttons |
| `optionsToMonitorForSubscribe` | Which options re-trigger subscribe/unsubscribe |
| `skipUnsubscribeOnOptionsChange?` | Only call unsubscribe on delete/disable |
| `hasResult: true` | **2.1+** — the callback returns the schema `result` |

### `CompanionActionEvent`

`event.options` (typed), `event.id`, `event.controlId`, `event.actionId`, `event.surfaceId`.

---

## Patterns & Examples

### Basic action with typed options

```typescript
[ActionIdTransport.gotoCue]: {
	name: 'Go to cue',
	options: [
		{ id: 'cue', type: 'number', label: 'Cue', default: 1, min: 1, max: 999, asInteger: true },
		{ id: 'name', type: 'textinput', label: 'Name', default: '', useVariables: true },
	],
	callback: async (event) => {
		instance.sendCommand('/cue', event.options.cue, event.options.name)
	},
},
```

No `as number`, and no `parseVariablesInString`. It no longer exists in v2.

### Automatic expression and variable parsing

Companion resolves option values **before** your callback runs:

| Field setting | Behaviour |
|---|---|
| `textinput` with `useVariables: true` | `$(conn:var)` references are substituted into the string |
| Any field without `disableAutoExpression: true` | The user can switch the field into **expression mode**. The computed value is validated against the field |
| `number` + expression | Coerced to a number. With `clampValues: true` it is clamped to min/max; otherwise out-of-range values fail validation. `asInteger: true` rounds first |
| `dropdown` + expression | Must equal a valid choice id, unless `allowCustom: true` |
| `allowInvalidValues: true` | Values that fail validation are passed through for you to handle |
| `expressionDescription` | Hint text shown under the expression input |

If validation fails and can't be corrected, Companion **skips the action**, as if it were disabled.

```typescript
[ActionIdMixer.muteChannel]: {
	name: 'Mute channel',
	sortName: 'Mixer: mute channel',
	description: 'Mute, unmute or toggle a mixer channel',
	options: [
		{
			id: 'channel',
			type: 'number',
			label: 'Channel',
			default: 1,
			min: 1,
			max: 64,
			asInteger: true,
			clampValues: true,
		},
		{
			id: 'mute',
			type: 'dropdown',
			label: 'State',
			choices: [
				{ id: 'on', label: 'Mute' },
				{ id: 'off', label: 'Unmute' },
				{ id: 'toggle', label: 'Toggle' },
			],
			default: 'toggle',
			disableAutoExpression: true, // an on/off/toggle choice makes no sense as an expression
		},
	],
	callback: (event) => {
		const current = instance.state.muted[event.options.channel] ?? false
		const next = event.options.mute === 'toggle' ? !current : event.options.mute === 'on'
		instance.sendCommand(`/ch/${event.options.channel}/mute`, next)
	},
},
```

Guidelines:

- Use a `number` field for numbers. Don't use a `textinput` just so users can type variables, because expressions now cover that.
- Use **human-friendly dropdown ids** (`'on'`, `'toggle'`), not protocol fragments (`'ch1=0'`). Users have to type them in expressions.
- `isVisibleExpression` (for example `'$(options:mode) == "manual"'`) may only reference fields that have `disableAutoExpression: true`. `isVisible` functions are not supported in v2.
- `textinput` uses `minLength`, not `required`.
- **2.1+:** option `id`s must be unique within an action. Companion drops duplicates and logs a warning.

### Multi-select

```typescript
[ActionIdMixer.muteMany]: {
	name: 'Mute several channels',
	options: [
		{
			id: 'channels',
			type: 'multidropdown',
			label: 'Channels',
			choices: [1, 2, 3, 4].map((ch) => ({ id: ch, label: `Channel ${ch}` })),
			default: [],
			sortSelection: true, // keep selections in choice order
		},
	],
	callback: (event) => {
		for (const ch of event.options.channels) instance.sendCommand(`/ch/${ch}/mute`, true)
	},
},
```

### Learn

```typescript
[ActionIdMixer.setMode]: {
	name: 'Set mode',
	options: [
		{
			id: 'mode',
			type: 'dropdown',
			label: 'Mode',
			choices: [
				{ id: 'auto', label: 'Auto' },
				{ id: 'manual', label: 'Manual' },
			],
			default: 'auto',
			expressionDescription: 'Must evaluate to "auto" or "manual"',
		},
	],
	callback: (event) => {
		instance.sendCommand('/mode', event.options.mode)
	},
	learn: () => ({ mode: instance.state.mode }), // return ONLY learned keys
},
```

Returning every option would overwrite expressions the user typed into the other fields.

### Subscribe / unsubscribe

```typescript
[ActionIdLevel.watchChannel]: {
	name: 'Watch channel',
	options: [
		{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 },
		{ id: 'label', type: 'textinput', label: 'Label', default: '' },
	],
	optionsToMonitorForSubscribe: ['channel'], // changing `label` won't re-subscribe
	subscribe: (action) => {
		instance.sendCommand('/subscribe', action.options.channel)
	},
	unsubscribe: (action) => {
		instance.sendCommand('/unsubscribe', action.options.channel)
	},
	callback: () => {},
},
```

- `optionsToMonitorForSubscribe` is an **allow-list**. It replaces v1's `optionsToIgnoreForSubscribe`. When unset (2.0), every option change re-runs the hooks.
- Call `instance.subscribeActions(ActionIdLevel.watchChannel)` to replay `subscribe` for existing instances, for example after a reconnect.

> **2.1+ (Companion 5.0+)** — when `subscribe` is present, `optionsToMonitorForSubscribe` is **required** by the types.

### Returning a result

> **2.1+ (Companion 5.0+)**

```typescript
// schema: [ActionIdMixer.readLevel]: { options: { channel: number }; result: number }
[ActionIdMixer.readLevel]: {
	name: 'Read channel level',
	options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
	hasResult: true,
	callback: async (event, context) => {
		return instance.query(`/ch/${event.options.channel}/level`, context.signal)
	},
},
```

The user picks a local or custom variable to store the result in, and later actions on the button can use it. `context.setCustomVariableValue` is deprecated in favour of this flow.

### Abort signals

> **2.1+ (Companion 5.0+)**

`context.signal` (an `AbortSignal`) fires when the result is no longer needed, for example when the user aborts the button's running actions. You can ignore it for short callbacks. For long-running work, pass it to `fetch` or your client, or check `signal.aborted`, and throw. The thrown error is ignored. `learn` receives `context.signal` too, which fires when the user cancels the learn.

```typescript
async query(path: string, signal?: AbortSignal): Promise<number> {
	signal?.throwIfAborted()
	// ... await the device, passing `signal` through ...
	return this.state.level
}
```

### Re-registering at runtime

When device capabilities change (channel count, inputs list), rebuild the definitions:

```typescript
instance.updateDefinitions() // calls UpdateActions(this), UpdateFeedbacks(this), …
```

---

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| `await instance.parseVariablesInString(...)` | Removed in v2. `event.options` is already parsed. Use `useVariables: true` on `textinput` |
| `event.options.x as string` | Not needed once the schema is typed. A cast hides schema mistakes |
| `optionsToIgnoreForSubscribe` | Replaced by the allow-list `optionsToMonitorForSubscribe` |
| `learn` returns `{ ...event.options, level }` | Return only `{ level }` |
| `isVisible: (opts) => …` | Not supported. Use `isVisibleExpression` on a `disableAutoExpression` field |
| `required: true` on `textinput` | Use `minLength: 1` |
| Numbers typed into a `textinput` | Use a `number` field, and migrate stored values with an upgrade script (`companion-v2-upgrades`) |
| `hasResult` on base 2.0.x | Needs 2.1+ |

## Import Reference

```typescript
import type {
	CompanionActionDefinitions,
	CompanionActionDefinition,
	CompanionActionEvent,
	CompanionActionCallbackContext, // 2.1+
	SomeCompanionActionInputField,
} from '@companion-module/base'
import type ModuleInstance from '../main.js'
```

## Related Skills

- **`companion-v2-action-file-pattern`** — create a new action category file and wire it into `actions.ts`
- **`companion-v2-add-action-to-category-file`** — add an action to an existing category file
- **`companion-v2-feedbacks`** — feedback definitions and `checkFeedbacks`
- **`companion-v2-variable-set-value`** — update variables from callbacks
- **`companion-v2-upgrades`** — migrate stored options when you change an action
- **`companion-v2-api-compliance`** — review checklist
- **`companion-actions`** — the v1 equivalent
