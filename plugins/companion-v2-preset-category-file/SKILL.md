---
name: companion-v2-preset-category-file
description: '(@companion-module/base v2.x) Create a new v2 preset category file (src/presets/preset-{category}.ts exporting a PresetId enum and GetPresets{Category}() returning { section, presets }) and wire it into presets.ts / setPresetDefinitions(structure, presets). Use when asked to create a preset file, add a preset category or section, set up template groups, or (2.1+) layered/alternatives presets in a v2 module. Does NOT apply when the category file exists (use companion-v2-add-preset-to-category-file), to v1 modules (use companion-preset-category-file), or to converting v1 presets (use companion-v1-to-v2-migrate-presets).'
license: MIT
---

# Companion v2 Preset Category File

v2 replaced the flat v1 preset list (`type: 'button'` + `category`) with a **structure**: sections, then groups, then presets. `setPresetDefinitions` now takes **two** arguments: `(structure, presets)`. In the split-file layout, each category file owns one **section** together with the presets it references, and the aggregator collects them.

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x. Patterns 1–3 and template groups are 2.0-compatible.

## When to Use This Skill

### ✅ Use this skill when:

- Creating a new `src/presets/preset-{category}.ts`
- Adding a new section to the preset browser
- Wiring `presets.ts` for the first time in a v2 module
- Building template groups (one preset definition shown as many buttons)

### ❌ Do NOT use this skill when:

- The category file exists and you're adding a button → use **`companion-v2-add-preset-to-category-file`**
- The module is on base v1.x → use **`companion-preset-category-file`**
- Converting v1 presets (`type: 'button'`, `category`) → use **`companion-v1-to-v2-migrate-presets`**

## Pattern Overview

```
src/
  presets.ts                     ← aggregator → setPresetDefinitions(structure, presets)
  presets/
    preset-{category-a}.ts       ← enum PresetId{A} + GetPresets{A}(): { section, presets }
    preset-{category-b}.ts
    preset-utils.ts              ← optional shared styles
```

The structure model:

```
Section  (id, name, description?, keywords?)          ← one per category file
 ├─ Group type 'simple'   (id, name, presets: [ids])  ← a heading with listed presets
 └─ Group type 'template' (id, name, presetId, templateVariableName, templateValues[])
                                                       ← one preset rendered once per value
   (a section may instead list preset ids directly: definitions: ['id1', 'id2'])
```

Presets themselves are a flat map `{ [presetId]: definition }`. The structure refers to them by id. A preset that no group references is **not shown**.

---

## Pattern 1 — The Preset Category File

```typescript
import { combineRgb, type CompanionPresetDefinitions, type CompanionPresetSection } from '@companion-module/base'
import type { ModuleSchema } from '../main.js'
import { ActionIdTransport } from '../actions/action-transport.js'
import { ActionIdLevel } from '../actions/action-level.js'
import { FeedbackIdTransport } from '../feedbacks/feedback-transport.js'

export enum PresetIdTransport {
	play = 'transport_play',
	stop = 'transport_stop',
	setLevelTemplate = 'transport_set_level_template',
}

export function GetPresetsTransport(): {
	section: CompanionPresetSection<ModuleSchema>
	presets: CompanionPresetDefinitions<ModuleSchema>
} {
	const presets: { [id in PresetIdTransport]: CompanionPresetDefinitions<ModuleSchema>[string] } = {
		[PresetIdTransport.play]: {
			type: 'simple',
			name: 'Play',
			style: { text: 'PLAY', size: '18', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) },
			steps: [{ down: [{ actionId: ActionIdTransport.play, options: {} }], up: [] }],
			feedbacks: [{ feedbackId: FeedbackIdTransport.playing, options: {}, style: { bgcolor: combineRgb(0, 200, 0) } }],
		},
		[PresetIdTransport.stop]: {
			type: 'simple',
			name: 'Stop',
			style: { text: 'STOP', size: '18', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) },
			steps: [
				{
					down: [{ actionId: ActionIdTransport.stop, options: {} }],
					up: [],
				},
			],
			feedbacks: [],
		},
		[PresetIdTransport.setLevelTemplate]: {
			type: 'simple',
			name: 'Set channel level',
			style: {
				text: 'CH $(local:channel)',
				size: 'auto',
				color: combineRgb(255, 255, 255),
				bgcolor: combineRgb(0, 0, 0),
			},
			localVariables: [{ variableType: 'simple', variableName: 'channel', startupValue: 1 }],
			steps: [
				{
					down: [
						{
							actionId: ActionIdLevel.setLevel,
							options: { channel: { isExpression: true, value: '$(local:channel)' }, level: 100 },
						},
					],
					up: [],
				},
			],
			feedbacks: [],
		},
	}

	const section: CompanionPresetSection<ModuleSchema> = {
		id: 'transport',
		name: 'Transport',
		definitions: [
			{
				id: 'transport_buttons',
				type: 'simple',
				name: 'Buttons',
				presets: [PresetIdTransport.play, PresetIdTransport.stop],
			},
			{
				id: 'transport_levels',
				type: 'template',
				name: 'Channel levels',
				presetId: PresetIdTransport.setLevelTemplate,
				templateVariableName: 'channel',
				templateValues: [
					{ name: 'Channel 1', value: 1 },
					{ name: 'Channel 2', value: 2 },
				],
			},
		],
	}

	return { section, presets }
}
```

