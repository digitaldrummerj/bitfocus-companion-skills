---
name: companion-v1-to-v2-migrate-presets
description: 'Migrate Bitfocus Companion module presets from @companion-module/base v1.x (type button/text + category, single-argument setPresetDefinitions) to the v2 API (sections, groups, type simple, setPresetDefinitions(structure, presets)). Use when converting preset category files, removing CompanionButtonPresetDefinition/CompanionPresetExt helpers, replacing loop-generated preset ID families with template groups, or fixing preset type errors after bumping base to 2.x. Does NOT apply to adding presets to an already-v2 module — use companion-v2-preset-category-file or companion-v2-add-preset-to-category-file instead.'
license: MIT
---

# Migrate Presets to v2

The v2 preset API replaces the flat `category` string with a **structure**: sections contain groups, and groups contain presets. `setPresetDefinitions` now takes two arguments, `setPresetDefinitions(structure, presets)`.

This skill keeps your **enum-per-category file pattern**. Each `src/presets/preset-{category}.ts` now returns its section together with its presets, and the `presets.ts` aggregator merges them. All "After" code compiles against `@companion-module/base` 2.1.3. Nothing in Steps 1–4 is 2.1-only.

This is Phase 5 of **companion-v1-to-v2-migration**. Actions and feedbacks must already have v2 schemas (Phases 3–4), because preset action and feedback ids and their options are type-checked against them.

## When to Use This Skill

### ✅ Use this skill when:

- Preset files contain `type: 'button'` / `type: 'text'` with a `category:` string
- `presets.ts` calls `this.setPresetDefinitions(GetPresetList(this))` with one argument
- A `preset-utils.ts` defines `CompanionPresetExt extends CompanionButtonPresetDefinition` or hand-rolled `actionId` / `feedbackId` unions
- Presets are generated in loops with template-literal IDs (``Caller_${number}``) or by builder helpers

### ❌ Do NOT use this skill when:

- The module is already v2 and you only need a new preset category → **companion-v2-preset-category-file**
- You are adding one preset to an existing v2 file → **companion-v2-add-preset-to-category-file**

**The rule:** Companion does not store preset **ids** (the keys of the `presets` object). When a user drags a preset onto a button, they get a *copy*. So you can rename preset ids and categories freely during migration, and no upgrade script is needed. Action and feedback ids *inside* presets must still match your definitions.

---

## v1 → v2 Mapping

| v1 | v2 |
|---|---|
| `type: 'button'` | `type: 'simple'` |
| `category: 'Chat Actions'` on each preset | Remove it. List the preset id in a **group** inside a **section** of the `structure` array. Builder helper parameters named `category` that fed this value go too. |
| `type: 'text'`, `text: '...'` heading presets | Remove them. Use the section/group `name` and `description` instead. |
| `options: { relativeDelay: true }` | Remove it. All delays are relative now. |
| `options: { rotaryActions: true }` | Remove it. Add `rotate_left` / `rotate_right` arrays to the step when needed. |
| `options: { stepAutoProgress }` | Unchanged |
| `options: {}` relying on field defaults | **Every option of the action must be given.** `CompanionPresetOptionValues<T>` maps over the action's schema, so every key is required. Fill in the field defaults (e.g. `{ userName: '', message: '' }`). Otherwise you get `options: {} is not assignable to … missing the following properties`. Only keys declared optional (`note?: …`) may be left out. |
| `CompanionButtonPresetDefinition`, `CompanionTextPresetDefinition`, `CompanionPresetExt` | `CompanionPresetDefinitions<ModuleSchema>` for the map. `CompanionSimplePresetDefinition<ModuleSchema>` for helpers that return one preset. `SomePresetActionEntry<ModuleSchema>` / `SomePresetSimpleFeedbackEntry<ModuleSchema>` for helpers that return one step action or feedback. |
| Hand-rolled `actionId: ActionIdA \| ActionIdB \| ...` unions | Delete them. `CompanionPresetDefinitions<ModuleSchema>` already restricts `actionId` / `feedbackId` to your schemas and checks each entry's `options`. |
| Feedback `style` in presets | **Boolean** feedbacks: `style` is **required**. **Value** and **advanced** feedbacks: `style` is **forbidden** (`style?: never`). |
| `setPresetDefinitions(presets)` | `setPresetDefinitions(structure, presets)`. Call it **after** the action and feedback definitions are set. |
| One preset per index generated in a loop | Either a `template` group with one preset and a local variable, or keep the loop in a `simple` group (Step 4) |

---

## Step 1 — Delete the v1 preset type helpers

In `src/presets/preset-utils.ts`:

