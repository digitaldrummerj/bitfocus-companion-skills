# Dynamic preset families and reusable builders (v1 → v2)

Companion to **companion-v1-to-v2-migrate-presets** Step 4. All code compiles against `@companion-module/base` 2.1.3. The template-group code also compiles against 2.0.x.

## Option A: template group (use this when the index can live in a local variable)

Define **one** preset that reads a local variable, and let a `template` group create the copies:

```ts
import {
	combineRgb,
	type CompanionButtonStyleProps,
	type CompanionPresetDefinitions,
	type CompanionPresetSection,
} from '@companion-module/base'
import type { ModuleSchema } from '../main.js'
import { ActionIdLevel } from '../actions/action-level.js'
import { FeedbackIdTransport } from '../feedbacks/feedback-transport.js'

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

- `templateVariableName` must match a `localVariables[].variableName` on the template preset. Each `templateValues` entry becomes one preset, and that preset's local variable starts at the entry's `value`.
- Feedback options accept the same `{ isExpression: true, value: '$(local:channel)' }` form.
- `commonVariableValues` sets the other local variables to the same value for every copy.
- The action option the expression drives must accept expressions, so it must not have `disableAutoExpression`.

## Option B: keep the loop (when the preset can't be expressed as a template)

Some presets can't be expressed as a template:

- Style text that references a **computed variable name**, such as `` `$(zoomosc:Participant${padding(index, 3)})` ``. A local variable can't build a variable name inside the style text.
- A preset whose list of feedbacks depends on the index.

For these, keep generating one `simple` preset per index and list them all in one `simple` group:

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

In a preset, only **boolean** feedbacks take `style`, and for them it is required. Value and advanced feedbacks, such as `FeedbackIdTransport.status` above, must not have one.

## Reusable builders: callbacks instead of `actionId` + loose options

Many v1 modules had generic builders such as `buildFixedPresets({ actionId, actionOptions, feedbackId, feedbackOptions })`, typed against the deleted `CompanionPresetExt`. In v2 TypeScript can't prove that a generic `{ actionId: A, options: {...} }` is assignable to the preset action union, so you would need a cast.

The cast-free fix is to have the builder take **callbacks** that return a `SomePresetActionEntry<ModuleSchema>` / `SomePresetSimpleFeedbackEntry<ModuleSchema>`. Each call site then names a concrete action, and its options are checked against that action's schema. Use `CompanionSimplePresetDefinition<ModuleSchema>` as the return type of helpers that build a single preset. It replaces v1's `CompanionButtonPresetDefinition`.

```ts
import {
	combineRgb,
	type CompanionPresetDefinitions,
	type CompanionPresetGroup,
	type CompanionPresetSection,
	type CompanionSimplePresetDefinition,
	type SomePresetActionEntry,
	type SomePresetSimpleFeedbackEntry,
} from '@companion-module/base'
import type { ModuleSchema } from '../main.js'
import { ActionIdLevel } from '../actions/action-level.js'
import { FeedbackIdTransport } from '../feedbacks/feedback-transport.js'

/** What a reusable builder hands back: groups to place in a section, and the presets they list. */
export interface PresetGroupsAndPresets {
	groups: CompanionPresetGroup<ModuleSchema>[]
	presets: CompanionPresetDefinitions<ModuleSchema>
}

/** One preset, for helpers that build a single button (replaces v1 CompanionButtonPresetDefinition). */
export function channelButton(
	channel: number,
	action: (channel: number) => SomePresetActionEntry<ModuleSchema>,
	feedback?: (channel: number) => SomePresetSimpleFeedbackEntry<ModuleSchema>,
): CompanionSimplePresetDefinition<ModuleSchema> {
	return {
		type: 'simple',
		name: `Channel ${channel}`,
		style: { text: `CH ${channel}`, size: 'auto', color: combineRgb(255, 255, 255), bgcolor: combineRgb(0, 0, 0) },
		steps: [{ down: [action(channel)], up: [] }],
		feedbacks: feedback ? [feedback(channel)] : [],
	}
}

/** Builds a "Channels" group; returns no group when there is nothing to list. */
export function buildChannelGroups(
	prefix: string,
	count: number,
	action: (channel: number) => SomePresetActionEntry<ModuleSchema>,
	feedback?: (channel: number) => SomePresetSimpleFeedbackEntry<ModuleSchema>,
): PresetGroupsAndPresets {
	const presets: CompanionPresetDefinitions<ModuleSchema> = {}
	const ids: string[] = []
	for (let ch = 1; ch <= count; ch++) {
		const id = `${prefix}_${ch}`
		presets[id] = channelButton(ch, action, feedback)
		ids.push(id)
	}
	const groups: CompanionPresetGroup<ModuleSchema>[] =
		ids.length === 0 ? [] : [{ id: `${prefix}_channels`, type: 'simple', name: 'Channels', presets: ids }]
	return { groups, presets }
}

// call sites name a concrete action, so its options are checked without a cast
const levels = buildChannelGroups(
	'level',
	8,
	(channel) => ({ actionId: ActionIdLevel.setLevel, options: { channel, level: 100 } }),
	() => ({ feedbackId: FeedbackIdTransport.playing, options: {}, style: { bgcolor: combineRgb(0, 200, 0) } }),
)

export const levelSection: CompanionPresetSection<ModuleSchema> = {
	id: 'levels',
	name: 'Levels',
	definitions: [...levels.groups],
}
export const levelPresets = levels.presets
```

## One family fed by several sources (suffix-style categories)

v1 often split one family across several categories: `'Scenes'` from a category file, `'Scenes - Fixed'` from a builder, and `'Scenes 001-050 - Dynamic'` / `'Scenes 051-100 - Dynamic'` from a chunked loop. Converting each of these literally gives three or four separate sections. Instead, make **one section per family** and put each former category in it as a **group**.

In the aggregator, append the builders' groups to the section returned by the category file:

```ts
import type { CompanionPresetGroup, CompanionPresetSection } from '@companion-module/base'

/** The groups a category file put in its section (skips bare preset-id references). */
function ownGroups(section: CompanionPresetSection<ModuleSchema> | undefined): CompanionPresetGroup<ModuleSchema>[] {
	if (!section) return []
	return section.definitions.filter((entry): entry is CompanionPresetGroup<ModuleSchema> => typeof entry !== 'string')
}

const familySection = (
	id: string,
	name: string,
	base: CompanionPresetSection<ModuleSchema> | undefined,
	...extra: PresetGroupsAndPresets[]
): CompanionPresetSection<ModuleSchema> => ({
	id: base?.id ?? id,
	name,
	definitions: [...ownGroups(base), ...extra.flatMap((e) => e.groups)],
})
```

`ownGroups` needs the type guard because `section.definitions` is `CompanionPresetGroup[] | CompanionPresetReference[]`. Remember to merge each builder's `presets` into the `presets` object as well.
