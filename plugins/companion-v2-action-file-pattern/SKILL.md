---
name: companion-v2-action-file-pattern
description: '(@companion-module/base v2.x) Teaches the multi-file action pattern for v2 Companion modules: an enum of action IDs, an enum-keyed ActionsSchema{Category} type and a GetActions{Category}() factory per src/actions/action-{category}.ts file, combined in an actions.ts aggregator whose ActionsSchema feeds ModuleSchema. Use when asked to add a new action category, create an action file, or wire a new file into the actions aggregator of a v2 module. Does NOT apply when the category file already exists — use companion-v2-add-action-to-category-file; for v1 modules use companion-action-file-pattern; for converting v1 action files use companion-v1-to-v2-migrate-definitions.'
license: MIT
---

# Companion v2 Action File Pattern

A v2 module splits its action definitions across one file per category. A single `actions.ts` aggregator combines them and calls `setActionDefinitions()`. In v2, every category file also exports a **schema type**. The aggregator joins these schemas with `&` into `ActionsSchema`, which becomes part of `ModuleSchema`. This makes every option fully typed.

## When to Use This Skill

### ✅ Use this skill when:

- Adding a **new logical category** of actions that doesn't fit an existing `src/actions/action-*.ts` file
- Creating a brand-new `src/actions/action-{category}.ts` from scratch
- Wiring a new file into the `actions.ts` aggregator for the first time

### ❌ Do NOT use this skill when:

- The category file already exists → use **`companion-v2-add-action-to-category-file`** (three edits, no aggregator change)
- The module is on base v1.x → use **`companion-action-file-pattern`**
- You are converting a v1 action file to v2 → use **`companion-v1-to-v2-migrate-definitions`**

**The rule of thumb:** if the category file exists, edit it directly. If it doesn't, use this skill to create and wire it.

## Pattern Overview

```
src/
  main.ts                         ← ModuleSchema { actions: ActionsSchema, … }
  actions.ts                      ← aggregator: ActionsSchema = A & B & C; UpdateActions(instance)
  actions/
    action-{category-a}.ts        ← enum + ActionsSchema{A} + GetActions{A}(instance)
    action-{category-b}.ts
    action-utils.ts               ← optional shared helpers / shared option fields
```

`main.ts` calls `UpdateActions(this)` from `updateDefinitions()`. `UpdateActions` spreads every `GetActions{Category}(instance)` into one `setActionDefinitions({...})` call.

---

## Pattern 1 — The Action File

```typescript
import type { CompanionActionDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'

export enum ActionIdTransport {
	play = 'transport_play',
	stop = 'transport_stop',
	gotoCue = 'transport_goto_cue',
}

export type ActionsSchemaTransport = {
	[ActionIdTransport.play]: { options: Record<string, never> }
	[ActionIdTransport.stop]: { options: Record<string, never> }
	[ActionIdTransport.gotoCue]: { options: { cue: number; name: string } }
}

export function GetActionsTransport(instance: ModuleInstance): CompanionActionDefinitions<ActionsSchemaTransport> {
	return {
		[ActionIdTransport.play]: {
			name: 'Play',
			options: [],
			callback: () => {
				instance.sendCommand('/play')
			},
		},
		[ActionIdTransport.stop]: {
			name: 'Stop',
			options: [],
			callback: () => {
				instance.sendCommand('/stop')
			},
		},
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
	}
}
```

The four parts:

| Part | Purpose |
|---|---|
| `import type ModuleInstance from '../main.js'` | Typed access to the module's state and helpers. A type-only import, so there is no runtime cycle with `main.ts`. It replaces v1's `InstanceBaseExt<Config>` |
| `enum ActionId{Category}` | Names every action. The string value is the ID stored in users' buttons, so it must be **globally unique** and must **never change** once released (renaming needs an upgrade script) |
| `type ActionsSchema{Category}` | Keyed by the enum members. Declares each action's option types (and `result` on 2.1+) |
| `GetActions{Category}(instance)` | Returns `CompanionActionDefinitions<ActionsSchema{Category}>`. TypeScript forces exactly one definition per schema key |

