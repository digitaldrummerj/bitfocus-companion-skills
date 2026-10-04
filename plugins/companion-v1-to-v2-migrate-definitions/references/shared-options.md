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

## 6. A shared array of fields spread into many actions

v1 modules often spread one array (`ROOM_TARGET_OPTIONS: SomeCompanionActionInputField[]`) into dozens of actions. Type the array with the **union of its literal ids**, and export the matching option-values type so that schemas can reuse it:

```ts
import type { CompanionActionDefinitions, SomeCompanionActionInputField } from '@companion-module/base'

export type RoomTargetOptions = { scope: string; room: string }

export const ROOM_TARGET_OPTIONS: SomeCompanionActionInputField<keyof RoomTargetOptions>[] = [
	{
		id: 'scope',
		type: 'dropdown',
		label: 'Scope',
		choices: [
			{ id: 'all', label: 'All rooms' },
			{ id: 'target', label: 'One room' },
		],
		default: 'all',
		disableAutoExpression: true, // referenced by isVisibleExpression below
	},
	{
		id: 'room',
		type: 'textinput',
		label: 'Room',
		default: '',
		useVariables: true,
		isVisibleExpression: '$(options:scope) == "target"',
	},
]
```

A schema entry is then `{ options: RoomTargetOptions }`, or `{ options: RoomTargetOptions & { number: string } }` for actions that add fields. Use `options: [...ROOM_TARGET_OPTIONS, { id: 'number', … }]` in the definition.

## 7. Factories that return a **callback**

A v1 helper such as `roomCommand(instance, '/mute')` that returns a callback needs a generic over the options. TypeScript infers it from the definition the callback is assigned to, so the call sites stay unchanged:

```ts
type Sender = { sendCommand(path: string, ...args: (string | number)[]): void }

export function roomCommand<TOptions extends RoomTargetOptions>(
	instance: Sender,
	cmd: string,
	extraArgs?: (options: TOptions) => (string | number)[],
): (action: { options: TOptions }) => void {
	return (action) => {
		instance.sendCommand(cmd, action.options.scope, action.options.room, ...(extraArgs?.(action.options) ?? []))
	}
}

export enum ActionIdRoom {
	mute = 'room_mute',
	dial = 'room_dial',
}

export type ActionsSchemaRoom = {
	[ActionIdRoom.mute]: { options: RoomTargetOptions }
	[ActionIdRoom.dial]: { options: RoomTargetOptions & { number: string } }
}

export function GetActionsRoom(instance: Sender): CompanionActionDefinitions<ActionsSchemaRoom> {
	return {
		[ActionIdRoom.mute]: { name: 'Mute', options: [...ROOM_TARGET_OPTIONS], callback: roomCommand(instance, '/mute') },
		[ActionIdRoom.dial]: {
			name: 'Dial',
			options: [...ROOM_TARGET_OPTIONS, { id: 'number', type: 'textinput', label: 'Number', default: '', useVariables: true }],
			callback: roomCommand(instance, '/dial', (o) => [o.number]), // o is inferred as the dial options
		},
	}
}
```

## 8. Composing `isVisible` functions into one `isVisibleExpression`

A v1 `.map()` that wrapped each field's `isVisible` (`(o) => o.scope === 'target' && field.isVisible(o)`) becomes **string** composition:

```ts
const inner = field.isVisibleExpression
const isVisibleExpression = inner ? `$(options:scope) == "target" && (${inner})` : '$(options:scope) == "target"'
```

Every field referenced by the expression needs `disableAutoExpression: true` (B.4).

## 9. A helper generic over the **option key**

A helper that builds a definition for one of several option keys fails with TS2322 when the field is typed `SomeCompanionFeedbackInputField<TKey>`, because `StringKeys<…>` doesn't reduce for a generic. Use `Extract<TKey, string>`, and pass the key separately to index the options:

```ts
import type { CompanionBooleanFeedbackDefinition, SomeCompanionFeedbackInputField } from '@companion-module/base'

export function thresholdFeedback<TKey extends 'level' | 'gain'>(
	key: TKey,
	option: SomeCompanionFeedbackInputField<Extract<TKey, string>>,
	read: () => number,
): CompanionBooleanFeedbackDefinition<Record<TKey, number>> {
	return {
		type: 'boolean',
		name: 'Above threshold',
		defaultStyle: { bgcolor: 0xff0000 },
		options: [option],
		callback: (feedback) => read() >= feedback.options[key],
	}
}
```

## 10. Small rules that are easy to miss

- **Use the field's `id` as the schema key, not the key in the options map.** For example, `options.channel = { id: 'number', … }` gives the schema key `number`.
- **Option keys are plain string literals**, even when the option id happens to equal a feedback enum value. Write `on: boolean`, not `[FeedbackId.on]: boolean`: a field with `id: 'on'` is not assignable to the enum member type.
- **A factory that derives its ids from a parameter** (`${id}UseVariable`, `${id}Variable`) needs a template-literal key type (`` type Keys<T extends string> = T | `${T}UseVariable` | `${T}Variable` ``). If no caller actually overrides the id, drop the parameter instead. The stored ids don't change.
