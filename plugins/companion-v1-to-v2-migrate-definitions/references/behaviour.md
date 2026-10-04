# Preserving behaviour while migrating definitions

Typing a v1 module exposes code paths that v1 hid behind casts and `[x: string]: any`. The default rule is to **preserve what v1 users experienced**. Anything that would change runtime behaviour is a **separate, flagged decision** for the maintainer: list it in the PR or report, and don't fold it silently into the migration.

## 1. `parseVariablesInString` → `useVariables: true` (silent breakage risk)

v1's `parseVariablesInString(x)` parsed **whatever string you passed**, even from a field without `useVariables`. v2 substitutes `$(…)` only in `textinput` fields that have `useVariables: true` (or a field the user switched to expression mode). Removing the call without the flag **silently breaks** users' existing variables.

- **Every** field whose value went through `parseVariablesInString` (instance **or** feedback `context`) gets `useVariables: true`. That includes shared definitions in `utils.ts`. v1 feedback textinputs very often lack the flag (lynbh-obs had 11).
- **A shared field parsed in only some actions:** turning on `useVariables` in the shared definition would change behaviour for the actions that never parsed it. Use a **same-id variant** for the parsing call sites only:
  ```ts
  export const options = {
  	message: { id: 'message', type: 'textinput', label: 'Message', default: '' } satisfies CompanionInputFieldTextInput<'message'>,
  	messageWithVariables: { id: 'message', type: 'textinput', label: 'Message', default: '', useVariables: true } satisfies CompanionInputFieldTextInput<'message'>,
  }
  ```
  The stored option id is the same (`message`), so saved buttons are unaffected. Alternatively, enable it everywhere and record that as an accepted behaviour change.
- **Guard test:** list every `(actionId, optionKey)` that v1 passed to `parseVariablesInString`, and assert that `useVariables` is set on each field at runtime. zoom-osc-iso checks 74 fields this way.
- **The reverse case:** a v1 field with `useVariables: true` whose callback **never** parsed it starts substituting variables in v2. It's usually a fix, but it is still a visible change, so record it in HELP.md and the changelog.

## 2. `textinput` → `number`: only when "empty" carries no meaning

B.3 step 2 converts number-in-a-textinput fields to `type: 'number'`. **Don't** convert when:
- an empty value means "not provided" or "use default"
- an empty value drives either/or validation with another field
- non-numeric input means "skip"

A `number` field can't be empty. In those cases, keep the `textinput` with `useVariables: true` **and keep the in-code `Number()` / `parseInt` parse**. That is real parsing, not a cast, and no upgrade script is needed.

When you **do** convert:
- **Choose bounds that never reject a value the device accepted in v1.** `min` and `max` are required. Use `asInteger: true` for indexes, and keep any in-code validation.
- **v1 `parseInt` was lenient** (`'2abc'` → 2, negatives allowed). v2 rejects invalid values and skips the action. List that as a behaviour change.
- **`FixupNumericOrVariablesValueToExpressions('')`** produces the expression `parseVariables("")`. Decide how to treat stored empty strings.
- **Sentinel values outside `min`/`max`** (e.g. `default: 0` meaning "unset" with `min: 10`) still work in literal mode. In **expression** mode, though, a computed sentinel fails validation and the action is skipped. Consider `allowInvalidValues: true` or widening `min`, and flag it.

## 3. Casts that lied about the runtime type

v1 casts were unchecked, so they often claimed the wrong type.

| v1 | v2 |
|---|---|
| `Number(action.options.x)` where `x` is a **number** field | Remove it. The value is already a number. |
| `Number(action.options.x)` / `parseInt` where `x` **stays a textinput** | Keep it. It is parsing (often with an `isNaN` skip), not a cast. |
| Parse-and-fallback helpers: `optionNumber(x, 100)`, `optionString(x, ALL)` | `x ?? 100` / `x ?? ALL`. Keep the fallback, drop the parse, and delete the helper once unused. |
| `action.options.group as number` on a dropdown whose choice ids are **strings** (`'1'`) | The runtime value was always a string. Where it only feeds indexing, arithmetic or template strings, `Number(x)` gives the same result. Where it feeds **strict comparisons** (`=== zoomId`), typed parameters or **OSC arguments**, converting changes behaviour, so decide explicitly. To preserve v1 exactly, use `x as unknown as number` with a comment. Presets must set these fields as strings (`String(index)`). |
| `const n = options.sceneCollection as number` used as an array index | `Number(options.sceneCollection)` (TS7015 otherwise) |

## 4. Members `[x: string]: any` used to hide

Replacing `InstanceBaseExt` with `ModuleInstance` (A.2) makes `tsc` list every member the callbacks touch. Some of them are not just undeclared:

- **The member doesn't exist on the class at all** (e.g. `instance.getMatrixSelections()`), or it is a **typo** (`instance.zoomUserData` vs `ZoomUserData`). This is a pre-existing v1 bug: the call threw, or the value was always `undefined`. **Don't invent an implementation.** To preserve behaviour, keep it behind a cast with a `// v1 bug: …` comment, or drop a dead path that could never run. Fixing it is a separate, flagged change.
- **Loose `any` fields become precise.** `socket: any` turns into `TCPHelper | null`, and that exposes null paths (`instance.socket.isConnected` on `null`), which threw a TypeError in v1. Prefer the behaviour-preserving cast, or make a flagged fix (`?.`).

## 5. Options that v1 presets omitted

The B.1 rule says to keep existing `?? default` guards. If a v1 preset shipped **without** an option and the v1 callback had **no** guard (so it threw), adding a guard changes the behaviour from "throws" to "no-op or default". Record it as a decision rather than adding the guard silently. Pin the current behaviour with a test either way.

## 6. Values written but never defined

Variables that v1 wrote with `setVariableValues` but never defined (relying on `disableVariableValidation`) must be in `VariablesSchema` so the writes compile. Add them as **optional** keys. Actually defining them makes them show up in the variable picker, which is a separate, visible decision. See `variables.md`.

## 7. Dotted or otherwise non-standard variable ids

The skills recommend variable ids made of `[a-zA-Z0-9_-]`. Base 2.1.3 doesn't validate ids itself; the Companion host does, and how Companion 5 treats a dot (`light.ip`) has not been verified. If a released module already uses such ids, **keep them byte-identical**, because users reference them as `$(conn:light.ip)` and no upgrade script can rewrite those references. Flag it for the maintainer to confirm in Companion 5. Renaming them would need a release note.
