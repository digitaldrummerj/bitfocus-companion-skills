---
name: companion-v2-feedback-file-pattern
description: '(@companion-module/base v2.x) Creates a new v2 feedback category file (src/feedbacks/feedback-{category}.ts with an enum of feedback IDs, an enum-keyed FeedbacksSchema{Category} type and a GetFeedbacks{Category}() factory) and wires it into the feedbacks.ts aggregator whose FeedbacksSchema feeds ModuleSchema. Use when asked to add a feedback category, create a feedback file, or split feedbacks.ts into category files in a v2 module, i.e. when no feedback category file exists yet for the category. Does NOT apply when the category file already exists — use companion-v2-add-feedback-to-category-file; for v1 modules use companion-feedback-file-pattern.'
license: MIT
---

# Companion v2 Feedback File Pattern

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x. The file template below is 2.0-compatible.

The feedback version of **`companion-v2-action-file-pattern`**. Each feedback category gets its own file that exports an enum of IDs, a schema type and a factory. `feedbacks.ts` combines the schemas with `&` and spreads the factories into one `setFeedbackDefinitions()` call.

## When to Use This Skill

### ✅ Use this skill when:

- Adding a **new** feedback category that has no `src/feedbacks/feedback-{category}.ts` yet
- Splitting a large single-file `feedbacks.ts` into category files
- Wiring a new feedback file into the aggregator for the first time

### ❌ Do NOT use this skill when:

- The category file already exists → use **`companion-v2-add-feedback-to-category-file`**
- The module is on base v1.x → use **`companion-feedback-file-pattern`**
- Converting v1 feedback code → use **`companion-v1-to-v2-migrate-definitions`**

## Pattern Overview

```
src/
  main.ts                           ← ModuleSchema { feedbacks: FeedbacksSchema, … }
  feedbacks.ts                      ← aggregator: FeedbacksSchema = A & B; UpdateFeedbacks(instance)
  feedbacks/
    feedback-{category-a}.ts        ← enum FeedbackId{A} + FeedbacksSchema{A} + GetFeedbacks{A}()
    feedback-{category-b}.ts
    feedback-utils.ts               ← optional shared styles / option factories
```

---

## Pattern 0 — Shared helpers (`feedback-utils.ts`, optional)

Put styles and option fields that several categories reuse here:

```typescript
import { combineRgb, type CompanionFeedbackButtonStyleResult, type SomeCompanionFeedbackInputField } from '@companion-module/base'

export const styleActive: CompanionFeedbackButtonStyleResult = {
	bgcolor: combineRgb(0, 200, 0),
	color: combineRgb(255, 255, 255),
}

export function channelOption(): SomeCompanionFeedbackInputField<'channel'> {
	return { id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64, asInteger: true }
}
```

Return a **new object** from each option factory. Reusing one shared object across definitions is fragile if anything mutates it.

---

## Pattern 1 — The Feedback File

```typescript
import { combineRgb, type CompanionFeedbackDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'

export enum FeedbackIdTransport {
	playing = 'transport_playing',
	level = 'transport_level',
	status = 'transport_status',
}

export type FeedbacksSchemaTransport = {
	[FeedbackIdTransport.playing]: { type: 'boolean'; options: Record<string, never> }
	[FeedbackIdTransport.level]: { type: 'value'; options: { channel: number } }
	[FeedbackIdTransport.status]: { type: 'advanced'; options: { showText: boolean } }
}

export function GetFeedbacksTransport(
	instance: ModuleInstance,
): CompanionFeedbackDefinitions<FeedbacksSchemaTransport> {
	return {
		[FeedbackIdTransport.playing]: {
			type: 'boolean',
			name: 'Playing',
			defaultStyle: { bgcolor: combineRgb(0, 200, 0), color: combineRgb(255, 255, 255) },
			options: [],
			callback: () => instance.state.playing,
		},
		[FeedbackIdTransport.level]: {
			type: 'value',
			name: 'Level',
			options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
			callback: (feedback) => (feedback.options.channel === 1 ? instance.state.level : null),
		},
		[FeedbackIdTransport.status]: {
			type: 'advanced',
			name: 'Status colour',
			options: [{ id: 'showText', type: 'checkbox', label: 'Show text', default: true }],
			affectedProperties: ['bgcolor', 'text'], // 2.1+ (Companion 5.0+): required key. Delete this line on 2.0.x
			callback: (feedback) => ({
				bgcolor: instance.state.playing ? combineRgb(0, 200, 0) : combineRgb(200, 0, 0),
				text: feedback.options.showText ? 'PLAY' : undefined,
			}),
		},
	}
}
```

