# Preset tests after the v2 migration

Companion to **companion-v1-to-v2-migrate-presets** Step 6.

## Capturing the two-argument call

Tests that captured `setPresetDefinitions` must now read two arguments: `(structure, presets)`. Put the reading code in one helper so the rewrite from `preset.category` to placement is mechanical:

```ts
// tests/helpers/presets.ts
import type { CompanionPresetDefinitions, CompanionPresetSection } from '@companion-module/base'
import type { ModuleSchema } from '../../src/main.js'

/** Where a preset is listed in the v2 structure: its section, and the group inside it. */
export interface PresetPlacement {
	sectionId: string
	sectionName: string
	groupId: string
	groupName: string
}

export interface CapturedPresets {
	structure: CompanionPresetSection<ModuleSchema>[]
	presets: CompanionPresetDefinitions<ModuleSchema>
	/** Preset id -> where it appears. A preset missing from here is never shown by Companion. */
	placement: Map<string, PresetPlacement>
}

/** Reads the first `setPresetDefinitions(structure, presets)` call off a mocked instance. */
export function capturePresets(setPresetDefinitions: unknown): CapturedPresets {
	const [structure, presets] = (setPresetDefinitions as { mock: { calls: unknown[][] } }).mock.calls[0] as [
		CompanionPresetSection<ModuleSchema>[],
		CompanionPresetDefinitions<ModuleSchema>,
	]

	const placement = new Map<string, PresetPlacement>()
	for (const section of structure) {
		for (const entry of section.definitions) {
			const where = { sectionId: section.id, sectionName: section.name }
			if (typeof entry === 'string') {
				placement.set(entry, { ...where, groupId: '', groupName: '' })
			} else if (entry.type === 'simple') {
				for (const id of entry.presets) placement.set(id, { ...where, groupId: entry.id, groupName: entry.name })
			} else {
				placement.set(entry.presetId, { ...where, groupId: entry.id, groupName: entry.name })
			}
		}
	}

	return { structure, presets, placement }
}
```

`expect(preset.category).toBe('Scenes')` → `expect(placement.get(id)?.sectionName).toBe('Scenes')`.

## Rewrites that are easy to miss

| v1 test code | v2 | Why it matters |
|---|---|---|
| `if (preset.type !== 'button') continue` / `preset.type === 'button'` | `'simple'` | **Silent coverage loss.** Every v2 preset is `'simple'`, so a guard test that skips non-button presets now skips everything and still passes. vitest/jest strip types and never notice. Only `tsc -p tsconfig.json --noEmit` reports it (TS2367 "no overlap"). |
| `expect(preset.options.idVariable).toBeUndefined()` | `toBe('')` (or the field default) | v2 presets must set every option of an action (see the SKILL), so options the preset used to omit now carry their defaults. |
| Helpers typed `(definition: CompanionActionDefinition \| undefined, …)` | `unknown`, or the schema-specific `CompanionActionDefinition<…>` | A schema-typed definition (plus the `\| false` that `CompanionActionDefinitions` adds) is not assignable to the un-parameterised type. |

## Guard tests worth adding

These catch the structural mistakes listed under Common Mistakes in the SKILL:

```ts
it('lists every preset in exactly one group', () => {
	const { presets, structure } = capturePresets(instance.setPresetDefinitions)
	const listed = structure.flatMap((s) =>
		s.definitions.flatMap((d) => (typeof d === 'string' ? [d] : d.type === 'simple' ? d.presets : [d.presetId])),
	)
	expect(new Set(listed).size).toBe(listed.length) // no id listed twice
	expect(new Set(listed)).toEqual(new Set(Object.keys(presets))) // every id listed, every listed id exists
})

it('uses unique section and group ids', () => {
	const { structure } = capturePresets(instance.setPresetDefinitions)
	const ids = structure.flatMap((s) => [s.id, ...s.definitions.flatMap((d) => (typeof d === 'string' ? [] : [d.id]))])
	expect(new Set(ids).size).toBe(ids.length)
})
```
