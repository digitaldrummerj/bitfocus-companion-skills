# Shared options, option factories and definition helpers (v1 → v2)

This file supports **companion-v1-to-v2-migrate-definitions** B.2. All code compiles against `@companion-module/base` 2.1.3.

In v2 the `options` array of an action or feedback is typed `SomeCompanionActionInputField<'key1' | 'key2' | ...>`, where the keys come from the schema. A field whose `id` is typed as plain `string` therefore fails:

```
TS2322: Type 'CompanionInputFieldTextInput<string>' is not assignable to type 'SomeCompanionActionInputField<"userName">'.
```

Each pattern below is a different way to give a shared field its **literal id type**.

## 1. Standalone constants

```ts
import type {
	CompanionInputFieldDropdown,
	CompanionInputFieldTextInput,
	CompanionInputFieldNumber,
} from '@companion-module/base'

// v2: give shared option constants a literal id type so they fit any schema that declares that key
export const userNameOption: CompanionInputFieldTextInput<'userName'> = {
	id: 'userName',
	type: 'textinput',
	label: 'User name',
	default: '',
	useVariables: true,
}

export const positionOption: CompanionInputFieldNumber<'position'> = {
	id: 'position',
	type: 'number',
	label: 'Position',
	default: 1,
	min: 1,
	max: 49,
	asInteger: true,
}

export const modeOption: CompanionInputFieldDropdown<'mode'> = {
	id: 'mode',
	type: 'dropdown',
	label: 'Mode',
	choices: [
		{ id: 'auto', label: 'Auto' },
		{ id: 'manual', label: 'Manual' },
	],
	default: 'auto',
	disableAutoExpression: true,
}
```

## 2. Keep an existing `options` map, using `satisfies`

This leaves call sites like `options.userName` unchanged:

```ts
export const options = {
	userName: {
		id: 'userName',
		type: 'textinput',
		label: 'User name',
		default: '',
		useVariables: true,
	} satisfies CompanionInputFieldTextInput<'userName'>,
	feedbackKind: {
		id: 'type',
		type: 'dropdown',
		label: 'Type of feedback',
		default: feedbackType.selected,
		choices: [
			{ id: feedbackType.selected, label: 'Selected' },
			{ id: feedbackType.micLive, label: 'Mic Live' },
		],
	} satisfies CompanionInputFieldDropdown<'type', feedbackType>,
}
```

After converting, delete the old `interface Options { userName: EnforceDefault<CompanionInputFieldTextInput, string> ... }`.

## 3. Option **factories** (functions that build fields)

Two rules make factories type-check:

- A factory that takes the id as a parameter needs a **generic key**.
- A factory that returns several fields declares a **literal-union** key and exports the matching **option-values type**, so schemas can reuse it.

```ts
import type {
	CompanionInputFieldCheckbox,
	CompanionInputFieldDropdown,
	CompanionInputFieldTextInput,
	DropdownChoice,
} from '@companion-module/base'

// generic key: the caller's literal id flows into the field type
export function deviceDropdown<TKey extends string>(
	id: TKey,
	label: string,
	choices: DropdownChoice[],
): CompanionInputFieldDropdown<TKey> {
	return { type: 'dropdown', id, label, choices, default: choices[0]?.id ?? '', allowCustom: true }
}

// several fields: a literal-union key, plus the values type the schemas reuse
export type DeviceIdOptionKey = 'useVariable' | 'id' | 'idVariable'
export type DeviceIdOptions = { useVariable: boolean; id: string; idVariable: string }

// fields valid in both actions and feedbacks (only actions allow custom-variable)
type SharedInputField<TKey extends string> =
	| CompanionInputFieldCheckbox<TKey>
	| CompanionInputFieldDropdown<TKey>
	| CompanionInputFieldTextInput<TKey>

export function deviceIdOptions(label: string, choices: DropdownChoice[]): SharedInputField<DeviceIdOptionKey>[] {
	return [
		{ type: 'checkbox', id: 'useVariable', label: 'Use variable', default: false, disableAutoExpression: true },
		{ ...deviceDropdown('id', label, choices), isVisibleExpression: '!$(options:useVariable)' },
		{
			type: 'textinput',
			id: 'idVariable',
			label,
			default: '',
			useVariables: true,
			isVisibleExpression: '$(options:useVariable)',
		},
	]
}

// in a category file:
// [ActionIdScene.setScene]: { options: DeviceIdOptions & { fade: number } }
// options: [...deviceIdOptions('Scene', choices), { id: 'fade', type: 'number', ... }]
```

