---
name: companion-v2-add-preset-to-category-file
description: '(@companion-module/base v2.x) Add one or more presets to an existing v2 preset category file (src/presets/preset-{category}.ts): add the PresetId enum member, the type simple preset definition, and reference it from a group in the category''s section. Use when you need to add a preset button, extend the preset enum, or grow an existing preset category in a v2 module. Does NOT apply when no preset category file exists yet — use companion-v2-preset-category-file; for v1 modules use companion-add-preset-to-category-file.'
license: MIT
---

# Companion v2 Add Preset to Category File

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x. Steps 1–3 are 2.0-compatible.

Add a preset to an **existing** v2 preset category file. v2 needs **three** edits, where v1 needed two. The extra step exists because a preset only appears in the UI once a group in the section references it.

## When to Use This Skill

### ✅ Use when:

- Adding one or more preset buttons to an existing `src/presets/preset-{category}.ts`
- The file already exports `PresetId{Category}` and `GetPresets{Category}()` returning `{ section, presets }`

### ❌ Do NOT use when:

- No preset category file exists yet → use **`companion-v2-preset-category-file`**
- The module is on base v1.x → use **`companion-add-preset-to-category-file`**

---

## The Pattern

### Step 1 — Add an enum member

```typescript
export enum PresetIdTransport {
	play = 'transport_play',
	stop = 'transport_stop',
	pause = 'transport_pause', // ← new
}
```

### Step 2 — Add the preset definition

Add it to the `presets` map in `GetPresets{Category}()`:

```typescript
[PresetIdTransport.pause]: {
	type: 'simple',
	name: 'Pause',
	style: { text: 'PAUSE', size: '18', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) },
	steps: [{ down: [{ actionId: ActionIdTransport.pause, options: { fadeMs: 0 } }], up: [] }],
	feedbacks: [{ feedbackId: FeedbackIdTransport.paused, options: {}, style: { bgcolor: combineRgb(200, 120, 0) } }],
},
```

This example assumes you added a `paused` boolean feedback with **`companion-v2-add-feedback-to-category-file`**.

Because the map is typed `{ [id in PresetIdTransport]: … }`, forgetting this step after Step 1 is a compile error.

**Every option of each step action must be set.** Preset option types map over the action's schema, so `options: {}` only compiles for actions that have no options. Fill in the field defaults, e.g. `{ fadeMs: 0 }`. Feedback options work the same way.

### Step 3 — Reference it from the section

```typescript
const section: CompanionPresetSection<ModuleSchema> = {
	id: 'transport',
	name: 'Transport',
	definitions: [
		{
			id: 'transport_buttons',
			type: 'simple',
			name: 'Buttons',
			presets: [PresetIdTransport.play, PresetIdTransport.stop, PresetIdTransport.pause], // ← add
		},
	],
}
```

> TypeScript does **not** catch a missing reference. The preset compiles but never shows in the preset browser.

If the new preset is one of a numbered family ("Input 1…16"), don't add 16 presets. Add **one** preset that uses a local variable, and a `type: 'template'` group (see **`companion-v2-preset-category-file`**).

---

## Preset Button Shape Reference (`type: 'simple'`)

```typescript
{
	type: 'simple',
	name: 'Button name',                          // shown in the preset list
	keywords: ['optional', 'search', 'terms'],
	style: {
		text: 'Label\\n$(conn:variable)',          // \\n for a line break
		size: 'auto',                              // 'auto' | '7' | '14' | '18' | '24' | '30' | '44'
		color: combineRgb(255, 255, 255),
		bgcolor: combineRgb(0, 0, 0),
	},
	localVariables: [{ variableType: 'simple', variableName: 'channel', startupValue: 1 }],
	steps: [
		{
			down: [{ actionId: ActionIdX.y, options: { /* typed by the action schema */ } }],
			up: [],
		},
	],
	feedbacks: [
		// boolean feedback → `style` required; value/advanced → no style
		{ feedbackId: FeedbackIdX.z, options: {}, style: { bgcolor: combineRgb(0, 200, 0) } },
	],
}
```

- Option values can be literals or `{ isExpression: true, value: '$(local:channel) + 1' }`.
- Multi-step (toggle) buttons: add more entries to `steps`. `options: { stepAutoProgress: true }` is the default behaviour.
- **2.1+ (Companion 5.0+):** steps may contain `internal:*` actions (for example `internal:wait`), and presets may be `layered` or `alternatives`. See **`companion-v2-preset-category-file`**.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Preset added but not listed in any group | Add its id to a group's `presets` (or as a template `presetId`) |
| `type: 'button'` / `category` | v1 shape. Use `type: 'simple'` and the section/group |
| Boolean feedback without `style` | Required |
| `style` on a value or advanced feedback | Forbidden. Remove it |
| `options: {}` for an action that has options | Every schema option is required in a preset. Fill in the defaults |
| Action option name doesn't match the action schema | Compile error. Fix the name |
| Duplicate preset id across categories | Preset ids must be unique module-wide. Prefix them with the category |
| `relativeDelay` | Removed. `delay` is relative |

## References

- **`companion-v2-preset-category-file`** — create a category file and wire `presets.ts`
- **`companion-v2-add-action-to-category-file`** / **`companion-v2-add-feedback-to-category-file`** — add the action or feedback the preset uses
- **`companion-v2-api-compliance`** — review checklist
- **`companion-add-preset-to-category-file`** — the v1 equivalent