| Part | Notes |
|---|---|
| `enum FeedbackId{Category}` | The string values are stored in users' buttons. Keep them globally unique and stable |
| `type FeedbacksSchema{Category}` | Every entry needs `type` (`'boolean'`, `'value'` or `'advanced'`) **and** `options` |
| `GetFeedbacks{Category}(instance)` | Returns `CompanionFeedbackDefinitions<FeedbacksSchema{Category}>` |
| `import type ModuleInstance` | Type-only, so there is no runtime cycle. Replaces v1's `InstanceBaseExt` |

---

## Pattern 2 — The Aggregator (`feedbacks.ts`)

```typescript
import type ModuleInstance from './main.js'
import { GetFeedbacksTransport, type FeedbacksSchemaTransport } from './feedbacks/feedback-transport.js'
import { GetFeedbacksMixer, type FeedbacksSchemaMixer } from './feedbacks/feedback-mixer.js'

export type FeedbacksSchema = FeedbacksSchemaTransport & FeedbacksSchemaMixer

export function UpdateFeedbacks(instance: ModuleInstance): void {
	instance.setFeedbackDefinitions({
		...GetFeedbacksTransport(instance),
		...GetFeedbacksMixer(instance),
	})
}
```

`main.ts` puts `FeedbacksSchema` into `ModuleSchema.feedbacks`. Every `instance.checkFeedbacks(...)` call is then checked against these IDs, so pass enum members:

```typescript
this.checkFeedbacks(FeedbackIdTransport.playing, FeedbackIdMixer.channelMuted)
```

---

## Pattern 3 — Step-by-Step Recipe

### 1. Create `src/feedbacks/feedback-{category}.ts`

### 2. File template

```typescript
import { combineRgb, type CompanionFeedbackDefinitions } from '@companion-module/base'
import type ModuleInstance from '../main.js'

export enum FeedbackId{Category} {
	isActive = '{category}_is_active',
}

export type FeedbacksSchema{Category} = {
	[FeedbackId{Category}.isActive]: { type: 'boolean'; options: { index: number } }
}

export function GetFeedbacks{Category}(instance: ModuleInstance): CompanionFeedbackDefinitions<FeedbacksSchema{Category}> {
	return {
		[FeedbackId{Category}.isActive]: {
			type: 'boolean',
			name: 'Is active',
			defaultStyle: { bgcolor: combineRgb(0, 200, 0), color: combineRgb(255, 255, 255) },
			options: [{ id: 'index', type: 'number', label: 'Index', default: 1, min: 1, max: 100 }],
			callback: (feedback) => instance.isActive(feedback.options.index), // isActive: your own helper on ModuleInstance
		},
	}
}
```

### 3. Import it in `feedbacks.ts`

```typescript
import { GetFeedbacks{Category}, type FeedbacksSchema{Category} } from './feedbacks/feedback-{category}.js'
```

### 4. Add the schema to the intersection

```typescript
export type FeedbacksSchema = FeedbacksSchemaTransport & FeedbacksSchemaMixer & FeedbacksSchema{Category}
```

### 5. Spread the factory

```typescript
instance.setFeedbackDefinitions({
	...GetFeedbacksTransport(instance),
	...GetFeedbacksMixer(instance),
	...GetFeedbacks{Category}(instance), // ← add
})
```

### 6. Trigger it from state changes

Wherever the relevant state changes: `instance.checkFeedbacks(FeedbackId{Category}.isActive)`.

### 7. Build and verify

```bash
yarn build
yarn lint
```

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Schema entry missing `type` | Every feedback schema entry needs `type` and `options` |
| `checkFeedbacks('raw_id')` | Use the enum member. Raw strings don't satisfy an enum-keyed schema |
| `checkFeedbacks()` with no args | Use `checkAllFeedbacks()` |
| `subscribe` on a feedback | Removed in v2. Use `callback` + `previousOptions`, and `unsubscribe` for cleanup |
| Advanced feedback without `affectedProperties` (**2.1+ (Companion 5.0+)**) | Add it, e.g. `['bgcolor', 'color']` |
| Value import of `ModuleInstance` | Use `import type` |
| Moved feedbacks out of an old single file but left their ids there too | Remove them from the old enum or schema, otherwise duplicate keys conflict |

## References

- **`companion-v2-feedbacks`** — full v2 feedback API
- **`companion-v2-add-feedback-to-category-file`** — extend an existing category
- **`companion-v2-action-file-pattern`** — the matching action pattern
- **`companion-v2-api-compliance`** — review checklist
- **`companion-feedback-file-pattern`** — the v1 equivalent