The checkbox gets `disableAutoExpression: true` because v2 only allows `isVisibleExpression` in actions and feedbacks to reference fields that cannot be expressions.

## 4. Helpers that return a whole definition

An un-parameterised `CompanionActionDefinition` (or `CompanionFeedbackDefinition`) is **not** assignable into `CompanionActionDefinitions<Schema>`. Give the helper the **schema-entry** generic instead. A local alias keeps the schema readable:

```ts
import type {
	CompanionActionDefinition,
	CompanionActionDefinitions,
	CompanionFeedbackDefinition,
	CompanionFeedbackDefinitions,
} from '@companion-module/base'
import type ModuleInstance from '../main.js'

export enum ActionIdScene {
	next = 'nextScene',
	prev = 'prevScene',
}

type NoOptions = { options: Record<string, never> }

export type ActionsSchemaScene = {
	[ActionIdScene.next]: NoOptions
	[ActionIdScene.prev]: NoOptions
}

export function GetActionsScene(instance: ModuleInstance): CompanionActionDefinitions<ActionsSchemaScene> {
	const simple = (name: string, path: string): CompanionActionDefinition<NoOptions> => ({
		name,
		options: [],
		callback: () => instance.sendCommand(path),
	})
	return {
		[ActionIdScene.next]: simple('Next scene', '/next'),
		[ActionIdScene.prev]: simple('Previous scene', '/prev'),
	}
}

// feedback helper: same idea, with the boolean schema entry
export enum FeedbackIdFlags {
	live = 'flag_live',
	muted = 'flag_muted',
}

type Flag = { type: 'boolean'; options: Record<string, never> }

export type FeedbacksSchemaFlags = { [FeedbackIdFlags.live]: Flag; [FeedbackIdFlags.muted]: Flag }

export function GetFeedbacksFlags(instance: ModuleInstance): CompanionFeedbackDefinitions<FeedbacksSchemaFlags> {
	const flag = (name: string, read: () => boolean): CompanionFeedbackDefinition<Flag> => ({
		type: 'boolean',
		name,
		defaultStyle: { bgcolor: 0xff0000 },
		options: [],
		callback: read,
	})
	return {
		[FeedbackIdFlags.live]: flag('Live', () => instance.state.playing),
		[FeedbackIdFlags.muted]: flag('Muted', () => instance.state.level === 0),
	}
}
```

> **2.0 vs 2.1:** in base 2.0.x, `CompanionActionDefinition<T>` is generic over the **options object** (`CompanionActionDefinition<Record<string, never>>`). From 2.1 it is generic over the **schema entry** (`CompanionActionDefinition<{ options: … }>`, as above). Use the form that matches the base version you target.

## 5. The v1 "Use variable" idiom

Many v1 modules paired a device dropdown with a `useVariable` checkbox and a `useVariables: true` textinput, because v1 dropdowns could not take variables. In v2 the user can switch any dropdown to expression mode, so the idiom is now redundant. You have two options:

- **Keep it (recommended during migration).** Nothing about stored options changes. Add `disableAutoExpression: true` to the checkbox, because the `isVisibleExpression` on the other two fields references it.
- **Collapse it (optional, later).** Remove the checkbox and the textinput. Ship an upgrade script that maps `{ useVariable: true, idVariable: '$(x)' }` to `id: { isExpression: true, value: 'parseVariables("$(x)")' }`, and update the presets. See **companion-v1-to-v2-expression-upgrades**.