Why it is shaped this way:

| Part | Notes |
|---|---|
| `enum PresetId{Category}` | Preset ids must be unique across the module, and the structure refers to them. Unlike action ids, they are not stored in users' configs |
| Mapped `presets` type `{ [id in PresetIdX]: … }` | TypeScript ensures every enum member has a definition |
| `CompanionPresetDefinitions<ModuleSchema>` | Checks every `actionId`, `feedbackId` and their `options` against your action and feedback schemas. A typo in an option name is a compile error |
| `section` returned with the presets | The category owns its place in the preset browser. Return exactly **one** section per file; if a category has sub-areas, use several groups in that section |
| `import type { ModuleSchema }` | Type-only. Preset factories usually don't need the instance; pass it in only if presets depend on runtime state, such as a channel count |

### Preset definition fields (`type: 'simple'`)

| Field | Notes |
|---|---|
| `name` | Shown in the preset list (and as a tooltip) |
| `keywords?` | Extra search terms |
| `style` | `text`, `size` (`'auto'` / `'7'` … `'44'`), `color`, `bgcolor`, `alignment?`, `pngalignment?`, `png64?`, `show_topbar?`, `textExpression?` |
| `previewStyle?` | Partial style used only in the preset browser |
| `options?` | `{ stepAutoProgress?: boolean }` |
| `steps` | `[{ down: [...], up: [...], rotate_left?, rotate_right?, name?, [ms]: hold-actions }]` |
| `feedbacks` | Boolean feedbacks **require** `style`. Value and advanced feedbacks must not have `style`/`isInverted` |
| step action / feedback `options` | **Every** option in the action's (or feedback's) schema must be given. `options: {}` only compiles when there are none. Fill in the field defaults |
| `localVariables?` | `[{ variableType: 'simple', variableName, startupValue }]`, used as `$(local:name)` |

Action and feedback `options` in presets accept either a plain value or `{ isExpression: true, value: '…' }`. Every action delay is **relative** to the previous action. `relativeDelay` was removed.

### Hold actions

```typescript
steps: [
	{
		down: [],
		up: [],
		2000: { options: { runWhileHeld: true }, actions: [{ actionId: ActionIdTransport.stop, options: {} }] },
	},
],
```

---

## Pattern 2 — The Aggregator (`presets.ts`)

```typescript
import type { CompanionPresetDefinitions, CompanionPresetSection } from '@companion-module/base'
import type ModuleInstance from './main.js'
import type { ModuleSchema } from './main.js'
import { GetPresetsTransport } from './presets/preset-transport.js'
import { GetPresetsMixer } from './presets/preset-mixer.js'

export function UpdatePresets(instance: ModuleInstance): void {
	const categories = [GetPresetsTransport(), GetPresetsMixer()]

	const structure: CompanionPresetSection<ModuleSchema>[] = categories.map((c) => c.section)
	const presets: CompanionPresetDefinitions<ModuleSchema> = Object.assign({}, ...categories.map((c) => c.presets))

	instance.setPresetDefinitions(structure, presets)
}
```

