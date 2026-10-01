---
name: companion-v2-feedbacks
description: '(@companion-module/base v2.x) API reference for v2 feedback definitions: boolean/value/advanced types, typed feedback schemas, checkFeedbacks(id, …) vs checkAllFeedbacks(), the callback/unsubscribe lifecycle with previousOptions, base64 imageBuffer, learn, and (2.1+) affectedProperties and abort signals. Use when choosing a feedback type, triggering re-evaluation, or debugging feedback lifecycle behaviour in a v2 module. For the file edits use companion-v2-add-feedback-to-category-file (existing category file) or companion-v2-feedback-file-pattern (new category file). Does NOT apply to v1 modules (use companion-feedbacks).'
license: MIT
---

# Companion v2 Feedbacks Skill

The API reference for **feedbacks** in `@companion-module/base` **v2.x**. The file layout is covered in **`companion-v2-feedback-file-pattern`**.

> **API level:** examples target base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.
>
> Examples call module-specific members on `ModuleInstance` (`sendCommand`, `state`, `query`). Define your own equivalents as public class members (see **companion-v2-module-scaffold**).

## When to Use This Skill

- Defining boolean, value or advanced feedbacks in a v2 module
- Typing feedback options with a schema
- Re-evaluating feedbacks when device state changes
- Cleaning up per-feedback subscriptions

---

## Key API Types

### Feedback schema

Each feedback declares its **type** and option types:

```typescript
export type FeedbacksSchemaMixer = {
	[FeedbackIdMixer.channelMuted]: { type: 'boolean'; options: { channel: number } }
	[FeedbackIdMixer.channelLevel]: { type: 'value'; options: { channel: number } }
	[FeedbackIdMixer.meterImage]: { type: 'advanced'; options: { channel: number } }
}
```

The schema `type` must match the definition's `type`. It also controls what presets may attach: a preset's `style` is **required** on boolean feedbacks and **forbidden** on value and advanced feedbacks.

### Feedback types

| Type | Callback returns | Use for |
|---|---|---|
| `'boolean'` | `boolean` | **Preferred.** Companion applies `defaultStyle`, and the user can override it and invert it |
| `'value'` | any `JsonValue` | Exposing a value (number, string, object, data-URI image) for expressions, local variables and layered graphics |
| `'advanced'` | partial style + optional `imageBuffer` | Discouraged and likely to be removed in a future major. Prefer boolean or value feedbacks, or layered presets |

### Lifecycle (changed in v2)

| Hook | When it runs |
|---|---|
| `callback(feedback, context)` | When the feedback is added, whenever its options change, and whenever you call `checkFeedbacks` |
| `unsubscribe?(feedback, context)` | Only when the feedback is **deleted or disabled** |
| `learn?(feedback, context)` | User clicked *Learn*. Return **only** the learned options |

There is **no `subscribe`** on feedbacks in v2. Do setup work in `callback`, and use `feedback.previousOptions` to detect what changed.

### Re-checking

```typescript
instance.checkFeedbacks(FeedbackIdTransport.playing, FeedbackIdMixer.channelMuted) // one or more ids
instance.checkAllFeedbacks() // everything (e.g. after reconnect)
instance.checkFeedbacksById(feedbackInstanceId) // specific placed instances
```

`checkFeedbacks()` with **no arguments was removed**. Its parameters are typed as keys of `ModuleSchema['feedbacks']`, so pass enum members. A raw string literal like `'transport_playing'` does **not** type-check against an enum-keyed schema.

When the ids to re-check are collected at runtime, type the collection with the union of your feedback enums, and split off the first element, because the signature requires at least one id:

```typescript
// feedbacks.ts, next to FeedbacksSchema
export type AnyFeedbackId = FeedbackIdTransport | FeedbackIdMixer

// wherever ids are collected
const [first, ...rest] = changedIds // Set<AnyFeedbackId> or AnyFeedbackId[]
if (first !== undefined) instance.checkFeedbacks(first, ...rest)
```

---

## Patterns & Examples

### Boolean feedback

```typescript
[FeedbackIdTransport.playing]: {
	type: 'boolean',
	name: 'Playing',
	defaultStyle: { bgcolor: combineRgb(0, 200, 0), color: combineRgb(255, 255, 255) },
	options: [],
	callback: () => instance.state.playing,
},
```

`showInvert` defaults to on, so Companion adds an *Inverted* checkbox. Set `showInvert: false` when inverting makes no sense.

### Boolean feedback with options, previousOptions, unsubscribe and learn

```typescript
[FeedbackIdMixer.channelMuted]: {
	type: 'boolean',
	name: 'Channel muted',
	description: 'Change style when the channel is muted',
	defaultStyle: { bgcolor: combineRgb(255, 0, 0), color: combineRgb(255, 255, 255) },
	options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
	callback: (feedback) => {
		if (feedback.previousOptions && feedback.previousOptions.channel !== feedback.options.channel) {
			instance.sendCommand('/subscribe', feedback.options.channel)
		}
		return instance.state.muted[feedback.options.channel] ?? false
	},
	unsubscribe: (feedback) => {
		instance.sendCommand('/unsubscribe', feedback.options.channel)
	},
	learn: () => ({ channel: 1 }),
},
```

