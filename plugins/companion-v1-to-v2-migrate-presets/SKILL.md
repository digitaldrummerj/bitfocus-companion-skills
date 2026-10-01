---
name: companion-v1-to-v2-migrate-presets
description: 'Migrate Bitfocus Companion module presets from @companion-module/base v1.x (type button/text + category, single-argument setPresetDefinitions) to the v2 API (sections, groups, type simple, setPresetDefinitions(structure, presets)). Use when converting preset category files, removing CompanionButtonPresetDefinition/CompanionPresetExt helpers, replacing loop-generated preset ID families with template groups, or fixing preset type errors after bumping base to 2.x. Does NOT apply to adding presets to an already-v2 module — use companion-v2-preset-category-file or companion-v2-add-preset-to-category-file instead.'
license: MIT
---

# Migrate Presets to v2

The v2 preset API replaces the flat `category` string with a **structure** made of sections, which contain groups, which contain presets. `setPresetDefinitions` now takes two arguments: `setPresetDefinitions(structure, presets)`.

This skill keeps your **enum-per-category file pattern**. Each `src/presets/preset-{category}.ts` file now returns its section together with its presets, and the `presets.ts` aggregator merges them. All "After" code compiles against `@companion-module/base` 2.1.3.

This is Phase 5 of **companion-v1-to-v2-migration**. Actions and feedbacks must already have v2 schemas (Phases 3–4), because preset action and feedback IDs and options are type-checked against them.

## When to Use This Skill

### ✅ Use this skill when:

- Preset files contain `type: 'button'` / `type: 'text'` with a `category:` string
- `presets.ts` calls `this.setPresetDefinitions(GetPresetList(this))` with one argument
- A `preset-utils.ts` defines `CompanionPresetExt extends CompanionButtonPresetDefinition` or hand-rolled `actionId` / `feedbackId` unions
- Presets are generated in loops with template-literal IDs (``Caller_${number}``)

### ❌ Do NOT use this skill when:

- The module is already v2 and you only need a new preset category → **companion-v2-preset-category-file**
- You are adding one preset to an existing v2 file → **companion-v2-add-preset-to-category-file**

**The rule:** preset **IDs** (the keys of the `presets` object) are not stored by Companion. Users get a *copy* when they drag a preset onto a button. That means preset IDs and categories can be renamed freely during migration, and no upgrade script is needed. Action and feedback IDs inside the presets must still match your definitions.

---

## v1 → v2 Mapping

| v1 | v2 |
|---|---|
| `type: 'button'` | `type: 'simple'` |
| `category: 'Chat Actions'` on each preset | Remove it. The preset ID is listed in a **group** inside a **section** of the `structure` array. |
| `type: 'text'`, `text: '...'` heading presets | Remove them. Use the section's or group's `name` / `description`. |
| `options: { relativeDelay: true }` | Remove it. All delays are relative now. |
| `options: { rotaryActions: true }` | Remove it. Add `rotate_left` / `rotate_right` arrays to the step when needed. |
| `options: { stepAutoProgress }` | Unchanged |
| `CompanionButtonPresetDefinition`, `CompanionTextPresetDefinition`, `CompanionPresetExt` | `CompanionPresetDefinitions<ModuleSchema>` (with `ModuleSchema` from `main.ts`) |
| Hand-rolled `actionId: ActionIdA \| ActionIdB \| ...` unions | Delete them. `CompanionPresetDefinitions<ModuleSchema>` already restricts `actionId` / `feedbackId` to your schemas and type-checks each entry's `options`. |
| Boolean feedback in preset without `style` | `style` is **required** for boolean feedbacks, optional for `value`, and forbidden for `advanced` |
| `setPresetDefinitions(presets)` | `setPresetDefinitions(structure, presets)`. Call it **after** the action and feedback definitions are set. |
| One preset per index generated in a loop | A `template` group with one preset and a local variable, or keep the loop in a `simple` group (see Step 4) |

---

## Step 1 — Delete the v1 preset type helpers

In `src/presets/preset-utils.ts`:

1. Delete `CompanionPresetExt`, `PresetFeedbackDefinition` and any `actionId` / `feedbackId` union types.
2. Delete the imports of every `ActionId*` enum that existed only to build those unions.
3. **Keep the style helpers.** Functions that return `CompanionButtonStyleProps` or `CompanionFeedbackButtonStyleResult` still type-check:
   ```ts
   import { combineRgb, type CompanionButtonStyleProps } from '@companion-module/base'

   // style helpers keep working unchanged
   export function getDefaultStyle(text: string): CompanionButtonStyleProps {
   	return { text, size: '14', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) }
   }
   ```
   Change their imports to `import type` (`verbatimModuleSyntax`).

## Step 2 — Convert each preset category file

**Before (v1)** `src/presets/preset-chat.ts`:

```ts
import { ActionIdUserChat } from '../actions/action-user-chat.js'
import { colorBlack, colorLightGray } from '../utils.js'
import { CompanionPresetExt } from './preset-utils.js'
import { ActionIdGlobal } from '../actions/action-global.js'

export enum PresetIdChat {
	sendChatEveryone = 'Send_Chat_Everyone',
	sendChatDM = 'Send_Chat_DM',
}

export function GetPresetsChat(): { [id in PresetIdChat]: CompanionPresetExt | undefined } {
	const presets: { [id in PresetIdChat]: CompanionPresetExt | undefined } = {
		[PresetIdChat.sendChatEveryone]: {
			type: 'button',
			category: 'Chat Actions',
			name: `Send_Chat_Everyone`,
			style: { text: `Send Chat Everyone`, size: '14', color: colorBlack, bgcolor: colorLightGray },
			steps: [{ down: [{ actionId: ActionIdGlobal.sendAChatToEveryone, options: {} }], up: [] }],
			feedbacks: [],
		},
		// ...
	}
	return presets
}
```

**After (v2):** the same enum, and the function now returns `{ section, presets }`.

```ts
import { combineRgb, type CompanionPresetDefinitions, type CompanionPresetSection } from '@companion-module/base'
import type { ModuleSchema } from '../main.js'
import { ActionIdTransport } from '../actions/action-transport.js'
import { FeedbackIdTransport } from '../feedbacks/feedback-transport.js'

export enum PresetIdTransport {
	play = 'transport_play',
	stop = 'transport_stop',
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
			steps: [{ down: [{ actionId: ActionIdTransport.stop, options: {} }], up: [] }],
			feedbacks: [],
		},
	}

	const section: CompanionPresetSection<ModuleSchema> = {
		id: 'transport',
		name: 'Transport',
		definitions: [
			{ id: 'transport_buttons', type: 'simple', name: 'Buttons', presets: [PresetIdTransport.play, PresetIdTransport.stop] },
		],
	}

	return { section, presets }
}
```

Conversion procedure for each file:

1. Keep the `PresetId{Category}` enum.
2. Change the return type to `{ section: CompanionPresetSection<ModuleSchema>; presets: CompanionPresetDefinitions<ModuleSchema> }`, and the local `presets` type to `{ [id in PresetId{Category}]: CompanionPresetDefinitions<ModuleSchema>[string] }`.
3. For every preset: `type: 'button'` → `type: 'simple'`, delete `category`, delete `relativeDelay` and `rotaryActions` from `options`, and make the `name` human-readable (e.g. `'Send chat to everyone'` instead of `'Send_Chat_Everyone'`).
4. Build the section:
   - **One v1 `category` value per file** → one section (`id` = kebab or snake case of the category, `name` = the old category string) containing one `simple` group that lists all the enum members.
   - **Several `category` values in one file** → either one section with one group per old category, or one section per category. If you choose one section per category, return `sections: CompanionPresetSection<ModuleSchema>[]` instead of `section`.
   - Section and group `id`s must be unique across the module.
5. Run `yarn build`. Any action or feedback option a preset sets that is not in that action's schema now errors with `Type '...' is not assignable to type 'CompanionPresetValue<never>'`. Fix the option name, or add the option to the schema.

Option values in presets can be literals or expressions:

```ts
options: { channel: { isExpression: true, value: '$(local:channel)' }, level: 100 }
```

## Step 3 — Rewrite the aggregator

**Before (v1):**

```ts
export function GetPresetList(instance: InstanceBaseExt<ZoomConfig>): CompanionPresetDefinitions {
	const presetsChat: { [id in PresetIdChat]: CompanionPresetExt | undefined } = GetPresetsChat()
	// ...
	const presets: { [id in PresetIdChat | /* ... */]: CompanionPresetExt | undefined } = { ...presetsChat /* ... */ }
	return presets as CompanionPresetDefinitions
}
// main: this.setPresetDefinitions(GetPresetList(this))
```

