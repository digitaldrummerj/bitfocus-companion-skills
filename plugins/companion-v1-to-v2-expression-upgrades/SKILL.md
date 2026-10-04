---
name: companion-v1-to-v2-expression-upgrades
description: 'Write and retype the upgrade scripts that ship with a Bitfocus Companion module migration from @companion-module/base v1.x to v2: wrapped { isExpression, value } options, retyping historical v1 scripts, textinput-to-number/checkbox conversion with FixupNumericOrVariablesValueToExpressions / FixupBooleanOrVariablesValueToExpressions, friendly dropdown IDs, 0-to-1-based offsets, builtin invert, and setCustomVariableValue to action results. Use when a migration changes saved option types or values, or when existing upgrade scripts stop compiling after bumping base to 2.x. Does NOT cover general upgrade-script authoring in an already-v2 module — use companion-v2-upgrades instead.'
license: MIT
---

# Upgrade Scripts for a v1 → v2 Migration

When you migrate to v2, the **upgrade scripts** need two kinds of work:

1. **Retype the existing (historical) scripts.** They still run for users jumping from old versions, and v2 now passes them **wrapped** option values.
2. **Append new scripts.** These convert saved buttons whenever the migration changed how options are stored: field types, dropdown IDs, or numbering.

This is Phase 7 of **companion-v1-to-v2-migration**. Every snippet here compiles against `@companion-module/base` 2.1.3.

## When to Use This Skill

### ✅ Use this skill when:

- `src/upgrades*` stops compiling after bumping the base package to 2.x
- A `textinput` that held numbers or booleans "so variables could be used" became `number` / `checkbox`
- Dropdown IDs are being renamed to user-friendly values (now is the best time)
- Numbering changes from 0-based to 1-based
- Actions wrote to custom variables via `context.setCustomVariableValue` (**2.1+ (Companion 5.0+)**)

### ❌ Do NOT use this skill when:

- Writing an ordinary upgrade script in a module that is already v2 → **companion-v2-upgrades**
- Changing nothing about stored option shapes. A pure API migration needs only the retyping in Part A.

**The rule:** upgrade scripts are **positional and permanent**. Companion records how many scripts each connection has run. Never delete, reorder, or "dedupe" entries, and only ever **append**.

---

## The v2 Option Shape

In v2 every option an upgrade script sees is wrapped:

```ts
// v1 script saw:
action.options = { channel: 1, name: 'Mic' }

// v2 script sees:
action.options = {
	channel: { isExpression: false, value: 1 },
	name: { isExpression: false, value: 'Mic' },
}
// …and after the user switches a field to expression mode:
action.options.channel = { isExpression: true, value: '$(local:ch) + 1' }
```

Feedback `isInverted` is wrapped the same way (`ExpressionOrValue<boolean>`). The types are `CompanionMigrationOptionValues` and `ExpressionOrValue<T>`.

---

## Part A — Retype Existing Scripts

### A.1 Signatures

`CompanionStaticUpgradeProps` and `CompanionStaticUpgradeResult` now take a **second, required** generic for secrets. `CompanionStaticUpgradeScript` defaults it to `undefined`.

```ts
// Before (v1)
export function addPollingConfigOptions(
	context: CompanionUpgradeContext<ZoomConfig>,
	props: CompanionStaticUpgradeProps<ZoomConfig>,
): CompanionStaticUpgradeResult<ZoomConfig> { ... }

// After (v2)
export function addPollingConfigOptions(
	context: CompanionUpgradeContext<ModuleConfig>,
	_props: CompanionStaticUpgradeProps<ModuleConfig, undefined>,
): CompanionStaticUpgradeResult<ModuleConfig, undefined> {
	return {
		updatedConfig: { ...context.currentConfig, enablePolling: true, pollInterval: 1000 },
		updatedActions: [],
		updatedFeedbacks: [],
	}
}
```

- Use `ModuleConfig` (a `type`, not an `interface`; see **companion-v1-to-v2-migrate-definitions** A.1).
- **Module with secrets:** use `ModuleSecrets` wherever these examples say `undefined`: `CompanionStaticUpgradeProps<ModuleConfig, ModuleSecrets>`, and `CompanionStaticUpgradeScript<ModuleConfig, ModuleSecrets>[]` for the array, even when it is empty.
- **When:** do this retyping in migration **Phase 2**, together with A.2. A historical script that touches `options` doesn't compile with a new signature alone, and the build must be green by the end of Phase 6.
- Use `import type { ... }` for these types (`verbatimModuleSyntax`).
- Config-only scripts usually need nothing else. When **retyping** a historical script, keep its logic: if it built `updatedConfig` from `context.currentConfig`, leave it that way. In **new** scripts, prefer `props.config`, as **companion-v2-upgrades** does. `props.config` is the config to upgrade and is `null` when there is none (e.g. only imported buttons are being upgraded), so return `updatedConfig: null` in that case.

