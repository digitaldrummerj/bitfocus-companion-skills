---
name: companion-v2-upgrades
description: '(@companion-module/base v2.x) Write upgrade scripts for a v2 module: wrapped { isExpression, value } options, config/secrets migration and the built-in Fixup*/Create* helpers. Use when renaming or removing actions, feedbacks or options, changing option types, or migrating config or secrets in a v2 module. Does NOT apply to v1 modules (use companion-upgrades) or to the scripts shipped with a v1 to v2 migration (use companion-v1-to-v2-expression-upgrades).'
license: MIT
---

# Companion v2 Upgrades Skill

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.

Upgrade scripts migrate users' saved config, secrets, actions and feedbacks when a module changes. In v2 the most important difference from v1 is that **every option value is wrapped**: `{ isExpression, value }`.

## When to Use This Skill

- Renaming an action, feedback or option ID
- Changing an option's type (for example `textinput` → `number`)
- Adding config fields with defaults, or moving a password into secrets
- Converting advanced feedbacks to boolean, or a custom invert option to the built-in invert

---

## Key API Types

### Registration (`main.ts` + `upgrades.ts`)

```typescript
// upgrades.ts
export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets>[] = [
	/* append only */
]

// main.ts
import { UpgradeScripts } from './upgrades.js'
export { UpgradeScripts }
export default class ModuleInstance extends InstanceBase<ModuleSchema> { /* … */ }
```

In v2 this replaces `runEntrypoint(ModuleInstance, UpgradeScripts)`. Companion records how many scripts each connection has run, so **never remove, reorder or edit a released script**. Only append. If a script must become a no-op, replace it with `EmptyUpgradeScript`.

### `CompanionStaticUpgradeScript<TConfig, TSecrets = undefined>`

```typescript
(context: { currentConfig: Readonly<TConfig> }, props: {
	config: TConfig | null
	secrets: TSecrets | null
	actions: CompanionMigrationAction[]
	feedbacks: CompanionMigrationFeedback[]
}) => {
	updatedConfig: TConfig | null
	updatedSecrets?: TSecrets | null
	updatedActions: CompanionMigrationAction[]
	updatedFeedbacks: CompanionMigrationFeedback[]
}
```

Return only what you changed. Use `null` for config and secrets you didn't touch, and `[]` for no actions or feedbacks.

`props.config` / `props.secrets` hold the config to upgrade, or `null` when there is none, for example when only imported buttons are being upgraded. Base config changes on `props.config` and return `updatedConfig: null` when it is `null`. `context.currentConfig` is the connection's current config and is read-only. Historical v1 scripts that built `updatedConfig` from `context.currentConfig` can keep doing so; see **companion-v1-to-v2-expression-upgrades**.

### Wrapped option values

```typescript
// v1: action.options.channel === 3
// v2:
action.options.channel // { isExpression: false, value: 3 }
                       // or { isExpression: true, value: '$(local:ch) + 1' }
feedback.isInverted    // { isExpression: false, value: true } | undefined
```

`options[key]` may also be `undefined`. Always check `isExpression` before touching `value`. An expression is a **string of code**, not data.

---

## Patterns & Examples

### Config: add fields with defaults

```typescript
const addPollingConfig: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets> = (_context, props) => {
	if (!props.config) return { updatedConfig: null, updatedActions: [], updatedFeedbacks: [] }
	return {
		updatedConfig: {
			...props.config,
			enablePolling: props.config.enablePolling ?? true,
			pollInterval: props.config.pollInterval ?? 1000,
		},
		updatedActions: [],
		updatedFeedbacks: [],
	}
}
```

### Config → secrets

```typescript
/** Config shape from before the password moved to secrets */
type LegacyConfig = ModuleConfig & { password?: string }

const movePasswordToSecrets: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets> = (_context, props) => {
	const legacy: LegacyConfig | null = props.config
	if (!legacy?.password) return { updatedConfig: null, updatedActions: [], updatedFeedbacks: [] }

	const { password, ...config } = legacy
	return {
		updatedConfig: config,
		updatedSecrets: { password },
		updatedActions: [],
		updatedFeedbacks: [],
	}
}
```

### Rename an action and one of its options

```typescript
const renameActionAndOption: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets> = (_context, props) => {
	const updatedActions: CompanionMigrationAction[] = []
	for (const action of props.actions) {
		if (action.actionId === 'mute') {
			action.actionId = 'mixer_mute_channel'
			action.options.channel = action.options.ch // moves the wrapped value as-is
			delete action.options.ch
			updatedActions.push(action)
		}
	}
	return { updatedConfig: null, updatedActions, updatedFeedbacks: [] }
}
```

Use **literal strings** for old IDs in upgrade scripts, not enum members. The enum will change over time, but the script must keep matching what was stored back then.

### Transform values safely (handle expressions)

```typescript
const offsetValue = (options: CompanionMigrationOptionValues, key: string): void => {
	const opt = options[key]
	if (!opt) return
	if (opt.isExpression) {
		options[key] = { isExpression: true, value: `(${opt.value}) + 1` }
	} else {
		options[key] = { isExpression: false, value: Number(opt.value) + 1 }
	}
}

const zeroToOneBasedChannels: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets> = (_context, props) => {
	const updatedActions: CompanionMigrationAction[] = []
	const updatedFeedbacks: CompanionMigrationFeedback[] = []
	for (const action of props.actions) {
		if (action.actionId !== 'mixer_mute_channel') continue
		offsetValue(action.options, 'channel')
		updatedActions.push(action)
	}
	for (const feedback of props.feedbacks) {
		if (feedback.feedbackId !== 'mixer_channel_muted') continue
		offsetValue(feedback.options, 'channel')
		updatedFeedbacks.push(feedback)
	}
	return { updatedConfig: null, updatedActions, updatedFeedbacks }
}
```

