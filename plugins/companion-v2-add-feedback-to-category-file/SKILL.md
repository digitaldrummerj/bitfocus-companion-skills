---
name: companion-v2-add-feedback-to-category-file
description: '(@companion-module/base v2.x) Add one or more feedbacks to an existing v2 feedback category file (src/feedbacks/feedback-{category}.ts): add the enum member, the schema entry (type + options) and the definition, then trigger it with checkFeedbacks. Use when you need to extend feedbacks in an existing category file or grow the feedback list of a v2 module. Does NOT apply when no feedback category file exists yet — use companion-v2-feedback-file-pattern; for v1 modules use companion-add-feedback-to-category-file.'
license: MIT
---

# Companion v2 Add Feedback to Category File

> **API level:** base ~2.1.x. Items marked **2.1+ (Companion 5.0+)** are not available in base 2.0.x.
>
> `instance.state.clipping` stands in for your module's own state on `ModuleInstance`.

Add a feedback to an **existing** v2 feedback category file. There are three edits in that file, plus a `checkFeedbacks` call wherever the state it watches changes. The aggregator doesn't change.

## When to Use This Skill

### ✅ Use when:

- Adding one or more feedbacks to an existing `src/feedbacks/feedback-{category}.ts`
- The file already exports `FeedbackId{Category}`, `FeedbacksSchema{Category}` and `GetFeedbacks{Category}()`

### ❌ Do NOT use when:

- No category file exists yet → use **`companion-v2-feedback-file-pattern`**
- The module is on base v1.x → use **`companion-add-feedback-to-category-file`**
- Renaming or removing a released feedback → add an upgrade script (**`companion-v2-upgrades`**)

---

## The Pattern

### Step 1 — Add an enum member

```typescript
export enum FeedbackIdMixer {
	channelMuted = 'mixer_channel_muted',
	channelLevel = 'mixer_channel_level',
	channelClipping = 'mixer_channel_clipping', // ← new
}
```

### Step 2 — Add the schema entry

```typescript
export type FeedbacksSchemaMixer = {
	[FeedbackIdMixer.channelMuted]: { type: 'boolean'; options: { channel: number } }
	[FeedbackIdMixer.channelLevel]: { type: 'value'; options: { channel: number } }
	[FeedbackIdMixer.channelClipping]: { type: 'boolean'; options: { channel: number } } // ← new
}
```

### Step 3 — Add the definition

```typescript
[FeedbackIdMixer.channelClipping]: {
	type: 'boolean',
	name: 'Channel clipping',
	defaultStyle: { bgcolor: combineRgb(255, 0, 0), color: combineRgb(255, 255, 255) },
	options: [{ id: 'channel', type: 'number', label: 'Channel', default: 1, min: 1, max: 64 }],
	callback: (feedback) => instance.state.clipping[feedback.options.channel] ?? false,
},
```

### Step 4 — Trigger it

Where the device reports the state change:

```typescript
instance.state.clipping[ch] = true
instance.checkFeedbacks(FeedbackIdMixer.channelClipping)
```

Pass the **enum member**. A string literal won't type-check against the enum-keyed schema, and `checkFeedbacks()` with no arguments was removed in v2.

#### Feedback types

| `type` | Definition must have | Callback returns |
|---|---|---|
| `'boolean'` (preferred) | `defaultStyle` | `boolean` |
| `'value'` | — | any `JsonValue` |
| `'advanced'` (discouraged) | `affectedProperties` (**2.1+ (Companion 5.0+)**; omit on 2.0.x) | style object (+ base64 `imageBuffer`) |

The schema's `type` must equal the definition's `type`.

---

## Accessing State in Callbacks

```typescript
callback: (feedback) => {
	// feedback.options is typed by the schema and already expression/variable-parsed
	// feedback.previousOptions is the previous option set (or null on first run)
	return instance.state.muted[feedback.options.channel] ?? false
},
```

There is no feedback `subscribe` in v2. If a feedback needs the device to start sending data, do that in `callback` (compare `previousOptions`) and stop it in `unsubscribe`.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Schema entry missing `type` | Add `type: 'boolean' \| 'value' \| 'advanced'` |
| Definition `type` differs from the schema `type` | Make them identical |
| Feedback never updates | Call `instance.checkFeedbacks(FeedbackIdX.y)` when the state changes |
| `context.parseVariablesInString` in the callback | Removed. Options are pre-parsed |
| Casting `feedback.options.x as number` | Unnecessary. Fix the schema instead |
| Duplicate option `id` | **2.1+ (Companion 5.0+)** drops duplicates with a warning |

## References

- **`companion-v2-feedback-file-pattern`** — create a new category file
- **`companion-v2-feedbacks`** — full v2 feedback API
- **`companion-v2-add-preset-to-category-file`** — use the feedback in a preset
- **`companion-v2-api-compliance`** — review checklist
- **`companion-add-feedback-to-category-file`** — the v1 equivalent
