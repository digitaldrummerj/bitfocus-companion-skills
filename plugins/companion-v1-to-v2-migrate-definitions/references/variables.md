# Variables: v1 → v2 details

This file supports **companion-v1-to-v2-migrate-definitions** Part D. All code compiles against `@companion-module/base` 2.1.3. For the v2 API itself, see **companion-v2-variable-definition** and **companion-v2-variable-set-value**.

## Literal conversion of a definitions builder

```ts
// Before (v1)
const variables: CompanionVariableDefinition[] = [
	{ variableId: 'zoomVersion', name: 'Zoom version' },
	{ variableId: 'callStatus', name: 'Call status' },
]
for (let i = 1; i <= groups; i++) variables.push({ variableId: `CallersInGroup${i}`, name: `Callers in group ${i}` })
instance.setVariableDefinitions(variables)

// After (v2) — the same ids, byte-identical
import type { CompanionVariableDefinitions } from '@companion-module/base'
import type ModuleInstance from './main.js'

export type VariablesSchema = {
	zoomVersion: string
	callStatus: number
	[callersInGroup: `CallersInGroup${number}`]: string
}

export function initVariableDefinitions(instance: ModuleInstance, groups: number): void {
	const definitions: CompanionVariableDefinitions<VariablesSchema> = {
		zoomVersion: { name: 'Zoom version' },
		callStatus: { name: 'Call status' },
	}
	for (let i = 1; i <= groups; i++) definitions[`CallersInGroup${i}`] = { name: `Callers in group ${i}` }
	instance.setVariableDefinitions(definitions)
}
```

The function name doesn't matter. Keep `initVariableDefinitions` if tests or other code call it; only the object shape changes.

## Catalog- or list-driven modules

Some modules derive both definitions and values from a single list, for example `buildVariableCatalog(): { variableId, name, value }[]`. Three typing rules apply.

1. **Static keys must be optional.** `CompanionVariableDefinitions<Schema>` maps every schema key to a **required** property. Building it incrementally (`const d = {}` followed by `d[spec.variableId] = …`) fails with `Property 'connection_status' is missing`. Mark the static ids optional (`connection_status?: …`). A misspelled id still fails to compile, because it matches neither a static key nor a template-literal family.
2. **Use one value type for every key when writes go through a union key.** `changed[spec.variableId] = spec.value` requires the value to be assignable to the *intersection* of every property type it could hit. Precise per-key types (`connected: boolean`, `viewers: number`) make every such write an error. Give all keys a shared type such as `string | number | boolean`. Precise per-key types only work when every write uses a literal key.
3. **A template-literal family must be at least as wide as what the code builds.** If prefixes come from a const table, derive the prefix union from that table and make the helpers generic on it. A helper typed `prefix: string` produces `` `${string}_…` ``, which does not fit `` `${SlotPrefix}_…` ``.

```ts
import type { CompanionVariableDefinitions } from '@companion-module/base'

const SLOT_FAMILIES = {
	scene: { prefix: 'scene', label: 'Scene' },
	overlay: { prefix: 'overlay', label: 'Overlay' },
} as const
type SlotPrefix = (typeof SLOT_FAMILIES)[keyof typeof SLOT_FAMILIES]['prefix']

export type VarValue = string | number | boolean

export type VariablesSchema = {
	connection_status?: VarValue
	viewers?: VarValue
	[slotName: `${SlotPrefix}_${string}_name`]: VarValue
}

type VariableId = keyof VariablesSchema & string
interface VariableSpec {
	variableId: VariableId
	name: string
	value: VarValue
}

function slotSpecs<P extends SlotPrefix>(family: { prefix: P; label: string }, count: number): VariableSpec[] {
	const out: VariableSpec[] = []
	for (let i = 1; i <= count; i++) {
		const n = String(i).padStart(3, '0')
		out.push({ variableId: `${family.prefix}_${n}_name`, name: `${family.label} ${n} name`, value: '' })
	}
	return out
}

export function buildCatalog(): VariableSpec[] {
	return [
		{ variableId: 'connection_status', name: 'Connection status', value: 'disconnected' },
		{ variableId: 'viewers', name: 'Viewers', value: 0 },
		...slotSpecs(SLOT_FAMILIES.scene, 50),
		...slotSpecs(SLOT_FAMILIES.overlay, 50),
	]
}

export function definitionsFromCatalog(): CompanionVariableDefinitions<VariablesSchema> {
	const definitions: CompanionVariableDefinitions<VariablesSchema> = {}
	for (const spec of buildCatalog()) definitions[spec.variableId] = { name: spec.name }
	return definitions
}

export function valuesFromCatalog(): Partial<VariablesSchema> {
	const changed: Partial<VariablesSchema> = {}
	for (const spec of buildCatalog()) changed[spec.variableId] = spec.value
	return changed
}
```

## Families with no fixed shape

If a family of ids has no stable pattern, the last resort is `[k: string]: string | number | undefined`. It keeps the code compiling but gives up typo checking for every key.