### A.2 Scripts that read or write `options`

Every `action.options.x` or `feedback.options.x` access in an old script now sees the wrapper. Use two small helpers, and treat **expressions as opaque**: never try to rewrite a user's expression string as if it were a literal.

```ts
import type {
	CompanionMigrationOptionValues,
	CompanionStaticUpgradeProps,
	CompanionStaticUpgradeResult,
	CompanionUpgradeContext,
	JsonValue,
} from '@companion-module/base'
import type { ModuleConfig } from '../config.js'

/** Literal (non-expression) value of an option, or undefined if missing / an expression */
export function getLiteralOption(options: CompanionMigrationOptionValues, key: string): JsonValue | undefined {
	const opt = options[key]
	if (!opt || opt.isExpression) return undefined
	return opt.value
}

/** Store a literal value in the v2 wrapped shape */
export function setLiteralOption(options: CompanionMigrationOptionValues, key: string, value: JsonValue): void {
	options[key] = { isExpression: false, value }
}

const oldActionToNewActions: Record<string, { newActionId: string; isGroupBased?: boolean }> = {
	'/zoom/userName/spotlight': { newActionId: 'spotlight', isGroupBased: true },
}

// Historical v1 script, retyped for v2. It still runs for users upgrading from old versions,
// and Companion now hands it wrapped { isExpression, value } options.
export function UpgradeV2ToV3(
	_context: CompanionUpgradeContext<ModuleConfig>,
	props: CompanionStaticUpgradeProps<ModuleConfig, undefined>,
): CompanionStaticUpgradeResult<ModuleConfig, undefined> {
	const result: CompanionStaticUpgradeResult<ModuleConfig, undefined> = {
		updatedConfig: null,
		updatedActions: [],
		updatedFeedbacks: [],
	}

	for (const action of props.actions) {
		// v1: action.options.actionID as string
		const oldId = getLiteralOption(action.options, 'actionID')
		if (typeof oldId !== 'string' || !Object.prototype.hasOwnProperty.call(oldActionToNewActions, oldId)) continue
		const mapping = oldActionToNewActions[oldId]
		action.actionId = mapping.newActionId

		// v1: action.options.group = (action.options.group as number) + 1
		const group = getLiteralOption(action.options, 'group')
		if (mapping.isGroupBased && typeof group === 'number') setLiteralOption(action.options, 'group', group + 1)

		// v1: if (action.options.groupOption === 'set') action.options.groupOption = 'replace'
		if (getLiteralOption(action.options, 'groupOption') === 'set') setLiteralOption(action.options, 'groupOption', 'replace')

		result.updatedActions.push(action)
	}
	return result
}
```

Rewrite rules:

| v1 expression in a script | v2 rewrite |
|---|---|
| `action.options.x as string` (read) | `getLiteralOption(action.options, 'x')`, then narrow with `typeof` |
| `action.options.x = value` (write) | `setLiteralOption(action.options, 'x', value)` |
| `action.options.x !== undefined` | `action.options.x !== undefined` (unchanged: the wrapper is `undefined` when the option is missing) |
| `delete action.options.x` | unchanged |
| `feedback.isInverted = true` | `feedback.isInverted = { isExpression: false, value: true }` |
| Changing `action.actionId` / `feedback.feedbackId` | unchanged |

### A.3 Move the array, preserving it exactly

```ts
// src/upgrades.ts
export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig>[] = [
	UpgradeV2ToV3,
	UpgradeV2ToV3, // duplicate kept on purpose — positions are permanent
	addNewConfigFieldsForSocialStreamAndPerformanceTweaks,
	fixWrongPinCommands,
	addNewConfigFieldsForSocialStreamChatMessagesToSend,
	addPollingConfigOptions,
	// new v2 migration scripts are appended below
]
```

### A.4 Base helpers inside the historical array

| Helper | In v2 |
|---|---|
| `EmptyUpgradeScript` | Unchanged |
| `CreateUseBuiltinInvertForFeedbacksUpgradeScript` | v2-aware: it unwraps the old option and writes a wrapped `isInverted`. Keep it as is. |
| `CreateConvertToBooleanFeedbackUpgradeScript` | **Not v2-aware in base 2.1.3.** It copies `feedback.options[key]` into `feedback.style[styleKey]` as is. Since v2 that is the `{ isExpression, value }` wrapper rather than the colour number, so the style ends up holding an object. It still compiles and looks fine in review. |