**After (v2)** `src/presets.ts`:

```ts
import type { CompanionPresetDefinitions, CompanionPresetSection } from '@companion-module/base'
import type ModuleInstance from './main.js'
import type { ModuleSchema } from './main.js'
import { GetPresetsTransport } from './presets/preset-transport.js'

export function UpdatePresets(instance: ModuleInstance): void {
	const categories = [GetPresetsTransport()]

	const structure: CompanionPresetSection<ModuleSchema>[] = categories.map((c) => c.section)
	const presets: CompanionPresetDefinitions<ModuleSchema> = Object.assign({}, ...categories.map((c) => c.presets))

	instance.setPresetDefinitions(structure, presets)
}
```

- The order of `categories` is the order sections appear in the Companion UI.
- Factories that read instance state (e.g. `GetPresetsListGallery(instance)`) keep taking `instance: ModuleInstance`. Static ones keep taking nothing.
- Wherever `main.ts` refreshed presets (`this.setPresetDefinitions(GetPresetList(this))`), call `UpdatePresets(this)` after `UpdateActions` / `UpdateFeedbacks`.

## Step 4 — Dynamic preset ID families

v1 modules often generated hundreds of near-identical presets in a loop (``Caller_${number}``, 1..1000). v2 gives you two options.

### Option A — Template group (preferred when the index can live in a local variable)

Define **one** preset that reads a local variable, and let a `template` group create the copies:

```ts
import { combineRgb, type CompanionPresetDefinitions, type CompanionPresetSection } from '@companion-module/base'
import type { ModuleSchema } from '../main.js'
import { ActionIdLevel } from '../actions/action-level.js'
import { FeedbackIdTransport } from '../feedbacks/feedback-transport.js'
import type { CompanionButtonStyleProps } from '@companion-module/base'

// style helpers keep working unchanged
export function getDefaultStyle(text: string): CompanionButtonStyleProps {
	return { text, size: '14', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) }
}

export enum PresetIdParticipants {
	selectChannelTemplate = 'participants_select_channel',
	clearAll = 'participants_clear_all',
}

// v1: for (let i = 1; i <= 1000; i++) presets[`Caller_${i}`] = {...}   ->  one template preset + template group
export function GetPresetsParticipants(maxChannels: number): {
	section: CompanionPresetSection<ModuleSchema>
	presets: CompanionPresetDefinitions<ModuleSchema>
} {
	const presets: { [id in PresetIdParticipants]: CompanionPresetDefinitions<ModuleSchema>[string] } = {
		[PresetIdParticipants.selectChannelTemplate]: {
			type: 'simple',
			name: 'Select channel',
			style: getDefaultStyle('Channel $(local:channel)'),
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
			feedbacks: [{ feedbackId: FeedbackIdTransport.playing, options: {}, style: { bgcolor: combineRgb(0, 200, 0) } }],
		},
		[PresetIdParticipants.clearAll]: {
			type: 'simple',
			name: 'Clear all',
			style: getDefaultStyle('Clear'),
			steps: [{ down: [{ actionId: ActionIdLevel.setLevel, options: { channel: 1, level: 0 } }], up: [] }],
			feedbacks: [],
		},
	}

	const section: CompanionPresetSection<ModuleSchema> = {
		id: 'participants',
		name: 'Participants',
		definitions: [
			{
				id: 'participants_channels',
				type: 'template',
				name: 'Select channel',
				presetId: PresetIdParticipants.selectChannelTemplate,
				templateVariableName: 'channel',
				templateValues: Array.from({ length: maxChannels }, (_, i) => ({ name: `Channel ${i + 1}`, value: i + 1 })),
			},
			{ id: 'participants_misc', type: 'simple', name: 'Other', presets: [PresetIdParticipants.clearAll] },
		],
	}
	return { section, presets }
}
```

- `templateVariableName` must match a `localVariables[].variableName` on the template preset. Each `templateValues` entry becomes one preset, whose local variable starts at that `value`.
- Feedback options accept the same `{ isExpression: true, value: '$(local:channel)' }` form.
- `commonVariableValues` sets the other local variables the same for every copy.
- The action option driven by the expression must accept expressions: no `disableAutoExpression` on it.