1. Delete `CompanionPresetExt`, `PresetFeedbackDefinition` and any `actionId` / `feedbackId` union types.
2. Delete the imports of every `ActionId*` / `FeedbackId*` enum that existed only to build those unions. This includes empty "anchor" enums (`export enum ActionId {}`) that the action and feedback aggregators kept only for these unions. Delete those enums from `actions.ts` / `feedbacks.ts` now as well.
3. **Keep the style helpers.** Functions that return `CompanionButtonStyleProps` or `CompanionFeedbackButtonStyleResult` still type-check:
   ```ts
   import { combineRgb, type CompanionButtonStyleProps } from '@companion-module/base'

   // style helpers keep working unchanged
   export function getDefaultStyle(text: string): CompanionButtonStyleProps {
   	return { text, size: '14', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) }
   }
   ```
   Change type-only imports to `import type` (`verbatimModuleSyntax`).
4. If the file held only v1 types, delete it, or reuse it for shared v2 preset types (see the builder types in `references/dynamic-presets.md`).

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
		[PresetIdChat.sendChatDM]: {
			type: 'button',
			category: 'Chat Actions',
			name: `Send_Chat_DM`,
			style: { text: `Send Chat DM`, size: '14', color: colorBlack, bgcolor: colorLightGray },
			steps: [{ down: [{ actionId: ActionIdUserChat.sendAChatViaDM, options: {} }], up: [] }],
			feedbacks: [],
		},
	}
	return presets
}
```

**After (v2):** the same enum and the same ids. The function returns `{ section, presets }`, and every action option is filled in. In this example, `sendAChatToEveryone` has a `message` option and `sendAChatViaDM` has `userName` and `message`.

```ts
import type { CompanionPresetDefinitions, CompanionPresetSection } from '@companion-module/base'
import type { ModuleSchema } from '../main.js'
import { ActionIdUserChat } from '../actions/action-user-chat.js'
import { ActionIdGlobal } from '../actions/action-global.js'
import { colorBlack, colorLightGray } from '../utils.js'

export enum PresetIdChat {
	sendChatEveryone = 'Send_Chat_Everyone',
	sendChatDM = 'Send_Chat_DM',
}

export function GetPresetsChat(): {
	section: CompanionPresetSection<ModuleSchema>
	presets: CompanionPresetDefinitions<ModuleSchema>
} {
	const presets: { [id in PresetIdChat]: CompanionPresetDefinitions<ModuleSchema>[string] } = {
		[PresetIdChat.sendChatEveryone]: {
			type: 'simple',
			name: 'Send chat to everyone',
			style: { text: `Send Chat Everyone`, size: '14', color: colorBlack, bgcolor: colorLightGray },
			steps: [{ down: [{ actionId: ActionIdGlobal.sendAChatToEveryone, options: { message: '' } }], up: [] }],
			feedbacks: [],
		},
		[PresetIdChat.sendChatDM]: {
			type: 'simple',
			name: 'Send chat via DM',
			style: { text: `Send Chat DM`, size: '14', color: colorBlack, bgcolor: colorLightGray },
			steps: [{ down: [{ actionId: ActionIdUserChat.sendAChatViaDM, options: { userName: '', message: '' } }], up: [] }],
			feedbacks: [],
		},
	}

	const section: CompanionPresetSection<ModuleSchema> = {
		id: 'chat',
		name: 'Chat Actions',
		definitions: [
			{ id: 'chat_buttons', type: 'simple', name: 'Chat', presets: [PresetIdChat.sendChatEveryone, PresetIdChat.sendChatDM] },
		],
	}

	return { section, presets }
}
```

Conversion procedure for each file:

1. Keep the `PresetId{Category}` enum and its values.
2. Change the return type to `{ section: CompanionPresetSection<ModuleSchema>; presets: CompanionPresetDefinitions<ModuleSchema> }`, and the local `presets` type to `{ [id in PresetId{Category}]: CompanionPresetDefinitions<ModuleSchema>[string] }`.
3. For every preset:
   - `type: 'button'` → `type: 'simple'`.
   - Delete `category`, and delete `relativeDelay` / `rotaryActions` from `options`.
   - Fill in **every option** of each step action and each feedback.
   - Make `name` human-readable.
4. Build the section. **Every category file returns exactly one `section`**, which keeps the aggregator uniform:
   - **One v1 `category` per file** → one section (`id` in snake case, `name` = the old category string) containing one `simple` group that lists all the enum members.
   - **Several `category` values in one file** → still one section, with **one group per old category**.
   - **Suffix-style categories spread over several files or builders** (`'Scenes'`, `'Scenes - Fixed'`, `'Scenes 001-050 - Dynamic'`) → one `Scenes` section. Each former category becomes a group, and the aggregator appends the builder groups (see `references/dynamic-presets.md` → "One family fed by several sources").
   - Leave out groups that would list no presets (for example a builder that has nothing before the device answers). Don't emit `presets: []`.
   - Section and group `id`s must be unique across the module.
5. Run `yarn build`. Typical errors:
   - `Type '...' is not assignable to type 'CompanionPresetValue<never>'`: the preset sets an option that is not in the schema. Fix the name, or add the option to the schema.
   - `options: {} … missing the following properties`: fill in the missing options.
   - `style … is not assignable to type 'undefined'`: you gave a value or advanced feedback a `style`. Remove it.

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
import { GetPresetsChat } from './presets/preset-chat.js'

export function UpdatePresets(instance: ModuleInstance): void {
	const categories = [GetPresetsChat() /* , GetPresetsOther(instance), ... */]

	const structure: CompanionPresetSection<ModuleSchema>[] = categories.map((c) => c.section)
	const presets: CompanionPresetDefinitions<ModuleSchema> = Object.assign({}, ...categories.map((c) => c.presets))

	instance.setPresetDefinitions(structure, presets)
}
```