For a historical `CreateConvertToBooleanFeedbackUpgradeScript(...)` entry, replace the helper call **at the same array position** with a hand-written script that moves the *literal* value. The full script is in **`references/scripts.md`** → "Replacing CreateConvertToBooleanFeedbackUpgradeScript". The bug only bites users upgrading from a module version older than that script, but those users get corrupted styles. Consider reporting it upstream to companion-module-base.

---

## Part B — New Scripts That Accompany the Migration

Add one script per kind of stored-value change, appended **in the same release** that changes the fields. Each script must:
- push **only** the actions and feedbacks it modified into `updatedActions` / `updatedFeedbacks`
- leave expressions untouched unless it can translate them safely
- be idempotent where possible, so running it on already-converted values does nothing harmful

### B.1 `textinput` → `number` / `checkbox`

v1 modules often used `textinput` + `parseVariablesInString` for numeric or boolean fields so users could type variables. In v2, convert those to `number` / `checkbox` (the user can still switch to expression mode) and fix up the stored values:

```ts
import {
	FixupBooleanOrVariablesValueToExpressions,
	FixupNumericOrVariablesValueToExpressions,
	type CompanionStaticUpgradeResult,
	type CompanionStaticUpgradeScript,
} from '@companion-module/base'
import type { ModuleConfig } from '../config.js'

// textinput -> number / checkbox conversions
const NUMERIC_OPTIONS: Record<string, string[]> = {
	level_set: ['channel', 'level'],
	transport_goto_cue: ['cue'],
}
const BOOLEAN_OPTIONS: Record<string, string[]> = {
	transport_play: ['loop'],
}

export const convertTextInputsToTypedFields: CompanionStaticUpgradeScript<ModuleConfig> = (_context, props) => {
	const result: CompanionStaticUpgradeResult<ModuleConfig, undefined> = {
		updatedConfig: null,
		updatedActions: [],
		updatedFeedbacks: [],
	}
	const fixups = [
		[NUMERIC_OPTIONS, FixupNumericOrVariablesValueToExpressions],
		[BOOLEAN_OPTIONS, FixupBooleanOrVariablesValueToExpressions],
	] as const
	for (const action of props.actions) {
		let changed = false
		for (const [map, fixup] of fixups) {
			for (const key of map[action.actionId] ?? []) {
				const before = action.options[key]
				const after = fixup(before)
				// push only real changes: values already converted, or expressions, come back the same
				if (after?.isExpression !== before?.isExpression || after?.value !== before?.value) {
					action.options[key] = after
					changed = true
				}
			}
		}
		if (changed) result.updatedActions.push(action)
	}
	return result
}
```

What `FixupNumericOrVariablesValueToExpressions` does:

| Stored v1 value | Result |
|---|---|
| `{ isExpression: false, value: '1' }` | `{ isExpression: false, value: 1 }` |
| `{ isExpression: false, value: '$(local:abc)' }` | `{ isExpression: true, value: '$(local:abc)' }` |
| `{ isExpression: false, value: '$(local:abc)$(local:def)' }` | `{ isExpression: true, value: 'parseVariables("$(local:abc)$(local:def)")' }` |

| `{ isExpression: false, value: '' }` | `{ isExpression: true, value: 'parseVariables("")' }`. Decide how empty values should be treated **before** converting the field. |

**Convert only where "empty" carries no meaning, and choose bounds that never reject a value the device accepted.** See **companion-v1-to-v2-migrate-definitions** → `references/behaviour.md` §2.

`FixupBooleanOrVariablesValueToExpressions` does the same for checkbox values (`'true'`, `'1'`, variables). Run the same loop over `props.feedbacks` for feedback options. The field definition change (to `type: 'number'` with `min` / `max`, or `type: 'checkbox'`) happens in the action file. See **companion-v1-to-v2-migrate-definitions**.

### B.2 Friendly dropdown ids

Expressions make users type dropdown ids, which turns cryptic ids such as `ch1=0` into a real pain. If you rename them, append a script that rewrites only the **literal** stored values (`if (!opt || opt.isExpression) continue`). Then update the `choices` ids **and** the `default`, the schema option type, every preset that sets this option, and the code that maps the id to a device command. Full script: **`references/scripts.md`** → B.2.

### B.3 0-based → 1-based numbers

