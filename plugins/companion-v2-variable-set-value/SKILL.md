---
name: companion-v2-variable-set-value
description: '(@companion-module/base v2.x) How to set variable values with setVariableValues(Partial<VariablesSchema>) and read them with getVariableValue() in a v2 Companion module, including JSON values, unsetting with undefined, batching and dynamic template-literal IDs. Use when you need to update variables from device data, actions or polling in a v2 module. Does NOT apply to declaring variables — use companion-v2-variable-definition; for v1 modules use companion-variable-set-value.'
license: MIT
---

# Companion v2 Variable Set Value Skill

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.

Update and read variable values in a v2 module. Both calls are typed by `ModuleSchema['variables']` (your `VariablesSchema`).

## When to Use This Skill

### ✅ Use when:

- Pushing device state into variables (on message, poll or connect)
- Clearing variables on disconnect
- Reading back a variable the module set earlier

### ❌ Do NOT use when:

- Declaring new variables → use **`companion-v2-variable-definition`**
- The module is on base v1.x → use **`companion-variable-set-value`**

---

## The Golden Rule

**Define before you set.** Every ID you set must be in `VariablesSchema` (checked at compile time) **and** registered with `setVariableDefinitions` at runtime. If a value is set for an ID that was never registered, users can't see or pick that variable.

---

## Pattern: Setting Values

```typescript
export function UpdateVariableValues(instance: ModuleInstance): void {
	const values: Partial<VariablesSchema> = {
		connection_state: 'connected',
		device_info: { model: 'X32', firmware: '4.06' },
	}
	for (let ch = 1; ch <= CHANNEL_COUNT; ch++) {
		values[`channel_${ch}_level`] = instance.state.level
	}
	instance.setVariableValues(values)
}
```

- `setVariableValues` takes `Partial<VariablesSchema>`, so pass **only the changed IDs**.
- Batch related updates into one call instead of calling it once per variable.
- The value type comes from the schema. Setting a `number` variable to a string is a compile error.
- An ID that isn't in the schema is an excess-property compile error.

## Pattern: Unsetting

```typescript
instance.setVariableValues({ [`channel_${ch}_name`]: undefined })
```

`undefined` clears the value. Do this on disconnect, or when an entity disappears.

## Pattern: Reading Values

```typescript
const last = instance.getVariableValue('last_command') ?? ''
```

`getVariableValue` returns the **module's own** last-set value (typed from the schema), or `undefined`. It can't read other connections' variables and can't parse expressions. Keep authoritative state on the instance (`instance.state`), and treat variables as output.

---

## Value Type Rules

| Schema type | Example | Notes |
|---|---|---|
| `string` | `'connected'` | |
| `number` | `-12.5` | Expressions can do maths on it directly, with no `parseFloat` |
| `boolean` | `true` | Usable directly in expressions (and in `internal:checkExpression` preset feedbacks on **2.1+ (Companion 5.0+)**) |
| `JsonObject` / arrays | `{ model: 'X32' }` | v2 allows any JSON value. Users access fields through expressions |
| `undefined` | — | Unsets |

Don't pre-format numbers as strings just for display. Users can format them in expressions or button text.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Setting an ID that isn't in `VariablesSchema` | Add it to the schema and the definitions |
| Calling `setVariableValues` per variable in a hot loop | Build one `Partial<VariablesSchema>` object and set it once |
| Stringifying numbers and booleans | Store real JSON types |
| Using `getVariableValue` as the module's state store | Keep state on the instance. Variables are output |
| Setting values before `setVariableDefinitions` | Define first (in `init` via `updateDefinitions()`) |

## Import Reference

```typescript
import type ModuleInstance from './main.js'
import type { VariablesSchema } from './variables.js'
```

## Related Skills

- **`companion-v2-variable-definition`** — declare variables and `VariablesSchema`
- **`companion-v2-feedbacks`** — refresh feedbacks with `checkFeedbacks` alongside variable updates
- **`companion-v2-actions`** — on **2.1+ (Companion 5.0+)**, consider `hasResult` actions instead of writing custom variables
- **`companion-v2-api-compliance`** — review checklist
- **`companion-variable-set-value`** — the v1 equivalent
