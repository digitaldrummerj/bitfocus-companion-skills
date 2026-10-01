---
name: companion-v2-variable-definition
description: '(@companion-module/base v2.x) Declare and register Companion v2 module variables: a VariablesSchema type (including template-literal keys for dynamic families like channel_${number}_level) wired into ModuleSchema, and setVariableDefinitions() with the v2 object form { variableId: { name } }. Use when you need to register variables, name variable IDs, or build dynamic variable sets from device capabilities in a v2 module. Does NOT apply to updating values — use companion-v2-variable-set-value; for v1 modules (array form) use companion-variable-definition.'
license: MIT
---

# Companion v2 Variable Definition Skill

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.

In v2, `setVariableDefinitions` takes an **object keyed by variable ID** instead of v1's array of `{ variableId, name }`. Variables are also typed through `ModuleSchema['variables']`, so `setVariableValues` and `getVariableValue` are type-checked.

## When to Use This Skill

### ✅ Use when:

- Declaring the variables a v2 module exposes
- Adding a variable or a dynamic family (per channel, per input, per user)
- Typing variables in `VariablesSchema`

### ❌ Do NOT use when:

- Updating variable values → use **`companion-v2-variable-set-value`**
- The module is on base v1.x → use **`companion-variable-definition`**
- Converting a v1 array-form definition → use **`companion-v1-to-v2-migrate-definitions`**

---

## Pattern

### `src/variables.ts`

```typescript
import type { CompanionVariableDefinitions, JsonObject } from '@companion-module/base'
import type ModuleInstance from './main.js'

const CHANNEL_COUNT = 4

export type VariablesSchema = {
	last_command: string
	connection_state: string
	device_info: JsonObject
	[channelLevel: `channel_${number}_level`]: number
	[channelName: `channel_${number}_name`]: string
}

export function UpdateVariableDefinitions(instance: ModuleInstance): void {
	const definitions: CompanionVariableDefinitions<VariablesSchema> = {
		last_command: { name: 'Last command sent' },
		connection_state: { name: 'Connection state' },
		device_info: { name: 'Device info (JSON object)' },
	}
	for (let ch = 1; ch <= CHANNEL_COUNT; ch++) {
		definitions[`channel_${ch}_level`] = { name: `Channel ${ch} level` }
		definitions[`channel_${ch}_name`] = { name: `Channel ${ch} name` }
	}
	instance.setVariableDefinitions(definitions)
}
```

### Wire it into `ModuleSchema` (`main.ts`)

```typescript
import { UpdateVariableDefinitions, type VariablesSchema } from './variables.js'

export type ModuleSchema = {
	config: ModuleConfig
	secrets: undefined
	actions: ActionsSchema
	feedbacks: FeedbacksSchema
	variables: VariablesSchema
}
```

Call `UpdateVariableDefinitions(this)` from `updateDefinitions()` (in `init`, before any `setVariableValues`).

### Larger modules: split by area

If the module has many variables, mirror the action layout. Create `src/variables/variable-{area}.ts` files, each exporting `VariablesSchema{Area}` and a `GetVariableDefinitions{Area}()` returning `CompanionVariableDefinitions<VariablesSchema{Area}>`. Then aggregate them:

```typescript
export type VariablesSchema = VariablesSchemaTransport & VariablesSchemaChannels

export function UpdateVariableDefinitions(instance: ModuleInstance): void {
	instance.setVariableDefinitions({
		...GetVariableDefinitionsTransport(),
		...GetVariableDefinitionsChannels(instance),
	})
}
```

---

## Variable value types

v2 variables can hold **any JSON value**: `string`, `number`, `boolean`, `null`, arrays and objects (`JsonObject`). Declare the real type in the schema, for example `number` for a level or `JsonObject` for structured data. Don't stringify everything.

## variableId Naming Rules

- Allowed characters: `a-z A-Z 0-9 _ -`. No spaces, dots or `:`.
- Users reference them as `$(connection-label:variable_id)`, so keep them short, stable and lowercase-snake.
- Changing a released variable ID breaks users' buttons. Treat IDs like action IDs.
- Dynamic IDs should follow one template per family (`channel_${n}_level`) so the template-literal key types them.

---

## Dynamic Registration

Re-run `UpdateVariableDefinitions` whenever capabilities change (channel count, inputs list). The new set **replaces** the old one, and variables that are no longer defined disappear.

```typescript
onChannelCountChanged(count: number): void {
	this.state.channelCount = count
	UpdateVariableDefinitions(this) // reads this.state.channelCount
}
```

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| `setVariableDefinitions([{ variableId: 'x', name: 'X' }])` | v1 array form. Use `{ x: { name: 'X' } }` |
| Variable missing from `VariablesSchema` | `definitions` / `setVariableValues` won't compile. Add it to the schema |
| Dynamic IDs typed as `[key: string]: string` | Prefer template-literal keys so typos are caught |
| Values set before definitions | Call `UpdateVariableDefinitions` first |
| Everything typed as `string` | Use the real JSON type, since v2 supports numbers, booleans and objects |

## Import Reference

```typescript
import type { CompanionVariableDefinitions, JsonObject } from '@companion-module/base'
import type ModuleInstance from './main.js'
```

## Related Skills

- **`companion-v2-variable-set-value`** — set and read values
- **`companion-v2-module-scaffold`** — where `VariablesSchema` joins `ModuleSchema`
- **`companion-v2-api-compliance`** — review checklist
- **`companion-variable-definition`** — the v1 equivalent