- The order of `categories` is the order sections appear in the UI.
- Call `UpdatePresets` **after** `UpdateActions` and `UpdateFeedbacks`.
- If a category's presets depend on runtime state (inputs list, channel count), make it `GetPresets{Category}(instance)` and call `UpdatePresets` again when that state changes.

---

## Pattern 3 — Step-by-Step Recipe

1. Create `src/presets/preset-{category}.ts` using Pattern 1, with an enum, a `presets` map and a `section`.
2. Give the section a unique `id`, and give every group a unique `id` within the module.
3. Reference each preset id from exactly one group, either through `presets: [...]` or as a template `presetId`.
4. In `presets.ts`, import `GetPresets{Category}` and add its result to the `categories` array.
5. `yarn build`: invalid action or feedback ids and options fail the compile.

---

## Template groups (one definition, many buttons)

Use a template group when you would otherwise generate N nearly identical presets in a loop, for example "Mute CH 1…32":

```typescript
{
	id: 'mixer_mute',
	type: 'template',
	name: 'Mute channel',
	presetId: PresetIdMixer.muteChannel,           // a preset that uses $(local:channel)
	templateVariableName: 'channel',              // the local variable to vary
	templateValues: Array.from({ length: 4 }, (_, i) => ({ name: `Mute CH ${i + 1}`, value: i + 1 })),
},
```

The template preset declares the local variable (`localVariables: [{ variableType: 'simple', variableName: 'channel', startupValue: 1 }]`). Its options read it through `{ isExpression: true, value: '$(local:channel)' }`. `commonVariableValues` can set other local variables for every generated button.

---

## 2.1 additions

> **2.1+ (Companion 5.0+)**: none of these exist in base 2.0.x. Hosts running an older API drop `internal:*` entries with a warning.

- **Internal actions and feedbacks** inside preset steps, e.g. `{ actionId: 'internal:wait', options: { time: 500 } }`, plus `internal:logicIf` / `internal:checkExpression` and the other logic blocks
- **`type: 'layered'`** presets built from elements (text, image, box, line, circle, gauge, group, composite), and **`type: 'alternatives'`** (layered first, with a `simple` fallback)
- **Feedback local variables:** `localVariables: [{ variableType: 'feedback', variableName, feedbackId, options }]`
- **Composite elements** registered with `setCompositeElementDefinitions`

Full examples: **`references/v2.1-presets.md`**.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| `setPresetDefinitions(presets)` (one argument) | v2 needs `setPresetDefinitions(structure, presets)` |
| `type: 'button'` / `category: '…'` | Use `type: 'simple'` and place the preset in a section/group |
| Preset defined but not referenced by any group | It won't appear. Add its id to a group |
| Boolean feedback in a preset without `style` | Required for boolean feedbacks |
| `style` on a value/advanced feedback in a preset | Not allowed. Remove it |
| Option typo in a preset action | Compile error. Use the action's schema option names |
| `relativeDelay` / absolute delays | Removed. `delay` is always relative |
| Generating 100 near-identical presets in a loop | Use a template group |
| Using `internal:*`, `layered` or `alternatives` on base 2.0.x | Needs **2.1+ (Companion 5.0+)** |
| `options: {}` for an action that has options | Every schema option is required. Fill in the defaults |
| Empty groups (`presets: []`) | Don't emit the group |

## References

- **`companion-v2-add-preset-to-category-file`** — add a button to an existing category
- **`companion-v2-actions`** / **`companion-v2-feedbacks`** — the ids and options presets reference
- **`companion-v2-module-scaffold`** — where `UpdatePresets` is called
- **`companion-v1-to-v2-migrate-presets`** → `references/dynamic-presets.md` — reusable preset builders (callbacks returning `SomePresetActionEntry<ModuleSchema>`) and families fed by several sources
- `references/v2.1-presets.md` — internal actions/feedbacks, layered and alternatives presets, feedback local variables, composite elements
- **`companion-v2-api-compliance`** — review checklist
- **`companion-preset-category-file`** — the v1 equivalent
- [Presets (API 2.x)](https://companion.free/for-developers/module-development/connection-basics/presets)
