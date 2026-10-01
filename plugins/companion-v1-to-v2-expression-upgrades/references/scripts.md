# Script examples: friendly dropdown ids, 1-based numbers, tests

Companion to **companion-v1-to-v2-expression-upgrades** Part B. All code compiles against `@companion-module/base` 2.1.3 (and 2.0.x).

The scripts below assume these imports:

```ts
import type {
	CompanionMigrationOptionValues,
	CompanionStaticUpgradeResult,
	CompanionStaticUpgradeScript,
} from '@companion-module/base'
import type { ModuleConfig } from '../config.js'
```

## B.2 Friendly dropdown IDs

Expressions make users type dropdown IDs, so cryptic IDs like `ch1=0` become painful. If you rename them, rewrite the stored literal values:

```ts
// rename cryptic dropdown ids to friendly ones
const MODE_RENAMES: Record<string, string> = { 'ch1=0': 'off', 'ch1=1': 'on' }

export const friendlyDropdownIds: CompanionStaticUpgradeScript<ModuleConfig> = (_context, props) => {
	const result: CompanionStaticUpgradeResult<ModuleConfig, undefined> = {
		updatedConfig: null,
		updatedActions: [],
		updatedFeedbacks: [],
	}
	for (const action of props.actions) {
		if (action.actionId !== 'set_mode') continue
		const mode = action.options.mode
		if (!mode || mode.isExpression) continue // never rewrite a user expression
		const renamed = MODE_RENAMES[String(mode.value)]
		if (renamed === undefined) continue
		action.options.mode = { isExpression: false, value: renamed }
		result.updatedActions.push(action)
	}
	return result
}
```

Update the `choices` IDs **and** the `default` in the definition, the schema option type, any preset that sets this option, and the code that maps the ID to a device command.

## B.3 0-based → 1-based numbers

Users write expressions such as `$(local:input)` in human (1-based) terms. If v1 stored 0-based indexes, convert them, and convert the device mapping in code (`value - 1`):

```ts
import type { CompanionMigrationOptionValues } from '@companion-module/base'

// 0-based -> 1-based numbers
function offsetValue(options: CompanionMigrationOptionValues, key: string): void {
	const opt = options[key]
	if (!opt) return
	if (opt.isExpression) {
		options[key] = { isExpression: true, value: `(${opt.value}) + 1` }
	} else {
		options[key] = { isExpression: false, value: Number(opt.value) + 1 }
	}
}

export const makeIndexesOneBased: CompanionStaticUpgradeScript<ModuleConfig> = (_context, props) => {
	const result: CompanionStaticUpgradeResult<ModuleConfig, undefined> = {
		updatedConfig: null,
		updatedActions: [],
		updatedFeedbacks: [],
	}
	for (const action of props.actions) {
		if (action.actionId !== 'level_set') continue
		offsetValue(action.options, 'channel')
		result.updatedActions.push(action)
	}
	for (const feedback of props.feedbacks) {
		if (feedback.feedbackId !== 'transport_level') continue
		offsetValue(feedback.options, 'channel')
		result.updatedFeedbacks.push(feedback)
	}
	return result
}
```

This is the one case where wrapping an expression is safe: `(<expr>) + 1` keeps the user's intent.

## Testing Upgrade Scripts

Upgrade scripts are pure functions, so unit-test them with wrapped input:

```ts
const props = {
	config: null,
	secrets: null,
	actions: [
		{ id: 'a1', controlId: 'c1', actionId: 'level_set', options: { channel: { isExpression: false as const, value: '3' } } },
	],
	feedbacks: [],
}
const out = convertTextInputsToTypedFields({ currentConfig: config }, props)
expect(out.updatedActions[0].options.channel).toEqual({ isExpression: false, value: 3 })
```

Cover: a literal value, a single variable, a mixed string, an expression the user already set (must be left alone), and an action the script should not touch (must not appear in `updatedActions`).