Users write expressions such as `$(local:input)` in human (1-based) terms. If v1 stored 0-based indexes, append a script that adds 1 to literal values and wraps expressions as `(<expr>) + 1`, which is safe because it keeps the user's intent. Then convert the device mapping in code (`value - 1`). Full script: **`references/scripts.md`** → B.3.

### B.4 Built-in invert for boolean feedbacks

If v1 feedbacks had their own `invert` checkbox, drop it from the definition (Companion's built-in invert is on by default via `showInvert`) and append:

```ts
CreateUseBuiltinInvertForFeedbacksUpgradeScript<ModuleConfig>({ transport_playing: 'invert' }),
```

The map key is the feedback ID, and the value is the option ID of the old invert checkbox.

### B.5 `setCustomVariableValue` → action results

> **2.1+ (Companion 5.0+)**, `@companion-module/base` ≥ 2.1.1
>
> In v1, an action with a `custom-variable` option called `context.setCustomVariableValue(...)`. In 2.1 the action returns its value instead (`hasResult: true` plus `result` in the schema), and the user chooses where to store it. Remove the `custom-variable` option from the definition, and append a script that moves the user's stored choice into the new result-store slot:
>
> ```ts
> // 2.1.1+: action that used setCustomVariableValue(option 'targetVariable') now returns a result
> CreateUseActionResultStoreUpgradeScript<ModuleConfig>({ level_read: 'targetVariable' }),
> ```
>
> The map key is the action ID, and the value is the ID of the old custom-variable option.

### B.6 Final array

The historical array from A.3, **unchanged**, followed by the new scripts:

```ts
export const UpgradeScripts: CompanionStaticUpgradeScript<ModuleConfig>[] = [
	// --- historical v1 scripts: exact order, duplicates kept (A.3) ---
	UpgradeV2ToV3,
	UpgradeV2ToV3,
	addNewConfigFieldsForSocialStreamAndPerformanceTweaks,
	fixWrongPinCommands,
	addNewConfigFieldsForSocialStreamChatMessagesToSend,
	addPollingConfigOptions,
	// --- appended with the v2 migration ---
	convertTextInputsToTypedFields,
	friendlyDropdownIds,
	makeIndexesOneBased,
	CreateUseBuiltinInvertForFeedbacksUpgradeScript<ModuleConfig>({ transport_playing: 'invert' }),
	// 2.1+ (Companion 5.0+), base >= 2.1.1: action that used setCustomVariableValue(option 'targetVariable') now returns a result
	CreateUseActionResultStoreUpgradeScript<ModuleConfig>({ level_read: 'targetVariable' }),
]
```

---

## Testing Upgrade Scripts

Upgrade scripts are pure functions, so unit-test them with **wrapped** input. Cover these cases:
- a literal value
- a single variable
- a mixed string
- an expression the user already set (must be left alone)
- an action the script should not touch (must not appear in `updatedActions`)

Example: **`references/scripts.md`** → Testing.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Deleting a duplicate or obsolete script while moving the array | Never. Append only. |
| Old script still does `action.options.group as number` | Read with `getLiteralOption`, write with `setLiteralOption` |
| `CompanionStaticUpgradeProps<ModuleConfig>` (one generic) | Add the secrets generic: `<ModuleConfig, undefined>` |
| Rewriting expression strings as if they were literals | Skip when `isExpression` is true, unless the change is a safe wrap (B.3) |
| Pushing every action into `updatedActions` | Push only the ones you changed. Compare `isExpression` / `value` before and after a fixup. |
| Keeping a historical `CreateConvertToBooleanFeedbackUpgradeScript(...)` entry | It writes the wrapped option into the style in base 2.1.3. Replace it in place with a literal-moving script (A.4). |
| Leaving historical scripts for Phase 7 | Retype them in Phase 2, or the build can't be green after Phase 6 |
| Converting the field type without the fixup script | Saved string values fail validation, and the action is skipped as if disabled |
| Renaming dropdown IDs but not presets / defaults | Update the choices, the default, the schema type, presets and the command mapping together |

## Related Skills

- **companion-v1-to-v2-migration** — where this phase fits
- **companion-v1-to-v2-migrate-definitions** — the field-type changes these scripts accompany
- **companion-v2-upgrades** — v2 upgrade-script reference for ongoing development
- **companion-upgrades** — the v1 reference (for reading the old scripts)

## References

- `references/scripts.md`: full friendly-dropdown-id and 1-based scripts, the CreateConvertToBooleanFeedbackUpgradeScript replacement, upgrade-script unit tests
- [API 2.0 changes — Expression handling in upgrade scripts](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [Upgrade scripts](https://companion.free/for-developers/module-development/connection-basics/upgrade-scripts)