> Use `{ options: Record<string, never> }` for actions without options.
> Option values in `event.options` are typed and already variable- or expression-parsed. Don't cast them, and don't call `parseVariablesInString`, which no longer exists.

### Shared option fields (optional `action-utils.ts`)

When several categories reuse a field, export a factory:

```typescript
import type { SomeCompanionActionInputField } from '@companion-module/base'

export function channelOption(): SomeCompanionActionInputField<'channel'> {
	return { id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64, asInteger: true }
}
```

Use it as `options: [channelOption()]` in any action whose schema has `channel: number`.

---

## Pattern 2 — The Aggregator (`actions.ts`)

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

`main.ts` consumes `ActionsSchema`:

```typescript
export type ModuleSchema = {
	config: ModuleConfig
	secrets: undefined
	actions: ActionsSchema
	feedbacks: FeedbacksSchema
	variables: VariablesSchema
}
```

If you forget to spread a category into `setActionDefinitions`, TypeScript reports the missing keys, because `ActionsSchema` declares them.

---

## Pattern 3 — Step-by-Step Recipe

### 1. Create the file

```
src/actions/action-{category}.ts
```

### 2. File template

```typescript
import type { CompanionActionDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'

export enum ActionId{Category} {
	firstAction = '{category}_first_action',
	secondAction = '{category}_second_action',
}

export type ActionsSchema{Category} = {
	[ActionId{Category}.firstAction]: { options: Record<string, never> }
	[ActionId{Category}.secondAction]: { options: { param: string } }
}

export function GetActions{Category}(instance: ModuleInstance): CompanionActionDefinitions<ActionsSchema{Category}> {
	return {
		[ActionId{Category}.firstAction]: {
			name: 'First Action',
			options: [],
			callback: () => {
				instance.log('debug', 'firstAction triggered')
			},
		},
		[ActionId{Category}.secondAction]: {
			name: 'Second Action',
			options: [{ id: 'param', type: 'textinput', label: 'Parameter', default: '', useVariables: true }],
			callback: (event) => {
				instance.log('debug', `secondAction triggered with ${event.options.param}`)
			},
		},
	}
}
```

### 3. Import it in `actions.ts`

```typescript
import { GetActions{Category}, type ActionsSchema{Category} } from './actions/action-{category}.js'
```

### 4. Add the schema to the intersection

```typescript
export type ActionsSchema = ActionsSchemaTransport & ActionsSchemaLevel & ActionsSchema{Category}
```

### 5. Spread the factory into `setActionDefinitions`

```typescript
instance.setActionDefinitions({
	...GetActionsTransport(instance),
	...GetActionsLevel(instance),
	...GetActions{Category}(instance), // ← add
})
```

### 6. Build and verify

```bash
yarn build
yarn lint
```

Zero errors means the file is typed and wired correctly.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Enum string value duplicates an ID in another category | IDs must be globally unique, so check every enum |
| Schema added to the intersection but the factory not spread | TypeScript flags the missing keys in `setActionDefinitions`. Add the spread |
| Option `id` not present in the schema's `options` | Compile error. Add it to the schema, or fix the typo |
| `import ModuleInstance from '../main.js'` (value import) | Use `import type`. A value import creates a runtime cycle and breaks `verbatimModuleSyntax` |
| Missing `.js` extension on a relative import | ESM requires `./actions/action-x.js` |
| `instance.parseVariablesInString(...)` | Removed in v2. Options arrive already parsed |
| `event.options.x as number` | Unnecessary. Fix the schema instead |
| `InstanceBaseExt<Config>` parameter type | Use `ModuleInstance` (type import of the default export) |
| `optionsToIgnoreForSubscribe` | Use `optionsToMonitorForSubscribe` (required with `subscribe` on 2.1+) |

## References

- **`companion-v2-actions`** — the full v2 action API (options, expressions, subscribe, learn, results)
- **`companion-v2-add-action-to-category-file`** — extend an existing category file
- **`companion-v2-module-scaffold`** — where `ModuleSchema` and `updateDefinitions()` live
- **`companion-v2-api-compliance`** — review checklist
- **`companion-action-file-pattern`** — the v1 equivalent
