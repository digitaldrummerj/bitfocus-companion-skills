---
name: companion-v2-add-action-to-category-file
description: '(@companion-module/base v2.x) Add one or more actions to an existing v2 action category file (src/actions/action-{category}.ts): add the enum member, the schema entry and the definition. Use when you need to extend actions in an existing category file, add an action to an action category file, or grow the action list of a v2 module. Does NOT apply when no category file exists yet — use companion-v2-action-file-pattern; for v1 modules use companion-add-action-to-category-file.'
license: MIT
---

# Companion v2 Add Action to Category File

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.

Add a new action to an **existing** v2 action category file. It takes three edits in the same file. The aggregator (`actions.ts`) doesn't change, because it already composes this file's schema and spreads its factory.

## When to Use This Skill

### ✅ Use when:

- Adding one or more actions to an **existing** `src/actions/action-{category}.ts`
- The file already exports `ActionId{Category}`, `ActionsSchema{Category}` and `GetActions{Category}()`

### ❌ Do NOT use when:

- No category file exists yet → use **`companion-v2-action-file-pattern`** (creates the file and wires the aggregator)
- The module is on base v1.x → use **`companion-add-action-to-category-file`**
- Renaming or removing an existing action → stored buttons reference the ID, so add an upgrade script (**`companion-v2-upgrades`**)

**The rule:** file exists → this skill. File doesn't exist → `companion-v2-action-file-pattern`.

---

## The Pattern

### Step 1 — Add an enum member

```typescript
export enum ActionIdTransport {
	play = 'transport_play',
	stop = 'transport_stop',
	gotoCue = 'transport_goto_cue',
	pause = 'transport_pause', // ← new
}
```

> The string value is the ID stored in users' configurations. It must be **unique across all categories**, and it must not change after release.

### Step 2 — Add the schema entry

```typescript
export type ActionsSchemaTransport = {
	[ActionIdTransport.play]: { options: Record<string, never> }
	[ActionIdTransport.stop]: { options: Record<string, never> }
	[ActionIdTransport.gotoCue]: { options: { cue: number; name: string } }
	[ActionIdTransport.pause]: { options: { fadeMs: number } } // ← new
}
```

- No options → `{ options: Record<string, never> }`
- **2.1+ (Companion 5.0+)**: an action that returns a value adds `result: <JsonValue type>`, for example `{ options: { channel: number }; result: number }`

### Step 3 — Add the definition

Add a matching entry to the object returned by `GetActions{Category}()`:

```typescript
[ActionIdTransport.pause]: {
	name: 'Pause',
	options: [
		{ id: 'fadeMs', type: 'number', label: 'Fade (ms)', default: 0, min: 0, max: 10000, clampValues: true },
	],
	callback: (event) => {
		instance.sendCommand('/pause', event.options.fadeMs)
	},
},
```

Until all three edits are in place, TypeScript reports the missing or extra key. That error is how you know you're done.

#### Callback forms

| Form | Signature | Use when |
|---|---|---|
| Sync | `callback: (event) => { … }` | Fire-and-forget commands |
| Async | `callback: async (event, context) => { … }` | Awaiting I/O. On **2.1+ (Companion 5.0+)** pass `context.signal` to cancellable work |
| With result (**2.1+ (Companion 5.0+)**) | `hasResult: true, callback: async (event) => value` | The schema declares `result` |

`event.options.*` values are typed by the schema and **already parsed**: variables in `textinput` fields with `useVariables: true` are substituted, and expressions are evaluated. Don't cast them, and don't call `parseVariablesInString`, which was removed in v2.

---

## Option Types Quick Reference

| Type | Schema value type | Required extra fields | Notes |
|---|---|---|---|
| `textinput` | `string` | — (`default` optional) | `useVariables: true` to substitute `$(…)`; `minLength` instead of `required` |
| `number` | `number` | `default`, `min`, `max` | `range`, `step`, `clampValues`, `asInteger` |
| `dropdown` | `string` / `number` | `choices`, `default` | `allowCustom` for free text; use friendly ids |
| `multidropdown` | `string[]` / `number[]` | `choices`, `default: []` | `sortSelection` (2.0.2+) |
| `checkbox` | `boolean` | `default` | |
| `colorpicker` | `number` (or `string` with `returnType: 'string'`) | `default` | `enableAlpha` |
| `static-text` | `note?: undefined`: required on base 2.0.x (the id must be a schema key); may be omitted from **2.1.3** | `value` | Display only |
| `custom-variable` | `string` | — | Actions only |

Expression controls that apply to every field: `disableAutoExpression`, `allowInvalidValues`, `expressionDescription`, `isVisibleExpression`.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Added the definition but not the schema entry | TS error "object literal may only specify known properties". Add the schema entry |
| Added the schema entry but not the definition | TS error "property … is missing". Add the definition |
| Duplicate enum string value | IDs must be unique across **all** category enums |
| `id` in `options` doesn't match a schema key | Compile error. Make them match exactly |
| `as string` / `as number` casts on `event.options` | Remove them. Let the schema type them |
| Duplicate option `id` within one action | Companion **2.1+ (Companion 5.0+)** drops it and logs a warning. Keep ids unique |
| Added a new option to an **existing** action and read it without a fallback | Buttons saved before the option existed don't have the key. Read it with `event.options.x ?? default` |
| Added an option to an action used in presets | Presets must give **every** option. Add the new key to each preset that uses the action |

## References

- **`companion-v2-action-file-pattern`** — create a new category file and wire the aggregator
- **`companion-v2-actions`** — full v2 action API
- **`companion-v2-add-preset-to-category-file`** — expose the new action as a preset button
- **`companion-v2-api-compliance`** — review checklist
- **`companion-add-action-to-category-file`** — the v1 equivalent