`feedback.options` is typed and **already parsed**: expressions are evaluated and variables substituted. Don't cast it.

### Value feedback

```typescript
[FeedbackIdMixer.channelLevel]: {
	type: 'value',
	name: 'Channel level',
	options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
	callback: async (feedback) => instance.query(`/ch/${feedback.options.channel}/level`),
},
```

On **2.1+ (Companion 5.0+)**, pass the abort signal through: `callback: async (feedback, context) => instance.query(path, context.signal)` (see "Abort signal" below).

Value feedbacks drive preset local variables (`variableType: 'feedback'`, **2.1+ (Companion 5.0+)**) and layered-preset graphics, such as a gauge bound to `$(local:level)` (**2.1+ (Companion 5.0+)**). On 2.0.x, use them in expressions.

### Advanced feedback

```typescript
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
```

> **2.1+ (Companion 5.0+)** — `affectedProperties` is a **required key** in the 2.1 typings (its value may be `undefined`). Companion logs a debug warning for advanced feedbacks that omit it. Allowed values: `'text' | 'size' | 'color' | 'bgcolor' | 'alignment' | 'pngalignment' | 'png64' | 'imageBuffer'`. On 2.0.x, leave it out.

### Image buffers (advanced)

```typescript
[FeedbackIdMixer.meterImage]: {
	type: 'advanced',
	name: 'Meter image',
	options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
	affectedProperties: ['imageBuffer'], // 2.1+ (Companion 5.0+): required key. Delete this line on 2.0.x
	callback: (feedback) => {
		if (!feedback.image) return {}
		const { width, height } = feedback.image
		const pixels = Buffer.alloc(width * height * 4)
		return {
			imageBuffer: pixels.toString('base64'), // v2: must be a base64 string, not a Buffer (Uint8Array: Buffer.from(u8).toString('base64'))
			imageBufferEncoding: { pixelFormat: 'RGBA' },
			imageBufferPosition: { x: 0, y: 0, width, height },
		}
	},
},
```

Before generating bitmaps, consider a **value feedback plus a layered preset**, or a **composite element** (**2.1+ (Companion 5.0+)**). Both scale better and are editable by users.

### Abort signal

> **2.1+ (Companion 5.0+)** — `context.signal` aborts when a re-check is queued while the callback is still running. If you honour it, throw; Companion ignores the error and runs a fresh check. Short synchronous callbacks can ignore it.

### Triggering updates from device events

```typescript
// in your connection / message handler
instance.state.muted[ch] = muted
instance.checkFeedbacks(FeedbackIdMixer.channelMuted)

// on (re)connect, when all state may have changed
instance.checkAllFeedbacks()
```

---

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| `instance.checkFeedbacks()` with no args | Removed. Use `checkAllFeedbacks()` or pass ids |
| `checkFeedbacks('my_feedback_id')` fails to compile | Pass the enum member: `checkFeedbacks(FeedbackIdX.myFeedback)` |
| `subscribe:` on a feedback | Removed in v2. Move setup into `callback` (using `previousOptions`), and keep cleanup in `unsubscribe` |
| `context.parseVariablesInString(...)` in a callback | Removed. Options arrive parsed. Use `useVariables: true` on `textinput` fields |
| `imageBuffer: buffer` (a Buffer) | Must be `buffer.toString('base64')` |
| Advanced feedback without `affectedProperties` on 2.1 | Compile error / debug warning. Declare the properties you set |
| `affectedProperties` on base 2.0.x | Not in the 2.0 types (excess-property error). Only add it on **2.1+ (Companion 5.0+)** |
| `checkFeedbacks(...ids)` with a runtime `string[]` | Type the list as `AnyFeedbackId[]` and split off the first id |
| `learn` returns every option | Return only learned keys, so user expressions survive |
| Schema `type` doesn't match the definition `type` | They must match. Presets rely on it |

## Import Reference

```typescript
import { combineRgb, type CompanionFeedbackDefinitions, type CompanionFeedbackDefinition } from '@companion-module/base'
import type ModuleInstance from '../main.js'
```

## Related Skills

- **`companion-v2-feedback-file-pattern`** — create a feedback category file and wire `feedbacks.ts`
- **`companion-v2-add-feedback-to-category-file`** — extend an existing category file
- **`companion-v2-preset-category-file`** — attach feedbacks to preset buttons (style, styleOverrides, local variables)
- **`companion-v2-actions`** — the action side of the API
- **`companion-v2-api-compliance`** — review checklist
- **`companion-feedbacks`** — the v1 equivalent