- The order of `categories` is the order sections appear in the Companion UI.
- Factories that read instance state keep taking `instance: ModuleInstance`. Static ones keep taking nothing.
- Wherever `main.ts` refreshed presets (`this.setPresetDefinitions(GetPresetList(this))`), call `UpdatePresets(this)` after `UpdateActions` / `UpdateFeedbacks`.

## Step 4 — Dynamic preset families and builders

v1 modules often generated hundreds of near-identical presets in a loop (``Caller_${number}``, 1..1000), or through builder helpers that took `actionId` plus loose `actionOptions`. Choose one of these:

| Situation | v2 approach |
|---|---|
| The index can live in a local variable (`$(local:channel)`) | **Template group**: one preset plus `type: 'template'` with `templateValues` |
| Style text builds a variable *name* from the index, or the feedback list varies per index | **Keep the loop** and list the generated ids in one `simple` group |
| Generic builder helpers (`buildXPresets({ actionId, actionOptions, … })`) | **Callbacks**: the builder takes `(…) => SomePresetActionEntry<ModuleSchema>` so each call site names a concrete action. This avoids casts. |

The full code for all three, and for merging builder groups into one family section, is in **`references/dynamic-presets.md`**.

## Step 5 — 2.1-only preset features (optional)

> **2.1+ (Companion 5.0+)**: none of these are needed for the migration. Adopt them only if you target 2.1.
>
> - `internal:*` actions and feedbacks inside presets, e.g. `{ actionId: 'internal:wait', options: { time: 500 } }`, `internal:logicIf`, `internal:checkExpression`
> - `type: 'layered'` presets and `type: 'alternatives'` (layered first, with a simple fallback)
> - `localVariables` entries with `variableType: 'feedback'`
>
> Details are in **companion-v2-preset-category-file** (`references/v2.1-presets.md`).

## Step 6 — Tests

- Tests that captured `setPresetDefinitions` must read **two** arguments.
- Replace assertions on `preset.category` with "which section/group lists this id" assertions.
- Change any `type === 'button'` filter to `'simple'`. Otherwise guard tests **silently skip every preset** and still pass.

A reusable `capturePresets()` helper, the rewrite table and recommended guard tests are in **`references/tests.md`**.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Leaving `category` on presets | TS error (unknown property). Delete it and put the id in a group. |
| `options: {}` for an action that has options | Every schema option is required in a preset. Fill in the defaults. |
| A preset id defined but not listed in any group | It is never shown. Every preset must appear in a group (or be a template group's `presetId`). |
| Boolean preset feedback without `style` | Required in v2 typing. Add a style (reuse your `getFeedbackStyle*` helpers). |
| Giving a value or advanced feedback a `style` in a preset | Forbidden (`style?: never`). Remove it. |
| Returning several sections from one category file | Return one `section` with one group per old category, so the aggregator stays `categories.map((c) => c.section)`. |
| Empty groups (`presets: []`) | Don't emit the group. |
| Duplicate section or group `id`s across category files | Prefix group ids with the category: `chat_buttons`, `participants_channels`. |
| Calling `setPresetDefinitions` before `setActionDefinitions` | Call presets last, in `updateDefinitions()`. |
| Template `templateVariableName` doesn't match a local variable | Make the names match exactly. |
| Guard tests filtering `type === 'button'` | They pass without checking anything. Use `'simple'` and run `tsc -p tsconfig.json --noEmit` over tests. |

## Related Skills

- **companion-v1-to-v2-migration**: overall phase order
- **companion-v1-to-v2-migrate-definitions**: action and feedback schemas (needed first)
- **companion-v2-preset-category-file**: the v2 category file pattern in full
- **companion-v2-add-preset-to-category-file**: adding presets after migration

## References

- `references/dynamic-presets.md`: template groups, kept loops, callback builders, families fed by several sources
- `references/tests.md`: `capturePresets()` helper, test rewrites, guard tests
- [API 2.0 changes — Presets overhaul](https://companion.free/for-developers/module-development/api-changes/v2.0)
- [Presets (API 2.x)](https://companion.free/for-developers/module-development/connection-basics/presets)