### `textinput` → `number` / `checkbox`

When you change a field that used to be a `textinput`, which users often filled with `$(var)` references, use the fixup helpers:

```typescript
const textinputToNumberAndCheckbox: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets> = (_context, props) => {
	const updatedActions: CompanionMigrationAction[] = []
	for (const action of props.actions) {
		if (action.actionId === 'level_set') {
			action.options.level = FixupNumericOrVariablesValueToExpressions(action.options.level)
			action.options.fade = FixupBooleanOrVariablesValueToExpressions(action.options.fade)
			updatedActions.push(action)
		}
	}
	return { updatedConfig: null, updatedActions, updatedFeedbacks: [] }
}
```

| Input | `FixupNumericOrVariablesValueToExpressions` output |
|---|---|
| `{ isExpression: false, value: '1' }` | `{ isExpression: false, value: 1 }` |
| `{ isExpression: false, value: '$(local:abc)' }` | `{ isExpression: true, value: '$(local:abc)' }` |
| `{ isExpression: false, value: '$(local:a)$(local:b)' }` | `{ isExpression: true, value: 'parseVariables("$(local:a)$(local:b)")' }` |

### Built-in helpers

```typescript
export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets>[] = [
	EmptyUpgradeScript, // a retired script, kept so later positions don't shift. Not boilerplate
	addPollingConfig,
	movePasswordToSecrets,
	renameActionAndOption,
	// advanced → boolean feedback (`true`, or a map of option id → style property)
	CreateConvertToBooleanFeedbackUpgradeScript<ModuleConfig>({ mixer_channel_muted: true }),
	// module-defined 'invert' checkbox → Companion's built-in invert
	CreateUseBuiltinInvertForFeedbacksUpgradeScript<ModuleConfig, ModuleSecrets>({ mixer_channel_muted: 'invert' }),
	zeroToOneBasedChannels,
	textinputToNumberAndCheckbox,
	// 2.1+ (Companion 5.0+), base >= 2.1.1: custom-variable option + setCustomVariableValue → action result flow
	CreateUseActionResultStoreUpgradeScript<ModuleConfig, ModuleSecrets>({ mixer_read_level: 'targetVariable' }),
]
```

> **Caution (base 2.1.3):** `CreateConvertToBooleanFeedbackUpgradeScript` copies `feedback.options[key]` into `feedback.style` unchanged. In v2 that value is the `{ isExpression, value }` wrapper, not the colour number, so the resulting style holds an object. Until it is fixed upstream, prefer a hand-written script that moves only literal values. There is one in **companion-v1-to-v2-expression-upgrades** → `references/scripts.md`. `CreateUseBuiltinInvertForFeedbacksUpgradeScript` is v2-aware and fine to use.

> **2.1+ (Companion 5.0+)** — `CreateUseActionResultStoreUpgradeScript` needs base **2.1.1** or later. It moves the stored `custom-variable` option into the action's `storeResult`. You must also update the action definition to `hasResult: true` and return the value (see **`companion-v2-actions`**).

### Testing an upgrade script

```typescript
const result = renameActionAndOption(
	{ currentConfig: DEFAULT_CONFIG },
	{
		config: null,
		secrets: null,
		actions: [{ id: 'a1', controlId: 'c1', actionId: 'mute', options: { ch: { isExpression: false, value: 3 } } }],
		feedbacks: [],
	},
)
// expect(result.updatedActions[0].actionId).toBe('mixer_mute_channel')
// expect(result.updatedActions[0].options.channel).toEqual({ isExpression: false, value: 3 })
```

---

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| Reading `action.options.x` as a raw value | It is `{ isExpression, value }` (or `undefined`) |
| Doing maths or string ops on an expression's `value` | Wrap it: `` `(${value}) + 1` ``. Never parse it |
| Removing or reordering an old script | Never do this. Append only, or swap in `EmptyUpgradeScript` |
| Using current enum members for old IDs | Use the literal strings that were stored at the time |
| `CompanionStaticUpgradeScript<ModuleConfig>` when the module has secrets | Add the second generic: `<ModuleConfig, ModuleSecrets>` |
| Returning every action "just in case" | Return only changed ones |
| Forgetting feedback `isInverted` is wrapped too | `{ isExpression: false, value: boolean }` |

## Import Reference

```typescript
import {
	CreateConvertToBooleanFeedbackUpgradeScript,
	CreateUseActionResultStoreUpgradeScript, // 2.1+ (Companion 5.0+), base >= 2.1.1
	CreateUseBuiltinInvertForFeedbacksUpgradeScript,
	EmptyUpgradeScript, // a retired script, kept so later positions don't shift. Not boilerplate
	FixupBooleanOrVariablesValueToExpressions,
	FixupNumericOrVariablesValueToExpressions,
	type CompanionMigrationAction,
	type CompanionMigrationFeedback,
	type CompanionMigrationOptionValues,
	type CompanionStaticUpgradeScript,
} from '@companion-module/base'
```

## Related Skills

- **`companion-v1-to-v2-expression-upgrades`** — the scripts to ship when moving a module from v1 to v2
- **`companion-v2-actions`** / **`companion-v2-feedbacks`** — the definitions your scripts migrate towards
- **`companion-v2-config`** — config and secrets
- **`companion-v2-api-compliance`** — review checklist
- **`companion-upgrades`** — the v1 equivalent