### Option B — Keep the loop (when the preset can't be expressed as a template)

Some presets can't use a template. One case is style text that references a **computed variable name**, such as `` `$(zoomosc:Participant${padding(index, 3)})` ``, because a local variable can't build a variable name inside the style text. Another is a preset whose list of feedbacks depends on the index. For these, keep generating one `simple` preset per index and list them all in one `simple` group:

```ts
export type PresetIdCaller = `Caller_${number}`

export function GetPresetsCallers(count: number): {
	section: CompanionPresetSection<ModuleSchema>
	presets: CompanionPresetDefinitions<ModuleSchema>
} {
	const presets: { [id: PresetIdCaller]: CompanionPresetDefinitions<ModuleSchema>[string] } = {}
	const ids: PresetIdCaller[] = []

	for (let index = 1; index <= count; index++) {
		const id: PresetIdCaller = `Caller_${index}`
		ids.push(id)
		presets[id] = {
			type: 'simple',
			name: `Caller ${index}`,
			style: {
				text: `$(sandbox:caller_${String(index).padStart(3, '0')})`,
				size: 'auto',
				color: combineRgb(255, 255, 255),
				bgcolor: combineRgb(0, 0, 0),
			},
			steps: [{ down: [{ actionId: ActionIdLevel.setLevel, options: { channel: index, level: 100 } }], up: [] }],
			feedbacks: [
				{ feedbackId: FeedbackIdTransport.playing, options: {}, style: { bgcolor: combineRgb(0, 200, 0) } },
				{ feedbackId: FeedbackIdTransport.status, options: { showText: true } },
			],
		}
	}

	return {
		section: {
			id: 'callers',
			name: 'Callers',
			definitions: [{ id: 'callers_by_position', type: 'simple', name: 'By position', presets: ids }],
		},
		presets,
	}
}
```

Advanced feedbacks (`FeedbackIdTransport.status` above) take **no** `style` in a preset.

## Step 5 — 2.1-only preset features (optional)

> **2.1+ (Companion 5.0+)**: none of these are needed for the migration. Only adopt them if you targeted 2.1.
>
> - `internal:*` actions and feedbacks inside presets, e.g. `{ actionId: 'internal:wait', options: { time: 500 } }`, `internal:logicIf`, `internal:checkExpression`
> - `type: 'layered'` presets and `type: 'alternatives'` (layered first, with a simple fallback)
> - `localVariables` entries with `variableType: 'feedback'`
>
> Details are in **companion-v2-preset-category-file**.

## Step 6 — Tests

Tests that captured `setPresetDefinitions` must take two arguments:

```ts
const [structure, presets] = instance.setPresetDefinitions.mock.calls[0]
expect(presets['transport_play']?.type).toBe('simple')
const groupIds = structure.flatMap((s) => s.definitions.map((d) => (typeof d === 'string' ? d : d.id)))
```

Replace assertions on `preset.category` with assertions that the preset ID appears in some group's `presets` array (or is a template group's `presetId`).

## Common Mistakes

| Mistake | Fix |
|---|---|
| Leaving `category` on presets | TS error (unknown property). Delete it, and put the ID in a group. |
| A preset ID defined but not listed in any group | It is never shown. Every preset must appear in a group (or be a template's `presetId`). |
| Boolean preset feedback without `style` | Required in v2 typing. Add a style (reuse your `getFeedbackStyle*` helpers). |
| Giving an advanced feedback a `style` in a preset | `style?: never`. Remove it. |
| Duplicate section or group `id`s across category files | Prefix group IDs with the category: `transport_buttons`, `participants_channels`. |
| Calling `setPresetDefinitions` before `setActionDefinitions` | Call presets last, in `updateDefinitions()`. |
| Template `templateVariableName` doesn't match a local variable | Make the names match exactly. |

## Related Skills

- **companion-v1-to-v2-migration** — overall phase order
- **companion-v1-to-v2-migrate-definitions** — action and feedback schemas (needed first)
- **companion-v2-preset-category-file** — the v2 category file pattern in full
- **companion-v2-add-preset-to-category-file** — adding presets after migration

## References

- [API 2.0 changes — Presets overhaul](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [Presets (API 2.x)](https://companion.free/for-developers/module-development/connection-basics/presets)
